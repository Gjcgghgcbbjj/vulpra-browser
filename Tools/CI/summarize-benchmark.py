#!/usr/bin/env python3
"""Validate and summarize Simulator standard-benchmark gate evidence.

Runs against attempt-XX.json fixtures produced by the benchmark harness
(Tools/CI/run-simulator-benchmark.sh). Each attempt loads a pinned benchmark
runner page (Speedometer 3.1 / MotionMark 1.3.2 / JetStream 3.0 from
Configuration/benchmarks.json) and captures the reported score from the
page title ("VulpraBenchmark <id> score=<text>"), which the App logs as
"Engine title: ..." through GeckoView:PageTitleChanged.

This summarizer is the semantic gate: it requires every attempt to capture a
positive numeric score from the title, the app to survive, the launch to
succeed, and the score to come from the unified evidence log. It does NOT
impose a minimum score: Simulator runs on the interpreter-mode engine are a
comparative regression proxy for the same engine snapshot, and absolute
cross-browser comparisons belong to physical-device qualification.

Single-attempt policy matches the R0/A2/scroll gates: exactly one attempt is
a valid gate (user rule: single pass first, repeated runs only after it
passes). Any N >= 1 is accepted; identifiers must be exactly 1..N.

Portable: pure stdlib; `python3 summarize-benchmark.py --benchmark ID
--attempts N --input DIR --output FILE` exits 0 only on a full pass.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
import sys

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SCORE_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)?$")
TITLE_MARKER = "Engine title: VulpraBenchmark"

ATTEMPT_KEYS = {
    "attempt", "benchmark", "url", "completed", "scoreText", "score",
    "scoreFrom", "elapsedMs", "appSurvived", "crashCount", "launchStatus",
    "launchAttempts", "logShowStatus", "logEvidenceSource", "screenshotStatus",
}


class GateError(ValueError):
    pass


def fail(message: str) -> None:
    raise GateError(message)


def integer(value: object, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        fail(f"{label} must be an integer >= {minimum}")
    return value


def number(value: object, label: str) -> float:
    if type(value) not in (int, float):
        fail(f"{label} must be a number")
    return float(value)


def boolean(value: object, label: str) -> bool:
    if type(value) is not bool:
        fail(f"{label} must be a Boolean")
    return value


def validate_attempt(value: object, benchmark_id: str) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != ATTEMPT_KEYS:
        diff = sorted(set(value) ^ ATTEMPT_KEYS) if isinstance(value, dict) else "not an object"
        fail(f"attempt has invalid keys: {diff}")
    attempt = integer(value["attempt"], "attempt", 1)
    benchmark = value["benchmark"]
    if not isinstance(benchmark, str) or not ID_RE.match(benchmark):
        fail(f"attempt {attempt} benchmark id is invalid: {benchmark!r}")
    if benchmark != benchmark_id:
        fail(f"attempt {attempt} benchmark {benchmark!r} does not match --benchmark {benchmark_id!r}")
    url = value["url"]
    if not isinstance(url, str) or not url.startswith("http://"):
        fail(f"attempt {attempt} url is invalid")
    if not boolean(value["completed"], f"attempt {attempt} completed"):
        fail(f"attempt {attempt} benchmark did not report a score")
    score_text = value["scoreText"]
    if not isinstance(score_text, str) or not SCORE_RE.match(score_text):
        fail(f"attempt {attempt} scoreText is not a plain number: {score_text!r}")
    score = number(value["score"], f"attempt {attempt} score")
    if score <= 0:
        fail(f"attempt {attempt} score must be positive: {score}")
    score_from = value["scoreFrom"]
    if not isinstance(score_from, str) or TITLE_MARKER not in score_from:
        fail(f"attempt {attempt} scoreFrom is not an Engine title evidence line")
    if f"score={score_text}" not in score_from:
        fail(f"attempt {attempt} scoreFrom does not carry score={score_text}")
    integer(value["elapsedMs"], f"attempt {attempt} elapsedMs")
    if not boolean(value["appSurvived"], f"attempt {attempt} appSurvived"):
        fail(f"attempt {attempt} app did not survive the benchmark run")
    if integer(value["crashCount"], f"attempt {attempt} crashCount") != 0:
        fail(f"attempt {attempt} contains a crash")
    if integer(value["launchStatus"], f"attempt {attempt} launchStatus") != 0:
        fail(f"attempt {attempt} Simulator launch did not succeed")
    integer(value["launchAttempts"], f"attempt {attempt} launchAttempts", 1)
    integer(value["logShowStatus"], f"attempt {attempt} logShowStatus")
    evidence_source = value["logEvidenceSource"]
    if not isinstance(evidence_source, str) or not evidence_source:
        fail(f"attempt {attempt} logEvidenceSource is invalid")
    integer(value["screenshotStatus"], f"attempt {attempt} screenshotStatus", -1)
    return value


def load_attempts(input_directory: Path, benchmark_id: str) -> list[dict[str, object]]:
    if not input_directory.is_dir():
        fail(f"input directory does not exist: {input_directory}")
    attempts = []
    for path in sorted(input_directory.glob("*.json")):
        try:
            attempts.append(validate_attempt(json.loads(path.read_text(encoding="utf-8")), benchmark_id))
        except (OSError, json.JSONDecodeError) as error:
            fail(f"invalid attempt file {path.name}: {error}")
    return attempts


def median_of(values: list[float]) -> float:
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return float(ordered[middle])
    return float((ordered[middle - 1] + ordered[middle]) / 2)


def summarize(attempts: list[dict[str, object]], expected_count: int,
              benchmark_id: str) -> dict[str, object]:
    identifiers = [attempt["attempt"] for attempt in attempts]
    if identifiers != list(range(1, expected_count + 1)):
        fail(f"attempt identifiers must be exactly 1...{expected_count}, got {identifiers}")
    if expected_count < 1:
        fail("attempt count must be positive")
    scores = [float(attempt["score"]) for attempt in attempts]
    elapsed = [int(attempt["elapsedMs"]) for attempt in attempts]
    return {
        "schemaVersion": 1,
        "benchmark": benchmark_id,
        "benchmarkAttempts": expected_count,
        "benchmarkPassed": len(attempts),
        "completed": len(attempts),
        "scores": scores,
        "scoreMin": round(min(scores), 4),
        "scoreMedian": round(median_of(scores), 4),
        "scoreMax": round(max(scores), 4),
        "scoreMean": round(sum(scores) / len(scores), 4),
        "elapsedMsMin": min(elapsed),
        "elapsedMsMedian": round(median_of([float(value) for value in elapsed])),
        "elapsedMsMax": max(elapsed),
        "totalCrashes": sum(int(attempt["crashCount"]) for attempt in attempts),
        "minScreenshotStatus": min(int(attempt["screenshotStatus"]) for attempt in attempts),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--benchmark", required=True)
    parser.add_argument("--attempts", required=True, type=int)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not ID_RE.match(args.benchmark):
        print(f"benchmark-error: invalid benchmark id {args.benchmark!r}", file=sys.stderr)
        return 1
    try:
        if args.attempts <= 0:
            fail("attempt count must be positive")
        summary = summarize(load_attempts(args.input, args.benchmark), args.attempts, args.benchmark)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    except (OSError, GateError) as error:
        print(f"benchmark-gate-error: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS: benchmark {summary['benchmark']} {summary['benchmarkPassed']}/"
        f"{summary['benchmarkAttempts']} median={summary['scoreMedian']} "
        f"min={summary['scoreMin']} max={summary['scoreMax']} "
        f"elapsedMedianMs={summary['elapsedMsMedian']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
