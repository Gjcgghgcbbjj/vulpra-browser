#!/usr/bin/env python3
"""Portable fixtures for native Gecko v5 artifacts and atomic promotion."""

from __future__ import annotations

import copy
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "Tools/Engine/verify-engine-artifact.py"
PROMOTER = ROOT / "Tools/Engine/promote-engine-artifacts.py"
PROMOTION_WORKFLOW = ROOT / ".github/workflows/promote-gecko-v5.yml"
DEVICE_CONTRACT = ROOT / "Configuration/engine-artifact-device-v5.json"
SIMULATOR_CONTRACT = ROOT / "Configuration/engine-artifact-simulator-v5.json"
PRODUCER_CONTRACT = ROOT / "Configuration/gecko-producer-v5.json"
SERIES = ROOT / "Engine/GeckoPatches/v5/series.json"
RUN_ID = 123456789
PRODUCER_COMMIT = "a" * 40


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def artifact_prefix(platform: str) -> str:
    if platform == "iphoneos":
        return "vulpra-gecko-ios-arm64-v5-"
    return "vulpra-gecko-ios-simulator-native-arm64-v5-"


def payload(platform: str, marker: bytes | None = None) -> dict[str, bytes]:
    kernel_marker = marker or (b"DEVICE-MACHO" if platform == "iphoneos" else b"SIMULATOR-MACHO")
    exports = b"\0".join((
        b"_MainProcessInit", b"_GeckoViewOpenWindow", b"_ChildProcessInit",
        b"_GeckoChildProcessDidChange", b"VulpraEngineRuntime",
    ))
    return {
        "runtime/bin/XUL": kernel_marker + b"\0" + exports,
        "runtime/lib/libmozglue.dylib": platform.encode("ascii") + b"-mozglue",
        "runtime/include/GeckoView/GeckoViewSwiftSupport.h": (
            b"GeckoChildProcessLifecycleObserver childProcessDidChangeWithLaunchID"
        ),
        "runtime/include/GeckoView/IOSBootstrap.h": b"GeckoChildProcessDidChange",
        "runtime/resources/omni.ja": b"runtime-resource",
        "licenses/MPL-2.0.txt": b"license",
        "licenses/FIREFOX-THIRD-PARTY.html": b"notice",
    }


def files_for(values: dict[str, bytes]) -> list[dict[str, object]]:
    return [
        {"path": path, "size": len(content), "sha256": hashlib.sha256(content).hexdigest()}
        for path, content in sorted(values.items())
    ]


def bind_artifact_id(manifest: dict[str, object], platform: str) -> None:
    manifest["artifactId"] = ""
    canonical = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode("utf-8")
    manifest["artifactId"] = artifact_prefix(platform) + hashlib.sha256(canonical).hexdigest()


def manifest_for(platform: str, values: dict[str, bytes], run_id: int = RUN_ID) -> dict[str, object]:
    producer = json.loads(PRODUCER_CONTRACT.read_text(encoding="utf-8"))
    manifest: dict[str, object] = {
        "formatVersion": 5,
        "artifactId": "",
        "abiVersion": "gecko-ios-v5-abi-1",
        "source": producer["upstream"],
        "patchSet": {
            "series": "Engine/GeckoPatches/v5/series.json",
            "sha256": hashlib.sha256(SERIES.read_bytes()).hexdigest(),
        },
        "producer": {
            "repository": "https://github.com/Gjcgghgcbbjj/vulpra-browser",
            "commit": PRODUCER_COMMIT,
            "workflowRunId": run_id,
        },
        "compiledBy": {
            "repository": "https://github.com/Gjcgghgcbbjj/vulpra-browser",
            "commit": PRODUCER_COMMIT,
            "workflowRunId": run_id,
            "buildFingerprint": hashlib.sha256(platform.encode("ascii") + b"-build").hexdigest(),
        },
        "configurationSHA256": hashlib.sha256(PRODUCER_CONTRACT.read_bytes()).hexdigest(),
        "build": {
            "mozconfigSHA256": hashlib.sha256(platform.encode("ascii")).hexdigest(),
            "xcodeBuild": "17E202",
            "sdkBuild": "23E252",
            "platform": platform,
            "targetTriple": producer["targets"][platform],
            "architecture": "arm64",
            "deploymentTarget": "15.0",
        },
        "licenses": ["licenses/MPL-2.0.txt"],
        "notices": ["licenses/FIREFOX-THIRD-PARTY.html"],
        "files": files_for(values),
    }
    bind_artifact_id(manifest, platform)
    return manifest


def write_root(
    root: Path, platform: str, values: dict[str, bytes] | None = None,
    manifest: dict[str, object] | None = None,
) -> dict[str, object]:
    contents = values or payload(platform)
    for relative, content in contents.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        if relative == "runtime/bin/XUL" or relative.endswith(".dylib"):
            path.chmod(path.stat().st_mode | stat.S_IXUSR)
    value = manifest or manifest_for(platform, contents)
    (root / "manifest.json").write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    return value


