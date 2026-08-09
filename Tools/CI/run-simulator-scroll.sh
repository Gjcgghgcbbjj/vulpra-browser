#!/bin/bash
# Scroll-performance Simulator harness (R1 scroll gate). Loads a tall fixture
# page that auto-scrolls in-page JS, triggers the scroll-performance gate
# scenario over the loopback GateDispatchServer, and samples the App
# main-thread render cadence with a CADisplayLink (ScrollFrameSampler).
#
# Modeled on Tools/CI/run-simulator-navigation.sh (device lifecycle, merged
# system+stream evidence, screenshot render audit) but measures frame
# intervals during an auto-scroll window instead of navigation timing.
#
# Usage: run-simulator-scroll.sh --app PATH --runtime ID --device-type ID
#        --attempt N --output DIR --url URL [--scroll-seconds SECONDS]
# Exit 0 ALWAYS when evidence is written; the scroll summarizer
# (summarize-scroll-gate.py) is the semantic gate, same contract pattern as
# the R0/A2 gates.
set -euo pipefail
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

APP=
RUNTIME=
DEVICE_TYPE=
ATTEMPT=
OUTPUT=
URL=
BUNDLE_ID=com.vulpra.browser
SCROLL_SECONDS=10
GATE_DISPATCH_PORT="${VULPRA_GATE_DISPATCH_PORT:-8766}"
GATE_DISPATCH_URL="${VULPRA_GATE_DISPATCH_URL:-http://127.0.0.1:8766/open}"
LOAD_TIMEOUT_SECONDS=180
SCENARIO_TIMEOUT_SECONDS=90
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP=$2; shift 2 ;;
    --runtime) RUNTIME=$2; shift 2 ;;
    --device-type) DEVICE_TYPE=$2; shift 2 ;;
    --attempt) ATTEMPT=$2; shift 2 ;;
    --output) OUTPUT=$2; shift 2 ;;
    --url) URL=$2; shift 2 ;;
    --bundle-id) BUNDLE_ID=$2; shift 2 ;;
    --scroll-seconds) SCROLL_SECONDS=$2; shift 2 ;;
    *) echo "usage: $0 ..." >&2; exit 64 ;;
  esac
done

