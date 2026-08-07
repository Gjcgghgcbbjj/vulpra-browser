#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: $0 --app PATH --runtime ID --device-type ID --attempt N --output DIR --url URL [--navigation-seconds SECONDS]" >&2
  exit 64
}

APP=
RUNTIME=
DEVICE_TYPE=
ATTEMPT=
OUTPUT=
URL=
BUNDLE_ID=com.vulpra.browser
NAVIGATION_SECONDS=180
GATE_DISPATCH_PORT="${VULPRA_GATE_DISPATCH_PORT:-8766}"
GATE_DISPATCH_URL="${VULPRA_GATE_DISPATCH_URL:-http://127.0.0.1:8766/open}"
OPENURL_GRACE_SECONDS="${OPENURL_GRACE_SECONDS:-6}"
SIMCTL_OPENURL_FIRST="${SIMCTL_OPENURL_FIRST:-1}"
WARM_SETTLE_SECONDS="${WARM_SETTLE_SECONDS:-30}"
QUIESCE_IDLE_SECONDS="${QUIESCE_IDLE_SECONDS:-8}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP=$2; shift 2 ;;
    --runtime) RUNTIME=$2; shift 2 ;;
    --device-type) DEVICE_TYPE=$2; shift 2 ;;
    --attempt) ATTEMPT=$2; shift 2 ;;
    --output) OUTPUT=$2; shift 2 ;;
    --url) URL=$2; shift 2 ;;
    --bundle-id) BUNDLE_ID=$2; shift 2 ;;
    --navigation-seconds) NAVIGATION_SECONDS=$2; shift 2 ;;
    *) usage ;;
  esac
done

