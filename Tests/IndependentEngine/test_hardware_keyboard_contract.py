#!/usr/bin/env python3
"""Annex 78 contract: App exposes hardware-keyboard chrome shortcuts
(UIKeyCommand) wired to real browser actions; EngineKit keeps the engine-side
key-event surface documented as a known limitation (annex 50).

Draft -> lands with landing-order step 12. Fails on HEAD (no UIKeyCommand
layer); passes on merged stack with annex 78 applied.
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
    kb = (ROOT / "App/Browser/BrowserKeyboardShortcuts.swift")
    if not kb.is_file():
        raise SystemExit("FAIL: BrowserKeyboardShortcuts.swift missing")
    vc = kb.read_text(encoding="utf-8")

    if "override var keyCommands: [UIKeyCommand]?" not in vc:
        raise SystemExit("FAIL: no UIKeyCommand layer in keyboard extension")
    if "extension BrowserViewController" not in vc:
        raise SystemExit("FAIL: keyboard shortcuts not an extension of BrowserViewController")
    # BrowserViewController itself must stay under the 350-line owner budget
    main = (ROOT / "App/Browser/BrowserViewController.swift").read_text(encoding="utf-8")
    if "override var keyCommands" in main:
        raise SystemExit("FAIL: keyCommands must live in BrowserKeyboardShortcuts.swift (owner budget)")

    # Shortcut matrix: input -> handler must exist and call a real action
    matrix = {
        "New Tab": ("handleKeyNewTab", "newTab"),
        "Focus Address Bar": ("handleKeyFocusAddress", "focusAddress"),
        "Reload": ("handleKeyReload", "browserChromeDidRequestReloadOrStop"),
        "Back": ("handleKeyBack", "goBack"),
        "Forward": ("handleKeyForward", "goForward"),
        "Close Tab": ("handleKeyCloseTab", "close"),
        "Tab switch": ("handleKeySwitchTab", "select"),
    }
    for label, (handler, action) in matrix.items():
        if f"#selector({handler}" not in vc:
            raise SystemExit(f"FAIL: {label} shortcut not registered ({handler})")
        pattern = re.compile(
            rf"@objc private func {handler}\b[^\{{]*\{{(.*?)\n    \}}", re.S
        )
        m = pattern.search(vc)
        if not m or action not in m.group(1):
            raise SystemExit(f"FAIL: {label} handler {handler} does not call {action}")

    # Cmd+1..9 switch-tab loop
    if "input: String(number)" not in vc or "1...9" not in vc:
        raise SystemExit("FAIL: Cmd+1..9 tab switch loop missing")

    print("PASS: hardware-keyboard chrome shortcuts wired (Cmd+T/L/R/[/]/W/1-9)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