[[ -d "$APP" && -n "$RUNTIME" && -n "$DEVICE_TYPE" && "$ATTEMPT" =~ ^[1-9][0-9]*$ \
  && -n "$OUTPUT" && "$URL" == http://* && "$SCROLL_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  echo "usage: $0 --app PATH --runtime ID --device-type ID --attempt N --output DIR --url URL [--scroll-seconds SECONDS]" >&2
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
printf 'attempt_start=%s\nscroll_seconds=%s\n' "$ATTEMPT_START_ISO" "$SCROLL_SECONDS" >> "$PREFIX-device.log"
UDID=$(xcrun simctl create "Vulpra-Scroll-${GITHUB_RUN_ID:-local}-$ATTEMPT" "$DEVICE_TYPE" "$RUNTIME")
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

navigation_completed_in_file() {
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

refresh_navigation_snapshot() {
  local snapshot="$PREFIX-persisted-nav.log" age=999
  if [[ -f "$snapshot" ]]; then
    age=$(python3 -c 'import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))' "$snapshot" 2>/dev/null || echo 0)
    age=$(( $(date +%s) - age ))
  fi
  if (( age >= 10 )); then
    run_with_timeout 90 xcrun simctl spawn "$UDID" log show --style compact --info --debug \
      --start "$ATTEMPT_START_ISO" --predicate "$LOG_PREDICATE" \
      > "$PREFIX-persisted-nav.log.tmp" 2>&1 || true
    mv "$PREFIX-persisted-nav.log.tmp" "$PREFIX-persisted-nav.log" 2>/dev/null || true
  fi
}

navigation_completed() {
  local url="$URL"
  if [[ -f "$PREFIX-stream.log" ]] && navigation_completed_in_file "$PREFIX-stream.log" "$url"; then
    return 0
  fi
  refresh_navigation_snapshot
  if [[ -f "$PREFIX-persisted-nav.log" ]] && navigation_completed_in_file "$PREFIX-persisted-nav.log" "$url"; then
    printf 'navigation_completed_via=persisted-store url=%s\n' "$url" >> "$PREFIX-device.log" || true
    return 0
  fi
  return 1
}

scroll_scenario_completed_in_file() {
  local file=$1
  grep -Fq "gate_scenario=scroll-performance completed" "$file"
}

scroll_scenario_completed() {
  if [[ -f "$PREFIX-stream.log" ]] && scroll_scenario_completed_in_file "$PREFIX-stream.log"; then
    return 0
  fi
  refresh_navigation_snapshot
  if [[ -f "$PREFIX-persisted-nav.log" ]] && scroll_scenario_completed_in_file "$PREFIX-persisted-nav.log"; then
    printf 'scroll_scenario_completed_via=persisted-store\n' >> "$PREFIX-device.log" || true
    return 0
  fi
  return 1
}

app_is_running() {
  [[ "$APP_PID" =~ ^[1-9][0-9]*$ ]] && /bin/kill -0 "$APP_PID" >/dev/null 2>&1
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
  LAUNCH_OUTPUT=$(SIMCTL_CHILD_VULPRA_SMOKE_URL="$URL" \
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

SCENARIO_STATUS=-1
if [[ "$LAUNCH_STATUS" -eq 0 && "$APP_PID" =~ ^[1-9][0-9]*$ ]]; then
  for ((_attempt = 1; _attempt <= LOAD_TIMEOUT_SECONDS; _attempt++)); do
    if navigation_completed; then
      break
    fi
    if ! app_is_running; then
      break
    fi
    sleep 1
  done
  if navigation_completed && app_is_running; then
    printf 'scroll_scenario_started=true url=%s\n' "$URL" >> "$PREFIX-device.log"
    set +e
    run_with_timeout 30 curl --fail --silent --show-error \
      -H 'Content-Type: application/json' \
      --data "{\"scenario\": \"scroll-performance\", \"url\": \"$URL\", \"seconds\": $SCROLL_SECONDS}" \
      "$GATE_DISPATCH_URL" >> "$PREFIX-device.log" 2>&1
    dispatch_status=$?
    set -e
    printf 'scroll_scenario_dispatch_status=%s\n' "$dispatch_status" >> "$PREFIX-device.log"
    if [[ "$dispatch_status" -eq 0 ]]; then
      for ((_attempt = 1; _attempt <= SCENARIO_TIMEOUT_SECONDS; _attempt++)); do
        if scroll_scenario_completed; then
          SCENARIO_STATUS=0
          break
        fi
        if ! app_is_running; then
          break
        fi
        sleep 1
      done
    fi
  else
    printf 'scroll_scenario_skipped=initial-navigation-incomplete\n' >> "$PREFIX-device.log"
  fi
  printf 'scroll_scenario_status=%s\n' "$SCENARIO_STATUS" >> "$PREFIX-device.log"
else
  printf 'launch_ready=false\n' >> "$PREFIX-device.log"
  printf 'scroll_scenario_skipped=launch-failed\n' >> "$PREFIX-device.log"
  printf 'scroll_scenario_status=-1\n' >> "$PREFIX-device.log"
fi

APP_SURVIVED=false
if app_is_running; then
  APP_SURVIVED=true
fi
SCREENSHOT_STATUS=1
for _screenshot_attempt in 1 2 3; do
  set +e
  run_with_timeout 60 xcrun simctl io "$UDID" screenshot "$PREFIX-navigation.png"
  SCREENSHOT_STATUS=$?
  set -e
  if [[ "$SCREENSHOT_STATUS" -eq 0 && -s "$PREFIX-navigation.png" ]]; then
    # Accept the capture only when the render audit proves the engine
    # surface composited content. `simctl io screenshot` can race an
    # OpenApplication foreground transition and capture a blank frame even
    # when the page fully rendered (run 31310633542 R0 attempt-01: all
    # functional markers green, screenshot pure white), so blank captures
    # are retried after a settle instead of failing the gate.
    "$SCRIPT_DIR/audit-rendering.sh" "$PREFIX-navigation.png" "$PREFIX-render-check.log"
    dark=$(sed -n 's/^rendered_dark_pixels=\([0-9][0-9]*\)$/\1/p' "$PREFIX-render-check.log" | head -1)
    if [[ "$dark" =~ ^[0-9]+$ ]] && (( dark >= 1000 )); then
      printf 'screenshot_audit=rendered dark=%s\n' "$dark" >> "$PREFIX-device.log"
      break
    fi
    printf 'screenshot_audit=blank dark=%s; recapturing\n' "${dark:-0}" >> "$PREFIX-device.log"
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
if [[ "$LOG_SHOW_STATUS" -eq 142 ]]; then
  printf 'log_show_timed_out=true\n' >> "$PREFIX-device.log"
fi
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

# Render audit for the evidence record (same dark-pixel semantics the
# summarizers apply; blank captures were already retried above).
"$SCRIPT_DIR/audit-rendering.sh" "$PREFIX-navigation.png" "$PREFIX-rendering.log"

python3 - "$ATTEMPT" "$URL" "$SCROLL_SECONDS" "$LOG_EVIDENCE" "$PREFIX-rendering.log" \
  "$APP_SURVIVED" "$CRASH_COUNT" "$PREFIX.json" "$PREFIX-device.log" <<'PY'
import json
import re
import sys
from pathlib import Path

attempt, url, scroll_seconds, log_path, rendering_path = sys.argv[1:6]
survived, crash_count, output, device_log_path = sys.argv[6:10]
lines = Path(log_path).read_text(encoding="utf-8", errors="replace").splitlines()

def metric(name):
    for line in Path(device_log_path).read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith(name + "="):
            return line[len(name) + 1:].strip()
    return None

completed = None
for line in lines:
    if "gate_scenario=scroll-performance completed" in line:
        completed = line
        break

def int_metric(raw):
    try:
        return int(raw)
    except (TypeError, ValueError):
        return -1

stats = {}
if completed is not None:
    for key in ("sampled", "p95", "max", "hitches", "stalls", "refreshHz"):
        match = re.search(rf"\b{key}=([0-9.]+)", completed)
        if match:
            try:
                stats[key] = int(match.group(1)) if key not in ("p95", "max") else round(float(match.group(1)), 1)
            except ValueError:
                stats[key] = -1

render_match = re.search(
    r"rendered_dark_pixels=(\d+)", Path(rendering_path).read_text(encoding="utf-8")
)
scroll_status_raw = metric("scroll_scenario_status")
scroll_status = {"0": "completed", "1": "aborted", "-1": "skipped"}.get(scroll_status_raw, "skipped")
value = {
    "attempt": int(attempt),
    "url": url,
    "scrollSeconds": int(scroll_seconds),
    "scenarioStatus": scroll_status,
    "sampledFrames": stats.get("sampled", -1),
    "p95FrameIntervalMs": stats.get("p95", -1.0),
    "maxFrameIntervalMs": stats.get("max", -1.0),
    "hitchCount": stats.get("hitches", -1),
    "stallCount": stats.get("stalls", -1),
    "displayRefreshHz": stats.get("refreshHz", -1),
    "renderedDarkPixels": int(render_match.group(1)) if render_match else 0,
    "appSurvived": survived == "true",
    "crashCount": int(crash_count),
    "launchStatus": int_metric(metric("launch_status")),
    "launchAttempts": int_metric(metric("launch_attempts")),
    "logShowStatus": int_metric(metric("log_show_status")),
    "logEvidenceSource": metric("log_evidence_source") or "unknown",
    "dispatchStatus": int_metric(metric("scroll_scenario_dispatch_status")),
}
Path(output).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
PY

printf 'PASS: Simulator scroll attempt %s evidence=%s\n' "$ATTEMPT" "$PREFIX.json"
