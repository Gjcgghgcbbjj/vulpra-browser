#!/usr/bin/env python3
"""Atomically promote one verified native Gecko v5 device/Simulator pair."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shlex
import subprocess
import sys
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "Tools/Engine/verify-engine-artifact.py"
CONTRACTS = {
    "iphoneos": ROOT / "Configuration/engine-artifact-device-v5.json",
    "iphonesimulator": ROOT / "Configuration/engine-artifact-simulator-v5.json",
}


class PromotionError(ValueError):
    pass


def fail(message: str) -> None:
    raise PromotionError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract_archive(archive_path: Path, destination: Path) -> None:
    if not archive_path.is_file() or archive_path.is_symlink():
        fail(f"missing or unsafe artifact archive: {archive_path}")
    seen: set[str] = set()
    try:
        with tarfile.open(archive_path, "r:gz") as archive:
            for member in archive.getmembers():
                path = PurePosixPath(member.name)
                if (not member.isfile() or path.is_absolute() or ".." in path.parts
                        or "." in path.parts or str(path) != member.name):
                    fail(f"unsafe artifact archive member: {member.name}")
                if member.name in seen:
                    fail(f"duplicate artifact archive member: {member.name}")
                seen.add(member.name)
                source = archive.extractfile(member)
                if source is None:
                    fail(f"unreadable artifact archive member: {member.name}")
                target = destination / member.name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read())
                target.chmod(member.mode & 0o777)
    except (OSError, tarfile.TarError) as error:
        fail(f"invalid artifact archive {archive_path}: {error}")


def load_manifest(root: Path) -> dict[str, object]:
    try:
        manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid artifact manifest: {error}")
    if not isinstance(manifest, dict):
        fail("artifact manifest must be an object")
    return manifest


def verify_root(platform: str, root: Path) -> dict[str, object]:
    result = subprocess.run(
        [sys.executable, str(VERIFIER), "--contract", str(CONTRACTS[platform]), str(root)],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(result.stderr.strip() or result.stdout.strip())
    return load_manifest(root)


def verify_repeat(platform: str, selected: Path, repeat: Path) -> None:
    result = subprocess.run(
        [
            sys.executable, str(VERIFIER), "--contract", str(CONTRACTS[platform]),
            "--compare", str(repeat), str(selected),
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(result.stderr.strip() or result.stdout.strip())


def inspect_macho_platform(kernel: Path) -> str:
    command = shlex.split(os.environ.get("VULPRA_VTOOL", "xcrun vtool"))
    if not command:
        fail("VULPRA_VTOOL is empty")
    try:
        result = subprocess.run(
            [*command, "-show-build", str(kernel)],
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError as error:
        fail(f"cannot execute Mach-O platform inspector: {error}")
    if result.returncode != 0:
        fail(f"Mach-O platform inspection failed: {result.stderr.strip()}")
    platforms = {
        line.split()[-1].upper()
        for line in result.stdout.splitlines()
        if line.strip().lower().startswith("platform ")
    }
    if len(platforms) != 1:
        fail("Mach-O kernel must declare exactly one build platform")
    return platforms.pop()


def require_matching_pair(
    device: dict[str, object], simulator: dict[str, object], run_id: int,
    device_root: Path, simulator_root: Path,
) -> None:
    for field in ("source", "patchSet", "configurationSHA256", "abiVersion", "producer"):
        if device.get(field) != simulator.get(field):
            fail(f"artifact pair {field} mismatch")
    for manifest in (device, simulator):
        producer = manifest.get("producer")
        if not isinstance(producer, dict) or producer.get("workflowRunId") != run_id:
            fail("artifact producer workflow run does not match selected run")
    device_compile = device.get("compiledBy", {})
    simulator_compile = simulator.get("compiledBy", {})
    for field in ("repository", "commit", "workflowRunId"):
        if device_compile.get(field) != simulator_compile.get(field):
            fail(f"artifact pair compiledBy {field} mismatch")
    if device.get("build", {}).get("platform") != "iphoneos":
        fail("device artifact platform is invalid")
    if simulator.get("build", {}).get("platform") != "iphonesimulator":
        fail("Simulator artifact platform is invalid")
    if device.get("build", {}).get("targetTriple") == simulator.get("build", {}).get("targetTriple"):
        fail("artifact target triples are not distinct")

    device_kernel = device_root / "runtime/bin/XUL"
    simulator_kernel = simulator_root / "runtime/bin/XUL"
    if sha256(device_kernel) == sha256(simulator_kernel):
        fail("device and Simulator kernels are byte-identical")
    if inspect_macho_platform(device_kernel) != "IOS":
        fail("device kernel is not a native iOS Mach-O")
    if inspect_macho_platform(simulator_kernel) != "IOSSIMULATOR":
        fail("Simulator kernel is not a native iOS Simulator Mach-O")


def lock_entry(archive: Path, manifest: dict[str, object]) -> dict[str, object]:
    build = manifest["build"]
    return {
        "archive": archive.name,
        "archiveSHA256": sha256(archive),
        "artifactId": manifest["artifactId"],
        "abiVersion": manifest["abiVersion"],
        "sourceCommit": manifest["source"]["commit"],
        "patchSetSHA256": manifest["patchSet"]["sha256"],
        "configurationSHA256": manifest["configurationSHA256"],
        "compiledByRunId": manifest["compiledBy"]["workflowRunId"],
        "compiledByHeadSha": manifest["compiledBy"]["commit"],
        "buildFingerprint": manifest["compiledBy"]["buildFingerprint"],
        "platform": build["platform"],
        "targetTriple": build["targetTriple"],
    }


def write_lock_atomic(path: Path, value: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps(value, indent=2) + "\n"
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=f".{path.name}.", suffix=".tmp", delete=False,
        ) as sink:
            temporary = Path(sink.name)
            sink.write(content)
            sink.flush()
            os.fsync(sink.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    verify_parser = commands.add_parser("verify-pair")
    promote_parser = commands.add_parser("promote")
    for command_parser in (verify_parser, promote_parser):
        command_parser.add_argument("--producer-run-id", required=True, type=int)
        command_parser.add_argument("--device-archive", required=True, type=Path)
        command_parser.add_argument("--simulator-archive", required=True, type=Path)
    promote_parser.add_argument("--release-tag", required=True)
    promote_parser.add_argument("--repeat-producer-run-id", required=True, type=int)
    promote_parser.add_argument("--repeat-device-archive", required=True, type=Path)
    promote_parser.add_argument("--repeat-simulator-archive", required=True, type=Path)
    promote_parser.add_argument("--lock", required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.producer_run_id <= 0:
            fail("producer run ID must be positive")
        with tempfile.TemporaryDirectory(prefix="vulpra-engine-v5-promotion-") as temporary:
            root = Path(temporary)
            device_root = root / "device"
            simulator_root = root / "simulator"
            extract_archive(args.device_archive, device_root)
            extract_archive(args.simulator_archive, simulator_root)
            device = verify_root("iphoneos", device_root)
            simulator = verify_root("iphonesimulator", simulator_root)
            require_matching_pair(
                device, simulator, args.producer_run_id, device_root, simulator_root
            )
            if args.command == "verify-pair":
                print(f"PASS: verified native Gecko v5 pair run={args.producer_run_id}")
                return 0

            if args.repeat_producer_run_id <= 0:
                fail("repeat producer run ID must be positive")
            if args.repeat_producer_run_id == args.producer_run_id:
                fail("repeat producer run must be independent from the selected run")
            if not args.release_tag or any(character.isspace() for character in args.release_tag):
                fail("release tag is invalid")
            repeat_device_root = root / "repeat-device"
            repeat_simulator_root = root / "repeat-simulator"
            extract_archive(args.repeat_device_archive, repeat_device_root)
            extract_archive(args.repeat_simulator_archive, repeat_simulator_root)
            repeat_device = verify_root("iphoneos", repeat_device_root)
            repeat_simulator = verify_root("iphonesimulator", repeat_simulator_root)
            require_matching_pair(
                repeat_device, repeat_simulator, args.repeat_producer_run_id,
                repeat_device_root, repeat_simulator_root,
            )
            verify_repeat("iphoneos", device_root, repeat_device_root)
            verify_repeat("iphonesimulator", simulator_root, repeat_simulator_root)
            producer = device["producer"]
            lock = {
                "schemaVersion": 2,
                "artifactFormatVersion": 5,
                "releaseTag": args.release_tag,
                "producerRunId": args.producer_run_id,
                "producerHeadSha": producer["commit"],
                "device": lock_entry(args.device_archive, device),
                "simulator": lock_entry(args.simulator_archive, simulator),
            }
            write_lock_atomic(args.lock, lock)
    except (OSError, KeyError, TypeError, PromotionError) as error:
        print(f"engine-artifact-promotion-error: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS: promoted repeat-verified native Gecko v5 pair "
        f"runs={args.producer_run_id},{args.repeat_producer_run_id}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
