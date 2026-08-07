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
UDID=$(xcrun simctl create "Vulpra-R0-${GITHUB_RUN_ID:-local}-$ATTEMPT" "$DEVICE_TYPE" "$RUNTIME")
printf 'attempt=%s\nruntime=%s\ndevice_type=%s\nudid=%s\n' \
  "$ATTEMPT" "$RUNTIME" "$DEVICE_TYPE" "$UDID" > "$PREFIX-device.log"
xcrun simctl boot "$UDID"
run_with_timeout 180 xcrun simctl bootstatus "$UDID" -b >> "$PREFIX-device.log" 2>&1
xcrun simctl spawn "$UDID" defaults write NSGlobalDomain AppleLanguages -array zh-Hans
xcrun simctl spawn "$UDID" defaults write NSGlobalDomain AppleLocale -string zh_CN
run_with_timeout 300 xcrun simctl install "$UDID" "$APP"

xcrun simctl spawn "$UDID" log stream --style compact --info --debug \
  --predicate "$LOG_PREDICATE" > "$PREFIX-stream.log" 2>&1 &
SYSTEM_LOG_PID=$!
sleep 2

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

set +e
LAUNCH_OUTPUT=$(SIMCTL_CHILD_VULPRA_SMOKE_URL="$WARM_URL" \
  run_with_timeout 180 xcrun simctl launch "$UDID" "$BUNDLE_ID" 2>&1)
LAUNCH_STATUS=$?
set -e
printf '%s\n' "$LAUNCH_OUTPUT" > "$PREFIX-launch.log"
APP_PID=${LAUNCH_OUTPUT##*: }

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

  if app_is_running; then
    set +e
    run_with_timeout 60 xcrun simctl openurl "$UDID" "$DEEP_LINK" >> "$PREFIX-device.log" 2>&1
    OPENURL_STATUS=$?
    set -e
    printf 'openurl_status=%s\n' "$OPENURL_STATUS" >> "$PREFIX-device.log"
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

  sleep 5
fi

APP_SURVIVED=false
if app_is_running; then
  APP_SURVIVED=true
fi
set +e
run_with_timeout 60 xcrun simctl io "$UDID" screenshot "$PREFIX-navigation.png"
SCREENSHOT_STATUS=$?
set -e
printf 'screenshot_status=%s\n' "$SCREENSHOT_STATUS" >> "$PREFIX-device.log"
kill "$SYSTEM_LOG_PID" >/dev/null 2>&1 || true
wait "$SYSTEM_LOG_PID" >/dev/null 2>&1 || true
SYSTEM_LOG_PID=
sleep 2
LOG_EVIDENCE="$PREFIX-system.log"
set +e
run_with_timeout 30 xcrun simctl spawn "$UDID" log show --style compact --info --debug \
  --last 10m --predicate "$LOG_PREDICATE" > "$PREFIX-system.log" 2>&1
LOG_SHOW_STATUS=$?
set -e
printf 'log_show_status=%s\n' "$LOG_SHOW_STATUS" >> "$PREFIX-device.log"
if [[ "$LOG_SHOW_STATUS" -ne 0 ]]; then
  printf 'log_show_status=%s; stream_log_fallback=true\n' "$LOG_SHOW_STATUS" >> "$PREFIX-system.log"
  if grep -q "Engine load requested" "$PREFIX-stream.log"; then
    LOG_EVIDENCE="$PREFIX-stream.log"
  fi
fi

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
  "$APP_SURVIVED" "$CRASH_COUNT" "$PREFIX.json" <<'PY'
from datetime import datetime
import json
from pathlib import Path
import re
import sys

attempt, smoke_url, log_path, rendering_path, survived, crash_count, output = sys.argv[1:]
lines = Path(log_path).read_text(encoding="utf-8", errors="replace").splitlines()
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
}
Path(output).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
PY

printf 'PASS: Simulator navigation attempt %s evidence=%s\n' "$ATTEMPT" "$PREFIX.json"
