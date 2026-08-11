#!/usr/bin/env python3
"""Draft: tracking protection real enforcement (A39 deepened by annex 58/59).

Prepared during gate 31244916221 wait (read-only; NOT yet committed).
When the lifecycle gate goes green, this becomes
Tests/IndependentEngine/test_tracking_protection_real.py together with the
EngineSession.swift + VulpraEngineRuntime.swift + VulpraEngineSession.swift +
BrowserSettings.swift fix (see .build/tracking-protection-real-fix.patch).
"""
import pathlib
import sys
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit" / "Public" / "EngineSession.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = find_root()
PROTOCOL = ROOT / "Engine/VulpraEngineKit/Public/EngineSession.swift"
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
SETTINGS = ROOT / "App/Settings/BrowserSettings.swift"
KITTESTS = ROOT / "Tests/VulpraEngineKitTests/VulpraEngineKitTests.swift"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    protocol = read(PROTOCOL)
    runtime = read(RUNTIME)
    session = read(SESSION)
    settings = read(SETTINGS)
    kittests = read(KITTESTS)

    # 1. Level enum replaces the collapsed Bool in the public configuration.
    require("public enum EngineTrackingProtectionLevel" in protocol,
            "EngineSession.swift missing EngineTrackingProtectionLevel")
    for case in ("case off", "case standard", "case strict"):
        require(case in protocol, f"EngineTrackingProtectionLevel missing {case}")
    require("public let trackingProtection: EngineTrackingProtectionLevel" in protocol,
            "configuration still collapses trackingProtection to Bool")
    require("trackingProtection: EngineTrackingProtectionLevel = .standard" in protocol,
            "configuration default is not .standard")

    # 2. Runtime injects the real blocking prefs (bool, user branch).
    require("func applyTrackingProtectionPrefs" in runtime,
            "VulpraEngineRuntime.swift missing applyTrackingProtectionPrefs")
    for pref in ("privacy.trackingprotection.enabled",
                 "privacy.trackingprotection.socialtracking.enabled",
                 "privacy.trackingprotection.fingerprinting.enabled",
                 "privacy.trackingprotection.cryptomining.enabled"):
        require(f'"{pref}"' in runtime, f"runtime pref injection missing {pref}")
    require('level != .off' in runtime, "enabled/socialtracking not gated on level != .off")
    require('level == .strict' in runtime, "fingerprinting/cryptomining not gated on strict")
    require('"type": 128' in runtime, "pref injection must use PREF_BOOL (type 128, v5 cenum)")

    # 3. Session enables the content-blocking module and wires per-BC flag + injection.
    require('"GeckoViewContentBlocking": true' in session,
            "initialData does not enable GeckoViewContentBlocking module")
    require("value.trackingProtection != .off" in session,
            "useTrackingProtection flag not derived from level != .off")
    require("runtime.applyTrackingProtectionPrefs(configuration.trackingProtection)" in session,
            "session does not apply tracking prefs before window open")

    # 4. App maps all three choices honestly (no collapse).
    require("init(level: TrackingProtectionLevel)" in settings,
            "BrowserSettings.swift missing honest level mapping")
    require("case .standard: self = .standard" in settings, "standard not mapped to .standard")
    require("case .strict: self = .strict" in settings, "strict not mapped to .strict")

    # 5. EngineKit unit tests compile with the new type.
    require("trackingProtection: .standard" in kittests,
            "VulpraEngineKitTests.swift still constructs trackingProtection as Bool")

    print("PASS: tracking protection real enforcement contract "
          "(level enum, blocking prefs injected, module enabled, honest App mapping)")
    return 0


if __name__ == "__main__":
    paths = [PROTOCOL, RUNTIME, SESSION, SETTINGS, KITTESTS]
    for i in range(len(paths)):
        if len(sys.argv) > i + 1:
            paths[i] = pathlib.Path(sys.argv[i + 1])
    PROTOCOL, RUNTIME, SESSION, SETTINGS, KITTESTS = paths
    raise SystemExit(main())
