#!/usr/bin/env python3
"""Contract gate for the EngineKit host-process memory-pressure channel.

Candidate 3 (low-memory early reclaim): the App layer must be able to react
to a dispatch_source_memorypressure warning before UIKit's late
didReceiveMemoryWarning, so background tabs can be downgraded/suspended and
the content process is less likely to be selected by jetsam. This gate pins
the public API surface, the monitor implementation shape, and the App-side
mapping without requiring a Gecko recompile.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> int:
    public_runtime = read("Engine/VulpraEngineKit/Public/EngineRuntime.swift")
    runtime = read("Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift")
    monitor = read("Engine/VulpraEngineKit/Internal/Runtime/MemoryPressureMonitor.swift")
    browser = read("App/Browser/BrowserViewController.swift")
    router = read("App/Browser/MemoryPressureRouter.swift")
    scene = read("App/SceneDelegate.swift")
    tab_manager = read("App/Browser/TabManager.swift")

    # Public API surface
    require("public enum EngineRuntimeMemoryPressure" in public_runtime,
            "EngineRuntimeMemoryPressure must be public")
    for case in ("case warning", "case critical"):
        require(case in public_runtime,
                f"EngineRuntimeMemoryPressure must declare {case}")
    require("var onMemoryPressure: ((EngineRuntimeMemoryPressure) -> Void)? { get set }" in public_runtime,
            "EngineRuntime protocol must expose onMemoryPressure observer")

    # Runtime implementation wires the monitor into start() and stops it on failure
    require("public var onMemoryPressure: ((EngineRuntimeMemoryPressure) -> Void)?" in runtime,
            "VulpraEngineRuntime must implement onMemoryPressure")
    require("startMemoryPressureMonitoring()" in runtime,
            "VulpraEngineRuntime.start() must launch the memory-pressure monitor")
    require("memoryPressureMonitor?.stop()" in runtime,
            "VulpraEngineRuntime must stop the monitor on terminal failure")

    # Monitor uses a dispatch memory-pressure source with warning/critical masks
    require("makeMemoryPressureSource" in monitor,
            "MemoryPressureMonitor must create a dispatch memory-pressure source")
    require("eventMask: [.warning, .critical]" in monitor,
            "MemoryPressureMonitor must subscribe warning and critical")
    require("DispatchSourceMemoryPressure" in monitor,
            "MemoryPressureMonitor must retain the dispatch source")
    require("Task { @MainActor" in monitor,
            "MemoryPressureMonitor must deliver on the main actor")

    # App layer maps warning -> light reclaim, critical -> heavy LRU suspend
    require("func attach(runtime: any EngineRuntime, controller: BrowserViewController)" in router,
            "MemoryPressureRouter must expose attach(runtime:controller:)")
    require("runtime.onMemoryPressure = { [weak controller] level in" in router,
            "MemoryPressureRouter must subscribe onMemoryPressure")
    require("level == .critical ? .heavy : .light" in router,
            "MemoryPressureRouter must map critical->heavy, warning->light")
    require("MemoryPressureRouter.attach(runtime: VulpraEngine.runtime, controller: browser)" in scene,
            "SceneDelegate must wire the memory-pressure router at browser creation")
    require("final class BrowserViewController" in browser,
            "BrowserViewController ownership boundary must remain intact")

    # TabManager policy invariants (regression guard for the reclaim mapping)
    require("case .light:" in tab_manager and "releaseThumbnail()" in tab_manager,
            "light pressure must release thumbnails, not close sessions")
    require("case .heavy:" in tab_manager and "keepActiveSessionCount" in tab_manager,
            "heavy pressure must keep a bounded live-session cap")

    # ABI boundary: public EngineKit surface must not leak Gecko symbols
    public_files = [
        "Engine/VulpraEngineKit/Public/EngineRuntime.swift",
        "Engine/VulpraEngineKit/Public/EngineSession.swift",
        "Engine/VulpraEngineKit/Public/EngineEvents.swift",
        "Engine/VulpraEngineKit/Public/EngineCapabilities.swift",
    ]
    gecko_tokens = ("nsIOSBridge", "GeckoView", "moz", "XUL", "nsAppShell")
    for relative in public_files:
        text = read(relative)
        for token in gecko_tokens:
            require(token not in text,
                    f"public ABI boundary leaked Gecko token {token!r} in {relative}")

    print("PASS: low-memory early-reclaim contract (public API + monitor + App mapping + ABI boundary)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
