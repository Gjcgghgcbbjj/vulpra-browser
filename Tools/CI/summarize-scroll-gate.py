#!/usr/bin/env python3
"""Validate and summarize Simulator scroll-performance gate evidence.

Runs against attempt-XX.json fixtures produced by the scroll harness
(Tools/CI/run-simulator-scroll.sh). The harness drives an in-page JS
auto-scroll fixture and samples the App main-thread frame cadence with
ScrollFrameSampler (CADisplayLink). This summarizer is the semantic gate:
it requires the scenario to complete, the app to survive, the dispatch to
succeed, a minimum number of sampled frames, and the R1 Simulator scroll
budgets from the power-browser spec §15.2:

- p95 frame interval <= 20 ms (120 Hz-class cadence; measured intervals are
  dominated by Simulator's host-driven pacing and are a comparative proxy).
- no main-thread stall > 100 ms (maxFrameIntervalMs <= 100).
- hitch (>25 ms) rate is recorded but NOT gated here: the spec leaves hitch
  rate to physical-device qualification (client spec 16), and gating the
  Simulator proxy on it would over-block first-version evidence.

Single-attempt policy matches the R0/A2 gates: exactly one attempt is a valid
gate (user rule: single pass first, 20x only after it passes); 10+ attempts
qualify as the repeated stability gate.

Portable: pure stdlib; `python3 summarize-scroll-gate.py --attempts N
--input DIR --output FILE` exits 0 only on a full pass.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys


# R1 Simulator scroll acceptance (power-browser spec §15.2).
P95_FRAME_BUDGET_MS = 20.0
MAX_STALL_BUDGET_MS = 100.0
MIN_SAMPLED_FRAMES = 120
MIN_RENDERED_DARK_PIXELS = 1000
HITCH_THRESHOLD_MS = 25.0

ATTEMPT_KEYS = {
    "attempt", "url", "scrollSeconds", "scenarioStatus", "sampledFrames",
    "p95FrameIntervalMs", "maxFrameIntervalMs", "hitchCount", "stallCount",
    "displayRefreshHz", "renderedDarkPixels", "appSurvived", "crashCount",
    "launchStatus", "launchAttempts", "logShowStatus", "logEvidenceSource",
    "dispatchStatus",
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


def validate_attempt(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != ATTEMPT_KEYS:
        fail(f"attempt has invalid keys: {sorted(set(value) ^ ATTEMPT_KEYS) if isinstance(value, dict) else 'not an object'}")
    attempt = integer(value["attempt"], "attempt", 1)
    url = value["url"]
    if not isinstance(url, str) or not url.startswith("http://"):
        fail(f"attempt {attempt} url is invalid")
    integer(value["scrollSeconds"], f"attempt {attempt} scrollSeconds", 1)
    status = value["scenarioStatus"]
    if not isinstance(status, str) or status != "completed":
        fail(f"attempt {attempt} scroll scenario did not complete: {status}")
    sampled = integer(value["sampledFrames"], f"attempt {attempt} sampledFrames")
    if sampled < MIN_SAMPLED_FRAMES:
        fail(f"attempt {attempt} sampled fewer than {MIN_SAMPLED_FRAMES} frames: {sampled}")
    p95 = number(value["p95FrameIntervalMs"], f"attempt {attempt} p95FrameIntervalMs")
    if p95 < 0:
        fail(f"attempt {attempt} p95FrameIntervalMs is negative")
    if p95 > P95_FRAME_BUDGET_MS:
        fail(f"attempt {attempt} p95 frame interval exceeds {P95_FRAME_BUDGET_MS} ms: {p95}")
    maximum = number(value["maxFrameIntervalMs"], f"attempt {attempt} maxFrameIntervalMs")
    if maximum < 0:
        fail(f"attempt {attempt} maxFrameIntervalMs is negative")
    if maximum > MAX_STALL_BUDGET_MS:
        fail(f"attempt {attempt} max frame interval exceeds {MAX_STALL_BUDGET_MS} ms: {maximum}")
    integer(value["hitchCount"], f"attempt {attempt} hitchCount")
    integer(value["stallCount"], f"attempt {attempt} stallCount")
    integer(value["displayRefreshHz"], f"attempt {attempt} displayRefreshHz", 1)
    if integer(value["renderedDarkPixels"], f"attempt {attempt} renderedDarkPixels") < MIN_RENDERED_DARK_PIXELS:
        fail(f"attempt {attempt} screenshot is visually blank")
    if not boolean(value["appSurvived"], f"attempt {attempt} appSurvived"):
        fail(f"attempt {attempt} app did not survive the scroll window")
    if integer(value["crashCount"], f"attempt {attempt} crashCount") != 0:
        fail(f"attempt {attempt} contains a crash")
    if integer(value["launchStatus"], f"attempt {attempt} launchStatus") != 0:
        fail(f"attempt {attempt} Simulator launch did not succeed")
    integer(value["launchAttempts"], f"attempt {attempt} launchAttempts", 1)
    integer(value["logShowStatus"], f"attempt {attempt} logShowStatus")
    evidence_source = value["logEvidenceSource"]
    if not isinstance(evidence_source, str) or not evidence_source:
        fail(f"attempt {attempt} logEvidenceSource is invalid")
    if integer(value["dispatchStatus"], f"attempt {attempt} dispatchStatus", -1) != 0:
        fail(f"attempt {attempt} scroll gate dispatch did not succeed")
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


def p95_of(values: list[float]) -> float:
    ordered = sorted(values)
    return float(ordered[math.ceil(len(ordered) * 0.95) - 1])


def summarize(attempts: list[dict[str, object]], expected_count: int) -> dict[str, object]:
    identifiers = [attempt["attempt"] for attempt in attempts]
    if identifiers != list(range(1, expected_count + 1)):
        fail(f"attempt identifiers must be exactly 1...{expected_count}, got {identifiers}")
    if expected_count != 1 and expected_count < 10:
        fail("scroll gate requires a single attempt or at least 10 repeated attempts")
    p95_values = [float(attempt["p95FrameIntervalMs"]) for attempt in attempts]
    max_values = [float(attempt["maxFrameIntervalMs"]) for attempt in attempts]
    p95 = p95_of(p95_values)
    maximum = max(max_values)
    if p95 > P95_FRAME_BUDGET_MS:
        fail(f"scroll gate p95 exceeds {P95_FRAME_BUDGET_MS} ms: {p95}")
    if maximum > MAX_STALL_BUDGET_MS:
        fail(f"scroll gate max exceeds {MAX_STALL_BUDGET_MS} ms: {maximum}")
    total_sampled = sum(int(attempt["sampledFrames"]) for attempt in attempts)
    total_hitches = sum(int(attempt["hitchCount"]) for attempt in attempts)
    total_stalls = sum(int(attempt["stallCount"]) for attempt in attempts)
    # Hitches are recorded for the physical-device qualification trail; they do
    # not fail the Simulator proxy gate (see module docstring).
    hitch_rate = round(total_hitches / total_sampled, 6) if total_sampled else 0.0
    return {
        "schemaVersion": 1,
        "scrollAttempts": expected_count,
        "scrollPassed": len(attempts),
        "p95FrameIntervalMs": round(p95, 3),
        "maxFrameIntervalMs": round(maximum, 3),
        "totalHitches": total_hitches,
        "totalStalls": total_stalls,
        "hitchRate": hitch_rate,
        "totalSampledFrames": total_sampled,
        "minDisplayRefreshHz": min(int(attempt["displayRefreshHz"]) for attempt in attempts),
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
        print(f"scroll-gate-error: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS: scroll gate {summary['scrollPassed']}/{summary['scrollAttempts']} "
        f"p95={summary['p95FrameIntervalMs']}ms max={summary['maxFrameIntervalMs']}ms "
        f"stalls={summary['totalStalls']} hitchRate={summary['hitchRate']*100:.2f}%"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
