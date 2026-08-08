#!/usr/bin/env python3
"""Fast single-attempt gate for the repeated Simulator navigation workflow.

The repeated R0 Simulator gate must not spend 20 attempts discovering a
systemic harness, lifecycle, or navigation failure.  This checker validates
the first attempt's evidence with the same per-attempt rules as the R0
summarizer, so a broken gate fails in minutes instead of after all attempts.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


class GateError(ValueError):
    pass


def fail(message: str) -> None:
    raise GateError(message)


def boolean(value: object, label: str) -> bool:
    if type(value) is not bool:
        fail(f"{label} must be a Boolean")
    return value


def integer(value: object, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        fail(f"{label} must be an integer >= {minimum}")
    return value


def id_array(value: object, label: str) -> list[int]:
    if not isinstance(value, list):
        fail(f"{label} must be an array")
    return [integer(item, label, 1) for item in value]


def check(attempt_path: Path) -> None:
    try:
        attempt = json.loads(attempt_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read single-attempt evidence: {error}")
    if not isinstance(attempt, dict):
        fail("single-attempt evidence must be an object")
    if integer(attempt.get("attempt"), "attempt", 1) != 1:
        fail("single-attempt evidence must be attempt 1")
    for key in ("locationMatched", "pageCompleted", "appSurvived"):
        if not boolean(attempt.get(key), f"attempt {key}"):
            fail(f"attempt 1 {key} is false")
    if integer(attempt.get("renderedDarkPixels"), "attempt renderedDarkPixels") < 1000:
        fail("attempt 1 screenshot is visually blank")
    duration = integer(attempt.get("loadToCompleteMs"), "attempt loadToCompleteMs")
    if duration > 30000:
        fail(f"attempt 1 load-to-complete exceeds 30000 ms: {duration}")
    if integer(attempt.get("crashCount"), "attempt crashCount") != 0:
        fail("attempt 1 contains a crash")
    if integer(attempt.get("gateDispatchStatus"), "attempt gateDispatchStatus", -1) != 0:
        fail(
            "attempt 1 gate dispatch did not succeed: "
            f"status {attempt.get('gateDispatchStatus')}"
        )
    for key in ("openLaunchIDs", "failedLaunchIDs"):
        if id_array(attempt.get(key), f"attempt {key}"):
            fail(f"attempt 1 leaves unresolved launches: {key} is non-empty")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the first Simulator navigation attempt before the 20x loop.",
    )
    parser.add_argument(
        "--input", required=True, type=Path,
        help="attempt-01.json written by run-simulator-navigation.sh",
    )
    args = parser.parse_args()
    try:
        check(args.input)
    except (OSError, GateError) as error:
        print(f"single-attempt-gate-error: {error}", file=sys.stderr)
        return 1
    print("PASS: single-attempt navigation gate (attempt 1)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
