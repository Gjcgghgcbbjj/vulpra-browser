#!/usr/bin/env python3
"""Phase 6b: CI symbol gate — verify JIT single-path policy.

Ensures the content process path in IOSBootstrap.mm.patch does NOT call
JS::DisableJitBackend(). The content process must either enable JIT or
MOZ_CRASH — no interpreter fallback is allowed (Phase 2).

Non-content processes (socket, GMPlugin) may still call DisableJitBackend
because they do not run user JS.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "Patches" / "toolkit" / "xre" / "IOSBootstrap.mm.patch"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not PATCH.is_file():
        fail(f"missing {PATCH}")

    lines = PATCH.read_text(encoding="utf-8").splitlines()

    # Locate the content-process gating block by anchors:
    #   "if (isContentProcess)"  → start
    #   "// Non-content"          → the else branch (end of content body)
    start = None
    else_line = None
    for i, line in enumerate(lines):
        if "if (isContentProcess)" in line:
            start = i
        if start is not None and "Non-content" in line:
            else_line = i
            break

    if start is None:
        fail("could not locate isContentProcess block in IOSBootstrap.mm.patch")
    if else_line is None:
        fail("could not locate Non-content else branch in IOSBootstrap.mm.patch")

    content_body = "\n".join(lines[start:else_line])

    if "DisableJitBackend" in content_body:
        fail(
            "content process path must not call JS::DisableJitBackend() — "
            "Phase 2 requires MOZ_CRASH on JIT failure (no interpreter fallback)"
        )

    if "MOZ_CRASH" not in content_body:
        fail("content process path must MOZ_CRASH when JIT is unavailable (Phase 2)")

    # Verify the else (non-content) branch DOES call DisableJitBackend.
    # Search a window after the else line.
    else_body = "\n".join(lines[else_line:else_line + 10])
    if "DisableJitBackend" not in else_body:
        fail("non-content process path should still call DisableJitBackend (no user JS)")

    print("PASS: JIT single-path symbol gate (Phase 6b)")


if __name__ == "__main__":
    main()
