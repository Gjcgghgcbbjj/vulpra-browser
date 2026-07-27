#!/usr/bin/env python3
"""Portable ownership contracts for the Vulpra browser client."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "App"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file(), f"missing {relative}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    scene = source("App/SceneDelegate.swift")
    require("BrowserViewController(runtime: VulpraEngine.runtime, initialURL:" in scene,
            "SceneDelegate does not inject the browser runtime")
    required = {
        "App/Browser/BrowserViewController.swift": ("final class BrowserViewController", "TabManagerDelegate"),
        "App/Browser/TabManager.swift": ("final class TabManager", "func shutdown()", "tabs.forEach { $0.suspend() }"),
        "App/Browser/BrowserTab.swift": ("final class BrowserTab", "any EngineSession", "BrowserTabRecord"),
        "App/UI/BrowserChromeView.swift": ("UIVisualEffectView", "UIAccessibility.isReduceMotionEnabled"),
        "App/Tabs/TabOverviewViewController.swift": ("UICollectionView", "privateControl", "newTab"),
        "App/Library/BrowserLibrary.swift": ("BookmarkStore", "HistoryStore", "privateMode"),
        "App/Downloads/DownloadManager.swift": ("DownloadManager", "moveItem", "receivedBytes"),
        "App/Privacy/BrowserPermissionController.swift": ("EnginePermissionHandler", "SitePermissionStore"),
        "App/Settings/BrowserSettings.swift": ("TrackingProtectionLevel", "engineConfiguration", "SearchEngine"),
        "App/PageTools/PageToolsController.swift": ("page_tools.request_desktop", "page_tools.page_zoom"),
        "App/Persistence/AtomicJSONStore.swift": ("JSONEncoder", "replaceItemAt", "DispatchQueue"),
    }
    for relative, tokens in required.items():
        text = source(relative)
        for token in tokens:
            require(token in text, f"{relative} is missing {token}")

    combined = "\n".join(path.read_text(encoding="utf-8") for path in APP.rglob("*.swift"))
    require("import VulpraEngineKit" in combined, "App does not consume VulpraEngineKit")
    for forbidden in (
        "import GeckoView",
        "GeckoSession",
        "RuntimeJITCoordinator",
        "WKWebView",
        "import WebKit",
        "AddonRuntime",
        "BrowserPictureInPictureController",
    ):
        require(forbidden not in combined, f"retired client path remains: {forbidden}")
    tab = source("App/Browser/BrowserTab.swift")
    require("if let session {" in tab and "session.load(EngineNavigationRequest(url: target))" in tab,
            "BrowserTab does not send navigation through its existing session")
    require("func engineSessionDidOpen(_ id: EngineSessionID)" in tab,
            "BrowserTab does not forward engine view readiness")
    require("activate(settings: settings).load" not in tab,
            "BrowserTab still duplicates session-open and navigation ownership")
    manager = source("App/Browser/TabManager.swift")
    require("lastPersistedTabs" in manager and "snapshot != lastPersistedTabs" in manager,
            "transient page events still enqueue redundant full tab-store writes")
    controller = source("App/Browser/BrowserViewController.swift")
    require("if attachedEngineView === engineView" in controller,
            "browser repeatedly detaches the active engine view during navigation events")
    require("DispatchQueue.main.async { [weak self, weak tab] in" in controller,
            "browser activates a newly attached view before queued navigation is flushed")
    require("suggestionWorkItem?.cancel()" in controller and
            "asyncAfter(deadline: .now() + 0.09" in controller,
            "omnibox suggestions are not coalesced before scanning local history")
    progress = source("App/UI/BrowserProgressView.swift")
    require("updateGeneration" in progress and "generation == self.updateGeneration" in progress,
            "stale progress completion animations can hide a newer page load")
    require("browser?.shutdown()" in scene and "browser = nil" in scene,
            "scene disconnect does not close and release every browser session")
    require(not any(tab in source("App/Browser/TabManager.swift") for tab in ("delete user data", "reset store")),
            "tab migration introduces destructive behavior")

    over = [
        (path.relative_to(ROOT), len(path.read_text(encoding="utf-8").splitlines()))
        for path in APP.rglob("*.swift")
        if len(path.read_text(encoding="utf-8").splitlines()) >= 350
    ]
    require(not over, f"product owner line budget exceeded: {over}")
    print(f"PASS: independent browser client contracts ({len(list(APP.rglob('*.swift')))} Swift files)")


if __name__ == "__main__":
    main()
