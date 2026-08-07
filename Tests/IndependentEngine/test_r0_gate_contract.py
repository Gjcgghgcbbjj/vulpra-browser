#!/usr/bin/env python3
"""Portable fixtures for the repeated R0 Simulator engine gate."""

from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SUMMARIZER = ROOT / "Tools/CI/summarize-r0-engine-gate.py"
HARNESS = ROOT / "Tools/CI/run-simulator-navigation.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def event(stage: str, timestamp: int, pid: int | None = None) -> dict[str, object]:
    return {
        "launchID": 1,
        "childID": 1,
        "processType": "content",
        "pid": pid,
        "stage": stage,
        "monotonicTimestampNanoseconds": timestamp,
        "failureCode": "none",
        "reason": None,
    }


def valid_attempt(identifier: int, duration: int = 12000) -> dict[str, object]:
    return {
        "attempt": identifier,
        "locationMatched": True,
        "pageCompleted": True,
        "renderedDarkPixels": 12266,
        "loadToCompleteMs": duration,
        "appSurvived": True,
        "crashCount": 0,
        "lifecycleEvents": [
            event("requested", 1_000_000_000),
            event("extensionConnected", 1_002_000_000),
            event("bootstrapAcknowledged", 1_003_000_000, 321),
            event("ipcConnected", 1_005_000_000, 321),
        ],
        "requestedLaunchIDs": [1],
        "connectedLaunchIDs": [1],
        "failedLaunchIDs": [],
        "openLaunchIDs": [],
    }


def write_attempts(directory: Path, values: list[dict[str, object]]) -> None:
    directory.mkdir(parents=True)
    for index, value in enumerate(values, 1):
        (directory / f"attempt-{index:02d}.json").write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )


