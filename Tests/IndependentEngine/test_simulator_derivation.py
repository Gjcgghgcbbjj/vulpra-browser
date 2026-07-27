#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "Tools/Engine/derive-simulator-artifact.py"
SOFTWARE_WEBRENDER_PREFERENCE = 'pref("gfx.webrender.software", true);'


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def macho(platform: int) -> bytes:
    header = struct.pack("<IiiIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 1, 24, 0, 0)
    build = struct.pack("<IIIIII", 0x32, 24, platform, 0x000F0000, 0x001A0400, 0)
    return header + build + b"VulpraEngineRuntime\0_MainProcessInit\0"


def write_source(root: Path, platform: str = "iphoneos") -> dict[str, object]:
    payload = {
        "runtime/bin/XUL": macho(2),
        "runtime/lib/libmozglue.dylib": macho(2),
        "runtime/include/GeckoView/IOSBootstrap.h": b"header",
        "runtime/resources/defaults/pref/mobile.js": b"prefs",
        "licenses/MPL-2.0.txt": b"license",
        "licenses/FIREFOX-THIRD-PARTY.html": b"notice",
    }
    for relative, content in payload.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    files = []
    for relative, content in sorted(payload.items()):
        files.append({"path": relative, "size": len(content),
                      "sha256": hashlib.sha256(content).hexdigest()})
    manifest = {
        "formatVersion": 4,
        "artifactId": "vulpra-gecko-ios-arm64-v4-" + "a" * 64,
        "abiVersion": "firefox-152.0.6-ios-abi-1",
        "source": {"repository": "https://github.com/mozilla-firefox/firefox",
                   "commit": "b" * 40},
        "build": {"xcodeBuild": "17E202", "sdkBuild": "23E252",
                  "platform": platform, "architecture": "arm64"},
        "licenses": ["licenses/MPL-2.0.txt"],
        "notices": ["licenses/FIREFOX-THIRD-PARTY.html"],
        "files": files,
    }
    (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    return manifest


def main() -> None:
    require(TOOL.is_file(), "missing deterministic Simulator derivation tool")
    with tempfile.TemporaryDirectory(prefix="vulpra-simulator-derivation-") as temporary:
        base = Path(temporary)
        source = base / "source"
        output = base / "output"
        source.mkdir()
        original = write_source(source)
        result = subprocess.run(
            ["python3", str(TOOL), str(source), str(output)],
            text=True, capture_output=True, check=False,
        )
        require(result.returncode == 0, result.stderr or result.stdout)
        derived = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        require(derived["build"]["platform"] == "iphonesimulator",
                "derived manifest platform is not iphonesimulator")
        require(derived["source"] == original["source"] and
                derived["abiVersion"] == original["abiVersion"],
                "derivation changed source or ABI identity")
        require(derived["artifactId"].startswith("vulpra-gecko-ios-simulator-arm64-v4-"),
                "derived artifact ID prefix is wrong")
        source_preferences = (source / "runtime/resources/defaults/pref/mobile.js").read_text()
        derived_preferences = (output / "runtime/resources/defaults/pref/mobile.js").read_text()
        require(SOFTWARE_WEBRENDER_PREFERENCE not in source_preferences,
                "test source unexpectedly contains the Simulator runtime policy")
        require(derived_preferences.count(SOFTWARE_WEBRENDER_PREFERENCE) == 1,
                "derived artifact does not contain exactly one software WebRender policy")
        for relative in ("runtime/bin/XUL", "runtime/lib/libmozglue.dylib"):
            data = (output / relative).read_bytes()
            require(struct.unpack_from("<I", data, 40)[0] == 7,
                    f"{relative} did not become an iossim Mach-O")
        for entry in derived["files"]:
            data = (output / entry["path"]).read_bytes()
            require(entry["size"] == len(data) and
                    entry["sha256"] == hashlib.sha256(data).hexdigest(),
                    f"manifest content identity is stale for {entry['path']}")

        invalid = base / "invalid"
        invalid.mkdir()
        write_source(invalid, platform="iphonesimulator")
        rejected = subprocess.run(
            ["python3", str(TOOL), str(invalid), str(base / "rejected")],
            text=True, capture_output=True, check=False,
        )
        require(rejected.returncode != 0 and "iphoneos" in rejected.stderr,
                "derivation accepted a non-device source artifact")

        conflicting = base / "conflicting"
        conflicting.mkdir()
        write_source(conflicting)
        preferences = conflicting / "runtime/resources/defaults/pref/mobile.js"
        preferences.write_text(SOFTWARE_WEBRENDER_PREFERENCE + "\n", encoding="utf-8")
        conflict_result = subprocess.run(
            ["python3", str(TOOL), str(conflicting), str(base / "conflict-output")],
            text=True, capture_output=True, check=False,
        )
        require(conflict_result.returncode != 0 and "already declares" in conflict_result.stderr,
                "derivation accepted a pre-existing Simulator runtime policy")
    print("PASS: deterministic device-to-Simulator artifact derivation")


if __name__ == "__main__":
    main()
