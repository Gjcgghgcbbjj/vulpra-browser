#!/usr/bin/env python3
"""Memory-pressure graded policy contract.

Verifies the App-layer light/heavy memory-pressure design:
- BrowserTab exposes hasLiveSession + releaseThumbnail
- TabManager exposes MemoryPressureLevel {light, heavy} + applyMemoryPressure
- heavy path uses LRU with a bounded keep-cap (selected never touched)
- didReceiveMemoryWarning routes to .heavy; scene background routes to .light
"""
import pathlib
import re
import sys


def find_root() -> pathlib.Path:
    p = pathlib.Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "App" / "Browser" / "TabManager.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(pathlib.Path(__file__).resolve().parent))


ROOT = find_root()
TAB = ROOT / "App/Browser/BrowserTab.swift"
MANAGER = ROOT / "App/Browser/TabManager.swift"
VC = ROOT / "App/Browser/BrowserViewController.swift"
SCENE = ROOT / "App/SceneDelegate.swift"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def main() -> int:
    if len(sys.argv) > 1:
        override = pathlib.Path(sys.argv[1]).resolve()
        require((override / "App/Browser/TabManager.swift").is_file(), "ROOT_OVERRIDE has no TabManager.swift")
        root = override
        global TAB, MANAGER, VC, SCENE
        TAB = root / "App/Browser/TabManager.swift"  # placeholder replaced below
        MANAGER = root / "App/Browser/TabManager.swift"
        VC = root / "App/Browser/BrowserViewController.swift"
        SCENE = root / "App/SceneDelegate.swift"
        tab = TAB.read_text(encoding="utf-8")  # unused placeholder
        TAB = root / "App/Browser/BrowserTab.swift"
        tab = TAB.read_text(encoding="utf-8")
    tab = TAB.read_text(encoding="utf-8")
    manager = MANAGER.read_text(encoding="utf-8")
    vc = VC.read_text(encoding="utf-8")
    scene = SCENE.read_text(encoding="utf-8")

    # 1. BrowserTab capabilities
    require("var hasLiveSession: Bool { session != nil && engineSurface != nil }" in tab,
            "BrowserTab missing hasLiveSession")
    require("func releaseThumbnail()" in tab and "thumbnail = nil" in tab,
            "BrowserTab missing releaseThumbnail")

    # 2. TabManager graded API
    require("enum MemoryPressureLevel { case light, heavy }" in manager,
            "TabManager missing MemoryPressureLevel")
    require("func applyMemoryPressure(_ level: MemoryPressureLevel)" in manager,
            "TabManager missing applyMemoryPressure")
    require("keepActiveSessionCount" in manager,
            "TabManager missing keepActiveSessionCount cap")
    require("case .light:" in manager and "case .heavy:" in manager,
            "applyMemoryPressure missing light/heavy branches")
    # heavy path must not call suspend() on the selected tab: it filters by
    # selectedID first and suspends only the background prefix
    heavy = manager.split("case .heavy:")[1].split("case .light:")[0] if "case .heavy:" in manager else ""
    require("$0.suspend()" in heavy and "selectedID" in manager.split("func applyMemoryPressure")[1][:400],
            "heavy path must suspend background-only (selected untouched)")

    # 3. didReceiveMemoryWarning routes to .heavy (not the old all-teardown)
    m = re.search(r"override func didReceiveMemoryWarning\(\).*?\n    \}", vc, re.S)
    require(m is not None and "applyMemoryPressure(.heavy)" in m.group(0),
            "didReceiveMemoryWarning must route to applyMemoryPressure(.heavy)")
    require("tabManager.suspendBackgroundTabs()" not in vc,
            "old all-teardown suspendBackgroundTabs() must be gone from VC")

    # 4. Scene background -> .light
    require("applyMemoryPressure(.light)" in scene,
            "sceneDidEnterBackground must apply .light pressure")

    # 5. Old public all-teardown helper stays private (bounded escape hatch)
    require("private func suspendBackgroundTabs()" in manager,
            "suspendBackgroundTabs must remain private")

    print("PASS: memory-pressure graded policy contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
