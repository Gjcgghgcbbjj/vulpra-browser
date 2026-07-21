#!/usr/bin/env python3
"""Portable contracts for the GitHub-hosted runtime substrate producer."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/build-runtime-substrate.yml"
PRODUCER = ROOT / "Tools/Runtime/build-runtime-substrate.sh"

def require(ok: bool, message: str) -> None:
    if not ok:
        print(f"FAIL: {message}", file=sys.stderr)
        raise SystemExit(1)

def main() -> None:
    require(WORKFLOW.is_file(), "missing runtime substrate workflow")
    text = WORKFLOW.read_text()
    for token in (
        "workflow_dispatch:", "runs-on: macos-26", "timeout-minutes: 360",
        "submodules: false", "Tools/Gecko/update-gecko.sh",
        "mach --no-interactive bootstrap", "Tools/Runtime/build-runtime-substrate.sh",
        "gecko-artifact.sh restore", "verify-runtime-artifacts.sh",
        "libidevice_ffi.a", "actions/cache/restore@v4", "actions/cache/save@v4",
        "actions/upload-artifact@v4", "retention-days: 90", "SHA256SUMS",
    ):
        require(token in text, f"workflow missing {token}")
    require("fetch-depth: 0" not in text, "runtime checkout must not fetch full application history")
    require("brew update" not in text, "workflow must not spend time updating Homebrew")
    require("build-ios-packages" not in text, "runtime workflow must not package the app")
    require(re.search(r"Firefox.*idevice.*Patches", text, re.S) is not None,
            "runtime identity must cover Firefox, idevice, and patches")

    producer = PRODUCER.read_text()
    require("submodule update --init --recursive Vendor/firefox Vendor/idevice" not in producer,
            "producer still performs an unbounded recursive clone")
    require("submodule update --init --depth 1 Vendor/idevice" in producer,
            "producer must shallow-initialize idevice")
    print("PASS: GitHub runtime substrate workflow contracts")

if __name__ == "__main__":
    main()
