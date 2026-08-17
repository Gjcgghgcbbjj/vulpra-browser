#!/usr/bin/env python3
"""Verify dormant independent-engine targets are present but not active."""

from __future__ import annotations

import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Vulpra.xcodeproj/project.pbxproj"
SCHEME = ROOT / "Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> None:
    text = PROJECT.read_text(encoding="utf-8")
    require(PROJECT.is_file(), "missing Xcode project")
    for token in (
        "VulpraEngineKit", "Vulpra Engine Process", "Engine/VulpraEngineKit",
        "Engine/VulpraEngineProcess", "EngineKit.xcconfig", "EngineProcess.xcconfig",
        'com.apple.product-type.framework', 'com.apple.product-type.app-extension',
    ):
        require(token in text, f"project graph missing {token}")
    vulpra = re.search(r"AB0000000000000000000001 /\* Vulpra \*/ = \{(.*?)\n\s*\};", text, re.S)
    require(vulpra is not None, "cannot locate Vulpra target")
    vulpra_body = vulpra.group(1)
    require("VulpraEngineKit" not in vulpra_body and "Vulpra Engine Process" not in vulpra_body,
            "new targets must remain dormant and absent from Vulpra dependencies/phases")
    require("AB0000000000000000000005" in text and "AB0000000000000000000006" in text,
            "independent target IDs are missing")
    require("GeckoView.framework" not in (ROOT / "Configuration/EngineKit.xcconfig").read_text(),
            "EngineKit config must not link inherited GeckoView")
    require("PRODUCT_BUNDLE_IDENTIFIER = com.vulpra.browser.enginekit" in
            (ROOT / "Configuration/EngineKit.xcconfig").read_text(),
            "EngineKit bundle identifier is wrong")
    require("PRODUCT_BUNDLE_IDENTIFIER = com.vulpra.browser.engine-process" in
            (ROOT / "Configuration/EngineProcess.xcconfig").read_text(),
            "engine process bundle identifier is wrong")
    require("import GeckoView" not in "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "Engine").rglob("*.swift")),
            "independent EngineKit sources must not import GeckoView")
    try:
        ET.parse(SCHEME)
    except (OSError, ET.ParseError) as error:
        fail(f"invalid shared scheme: {error}")
    scheme = SCHEME.read_text(encoding="utf-8")
    for blueprint in ("AB0000000000000000000005", "AB0000000000000000000006"):
        require(blueprint in scheme, f"scheme missing dormant target {blueprint}")
    for config in ("EngineKit.xcconfig", "EngineProcess.xcconfig"):
        require((ROOT / "Configuration" / config).is_file(), f"missing {config}")
    info = plistlib.loads((ROOT / "Engine/VulpraEngineProcess/Info.plist").read_bytes())
    require(info.get("CFBundlePackageType") == "XPC!", "process plist package type is wrong")
    print("PASS: dormant independent-engine Xcode staging")


if __name__ == "__main__":
    main()
