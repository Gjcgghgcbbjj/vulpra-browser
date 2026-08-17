#!/usr/bin/env python3
"""Report the atomic cutover entry gates without claiming they are complete."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OWNERSHIP = ROOT / "Configuration/engine-ownership.json"

BLOCKERS = [
    "verified v4 Gecko artifact payload",
    "ABI header and exported-symbol inventory",
    "interpreter-mode runtime startup evidence",
    "independent child-process launch evidence",
    "App migration to VulpraEngineKit protocols",
    "removal of old GeckoView and Helper targets",
    "package workflow update for the independent artifact",
    "simulator navigation evidence",
    "physical-device and JIT evidence",
]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-cutover", action="store_true")
    args = parser.parse_args(argv)
    data = json.loads(OWNERSHIP.read_text(encoding="utf-8"))
    if data.get("state") != "staged":
        print("FAIL: Phase A ownership state must remain staged", file=sys.stderr)
        return 1
    app_imports_old_adapter = any(
        "import GeckoView" in path.read_text(encoding="utf-8")
        for path in (ROOT / "App").rglob("*.swift")
    )
    if not app_imports_old_adapter:
        print("FAIL: staged readiness gate cannot find the temporary adapter", file=sys.stderr)
        return 1
    print("Phase A cutover readiness: NOT READY")
    for blocker in BLOCKERS:
        print(f"- {blocker}")
    print("- runtime fallback remains prohibited; staged GeckoView is temporary ownership only")
    return 2 if args.require_cutover else 0


if __name__ == "__main__":
    raise SystemExit(main())
