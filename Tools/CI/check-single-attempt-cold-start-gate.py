#!/usr/bin/env python3
"""DRAFT: fast single-attempt gate for the repeated A2 cold-start loop.

Mirror of Tools/CI/check-single-attempt-gate.py (R0 navigation rule, user
policy): a repeated stability gate must first PASS a single fresh-launch
attempt before the 2..N loop runs, so a systemic cold-start failure fails in
minutes instead of after >=10 attempts. Reuses the exact per-attempt
validation from summarize-cold-start-gate.py.

Usage: python3 check-single-attempt-cold-start-gate.py --input attempt-01.json
Exit 0 -> proceed with attempts 2..N; nonzero -> stop immediately.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import importlib.util

_SUMMARIZER = Path(__file__).resolve().parent / "summarize-cold-start-gate.py"
_spec = importlib.util.spec_from_file_location("summarize_cold_start_gate", _SUMMARIZER)
_summarizer = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_summarizer)  # type: ignore[union-attr]
GateError, validate_attempt = _summarizer.GateError, _summarizer.validate_attempt


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the first A2 cold-start attempt before the repeated loop.",
    )
    parser.add_argument(
        "--input", required=True, type=Path,
        help="attempt-01.json written by run-simulator-cold-start.sh",
    )
    args = parser.parse_args()
    try:
        attempt = json.loads(args.input.read_text(encoding="utf-8"))
        if int(attempt.get("attempt", 0)) != 1:
            raise GateError("single-attempt evidence must be attempt 1")
        validate_attempt(attempt)
    except (OSError, json.JSONDecodeError, GateError) as error:
        print(f"a2-single-attempt-gate-error: {error}", file=sys.stderr)
        return 1
    print("PASS: A2 single-attempt cold-start gate (attempt 1)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
