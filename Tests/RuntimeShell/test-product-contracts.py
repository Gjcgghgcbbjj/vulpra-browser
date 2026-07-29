#!/usr/bin/env python3
"""Verify preserved product identities, metadata, and URL routing."""

from pathlib import Path
import plistlib
import re


ROOT = Path(__file__).resolve().parents[2]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def load(relative: str) -> dict:
    with (ROOT / relative).open("rb") as source:
        value = plistlib.load(source)
    require(isinstance(value, dict), f"invalid plist: {relative}")
    return value


def main() -> None:
    identities = {
        "Configuration/App.xcconfig": "com.vulpra.browser",
        "Configuration/EngineKit.xcconfig": "com.vulpra.browser.engine-kit",
        "Configuration/EngineProcess.xcconfig": "com.vulpra.browser.engine-process",
        "Configuration/OpenIn.xcconfig": "com.vulpra.browser.open-in",
    }
    for relative, bundle_id in identities.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        require(f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id}" in text, f"wrong identity in {relative}")

    app = load("App/Info.plist")
    require(app.get("CFBundleDisplayName") == "Vulpra", "wrong display name")
    require(app.get("LSRequiresIPhoneOS") is True, "app must require iPhoneOS")
    require(app.get("UIRequiredDeviceCapabilities") == ["arm64"], "app must require arm64")
    require(app.get("CFBundleURLTypes", [{}])[0].get("CFBundleURLSchemes") == ["vulpra"],
            "vulpra URL scheme is not preserved")
    scene = app.get("UIApplicationSceneManifest", {})
    require(scene.get("UIApplicationSupportsMultipleScenes") is False, "app must retain one scene")

    process = load("Engine/VulpraEngineProcess/Info.plist")
    require(process.get("CFBundleDisplayName") == "Vulpra Engine Process",
            "engine process display name is wrong")
    extension = process.get("NSExtension", {})
    require(extension.get("NSExtensionPrincipalClass") == "VulpraEngineProcessMain",
            "engine process principal class is wrong")
    require(process.get("CFBundlePackageType") == "XPC!", "engine process package type is wrong")
    require(process.get("VulpraEngineProcessProtocolVersion") == 2, "engine process protocol is wrong")

    open_in = load("Extensions/OpenIn/Info.plist")
    require(open_in.get("CFBundleDisplayName") == "Open in Vulpra",
            "OpenIn display name is wrong")

    base = (ROOT / "Configuration/Base.xcconfig").read_text(encoding="utf-8")
    require("IPHONEOS_DEPLOYMENT_TARGET = 15.0" in base, "deployment target changed")
    require("TARGETED_DEVICE_FAMILY = 1,2" in base, "device families changed")

    standard = load("App/Entitlements/Vulpra.entitlements")
    require(standard == {"com.apple.developer.kernel.increased-memory-limit": True},
            "standard app entitlements changed")
    private = load("App/Entitlements/Vulpra.private.entitlements")
    require(private.get("application-identifier") == "com.vulpra.browser", "private identity changed")
    require(private.get("platform-application") is True, "private package entitlement is missing")

    router = (ROOT / "App/RuntimeURLRouter.swift").read_text(encoding="utf-8")
    for token in ('"http"', '"https"', '"vulpra"', '"open"', 'item.name == "url"'):
        require(token in router, f"URL router is missing {token}")
    for forbidden in ("UserDefaults", "WKWebView", "fallback"):
        require(re.search(rf"\b{re.escape(forbidden)}\b", router, re.I) is None,
                f"URL router contains forbidden behavior: {forbidden}")
    scene = (ROOT / "App/SceneDelegate.swift").read_text(encoding="utf-8")
    require("#if DEBUG" in scene and 'environment["VULPRA_SMOKE_URL"]' in scene,
            "simulator navigation evidence input must remain Debug-only")
    print("PASS: preserved Vulpra product contracts")


if __name__ == "__main__":
    main()
