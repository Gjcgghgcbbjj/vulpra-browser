#!/usr/bin/env python3
"""Portable fixtures and source-wiring checks for the Simulator scroll gate.

Verifies that the scroll-performance gate is wired end to end:
1. ScrollFrameSampler (CADisplayLink frame sampling with p95/max/hitch/stall)
   and ScrollPerformanceScenario (auto-scroll scenario) exist in DEBUG builds.
2. GateDispatchServer routes the "scroll-performance" scenario and
   SceneDelegate wires it into the browser.
3. summarize-scroll-gate.py accepts a valid single attempt and a valid 10+
   attempt repeated gate, and rejects every measured failure class.
"""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SUMMARIZER = ROOT / "Tools/CI/summarize-scroll-gate.py"
GATE_DIR = ROOT / "App" / "Gate"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def valid_attempt(identifier: int) -> dict[str, object]:
    return {
        "attempt": identifier,
        "url": "http://127.0.0.1:8765/",
        "scrollSeconds": 12,
        "scenarioStatus": "completed",
        "sampledFrames": 720,
        "p95FrameIntervalMs": 16.7,
        "maxFrameIntervalMs": 33.3,
        "hitchCount": 3,
        "stallCount": 0,
        "displayRefreshHz": 60,
        "renderedDarkPixels": 12266,
        "appSurvived": True,
        "crashCount": 0,
        "launchStatus": 0,
        "launchAttempts": 1,
        "logShowStatus": 0,
        "logEvidenceSource": "merged-system+stream",
        "dispatchStatus": 0,
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
        "--input", str(directory), "--output", str(directory.parent / "scroll-summary.json"),
    ], text=True, capture_output=True, check=False)


def expect_failure(base: Path, name: str, values: list[dict[str, object]], token: str,
                 count: int | None = None) -> None:
    directory = base / name
    write_attempts(directory, values)
    result = run(directory, len(values) if count is None else count)
    require(result.returncode != 0, f"invalid scroll fixture passed: {name}")
    require(token in result.stderr, f"{name} did not report {token!r}: {result.stderr}")


def check_source_wiring() -> None:
    sampler = GATE_DIR / "ScrollFrameSampler.swift"
    scenario = GATE_DIR / "ScrollPerformanceScenario.swift"
    require(sampler.is_file(), "missing ScrollFrameSampler.swift")
    require(scenario.is_file(), "missing ScrollPerformanceScenario.swift")
    sampler_text = sampler.read_text(encoding="utf-8")
    scenario_text = scenario.read_text(encoding="utf-8")
    for token in (
        "CADisplayLink", "UIScreen.main.maximumFramesPerSecond",
        "p95FrameIntervalMs", "maxFrameIntervalMs", "hitchCount", "stallCount",
        "> 25", "> 100", "#if DEBUG",
    ):
        require(token in sampler_text, f"ScrollFrameSampler missing {token!r}")
    for token in (
        "runScrollPerformanceScenario", "gate_scenario=scroll-performance",
        "completed", "waitForIdleLoad", "tab.isLoading", "ScrollFrameSampler",
    ):
        require(token in scenario_text, f"ScrollPerformanceScenario missing {token!r}")
    dispatch = (ROOT / "App" / "GateDispatchServer.swift").read_text(encoding="utf-8")
    require('"scroll-performance"' in dispatch, "GateDispatchServer missing scroll-performance branch")
    require("onScrollPerformance" in dispatch, "GateDispatchServer missing onScrollPerformance")
    require("onScrollPerformance(" in dispatch, "GateDispatchServer not wired in init/body")
    scene = (ROOT / "App" / "SceneDelegate.swift").read_text(encoding="utf-8")
    require("onScrollPerformance:" in scene, "SceneDelegate missing onScrollPerformance wiring")
    require("runScrollPerformanceScenario(url:seconds:)" in scene or
            "runScrollPerformanceScenario(url: url, seconds: seconds)" in scene,
            "SceneDelegate does not route into runScrollPerformanceScenario")


def main() -> None:
    require(SUMMARIZER.is_file(), "missing scroll gate summarizer")
    check_source_wiring()
    with tempfile.TemporaryDirectory(prefix="vulpra-scroll-gate-") as temporary:
        base = Path(temporary)
        valid = [valid_attempt(index) for index in range(1, 13)]

        good = base / "good"
        write_attempts(good, valid)
        result = run(good, 12)
        require(result.returncode == 0, result.stderr or result.stdout)
        summary = json.loads((base / "scroll-summary.json").read_text(encoding="utf-8"))
        require(summary["scrollPassed"] == 12 and summary["scrollAttempts"] == 12,
                "valid scroll fixture did not produce a 12/12 summary")
        require(summary["p95FrameIntervalMs"] == 16.7 and summary["maxFrameIntervalMs"] == 33.3,
                "scroll p95/max aggregation is wrong")
        require(summary["totalSampledFrames"] == 12 * 720,
                "scroll total sampled frame count is wrong")
        require(summary["totalStalls"] == 0 and summary["totalHitches"] == 12 * 3,
                "scroll hitch/stall aggregation is wrong")
        require(summary["hitchRate"] == round(36 / (12 * 720), 6),
                "scroll hitchRate is wrong")

        # User policy: a single attempt is a valid scroll gate by itself.
        single = base / "single"
        write_attempts(single, [valid_attempt(1)])
        result = run(single, 1)
        require(result.returncode == 0, result.stderr or result.stdout)
        summary = json.loads((base / "scroll-summary.json").read_text(encoding="utf-8"))
        require(summary["scrollPassed"] == 1 and summary["scrollAttempts"] == 1,
                "single-attempt scroll gate did not produce a 1/1 summary")

        expect_failure(base, "too-few", valid[:8], "at least 10")
        slow_p95 = copy.deepcopy(valid)
        slow_p95[0]["p95FrameIntervalMs"] = 20.1
        expect_failure(base, "slow-p95", slow_p95, "exceeds 20.0 ms")
        stall = copy.deepcopy(valid)
        stall[0]["maxFrameIntervalMs"] = 100.5
        expect_failure(base, "stall", stall, "exceeds 100.0 ms")
        aborted = copy.deepcopy(valid)
        aborted[0]["scenarioStatus"] = "aborted"
        expect_failure(base, "aborted", aborted, "did not complete")
        few_frames = copy.deepcopy(valid)
        few_frames[0]["sampledFrames"] = 119
        expect_failure(base, "few-frames", few_frames, "sampled fewer than 120 frames")
        crashed = copy.deepcopy(valid)
        crashed[0]["crashCount"] = 1
        expect_failure(base, "crash", crashed, "contains a crash")
        blank = copy.deepcopy(valid)
        blank[0]["renderedDarkPixels"] = 999
        expect_failure(base, "blank", blank, "visually blank")
        died = copy.deepcopy(valid)
        died[0]["appSurvived"] = False
        expect_failure(base, "died", died, "did not survive the scroll window")
        launch_failed = copy.deepcopy(valid)
        launch_failed[0]["launchStatus"] = 1
        expect_failure(base, "launch-failed", launch_failed, "launch did not succeed")
        bad_dispatch = copy.deepcopy(valid)
        bad_dispatch[0]["dispatchStatus"] = 7
        expect_failure(base, "bad-dispatch", bad_dispatch, "dispatch did not succeed")
        wrong_url = copy.deepcopy(valid)
        wrong_url[0]["url"] = "file:///tmp/index.html"
        expect_failure(base, "wrong-url", wrong_url, "url is invalid")
    print("PASS: scroll gate summarizer contracts and wiring")
    return None


if __name__ == "__main__":
    raise SystemExit(main())
