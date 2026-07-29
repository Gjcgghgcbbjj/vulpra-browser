#!/usr/bin/env python3
"""Check the closed internal child-process lifecycle boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LIFECYCLE = ROOT / "Engine/VulpraEngineKit/Internal/Process/EngineChildProcessLifecycle.swift"
ABI_HEADER = ROOT / "Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.h"
ABI_IMPLEMENTATION = ROOT / "Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.mm"
ABI_SWIFT = ROOT / "Engine/VulpraEngineKit/Internal/ABI/EngineABI.swift"
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    lifecycle = LIFECYCLE.read_text(encoding="utf-8")
    header = ABI_HEADER.read_text(encoding="utf-8")
    implementation = ABI_IMPLEMENTATION.read_text(encoding="utf-8")
    swift = ABI_SWIFT.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")

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

    for public_root in (ROOT / "Engine/VulpraEngineKit/Public", ROOT / "App"):
        for path in public_root.rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            require("EngineChildProcess" not in text and "processIdentifier" not in text,
                    f"private process lifecycle leaked into public source: {path}")

    print("PASS: closed internal child-process lifecycle contract")


if __name__ == "__main__":
    main()
