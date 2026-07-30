#!/usr/bin/env python3
"""Package a native Gecko dist tree as a deterministic Vulpra v5 artifact."""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile
from typing import Iterable


ROOT = Path(__file__).resolve().parents[2]
PRODUCER_REPOSITORY = "https://github.com/Gjcgghgcbbjj/vulpra-browser"
HEADERS = (
    "GeckoView/GeckoViewSwiftSupport.h",
    "GeckoView/IOSBootstrap.h",
)


class PackageError(ValueError):
    pass


def fail(message: str) -> None:
    raise PackageError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def required_environment(name: str, pattern: str | None = None) -> str:
    value = os.environ.get(name, "")
    if not value:
        fail(f"{name} is required")
    if pattern is not None and re.fullmatch(pattern, value) is None:
        fail(f"{name} is invalid")
    return value


def resolve_build_identity(platform: str) -> tuple[str, str]:
    xcode = os.environ.get("VULPRA_XCODE_BUILD")
    sdk = os.environ.get("VULPRA_SDK_BUILD")
    if xcode and sdk:
        return xcode, sdk
    try:
        xcode_output = subprocess.check_output(["xcodebuild", "-version"], text=True)
        sdk_output = subprocess.check_output(
            ["xcrun", "--sdk", platform, "--show-sdk-build-version"], text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"cannot resolve Xcode/SDK build identity: {error}")
    match = re.search(r"^Build version (\S+)$", xcode_output, re.MULTILINE)
    if match is None or not sdk_output:
        fail("cannot parse Xcode/SDK build identity")
    return match.group(1), sdk_output


def ensure_regular_file(
    path: Path, label: str, *, allowed_symlink_root: Path | None = None
) -> Path:
    if not path.is_file():
        fail(f"missing or unsafe {label}: {path}")
    if not path.is_symlink():
        return path
    if allowed_symlink_root is None:
        fail(f"missing or unsafe {label}: {path}")
    resolved = path.resolve(strict=True)
    root = allowed_symlink_root.resolve(strict=True)
    if not resolved.is_file() or not resolved.is_relative_to(root):
        fail(f"symlinked {label} resolves outside Gecko source: {path}")
    return resolved


def resource_files(dist: Path) -> Iterable[tuple[str, Path]]:
    bin_root = dist / "bin"
    for path in sorted(bin_root.rglob("*")):
        if not path.is_file() or path.name == "XUL" or path.suffix == ".dylib":
            continue
        relative = path.relative_to(bin_root).as_posix()
        yield f"runtime/resources/{relative}", path


def add_payload(
    payload: dict[str, Path], archive_path: str, source: Path,
    *, allowed_symlink_root: Path | None = None,
) -> None:
    source = ensure_regular_file(
        source, archive_path, allowed_symlink_root=allowed_symlink_root
    )
    if archive_path in payload:
        fail(f"duplicate artifact path: {archive_path}")
    payload[archive_path] = source


