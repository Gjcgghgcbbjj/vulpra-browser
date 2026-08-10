#!/usr/bin/env python3
"""Apply the verified Gecko v5 series atomically to its pinned source."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    raise SystemExit(f"gecko-apply-error: {message}")


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=capture, check=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()

    root = args.root.resolve()
    contract_path = args.contract.resolve()
    verification = run([
        "python3", str(root / "Tools/GeckoProducer/verify-producer.py"),
        "--contract", str(contract_path), "--root", str(root),
    ], capture=True)
    if verification.returncode != 0:
        sys.stderr.write(verification.stderr or verification.stdout)
        return verification.returncode

    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    source = args.source.resolve()
    if not (source / ".git").exists():
        fail(f"source is not a Git checkout: {source}")
    head = run(["git", "-C", str(source), "rev-parse", "HEAD"], capture=True)
    if head.returncode != 0 or head.stdout.strip() != contract["upstream"]["commit"]:
        fail("source HEAD does not match the pinned upstream commit")
    status = run(["git", "-C", str(source), "status", "--porcelain"], capture=True)
    if status.returncode != 0 or status.stdout:
        fail("source checkout must be clean before applying patches")

    series_path = root / contract["patchSeries"]
    series = json.loads(series_path.read_text(encoding="utf-8"))
    patches = [str(series_path.parent / entry["path"]) for entry in series["patches"]]
    # Apply one patch at a time. A one-shot `git apply --check` validates
    # every patch against the pristine tree, which rejects series where a
    # later patch's context depends on an earlier patch touching the same
    # file (e.g. the real-device JIT gate, order 249, layered on the v5
    # IOSBootstrap.mm and GeckoChildProcessHost.cpp patches). Applying
    # sequentially validates each patch against the state produced by its
    # predecessors; on failure the already-applied patches are rolled back.
    applied_patches: list[str] = []
    for patch in patches:
        applied = run(["git", "-C", str(source), "apply", patch], capture=True)
        if applied.returncode != 0:
            for applied_patch in reversed(applied_patches):
                run(["git", "-C", str(source), "apply", "-R", applied_patch],
                    capture=True)
            sys.stderr.write(applied.stderr or applied.stdout)
            fail(f"patch series does not apply cleanly (at {patch})")
        applied_patches.append(patch)

    print(f"PASS: applied {len(patches)} Gecko v5 patches")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
