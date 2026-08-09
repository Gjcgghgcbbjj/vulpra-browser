#!/usr/bin/env python3
"""Portable contract test for the v1 engine event pipeline architecture.

Covers the four v1 changes shipped together (single-attempt gate first):

1. Event coalescing: high-frequency fire-and-forget engine events are
   collapsed per kind (latest-wins, first-arrival order preserved) so the
   main-thread observer chain is not walked once per progress/location/title
   event; critical transitions and callback requests always flush pending
   state first, preserving engine ordering.
2. A2 cold-navigation: the initial LoadUri is flushed at window-open with a
   measured deferral instead of waiting for the initial about:blank PageStop
   (removes the cold-start half-beat).
3. Synchronous tab activation: tab switching no longer performs main-thread
   thumbnail drawHierarchy work and SetActive is delivered synchronously with
   final layout bounds.
4. Negative-path evidence: the tab-switch-during-load scenario exercises the
   hidden-session suspend/activate cycle from the gate harness and records
   browser_tab_active / engine_event_stats / gate_scenario markers.

Portable (no Xcode or simulator required): pure token/presence checks.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
COALESCER = ROOT / "Engine/VulpraEngineKit/Internal/Session/EngineEventCoalescer.swift"
BROWSER_TAB = ROOT / "App/Browser/BrowserTab.swift"
TAB_MANAGER = ROOT / "App/Browser/TabManager.swift"
BROWSER_VC = ROOT / "App/Browser/BrowserViewController.swift"
SCENARIO = ROOT / "App/Gate/TabSwitchDuringLoadScenario.swift"
GATE_SERVER = ROOT / "App/GateDispatchServer.swift"
SCENE = ROOT / "App/SceneDelegate.swift"
SUMMARIZER = ROOT / "Tools/CI/summarize-r0-engine-gate.py"
CHECKER = ROOT / "Tools/CI/check-single-attempt-gate.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> int:
    coalescer = COALESCER.read_text(encoding="utf-8")
    session = SESSION.read_text(encoding="utf-8")
    browser_tab = BROWSER_TAB.read_text(encoding="utf-8")
    tab_manager = TAB_MANAGER.read_text(encoding="utf-8")
    browser_vc = BROWSER_VC.read_text(encoding="utf-8")
    gate_server = GATE_SERVER.read_text(encoding="utf-8")
    scene = SCENE.read_text(encoding="utf-8")

    # 1a. Coalescer exists and implements the latest-wins/first-arrival contract.
    require(COALESCER.is_file(), "EngineEventCoalescer.swift is missing")
    for token in (
        "struct EngineEventCoalescer",
        "func record(kind: String, payload: [String: Any])",
        "func drain()",
        "var isEmpty",
        "coalescedCount",
        "kinds.append(kind)",
        "coalescedCount += 1",
        "struct Item",
    ):
        require(token in coalescer, f"EngineEventCoalescer is missing {token!r}")

    # 1b. Delivery classes: exactly the four coalesced kinds and the seven
    # critical kinds; callback and critical paths flush pending state first.
    for token in (
        '"GeckoView:ProgressChanged"',
        '"GeckoView:LocationChange"',
        '"GeckoView:PageTitleChanged"',
        '"GeckoView:SecurityChanged"',
        '"GeckoView:PageStart"',
        '"GeckoView:PageStop"',
        '"GeckoView:ContentCrash"',
        '"GeckoView:ContentKill"',
        '"GeckoView:OnLoadError"',
        '"GeckoView:DOMWindowClose"',
        '"GeckoView:FocusRequest"',
        "static let coalescedKinds: Set<String>",
        "static let criticalKinds: Set<String>",
        "func scheduleEventFlush()",
        "func flushCoalescedEvents()",
        "if callback != nil",
        "flushCoalescedEvents()",
        "eventCoalescer.record(kind: type, payload: payload)",
        "scheduleEventFlush()",
        "eventCoalescer.drain()",
    ):
        require(token in session, f"VulpraEngineSession is missing {token!r}")
    require(session.count('"GeckoView:ProgressChanged"') >= 1 and
            session.count("coalescedKinds.contains(type)") >= 1,
            "VulpraEngineSession does not route coalesced kinds through the coalescer")

    # 1c. PageStop emits the per-navigation evidence line with totals.
    require("engine_event_stats delivered=" in session and
            "coalesced=" in session and "total=" in session,
            "VulpraEngineSession PageStop is missing engine_event_stats evidence")

    # 2. A2 cold-navigation contract (markers + window-open flush).
    for token in (
        "initial_load_deferred=true",
        "initial_load_deferred=false",
        "initial_load_deferred_ms=",
        "flushInitialLoadCommands()",
        "initialLoadQueuedAtNanoseconds",
        "pendingInitialLoadCommands",
    ):
        require(token in session, f"VulpraEngineSession is missing A2 marker {token!r}")
    require("awaitingInitialPageStop" not in session,
            "VulpraEngineSession still carries the retired awaitingInitialPageStop path")

    # 3a. Tab activation evidence and deferred thumbnail capture off the
    # tab-switch path.
    for token in (
        "browser_tab_active=",
        "thumbnailWorkItem",
        "scheduleThumbnailCapture()",
        "thumbnailWorkItem?.cancel()",
        "DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)",
        "case .completed",
    ):
        require(token in browser_tab, f"BrowserTab is missing {token!r}")
    require("captureThumbnail()" not in tab_manager.replace("scheduleThumbnailCapture", "x"),
            "TabManager.select still performs main-thread thumbnail capture")

    # 3b. Synchronous activation with final layout bounds in showSelectedTab.
    require("contentContainer.layoutIfNeeded()" in browser_vc and
            "tab.setActive(isSceneActive)" in browser_vc,
            "BrowserViewController does not activate the attached tab synchronously")
    async_activation = "DispatchQueue.main.async { [weak self, weak tab] in"
    require(async_activation not in browser_vc,
            "BrowserViewController still defers SetActive to an async hop")

    # 4. Negative-path scenario wiring end to end (extension file keeps the
    # browser owner under the product line budget).
    scenario = SCENARIO.read_text(encoding="utf-8")
    for token in (
        "func runTabSwitchDuringLoadScenario(url: URL)",
        "extension BrowserViewController",
        "gate_scenario=tab-switch-during-load started",
        "gate_scenario=tab-switch-during-load completed",
        "gate_scenario=tab-switch-during-load aborted",
        "tabManager.select(second)",
        "tabManager.select(first)",
    ):
        require(token in scenario, f"tab-switch scenario extension is missing {token!r}")
    require("gate_scenario=tab-switch-during-load" not in browser_vc,
            "BrowserViewController retains the scenario in the over-budget owner")
    for token in (
        "onTabSwitchDuringLoad",
        'dictionary["scenario"] as? String == "tab-switch-during-load"',
        "scheme == \"http\" || scheme == \"https\"",
    ):
        require(token in gate_server, f"GateDispatchServer is missing {token!r}")
    require("onTabSwitchDuringLoad: { [weak self] url in" in scene and
            "runTabSwitchDuringLoadScenario(url: url)" in scene,
            "SceneDelegate does not wire the tab-switch scenario to the browser")

    # 5. Gate schema carries the new evidence end to end.
    summarize = SUMMARIZER.read_text(encoding="utf-8")
    checker = CHECKER.read_text(encoding="utf-8")
    for token in (
        '"tabSwitchStatus"',
        '"engineEventStats"',
        '"browserTabDeactivatedCount"',
        '"initialLoadPath"',
        '"initialLoadDeferredMs"',
    ):
        require(token in summarize and token in checker,
                f"R0 gate schema is missing evidence key {token!r}")
    require("tab-switch-during-load scenario did not complete" in summarize and
            "tab-switch-during-load scenario did not complete" in checker,
            "R0 gate does not require tab-switch scenario completion")

    print("PASS: v1 engine event pipeline architecture contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