[[ -d "$APP" && -n "$RUNTIME" && -n "$DEVICE_TYPE" && "$ATTEMPT" =~ ^[1-9][0-9]*$ \
  && -n "$OUTPUT" && "$URL" == http://* && "$NAVIGATION_SECONDS" =~ ^[1-9][0-9]*$ ]] || usage
WARM_URL="${URL}?vulpra-warm=1"

run_with_timeout() {
  local seconds=$1
  shift
  perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$seconds" "$@"
}

deep_link() {
  python3 -c 'import sys, urllib.parse; print("vulpra://open?url=" + urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

DEEP_LINK=$(deep_link "$URL")
mkdir -p "$OUTPUT"
OUTPUT=$(CDPATH='' cd -- "$OUTPUT" && pwd)
ATTEMPT_START_ISO=$(date '+%Y-%m-%d %H:%M:%S')

UDID=
SYSTEM_LOG_PID=
LOG_PREDICATE='process == "Vulpra" OR process CONTAINS[c] "Vulpra Engine" OR senderImagePath CONTAINS[c] "Vulpra" OR eventMessage CONTAINS[c] "Vulpra"'
cleanup() {
  if [[ -n "$SYSTEM_LOG_PID" ]]; then
    kill "$SYSTEM_LOG_PID" >/dev/null 2>&1 || true
    wait "$SYSTEM_LOG_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$UDID" ]]; then
    run_with_timeout 60 xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
    run_with_timeout 60 xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

PREFIX="$OUTPUT/attempt-$(printf '%02d' "$ATTEMPT")"
printf 'attempt_start=%s\n' "$ATTEMPT_START_ISO" >> "$PREFIX-device.log"
UDID=$(xcrun simctl create "Vulpra-R0-${GITHUB_RUN_ID:-local}-$ATTEMPT" "$DEVICE_TYPE" "$RUNTIME")
printf 'attempt=%s\nruntime=%s\ndevice_type=%s\nudid=%s\n' \
  "$ATTEMPT" "$RUNTIME" "$DEVICE_TYPE" "$UDID" > "$PREFIX-device.log"
set +e
defaults write com.apple.iphonesimulator ConfirmOpenURLInSimulator -bool NO >> "$PREFIX-device.log" 2>&1
DEFAULTS_WRITE_STATUS=$?
set -e
printf 'confirm_open_url_simulator_defaults_status=%s\n' "$DEFAULTS_WRITE_STATUS" >> "$PREFIX-device.log" || true
defaults read com.apple.iphonesimulator ConfirmOpenURLInSimulator >> "$PREFIX-device.log" 2>&1 || true
xcrun simctl boot "$UDID"
run_with_timeout 180 xcrun simctl bootstatus "$UDID" -b >> "$PREFIX-device.log" 2>&1
xcrun simctl spawn "$UDID" defaults write NSGlobalDomain AppleLanguages -array zh-Hans
xcrun simctl spawn "$UDID" defaults write NSGlobalDomain AppleLocale -string zh_CN
run_with_timeout 300 xcrun simctl install "$UDID" "$APP"

xcrun simctl spawn "$UDID" log stream --style compact --info --debug \
  --predicate "$LOG_PREDICATE" > "$PREFIX-stream.log" 2>&1 &
SYSTEM_LOG_PID=$!
# Give the simulator log stream time to attach to logd before the first
# engine launch; a too-early launch can race the stream attach and drop the
# initial "requested" lifecycle event (unified log still retains it).
sleep 5

navigation_completed() {
  python3 - "$PREFIX-stream.log" "${1:-$URL}" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines()
url = sys.argv[2]
locations = []
for index, line in enumerate(lines):
    marker = f"Engine location: {url}"
    if marker not in line:
        continue
    remainder = line[line.index(marker) + len(marker):]
    if remainder != "" and remainder[0] not in ", ":
        continue
    locations.append(index)
location = locations[-1] if locations else None
complete = location is not None and any(
    "Engine page completed: true" in line for line in lines[location + 1:]
)
raise SystemExit(0 if complete else 1)
PY
}

app_is_running() {
  [[ "$APP_PID" =~ ^[1-9][0-9]*$ ]] && /bin/kill -0 "$APP_PID" >/dev/null 2>&1
}

gate_http_dispatch() {
  DELIVERY_METHOD=gate-http-dispatch
  printf 'gate_http_dispatch=true\ndispatch_deep_link=%s\n' "$DEEP_LINK" >> "$PREFIX-device.log"
  set +e
  run_with_timeout 30 curl --fail --silent --show-error \
    -H 'Content-Type: application/json' \
    --data "{\"deepLink\": \"$DEEP_LINK\"}" \
    "$GATE_DISPATCH_URL" >> "$PREFIX-device.log" 2>&1
  DISPATCH_STATUS=$?
  set -e
  printf 'gate_dispatch_status=%s\n' "$DISPATCH_STATUS" >> "$PREFIX-device.log"
  if [[ "$DISPATCH_STATUS" -ne 0 ]]; then
    for _retry in {1..10}; do
      sleep 1
      set +e
      run_with_timeout 5 curl --fail --silent --show-error \
        -H 'Content-Type: application/json' \
        --data "{\"deepLink\": \"$DEEP_LINK\"}" \
        "$GATE_DISPATCH_URL" >> "$PREFIX-device.log" 2>&1
      DISPATCH_STATUS=$?
      set -e
      if [[ "$DISPATCH_STATUS" -eq 0 ]]; then
        break
      fi
    done
  fi
  printf 'gate_dispatch_status_final=%s\n' "$DISPATCH_STATUS" >> "$PREFIX-device.log"
}

wait_for_engine_settle() {
  printf 'warm_settle_start=true\n' >> "$PREFIX-device.log"
  local started quiet baseline count
  started=$(date +%s)
  baseline=$(grep -c '\[com.vulpra.browser.engine-kit:child-lifecycle\]' "$PREFIX-stream.log" 2>/dev/null || true)
  quiet=$started
  for ((_attempt = 1; _attempt <= WARM_SETTLE_SECONDS; _attempt++)); do
    count=$(grep -c '\[com.vulpra.browser.engine-kit:child-lifecycle\]' "$PREFIX-stream.log" 2>/dev/null || true)
    if [[ "$count" -eq "$baseline" ]]; then
      if (( $(date +%s) - quiet >= QUIESCE_IDLE_SECONDS )); then
        break
      fi
    else
      baseline=$count
      quiet=$(date +%s)
    fi
    sleep 1
  done
  printf 'warm_settle_waited_seconds=%s\nquiesce_idle_seconds=%s\n' \
    "$(( $(date +%s) - started ))" "$QUIESCE_IDLE_SECONDS" >> "$PREFIX-device.log"
}


resolve_app_pid() {
  local candidate
  candidate=$(run_with_timeout 30 xcrun simctl spawn "$UDID" launchctl list 2>/dev/null \
    | awk -v bundle="$BUNDLE_ID" '$3 == bundle { print $1; exit }')
  if [[ "$candidate" =~ ^[1-9][0-9]*$ ]]; then
    APP_PID=$candidate
    return 0
  fi
  return 1
}

LAUNCH_STATUS=1
LAUNCH_ATTEMPTS=0
APP_PID=
set +e
for _launch_attempt in 1 2; do
  LAUNCH_ATTEMPTS=$_launch_attempt
  LAUNCH_OUTPUT=$(SIMCTL_CHILD_VULPRA_SMOKE_URL="$WARM_URL" \
    SIMCTL_CHILD_VULPRA_GATE_DISPATCH_PORT="$GATE_DISPATCH_PORT" \
    run_with_timeout 180 xcrun simctl launch "$UDID" "$BUNDLE_ID" 2>&1)
  LAUNCH_STATUS=$?
  printf '%s\n' "$LAUNCH_OUTPUT" > "$PREFIX-launch.log"
  APP_PID=${LAUNCH_OUTPUT##*: }
  if [[ "$APP_PID" =~ ^[1-9][0-9]*$ ]]; then
    break
  fi
  if resolve_app_pid; then
    printf 'launch_pid_resolved_via_launchctl=true\n' >> "$PREFIX-device.log"
    break
  fi
  if [[ "$_launch_attempt" -eq 1 ]]; then
    printf 'launch_attempt=%s launch_status=%s; retrying after settle\n' \
      "$_launch_attempt" "$LAUNCH_STATUS" >> "$PREFIX-device.log"
    sleep 15
  fi
done
set -e
printf 'launch_status=%s\nlaunch_attempts=%s\n' "$LAUNCH_STATUS" "$LAUNCH_ATTEMPTS" >> "$PREFIX-device.log"

if [[ "$LAUNCH_STATUS" -eq 0 && "$APP_PID" =~ ^[1-9][0-9]*$ ]]; then
  for ((_attempt = 1; _attempt <= NAVIGATION_SECONDS; _attempt++)); do
    if navigation_completed "$WARM_URL"; then
      break
    fi
    if ! app_is_running; then
      break
    fi
    sleep 1
  done

  DELIVERY_METHOD=simctl-openurl
  if app_is_running; then
    if navigation_completed "$WARM_URL"; then
      wait_for_engine_settle
    fi
    if [[ "$SIMCTL_OPENURL_FIRST" != "1" ]]; then
      printf 'openurl_status=skipped\nopenurl_blocked_by_system_prompt=skipped-ios26\n' >> "$PREFIX-device.log"
      gate_http_dispatch
    else
      set +e
      run_with_timeout 60 xcrun simctl openurl "$UDID" "$DEEP_LINK" >> "$PREFIX-device.log" 2>&1
      OPENURL_STATUS=$?
      set -e
      printf 'openurl_status=%s\n' "$OPENURL_STATUS" >> "$PREFIX-device.log"
      for ((_attempt = 1; _attempt <= OPENURL_GRACE_SECONDS; _attempt++)); do
        if navigation_completed "$URL"; then
          break
        fi
        if ! app_is_running; then
          break
        fi
        sleep 1
      done
      if ! navigation_completed "$URL" && app_is_running; then
        if grep -Fq 'SBUserNotificationAlert' "$PREFIX-stream.log" 2>/dev/null; then
          printf 'openurl_blocked_by_system_prompt=true\n' >> "$PREFIX-device.log"
        fi
        gate_http_dispatch
      fi
    fi
    for ((_attempt = 1; _attempt <= NAVIGATION_SECONDS; _attempt++)); do
      if navigation_completed "$URL"; then
        break
      fi
      if ! app_is_running; then
        break
      fi
      sleep 1
    done
  fi
  printf 'DELIVERY_METHOD=%s\n' "$DELIVERY_METHOD" >> "$PREFIX-device.log"

  sleep 5
fi

APP_SURVIVED=false
if app_is_running; then
  APP_SURVIVED=true
fi
SCREENSHOT_STATUS=1
SCREENSHOT_ATTEMPTS=0
for _screenshot_attempt in 1 2 3; do
  SCREENSHOT_ATTEMPTS=$_screenshot_attempt
  set +e
  run_with_timeout 60 xcrun simctl io "$UDID" screenshot "$PREFIX-navigation.png"
  SCREENSHOT_STATUS=$?
  set -e
  if [[ "$SCREENSHOT_STATUS" -eq 0 && -s "$PREFIX-navigation.png" ]]; then
    break
  fi
  if [[ "$_screenshot_attempt" -lt 3 ]]; then
    printf 'screenshot_attempt=%s screenshot_status=%s; retrying after settle\n' \
      "$_screenshot_attempt" "$SCREENSHOT_STATUS" >> "$PREFIX-device.log"
    sleep 10
  fi
done
printf 'screenshot_status=%s\nscreenshot_attempts=%s\n' "$SCREENSHOT_STATUS" "$SCREENSHOT_ATTEMPTS" >> "$PREFIX-device.log"
kill "$SYSTEM_LOG_PID" >/dev/null 2>&1 || true
wait "$SYSTEM_LOG_PID" >/dev/null 2>&1 || true
SYSTEM_LOG_PID=
sleep 2
set +e
run_with_timeout 180 xcrun simctl spawn "$UDID" log show --style compact --info --debug \
  --start "$ATTEMPT_START_ISO" --predicate "$LOG_PREDICATE" > "$PREFIX-system.log" 2>&1
LOG_SHOW_STATUS=$?
set -e
printf 'log_show_status=%s\n' "$LOG_SHOW_STATUS" >> "$PREFIX-device.log"
if [[ "$LOG_SHOW_STATUS" -eq 142 ]]; then
  printf 'log_show_timed_out=true\n' >> "$PREFIX-device.log"
fi
# Build one timestamp-ordered evidence log from both the live stream and the
# unified log query. Either source alone can be partial (stream attach race,
# log-show scan timeout under load); merging by monotonic event key removes
# duplicates while keeping the union of every captured lifecycle/navigation
# event. Keep the raw sources as diagnostics.
LOG_EVIDENCE="$PREFIX-evidence.log"
python3 - "$PREFIX-evidence.log" "$PREFIX-system.log" "$PREFIX-stream.log" <<'PYE'
import sys
from pathlib import Path

out_path, *sources = sys.argv[1:]
keyed = {}
for source in sources:
    path = Path(source)
    if not path.exists():
        continue
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line:
            continue
        match = __import__("re").search(
            r"launch=(\d+) .*stage=(\d+) .*monotonic_ns=(\d+)", line)
        if match:
            key = "lifecycle:{}:{}:{}".format(*match.groups())
        else:
            key = "line:" + line
        if key not in keyed:
            keyed[key] = line
Path(out_path).write_text(
    "\n".join(sorted(keyed.values())) + "\n", encoding="utf-8")
PYE
printf 'log_evidence_source=merged-system+stream\nlog_evidence_lines=%s\n' \
  "$(wc -l < "$LOG_EVIDENCE" | tr -d ' ')" >> "$PREFIX-device.log"

mkdir -p "$PREFIX-crashes"
: > "$PREFIX-crash-paths.log"
for crash_root in \
  "$HOME/Library/Logs/DiagnosticReports" \
  "$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data"; do
  [[ -d "$crash_root" ]] || continue
  while IFS= read -r crash; do
    [[ -n "$crash" ]] || continue
    printf '%s\n' "$crash" >> "$PREFIX-crash-paths.log"
    cp "$crash" "$PREFIX-crashes/"
  done < <(find "$crash_root" -type f \
    \( -name 'Vulpra*.crash' -o -name 'Vulpra*.ips' \) -mmin -10 -print 2>/dev/null)
done
CRASH_COUNT=$(find "$PREFIX-crashes" -type f | wc -l | tr -d ' ')
run_with_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE_ID" \
  > "$PREFIX-terminate.log" 2>&1 || true

set +e
swift - "$PREFIX-navigation.png" <<'SWIFT' > "$PREFIX-rendering.log"
import CoreGraphics
import Darwin
import Foundation
import ImageIO

let path = CommandLine.arguments[1]
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("unable to decode simulator screenshot\n", stderr)
    exit(1)
}
let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 255, count: width * height * 4)
let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
    guard let context = CGContext(
        data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return true
}
guard drewImage else { exit(1) }
var darkPixels = 0
for y in (height / 4)..<(height * 3 / 4) {
    for x in (width / 8)..<(width * 7 / 8) {
        let offset = (y * width + x) * 4
        if pixels[offset] < 220 && pixels[offset + 1] < 220 && pixels[offset + 2] < 220 {
            darkPixels += 1
        }
    }
}
print("rendered_dark_pixels=\(darkPixels)")
SWIFT
SWIFT_STATUS=$?
set -e
if [[ "$SWIFT_STATUS" -ne 0 ]]; then
  printf 'rendered_dark_pixels=0\n' > "$PREFIX-rendering.log"
fi

python3 - "$ATTEMPT" "$URL" "$LOG_EVIDENCE" "$PREFIX-rendering.log" \
  "$APP_SURVIVED" "$CRASH_COUNT" "$PREFIX.json" "$PREFIX-device.log" <<'PY'
from datetime import datetime
import json
from pathlib import Path
import re
import sys

attempt, smoke_url, log_path, rendering_path, survived, crash_count, output, device_log_path = sys.argv[1:]
lines = Path(log_path).read_text(encoding="utf-8", errors="replace").splitlines()

def int_metric(raw):
    try:
        return int(raw)
    except (TypeError, ValueError):
        return -1


def metric(name):
    for line in Path(device_log_path).read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith(name + "="):
            return line[len(name) + 1:].strip()
    return None

timestamp = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})")