def write_executable(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def test_harness(base: Path) -> None:
    fake_bin = base / "fake-bin"
    operations = base / "simctl-operations.log"
    app_pid = base / "app.pid"
    write_executable(fake_bin / "sleep", "#!/bin/sh\n/bin/sleep 0.05\n")
    write_executable(fake_bin / "swift", "#!/bin/sh\necho rendered_dark_pixels=12266\n")
    write_executable(fake_bin / "xcrun", r'''#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$VULPRA_FAKE_SIMCTL_LOG"
if [ "$1" = simctl ] && [ "$2" = create ]; then
  echo fixture-udid
elif [ "$1" = simctl ] && [ "$2" = spawn ] && [ "${4:-}" = log ] && [ "${5:-}" = stream ]; then
  cat <<'LOG'
2026-07-30 12:00:00.000 Engine load requested: http://127.0.0.1:8765/?vulpra-warm=1
2026-07-30 12:00:00.010 launch=1 child=1 type=content pid=0 stage=1 monotonic_ns=1000000000 failure=0 reason=none
2026-07-30 12:00:00.500 Engine location: about:blank
2026-07-30 12:00:00.510 Engine page completed: true
2026-07-30 12:00:01.000 Engine location: http://127.0.0.1:8765/?vulpra-warm=1
2026-07-30 12:00:02.000 Engine page completed: true
2026-07-30 12:00:02.500 Engine load requested: http://127.0.0.1:8765/
2026-07-30 12:00:03.000 Engine location: http://127.0.0.1:8765/
2026-07-30 12:00:04.000 Engine page completed: true
LOG
elif [ "$1" = simctl ] && [ "$2" = spawn ] && [ "${4:-}" = log ] && [ "${5:-}" = show ]; then
  cat <<'LOG'
2026-07-30 12:00:00.000 Engine load requested: http://127.0.0.1:8765/?vulpra-warm=1
2026-07-30 12:00:00.010 launch=1 child=1 type=content pid=0 stage=1 monotonic_ns=1000000000 failure=0 reason=none
2026-07-30 12:00:00.020 launch=1 child=1 type=content pid=0 stage=2 monotonic_ns=1002000000 failure=0 reason=none
2026-07-30 12:00:00.030 launch=1 child=1 type=content pid=321 stage=3 monotonic_ns=1003000000 failure=0 reason=none
2026-07-30 12:00:00.040 launch=1 child=1 type=content pid=321 stage=4 monotonic_ns=1005000000 failure=0 reason=none
2026-07-30 12:00:00.500 Engine location: about:blank
2026-07-30 12:00:00.510 Engine page completed: true
2026-07-30 12:00:01.000 Engine location: http://127.0.0.1:8765/?vulpra-warm=1
2026-07-30 12:00:02.000 Engine page completed: true
2026-07-30 12:00:02.500 Engine load requested: http://127.0.0.1:8765/
2026-07-30 12:00:03.000 Engine location: http://127.0.0.1:8765/
2026-07-30 12:00:04.000 Engine page completed: true
LOG
elif [ "$1" = simctl ] && [ "$2" = launch ]; then
  /bin/sleep 300 >/dev/null 2>&1 &
  pid=$!
  printf '%s\n' "$pid" > "$VULPRA_FAKE_APP_PID"
  echo "com.vulpra.browser: $pid"
elif [ "$1" = simctl ] && [ "$2" = openurl ]; then
  printf 'openurl:%s\n' "$5" >> "$VULPRA_FAKE_SIMCTL_LOG"
  :
elif [ "$1" = simctl ] && [ "$2" = io ]; then
  for value in "$@"; do output=$value; done
  printf 'fixture-png' > "$output"
elif [ "$1" = simctl ] && [ "$2" = spawn ] && [ "${4:-}" = /bin/kill ]; then
  kill -0 "$(cat "$VULPRA_FAKE_APP_PID")"
elif [ "$1" = simctl ] && [ "$2" = terminate ]; then
  kill "$(cat "$VULPRA_FAKE_APP_PID")" >/dev/null 2>&1 || true
fi
''')
    app = base / "Vulpra.app"
    app.mkdir()
    output = base / "harness-output"
    environment = os.environ.copy()
    environment.update({
        "PATH": f"{fake_bin}:{environment['PATH']}",
        "HOME": str(base / "home"),
        "VULPRA_FAKE_SIMCTL_LOG": str(operations),
        "VULPRA_FAKE_APP_PID": str(app_pid),
    })
    result = subprocess.run([
        str(HARNESS), "--app", str(app),
        "--runtime", "fixture-runtime", "--device-type", "fixture-device",
        "--attempt", "1", "--output", str(output),
        "--url", "http://127.0.0.1:8765/",
    ], env=environment, text=True, capture_output=True, check=False)
    require(result.returncode == 0, result.stderr or result.stdout)
    evidence = json.loads((output / "attempt-01.json").read_text(encoding="utf-8"))
    require(evidence["locationMatched"] and evidence["pageCompleted"] and
            evidence["appSurvived"] and evidence["connectedLaunchIDs"] == [1] and
            evidence["loadToCompleteMs"] == 1500,
            "Simulator harness lost functional, lifecycle, or timing evidence")
    log = operations.read_text(encoding="utf-8")
    for command in (
        "simctl create", "simctl openurl", "simctl spawn fixture-udid log show",
        "simctl terminate", "simctl shutdown", "simctl delete",
        "vulpra://open?url=http%3A%2F%2F127.0.0.1%3A8765%2F",
    ):
        require(command in log, f"Simulator harness did not execute/route {command}")
    result = run(output, count=1)
    require(result.returncode == 0, result.stderr or result.stdout)


def run(directory: Path, count: int = 20) -> subprocess.CompletedProcess[str]:
    return subprocess.run([
        "python3", str(SUMMARIZER), "--attempts", str(count),
        "--input", str(directory), "--output", str(directory.parent / "summary.json"),
    ], text=True, capture_output=True, check=False)


def expect_failure(base: Path, name: str, values: list[dict[str, object]], token: str) -> None:
    directory = base / name
    write_attempts(directory, values)
    result = run(directory)
    require(result.returncode != 0, f"invalid R0 fixture passed: {name}")
    require(token in result.stderr, f"{name} did not report {token!r}: {result.stderr}")


def main() -> None:
    require(SUMMARIZER.is_file(), "missing Tools/CI/summarize-r0-engine-gate.py")
    require(HARNESS.is_file(), "missing Tools/CI/run-simulator-navigation.sh")
    with tempfile.TemporaryDirectory(prefix="vulpra-r0-gate-") as temporary:
        base = Path(temporary)
        test_harness(base)
        valid = [valid_attempt(index) for index in range(1, 21)]
        valid_directory = base / "valid"
        write_attempts(valid_directory, valid)
        result = run(valid_directory)
        require(result.returncode == 0, result.stderr or result.stdout)
        summary = json.loads((base / "summary.json").read_text(encoding="utf-8"))
        require(summary["r0Attempts"] == 20 and summary["r0Passed"] == 20,
                "valid R0 fixture did not produce a 20/20 summary")
        require(summary["p95LoadToCompleteMs"] == 12000 and
                summary["totalOpenLaunches"] == 0,
                "valid R0 summary lost performance or lifecycle evidence")

        expect_failure(base, "missing-attempt", valid[:-1], "exactly 1...20")
        duplicate = copy.deepcopy(valid)
        duplicate[-1]["attempt"] = 19
        expect_failure(base, "duplicate-attempt", duplicate, "exactly 1...20")

        mutations = (
            ("blank", lambda value: value.update(renderedDarkPixels=999), "visually blank"),
            ("crash", lambda value: value.update(crashCount=1), "contains a crash"),
            ("missing-duration", lambda value: value.update(loadToCompleteMs=-1), "integer >= 0"),
            ("missing-request", lambda value: value["lifecycleEvents"].pop(0), "first event is not requested"),
            ("duplicate-request", lambda value: value["lifecycleEvents"].insert(1, {
                **copy.deepcopy(value["lifecycleEvents"][0]),
                "monotonicTimestampNanoseconds": 1_001_000_000,
            }), "duplicate stage"),
            ("zero-timestamp", lambda value: value["lifecycleEvents"][0].update(monotonicTimestampNanoseconds=0), "timestamp"),
            ("regressive-timestamp", lambda value: value["lifecycleEvents"][1].update(monotonicTimestampNanoseconds=999_999_999), "regressive"),
            ("stored-mismatch", lambda value: value.update(connectedLaunchIDs=[]), "stored/derived"),
            ("open-launch", lambda value: (value.update(lifecycleEvents=value["lifecycleEvents"][:2], connectedLaunchIDs=[], openLaunchIDs=[1])), "open child launches"),
            ("both-outcomes", lambda value: value.update(failedLaunchIDs=[1]), "both outcome sets"),
        )
        for name, mutate, token in mutations:
            values = copy.deepcopy(valid)
            mutate(values[0])
            expect_failure(base, name, values, token)

        p95 = copy.deepcopy(valid)
        p95[-1]["loadToCompleteMs"] = 20000
        p95[-2]["loadToCompleteMs"] = 16000
        expect_failure(base, "p95", p95, "p95 load-to-complete")
        maximum = copy.deepcopy(valid)
        maximum[-1]["loadToCompleteMs"] = 30001
        expect_failure(base, "maximum", maximum, "maximum load-to-complete")

    print("PASS: repeated R0 Simulator engine gate contracts")


if __name__ == "__main__":
    main()
