#!/usr/bin/env python3
"""Normalize a native Gecko iOS Simulator dist into artifact v4."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import stat
import sys


ARTIFACT_PREFIX = "vulpra-gecko-ios-simulator-arm64-v4-"
ABI_HEADERS = (
    "GeckoViewRuntimeSupport.h",
    "GeckoViewSwiftSupport.h",
    "IOSBootstrap.h",
)
BUILD_ONLY_ROOT_FILES = {
    ".lldbinit",
    ".mkdir.done",
    ".purgecaches",
    "certutil",
    "nsinstall",
    "pingsender",
    "pk12util",
    "plugin-container",
    "xpcshell",
}
TEST_ONLY_ROOTS = {
    "gmp-clearkey",
    "gmp-fake",
    "gmp-fakeopenh264",
}
SOFTWARE_WEBRENDER_PREFERENCE = 'pref("gfx.webrender.software", true);'


class PackagingError(ValueError):
    pass


def fail(message: str) -> None:
    raise PackagingError(message)


def load_json(path: Path, label: str) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError) as error:
        fail(f"invalid {label}: {path}: {error}")
    if not isinstance(value, dict):
        fail(f"{label} must be a JSON object")
    return value


def require_regular_file(path: Path, label: str) -> Path:
    if path.is_symlink() or not path.is_file():
        fail(f"missing regular {label}: {path}")
    return path


def copy_file(source: Path, destination: Path) -> None:
    require_regular_file(source, "input file")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination, follow_symlinks=False)


def validate_inputs(dist: Path, legal_artifact: Path) -> dict[str, object]:
    if not dist.is_dir():
        fail(f"native Simulator dist is not a directory: {dist}")
    manifest = load_json(legal_artifact / "manifest.json", "legal artifact manifest")
    required_keys = {"abiVersion", "source", "build", "licenses", "notices"}
    if not required_keys.issubset(manifest):
        fail("legal artifact manifest is missing identity fields")
    build = manifest.get("build")
    if not isinstance(build, dict) or build.get("architecture") != "arm64":
        fail("legal artifact does not describe the arm64 engine family")

    kernel = require_regular_file(dist / "bin/XUL", "native Simulator XUL")
    content = kernel.read_bytes()
    for token in (b"_MainProcessInit", b"GeckoView.framework"):
        if content.count(token) != 1:
            fail(f"native Simulator XUL has invalid token ownership: {token.decode()}")
    if b"BrowserEngineKit" in content:
        fail("native Simulator XUL still depends on BrowserEngineKit")

    preferences = require_regular_file(
        dist / "bin/defaults/pref/mobile.js", "native Simulator preferences"
    ).read_text(encoding="utf-8")
    if preferences.count(SOFTWARE_WEBRENDER_PREFERENCE) != 1:
        fail("native Simulator preferences must enable software WebRender exactly once")
    for header in ABI_HEADERS:
        require_regular_file(dist / "include/GeckoView" / header, f"ABI header {header}")
    if not list((dist / "bin").glob("*.dylib")):
        fail("native Simulator dist contains no runtime dylibs")
    return manifest


def copy_payload(dist: Path, legal_artifact: Path, output: Path, manifest: dict[str, object]) -> None:
    copy_file(dist / "bin/XUL", output / "runtime/bin/XUL")
    for dylib in sorted((dist / "bin").glob("*.dylib")):
        copy_file(dylib, output / "runtime/lib" / dylib.name)
    for header in ABI_HEADERS:
        copy_file(
            dist / "include/GeckoView" / header,
            output / "runtime/include/GeckoView" / header,
        )

    bin_root = dist / "bin"
    for source in sorted(path for path in bin_root.rglob("*") if path.is_file()):
        relative = source.relative_to(bin_root)
        if source.is_symlink():
            fail(f"symbolic link is forbidden in native Simulator dist: {relative}")
        if len(relative.parts) == 1 and (
            relative.name == "XUL"
            or relative.suffix == ".dylib"
            or relative.name in BUILD_ONLY_ROOT_FILES
        ):
            continue
        if relative.parts[0] in TEST_ONLY_ROOTS or relative.name == ".mkdir.done":
            continue
        if source.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH):
            fail(f"unexpected executable in native Simulator resources: {relative}")
        copy_file(source, output / "runtime/resources" / relative)

    for key in ("licenses", "notices"):
        values = manifest.get(key)
        if not isinstance(values, list) or not values:
            fail(f"legal artifact manifest {key} is invalid")
        for value in values:
            if not isinstance(value, str) or not value.startswith("licenses/"):
                fail(f"legal artifact manifest {key} path is invalid")
            copy_file(legal_artifact / value, output / value)


def write_manifest(output: Path, source_manifest: dict[str, object]) -> str:
    entries = []
    paths = sorted(
        (path.relative_to(output).as_posix(), path)
        for path in output.rglob("*")
        if path.is_file() and path.relative_to(output).as_posix() != "manifest.json"
    )
    for relative, path in paths:
        content = path.read_bytes()
        entries.append({
            "path": relative,
            "size": len(content),
            "sha256": hashlib.sha256(content).hexdigest(),
        })

    source_build = source_manifest["build"]
    manifest = {
        "formatVersion": 4,
        "artifactId": "",
        "abiVersion": source_manifest["abiVersion"],
        "source": source_manifest["source"],
        "build": {
            "xcodeBuild": source_build["xcodeBuild"],
            "sdkBuild": source_build["sdkBuild"],
            "platform": "iphonesimulator",
            "architecture": "arm64",
        },
        "licenses": source_manifest["licenses"],
        "notices": source_manifest["notices"],
        "files": entries,
    }
    canonical = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode("utf-8")
    artifact_id = ARTIFACT_PREFIX + hashlib.sha256(canonical).hexdigest()
    manifest["artifactId"] = artifact_id
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return artifact_id


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Package a native Gecko iOS Simulator dist as artifact v4."
    )
    parser.add_argument("--dist", required=True, type=Path)
    parser.add_argument("--legal-artifact", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.output.exists():
            fail(f"output already exists: {args.output}")
        manifest = validate_inputs(args.dist, args.legal_artifact)
        args.output.mkdir(parents=True)
        copy_payload(args.dist, args.legal_artifact, args.output, manifest)
        artifact_id = write_manifest(args.output, manifest)
    except (PackagingError, OSError, UnicodeDecodeError, KeyError) as error:
        print(f"native-simulator-artifact-error: {error}", file=sys.stderr)
        return 1
    print(f"native-simulator-artifact-ok {artifact_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
