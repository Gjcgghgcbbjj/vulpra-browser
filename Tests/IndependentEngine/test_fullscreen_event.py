#!/usr/bin/env python3
"""Draft: GeckoView:DOMFullscreenEntered/Exited -> EngineFullscreenObserver contract.

Prepared during gate 31244916221 wait (read-only; NOT yet committed).
When the lifecycle gate goes green, this becomes
Tests/IndependentEngine/test_fullscreen_event.py together with the
EngineEvents.swift + EngineSession.swift + VulpraEngineSession.swift fix
(see .build/fullscreen-event-fix.patch).
"""
import pathlib
import sys
from pathlib import Path

from engine_sources import ROOT, read_packaged


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit" / "Public" / "EngineEvents.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = find_root()
EVENTS = ROOT / "Engine/VulpraEngineKit/Public/EngineEvents.swift"
PROTOCOL = ROOT / "Engine/VulpraEngineKit/Public/EngineSession.swift"
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"



def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    events = read(EVENTS)
    protocol = read(PROTOCOL)
    session = read(SESSION)
    content = read_packaged("modules/GeckoViewContent.sys.mjs")
    require(content is not None,
            "GeckoViewContent.sys.mjs not found in packaged runtime resources")

    # 1. Gecko side: emits fullscreen events and listens for the app exit command.
    require('"GeckoView:DOMFullscreenEntered"' in content,
            "GeckoViewContent.sys.mjs does not emit DOMFullscreenEntered")
    require('"GeckoView:DOMFullscreenExited"' in content,
            "GeckoViewContent.sys.mjs does not emit DOMFullscreenExited")
    require('"GeckoViewContent:ExitFullScreen"' in content,
            "GeckoViewContent.sys.mjs lost GeckoViewContent:ExitFullScreen listener")

    # 2. Public observer + session surface (no Gecko strings leak into public API).
    require("public protocol EngineFullscreenObserver" in events,
            "EngineEvents.swift missing EngineFullscreenObserver")
    require("engineSessionDidEnterFullscreen(_ id: EngineSessionID)" in events,
            "EngineFullscreenObserver missing enter method")
    require("engineSessionDidExitFullscreen(_ id: EngineSessionID)" in events,
            "EngineFullscreenObserver missing exit method")
    require("var fullscreenObserver" in protocol,
            "EngineSession.swift missing fullscreenObserver property")
    require("func exitFullscreen()" in protocol,
            "EngineSession.swift missing exitFullscreen()")
    for token in ("GeckoView", "Gecko"):
        require(token not in events and token not in protocol,
                f"Gecko string leaked into public contract: {token}")

    # 3. Session implementation handles both events and forwards exit to Gecko.
    require('case "GeckoView:DOMFullscreenEntered"' in session,
            "VulpraEngineSession.swift missing DOMFullscreenEntered branch")
    require('case "GeckoView:DOMFullscreenExited"' in session,
            "VulpraEngineSession.swift missing DOMFullscreenExited branch")
    require("fullscreenObserver" in session,
            "VulpraEngineSession.swift missing fullscreenObserver property")
    require('send("GeckoViewContent:ExitFullScreen")' in session,
            "VulpraEngineSession.swift missing ExitFullScreen send")

    print("PASS: DOMFullscreen event contract (enter/exit branches wired, "
          "observer exposed, app-driven exit path present)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        EVENTS = pathlib.Path(sys.argv[1])
    if len(sys.argv) > 2:
        PROTOCOL = pathlib.Path(sys.argv[2])
    if len(sys.argv) > 3:
        SESSION = pathlib.Path(sys.argv[3])
    raise SystemExit(main())
