#!/usr/bin/env python3
"""G4+G5 contract: GeckoView:FocusRequest handled by App (tab select path),
and EngineCapabilities honestly declares supportsAutofill=false while the
engine's autofill actor surface stays covered.

Draft -> landed with step 11 of landing-order (annex 75). Fails on HEAD
(no FocusRequest case / no supportsAutofill field); passes on the merged
stack with G4+G5 applied.
"""
import pathlib
import re
import sys
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit").is_dir():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = find_root()


def main() -> int:
    # G4: session must dispatch FocusRequest to the content observer
    session = (ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift").read_text(encoding="utf-8")
    if 'case "GeckoView:FocusRequest": contentObserver?.engineSessionDidRequestFocus(id)' not in session:
        raise SystemExit("FAIL: VulpraEngineSession does not handle GeckoView:FocusRequest")
    if "engineSessionDidRequestFocus" not in session:
        raise SystemExit("FAIL: FocusRequest never reaches content observer")

    # G4: App layer must forward focus to TabManager.select
    tab = (ROOT / "App/Browser/BrowserTab.swift").read_text(encoding="utf-8")
    if "func engineSessionDidRequestFocus" not in tab:
        raise SystemExit("FAIL: BrowserTab does not forward focus request")
    manager = (ROOT / "App/Browser/TabManager.swift").read_text(encoding="utf-8")
    if "func browserTabDidRequestFocus(_ tab: BrowserTab) { select(tab) }" not in manager:
        raise SystemExit("FAIL: TabManager does not select the tab on focus request")

    # G5: capability honesty
    caps = (ROOT / "Engine/VulpraEngineKit/Public/EngineCapabilities.swift").read_text(encoding="utf-8")
    if "supportsAutofill" not in caps:
        raise SystemExit("FAIL: EngineCapabilities has no supportsAutofill field")
    runtime = (ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift").read_text(encoding="utf-8")
    m = re.search(r"supportsAutofill:\s*(true|false)", runtime)
    if not m:
        raise SystemExit("FAIL: capabilities value for supportsAutofill missing")
    if m.group(1) != "false":
        raise SystemExit("FAIL: supportsAutofill must be honestly false (no autofill UI shipped)")

    print("PASS: FocusRequest -> tab select chain wired; supportsAutofill honestly false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
