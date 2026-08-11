#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import plistlib
import struct
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "Tools/Engine/validate-ipa.py"
BUILD_IDENTITY = json.loads((ROOT / "Configuration/build-identity.json").read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def plain_macho() -> bytes:
    return struct.pack("<IiiIIIII", 0xFEEDFACF, 0x0100000C, 0, 2, 0, 0, 0, 0)


def signed_kernel(signature: bytes) -> bytes:
    text = b"native-gecko-kernel\x00independent-section-content"
    text_offset = 512
    signature_offset = 1024
    text_segment_size = 72 + 80
    linkedit_segment_size = 72
    signature_command_size = 16
    commands_size = text_segment_size + linkedit_segment_size + signature_command_size
    header = struct.pack(
        "<IiiIIIII", 0xFEEDFACF, 0x0100000C, 0, 2, 3, commands_size, 0, 0
    )
    text_segment = struct.pack(
        "<II16sQQQQiiII", 0x19, text_segment_size, b"__TEXT", 0, 4096,
        0, signature_offset, 5, 5, 1, 0,
    )
    text_section = struct.pack(
        "<16s16sQQIIIIIIII", b"__text", b"__TEXT", text_offset, len(text),
        text_offset, 0, 0, 0, 0, 0, 0, 0,
    )
    linkedit = struct.pack(
        "<II16sQQQQiiII", 0x19, linkedit_segment_size, b"__LINKEDIT",
        signature_offset, len(signature), signature_offset, len(signature), 1, 1, 0, 0,
    )
    code_signature = struct.pack("<IIII", 0x1D, signature_command_size,
                                 signature_offset, len(signature))
    prefix = header + text_segment + text_section + linkedit + code_signature
    return prefix.ljust(text_offset, b"\x00") + text.ljust(signature_offset - text_offset, b"\x00") + signature


def plist(bundle_id: str, executable: str, app: bool = False) -> bytes:
    value = {"CFBundleIdentifier": bundle_id, "CFBundleExecutable": executable}
    if app:
        value.update({
            "CFBundleShortVersionString": BUILD_IDENTITY["marketingVersion"],
            "CFBundleVersion": BUILD_IDENTITY["buildVersion"],
            "VulpraUIBuildFingerprint": BUILD_IDENTITY["uiFingerprint"],
            "VulpraDistributionProfile": "external-signing",
        })
    return plistlib.dumps(value)


def write_package(path: Path, kernel: bytes, resource: bytes) -> None:
    app = "Payload/Vulpra.app"
    files = {
        f"{app}/Info.plist": plist("com.vulpra.browser", "Vulpra", app=True),
        f"{app}/Vulpra": plain_macho() + BUILD_IDENTITY["uiFingerprint"].encode("ascii") + b"\x00",
        f"{app}/Frameworks/VulpraEngineKit.framework/Info.plist":
            plist("com.vulpra.browser.engine-kit", "VulpraEngineKit"),
        f"{app}/Frameworks/VulpraEngineKit.framework/VulpraEngineKit": plain_macho(),
        f"{app}/PlugIns/Vulpra Engine Process.appex/Info.plist":
            plist("com.vulpra.browser.engine-process", "Vulpra Engine Process"),
        f"{app}/PlugIns/Vulpra Engine Process.appex/Vulpra Engine Process": plain_macho(),
        f"{app}/PlugIns/OpenIn.appex/Info.plist":
            plist("com.vulpra.browser.open-in", "OpenIn"),
        f"{app}/PlugIns/OpenIn.appex/OpenIn": plain_macho(),
        f"{app}/Frameworks/XUL": kernel,
        f"{app}/Frameworks/libfixture.dylib": plain_macho(),
        f"{app}/Frameworks/VulpraEngineRuntime/Frameworks/application.ini": resource,
        f"{app}/Frameworks/VulpraEngineRuntime/Frameworks/defaults/pref/vulpra-main-jit.js":
            b'pref("javascript.options.main_process_disable_jit", false);\n',
        f"{app}/Frameworks/VulpraEngineRuntime/Licenses/LICENSE.txt": b"license\n",
    }
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)


def validate(package: Path, manifest: Path, lock: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "python3", str(VALIDATOR), "--manifest", str(manifest),
            "--lock", str(lock), str(package),
        ],
        text=True, capture_output=True, check=False,
    )


