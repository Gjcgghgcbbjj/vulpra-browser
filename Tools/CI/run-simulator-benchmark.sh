#!/bin/bash
# Standard-benchmark Simulator harness. Loads a pinned benchmark runner page
# (Tools/CI/benchmark-fixture.py generate) as the App initial URL over the
# loopback fixture server, waits for the same-origin runner to report the
# final score through the page title ("VulpraBenchmark <id> score=<text>"),
# which VulpraEngineSession logs as "Engine title: ..." via
# GeckoView:PageTitleChanged. The score is then parsed from the unified
# system+stream evidence log.
#
# Modeled on Tools/CI/run-simulator-scroll.sh (device lifecycle, merged
# system+stream evidence, crash collection) minus the GateDispatchServer
# scenario: the runner page itself starts the benchmark and publishes the
# score, so no loopback dispatch is needed.
#
# Usage: run-simulator-benchmark.sh --app PATH --runtime ID --device-type ID
#        --attempt N --output DIR --url URL --benchmark ID
#        [--timeout-seconds SECONDS] [--bundle-id ID]
# Exit 0 ALWAYS when evidence is written; summarize-benchmark.py is the
# semantic gate (same contract pattern as the R0/A2/scroll gates).
set -euo pipefail
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

APP=
RUNTIME=
DEVICE_TYPE=
ATTEMPT=
OUTPUT=
URL=
BENCHMARK=
TIMEOUT_SECONDS=
BUNDLE_ID=com.vulpra.browser
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP=$2; shift 2 ;;
    --runtime) RUNTIME=$2; shift 2 ;;
    --device-type) DEVICE_TYPE=$2; shift 2 ;;
    --attempt) ATTEMPT=$2; shift 2 ;;
    --output) OUTPUT=$2; shift 2 ;;
    --url) URL=$2; shift 2 ;;
    --benchmark) BENCHMARK=$2; shift 2 ;;
    --timeout-seconds) TIMEOUT_SECONDS=$2; shift 2 ;;
    --bundle-id) BUNDLE_ID=$2; shift 2 ;;
    *) echo "usage: $0 ..." >&2; exit 64 ;;
  esac
done

