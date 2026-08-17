#!/usr/bin/env python3
"""Validate a checksum-pinned Vulpra Gecko kernel artifact."""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "Configuration" / "engine-artifact-v4.json"


class ArtifactError(ValueError):
    pass


def _fail(message: str) -> None:
    raise ArtifactError(message)


def _read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        _fail(f"missing {path.name}")
    except (OSError, json.JSONDecodeError) as error:
        _fail(f"invalid {path.name}: {error}")
    if not isinstance(value, dict):
        _fail(f"{path.name} must contain an object")
    return value


def _normal_path(value: object) -> str:
    if not isinstance(value, str) or not value or value.startswith("/"):
        _fail("manifest paths must be non-empty relative strings")
    if "\\" in value or posixpath.normpath(value) != value or ".." in Path(value).parts:
        _fail(f"manifest path is not normalized: {value!r}")
    return value


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_artifact(root: Path, contract: dict | None = None) -> dict:
    contract = contract or _read_json(CONTRACT_PATH)
    manifest = _read_json(root / contract["manifestFile"])
    if manifest.get("formatVersion") != contract["formatVersion"]:
        _fail("artifact formatVersion must be 4")
    for key in ("artifactKind", "platform", "architecture", "abiVersion", "sourceIdentity", "buildIdentity"):
        if not isinstance(manifest.get(key), str) or not manifest[key]:
            _fail(f"manifest field {key} is required")
    if manifest["artifactKind"] != contract["artifactKind"]:
        _fail("artifact kind does not match the v4 contract")
    if manifest["platform"] != contract["platform"] or manifest["architecture"] != contract["architecture"]:
        _fail("artifact platform or architecture is wrong")
    if not isinstance(manifest.get("licenses"), list) or not manifest["licenses"]:
        _fail("manifest licenses must be a non-empty list")
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        _fail("manifest files must be a non-empty list")

    allowed_roots = tuple(contract["allowedRoots"])
    forbidden_tokens = tuple(token.lower() for token in contract["forbiddenPathTokens"])
    forbidden_exts = tuple(ext.lower() for ext in contract["forbiddenExtensions"])
    seen: set[str] = set()
    kinds: dict[str, int] = {}
    for entry in files:
        if not isinstance(entry, dict):
            _fail("each manifest file entry must be an object")
        relative = _normal_path(entry.get("path"))
        if relative in seen:
            _fail(f"duplicate manifest path: {relative}")
        seen.add(relative)
        if not any(relative == base or relative.startswith(base + "/") for base in allowed_roots):
            _fail(f"file outside allowed roots: {relative}")
        lower = relative.lower()
        forbidden = any(
            (token in lower if token not in {"source", "sources"} else any(
                part.lower() in {"source", "sources"} for part in Path(relative).parts
            ))
            for token in forbidden_tokens
        )
        if forbidden or lower.endswith(forbidden_exts):
            _fail(f"forbidden artifact path: {relative}")
        if relative.startswith("runtime/bin/") and relative != "runtime/bin/XUL":
            _fail(f"unexpected executable in runtime/bin: {relative}")
        path = root / relative
        if path.is_symlink():
            _fail(f"symlink is not allowed: {relative}")
        if not path.is_file():
            _fail(f"manifest file is missing: {relative}")
        actual_size = path.stat().st_size
        if entry.get("size") != actual_size:
            _fail(f"size mismatch: {relative}")
        expected_hash = entry.get("sha256")
        if not isinstance(expected_hash, str) or expected_hash != expected_hash.lower() or len(expected_hash) != 64:
            _fail(f"invalid sha256 for {relative}")
        if _sha256(path) != expected_hash:
            _fail(f"checksum mismatch: {relative}")
        kind = entry.get("kind")
        if not isinstance(kind, str):
            _fail(f"missing kind for {relative}")
        kinds[kind] = kinds.get(kind, 0) + 1

    required = set(contract["requiredFiles"])
    if not required.issubset(seen):
        _fail(f"missing required files: {', '.join(sorted(required - seen))}")
    if kinds.get("dylib", 0) == 0:
        _fail("artifact must contain at least one runtime dylib")
    if kinds.get("header", 0) == 0:
        _fail("artifact must contain at least one ABI header")
    if kinds.get("resource", 0) == 0:
        _fail("artifact must contain at least one runtime resource")
    if kinds.get("notice", 0) == 0:
        _fail("artifact must contain at least one license notice")
    if seen != set(sorted(seen)):
        _fail("manifest files must be sorted by path")
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="artifact root containing manifest.json")
    args = parser.parse_args(argv)
    try:
        manifest = validate_artifact(args.root.resolve())
    except ArtifactError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: Vulpra engine artifact v4 ({manifest['buildIdentity']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
