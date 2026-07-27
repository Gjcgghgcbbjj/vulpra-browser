#!/usr/bin/env python3
"""Portable structural checks for the independent Vulpra Xcode graph."""

from pathlib import Path
import re
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Vulpra.xcodeproj/project.pbxproj"
SCHEME = ROOT / "Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    text = PROJECT.read_text(encoding="utf-8")
    require("objectVersion = 77;" in text, "Xcode object version is wrong")
    require(text.count("isa = PBXNativeTarget;") == 5, "target set is not canonical")
    require("PBXFileSystemSynchronizedRootGroup" in text, "missing synchronized source groups")
    require(len(text.splitlines()) < 800, "project file exceeds line budget")

    expected = {
        "Vulpra": "com.apple.product-type.application",
        "OpenIn": "com.apple.product-type.app-extension",
        "VulpraEngineKit": "com.apple.product-type.framework",
        "Vulpra Engine Process": "com.apple.product-type.app-extension",
        "VulpraEngineKitTests": "com.apple.product-type.bundle.unit-test",
    }
    for name, product_type in expected.items():
        pattern = rf"/\* {re.escape(name)} \*/ = \{{isa = PBXNativeTarget;.*?productType = \"{re.escape(product_type)}\";"
        require(re.search(pattern, text, re.S) is not None, f"missing or invalid target: {name}")

    for token in (
        "VulpraEngineKit.framework in Embed Frameworks",
        "Vulpra Engine Process.appex in Embed App Extensions",
        "OpenIn.appex in Embed App Extensions",
        "Verify Engine Artifact",
        "Stage Engine Runtime",
        "path = App;",
        "path = Engine/VulpraEngineKit;",
        "path = Engine/VulpraEngineProcess;",
        "path = Extensions/OpenIn;",
    ):
        require(token in text, f"missing graph contract: {token}")

    for token in (
        "GeckoView.framework",
        "Vulpra Helper",
        "Extensions/GeckoView",
        "Extensions/Helper",
        "Modules/VulpraRuntime",
        "Vendor/firefox",
        "idevice",
    ):
        require(token not in text, f"retired graph token remains: {token}")

    for name in ("Base", "App", "OpenIn", "EngineKit", "EngineProcess"):
        config = ROOT / f"Configuration/{name}.xcconfig"
        require(config.is_file(), f"missing {config.relative_to(ROOT)}")
        require(f"path = Configuration/{name}.xcconfig;" in text, f"config is absent from graph: {name}")
    for name in ("GeckoView", "Helper"):
        require(not (ROOT / f"Configuration/{name}.xcconfig").exists(), f"retired config remains: {name}")

    base = (ROOT / "Configuration/Base.xcconfig").read_text(encoding="utf-8")
    for setting in (
        "IPHONEOS_DEPLOYMENT_TARGET = 15.0",
        "ARCHS = arm64",
        "TARGETED_DEVICE_FAMILY = 1,2",
        "VULPRA_ENGINE_ROOT = $(SRCROOT)/.build/engine",
        "VULPRA_ENGINE_CONTRACT[sdk=iphonesimulator*]",
    ):
        require(setting in base, f"base build contract is missing: {setting}")
    combined = text + "\n" + "\n".join(
        path.read_text(encoding="utf-8") for path in (ROOT / "Configuration").glob("*.xcconfig")
    )
    for setting in ("DEVELOPMENT_TEAM", "PROVISIONING_PROFILE", "PROVISIONING_PROFILE_SPECIFIER"):
        require(setting not in combined, f"hard-coded signing setting remains: {setting}")

    ET.parse(SCHEME)
    scheme = SCHEME.read_text(encoding="utf-8")
    for target in expected:
        require(f'BlueprintName="{target}"' in scheme, f"scheme is missing {target}")
    require("GeckoView" not in scheme and "Vulpra Helper" not in scheme, "scheme retains old targets")
    print("PASS: independent Vulpra Xcode graph")


if __name__ == "__main__":
    main()
