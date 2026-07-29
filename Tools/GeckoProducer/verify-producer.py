#!/usr/bin/env python3
"""Validate repository-owned Gecko producer inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
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
PATCH_FORBIDDEN_TOKENS = REQUIRED_FORBIDDEN_TOKENS | {
    "RuntimeJITCoordinator",
    "childProcessDidStartWithPID",
    "ptrace",
    "task_for_pid",
}
SERIES_FIELDS = {"schemaVersion", "patches"}
PATCH_FIELDS = {"order", "path", "sha256", "owner", "purpose", "upstreamPaths"}


class ContractError(ValueError):
    pass


def object_without_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path, owner: str = "contract") -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"),
                           object_pairs_hook=object_without_duplicates)
    except (OSError, UnicodeError, json.JSONDecodeError, ContractError) as error:
        raise ContractError(f"cannot load {owner} {path}: {error}") from error
    if not isinstance(value, dict):
        raise ContractError(f"{owner} root must be an object")
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


def safe_relative_path(value: Any, field: str) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        raise ContractError(f"{field} must be a nonempty string")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise ContractError(f"{field} must be a safe relative path")
    if str(path) != value:
        raise ContractError(f"{field} must use normalized POSIX separators")
    return path


def patch_upstream_paths(contents: str, patch_path: str) -> list[str]:
    paths: list[str] = []
    for line in contents.splitlines():
        if not line.startswith("diff --git "):
            continue
        match = re.fullmatch(r"diff --git a/(\S+) b/(\S+)", line)
        if match is None or match.group(1) != match.group(2):
            raise ContractError(f"unsupported diff header in {patch_path}: {line}")
        upstream_path = match.group(1)
        safe_relative_path(upstream_path, f"{patch_path} upstream path")
        paths.append(upstream_path)
    if not paths:
        raise ContractError(f"patch contains no diff headers: {patch_path}")
    if len(paths) != len(set(paths)):
        raise ContractError(f"patch contains duplicate upstream paths: {patch_path}")
    return paths


def validate_series(contract: dict[str, Any], root: Path) -> None:
    series_relative = safe_relative_path(contract["patchSeries"], "patchSeries")
    resolved_root = root.resolve()
    series_path = (resolved_root / Path(*series_relative.parts)).resolve()
    if resolved_root not in series_path.parents:
        raise ContractError("patchSeries resolves outside repository root")
    series = load_json(series_path, "patch series")
    require_exact_fields(series, SERIES_FIELDS, "patch series")
    require_integer(series["schemaVersion"], 1, "patch series schemaVersion")
    entries = series["patches"]
    if not isinstance(entries, list) or not entries:
        raise ContractError("patches must be a nonempty array")

    expected_orders = list(range(1, len(entries) + 1))
    actual_orders: list[Any] = []
    declared_paths: list[str] = []
    series_directory = series_path.parent
    for index, entry in enumerate(entries, start=1):
        if not isinstance(entry, dict):
            raise ContractError(f"patch entry {index} must be an object")
        require_exact_fields(entry, PATCH_FIELDS, f"patch entry {index}")
        order = entry["order"]
        if isinstance(order, bool) or not isinstance(order, int):
            raise ContractError(f"patch entry {index} order must be an integer")
        actual_orders.append(order)

        relative = safe_relative_path(entry["path"], f"patch entry {index} path")
        if relative.suffix != ".patch":
            raise ContractError(f"patch entry {index} path must end in .patch")
        declared = str(relative)
        if declared in declared_paths:
            raise ContractError(f"duplicate patch path: {declared}")
        declared_paths.append(declared)

        patch_path = (series_directory / Path(*relative.parts)).resolve()
        if series_directory.resolve() not in patch_path.parents:
            raise ContractError(f"patch path resolves outside series directory: {declared}")
        if not patch_path.is_file() or patch_path.is_symlink():
            raise ContractError(f"missing patch file: {declared}")
        patch_bytes = patch_path.read_bytes()
        digest = entry["sha256"]
        if not isinstance(digest, str) or re.fullmatch(r"[0-9a-f]{64}", digest) is None:
            raise ContractError(f"patch entry {index} sha256 must be 64 lowercase hex characters")
        if hashlib.sha256(patch_bytes).hexdigest() != digest:
            raise ContractError(f"patch digest mismatch: {declared}")
        try:
            contents = patch_bytes.decode("utf-8")
        except UnicodeDecodeError as error:
            raise ContractError(f"patch is not UTF-8: {declared}") from error
        for token in sorted(PATCH_FORBIDDEN_TOKENS):
            if token in contents:
                raise ContractError(f"forbidden runtime token {token!r} in {declared}")

        if entry["owner"] != "engine-platform":
            raise ContractError(f"patch entry {index} owner must be engine-platform")
        purpose = entry["purpose"]
        if (not isinstance(purpose, str) or len(purpose.strip()) < 24
                or purpose.strip().casefold() == "ios patch"):
            raise ContractError(f"patch entry {index} must have a specific purpose")
        upstream_paths = require_string_list(
            entry["upstreamPaths"], f"patch entry {index} upstreamPaths"
        )
        for upstream_path in upstream_paths:
            safe_relative_path(upstream_path, f"patch entry {index} upstreamPaths")
        actual_upstream_paths = patch_upstream_paths(contents, declared)
        if upstream_paths != actual_upstream_paths:
            raise ContractError(
                f"upstreamPaths mismatch for {declared}: "
                f"declared {upstream_paths!r}, actual {actual_upstream_paths!r}"
            )

    if actual_orders != expected_orders:
        raise ContractError(
            f"patch orders must be contiguous 1...{len(entries)} in series order"
        )
    actual_paths = sorted(
        path.relative_to(series_directory).as_posix()
        for path in series_directory.rglob("*.patch")
        if path.is_file()
    )
    if sorted(declared_paths) != actual_paths:
        missing = sorted(set(declared_paths) - set(actual_paths))
        undeclared = sorted(set(actual_paths) - set(declared_paths))
        detail = []
        if missing:
            detail.append("missing: " + ", ".join(missing))
        if undeclared:
            detail.append("undeclared: " + ", ".join(undeclared))
        raise ContractError("patch file set mismatch (" + "; ".join(detail) + ")")


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--contract-only", type=Path)
    mode.add_argument("--contract", type=Path)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        contract_path = args.contract_only or args.contract
        contract = load_json(contract_path)
        validate_contract(contract)
        if args.contract is not None:
            validate_series(contract, args.root)
    except ContractError as error:
        print(f"gecko-producer-v5-error: {error}", file=sys.stderr)
        return 1
    if args.contract is not None:
        print("PASS: Gecko producer v5 patch series")
    else:
        print("PASS: Gecko producer v5 contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
