#!/usr/bin/env python3
"""Derive the canonical arm64 Simulator artifact from the verified device artifact."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys


LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2
PLATFORM_IOSSIMULATOR = 7
ARTIFACT_PREFIX = "vulpra-gecko-ios-simulator-arm64-v4-"


class DerivationError(ValueError):
    pass


def fail(message: str) -> None:
    raise DerivationError(message)


def rewrite_build_platform(path: Path) -> None:
    data = bytearray(path.read_bytes())
    if len(data) < 32:
        fail(f"truncated Mach-O: {path}")
    if data[:4] == b"\xcf\xfa\xed\xfe":
        endian = "<"
    elif data[:4] == b"\xfe\xed\xfa\xcf":
        endian = ">"
    else:
        fail(f"not a thin 64-bit Mach-O: {path}")

    command_count = struct.unpack_from(endian + "I", data, 16)[0]
    command_bytes = struct.unpack_from(endian + "I", data, 20)[0]
    command_end = 32 + command_bytes
    if command_end > len(data):
        fail(f"truncated Mach-O commands: {path}")

    offset = 32
    found = 0
    for _ in range(command_count):
        if offset + 8 > command_end:
            fail(f"invalid Mach-O command table: {path}")
        command, size = struct.unpack_from(endian + "II", data, offset)
        if size < 8 or offset + size > command_end:
            fail(f"invalid Mach-O command size: {path}")
        if command == LC_BUILD_VERSION:
            if size < 24:
                fail(f"truncated LC_BUILD_VERSION: {path}")
            platform = struct.unpack_from(endian + "I", data, offset + 8)[0]
            if platform != PLATFORM_IOS:
                fail(f"LC_BUILD_VERSION is not iphoneos in {path}: {platform}")
            struct.pack_into(endian + "I", data, offset + 8, PLATFORM_IOSSIMULATOR)
            found += 1
        offset += size
    if offset != command_end or found != 1:
        fail(f"expected one LC_BUILD_VERSION in {path}, found {found}")
    path.write_bytes(data)


def derive(source: Path, output: Path) -> str:
    manifest_path = source / "manifest.json"
    if not source.is_dir() or not manifest_path.is_file():
        fail("source artifact is missing manifest.json")
    if output.exists():
        fail("output path already exists")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    build = manifest.get("build")
    if not isinstance(build, dict) or build.get("platform") != "iphoneos":
        fail("source manifest platform must be iphoneos")
    if build.get("architecture") != "arm64":
        fail("source manifest architecture must be arm64")
    if manifest.get("formatVersion") != 4:
        fail("source manifest formatVersion must be 4")

    shutil.copytree(source, output, symlinks=True)
    binary_paths = [output / "runtime/bin/XUL", *sorted((output / "runtime/lib").glob("*.dylib"))]
    if len(binary_paths) < 2 or any(not path.is_file() for path in binary_paths):
        fail("source artifact is missing XUL or runtime dylibs")
    for path in binary_paths:
        rewrite_build_platform(path)

    derived = copy.deepcopy(manifest)
    derived["build"]["platform"] = "iphonesimulator"
    files = derived.get("files")
    if not isinstance(files, list):
        fail("source manifest files must be a list")
    declared = set()
    for entry in files:
        relative = entry.get("path") if isinstance(entry, dict) else None
        if not isinstance(relative, str) or relative in declared:
            fail("source manifest contains an invalid or duplicate path")
        declared.add(relative)
        content = (output / relative).read_bytes()
        entry["size"] = len(content)
        entry["sha256"] = hashlib.sha256(content).hexdigest()
    for path in binary_paths:
        relative = path.relative_to(output).as_posix()
        if relative not in declared:
            fail(f"binary is not declared in source manifest: {relative}")

    identity = copy.deepcopy(derived)
    identity["artifactId"] = ""
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    artifact_id = ARTIFACT_PREFIX + hashlib.sha256(canonical).hexdigest()
    derived["artifactId"] = artifact_id
    (output / "manifest.json").write_text(
        json.dumps(derived, indent=2) + "\n", encoding="utf-8"
    )
    return artifact_id


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} SOURCE_ROOT OUTPUT_ROOT")
    try:
        artifact_id = derive(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
    except (DerivationError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"derive-simulator-artifact: {error}") from error
    print(f"simulator-artifact-derived {artifact_id}")


if __name__ == "__main__":
    main()
