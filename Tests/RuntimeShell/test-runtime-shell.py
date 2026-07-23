#!/usr/bin/env python3
"""Retirement contract for the Phase 1A smoke shell."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]

def require(ok, message):
    if not ok: print('FAIL:', message, file=sys.stderr); raise SystemExit(1)

def main():
    require(not (ROOT/'App/RuntimeShellViewController.swift').exists(), 'runtime shell still exists')
    scene=(ROOT/'App/SceneDelegate.swift').read_text()
    require('BrowserViewController(initialURL:' in scene, 'browser root missing')
    require('RuntimeShellViewController' not in scene, 'old root remains referenced')
    entry=(ROOT/'App/main.swift').read_text()
    require('RuntimeJITCoordinator' not in entry, 'startup JIT path must remain disconnected')
    require('GeckoRuntime.main' in entry, 'startup must enter Gecko directly')
    print('PASS: runtime shell retired into browser root')
if __name__ == '__main__': main()
