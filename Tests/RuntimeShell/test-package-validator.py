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
    text = b"VulpraEngineRuntime\x00independent-section-content"
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
        f"{app}/Frameworks/VulpraEngineRuntime/Licenses/LICENSE.txt": b"license\n",
    }
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)


def validate(package: Path, manifest: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VALIDATOR), "--manifest", str(manifest), str(package)],
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
        manifest.write_text(json.dumps({
            "artifactId": "fixture-v4",
            "files": [
                {"path": relative, "size": len(content),
                 "sha256": hashlib.sha256(content).hexdigest()}
                for relative, content in payload.items()
            ],
        }), encoding="utf-8")

        resigned = root / "resigned.ipa"
        write_package(resigned, signed_kernel(b"replacement-signature-is-a-different-size"), b"[App]\n")
        result = validate(resigned, manifest)
        require(result.returncode == 0, f"valid re-signing was rejected: {result.stderr.strip()}")

        tampered = root / "tampered.tipa"
        write_package(tampered, original_kernel, b"[App]\ntampered=true\n")
        result = validate(tampered, manifest)
        require(result.returncode != 0 and "checksum mismatch" in result.stderr,
                "TIPA resource tampering was not rejected")
    print("PASS: package validator distinguishes signatures from engine content")


if __name__ == "__main__":
    main()
