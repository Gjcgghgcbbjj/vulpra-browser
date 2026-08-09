#!/usr/bin/env python3
"""DRAFT: validate and summarize repeated A2 cold-start Simulator evidence.

Post-cutover cycle draft (NOT committed, NOT wired into CI). Runs against
attempt-XX.json fixtures produced by the A2 cold-start harness (draft:
run-simulator-cold-start.sh). Enforces the phase budgets from the A2 design
doc: firstNavigationDelayMs <= 30000, pageCompleteDelayMs <= 45000, all four
markers present, app alive, 0 crashes, non-blank render, and reports p95/max
per phase grouped by the initial_load_deferred path (A2 annex 21: Path A
immediate vs Path B deferred have two timing baselines).

Portable: pure stdlib; `python3 summarize-cold-start-gate.py --attempts N
--input DIR --output FILE` exits 0 only on a full pass.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys


REQUIRED_MARKERS = ("runtime-ready", "load-requested", "location", "page-complete")
PHASES = (
    "appLaunchToEngineReadyMs",
    "engineReadyToLoadRequestedMs",
    "loadRequestedToLocationMs",
    "locationToPageCompleteMs",
    "firstNavigationDelayMs",
    "pageCompleteDelayMs",
)
PHASE_BOUNDS_MS = {
    "appLaunchToEngineReadyMs": 30_000,
    "engineReadyToLoadRequestedMs": 10_000,
    "loadRequestedToLocationMs": 25_000,
    "locationToPageCompleteMs": 20_000,
    "firstNavigationDelayMs": 30_000,
    "pageCompleteDelayMs": 45_000,
}


class GateError(ValueError):
    pass


def fail(message: str) -> None:
    raise GateError(message)


def integer(value: object, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        fail(f"{label} must be an integer >= {minimum}")
    return value


def boolean(value: object, label: str) -> bool:
    if type(value) is not bool:
        fail(f"{label} must be a Boolean")
    return value


def validate_attempt(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        fail("attempt is not an object")
    required_keys = {
        "attempt", "initialLoadDeferred", *PHASES, "renderedDarkPixels",
        "appSurvived", "crashCount", "markersPresent", "evidenceSource",
        "deliveryMethod",
    }
    if set(value) != required_keys:
        fail(f"attempt has invalid keys: {sorted(set(value) ^ required_keys)}")
    attempt = integer(value["attempt"], "attempt", 1)
    if type(value["initialLoadDeferred"]) is not bool:
        fail(f"attempt {attempt} initialLoadDeferred must be a Boolean")
    for phase in PHASES:
        duration = integer(value[phase], f"attempt {attempt} {phase}")
        bound = PHASE_BOUNDS_MS[phase]
        if duration > bound:
            fail(f"attempt {attempt} {phase} exceeds {bound} ms: {duration}")
    markers = value["markersPresent"]
    if not isinstance(markers, list) or sorted(markers) != sorted(REQUIRED_MARKERS):
        fail(f"attempt {attempt} missing required cold-start markers")
    if not boolean(value["appSurvived"], f"attempt {attempt} appSurvived"):
        fail(f"attempt {attempt} app did not survive cold start")
    if integer(value["crashCount"], f"attempt {attempt} crashCount") != 0:
        fail(f"attempt {attempt} contains a crash")
    if integer(value["renderedDarkPixels"], f"attempt {attempt} renderedDarkPixels") < 1000:
        fail(f"attempt {attempt} screenshot is visually blank")
    delivery = value["deliveryMethod"]
    if not isinstance(delivery, str) or delivery != "launch-env-url":
        fail(f"attempt {attempt} deliveryMethod must be launch-env-url")
    if not isinstance(value["evidenceSource"], str) or not value["evidenceSource"]:
        fail(f"attempt {attempt} evidenceSource is invalid")
    return value


def load_attempts(input_directory: Path) -> list[dict[str, object]]:
    if not input_directory.is_dir():
        fail(f"input directory does not exist: {input_directory}")
    attempts = []
    for path in sorted(input_directory.glob("*.json")):
        try:
            attempts.append(validate_attempt(json.loads(path.read_text(encoding="utf-8"))))
        except (OSError, json.JSONDecodeError) as error:
            fail(f"invalid attempt file {path.name}: {error}")
    return attempts


def summarize(attempts: list[dict[str, object]], expected_count: int) -> dict[str, object]:
    identifiers = [attempt["attempt"] for attempt in attempts]
    if identifiers != list(range(1, expected_count + 1)):
        fail(f"attempt identifiers must be exactly 1...{expected_count}, got {identifiers}")
    if expected_count != 1 and expected_count < 10:
        fail("A2 cold-start gate requires a single attempt or at least 10 fresh-launch attempts")
    per_phase: dict[str, list[int]] = {phase: [] for phase in PHASES}
    deferred_paths: dict[bool, list[int]] = {True: [], False: []}
    for attempt in attempts:
        for phase in PHASES:
            per_phase[phase].append(int(attempt[phase]))
        deferred_paths[bool(attempt["initialLoadDeferred"])].append(int(attempt["firstNavigationDelayMs"]))

    def p95_max(values: list[int]) -> tuple[int, int]:
        ordered = sorted(values)
        p95 = ordered[math.ceil(len(ordered) * 0.95) - 1]
        return p95, ordered[-1]

    return {
        "schemaVersion": 1,
        "a2Attempts": expected_count,
        "a2Passed": len(attempts),
        "initialLoadDeferredCount": sum(1 for a in attempts if a["initialLoadDeferred"]),
        "initialLoadImmediateCount": sum(1 for a in attempts if not a["initialLoadDeferred"]),
        "perPhaseP95MaxMs": {phase: p95_max(per_phase[phase]) for phase in PHASES},
        "firstNavigationDelayByPathMs": {
            "deferred": p95_max(deferred_paths[True]) if deferred_paths[True] else None,
            "immediate": p95_max(deferred_paths[False]) if deferred_paths[False] else None,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--attempts", required=True, type=int)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.attempts <= 0:
            fail("attempt count must be positive")
        summary = summarize(load_attempts(args.input), args.attempts)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    except (OSError, GateError) as error:
        print(f"a2-cold-start-gate-error: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS: A2 cold-start gate {summary['a2Passed']}/{summary['a2Attempts']} "
        f"firstNavP95={summary['perPhaseP95MaxMs']['firstNavigationDelayMs'][0]}ms "
        f"max={summary['perPhaseP95MaxMs']['firstNavigationDelayMs'][1]}ms"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