def verify(
    root: Path, platform: str, nm: Path, compare: Path | None = None,
    omit_export: str | None = None,
) -> subprocess.CompletedProcess[str]:
    contract = DEVICE_CONTRACT if platform == "iphoneos" else SIMULATOR_CONTRACT
    command = ["python3", str(VERIFIER), "--contract", str(contract)]
    if compare is not None:
        command.extend(("--compare", str(compare)))
    command.append(str(root))
    environment = os.environ.copy()
    environment["VULPRA_NM"] = str(nm)
    if omit_export is not None:
        environment["VULPRA_FAKE_NM_OMIT"] = omit_export
    return subprocess.run(
        command, env=environment, text=True, capture_output=True, check=False
    )


def expect_invalid(root: Path, platform: str, token: str, nm: Path) -> None:
    result = verify(root, platform, nm)
    require(result.returncode != 0, f"invalid v5 artifact accepted: {root.name}")
    require(token in result.stderr, f"missing failure token {token!r}: {result.stderr}")


def archive_root(root: Path, output: Path) -> None:
    with tarfile.open(output, "w:gz") as archive:
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            content = path.read_bytes()
            info = tarfile.TarInfo(path.relative_to(root).as_posix())
            info.size = len(content)
            info.mode = path.stat().st_mode & 0o777
            archive.addfile(info, io.BytesIO(content))


