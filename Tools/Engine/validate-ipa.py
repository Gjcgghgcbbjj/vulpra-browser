#!/usr/bin/env python3
"""Validate the independent Vulpra application package."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import struct
import sys
import zipfile

from macho_content import MachOContentError, content_identity


EXPECTED_BUNDLES = {
    "Payload/Vulpra.app": ("com.vulpra.browser", "Vulpra"),
    "Payload/Vulpra.app/Frameworks/VulpraEngineKit.framework": (
        "com.vulpra.browser.engine-kit",
        "VulpraEngineKit",
    ),
    "Payload/Vulpra.app/PlugIns/Vulpra Engine Process.appex": (
        "com.vulpra.browser.engine-process",
        "Vulpra Engine Process",
    ),
    "Payload/Vulpra.app/PlugIns/OpenIn.appex": (
        "com.vulpra.browser.open-in",
        "OpenIn",
    ),
}
FORBIDDEN_PATH_TOKENS = (
    "geckoview.framework",
    "vulpra helper.appex",
    "ptrace_jit",
    "libidevice",
    "/jit/",
    "/patches/",
    "/vendor/firefox/",
)
BUILD_IDENTITY_PATH = Path(__file__).resolve().parents[2] / "Configuration/build-identity.json"
ENGINE_LOCK_PATH = Path(__file__).resolve().parents[2] / "Configuration/engine-artifact-lock.json"
EXTERNAL_SIGNING_PROFILE = "external-signing"
TROLLSTORE_PROFILE = "trollstore"
FORBIDDEN_RUNTIME_TOKENS = (
    b"jit-ready-fd",
    b"ReportJITStatusForChild",
    b"WaitForJITReadySignal",
)

# Real-device main-process JIT (v9): package-app.sh stages this default pref
# into the GRE defaults dir so the iOS main process keeps the JIT backend when
# the App runs web JS in-process under CS_DEBUGGED.
MAIN_PROCESS_JIT_PREF = (
    "Payload/Vulpra.app/Frameworks/VulpraEngineRuntime/Frameworks/"
    "defaults/pref/vulpra-main-jit.js"
)
MAIN_PROCESS_JIT_PREF_MARKER = b'pref("javascript.options.main_process_disable_jit", false);'


class PackageError(ValueError):
    pass


def fail(message: str) -> None:
    raise PackageError(message)


def normalized_member(name: str) -> bool:
    path = PurePosixPath(name)
    return (
        bool(name)
        and not path.is_absolute()
        and ".." not in path.parts
        and "." not in path.parts
        and str(path) == name.rstrip("/")
        and "\\" not in name
    )


def u32(data: bytes, offset: int, endian: str) -> int:
    return struct.unpack_from(endian + "I", data, offset)[0]


def thin_macho(data: bytes, label: str) -> tuple[set[int], bool]:
    if len(data) < 32:
        fail(f"truncated Mach-O: {label}")
    magic = data[:4]
    if magic == b"\xcf\xfa\xed\xfe":
        endian = "<"
    elif magic == b"\xfe\xed\xfa\xcf":
        endian = ">"
    else:
        fail(f"not a 64-bit Mach-O: {label}")
    cpu_type = u32(data, 4, endian)
    command_count = u32(data, 16, endian)
    command_bytes = u32(data, 20, endian)
    command_end = 32 + command_bytes
    if command_end > len(data):
        fail(f"truncated Mach-O commands: {label}")
    offset = 32
    signed = False
    for _ in range(command_count):
        if offset + 8 > command_end:
            fail(f"invalid Mach-O command table: {label}")
        command = u32(data, offset, endian)
        size = u32(data, offset + 4, endian)
        if size < 8 or offset + size > command_end:
            fail(f"invalid Mach-O command size: {label}")
        if command == 0x1D:
            signed = True
        offset += size
    return {cpu_type}, signed


def macho_identity(data: bytes, label: str) -> tuple[set[int], bool]:
    if data[:4] not in (b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
        return thin_macho(data, label)
    endian = ">" if data[:4] == b"\xca\xfe\xba\xbe" else "<"
    count = u32(data, 4, endian)
    if count == 0 or len(data) < 8 + count * 20:
        fail(f"invalid universal Mach-O: {label}")
    architectures: set[int] = set()
    all_signed = True
    for index in range(count):
        base = 8 + index * 20
        offset = u32(data, base + 8, endian)
        size = u32(data, base + 12, endian)
        if size == 0 or offset + size > len(data):
            fail(f"invalid universal Mach-O slice: {label}")
        slice_architectures, signed = thin_macho(data[offset : offset + size], label)
        architectures.update(slice_architectures)
        all_signed = all_signed and signed
    return architectures, all_signed


def load_manifest(path: Path) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid engine manifest: {path}: {error}")
    if not isinstance(value, dict) or not isinstance(value.get("files"), list):
        fail(f"invalid engine manifest shape: {path}")
    return value


def validate_manifest_lock(manifest: dict[str, object], lock_path: Path) -> None:
    try:
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid engine artifact lock: {lock_path}: {error}")
    if not isinstance(lock, dict) or lock.get("schemaVersion") != 2 or \
            lock.get("artifactFormatVersion") != 5:
        fail("engine artifact lock is not a complete v5 pair")
    device = lock.get("device")
    if (not isinstance(device, dict)
            or device.get("platform") != "iphoneos"
            or device.get("targetTriple") != "aarch64-apple-ios"):
        fail("engine artifact lock device entry is not native iOS")
    producer = manifest.get("producer")
    compiled_by = manifest.get("compiledBy")
    source = manifest.get("source")
    patch_set = manifest.get("patchSet")
    build = manifest.get("build")
    if (manifest.get("formatVersion") != 5
            or manifest.get("artifactId") != device.get("artifactId")
            or manifest.get("abiVersion") != device.get("abiVersion")
            or not isinstance(source, dict)
            or source.get("commit") != device.get("sourceCommit")
            or not isinstance(patch_set, dict)
            or patch_set.get("sha256") != device.get("patchSetSHA256")
            or manifest.get("configurationSHA256") != device.get("configurationSHA256")
            or not isinstance(producer, dict)
            or producer.get("workflowRunId") != lock.get("producerRunId")
            or producer.get("commit") != lock.get("producerHeadSha")
            or not isinstance(compiled_by, dict)
            or compiled_by.get("workflowRunId") != device.get("compiledByRunId")
            or compiled_by.get("commit") != device.get("compiledByHeadSha")
            or compiled_by.get("buildFingerprint") != device.get("buildFingerprint")
            or not isinstance(build, dict)
            or build.get("platform") != "iphoneos"
            or build.get("targetTriple") != "aarch64-apple-ios"):
        fail("engine manifest provenance does not match the v5 device lock")


def load_build_identity() -> dict[str, str]:
    try:
        value = json.loads(BUILD_IDENTITY_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid build identity: {error}")
    required = ("marketingVersion", "buildVersion", "uiFingerprint")
    if not isinstance(value, dict) or any(not isinstance(value.get(key), str) for key in required):
        fail("invalid build identity shape")
    return value


def expected_runtime(manifest: dict[str, object]) -> dict[str, tuple[str, str]]:
    expected: dict[str, tuple[str, str]] = {}
    app = "Payload/Vulpra.app"
    runtime = f"{app}/Frameworks/VulpraEngineRuntime"
    for entry in manifest["files"]:
        if not isinstance(entry, dict):
            fail("invalid engine manifest file entry")
        relative = entry.get("path")
        digest = entry.get("sha256")
        if not isinstance(relative, str) or not isinstance(digest, str):
            fail("invalid engine manifest file identity")
        if relative == "runtime/bin/XUL":
            packaged = f"{app}/Frameworks/XUL"
        elif relative.startswith("runtime/lib/"):
            packaged = f"{app}/Frameworks/{PurePosixPath(relative).name}"
        elif relative.startswith("runtime/resources/"):
            packaged = f"{runtime}/Frameworks/{relative.removeprefix('runtime/resources/')}"
        elif relative.startswith("licenses/"):
            packaged = f"{runtime}/Licenses/{relative.removeprefix('licenses/')}"
        else:
            continue
        expected[packaged] = (relative, digest)
    return expected


def validate(
    package: Path, manifest_path: Path, lock_path: Path, require_signatures: bool
) -> tuple[int, str]:
    manifest = load_manifest(manifest_path)
    validate_manifest_lock(manifest, lock_path)
    build_identity = load_build_identity()
    expected = expected_runtime(manifest)
    if not expected:
        fail("engine manifest produced no package expectations")

    try:
        archive = zipfile.ZipFile(package)
    except (OSError, zipfile.BadZipFile) as error:
        fail(f"invalid ZIP package: {package}: {error}")
    with archive:
        if archive.testzip() is not None:
            fail("ZIP integrity check failed")
        infos = archive.infolist()
        names = [info.filename.rstrip("/") for info in infos if not info.is_dir()]
        if len(names) != len(set(names)):
            fail("ZIP contains duplicate file names")
        if not names or any(not normalized_member(name) for name in names):
            fail("ZIP contains an unsafe member path")
        if any(not name.startswith("Payload/Vulpra.app/") for name in names):
            fail("ZIP contains data outside Payload/Vulpra.app")
        lowered = "\n".join(names).casefold()
        for token in FORBIDDEN_PATH_TOKENS:
            if token in lowered:
                fail(f"retired package path remains: {token}")

        name_set = set(names)
        for root, (bundle_id, executable) in EXPECTED_BUNDLES.items():
            plist_name = f"{root}/Info.plist"
            binary_name = f"{root}/{executable}"
            if plist_name not in name_set or binary_name not in name_set:
                fail(f"missing bundle product: {root}")
            try:
                info = plistlib.loads(archive.read(plist_name))
            except (ValueError, plistlib.InvalidFileException) as error:
                fail(f"invalid bundle plist {plist_name}: {error}")
            if info.get("CFBundleIdentifier") != bundle_id:
                fail(f"bundle identity mismatch for {root}: {info.get('CFBundleIdentifier')}")
            if info.get("CFBundleExecutable") != executable:
                fail(f"bundle executable mismatch for {root}")
            if root == "Payload/Vulpra.app":
                if info.get("CFBundleShortVersionString") != build_identity["marketingVersion"]:
                    fail("app marketing version does not identify the current client")
                if info.get("CFBundleVersion") != build_identity["buildVersion"]:
                    fail("app build version does not identify the current client")
                fingerprint = build_identity["uiFingerprint"]
                if info.get("VulpraUIBuildFingerprint") != fingerprint:
                    fail("VulpraUIBuildFingerprint does not identify the current client")
                if fingerprint.encode("ascii") not in archive.read(binary_name):
                    fail("app executable does not contain the current UI fingerprint")
                expected_profile = TROLLSTORE_PROFILE if require_signatures else EXTERNAL_SIGNING_PROFILE
                if info.get("VulpraDistributionProfile") != expected_profile:
                    fail(f"package distribution profile is not {expected_profile}")
            architectures, signed = macho_identity(archive.read(binary_name), binary_name)
            if architectures != {0x0100000C}:
                fail(f"bundle executable is not arm64-only: {binary_name}")
            if require_signatures and not signed:
                fail(f"bundle executable is unsigned: {binary_name}")

        plugin_roots = {
            name.split("/Info.plist", 1)[0]
            for name in names
            if name.startswith("Payload/Vulpra.app/PlugIns/") and name.endswith(".appex/Info.plist")
        }
        expected_plugins = {
            "Payload/Vulpra.app/PlugIns/Vulpra Engine Process.appex",
            "Payload/Vulpra.app/PlugIns/OpenIn.appex",
        }
        if plugin_roots != expected_plugins:
            fail(f"unexpected app extension set: {sorted(plugin_roots)}")

        if MAIN_PROCESS_JIT_PREF not in name_set:
            fail("missing main-process JIT default pref")
        if MAIN_PROCESS_JIT_PREF_MARKER not in archive.read(MAIN_PROCESS_JIT_PREF):
            fail("main-process JIT default pref lacks the disable_jit override")

        for packaged, (relative, digest) in expected.items():
            if packaged not in name_set:
                fail(f"missing engine payload: {packaged}")
            content = archive.read(packaged)
            if hashlib.sha256(content).hexdigest() != digest:
                is_binary = packaged.endswith("/XUL") or packaged.endswith(".dylib")
                if not is_binary:
                    fail(f"engine payload checksum mismatch: {packaged}")
                source_path = manifest_path.parent / relative
                try:
                    source = source_path.read_bytes()
                except OSError as error:
                    fail(f"missing original engine binary: {source_path}: {error}")
                if hashlib.sha256(source).hexdigest() != digest:
                    fail(f"original engine binary does not match manifest: {relative}")
                try:
                    source_identity = content_identity(source, relative)
                    packaged_identity = content_identity(content, packaged)
                except MachOContentError as error:
                    fail(str(error))
                if packaged_identity != source_identity:
                    fail(f"engine binary content mismatch: {packaged}")

        runtime_binaries = [
            name
            for name in expected
            if name.endswith("/XUL") or name.endswith(".dylib")
        ]
        for name in runtime_binaries:
            content = archive.read(name)
            for token in FORBIDDEN_RUNTIME_TOKENS:
                if token in content:
                    fail(f"retired runtime token remains in package: {token.decode('ascii')}")
            architectures, signed = macho_identity(content, name)
            if architectures != {0x0100000C}:
                fail(f"runtime binary is not arm64-only: {name}")
            if require_signatures and not signed:
                fail(f"runtime binary is unsigned: {name}")

    return len(names), str(manifest.get("artifactId", ""))


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=Path)
    parser.add_argument("--manifest", type=Path, default=root / ".build/engine/manifest.json")
    parser.add_argument("--lock", type=Path, default=ENGINE_LOCK_PATH)
    parser.add_argument("--require-signatures", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        count, artifact_id = validate(
            args.package, args.manifest, args.lock, args.require_signatures
        )
    except (PackageError, FileNotFoundError, OSError) as error:
        print(f"vulpra-package-error: {error}", file=sys.stderr)
        return 1
    print(f"vulpra-package-ok {args.package} files={count} engine={artifact_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
