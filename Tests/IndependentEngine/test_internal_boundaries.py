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
    request = read("Engine/VulpraEngineProcess/EngineProcessRequest.swift")
    process_host = read("Engine/VulpraEngineKit/Internal/Process/VulpraEngineProcessHost.swift")
    process_extension = read("Engine/VulpraEngineProcess/EngineProcessExtension.swift")
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
    require('"VulpraXPCListenerEndpoint"] as? NSXPCListenerEndpoint' in request,
            "typed process request does not require the native XPC endpoint")
    require("NSKeyedUnarchiver" not in process_extension and
            '"VulpraXPCListenerEndpoint"] as? Data' not in process_extension,
            "retired normalized-data endpoint path remains in the process extension")
    for token in (
        "Engine process request received launch=", "Engine process connected launch=",
        "Engine process connection released launch=", "request.launchID", "request.childID",
        "try EngineProcessRequest(userInfo: input.userInfo)", "context.cancelRequest(withError: error)",
    ):
        require(token in process_extension, f"process extension is missing correlated request handling: {token}")

    for root in (ROOT / "App", ROOT / "Engine/VulpraEngineKit/Public"):
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            require("runtime/include" not in text, f"artifact header path leaked outside Internal/ABI: {path}")
            require("OpaquePointer" not in text and "UnsafePointer" not in text, f"opaque pointer leaked outside Internal/ABI: {path}")

    required_request = (
        "struct EngineProcessRequest",
        "static let protocolVersion = 2",
        "static let maximumProcessTypeLength = 64",
        "let endpoint: NSXPCListenerEndpoint",
        "let launchID: UInt64",
        "let childID: Int32",
        "let processType: String",
        "init(userInfo: [AnyHashable: Any]?) throws",
        'userInfo["VulpraEngineProcessProtocolVersion"]',
        'userInfo["VulpraXPCListenerEndpoint"]',
        'userInfo["VulpraChildLaunchID"]',
        'userInfo["VulpraGeckoChildID"]',
        'userInfo["VulpraGeckoProcessType"]',
        "launchID > 0",
        "childIDValue > 0",
        "processType.count <= Self.maximumProcessTypeLength",
        "CFBooleanGetTypeID()",
    )
    for token in required_request:
        require(token in request, f"typed process request is missing {token}")
    require(not (PROCESS / "EngineProcessBootstrap.swift").exists(),
            "dead argument-based process bootstrap remains")
    for token in ("--vulpra-process-role", "--vulpra-endpoint-token", "--vulpra-parent-pid"):
        require(token not in request and token not in process_extension,
                f"retired process bootstrap argument remains: {token}")
    require("public static func start(connection: NSXPCConnection) throws" in process_host,
            "process host start is not throwing")
    for token in ("unavailablePrivateConnectionBridge", "missingNativeXPCHandle"):
        require(token in process_host, f"process host is missing local transport error: {token}")
    require(len(request.splitlines()) < 150, "typed process request exceeds 150-line budget")

    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    require(info.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)", "process bundle identity must be build-owned")
    require(info.get("CFBundleExecutable") == "$(EXECUTABLE_NAME)", "process executable metadata is missing")
    require(info.get("CFBundlePackageType") == "XPC!", "process package type must be XPC!")
    require(info.get("VulpraEngineProcessProtocolVersion") == 2, "process protocol version must be 2")
    service = info.get("XPCService")
    require(isinstance(service, dict) and service.get("ServiceType") == "Application", "process XPC service metadata is missing")
    extension = info.get("NSExtension")
    require(isinstance(extension, dict), "process NSExtension metadata is missing")
    require(extension.get("NSExtensionPrincipalClass") == "VulpraEngineProcessMain",
            "process principal class is not Vulpra-owned")
    print("PASS: independent ABI and process boundaries")


if __name__ == "__main__":
    main()