def fake_vtool(path: Path) -> None:
    path.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "for value in \"$@\"; do last=$value; done\n"
        "case \"$(cat \"$last\")\" in\n"
        "  *SIMULATOR-MACHO*) echo 'platform IOSSIMULATOR' ;;\n"
        "  *) echo 'platform IOS' ;;\n"
        "esac\n",
        encoding="utf-8",
    )
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def fake_nm(path: Path) -> None:
    path.write_text(
        "#!/usr/bin/env python3\n"
        "import os, pathlib, sys\n"
        "content = pathlib.Path(sys.argv[-1]).read_bytes()\n"
        "omit = os.environ.get('VULPRA_FAKE_NM_OMIT')\n"
        "symbols = ('_MainProcessInit', '_GeckoViewOpenWindow', '_ChildProcessInit', "
        "'_GeckoChildProcessDidChange')\n"
        "for symbol in symbols:\n"
        "    if symbol != omit and symbol.encode() in content:\n"
        "        print(f'0000000000000000 T {symbol}')\n",
        encoding="utf-8",
    )
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def promote(
    device_archive: Path, simulator_archive: Path, lock: Path, inspector: Path, nm: Path,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["VULPRA_VTOOL"] = str(inspector)
    environment["VULPRA_NM"] = str(nm)
    return subprocess.run([
        "python3", str(PROMOTER),
        "--release-tag", "vulpra-engine-v5-candidate",
        "--producer-run-id", str(RUN_ID),
        "--device-archive", str(device_archive),
        "--simulator-archive", str(simulator_archive),
        "--lock", str(lock),
    ], env=environment, text=True, capture_output=True, check=False)


def main() -> None:
    for path in (
        VERIFIER, PROMOTER, PROMOTION_WORKFLOW, DEVICE_CONTRACT, SIMULATOR_CONTRACT,
    ):
        require(path.is_file(), f"missing {path.relative_to(ROOT)}")
    workflow = PROMOTION_WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "producer_run_id:", "release_tag:", "runs-on: macos-26",
        "gh run download \"$run_id\"", "gh release download \"$release_tag\"",
        "promote-engine-artifacts.py", "engine-v5-promotion-${{ inputs.producer_run_id }}",
    ):
        require(token in workflow, f"v5 promotion workflow is missing {token!r}")
    with tempfile.TemporaryDirectory(prefix="vulpra-engine-v5-") as temporary:
        base = Path(temporary)
        device = base / "device"
        simulator = base / "simulator"
        nm = base / "nm"
        fake_nm(nm)
        write_root(device, "iphoneos")
        write_root(simulator, "iphonesimulator")
        for root, platform in ((device, "iphoneos"), (simulator, "iphonesimulator")):
            result = verify(root, platform, nm)
            require(result.returncode == 0, result.stderr or result.stdout)
            require(result.stdout.startswith("engine-artifact-v5-ok "), "v5 verifier output is unstable")

        mutations = (
            ("source-mismatch", "source provenance", lambda value: value["source"].update(commit="b" * 40)),
            ("patch-mismatch", "patch provenance", lambda value: value["patchSet"].update(sha256="0" * 64)),
            ("wrong-target", "targetTriple", lambda value: value["build"].update(targetTriple="aarch64-apple-ios")),
        )
        for name, token, mutate in mutations:
            root = base / name
            values = payload("iphonesimulator")
            value = manifest_for("iphonesimulator", values)
            mutate(value)
            bind_artifact_id(value, "iphonesimulator")
            write_root(root, "iphonesimulator", values, value)
            expect_invalid(root, "iphonesimulator", token, nm)

        forbidden = base / "forbidden-token"
        forbidden_values = payload("iphoneos")
        forbidden_values["runtime/bin/XUL"] += b"\0jit-ready-fd"
        write_root(forbidden, "iphoneos", forbidden_values)
        expect_invalid(forbidden, "iphoneos", "forbidden v5 runtime token", nm)

        missing_header = base / "missing-lifecycle-header"
        missing_values = payload("iphoneos")
        del missing_values["runtime/include/GeckoView/GeckoViewSwiftSupport.h"]
        write_root(missing_header, "iphoneos", missing_values)
        expect_invalid(missing_header, "iphoneos", "required v5 ABI header", nm)

        result = verify(
            device, "iphoneos", nm, omit_export="_GeckoChildProcessDidChange"
        )
        require(result.returncode != 0 and "exported symbol is missing" in result.stderr,
                "v5 verifier accepted a lifecycle token that is not globally exported")

        repeat = base / "repeat"
        repeat_manifest = manifest_for("iphoneos", payload("iphoneos"), RUN_ID + 1)
        write_root(repeat, "iphoneos", manifest=repeat_manifest)
        result = verify(device, "iphoneos", nm, repeat)
        require(result.returncode == 0 and "repeat-match" in result.stdout,
                result.stderr or "repeat build comparison failed")
        changed = base / "repeat-changed"
        changed_values = payload("iphoneos")
        changed_values["runtime/resources/omni.ja"] = b"changed"
        write_root(changed, "iphoneos", changed_values, manifest_for("iphoneos", changed_values, RUN_ID + 1))
        require(verify(device, "iphoneos", nm, changed).returncode != 0,
                "repeat comparison accepted changed resources")
        changed_compile = base / "repeat-compile-changed"
        changed_compile_manifest = manifest_for("iphoneos", payload("iphoneos"), RUN_ID + 1)
        changed_compile_manifest["compiledBy"]["commit"] = "b" * 40
        bind_artifact_id(changed_compile_manifest, "iphoneos")
        write_root(
            changed_compile, "iphoneos",
            manifest=changed_compile_manifest,
        )
        result = verify(device, "iphoneos", nm, changed_compile)
        require(result.returncode != 0 and "repeat v5 build" in result.stderr,
                "repeat comparison normalized away a different compile commit")

        device_archive = base / "vulpra-engine-ios-arm64-v5.tar.gz"
        simulator_archive = base / "vulpra-engine-ios-simulator-native-arm64-v5.tar.gz"
        archive_root(device, device_archive)
        archive_root(simulator, simulator_archive)
        inspector = base / "vtool"
        fake_vtool(inspector)
        lock = base / "engine-artifact-lock.json"
        result = promote(device_archive, simulator_archive, lock, inspector, nm)
        require(result.returncode == 0, result.stderr or result.stdout)
        promoted = json.loads(lock.read_text(encoding="utf-8"))
        require(promoted["schemaVersion"] == 2 and promoted["artifactFormatVersion"] == 5,
                "promotion did not write a complete v5 lock")
        require(promoted["producerRunId"] == RUN_ID and
                promoted["device"]["platform"] == "iphoneos" and
                promoted["simulator"]["platform"] == "iphonesimulator",
                "promotion lost run or platform identity")
        require(promoted["device"]["compiledByRunId"] == RUN_ID and
                promoted["device"]["compiledByHeadSha"] == PRODUCER_COMMIT and
                len(promoted["device"]["buildFingerprint"]) == 64,
                "promotion lost native compilation provenance")

        original_lock = lock.read_bytes()
        unsafe = base / "unsafe.tar.gz"
        with tarfile.open(unsafe, "w:gz") as archive:
            info = tarfile.TarInfo("../escape")
            info.size = 1
            archive.addfile(info, io.BytesIO(b"x"))
        result = promote(device_archive, unsafe, lock, inspector, nm)
        require(result.returncode != 0 and lock.read_bytes() == original_lock,
                "unsafe archive changed the lock before atomic promotion completed")

        same_platform_root = base / "same-platform"
        same_values = payload("iphonesimulator", marker=b"DEVICE-MACHO-SIMULATOR-CONTENT")
        write_root(same_platform_root, "iphonesimulator", same_values)
        same_platform_archive = base / "same-platform.tar.gz"
        archive_root(same_platform_root, same_platform_archive)
        result = promote(device_archive, same_platform_archive, lock, inspector, nm)
        require(result.returncode != 0 and "not a native iOS Simulator" in result.stderr and
                lock.read_bytes() == original_lock,
                "promotion accepted same-platform binaries or changed the existing lock")

    print("PASS: native Gecko v5 artifact and atomic promotion contracts")


if __name__ == "__main__":
    main()
