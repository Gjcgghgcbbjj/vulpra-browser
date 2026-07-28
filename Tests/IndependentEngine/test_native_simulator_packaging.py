#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "Tools/Engine/package-native-simulator-artifact.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def write(path: Path, content: bytes, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    if executable:
        path.chmod(path.stat().st_mode | stat.S_IXUSR)


def main() -> None:
    require(TOOL.is_file(), "missing native Simulator artifact packager")
    with tempfile.TemporaryDirectory(prefix="vulpra-native-simulator-") as temporary:
        base = Path(temporary)
        dist = base / "dist"
        legal = base / "legal"
        output = base / "output"

        xul = b"native-iossim-XUL-_MainProcessInit-GeckoView.framework"
        write(dist / "bin/XUL", xul, executable=True)
        write(dist / "bin/libmozglue.dylib", b"native-iossim-dylib", executable=True)
        write(dist / "bin/application.ini", b"[App]\nName=Vulpra\n")
        write(dist / "bin/extensions/schemas/manifest.json", b"nested-manifest")
        write(dist / "bin/defaults/pref/mobile.js",
              b'pref("gfx.webrender.software", true);\n')
        write(dist / "bin/.mkdir.done", b"")
        write(dist / "bin/xpcshell", b"build-tool", executable=True)
        write(dist / "bin/gmp-fake/1.0/manifest.json", b"{}")
        for name in ("GeckoViewRuntimeSupport.h", "GeckoViewSwiftSupport.h",
                     "IOSBootstrap.h"):
            write(dist / f"include/GeckoView/{name}", name.encode("ascii"))

        write(legal / "licenses/MPL-2.0.txt", b"license")
        write(legal / "licenses/FIREFOX-THIRD-PARTY.html", b"notice")
        legal_manifest = {
            "formatVersion": 4,
            "artifactId": "vulpra-gecko-ios-arm64-v4-" + "a" * 64,
            "abiVersion": "firefox-152.0.6-ios-abi-1",
            "source": {
                "repository": "https://github.com/mozilla-firefox/firefox",
                "commit": "b" * 40,
            },
            "build": {
                "xcodeBuild": "17E202",
                "sdkBuild": "23E252",
                "platform": "iphoneos",
                "architecture": "arm64",
            },
            "licenses": ["licenses/MPL-2.0.txt"],
            "notices": ["licenses/FIREFOX-THIRD-PARTY.html"],
            "files": [],
        }
        write(legal / "manifest.json", json.dumps(legal_manifest).encode("utf-8"))

        result = subprocess.run(
            ["python3", str(TOOL), "--dist", str(dist),
             "--legal-artifact", str(legal), "--output", str(output)],
            text=True, capture_output=True, check=False,
        )
        require(result.returncode == 0, result.stderr or result.stdout)
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        require((output / "runtime/bin/XUL").read_bytes() == xul,
                "packager changed the native Simulator kernel")
        require((output / "runtime/resources/application.ini").is_file(),
                "packager omitted native runtime resources")
        require((output / "runtime/resources/extensions/schemas/manifest.json").is_file(),
                "packager omitted a nested resource manifest")
        require(not (output / "runtime/resources/.mkdir.done").exists(),
                "packager retained a build marker")
        require(not (output / "runtime/resources/xpcshell").exists(),
                "packager retained a host build executable")
        require(not (output / "runtime/resources/gmp-fake").exists(),
                "packager retained test-only GMP payload")
        require(manifest["build"]["platform"] == "iphonesimulator" and
                manifest["build"]["architecture"] == "arm64",
                "native Simulator build identity is wrong")
        require(manifest["source"] == legal_manifest["source"] and
                manifest["abiVersion"] == legal_manifest["abiVersion"],
                "packager changed source or ABI identity")
        require(manifest["artifactId"].startswith(
                    "vulpra-gecko-ios-simulator-arm64-v4-"),
                "native Simulator artifact ID prefix is wrong")
        for entry in manifest["files"]:
            content = (output / entry["path"]).read_bytes()
            require(entry["size"] == len(content) and
                    entry["sha256"] == hashlib.sha256(content).hexdigest(),
                    f"stale content identity for {entry['path']}")

        duplicate = subprocess.run(
            ["python3", str(TOOL), "--dist", str(dist),
             "--legal-artifact", str(legal), "--output", str(output)],
            text=True, capture_output=True, check=False,
        )
        require(duplicate.returncode != 0 and "already exists" in duplicate.stderr,
                "packager overwrote an existing artifact")

    print("PASS: native Simulator dist packaging")


if __name__ == "__main__":
    main()
