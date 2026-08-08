#!/usr/bin/env python3
"""GeckoView:SecurityChanged -> EngineSecurityEvent contract.

Cross-checks the packaged GeckoViewProgress.sys.mjs (actual v5 runtime:
exploded resources dir or omni.ja, resolved by engine_sources.py) against
EngineEvents.swift + VulpraEngineSession.swift. The omni.ja path must not be
hardcoded to a local-only directory (CI has only .build/engine/runtime/resources).
"""
import pathlib
import re
import sys
from pathlib import Path

from engine_sources import ROOT, read_packaged

EVENTS = ROOT / "Engine/VulpraEngineKit/Public/EngineEvents.swift"
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
    session = read(SESSION)
    # GeckoViewProgress is not in the sparse patched source tree; verify the
    # packaged module from the locked v5 artifact (exploded resources dir in
    # CI, omni.ja archive locally), same as the annex evidence chain.
    progress = read_packaged("modules/GeckoViewProgress.sys.mjs")
    require(progress is not None,
            "GeckoViewProgress.sys.mjs not found in packaged runtime resources")

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
