#!/usr/bin/env python3
"""Verify the VulpraEngineKit public boundary remains typed and dependency-free."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "Engine" / "VulpraEngineKit" / "Public"
EXPECTED = {
    "EngineCapabilities.swift",
    "EngineRuntime.swift",
    "EngineSession.swift",
    "EngineEvents.swift",
    "EngineView.swift",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> None:
    require(PUBLIC.is_dir(), "missing VulpraEngineKit/Public")
    actual = {path.name for path in PUBLIC.glob("*.swift")}
    require(actual == EXPECTED, "public EngineKit owner set differs from the approved skeleton")
    text = "\n".join(path.read_text(encoding="utf-8") for path in sorted(PUBLIC.glob("*.swift")))
    for token in ("Gecko", "[String: Any]", "UnsafePointer", "UnsafeMutablePointer", "NotificationCenter", "WebKit"):
        require(token not in text, f"public contract exposes forbidden token {token}")
    for token in ("EngineRuntime", "EngineSession", "EngineView", "EngineNavigationObserver", "EngineProgressObserver", "EngineRequestCancellation"):
        require(re.search(rf"\b(protocol|struct|enum)\s+{token}\b", text) is not None,
                f"missing public owner {token}")
    require("@MainActor" in (PUBLIC / "EngineView.swift").read_text(encoding="utf-8"),
            "EngineView must be MainActor isolated")
    require("func cancel()" in (PUBLIC / "EngineSession.swift").read_text(encoding="utf-8"),
            "request cancellation contract is missing")
    require(all(len(path.read_text(encoding="utf-8").splitlines()) < 350 for path in PUBLIC.glob("*.swift")),
            "public EngineKit owner exceeds the file budget")
    print("PASS: VulpraEngineKit public contract")


if __name__ == "__main__":
    main()
