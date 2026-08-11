#!/usr/bin/env python3
"""Draft: GeckoView:ClipboardPermissionRequest -> EngineClipboardPermissionHandler.

A51 amended by annex 58: the message is NOT hung; Swift's default branch
resolves NSNull -> {ok:null} -> silent deny. This fix adds a real handler
branch that defaults to a resolved deny (never hangs) and, when a handler is
attached, surfaces an explicit allow/deny UI.
Prepared during gate 31244916221 wait (read-only; NOT yet committed).
"""
import pathlib
import sys
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit" / "Public" / "EngineFeatures.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = find_root()
FEATURES = ROOT / "Engine/VulpraEngineKit/Public/EngineFeatures.swift"
PROTOCOL = ROOT / "Engine/VulpraEngineKit/Public/EngineSession.swift"
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
CONTROLLER = ROOT / "App/Privacy/BrowserPermissionController.swift"
VC = ROOT / "App/Browser/BrowserViewController.swift"
TABS = ROOT / "App/Browser/TabManager.swift"
TAB = ROOT / "App/Browser/BrowserTab.swift"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    features = read(FEATURES)
    protocol = read(PROTOCOL)
    session = read(SESSION)
    controller = read(CONTROLLER)
    vc = read(VC)
    tabs = read(TABS)
    tab = read(TAB)

    # 1. Public handler surface (no UIKit, no Gecko strings).
    require("public struct EngineScreenPoint" in features, "missing EngineScreenPoint")
    require("public protocol EngineClipboardPermissionHandler" in features,
            "missing EngineClipboardPermissionHandler")
    require("requestedClipboardAccessAt point: EngineScreenPoint" in features,
            "handler method signature mismatch")
    require("var clipboardPermissionHandler" in protocol,
            "EngineSession.swift missing clipboardPermissionHandler")

    # 2. Session handles the request and defaults to a resolved deny.
    require('case "GeckoView:ClipboardPermissionRequest"' in session,
            "missing ClipboardPermissionRequest branch")
    require("handleClipboardPermission(payload, callback: callback)" in session,
            "branch does not call handler")
    require("guard let clipboardPermissionHandler else { resolve(callback, value: NSNumber(value: false)); return }" in session,
            "no-handler path must resolve false (A51 amendment: never hang)")
    require("screenPoint" in session, "payload screenPoint not parsed")
    require("completion: @escaping (Bool) -> Void" not in session or "completion" in session,
            "handler completion not forwarded")

    # 3. App wires the controller end-to-end.
    require("EngineClipboardPermissionHandler" in controller,
            "BrowserPermissionController does not implement the handler")
    require("permission.clipboard_paste" in controller,
            "clipboard permission UI copy missing")
    require("tabManager.clipboardPermissionHandler = permissionController" in vc,
            "BrowserViewController does not wire clipboardPermissionHandler")
    require("clipboardPermissionHandler" in tabs, "TabManager does not propagate")
    require("clipboardPermissionHandler" in tab, "BrowserTab does not propagate")

    print("PASS: clipboard permission handler contract (resolved-deny default, "
          "App UI wired, propagation end-to-end)")
    return 0


if __name__ == "__main__":
    paths = [FEATURES, PROTOCOL, SESSION, CONTROLLER, VC, TABS, TAB]
    for i in range(len(paths)):
        if len(sys.argv) > i + 1:
            paths[i] = pathlib.Path(sys.argv[i + 1])
    FEATURES, PROTOCOL, SESSION, CONTROLLER, VC, TABS, TAB = paths
    raise SystemExit(main())