def main() -> None:
    with tempfile.TemporaryDirectory() as value:
        root = Path(value)
        original_kernel = signed_kernel(b"original-signature")
        payload = {
            "runtime/bin/XUL": original_kernel,
            "runtime/lib/libfixture.dylib": plain_macho(),
            "runtime/resources/application.ini": b"[App]\n",
            "licenses/LICENSE.txt": b"license\n",
        }
        for relative, content in payload.items():
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
        manifest = root / "manifest.json"
        artifact_id = "vulpra-gecko-ios-arm64-v5-" + "a" * 64
        source_commit = "2" * 40
        patch_sha = "3" * 64
        configuration_sha = "4" * 64
        producer_commit = "5" * 40
        abi_version = "gecko-ios-v5-abi-1"
        manifest_value = {
            "formatVersion": 5,
            "artifactId": artifact_id,
            "abiVersion": abi_version,
            "source": {"repository": "https://example.invalid/firefox", "commit": source_commit},
            "patchSet": {"series": "fixture-series.json", "sha256": patch_sha},
            "producer": {
                "repository": "https://example.invalid/vulpra",
                "commit": producer_commit,
                "workflowRunId": 123,
            },
            "compiledBy": {
                "repository": "https://example.invalid/vulpra",
                "commit": producer_commit, "workflowRunId": 123,
                "buildFingerprint": "7" * 64,
            },
            "configurationSHA256": configuration_sha,
            "build": {
                "platform": "iphoneos", "targetTriple": "aarch64-apple-ios",
                "architecture": "arm64", "deploymentTarget": "15.0",
                "mozconfigSHA256": "6" * 64, "xcodeBuild": "17E202", "sdkBuild": "23E252",
            },
            "files": [
                {"path": relative, "size": len(content),
                 "sha256": hashlib.sha256(content).hexdigest()}
                for relative, content in payload.items()
            ],
        }
        manifest.write_text(json.dumps(manifest_value), encoding="utf-8")
        lock = root / "engine-artifact-lock.json"
        lock.write_text(json.dumps({
            "schemaVersion": 2,
            "artifactFormatVersion": 5,
            "producerRunId": 123,
            "producerHeadSha": producer_commit,
            "device": {
                "artifactId": artifact_id,
                "abiVersion": abi_version,
                "sourceCommit": source_commit,
                "patchSetSHA256": patch_sha,
                "configurationSHA256": configuration_sha,
                "platform": "iphoneos",
                "targetTriple": "aarch64-apple-ios",
                "compiledByRunId": 123,
                "compiledByHeadSha": producer_commit,
                "buildFingerprint": "7" * 64,
            },
        }), encoding="utf-8")

        resigned = root / "resigned.ipa"
        write_package(resigned, signed_kernel(b"replacement-signature-is-a-different-size"), b"[App]\n")
        result = validate(resigned, manifest, lock)
        require(result.returncode == 0, f"valid re-signing was rejected: {result.stderr.strip()}")

        tampered = root / "tampered.tipa"
        write_package(tampered, original_kernel, b"[App]\ntampered=true\n")
        result = validate(tampered, manifest, lock)
        require(result.returncode != 0 and "checksum mismatch" in result.stderr,
                "TIPA resource tampering was not rejected")

        forbidden_kernel = original_kernel + b"\0jit-ready-fd"
        (root / "runtime/bin/XUL").write_bytes(forbidden_kernel)
        forbidden_manifest = json.loads(json.dumps(manifest_value))
        for entry in forbidden_manifest["files"]:
            if entry["path"] == "runtime/bin/XUL":
                entry["size"] = len(forbidden_kernel)
                entry["sha256"] = hashlib.sha256(forbidden_kernel).hexdigest()
        manifest.write_text(json.dumps(forbidden_manifest), encoding="utf-8")
        forbidden_package = root / "retired-token.ipa"
        write_package(forbidden_package, forbidden_kernel, b"[App]\n")
        result = validate(forbidden_package, manifest, lock)
        require(result.returncode != 0 and "retired runtime token" in result.stderr,
                "package validator accepted a retired JIT protocol token")

        mismatched_manifest = json.loads(json.dumps(manifest_value))
        mismatched_manifest["producer"]["workflowRunId"] = 124
        manifest.write_text(json.dumps(mismatched_manifest), encoding="utf-8")
        result = validate(resigned, manifest, lock)
        require(result.returncode != 0 and "provenance" in result.stderr,
                "package validator accepted producer provenance outside the lock")

        mismatched_compile = json.loads(json.dumps(manifest_value))
        mismatched_compile["compiledBy"]["workflowRunId"] = 124
        manifest.write_text(json.dumps(mismatched_compile), encoding="utf-8")
        result = validate(resigned, manifest, lock)
        require(result.returncode != 0 and "provenance" in result.stderr,
                "package validator accepted compilation provenance outside the lock")

        v4_manifest = dict(manifest_value)
        v4_manifest["formatVersion"] = 4
        manifest.write_text(json.dumps(v4_manifest), encoding="utf-8")
        result = validate(resigned, manifest, lock)
        require(result.returncode != 0 and "provenance" in result.stderr,
                "package validator accepted a v4 engine manifest")
    print("PASS: package validator distinguishes signatures from engine content")


if __name__ == "__main__":
    main()