[[ -d "$APP" && -n "$RUNTIME" && -n "$DEVICE_TYPE" && "$ATTEMPT" =~ ^[1-9][0-9]*$ \
  && -n "$OUTPUT" && "$URL" == http://* && "$BENCHMARK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "usage: $0 --app PATH --runtime ID --device-type ID --attempt N --output DIR --url URL --benchmark ID [--timeout-seconds SECONDS]" >&2
  exit 64
}
if [[ -z "$TIMEOUT_SECONDS" ]]; then
  TIMEOUT_SECONDS=$(python3 - "$BENCHMARK" <<'PY' || echo 1800
import json
import sys
from pathlib import Path
benchmark_id = sys.argv[1]
manifest = Path("Configuration/benchmarks.json")
value = json.loads(manifest.read_text(encoding="utf-8"))
for entry in value["benchmarks"]:
    if entry["id"] == benchmark_id:
        print(entry["run"]["timeoutSeconds"])
        raise SystemExit(0)
raise SystemExit(1)
PY
)
fi
[[ "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  echo "timeout must be a positive integer" >&2
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
printf 'attempt_start=%s\ntimeout_seconds=%s\nbenchmark=%s\n' \
  "$ATTEMPT_START_ISO" "$TIMEOUT_SECONDS" "$BENCHMARK" >> "$PREFIX-device.log"
UDID=$(xcrun simctl create "Vulpra-Bench-${GITHUB_RUN_ID:-local}-$BENCHMARK-$ATTEMPT" "$DEVICE_TYPE" "$RUNTIME")
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

benchmark_score_in_file() {
  local file=$1
  python3 - "$file" "$BENCHMARK" <<'PY'
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines()
benchmark_id = sys.argv[2]
marker = f"Engine title: VulpraBenchmark {benchmark_id} score="
for line in lines:
    index = line.find(marker)
    if index == -1:
        continue
    remainder = line[index + len(marker):]
    match = re.match(r"([0-9]+(?:\.[0-9]+)?)", remainder)
    if not match:
        continue
    print(f"{match.group(1)}\t{line}")
    raise SystemExit(0)
raise SystemExit(1)
PY
}

refresh_log_snapshot() {
  local snapshot="$PREFIX-persisted.log" age=999
  if [[ -f "$snapshot" ]]; then
    age=$(python3 -c 'import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))' "$snapshot" 2>/dev/null || echo 0)
    age=$(( $(date +%s) - age ))
  fi
  if (( age >= 30 )); then
    run_with_timeout 90 xcrun simctl spawn "$UDID" log show --style compact --info --debug \
      --start "$ATTEMPT_START_ISO" --predicate "$LOG_PREDICATE" \
      > "$PREFIX-persisted.log.tmp" 2>&1 || true
    mv "$PREFIX-persisted.log.tmp" "$PREFIX-persisted.log" 2>/dev/null || true
  fi
}

benchmark_completed() {
  local result
  if [[ -f "$PREFIX-stream.log" ]] && result=$(benchmark_score_in_file "$PREFIX-stream.log"); then
    SCORE_RESULT=$result
    printf 'score_via=stream\n' >> "$PREFIX-device.log"
    return 0
  fi
  refresh_log_snapshot
  if [[ -f "$PREFIX-persisted.log" ]] && result=$(benchmark_score_in_file "$PREFIX-persisted.log"); then
    SCORE_RESULT=$result
    printf 'score_via=persisted-store\n' >> "$PREFIX-device.log"
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
SCORE_RESULT=
set +e
for _launch_attempt in 1 2; do
  LAUNCH_ATTEMPTS=$_launch_attempt
  LAUNCH_OUTPUT=$(SIMCTL_CHILD_VULPRA_SMOKE_URL="$URL" \
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

LAUNCH_START_EPOCH_MS=$(date +%s%3N)
COMPLETED=false
if [[ "$LAUNCH_STATUS" -eq 0 && "$APP_PID" =~ ^[1-9][0-9]*$ ]]; then
  for ((_second = 1; _second <= TIMEOUT_SECONDS; _second++)); do
    if benchmark_completed; then
      COMPLETED=true
      break
    fi
    if ! app_is_running; then
      break
    fi
    sleep 1
  done
  if [[ "$COMPLETED" != true ]]; then
    printf 'benchmark_timeout=true url=%s benchmark=%s seconds=%s\n' \
      "$URL" "$BENCHMARK" "$TIMEOUT_SECONDS" >> "$PREFIX-device.log"
  fi
else
  printf 'launch_ready=false\n' >> "$PREFIX-device.log"
fi
ELAPSED_MS=$(( $(date +%s%3N) - LAUNCH_START_EPOCH_MS ))
printf 'benchmark_completed=%s\nelapsed_ms=%s\n' "$COMPLETED" "$ELAPSED_MS" >> "$PREFIX-device.log"

APP_SURVIVED=false
if app_is_running; then
  APP_SURVIVED=true
fi
SCREENSHOT_STATUS=1
for _screenshot_attempt in 1 2 3; do
  set +e
  run_with_timeout 60 xcrun simctl io "$UDID" screenshot "$PREFIX-benchmark.png"
  SCREENSHOT_STATUS=$?
  set -e
  if [[ "$SCREENSHOT_STATUS" -eq 0 && -s "$PREFIX-benchmark.png" ]]; then
    break
  fi
  sleep 5
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
    cp "$crash" "$PREFIX-crashes/" 2>/dev/null || true
  done < <(find "$crash_root" -type f \
    \( -name 'Vulpra*.crash' -o -name 'Vulpra*.ips' \) -mmin -30 -print 2>/dev/null)
done
CRASH_COUNT=$(find "$PREFIX-crashes" -type f | wc -l | tr -d ' ')
run_with_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE_ID" \
  > "$PREFIX-terminate.log" 2>&1 || true

# Re-derive the score from the merged evidence so the JSON and the log agree.
SCORE_TEXT=
SCORE_VALUE=-1.0
SCORE_FROM=
if [[ "$COMPLETED" == true ]] && result=$(benchmark_score_in_file "$LOG_EVIDENCE"); then
  SCORE_TEXT=${result%%$'\t'*}
  SCORE_FROM=${result#*$'\t'}
  SCORE_VALUE=$(python3 -c 'import sys; print(float(sys.argv[1]))' "$SCORE_TEXT")
fi
printf 'score_text=%s\nscore_value=%s\n' "${SCORE_TEXT:-}" "${SCORE_VALUE}" >> "$PREFIX-device.log"

python3 - "$ATTEMPT" "$BENCHMARK" "$URL" "$COMPLETED" "$SCORE_TEXT" "$SCORE_VALUE" \
  "$SCORE_FROM" "$ELAPSED_MS" "$APP_SURVIVED" "$CRASH_COUNT" "$LAUNCH_STATUS" \
  "$LAUNCH_ATTEMPTS" "$LOG_SHOW_STATUS" "$SCREENSHOT_STATUS" "$PREFIX.json" <<'PY'
import json
import sys
from pathlib import Path

(
    attempt, benchmark, url, completed, score_text, score_value, score_from,
    elapsed_ms, survived, crash_count, launch_status, launch_attempts,
    log_show_status, screenshot_status, output,
) = sys.argv[1:]
value = {
    "attempt": int(attempt),
    "benchmark": benchmark,
    "url": url,
    "completed": completed == "true",
    "scoreText": score_text,
    "score": float(score_value),
    "scoreFrom": score_from,
    "elapsedMs": int(elapsed_ms),
    "appSurvived": survived == "true",
    "crashCount": int(crash_count),
    "launchStatus": int(launch_status),
    "launchAttempts": int(launch_attempts),
    "logShowStatus": int(log_show_status),
    "logEvidenceSource": "merged-system+stream",
    "screenshotStatus": int(screenshot_status),
}
Path(output).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
PY

printf 'PASS: Simulator benchmark attempt %s evidence=%s\n' "$ATTEMPT" "$PREFIX.json"
