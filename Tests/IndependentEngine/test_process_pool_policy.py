#!/usr/bin/env python3
"""Draft (NOT committed): process pool policy prefs must be injected at runtime.

Prepared during gate 31244916221 wait (annex 66: GetMaxWebProcessCount defined
at toolkit/xre/nsAppRunner.cpp:6491; prelaunch pool = fission.number and
BYPASSES the web cap while Fission autostarts; the correct knob is
dom.ipc.processPrelaunch.fission.number, not dom.ipc.processCount alone).
When the gate goes green this becomes part of
Tests/IndependentEngine/test_runtime_hardening.py together with the
VulpraEngineRuntime fix (C1). Fails today (prefs absent); passes after fix.
"""
import pathlib
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
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"


def main() -> int:
    if not RUNTIME.is_file():
        raise SystemExit(f"FAIL: missing {RUNTIME}")
    src = RUNTIME.read_text(encoding="utf-8")

    if '"dom.ipc.processPrelaunch.fission.number"' not in src:
        raise SystemExit("FAIL: dom.ipc.processPrelaunch.fission.number pref not injected in VulpraEngineRuntime")
    if '"dom.ipc.processCount"' not in src:
        raise SystemExit("FAIL: dom.ipc.processCount pref not injected in VulpraEngineRuntime")
    if '"type": 64' not in src:  # nsIPrefBranch.PREF_INT (v5 PreferenceType cenum)
        raise SystemExit("FAIL: no PREF_INT (type 64) pref injection found")
    if '"value": 2' not in src:
        raise SystemExit("FAIL: fission.number pref not set to 2")

    # Must be dispatched through the same GeckoView:Preferences:SetPref channel
    # used by the RDD startup-timeout fix (>= 2 dispatches after this lands).
    if src.count('"GeckoView:Preferences:SetPref"') < 2:
        raise SystemExit("FAIL: process pool prefs must go through GeckoView:Preferences:SetPref")

    # Guard: a bare constant is NOT enough; must be applied from markReady
    # (before the first child-process launch).
    if "applyProcessPoolPolicy" not in src:
        raise SystemExit("FAIL: no process pool apply hook found in VulpraEngineRuntime")

    print("PASS: process pool prefs injected via SetPref PREF_INT (fission.number=2, processCount bound)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        RUNTIME = pathlib.Path(sys.argv[1])
    raise SystemExit(main())
