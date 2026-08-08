#!/usr/bin/env python3
"""Draft: GeckoView:SecurityChanged -> EngineSecurityEvent contract.

Prepared during gate 31244916221 wait (read-only; NOT yet committed).
When the lifecycle gate goes green, this becomes
Tests/IndependentEngine/test_security_state_event.py together with the
EngineEvents.swift + VulpraEngineSession.swift security-state fix
(see .build/security-state-event-fix.patch).
"""
import pathlib
import re
import sys
from pathlib import Path


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
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
OMNIJAR = ROOT / ".build/omnijar-verify-root/runtime/resources/omni.ja"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    events = read(EVENTS)
    session = read(SESSION)
    # GeckoViewProgress is not in the sparse patched source tree; verify the
    # shipped omni.ja (locked v5 artifact), same as the annex evidence chain.
    import zipfile
    with zipfile.ZipFile(OMNIJAR) as z:
        progress = z.read("modules/GeckoViewProgress.sys.mjs").decode("utf-8", errors="ignore")

    # 1. Gecko side emits GeckoView:SecurityChanged with identity payload.
    require('"GeckoView:SecurityChanged"' in progress,
            "GeckoViewProgress.sys.mjs does not emit GeckoView:SecurityChanged")
    require("IdentityHandler.checkIdentity" in progress,
            "GeckoViewProgress.sys.mjs lost IdentityHandler.checkIdentity")
    gecko_keys = ["mode", "origin", "secure", "host", "certificate", "securityException",
                  "identity", "mixed_display", "mixed_active"]
    for key in gecko_keys:
        require(key in progress, f"Gecko identity payload key missing: {key}")

    # 2. Public event type + observer protocol.
    require("public struct EngineSecurityEvent" in events,
            "EngineEvents.swift missing EngineSecurityEvent")
    for field in ["sessionID", "origin", "isSecure", "host", "identityMode",
                  "hasMixedDisplayContent", "hasMixedActiveContent", "certificate",
                  "hasSecurityException"]:
        require(f"public let {field}" in events, f"EngineSecurityEvent missing field: {field}")
    require("public protocol EngineSecurityObserver" in events,
            "EngineEvents.swift missing EngineSecurityObserver")
    require("didUpdate security: EngineSecurityEvent" in events,
            "EngineSecurityObserver method signature mismatch")

    # 3. Session handles the message and maps the payload.
    require('case "GeckoView:SecurityChanged"' in session,
            "VulpraEngineSession.swift missing GeckoView:SecurityChanged branch")
    require("securityObserver" in session,
            "VulpraEngineSession.swift missing securityObserver property")
    require("securityEvent(id, payload)" in session,
            "VulpraEngineSession.swift missing securityEvent dispatch")
    # Swift mapping keys must cover the Gecko payload keys.
    for key in ["identity", "mode", "mixed_display", "mixed_active",
                "origin", "secure", "host", "certificate", "securityException"]:
        require(f'"{key}"' in session, f"Swift mapping missing payload key: {key}")

    print("PASS: GeckoView:SecurityChanged -> EngineSecurityEvent contract "
          "(payload keys covered, observer wired, branch present)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        EVENTS = pathlib.Path(sys.argv[1])
    if len(sys.argv) > 2:
        SESSION = pathlib.Path(sys.argv[2])
    raise SystemExit(main())