def find_event(marker, start=0):
    for index in range(start, len(lines)):
        if marker not in lines[index]:
            continue
        match = timestamp.match(lines[index])
        if match:
            return index, datetime.fromisoformat(match.group(1))
    return None

def find_events(prefix, url):
    marker = f"{prefix}{url}"
    events = []
    for index, line in enumerate(lines):
        if marker not in line:
            continue
        remainder = line[line.index(marker) + len(marker):]
        if remainder != "" and remainder[0] not in ", ":
            continue
        match = timestamp.match(line)
        if match:
            events.append((index, datetime.fromisoformat(match.group(1))))
    return events

load_events = find_events("Engine load requested: ", smoke_url)
location_events = find_events("Engine location: ", smoke_url)
load = load_events[-1] if load_events else None
location = None
if load is not None:
    for index, at in location_events:
        if index > load[0]:
            location = (index, at)
            break
complete = None
if location is not None:
    complete = find_event("Engine page completed: true", location[0] + 1)
load_to_complete = -1
if load and complete:
    load_to_complete = round((complete[1] - load[1]).total_seconds() * 1000)

stage_names = {
    1: "requested", 2: "extensionConnected", 3: "bootstrapAcknowledged",
    4: "ipcConnected", 5: "failed", 6: "terminated",
}
failure_names = {
    0: "none", 1: "extensionStart", 2: "xpcTransport", 3: "bootstrapReply",
    4: "processLaunch", 5: "ipcBeforeConnection", 6: "terminatedBeforeOutcome",
    7: "invalidTransition",
}
pattern = re.compile(
    r"launch=(\d+) child=(\d+) type=(\S+) pid=(\d+) stage=(\d+) "
    r"monotonic_ns=(\d+) failure=(\d+) reason=(.*)$"
)
events = []
for line in lines:
    match = pattern.search(line)
    if not match:
        continue
    launch, child, process_type, pid, stage, monotonic, failure, reason = match.groups()
    reason = reason.strip()
    stage_value = int(stage)
    failure_value = int(failure)
    if stage_value not in stage_names or failure_value not in failure_names:
        continue
    events.append({
        "launchID": int(launch),
        "childID": int(child),
        "processType": process_type,
        "pid": None if int(pid) == 0 else int(pid),
        "stage": stage_names[stage_value],
        "monotonicTimestampNanoseconds": int(monotonic),
        "failureCode": failure_names[failure_value],
        "reason": None if reason == "none" else reason,
    })
