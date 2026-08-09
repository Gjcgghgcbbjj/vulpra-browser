#!/usr/bin/env python3
"""Validate a benchmark id selection against Configuration/benchmarks.json.

Used by .github/workflows/benchmark-ci.yml before any benchmark gate run, and
by Tests/IndependentEngine/test_benchmark_contract.py as a portable contract.

Refuses:
  - an empty selection,
  - unknown benchmark ids,
  - benchmarks flagged `requiresJitBackend: true` (JetStream 3.0): the current
    v5 engine disables the JIT backend in every Gecko child process
    (toolkit/xre/IOSBootstrap.mm -> JS::DisableJitBackend ->
    JitOptions.disableJitBackend -> wasm::HasSupport() == false), and those
    suites contain WebAssembly workloads whose failure aborts the whole run,
    so selecting them only burns a guaranteed-failing CI gate.

Pure stdlib; loads the manifest parser shared with benchmark-fixture.py via
importlib (the filename's hyphen prevents a plain module import).
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

_TOOLS_CI = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(
    "vulpra_benchmark_fixture_shared", _TOOLS_CI / "benchmark-fixture.py"
)
benchmark_fixture = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(benchmark_fixture)


def validate_selection(ids: str) -> list[dict[str, object]]:
    if not ids or not any(item.strip() for item in ids.split(",")):
        benchmark_fixture.fail("no benchmark ids selected")
    manifest = benchmark_fixture.load_manifest()
    entries = benchmark_fixture.select_benchmarks(manifest, ids)
    for entry in entries:
        benchmark_id = entry["id"]
        if entry.get("requiresJitBackend") is True:
            notes = entry.get("notes") or ""
            benchmark_fixture.fail(
                f"benchmark {benchmark_id} requires the JIT backend (WebAssembly) "
                f"and cannot pass on the current JIT-disabled engine; refusing to "
                f"run a guaranteed-failing gate. {notes}"
            )
    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ids", required=True,
        help="comma-separated benchmark ids from Configuration/benchmarks.json",
    )
    args = parser.parse_args()
    entries = validate_selection(args.ids)
    print(" ".join(entry["id"] for entry in entries))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
