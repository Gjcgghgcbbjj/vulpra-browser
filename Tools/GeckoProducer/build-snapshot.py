#!/usr/bin/env python3
"""Create and verify a portable snapshot of expensive Gecko build outputs."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = ROOT / "Tools/GeckoProducer/build-runtime.sh"
HEADERS = (
    "GeckoView/GeckoViewSwiftSupport.h",
    "GeckoView/IOSBootstrap.h",
)
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")


class SnapshotError(ValueError):
    pass


def fail(message: str) -> None:
    raise SnapshotError(message)


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path, label: str) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {label}: {error}")
    if not isinstance(value, dict):
        fail(f"{label} must be a JSON object")
    return value


def regular_source(path: Path, source_root: Path, label: str) -> Path:
    if not path.is_file():
        fail(f"missing build snapshot input {label}: {path}")
    resolved = path.resolve(strict=True)
    if path.is_symlink() and not resolved.is_relative_to(source_root):
        fail(f"symlinked {label} resolves outside Gecko source: {path}")
    if not resolved.is_file():
        fail(f"unsafe build snapshot input {label}: {path}")
    return resolved


def snapshot_inputs(source: Path, platform: str, target: str) -> dict[str, Path]:
    dist = source / f"obj-{target}/dist"
    inputs: dict[str, Path] = {}

    def add(archive_path: str, path: Path) -> None:
        if archive_path in inputs:
            fail(f"duplicate build snapshot path: {archive_path}")
        inputs[archive_path] = regular_source(path, source, archive_path)

    bin_root = dist / "bin"
    if not bin_root.is_dir():
        fail(f"Gecko dist bin directory is missing: {bin_root}")
    for path in sorted(bin_root.rglob("*")):
        if path.is_file():
            add(f"dist/bin/{path.relative_to(bin_root).as_posix()}", path)
    for path in sorted((dist / "lib").glob("*.dylib")):
        add(f"dist/lib/{path.name}", path)
    for header in HEADERS:
        add(f"dist/include/{header}", dist / "include" / header)

    add(f".mozconfig-vulpra-{platform}", source / f".mozconfig-vulpra-{platform}")
    license_path = next(
        (path for path in (source / "LICENSE", source / "MPL-2.0.txt") if path.is_file()),
        None,
    )
    if license_path is None:
        fail("Firefox source license is missing")
    add("LICENSE", license_path)
    notice_path = next(
        (path for path in (
            source / "toolkit/content/license.html",
            dist / "bin/license.html",
        ) if path.is_file()),
        None,
    )
    if notice_path is None:
        fail("Firefox third-party notice is missing")
    add("toolkit/content/license.html", notice_path)
    return inputs


def build_identity(
    contract_path: Path, platform: str, xcode_build: str, sdk_build: str,
    mozconfig_sha256: str,
) -> dict[str, object]:
    if not xcode_build.strip() or not sdk_build.strip():
        fail("build snapshot toolchain identity is empty")
    contract = load_json(contract_path, "producer contract")
    target = contract.get("targets", {}).get(platform) if isinstance(contract.get("targets"), dict) else None
    if not isinstance(target, str) or not target:
        fail(f"producer contract has no target for {platform}")
    series = contract.get("patchSeries")
    if not isinstance(series, str) or not series:
        fail("producer contract patch series is invalid")
    series_path = ROOT / series
    upstream = contract.get("upstream")
    if not isinstance(upstream, dict):
        fail("producer contract upstream identity is invalid")
    identity: dict[str, object] = {
        "source": upstream,
        "patchSet": {"series": series, "sha256": sha256(series_path)},
        "configurationSHA256": sha256(contract_path),
        "buildScriptSHA256": sha256(BUILD_SCRIPT),
        "platform": platform,
        "targetTriple": target,
        "deploymentTarget": contract.get("deploymentTarget"),
        "mozconfigSHA256": mozconfig_sha256,
        "toolchain": {"xcodeBuild": xcode_build, "sdkBuild": sdk_build},
    }
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode()
    identity["fingerprint"] = sha256_bytes(canonical)
    return identity


def write_archive(output: Path, manifest: dict[str, object], inputs: dict[str, Path]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest_bytes = (json.dumps(manifest, indent=2) + "\n").encode()
    temporary = output.with_name(f".{output.name}.tmp")
    try:
        with temporary.open("wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
                with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                    items: list[tuple[str, bytes, int]] = [("snapshot.json", manifest_bytes, 0o644)]
                    for relative, source in inputs.items():
                        mode = 0o755 if source.stat().st_mode & stat.S_IXUSR else 0o644
                        items.append((relative, source.read_bytes(), mode))
                    for relative, content, mode in sorted(items):
                        info = tarfile.TarInfo(relative)
                        info.size = len(content)
                        info.mode = mode
                        info.mtime = 0
                        info.uid = info.gid = 0
                        info.uname = info.gname = ""
                        archive.addfile(info, io.BytesIO(content))
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)


def create(args: argparse.Namespace) -> None:
    source = args.source.resolve(strict=True)
    if not source.is_dir():
        fail(f"Gecko source directory is missing: {source}")
    contract = load_json(args.contract, "producer contract")
    target = contract.get("targets", {}).get(args.platform)
    if not isinstance(target, str):
        fail(f"producer contract has no target for {args.platform}")
    inputs = snapshot_inputs(source, args.platform, target)
    mozconfig_name = f".mozconfig-vulpra-{args.platform}"
    identity = build_identity(
        args.contract, args.platform, args.xcode_build, args.sdk_build,
        sha256(inputs[mozconfig_name]),
    )
    if COMMIT_PATTERN.fullmatch(args.producer_commit) is None or args.producer_run_id < 1:
        fail("snapshot producer identity is invalid")
    files = []
    for relative, path in sorted(inputs.items()):
        content = path.read_bytes()
        files.append({
            "path": relative,
            "size": len(content),
            "sha256": sha256_bytes(content),
            "executable": bool(path.stat().st_mode & stat.S_IXUSR),
        })
    manifest = {
        "formatVersion": 1,
        "buildIdentity": identity,
        "producer": {
            "commit": args.producer_commit,
            "workflowRunId": args.producer_run_id,
        },
        "files": files,
    }
    write_archive(args.output, manifest, inputs)


def safe_member_name(name: str) -> str:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        fail(f"unsafe build snapshot member: {name}")
    return path.as_posix()


def archive_contents(archive_path: Path) -> tuple[dict[str, object], dict[str, tuple[bytes, int]]]:
    try:
        with tarfile.open(archive_path, "r:gz") as archive:
            members = archive.getmembers()
            names: set[str] = set()
            contents: dict[str, tuple[bytes, int]] = {}
            for member in members:
                name = safe_member_name(member.name)
                if name in names:
                    fail(f"duplicate build snapshot member: {name}")
                names.add(name)
                if not member.isfile() or member.issym() or member.islnk():
                    fail(f"non-regular build snapshot member: {name}")
                source = archive.extractfile(member)
                if source is None:
                    fail(f"cannot read build snapshot member: {name}")
                contents[name] = (source.read(), member.mode)
    except (OSError, tarfile.TarError) as error:
        fail(f"cannot read build snapshot: {error}")
    manifest_item = contents.pop("snapshot.json", None)
    if manifest_item is None:
        fail("build snapshot manifest is missing")
    try:
        manifest = json.loads(manifest_item[0].decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"build snapshot manifest is invalid: {error}")
    if not isinstance(manifest, dict):
        fail("build snapshot manifest must be an object")
    return manifest, contents


def verify_manifest(args: argparse.Namespace, manifest: dict[str, object], contents: dict[str, tuple[bytes, int]]) -> None:
    if set(manifest) != {"formatVersion", "buildIdentity", "producer", "files"} or manifest.get("formatVersion") != 1:
        fail("build snapshot manifest shape is invalid")
    identity = manifest.get("buildIdentity")
    if not isinstance(identity, dict):
        fail("build snapshot identity is invalid")
    mozconfig_name = f".mozconfig-vulpra-{args.platform}"
    mozconfig_item = contents.get(mozconfig_name)
    if mozconfig_item is None:
        fail("build snapshot mozconfig is missing")
    expected = build_identity(
        args.contract, args.platform, args.xcode_build, args.sdk_build,
        sha256_bytes(mozconfig_item[0]),
    )
    if identity.get("toolchain") != expected["toolchain"]:
        fail("build snapshot toolchain identity mismatch")
    if identity != expected:
        fail("build snapshot input fingerprint mismatch")
    producer = manifest.get("producer")
    if (not isinstance(producer, dict)
            or set(producer) != {"commit", "workflowRunId"}
            or not isinstance(producer.get("commit"), str)
            or COMMIT_PATTERN.fullmatch(producer["commit"]) is None
            or type(producer.get("workflowRunId")) is not int
            or producer["workflowRunId"] < 1):
        fail("build snapshot producer identity is invalid")
    if producer["workflowRunId"] != args.expected_producer_run_id:
        fail("build snapshot producer run identity mismatch")
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        fail("build snapshot file inventory is invalid")
    declared: set[str] = set()
    for entry in files:
        if not isinstance(entry, dict) or set(entry) != {"path", "size", "sha256", "executable"}:
            fail("build snapshot file entry is invalid")
        path = safe_member_name(entry.get("path")) if isinstance(entry.get("path"), str) else fail("build snapshot file path is invalid")
        if path in declared:
            fail(f"duplicate build snapshot file declaration: {path}")
        declared.add(path)
        item = contents.get(path)
        if item is None:
            fail(f"declared build snapshot file is missing: {path}")
        content, mode = item
        if (entry.get("size") != len(content)
                or not isinstance(entry.get("sha256"), str)
                or SHA256_PATTERN.fullmatch(entry["sha256"]) is None
                or entry["sha256"] != sha256_bytes(content)
                or type(entry.get("executable")) is not bool
                or entry["executable"] != bool(mode & stat.S_IXUSR)):
            fail(f"build snapshot content identity mismatch: {path}")
    if declared != set(contents):
        fail("build snapshot contains undeclared files")


def extract(args: argparse.Namespace) -> None:
    if args.output.exists():
        fail(f"build snapshot output already exists: {args.output}")
    manifest, contents = archive_contents(args.archive)
    verify_manifest(args, manifest, contents)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{args.output.name}-", dir=args.output.parent))
    try:
        for relative, (content, mode) in contents.items():
            destination = temporary / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
            destination.chmod(0o755 if mode & stat.S_IXUSR else 0o644)
        os.replace(temporary, args.output)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("create", "extract"):
        child = subparsers.add_parser(command)
        child.add_argument("--contract", required=True, type=Path)
        child.add_argument("--platform", required=True, choices=("iphoneos", "iphonesimulator"))
        child.add_argument("--xcode-build", required=True)
        child.add_argument("--sdk-build", required=True)
        if command == "create":
            child.add_argument("--source", required=True, type=Path)
            child.add_argument("--producer-commit", required=True)
            child.add_argument("--producer-run-id", required=True, type=int)
            child.add_argument("--output", required=True, type=Path)
        else:
            child.add_argument("--archive", required=True, type=Path)
            child.add_argument("--output", required=True, type=Path)
            child.add_argument("--expected-producer-run-id", required=True, type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.contract = args.contract.resolve()
    args.output = args.output.resolve()
    if args.command == "extract":
        args.archive = args.archive.resolve()
    try:
        if args.command == "create":
            create(args)
        else:
            extract(args)
    except (OSError, SnapshotError, ValueError) as error:
        print(f"gecko-build-snapshot-error: {error}", file=sys.stderr)
        return 1
    print(f"PASS: Gecko build snapshot {args.command} platform={args.platform}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
