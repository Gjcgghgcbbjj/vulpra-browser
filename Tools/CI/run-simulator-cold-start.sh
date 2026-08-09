#!/bin/bash
# Fresh-launch cold-start measurement harness (A2 gate). Modeled on Tools/CI/run-simulator-navigation.sh
# (device lifecycle, merged system+stream evidence, screenshot render audit)
# but measures launch -> engine ready -> load requested -> location ->
# page complete WITHOUT a warm URL / openurl / gate dispatch. The real URL is
# delivered at launch via SIMCTL_CHILD_VULPRA_SMOKE_URL.
#
# Requires the A2 markers already in the v5 snapshot:
#   VulpraEngineRuntime.markReady()  -> "Engine runtime ready"
#   VulpraEngineSession load         -> "Engine load requested: <url>, open:"
#   VulpraEngineSession location     -> "Engine location: <url>"
#   VulpraEngineSession page stop    -> "Engine page completed: true"
#   VulpraEngineSession openNow      -> "initial_load_deferred=true|false"
#
# Usage: run-simulator-cold-start.sh --app PATH --runtime ID --device-type ID
#        --attempt N --output DIR --url URL [--cold-start-seconds SECONDS]
# Exit 0 ALWAYS when evidence is written; the A2 summarizer
# (summarize-cold-start-gate.py) is the semantic gate, same contract pattern
# as the R0 navigation gate.
set -euo pipefail
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

APP=
RUNTIME=
DEVICE_TYPE=
ATTEMPT=
OUTPUT=
URL=
BUNDLE_ID=com.vulpra.browser
COLD_START_SECONDS=120
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP=$2; shift 2 ;;
    --runtime) RUNTIME=$2; shift 2 ;;
    --device-type) DEVICE_TYPE=$2; shift 2 ;;
    --attempt) ATTEMPT=$2; shift 2 ;;
    --output) OUTPUT=$2; shift 2 ;;
    --url) URL=$2; shift 2 ;;
    --bundle-id) BUNDLE_ID=$2; shift 2 ;;
    --cold-start-seconds) COLD_START_SECONDS=$2; shift 2 ;;
    *) echo "usage: $0 ..." >&2; exit 64 ;;
  esac
done

