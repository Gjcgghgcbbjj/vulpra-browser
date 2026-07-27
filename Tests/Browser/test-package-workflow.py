#!/usr/bin/env python3
"""Verify the precompiled-v4 package workflow contract."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/build-ios-packages.yml"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    text = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "workflow_dispatch:",
        "runs-on: macos-26",
        "engine_release_tag",
        "verify-engine-artifact.py",
        "xcodebuild -list",
        "run-portable.sh",
        "build-app.sh",
        "create-ipa.sh",
        "validate-ipa.py",
        "Vulpra.ipa",
        "Vulpra-TrollStore.tipa",
        "actions/upload-artifact@v4",
    ):
        require(token in text, f"package workflow is missing {token}")
    for forbidden in (
        "Tools/Gecko",
        "Tools/Runtime",
        "Vendor/firefox",
        "libidevice",
        "Patches/",
        "build-gecko",
        "GeckoView.framework",
        "Vulpra Helper",
    ):
        require(forbidden not in text, f"package workflow retains {forbidden}")
    print("PASS: independent iOS package workflow")


if __name__ == "__main__":
    main()