def make_manifest(args: argparse.Namespace, payload: dict[str, Path]) -> dict[str, object]:
    contract = json.loads(args.contract.read_text(encoding="utf-8"))
    series_path = ROOT / contract["patchSeries"]
    xcode_build, sdk_build = resolve_build_identity(args.platform)
    github_sha = os.environ.get("GITHUB_SHA")
    github_run_id = os.environ.get("GITHUB_RUN_ID")
    in_ci = bool(os.environ.get("GITHUB_ACTIONS"))
    if in_ci:
        producer_commit = required_environment("GITHUB_SHA", r"[0-9a-f]{40}")
        workflow_run_id = int(required_environment("GITHUB_RUN_ID", r"[1-9][0-9]*"))
    else:
        producer_commit = github_sha or "0" * 40
        workflow_run_id = int(github_run_id or "0")
        if re.fullmatch(r"[0-9a-f]{40}", producer_commit) is None or workflow_run_id < 0:
            fail("local producer identity is invalid")

    files = []
    for relative, source in sorted(payload.items()):
        content = source.read_bytes()
        files.append({
            "path": relative,
            "size": len(content),
            "sha256": hashlib.sha256(content).hexdigest(),
        })
    prefix = (
        "vulpra-gecko-ios-arm64-v5-" if args.platform == "iphoneos"
        else "vulpra-gecko-ios-simulator-native-arm64-v5-"
    )
    manifest: dict[str, object] = {
        "formatVersion": 5,
        "artifactId": "",
        "abiVersion": "gecko-ios-v5-abi-1",
        "source": contract["upstream"],
        "patchSet": {
            "series": contract["patchSeries"],
            "sha256": sha256(series_path),
        },
        "producer": {
            "repository": PRODUCER_REPOSITORY,
            "commit": producer_commit,
            "workflowRunId": workflow_run_id,
        },
        "configurationSHA256": sha256(args.contract),
        "build": {
            "mozconfigSHA256": sha256(args.mozconfig),
            "xcodeBuild": xcode_build,
            "sdkBuild": sdk_build,
            "platform": args.platform,
            "targetTriple": contract["targets"][args.platform],
            "architecture": "arm64",
            "deploymentTarget": contract["deploymentTarget"],
        },
        "licenses": ["licenses/MPL-2.0.txt"],
        "notices": ["licenses/FIREFOX-THIRD-PARTY.html"],
        "files": files,
    }
    identity = copy.deepcopy(manifest)
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode()
    manifest["artifactId"] = prefix + hashlib.sha256(canonical).hexdigest()
    return manifest


def write_archive(output: Path, payload: dict[str, Path], manifest: dict[str, object]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest_bytes = (json.dumps(manifest, indent=2) + "\n").encode()
    with output.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                items: list[tuple[str, bytes, int]] = [("manifest.json", manifest_bytes, 0o644)]
                for relative, source in payload.items():
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--platform", required=True, choices=("iphoneos", "iphonesimulator"))
    parser.add_argument("--dist", required=True, type=Path)
    parser.add_argument("--mozconfig", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.contract = args.contract.resolve()
    args.dist = args.dist.resolve()
    args.mozconfig = args.mozconfig.resolve()
    args.output = args.output.resolve()

    try:
        verification = subprocess.run([
            "python3", str(ROOT / "Tools/GeckoProducer/verify-producer.py"),
            "--contract", str(args.contract),
        ], check=False)
        if verification.returncode != 0:
            return verification.returncode
        ensure_regular_file(args.mozconfig, "mozconfig")
        source = args.mozconfig.parent
        payload: dict[str, Path] = {}
        add_payload(
            payload, "runtime/bin/XUL", args.dist / "bin/XUL",
            allowed_symlink_root=source,
        )
        dylibs = sorted(set((args.dist / "bin").glob("*.dylib")) |
                        set((args.dist / "lib").glob("*.dylib")))
        if not dylibs:
            fail("Gecko dist contains no dylibs")
        for dylib in dylibs:
            add_payload(
                payload, f"runtime/lib/{dylib.name}", dylib,
                allowed_symlink_root=source,
            )
        for header in HEADERS:
            add_payload(
                payload, f"runtime/include/{header}", args.dist / "include" / header,
                allowed_symlink_root=source,
            )
        for relative, resource in resource_files(args.dist):
            add_payload(
                payload, relative, resource, allowed_symlink_root=source
            )

        license_candidates = (source / "LICENSE", source / "MPL-2.0.txt")
        license_path = next((path for path in license_candidates if path.is_file()), None)
        if license_path is None:
            fail("Firefox source license is missing")
        notice_candidates = (
            source / "toolkit/content/license.html",
            args.dist / "bin/license.html",
        )
        notice_path = next((path for path in notice_candidates if path.is_file()), None)
        if notice_path is None:
            fail("Firefox third-party notice is missing")
        add_payload(payload, "licenses/MPL-2.0.txt", license_path)
        add_payload(payload, "licenses/FIREFOX-THIRD-PARTY.html", notice_path)

        manifest = make_manifest(args, payload)
        write_archive(args.output, payload, manifest)
    except (OSError, ValueError, PackageError) as error:
        print(f"gecko-package-error: {error}", file=sys.stderr)
        return 1

    print(f"PASS: packaged {manifest['artifactId']} at {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
