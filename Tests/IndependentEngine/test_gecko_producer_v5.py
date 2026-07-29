#!/usr/bin/env python3
"""Verify the repository-owned Gecko v5 producer contract."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "Tools/GeckoProducer/verify-producer.py"
CONTRACT = ROOT / "Configuration/gecko-producer-v5.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def valid_contract() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "artifactFormatVersion": 5,
        "upstream": {
            "repository": "https://github.com/mozilla-firefox/firefox",
            "commit": "27b462b22705a8860f7ab0d33aa5b4b658ae5932",
        },
        "patchSeries": "Engine/GeckoPatches/v5/series.json",
        "deploymentTarget": "15.0",
        "targets": {
            "iphoneos": "aarch64-apple-ios",
            "iphonesimulator": "aarch64-apple-ios-sim",
        },
        "requiredExports": ["_MainProcessInit", "_GeckoViewOpenWindow", "_ChildProcessInit"],
        "forbiddenRuntimeTokens": [
            "jit-ready-fd",
            "ReportJITStatusForChild",
            "WaitForJITReadySignal",
        ],
    }


def run_contract(path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VERIFIER), "--contract-only", str(path)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def write_fixture(directory: Path, name: str, payload: dict[str, object]) -> Path:
    path = directory / name
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return path


def main() -> None:
    require(VERIFIER.is_file(), "missing Tools/GeckoProducer/verify-producer.py")
    require(CONTRACT.is_file(), "missing Configuration/gecko-producer-v5.json")

    with tempfile.TemporaryDirectory(prefix="vulpra-gecko-producer-v5-") as temporary:
        fixtures = Path(temporary)
        valid = valid_contract()
        result = run_contract(write_fixture(fixtures, "valid.json", valid))
        require(result.returncode == 0, result.stderr or result.stdout)
        require(result.stdout.strip() == "PASS: Gecko producer v5 contract",
                "valid contract output is not deterministic")

        invalid: list[tuple[str, dict[str, object], str]] = []

        unknown = copy.deepcopy(valid)
        unknown["fallbackArtifact"] = "v4"
        invalid.append(("unknown-field", unknown, "unknown fields"))

        missing = copy.deepcopy(valid)
        del missing["upstream"]["commit"]  # type: ignore[index]
        invalid.append(("missing-commit", missing, "missing fields"))

        malformed_commit = copy.deepcopy(valid)
        malformed_commit["upstream"]["commit"] = "not-a-commit"  # type: ignore[index]
        invalid.append(("malformed-commit", malformed_commit, "40 lowercase hex"))

        duplicate_target = copy.deepcopy(valid)
        duplicate_target["targets"]["iphonesimulator"] = "aarch64-apple-ios"  # type: ignore[index]
        invalid.append(("duplicate-target", duplicate_target, "target triples must be unique"))

        non_ios = copy.deepcopy(valid)
        non_ios["targets"]["iphonesimulator"] = "aarch64-apple-darwin"  # type: ignore[index]
        invalid.append(("non-ios-target", non_ios, "unexpected target triple"))

        duplicate_export = copy.deepcopy(valid)
        duplicate_export["requiredExports"].append("_MainProcessInit")  # type: ignore[union-attr]
        invalid.append(("duplicate-export", duplicate_export, "requiredExports contains duplicates"))

        missing_forbidden = copy.deepcopy(valid)
        missing_forbidden["forbiddenRuntimeTokens"].remove("jit-ready-fd")  # type: ignore[union-attr]
        invalid.append(("missing-forbidden", missing_forbidden, "missing required values"))

        for name, payload, expected in invalid:
            result = run_contract(write_fixture(fixtures, f"{name}.json", payload))
            require(result.returncode != 0, f"invalid fixture passed: {name}")
            require(expected in result.stderr, f"{name} did not report {expected!r}: {result.stderr}")

        duplicate_key = fixtures / "duplicate-key.json"
        duplicate_key.write_text(
            json.dumps(valid).replace('"schemaVersion": 1',
                                      '"schemaVersion": 1, "schemaVersion": 1', 1),
            encoding="utf-8",
        )
        result = run_contract(duplicate_key)
        require(result.returncode != 0 and "duplicate JSON key" in result.stderr,
                "duplicate JSON keys were not rejected")

    result = run_contract(CONTRACT)
    require(result.returncode == 0, result.stderr or result.stdout)
    print("PASS: Gecko producer v5 contract fixtures")


if __name__ == "__main__":
    main()
