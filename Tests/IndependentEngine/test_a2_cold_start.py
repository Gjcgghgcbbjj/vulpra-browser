#!/usr/bin/env python3
"""Draft: A2 cold-start readiness markers contract.

Prepared during gate 31244916221 wait (read-only; NOT yet committed).
When the lifecycle gate goes green, this becomes
Tests/IndependentEngine/test_a2_cold_start.py together with the
VulpraEngineRuntime.swift + VulpraEngineSession.swift marker fix
(see .build/a2-cold-start-markers.patch).

Usage: python3 test_a2_cold_start_draft.py [ROOT_OVERRIDE]
ROOT_OVERRIDE = patched worktree copy (PASS expected).
Default = this worktree (FAIL expected on current HEAD).
"""
import pathlib
import sys
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit" / "Internal" / "Runtime" / "VulpraEngineRuntime.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else find_root()
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def main() -> int:
    runtime = RUNTIME.read_text(encoding="utf-8")
    session = SESSION.read_text(encoding="utf-8")

    # 1. Cold-start anchor: single public os_log line at runtime ready.
    require('"Engine runtime ready"' in runtime,
            "VulpraEngineRuntime missing 'Engine runtime ready' marker")
    require('lifecycle.becomeReady(Self.capabilities) else { return }' in runtime,
            "markReady guard missing")

    # 2. Both initial-load path markers must exist (A2 groups p95 by path).
    require('"initial_load_deferred=false"' in session,
            "missing immediate-dispatch marker (path A)")
    require('"initial_load_deferred=true"' in session,
            "missing deferred-dispatch marker (path B)")

    # 3. Marker placement must be correct: path A only when window != nil,
    #    path B only inside the LoadUri queuing branch.
    immediate_idx = session.find('"initial_load_deferred=false"')
    window_idx = session.find("if window != nil {")
    require(0 <= window_idx < immediate_idx < window_idx + 400,
            "immediate marker is not inside the window-open dispatch branch")
    deferred_idx = session.find('"initial_load_deferred=true"')
    loaduri_idx = session.rfind('type == "GeckoView:LoadUri"')
    require(0 <= loaduri_idx < deferred_idx < loaduri_idx + 400,
            "deferred marker is not inside the LoadUri queuing branch")

    # 4. The runtime logger must be declared (compiles).
    require('category: "runtime"' in runtime,
            "runtime logger category missing")

    print(f"PASS: A2 cold-start markers contract verified at {ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
