#!/usr/bin/env python3
"""Check the closed internal child-process lifecycle boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LIFECYCLE = ROOT / "Engine/VulpraEngineKit/Internal/Process/EngineChildProcessLifecycle.swift"
ABI_HEADER = ROOT / "Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.h"
ABI_IMPLEMENTATION = ROOT / "Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.mm"
ABI_SWIFT = ROOT / "Engine/VulpraEngineKit/Internal/ABI/EngineABI.swift"
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"
PROCESS_REQUEST = ROOT / "Engine/VulpraEngineProcess/EngineProcessRequest.swift"
PROCESS_EXTENSION = ROOT / "Engine/VulpraEngineProcess/EngineProcessExtension.swift"
PROCESS_HOST = ROOT / "Engine/VulpraEngineKit/Internal/Process/VulpraEngineProcessHost.swift"
GECKO_HOST_PATCH = ROOT / "Engine/GeckoPatches/v5/platform/ipc/glue/GeckoChildProcessHost.cpp.patch"
GECKO_EXTENSION_PATCH = ROOT / "Engine/GeckoPatches/v5/platform/ipc/glue/NSExtensionUtils.mm.patch"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    lifecycle = LIFECYCLE.read_text(encoding="utf-8")
    header = ABI_HEADER.read_text(encoding="utf-8")
    implementation = ABI_IMPLEMENTATION.read_text(encoding="utf-8")
    swift = ABI_SWIFT.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    request = PROCESS_REQUEST.read_text(encoding="utf-8")
    process_extension = PROCESS_EXTENSION.read_text(encoding="utf-8")
    process_host = PROCESS_HOST.read_text(encoding="utf-8")
    gecko_host = GECKO_HOST_PATCH.read_text(encoding="utf-8")
    gecko_extension = GECKO_EXTENSION_PATCH.read_text(encoding="utf-8")

    for token in (
        "case requested = 1", "case extensionConnected = 2",
        "case bootstrapAcknowledged = 3", "case ipcConnected = 4",
        "case failed = 5", "case terminated = 6",
        "case terminatedBeforeOutcome = 6", "case invalidTransition = 7",
        "event.monotonicTimestampNanoseconds > record.lastTimestampNanoseconds",
        "record.outcome = .connected", "record.outcome = .failed(event.failureCode)",
        "engine-child-terminated-before-outcome", "openLaunchIDs",
    ):
        require(token in lifecycle, f"child lifecycle owner is missing {token!r}")

    for token in (
        "VulpraEngineChildProcessHandler", "uint64_t launchID", "int32_t childID",
        "uint64_t monotonicTimestampNanoseconds", "VEKRuntimeCreate",
    ):
        require(token in header, f"child lifecycle ABI is missing {token!r}")
    require("childProcessDidChangeWithLaunchID" in implementation,
            "Objective-C bridge does not conform to the Gecko lifecycle observer")
    require("childProcessHandler:nullptr" in implementation,
            "child-side runtime became a second lifecycle owner")
    require("EngineABIChildProcessHandler" in swift and
            "vulpraRuntimeChildProcessHandler" in runtime,
            "Swift ABI does not copy and route child lifecycle events")
    require("pid == 0 ? nil : pid" in runtime,
            "Swift ABI does not normalize an absent process identifier")
    require("engine-bootstrap-timeout" in runtime and "openLaunchIDs" in runtime,
            "startup watchdog does not report anonymous open launches")

    for token in (
        'forKey:@"VulpraEngineProcessProtocolVersion"',
        'forKey:@"VulpraXPCListenerEndpoint"', 'forKey:@"VulpraChildLaunchID"',
        'forKey:@"VulpraGeckoChildID"', 'forKey:@"VulpraGeckoProcessType"',
        "mHost->mLaunchID", "mHost->mChildID", "ChildProcessType()",
    ):
        require(token in gecko_extension or token in gecko_host,
                f"Gecko typed extension request is missing {token!r}")
    for token in (
        "static let protocolVersion = 2", "let launchID: UInt64", "let childID: Int32",
        "let processType: String", "let endpoint: NSXPCListenerEndpoint",
    ):
        require(token in request, f"typed extension request is missing {token!r}")
    require("try EngineProcessRequest(userInfo: input.userInfo)" in process_extension and
            "context.cancelRequest(withError: error)" in process_extension,
            "malformed typed extension requests are not cancelled")
    require("public static func start(connection: NSXPCConnection) throws" in process_host,
            "process transport start does not expose local errors")
    require("EngineProcessBootstrap" not in request and
            not (ROOT / "Engine/VulpraEngineProcess/EngineProcessBootstrap.swift").exists(),
            "dead argument-based process identity remains")

    for public_root in (ROOT / "Engine/VulpraEngineKit/Public", ROOT / "App"):
        for path in public_root.rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            require("EngineChildProcess" not in text and "processIdentifier" not in text,
                    f"private process lifecycle leaked into public source: {path}")

    print("PASS: closed internal child-process lifecycle contract")


if __name__ == "__main__":
    main()
