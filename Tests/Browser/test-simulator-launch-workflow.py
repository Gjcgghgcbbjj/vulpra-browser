#!/usr/bin/env python3
"""Contracts for the real Vulpra iOS Simulator launch diagnostic."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "simulator-launch.yml"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL: {message}", file=sys.stderr)
        raise SystemExit(1)


def main() -> None:
    require(WORKFLOW.is_file(), "missing real simulator launch workflow")
    text = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "runs-on: macos-26",
        "vulpra-gecko-simulator-",
        "build-idevice.sh aarch64-apple-ios-sim",
        "generic/platform=iOS Simulator",
        "xcrun simctl create",
        "xcrun simctl bootstatus",
        "xcrun simctl install",
        "xcrun simctl launch",
        "xcrun simctl terminate",
        "simulator-system.log",
        "simulator-launch.png",
        "actions/upload-artifact@v4",
    ):
        require(token in text, f"simulator launch workflow missing {token}")
    for forbidden in (
        "Vulpra Simulator Shell",
        "VulpraSimulator.swift",
        "Tools/Runtime/build-gecko-simulator.sh",
        "./mach build",
    ):
        require(forbidden not in text, f"simulator workflow contains fake/rebuild path: {forbidden}")
    print("PASS: real iOS Simulator launch workflow contract")


if __name__ == "__main__":
    main()
