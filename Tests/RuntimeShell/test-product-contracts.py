#!/usr/bin/env python3
"""Verify Vulpra product metadata, entitlement, and URL input contracts."""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP_INFO = ROOT / "App" / "Info.plist"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load_plist(relative: str) -> dict:
    path = ROOT / relative
    require(path.is_file(), f"missing {relative}")
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    require(isinstance(value, dict), f"{relative} is not a dictionary plist")
    return value


def read_config(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file(), f"missing {relative}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    if not APP_INFO.is_file():
        fail("missing App/Info.plist")

    identities = {
        "Configuration/App.xcconfig": "com.vulpra.browser",
        "Configuration/GeckoView.xcconfig": "com.vulpra.browser.geckoview",
        "Configuration/Helper.xcconfig": "com.vulpra.browser.helper",
        "Configuration/OpenIn.xcconfig": "com.vulpra.browser.open-in",
    }
    for config, bundle_id in identities.items():
        text = read_config(config)
        require(
            f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id}" in text,
            f"wrong bundle identifier in {config}",
        )

    info = load_plist("App/Info.plist")
    require(info.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)", "app plist bundle identifier is not build-owned")
    require(info.get("CFBundleDisplayName") == "Vulpra", "wrong app display name")
    require(info.get("CFBundlePackageType") == "APPL", "wrong app package type")
    require(info.get("LSRequiresIPhoneOS") is True, "app must require iPhoneOS")
    require(info.get("UIRequiredDeviceCapabilities") == ["arm64"], "app must require arm64")
    require(isinstance(info.get("UILaunchScreen"), dict), "UILaunchScreen dictionary is required")
    require(isinstance(info.get("NSCameraUsageDescription"), str), "camera usage description is required")
    require(isinstance(info.get("NSMicrophoneUsageDescription"), str), "microphone usage description is required")
    require(isinstance(info.get("NSLocationWhenInUseUsageDescription"), str), "location usage description is required")
    require(isinstance(info.get("NSPhotoLibraryAddUsageDescription"), str), "photo-save usage description is required")

    helper_info = load_plist("Extensions/Helper/Info.plist")
    require(
        helper_info.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "Helper plist bundle identifier is not build-owned",
    )
    require(helper_info.get("CFBundleExecutable") == "$(EXECUTABLE_NAME)", "Helper executable metadata is missing")
    require(helper_info.get("CFBundlePackageType") == "XPC!", "Helper package type is wrong")

    url_types = info.get("CFBundleURLTypes")
    require(isinstance(url_types, list) and len(url_types) == 1, "expected one URL type")
    require(url_types[0].get("CFBundleURLSchemes") == ["vulpra"], "expected only the vulpra URL scheme")

    manifest = info.get("UIApplicationSceneManifest")
    require(isinstance(manifest, dict), "scene manifest is required")
    require(manifest.get("UIApplicationSupportsMultipleScenes") is False, "runtime shell must use one scene")
    configurations = manifest.get("UISceneConfigurations", {}).get("UIWindowSceneSessionRoleApplication")
    require(isinstance(configurations, list) and len(configurations) == 1, "expected one application scene configuration")
    require(
        configurations[0].get("UISceneDelegateClassName") == "$(PRODUCT_MODULE_NAME).SceneDelegate",
        "scene delegate identity is wrong",
    )

    base = read_config("Configuration/Base.xcconfig")
    require("IPHONEOS_DEPLOYMENT_TARGET = 15.0" in base, "deployment target is not 15.0")
    require("TARGETED_DEVICE_FAMILY = 1,2" in base, "iPhone and iPad families are required")

    app_standard = load_plist("App/Entitlements/Vulpra.entitlements")
    require(
        app_standard == {"com.apple.developer.kernel.increased-memory-limit": True},
        "standard app entitlement set is not minimal",
    )

    app_private = load_plist("App/Entitlements/Vulpra.private.entitlements")
    expected_private = {
        "application-identifier": "com.vulpra.browser",
        "com.apple.developer.kernel.extended-virtual-addressing": True,
        "com.apple.developer.kernel.increased-memory-limit": True,
        "get-task-allow": True,
        "com.apple.private.memorystatus": True,
        "platform-application": True,
        "com.apple.private.persona-mgmt": True,
        "com.apple.private.security.no-sandbox": True,
        "com.apple.private.security.storage.AppDataContainers": True,
        "com.apple.private.security.storage.MobileDocuments": True,
        "com.apple.developer.web-browser": True,
        "com.apple.security.iokit-user-client-class": [
            "IOSurfaceRootUserClient",
            "AGXDeviceUserClient",
            "AGXSharedUserClient",
            "AGXCommandQueue",
            "AGXDevice",
        ],
        "com.apple.security.exception.mach-lookup.global-name": [
            "com.apple.nsurlsessiond",
            "com.apple.nsurlsessiond.NSURLSessionProxyService",
            "com.apple.nsurlstorage-cache",
        ],
    }
    require(app_private == expected_private, "private app entitlement set differs from the approved inventory")

    helper_standard = load_plist("Extensions/Helper/Entitlements/Vulpra-Helper.entitlements")
    require(helper_standard == {}, "standard Helper entitlements must be empty")
    helper_private = load_plist("Extensions/Helper/Entitlements/Vulpra-Helper.private.entitlements")
    expected_helper_private = {
        "application-identifier": "com.vulpra.browser.helper",
        "get-task-allow": True,
        "com.apple.developer.kernel.extended-virtual-addressing": True,
        "com.apple.developer.kernel.increased-memory-limit": True,
        "platform-application": True,
    }
    require(helper_private == expected_helper_private, "private Helper entitlement set differs from the proven contract")

    entitlement_files = [
        ROOT / "App/Entitlements/Vulpra.entitlements",
        ROOT / "App/Entitlements/Vulpra.private.entitlements",
        ROOT / "Extensions/Helper/Entitlements/Vulpra-Helper.entitlements",
        ROOT / "Extensions/Helper/Entitlements/Vulpra-Helper.private.entitlements",
    ]
    entitlement_text = "\n".join(path.read_text(encoding="utf-8") for path in entitlement_files)
    require("com.apple.private.security.no-sandbox" in entitlement_text, "TrollStore app entitlement is missing")

    router_path = ROOT / "App" / "RuntimeURLRouter.swift"
    require(router_path.is_file(), "missing App/RuntimeURLRouter.swift")
    router = router_path.read_text(encoding="utf-8")
    require("static func resolve(_ input: URL?) -> URL?" in router, "router signature is wrong")
    require("URLComponents(url: input" in router, "custom URL must use URLComponents")
    require("queryItems" in router and 'item.name == "url"' in router, "custom URL must extract the url item")
    for token in ('"http"', '"https"', '"vulpra"', '"open"'):
        require(token in router, f"router missing token {token}")
    for forbidden in ("UserDefaults", "WKWebView", "history", "bookmark", "migration", "fallback"):
        require(re.search(rf"\b{re.escape(forbidden)}\b", router, re.I) is None, f"router contains forbidden behavior: {forbidden}")

    startup = read_config("App/main.swift")
    require("RuntimeJITCoordinator.shared.start()" in startup, "startup does not begin JIT coordination")
    require("defer { RuntimeJITCoordinator.shared.stop() }" in startup, "startup does not stop JIT coordination")
    require("GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)" in startup, "startup does not enter Gecko")
    for forbidden in ("FileManager", "UserDefaults", "UIWindow", "VULPRA_DIAGNOSTIC", "vulpraStartupMarker"):
        require(forbidden not in startup, f"startup contains retired diagnostic path: {forbidden}")

    atomic_store = read_config("App/Persistence/AtomicJSONStore.swift")
    require("struct AtomicJSONStore<Value: Codable>" in atomic_store, "atomic JSON store must remain a value type")
    require("class AtomicJSONStore" not in atomic_store, "optimizer-sensitive reference owner returned")

    print("PASS: Vulpra product and URL contracts")


if __name__ == "__main__":
    main()
