#!/usr/bin/env python3
"""Portable ownership contracts for the Vulpra browser client."""

from pathlib import Path
import re


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
    for token in (
        "browserTabPresentationDidChange",
        "browserTabPersistableStateDidChange",
        "browserTabContentDidChange",
    ):
        require(token in tab, f"BrowserTab performance contract is missing {token}")
    require("browserTabDidChange" not in tab,
            "BrowserTab retains the unified transient/persisted/content event owner")
    progress_handler = re.search(
        r"func engineSession\(_ id: EngineSessionID, didUpdate event: EngineProgressEvent\) \{.+?\n    \}",
        tab,
        flags=re.DOTALL,
    )
    require(progress_handler is not None, "BrowserTab progress handler is missing")
    require("browserTabPersistableStateDidChange" not in progress_handler.group(0),
            "transient progress events still enter tab persistence")
    activation_helper = re.search(
        r"func reassertActivationIfNeeded\(_ active: Bool\) \{.+?\n    \}",
        tab,
        flags=re.DOTALL,
    )
    require("private var didReassertActivationForLoad = false" in tab and
            activation_helper is not None and
            "guard isLoading, !didReassertActivationForLoad else { return }" in activation_helper.group(0) and
            progress_handler.group(0).count("didReassertActivationForLoad = false") == 1,
            "BrowserTab does not rearm Gecko activation exactly once at each load start")
    manager = source("App/Browser/TabManager.swift")
    require("lastPersistedTabs" in manager and "snapshot != lastPersistedTabs" in manager,
            "transient page events still enqueue redundant full tab-store writes")
    require("func browserTabPresentationDidChange" in manager and
            "func browserTabContentDidChange" in manager and
            "browserTabDidChange" not in manager,
            "TabManager does not route presentation and content events separately")
    controller = source("App/Browser/BrowserViewController.swift")
    require("guard attachedEngineView !== engineView else { return }" in controller,
            "browser repeatedly reactivates or detaches the active engine view")
    require("tab.reassertActivationIfNeeded(isSceneActive)" in controller,
            "browser does not reassert Gecko activation at the top-level load boundary")
    require("DispatchQueue.main.async { [weak self, weak tab] in" in controller,
            "browser activates a newly attached view before queued navigation is flushed")
    require("suggestionWorkItem?.cancel()" in controller and
            "asyncAfter(deadline: .now() + 0.09" in controller,
            "omnibox suggestions are not coalesced before scanning local history")
    suggestions = source("App/Browser/OmniboxSuggestions.swift")
    library = source("App/Library/BrowserLibrary.swift")
    require("BookmarkStore.shared.matches(value, limit: 6)" in suggestions and
            "HistoryStore.shared.matches(value, limit: 8)" in suggestions,
            "omnibox suggestions still materialize unbounded local search results")
    require(library.count("func matches(_ query: String, limit: Int)") == 2,
            "bounded bookmark/history query owners are missing")
    chrome = source("App/UI/BrowserChromeView.swift")
    require("private struct RenderState: Equatable" in chrome and
            "guard state != renderedState else { return }" in chrome,
            "browser chrome still redraws duplicate engine progress state")
    require("addressField.text = renderedState?.address" in chrome,
            "address field does not reconcile deferred URL state after editing")
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
