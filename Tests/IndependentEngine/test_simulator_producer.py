#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "Tools/Engine/produce-simulator-artifact.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def write(path: Path, content: bytes, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    if executable:
        path.chmod(path.stat().st_mode | stat.S_IXUSR)


def main() -> None:
    source = TOOL.read_text(encoding="utf-8")
    require("xcrun vtool" in source and
            "-set-build-version iossim 15.0" in source and
            "-replace -output" in source,
            "producer does not preserve the verified Apple vtool transform")
    require("derive-simulator-artifact.py" not in source,
            "producer retains the failed structural Mach-O derivation")

    with tempfile.TemporaryDirectory(prefix="vulpra-vtool-producer-") as temporary:
        base = Path(temporary)
        device = base / "device"
        output = base / "simulator"
        fake_vtool = base / "fake-vtool"
        xul = b"VulpraEngineRuntime-_MainProcessInit"
        payload = {
            "runtime/bin/XUL": xul,
            "runtime/lib/libmozglue.dylib": b"device-dylib",
            "runtime/include/GeckoView/IOSBootstrap.h": b"header",
            "runtime/resources/application.ini": b"resource",
            "licenses/MPL-2.0.txt": b"license",
            "licenses/FIREFOX-THIRD-PARTY.html": b"notice",
        }
        for relative, content in payload.items():
            write(device / relative, content, relative.endswith("XUL") or relative.endswith(".dylib"))
        files = []
        for relative, content in sorted(payload.items()):
            files.append({"path": relative, "size": len(content),
                          "sha256": hashlib.sha256(content).hexdigest()})
        manifest = {
            "formatVersion": 4,
            "artifactId": "",
            "abiVersion": "firefox-152.0.6-ios-abi-1",
            "source": {"repository": "https://github.com/mozilla-firefox/firefox",
                       "commit": "b" * 40},
            "build": {"xcodeBuild": "17E202", "sdkBuild": "23E252",
                      "platform": "iphoneos", "architecture": "arm64"},
            "licenses": ["licenses/MPL-2.0.txt"],
            "notices": ["licenses/FIREFOX-THIRD-PARTY.html"],
            "files": files,
        }
        canonical = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
        manifest["artifactId"] = (
            "vulpra-gecko-ios-arm64-v4-" + hashlib.sha256(canonical).hexdigest()
        )
        write(device / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())

        write(fake_vtool, b'''#!/bin/sh
set -eu
while [ "$1" != "-output" ]; do shift; done
output=$2
input=$3
cp "$input" "$output"
printf simulator-vtool >> "$output"
''', executable=True)
        result = subprocess.run(
            [str(TOOL), str(device), str(output)],
            env={"PATH": "/usr/bin:/bin", "VULPRA_VTOOL": str(fake_vtool),
                 "VULPRA_SIMULATOR_SDK_VERSION": "26.4"},
            text=True, capture_output=True, check=False,
        )
        require(result.returncode == 0, result.stderr or result.stdout)
        derived = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        require(derived["build"]["platform"] == "iphonesimulator",
                "producer did not set the Simulator manifest platform")
        require(derived["source"] == manifest["source"] and
                derived["abiVersion"] == manifest["abiVersion"],
                "producer changed source or ABI identity")
        require((output / "runtime/bin/XUL").read_bytes().endswith(b"simulator-vtool"),
                "producer did not install vtool output")
        for entry in derived["files"]:
            content = (output / entry["path"]).read_bytes()
            require(entry["size"] == len(content) and
                    entry["sha256"] == hashlib.sha256(content).hexdigest(),
                    f"stale content identity for {entry['path']}")

    print("PASS: verified device-to-Simulator vtool producer")


if __name__ == "__main__":
    main()
