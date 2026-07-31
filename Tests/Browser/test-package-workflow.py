#!/usr/bin/env python3
"""Verify the precompiled native Gecko v5 package workflow contract."""

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
        "vulpra-engine-v5-r0.3-candidate",
        "verify-engine-artifact.py",
        "engine-artifact-device-v5.json",
        "ENGINE_ABI_VERSION",
        "ENGINE_PRODUCER_RUN_ID",
        "ENGINE_PATCH_SET_SHA256",
        "ENGINE_CONFIGURATION_SHA256",
        "ENGINE_COMPILED_BY_RUN_ID",
        "ENGINE_COMPILED_BY_HEAD_SHA",
        "ENGINE_BUILD_FINGERPRINT",
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
        "engine-artifact-v4.json",
        "vulpra-engine-v4-candidate",
        "produce-simulator-artifact",
        "apple-vtool-set-build-version-iossim-15",
    ):
        require(forbidden not in text, f"package workflow retains {forbidden}")
    print("PASS: independent iOS package workflow")


if __name__ == "__main__":
    main()