[[ -d "$APP" && -n "$RUNTIME" && -n "$DEVICE_TYPE" && "$ATTEMPT" =~ ^[1-9][0-9]*$ \
  && -n "$OUTPUT" && "$URL" == http://* && "$COLD_START_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  echo "usage: $0 --app PATH --runtime ID --device-type ID --attempt N --output DIR --url URL [--cold-start-seconds SECONDS]" >&2
  exit 64
}

run_with_timeout() {
  local seconds=$1
  shift
  python3 "$SCRIPT_DIR/run-with-timeout.py" "$seconds" "$@"
}

mkdir -p "$OUTPUT"
OUTPUT=$(CDPATH='' cd -- "$OUTPUT" && pwd)
ATTEMPT_START_ISO=$(date '+%Y-%m-%d %H:%M:%S')
T0_WALL_ISO=$(python3 -c 'from datetime import datetime; print(datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3])')

LOG_PREDICATE='process == "Vulpra" OR process CONTAINS[c] "Vulpra Engine" OR senderImagePath CONTAINS[c] "Vulpra" OR eventMessage CONTAINS[c] "Vulpra"'
UDID=
SYSTEM_LOG_PID=
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
printf 'attempt_start=%s\nt0_wall_iso=%s\ncold_start_seconds=%s\n' \
  "$ATTEMPT_START_ISO" "$T0_WALL_ISO" "$COLD_START_SECONDS" >> "$PREFIX-device.log"
UDID=$(xcrun simctl create "Vulpra-A2-${GITHUB_RUN_ID:-local}-$ATTEMPT" "$DEVICE_TYPE" "$RUNTIME")
printf 'attempt=%s\nruntime=%s\ndevice_type=%s\nudid=%s\n' \
  "$ATTEMPT" "$RUNTIME" "$DEVICE_TYPE" "$UDID" >> "$PREFIX-device.log"
set +e
defaults write com.apple.iphonesimulator ConfirmOpenURLInSimulator -bool NO >> "$PREFIX-device.log" 2>&1
set -e
xcrun simctl boot "$UDID"
run_with_timeout 180 xcrun simctl bootstatus "$UDID" -b >> "$PREFIX-device.log" 2>&1
xcrun simctl spawn "$UDID" defaults write NSGlobalDomain AppleLanguages -array zh-Hans
xcrun simctl spawn "$UDID" defaults write NSGlobalDomain AppleLocale -string zh_CN
run_with_timeout 300 xcrun simctl install "$UDID" "$APP"

xcrun simctl spawn "$UDID" log stream --style compact --info --debug \
  --predicate "$LOG_PREDICATE" > "$PREFIX-stream.log" 2>&1 &
SYSTEM_LOG_PID=$!
sleep 5

cold_start_completed_in_file() {
  local file=$1 url=$2
  python3 - "$file" "$url" <<'PY'
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

refresh_cold_start_snapshot() {
  local snapshot="$PREFIX-persisted-cold.log" age=999
  if [[ -f "$snapshot" ]]; then
    age=$(python3 -c 'import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))' "$snapshot" 2>/dev/null || echo 0)
    age=$(( $(date +%s) - age ))
  fi
  if (( age >= 10 )); then
    run_with_timeout 90 xcrun simctl spawn "$UDID" log show --style compact --info --debug \
      --start "$ATTEMPT_START_ISO" --predicate "$LOG_PREDICATE" \
      > "$PREFIX-persisted-cold.log.tmp" 2>&1 || true
    mv "$PREFIX-persisted-cold.log.tmp" "$PREFIX-persisted-cold.log" 2>/dev/null || true
  fi
}

cold_start_completed() {
  local url="$URL"
  if [[ -f "$PREFIX-stream.log" ]] && cold_start_completed_in_file "$PREFIX-stream.log" "$url"; then
    return 0
  fi
  refresh_cold_start_snapshot
  if [[ -f "$PREFIX-persisted-cold.log" ]] && cold_start_completed_in_file "$PREFIX-persisted-cold.log" "$url"; then
    printf 'cold_start_completed_via=persisted-store url=%s\n' "$url" >> "$PREFIX-device.log" || true
    return 0
  fi
  return 1
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

APP_PID=
LAUNCH_STATUS=1
LAUNCH_ATTEMPTS=0
# The cold-start phase anchor is the moment the app process is requested, not
# the harness start (device create/boot/install can take minutes on a fresh
# simulator). launch_t0_iso is emitted with milliseconds in the same format as
# the os_log evidence timestamps so delta computation is exact.
LAUNCH_T0_ISO=$(python3 -c 'from datetime import datetime; print(datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3])')
printf 'launch_t0_iso=%s\n' "$LAUNCH_T0_ISO" >> "$PREFIX-device.log"
set +e
for _launch_attempt in 1 2; do
  LAUNCH_ATTEMPTS=$_launch_attempt
  LAUNCH_OUTPUT=$(SIMCTL_CHILD_VULPRA_SMOKE_URL="$URL" \
    run_with_timeout 180 xcrun simctl launch "$UDID" "$BUNDLE_ID" 2>&1)
  LAUNCH_STATUS=$?
  set -e
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
printf 'launch_status=%s\nlaunch_attempts=%s\n' "$LAUNCH_STATUS" "$LAUNCH_ATTEMPTS" >> "$PREFIX-device.log"

if [[ "$LAUNCH_STATUS" -eq 0 && "$APP_PID" =~ ^[1-9][0-9]*$ ]]; then
  for ((_attempt = 1; _attempt <= COLD_START_SECONDS; _attempt++)); do
    if cold_start_completed; then
      break
    fi
    if ! /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
else
  printf 'launch_ready=false\n' >> "$PREFIX-device.log"
fi

APP_SURVIVED=false
if [[ "$APP_PID" =~ ^[1-9][0-9]*$ ]] && /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
  APP_SURVIVED=true
fi
SCREENSHOT_STATUS=1
for _screenshot_attempt in 1 2 3; do
  set +e
  run_with_timeout 60 xcrun simctl io "$UDID" screenshot "$PREFIX-navigation.png"
  SCREENSHOT_STATUS=$?
  set -e
  if [[ "$SCREENSHOT_STATUS" -eq 0 && -s "$PREFIX-navigation.png" ]]; then
    break
  fi
  sleep 10
done
printf 'screenshot_status=%s\n' "$SCREENSHOT_STATUS" >> "$PREFIX-device.log"
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
LOG_EVIDENCE="$PREFIX-evidence.log"
python3 - "$LOG_EVIDENCE" "$PREFIX-system.log" "$PREFIX-stream.log" <<'PYE'
import re
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
        match = re.search(r"launch=(\d+) .*stage=(\d+) .*monotonic_ns=(\d+)", line)
        if match:
            key = "lifecycle:{}:{}:{}".format(*match.groups())
        else:
            key = "line:" + line
        if key not in keyed:
            keyed[key] = line
Path(out_path).write_text("\n".join(sorted(keyed.values())) + "\n", encoding="utf-8")
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

python3 - "$ATTEMPT" "$URL" "$LAUNCH_T0_ISO" "$LOG_EVIDENCE" "$PREFIX-rendering.log" \
  "$APP_SURVIVED" "$CRASH_COUNT" "$PREFIX.json" "$PREFIX-device.log" <<'PY'
from datetime import datetime
import json
import re
import sys

attempt, url, t0_wall, evidence_path = sys.argv[1:5]
rendering_path, app_survived, crash_count, output_path = sys.argv[5:9]

timestamp = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})")

def find_event(marker, start=0):
    for index in range(start, len(lines)):
        if marker not in lines[index]:
            continue
        match = timestamp.match(lines[index])
        if match:
            return index, datetime.fromisoformat(match.group(1))
    return None

def find_events(prefix, url_value):
    marker = f"{prefix}{url_value}"
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

lines = open(evidence_path, encoding="utf-8", errors="replace").read().splitlines()
try:
    t0 = datetime.fromisoformat(t0_wall)
except ValueError:
    t0 = None

ready = find_event("Engine runtime ready")
loads = find_events("Engine load requested: ", url)
load = loads[0] if loads else None
location = None
if load is not None:
    for index, at in find_events("Engine location: ", url):
        if index > load[0]:
            location = (index, at)
            break
complete = None
if location is not None:
    complete = find_event("Engine page completed: true", location[0] + 1)
deferred_line = next((line for line in lines if "initial_load_deferred=true" in line), None)
immediate_line = next((line for line in lines if "initial_load_deferred=false" in line), None)
deferred = None
if deferred_line or immediate_line:
    deferred = deferred_line is not None

def delta_ms(later, earlier):
    if later is None or earlier is None:
        return -1
    return round((later[1] - earlier[1]).total_seconds() * 1000)

render_match = re.search(r"rendered_dark_pixels=(\d+)", open(rendering_path, encoding="utf-8").read())
value = {
    "attempt": int(attempt),
    "initialLoadDeferred": bool(deferred),
    "appLaunchToEngineReadyMs": delta_ms(ready, (0, t0)) if t0 else -1,
    "engineReadyToLoadRequestedMs": delta_ms(load, ready),
    "loadRequestedToLocationMs": delta_ms(location, load),
    "locationToPageCompleteMs": delta_ms(complete, location),
    "firstNavigationDelayMs": delta_ms(location, (0, t0)) if t0 else -1,
    "pageCompleteDelayMs": delta_ms(complete, (0, t0)) if t0 else -1,
    "renderedDarkPixels": int(render_match.group(1)) if render_match else 0,
    "appSurvived": app_survived == "true",
    "crashCount": int(crash_count),
    "markersPresent": sorted(
        marker for marker, event in (
            ("runtime-ready", ready), ("load-requested", load),
            ("location", location), ("page-complete", complete),
        ) if event is not None
    ),
    "evidenceSource": "merged-system+stream",
    "deliveryMethod": "launch-env-url",
}
open(output_path, "w", encoding="utf-8").write(json.dumps(value, indent=2) + "\n")
PY

printf 'PASS: Simulator cold-start attempt %s evidence=%s\n' "$ATTEMPT" "$PREFIX.json"
