#!/usr/bin/env python3
"""Contracts for the runtime/session/process hardening repair."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {relative}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    public_runtime = read("Engine/VulpraEngineKit/Public/EngineRuntime.swift")
    public_session = read("Engine/VulpraEngineKit/Public/EngineSession.swift")
    runtime = read("Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift")
    session = read("Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift")
    tab = read("App/Browser/BrowserTab.swift")
    manager = read("App/Browser/TabManager.swift")
    browser = read("App/Browser/BrowserViewController.swift")
    scene = read("App/SceneDelegate.swift")
    bridge_header = read("Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.h")
    process = read("Engine/VulpraEngineProcess/EngineProcessExtension.swift")
    simulator_workflow = read(".github/workflows/simulator-smoke.yml")

    require("@MainActor\npublic protocol EngineRuntime" in public_runtime,
            "EngineRuntime must declare its actor boundary")
    require("@MainActor\npublic protocol EngineSession" in public_session,
            "EngineSession must declare its actor boundary")
    require("@unchecked Sendable" not in runtime and "@unchecked Sendable" not in session,
            "runtime/session must not bypass Sendable checking")
    require("@MainActor\npublic final class VulpraEngineRuntime" in runtime,
            "runtime implementation must be main-actor isolated")
    require("@MainActor\npublic final class VulpraEngineSession" in session,
            "session implementation must be main-actor isolated")
    require("contentProcessLimit" not in public_runtime and "contentProcessLimit" not in runtime,
            "unused content-process configuration promise remains")
    require("deinit { close() }" not in session,
            "session deinit must not cross the main-actor lifecycle boundary")
    require(runtime.count("markReady()") == 2,
            "native RuntimeReady must be the sole runtime callback ready transition")
    require('case "Vulpra:RuntimeReady"' in runtime,
            "runtime does not consume the native ready event")

    require("private let runtime: any EngineRuntime" in tab,
            "BrowserTab must depend on EngineRuntime protocol")
    require("@MainActor\nprotocol BrowserTabObserver" in tab,
            "BrowserTabObserver must share the tab actor boundary")
    require("VulpraEngine.runtime" not in tab and "VulpraEngineSession" not in tab,
            "BrowserTab still depends on concrete engine owners")
    require("private var engineSurface: (any EngineView)?" in tab,
            "BrowserTab must own its protocol-backed engine surface")
    require("session?.contentView" not in tab,
            "BrowserTab still reads concrete session view state")
    require("private let runtime: any EngineRuntime" in manager,
            "TabManager must receive the runtime dependency")
    require("init(runtime: any EngineRuntime" in manager,
            "TabManager lacks runtime injection")
    require("init(runtime: any EngineRuntime" in browser,
            "BrowserViewController is not wired as the composition boundary")
    require("import VulpraEngineKit" in scene and "VulpraEngine.runtime" in scene,
            "SceneDelegate must own the concrete runtime composition")

    require("Callback values are owned handoffs" in bridge_header,
            "ABI callback ownership contract is missing")
    require("__bridge_retained void *)box" in read("Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.mm"),
            "ABI callback handoff is not retained")
    require("EngineABICallbackLease" in read("Engine/VulpraEngineKit/Internal/ABI/EngineABI.swift"),
            "Swift callback lease owner is missing")
    require("func shutdown()" in manager and "browser?.shutdown()" in scene,
            "scene teardown does not close all tab sessions")
    require("connection.interruptionHandler" in process and
            "connection.invalidationHandler" in process,
            "Engine Process lacks connection terminal handlers")
    require("removeValue(forKey:" in process and "completeRequest" in process,
            "Engine Process does not reclaim connection/context owners")
    require("lock['simulator']['archive']" in simulator_workflow and "xcrun vtool" not in simulator_workflow,
            "simulator workflow does not consume the locked simulator artifact")

    for token in (
        'xcrun simctl boot "$test_udid"',
        'test_deadline=$((SECONDS + 600))',
        '"** TEST SUCCEEDED **"',
        '"** TEST FAILED **"',
        "testRuntimeCreatesProtocolSessionWithRequestedConfiguration()' passed",
        "testRuntimeStartsStopped()' passed",
        "testCallbackLeaseResolvesOnlyOnce()' passed",
        "testSessionLifecycleClosesAfterFailedOpenAndRetry()' passed",
        'log stream --style compact --info --debug',
    ):
        require(token in simulator_workflow,
                f"native test workflow lacks bounded completion evidence: {token}")
    require("log show --last" not in simulator_workflow,
            "simulator evidence must not use an unbounded historical log scan")
    require("run_with_timeout 60 xcrun simctl launch" in simulator_workflow and
            "run_with_timeout 180 xcrun simctl bootstatus" in simulator_workflow,
            "simulator lifecycle commands must have bounded completion")
    require(simulator_workflow.count("run_with_timeout 300 xcrun simctl install") == 2,
            "large Simulator app installs need a bounded but viable timeout")

    print("PASS: runtime, injection, ABI, and process hardening contracts")


if __name__ == "__main__":
    main()