events.sort(key=lambda event: event["monotonicTimestampNanoseconds"])

requested = sorted({event["launchID"] for event in events if event["stage"] == "requested"})
connected = sorted({event["launchID"] for event in events if event["stage"] == "ipcConnected"})
failed = sorted({event["launchID"] for event in events if event["stage"] == "failed"})
open_ids = sorted(set(requested) - set(connected) - set(failed))
render_match = re.search(
    r"rendered_dark_pixels=(\d+)", Path(rendering_path).read_text(encoding="utf-8")
)
value = {
    "attempt": int(attempt),
    "locationMatched": location is not None,
    "pageCompleted": complete is not None,
    "renderedDarkPixels": int(render_match.group(1)) if render_match else 0,
    "loadToCompleteMs": load_to_complete,
    "appSurvived": survived == "true",
    "crashCount": int(crash_count),
    "lifecycleEvents": events,
    "requestedLaunchIDs": requested,
    "connectedLaunchIDs": connected,
    "failedLaunchIDs": failed,
    "openLaunchIDs": open_ids,
    "deliveryMethod": metric("DELIVERY_METHOD"),
    "warmSettleSeconds": int_metric(metric("warm_settle_waited_seconds")),
    "gateDispatchStatus": int_metric(metric("gate_dispatch_status_final")),
    "openurlStatus": metric("openurl_status") or "unavailable",
    "launchStatus": int_metric(metric("launch_status")),
    "launchAttempts": int_metric(metric("launch_attempts")),
    "logShowStatus": int_metric(metric("log_show_status")),
    "logEvidenceSource": metric("log_evidence_source") or "unknown",
}
Path(output).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
PY

printf 'PASS: Simulator navigation attempt %s evidence=%s\n' "$ATTEMPT" "$PREFIX.json"
