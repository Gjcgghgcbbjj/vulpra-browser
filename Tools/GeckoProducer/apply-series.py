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
    check = run(["git", "-C", str(source), "apply", "--check", *patches], capture=True)
    if check.returncode != 0:
        sys.stderr.write(check.stderr or check.stdout)
        fail("patch series does not apply cleanly")
    applied = run(["git", "-C", str(source), "apply", *patches], capture=True)
    if applied.returncode != 0:
        sys.stderr.write(applied.stderr or applied.stdout)
        fail("patch series application failed")

    print(f"PASS: applied {len(patches)} Gecko v5 patches")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
