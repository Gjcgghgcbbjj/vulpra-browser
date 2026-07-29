#!/usr/bin/env python3
"""Validate repository-owned Gecko producer inputs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Any


UPSTREAM_REPOSITORY = "https://github.com/mozilla-firefox/firefox"
UPSTREAM_COMMIT = "27b462b22705a8860f7ab0d33aa5b4b658ae5932"
PATCH_SERIES = "Engine/GeckoPatches/v5/series.json"
TARGETS = {
    "iphoneos": "aarch64-apple-ios",
    "iphonesimulator": "aarch64-apple-ios-sim",
}
REQUIRED_EXPORTS = {"_MainProcessInit", "_GeckoViewOpenWindow", "_ChildProcessInit"}
REQUIRED_FORBIDDEN_TOKENS = {
    "jit-ready-fd",
    "ReportJITStatusForChild",
    "WaitForJITReadySignal",
}


class ContractError(ValueError):
    pass


def object_without_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"),
                           object_pairs_hook=object_without_duplicates)
    except (OSError, UnicodeError, json.JSONDecodeError, ContractError) as error:
        raise ContractError(f"cannot load contract {path}: {error}") from error
    if not isinstance(value, dict):
        raise ContractError("contract root must be an object")
    return value


def require_exact_fields(value: dict[str, Any], expected: set[str], owner: str) -> None:
    actual = set(value)
    missing = sorted(expected - actual)
    unknown = sorted(actual - expected)
    if missing:
        raise ContractError(f"{owner} missing fields: {', '.join(missing)}")
    if unknown:
        raise ContractError(f"{owner} unknown fields: {', '.join(unknown)}")


def require_integer(value: Any, expected: int, field: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value != expected:
        raise ContractError(f"{field} must be integer {expected}")


def require_string_list(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not value:
        raise ContractError(f"{field} must be a nonempty array")
    if not all(isinstance(item, str) and item for item in value):
        raise ContractError(f"{field} must contain nonempty strings")
    if len(value) != len(set(value)):
        raise ContractError(f"{field} contains duplicates")
    return value


def validate_contract(contract: dict[str, Any]) -> None:
    require_exact_fields(
        contract,
        {
            "schemaVersion",
            "artifactFormatVersion",
            "upstream",
            "patchSeries",
            "deploymentTarget",
            "targets",
            "requiredExports",
            "forbiddenRuntimeTokens",
        },
        "contract",
    )
    require_integer(contract["schemaVersion"], 1, "schemaVersion")
    require_integer(contract["artifactFormatVersion"], 5, "artifactFormatVersion")

    upstream = contract["upstream"]
    if not isinstance(upstream, dict):
        raise ContractError("upstream must be an object")
    require_exact_fields(upstream, {"repository", "commit"}, "upstream")
    if upstream["repository"] != UPSTREAM_REPOSITORY:
        raise ContractError(f"upstream.repository must be {UPSTREAM_REPOSITORY}")
    commit = upstream["commit"]
    if not isinstance(commit, str) or re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise ContractError("upstream.commit must be 40 lowercase hex characters")
    if commit != UPSTREAM_COMMIT:
        raise ContractError(f"upstream.commit must remain pinned to {UPSTREAM_COMMIT}")

    patch_series = contract["patchSeries"]
    if patch_series != PATCH_SERIES:
        raise ContractError(f"patchSeries must be {PATCH_SERIES}")
    path = PurePosixPath(patch_series)
    if path.is_absolute() or ".." in path.parts:
        raise ContractError("patchSeries must be a safe repository-relative path")
    if contract["deploymentTarget"] != "15.0":
        raise ContractError("deploymentTarget must be 15.0")

    targets = contract["targets"]
    if not isinstance(targets, dict):
        raise ContractError("targets must be an object")
    require_exact_fields(targets, set(TARGETS), "targets")
    values = list(targets.values())
    if len(values) != len(set(values)):
        raise ContractError("target triples must be unique")
    for platform, expected in TARGETS.items():
        if targets[platform] != expected:
            raise ContractError(f"unexpected target triple for {platform}: {targets[platform]!r}")

    exports = require_string_list(contract["requiredExports"], "requiredExports")
    missing_exports = sorted(REQUIRED_EXPORTS - set(exports))
    if missing_exports:
        raise ContractError(f"requiredExports missing required values: {', '.join(missing_exports)}")

    forbidden = require_string_list(contract["forbiddenRuntimeTokens"],
                                    "forbiddenRuntimeTokens")
    missing_tokens = sorted(REQUIRED_FORBIDDEN_TOKENS - set(forbidden))
    if missing_tokens:
        raise ContractError(
            "forbiddenRuntimeTokens missing required values: " + ", ".join(missing_tokens)
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract-only", type=Path, required=True)
    args = parser.parse_args()
    try:
        validate_contract(load_json(args.contract_only))
    except ContractError as error:
        print(f"gecko-producer-v5-error: {error}", file=sys.stderr)
        return 1
    print("PASS: Gecko producer v5 contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
