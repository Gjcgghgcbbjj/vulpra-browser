#!/usr/bin/env python3
from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parents[2]
ABI = ROOT / "Engine/VulpraEngineKit/Internal/ABI"
PROCESS = ROOT / "Engine/VulpraEngineProcess"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def read(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file(), f"missing {relative}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    header = read("Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.h")
    implementation = read("Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.mm")
    decoder = read("Engine/VulpraEngineProcess/EngineProcessDecoder.m")
    bootstrap = read("Engine/VulpraEngineProcess/EngineProcessBootstrap.swift")
    process_extension = read("Engine/VulpraEngineProcess/EngineProcessExtension.swift")
    session = read("Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift")
    info_path = PROCESS / "Info.plist"
    require(info_path.is_file(), "missing Engine/VulpraEngineProcess/Info.plist")

    for token in ("VEKRuntimeCreate", "VEKRuntimeMain", "VEKWindowOpen", "VEKChildProcessStart"):
        require(token in header, f"ABI header is missing {token}")
    require("#import <Foundation/Foundation.h>" in header, "ABI header must expose Foundation-owned values")

    for token in ("MainProcessInit", "ChildProcessInit", "GeckoViewOpenWindow",
                  "SwiftGeckoViewRuntime", "SwiftEventDispatcher", "Vulpra:RuntimeReady"):
        require(token in implementation, f"ABI implementation is missing verified owner token: {token}")
    require("#import \"EngineABIBridge.h\"" in implementation, "ABI implementation must include its public header")
    for header_name in ("GeckoViewSwiftSupport.h", "IOSBootstrap.h"):
        require(header_name in implementation, f"ABI implementation must include verified header: {header_name}")
    require("NS_ShutdownXPCOM" not in implementation, "unexported shutdown ABI must not be invented")
    require("XRE_ShutdownChildProcess" not in implementation, "unexported child shutdown ABI must not be invented")
    require("prepareWithError" not in implementation and "- (void)shutdown" not in implementation,
            "invented lifecycle ABI remains")
    require(implementation.count("MainProcessInit(") == 1, "MainProcessInit must have one owner")
    require(implementation.count("ChildProcessInit(") == 1, "ChildProcessInit must have one owner")
    require(implementation.count("GeckoViewOpenWindow(") == 1, "GeckoViewOpenWindow must have one owner")
    require("VEKInstallEngineProcessTransport" not in implementation,
            "retired producer-side endpoint transport remains active")
    require(not (ABI / "EngineProcessTransport.h").exists(),
            "retired producer-side transport header remains")
    require(not (ABI / "EngineProcessTransport.mm").exists(),
            "retired producer-side transport implementation remains")
    for token in ("NSClassFromString(@\"NSXPCDecoder\")", "method_setImplementation",
                  "decodeObjectOfClasses:forKey:", "NSExtensionItem.class",
                  "NSXPCListenerEndpoint.class"):
        require(token in decoder, f"engine process decoder is missing {token}")
    require("NSKeyedArchiver" not in decoder and "NSData" not in decoder,
            "engine process decoder contains an impossible endpoint archive path")
    require('"VulpraXPCListenerEndpoint"] as? NSXPCListenerEndpoint' in process_extension,
            "process extension does not require the native XPC endpoint")
    require("NSKeyedUnarchiver" not in process_extension and
            '"VulpraXPCListenerEndpoint"] as? Data' not in process_extension,
            "retired normalized-data endpoint path remains in the process extension")
    require("Vulpra Engine Process connected" in process_extension,
            "process host lacks runtime connection evidence")
    require("struct EngineInitialNavigationGate" in session and
            "initialNavigationGate.stage(request)" in session and
            "initialNavigationGate.becomeReady()" in session and
            "dispatchLoad(request, reassertActivity: true)" in session and
            "private var requestedActive: Bool?" in session and
            "private var requestedFocused: Bool?" in session,
            "EngineKit does not stage cold-start navigation until initial document readiness")

    for root in (ROOT / "App", ROOT / "Engine/VulpraEngineKit/Public"):
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            require("runtime/include" not in text, f"artifact header path leaked outside Internal/ABI: {path}")
            require("OpaquePointer" not in text and "UnsafePointer" not in text, f"opaque pointer leaked outside Internal/ABI: {path}")

    required_bootstrap = (
        "public enum EngineProcessRole",
        "case content",
        "case graphics",
        "case network",
        "case utility",
        "public struct EngineProcessBootstrap",
        "public let endpointToken: String",
        "public let parentProcessIdentifier: Int32",
        "public init(arguments: [String]) throws",
        "--vulpra-process-role=",
        "--vulpra-endpoint-token=",
        "--vulpra-parent-pid=",
    )
    for token in required_bootstrap:
        require(token in bootstrap, f"process bootstrap is missing {token}")
    for token in ("Browser", "Tab", "Bookmark", "History", "Download", "Gecko", "NSXPCListenerEndpoint"):
        require(token not in bootstrap, f"process bootstrap owns forbidden product/external state: {token}")
    require(len(bootstrap.splitlines()) < 180, "process bootstrap exceeds 180-line budget")

    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    require(info.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)", "process bundle identity must be build-owned")
    require(info.get("CFBundleExecutable") == "$(EXECUTABLE_NAME)", "process executable metadata is missing")
    require(info.get("CFBundlePackageType") == "XPC!", "process package type must be XPC!")
    require(info.get("VulpraEngineProcessProtocolVersion") == 1, "process protocol version must be 1")
    service = info.get("XPCService")
    require(isinstance(service, dict) and service.get("ServiceType") == "Application", "process XPC service metadata is missing")
    extension = info.get("NSExtension")
    require(isinstance(extension, dict), "process NSExtension metadata is missing")
    require(extension.get("NSExtensionPrincipalClass") == "VulpraEngineProcessMain",
            "process principal class is not Vulpra-owned")
    print("PASS: independent ABI and process boundaries")


if __name__ == "__main__":
    main()
