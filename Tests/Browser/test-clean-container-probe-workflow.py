#!/usr/bin/env python3
"""Contracts for the known-working fresh-container device probe."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "clean-container-probe.yml"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL: {message}", file=sys.stderr)
        raise SystemExit(1)


def main() -> None:
    require(WORKFLOW.is_file(), "missing fresh-container probe workflow")
    text = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "runs-on: macos-26",
        "29946679556",
        "e134fb36fb07ce93738a9c1bee8da12baf522e985d37e131e92a629eeb146c1b",
        "com.vulpra.browser.cleanprobe",
        "com.vulpra.browser.cleanprobe.helper",
        "com.vulpra.browser.cleanprobe.open-in",
        "ldid -e",
        "ldid -S",
        "Vulpra-Clean-Container-Probe.tipa",
        "actions/upload-artifact@v4",
    ):
        require(token in text, f"clean-container workflow missing {token}")
    for forbidden in (
        "xcodebuild",
        "build-app.sh",
        "build-gecko.sh",
        "build-runtime-substrate.sh",
    ):
        require(forbidden not in text, f"clean-container probe rebuilds code: {forbidden}")
    print("PASS: known-working fresh-container probe workflow contract")


if __name__ == "__main__":
    main()
