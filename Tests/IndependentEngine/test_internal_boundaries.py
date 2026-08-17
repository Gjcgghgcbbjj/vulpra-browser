#!/usr/bin/env python3
"""Verify internal ABI and child-process ownership boundaries."""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ABI = ROOT / "Engine/VulpraEngineKit/Internal/ABI"
PROCESS = ROOT / "Engine/VulpraEngineProcess"
PUBLIC = ROOT / "Engine/VulpraEngineKit/Public"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> None:
    header = ABI / "EngineABIBridge.h"
    implementation = ABI / "EngineABIBridge.mm"
    bootstrap = PROCESS / "EngineProcessBootstrap.swift"
    info_path = PROCESS / "Info.plist"
    for path in (header, implementation, bootstrap, info_path):
        require(path.is_file(), f"missing {path.relative_to(ROOT)}")
    header_text = header.read_text(encoding="utf-8")
    implementation_text = implementation.read_text(encoding="utf-8")
    require("#include <stdint.h>" in header_text, "ABI header must be C-compatible")
    require("#import \"EngineABIBridge.h\"" in implementation_text, "ABI implementation must own its header")
    require("Gecko" not in header_text and "Gecko" not in implementation_text,
            "Phase A ABI bridge must not fabricate kernel symbol names")
    require("static void *" in implementation_text, "opaque state must be owned by the .mm translation unit")
    public_text = "\n".join(path.read_text(encoding="utf-8") for path in PUBLIC.glob("*.swift"))
    require("EngineABIBridge" not in public_text, "public contracts must not expose the ABI bridge")
    process_text = bootstrap.read_text(encoding="utf-8")
    for token in ("TabManager", "BrowserTab", "UIViewController", "UserDefaults", "NotificationCenter"):
        require(token not in process_text, f"process bootstrap contains product state token {token}")
    for token in ("runtime-root", "endpoint", "protocol-version", "duplicateArgument", "missingArgument"):
        require(token in process_text, f"process bootstrap contract missing {token}")
    info = plistlib.loads(info_path.read_bytes())
    require(info.get("CFBundlePackageType") == "XPC!", "engine process must be an XPC host")
    require(info.get("VulpraEngineProcessProtocolVersion") == 1, "process protocol version must be 1")
    require(re.search(r"Unsafe\w*Pointer", process_text) is None, "process bootstrap must not hold opaque pointers")
    print("PASS: independent ABI and process boundaries")


if __name__ == "__main__":
    main()
