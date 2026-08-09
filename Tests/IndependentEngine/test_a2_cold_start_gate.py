#!/usr/bin/env python3
"""Portable fixtures for the A2 cold-start gate summarizer."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SUMMARIZER = ROOT / "Tools/CI/summarize-cold-start-gate.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def valid_attempt(identifier: int) -> dict[str, object]:
    return {
        "attempt": identifier,
        "initialLoadDeferred": identifier % 2 == 0,
        "appLaunchToEngineReadyMs": 2200,
        "engineReadyToLoadRequestedMs": 700,
        "loadRequestedToLocationMs": 6800,
        "locationToPageCompleteMs": 1300,
        "firstNavigationDelayMs": 9700,
        "pageCompleteDelayMs": 11000,
        "renderedDarkPixels": 12266,
        "appSurvived": True,
        "crashCount": 0,
        "markersPresent": ["runtime-ready", "load-requested", "location", "page-complete"],
        "evidenceSource": "merged-system+stream",
        "deliveryMethod": "launch-env-url",
    }


def write_attempts(directory: Path, values: list[dict[str, object]]) -> None:
    directory.mkdir(parents=True)
    for index, value in enumerate(values, 1):
        (directory / f"attempt-{index:02d}.json").write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )


def run(directory: Path, count: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run([
        "python3", str(SUMMARIZER), "--attempts", str(count),
        "--input", str(directory), "--output", str(directory.parent / "a2-summary.json"),
    ], text=True, capture_output=True, check=False)


def expect_failure(base: Path, name: str, values: list[dict[str, object]], token: str,
                 count: int | None = None) -> None:
    directory = base / name
    write_attempts(directory, values)
    result = run(directory, len(values) if count is None else count)
    require(result.returncode != 0, f"invalid A2 fixture passed: {name}")
    require(token in result.stderr, f"{name} did not report {token!r}: {result.stderr}")


def main() -> None:
    require(SUMMARIZER.is_file(), "missing A2 cold-start summarizer")
    with tempfile.TemporaryDirectory(prefix="vulpra-a2-gate-") as temporary:
        base = Path(temporary)
        valid = [valid_attempt(index) for index in range(1, 13)]
        good = base / "good"
        write_attempts(good, valid)
        result = run(good, 12)
        require(result.returncode == 0, result.stderr or result.stdout)
        summary = json.loads((base / "a2-summary.json").read_text(encoding="utf-8"))
        require(summary["a2Passed"] == 12 and summary["a2Attempts"] == 12,
                "valid A2 fixture did not produce a 12/12 summary")
        require(summary["initialLoadDeferredCount"] == 6 and
                summary["initialLoadImmediateCount"] == 6,
                "A2 path grouping did not split deferred/immediate")
        require(summary["perPhaseP95MaxMs"]["firstNavigationDelayMs"] == [9700, 9700],
                "A2 per-phase p95/max is wrong")

        # User policy: a single fresh-launch attempt is a valid A2 gate by
        # itself (single-attempt gate first, 20x only after it passes).
        single = base / "single"
        write_attempts(single, [valid_attempt(1)])
        result = run(single, 1)
        require(result.returncode == 0, result.stderr or result.stdout)
        summary = json.loads((base / "a2-summary.json").read_text(encoding="utf-8"))
        require(summary["a2Passed"] == 1 and summary["a2Attempts"] == 1,
                "single-attempt A2 gate did not produce a 1/1 summary")
        expect_failure(base, "too-few", valid[:8], "at least 10")
        slow = copy.deepcopy(valid)
        slow[0]["firstNavigationDelayMs"] = 31_000
        expect_failure(base, "slow-first-nav", slow, "exceeds 30000 ms")
        page_slow = copy.deepcopy(valid)
        page_slow[0]["pageCompleteDelayMs"] = 46_000
        expect_failure(base, "slow-page", page_slow, "exceeds 45000 ms")
        missing = copy.deepcopy(valid)
        missing[0]["markersPresent"] = ["runtime-ready"]
        expect_failure(base, "missing-markers", missing, "missing required cold-start markers")
        crashed = copy.deepcopy(valid)
        crashed[0]["crashCount"] = 1
        expect_failure(base, "crash", crashed, "contains a crash")
        blank = copy.deepcopy(valid)
        blank[0]["renderedDarkPixels"] = 999
        expect_failure(base, "blank", blank, "visually blank")
        died = copy.deepcopy(valid)
        died[0]["appSurvived"] = False
        expect_failure(base, "died", died, "app did not survive cold start")
        wrong_delivery = copy.deepcopy(valid)
        wrong_delivery[0]["deliveryMethod"] = "simctl-openurl"
        expect_failure(base, "wrong-delivery", wrong_delivery, "deliveryMethod must be launch-env-url")
    print("PASS: A2 cold-start gate summarizer contracts")
    return None


if __name__ == "__main__":
    raise SystemExit(main())
