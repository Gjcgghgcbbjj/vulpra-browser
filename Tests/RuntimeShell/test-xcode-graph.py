#!/usr/bin/env python3
"""Portable structural checks for the hand-authored Vulpra Xcode graph."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Vulpra.xcodeproj" / "project.pbxproj"
SCHEME = ROOT / "Vulpra.xcodeproj" / "xcshareddata" / "xcschemes" / "Vulpra.xcscheme"
CONFIGURATION = ROOT / "Configuration"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def balanced_openstep(text: str) -> bool:
    stripped = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', stripped)
    stack: list[str] = []
    pairs = {"}": "{", ")": "("}
    for character in stripped:
        if character in "{(":
            stack.append(character)
        elif character in pairs:
            if not stack or stack.pop() != pairs[character]:
                return False
    return not stack


def target_blocks(text: str) -> dict[str, str]:
    blocks: dict[str, str] = {}
    pattern = re.compile(
        r"[A-F0-9]{24} /\* (?P<comment>[^*]+) \*/ = \{\s*"
        r"isa = PBXNativeTarget;(?P<body>.*?)\n\s*\};",
        re.S,
    )
    for match in pattern.finditer(text):
        body = match.group("body")
        name_match = re.search(r"\bname = (?P<name>\"[^\"]+\"|[^;]+);", body)
        if name_match:
            blocks[name_match.group("name").strip('"')] = body
    return blocks


def main() -> None:
    if not PROJECT.is_file():
        fail("missing Vulpra.xcodeproj/project.pbxproj")

    text = PROJECT.read_text(encoding="utf-8")
    lines = text.splitlines()
    require(len(lines) < 800, f"project.pbxproj has {len(lines)} lines; budget is < 800")
    require(balanced_openstep(text), "unbalanced OpenStep braces or parentheses")
    require("objectVersion = 77;" in text, "objectVersion must be 77")
    object_ids = re.findall(r"^\s*([A-F0-9]+)(?: /\*.*?\*/)? =", text, re.M)
    require(object_ids, "project contains no object IDs")
    require(all(len(identifier) == 24 for identifier in object_ids), "project object IDs must be 24 characters")
    require("PBXFileSystemSynchronizedRootGroup" in text, "missing synchronized source groups")
    require("PBXFileSystemSynchronizedBuildFileExceptionSet" in text, "missing membership exceptions")

    targets = target_blocks(text)
    expected = {
        "Vulpra": "com.apple.product-type.application",
        "GeckoView": "com.apple.product-type.framework",
        "Vulpra Helper": "com.apple.product-type.app-extension",
        "OpenIn": "com.apple.product-type.app-extension",
    }
    require(set(targets) == set(expected), f"unexpected targets: {sorted(targets)}")
    for name, product_type in expected.items():
        require(
            f"productType = \"{product_type}\";" in targets[name],
            f"{name} has wrong product type",
        )

    app = targets["Vulpra"]
    dependency_list = re.search(r"dependencies = \((?P<body>.*?)\);", app, re.S)
    require(dependency_list is not None, "Vulpra dependency list is missing")
    require(
        len(re.findall(r"[A-F0-9]{24}", dependency_list.group("body"))) == 3,
        "Vulpra must have exactly three target dependencies",
    )
    for dependency in ("GeckoView", "Vulpra Helper", "OpenIn"):
        quoted = f'name = "{dependency}";'
        unquoted = f"name = {dependency};"
        require(
            quoted in text or unquoted in text,
            f"missing {dependency} dependency",
        )

    required_tokens = (
        "Embed Frameworks",
        "Embed App Extensions",
        "GeckoView.framework in Embed Frameworks",
        "Vulpra Helper.appex in Embed App Extensions",
        "OpenIn.appex in Embed App Extensions",
        "Verify Runtime Artifacts",
        "Copy Gecko Payload",
        "path = App;",
        "path = Modules;",
        "path = Extensions/GeckoView;",
        "path = Extensions/Helper;",
        "path = Extensions/OpenIn;",
        "publicHeaders = (ExtensionBridge.h, );",
    )
    for token in required_tokens:
        require(token in text, f"missing graph contract: {token}")

    phase_order = [
        "Verify Runtime Artifacts",
        "Sources",
        "Frameworks",
        "Resources",
        "Embed Frameworks",
        "Embed App Extensions",
        "Copy Gecko Payload",
    ]
    positions = [app.find(f"/* {phase} */") for phase in phase_order]
    require(all(position >= 0 for position in positions), "Vulpra build phase list is incomplete")
    require(positions == sorted(positions), "Vulpra build phases are in the wrong order")

    configs = ("Base", "App", "GeckoView", "Helper", "OpenIn")
    config_text: dict[str, str] = {}
    for config in configs:
        require(
            f"path = Configuration/{config}.xcconfig;" in text,
            f"missing {config}.xcconfig reference",
        )
        path = CONFIGURATION / f"{config}.xcconfig"
        require(path.is_file(), f"missing {path.relative_to(ROOT)}")
        require(sum(1 for _ in path.open(encoding="utf-8")) < 100, f"{path.name} exceeds 100-line budget")
        config_text[config] = path.read_text(encoding="utf-8")

    base = config_text["Base"]
    for setting in (
        "IPHONEOS_DEPLOYMENT_TARGET = 15.0",
        "ARCHS = arm64",
        "TARGETED_DEVICE_FAMILY = 1,2",
        "SUPPORTS_MACCATALYST = NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO",
        "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO",
        "Vendor/firefox/obj-aarch64-apple-ios/dist",
        ".build/idevice/aarch64-apple-ios/release/libidevice_ffi.a",
    ):
        require(setting in base, f"Base.xcconfig missing: {setting}")
    app_config = config_text["App"]
    require("$(VULPRA_GECKO_DIST)/bin/XUL" in app_config, "app does not link Gecko XUL")
    require("$(VULPRA_IDEVICE_ARCHIVE)" in app_config, "app does not link idevice archive")
    require(
        "SWIFT_OBJC_BRIDGING_HEADER" not in config_text["GeckoView"],
        "framework target must expose Objective-C through its module, not a bridging header",
    )
    require(
        "SWIFT_OBJC_BRIDGING_HEADER" not in config_text["Helper"],
        "helper must consume the GeckoView module instead of the app bridging header",
    )

    require("Reynard" not in text, "old product identity found in project")
    all_settings = text + "\n" + "\n".join(config_text.values())
    forbidden_settings = ("DEVELOPMENT_TEAM", "PROVISIONING_PROFILE", "PROVISIONING_PROFILE_SPECIFIER")
    for setting in forbidden_settings:
        require(setting not in all_settings, f"hard-coded signing setting found: {setting}")

    for forbidden_root in ("Client", "BrowserCore", "StabilityCore", "Resources", "dist", ".build"):
        require(f"path = {forbidden_root};" not in text, f"forbidden synchronized root: {forbidden_root}")

    require(SCHEME.is_file(), "missing shared Vulpra scheme")
    require(
        list(SCHEME.parent.glob("*.xcscheme")) == [SCHEME],
        "expected exactly one shared scheme",
    )
    scheme = SCHEME.read_text(encoding="utf-8")
    require(scheme.count('BlueprintName="Vulpra"') >= 2, "scheme must build and archive Vulpra")
    for dependency in ("GeckoView", "Vulpra Helper", "OpenIn"):
        require(f'BlueprintName="{dependency}"' in scheme, f"scheme missing {dependency}")

    print("PASS: fresh Vulpra Xcode graph contract")


if __name__ == "__main__":
    main()
