#!/usr/bin/env python3
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "Configuration/engine-artifact-v4.json"
SIMULATOR_CONTRACT = ROOT / "Configuration/engine-artifact-simulator-v4.json"
VERIFIER = ROOT / "Tools/Engine/verify-engine-artifact.py"

PAYLOAD = {
    "runtime/bin/XUL": b"xul-kernel-VulpraEngineRuntime",
    "runtime/lib/libmozglue.dylib": b"runtime-library",
    "runtime/include/Gecko/IOSBootstrap.h": b"abi-header",
    "runtime/resources/omni.ja": b"runtime-resource",
    "licenses/LICENSE.mozilla.txt": b"license",
    "licenses/NOTICE.txt": b"notice",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def write_payload(root: Path, payload: dict[str, bytes] = PAYLOAD) -> None:
    for relative, content in payload.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)


def manifest_files(root: Path) -> list[dict[str, object]]:
    entries = []
    for path in sorted(item for item in root.rglob("*") if item.is_file() and item.name != "manifest.json"):
        content = path.read_bytes()
        entries.append(
            {
                "path": path.relative_to(root).as_posix(),
                "size": len(content),
                "sha256": hashlib.sha256(content).hexdigest(),
            }
        )
    return entries


def base_manifest(root: Path) -> dict[str, object]:
    return {
        "formatVersion": 4,
        "artifactId": "",
        "abiVersion": "gecko-ios-abi-1",
        "source": {
            "repository": "https://github.com/mozilla-firefox/firefox",
            "commit": "b" * 40,
        },
        "build": {
            "xcodeBuild": "17A400",
            "sdkBuild": "23A339",
            "platform": "iphoneos",
            "architecture": "arm64",
        },
        "licenses": ["licenses/LICENSE.mozilla.txt"],
        "notices": ["licenses/NOTICE.txt"],
        "files": manifest_files(root),
    }


def content_bound_artifact_id(manifest: dict[str, object]) -> str:
    identity = copy.deepcopy(manifest)
    identity["artifactId"] = ""
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return f"vulpra-gecko-ios-arm64-v4-{hashlib.sha256(canonical).hexdigest()}"


def write_manifest(root: Path, manifest: dict[str, object] | None = None) -> dict[str, object]:
    value = manifest if manifest is not None else base_manifest(root)
    value["artifactId"] = content_bound_artifact_id(value)
    (root / "manifest.json").write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    return value


def make_fixture(parent: Path, name: str) -> tuple[Path, dict[str, object]]:
    fixture = parent / name
    fixture.mkdir()
    write_payload(fixture)
    return fixture, write_manifest(fixture)


def verify(fixture: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VERIFIER), "--contract", str(CONTRACT), str(fixture)],
        text=True,
        capture_output=True,
        check=False,
    )


def expect_valid(fixture: Path) -> None:
    result = verify(fixture)
    require(result.returncode == 0, f"valid artifact rejected: {result.stderr or result.stdout}")
    require(result.stdout.startswith("engine-artifact-v4-ok "), "valid result is not deterministic")


def expect_invalid(fixture: Path, token: str) -> None:
    result = verify(fixture)
    require(result.returncode != 0, f"invalid artifact was accepted: {fixture.name}")
    require(token in result.stderr, f"failure for {fixture.name} did not contain {token!r}: {result.stderr}")


def main() -> None:
    require(CONTRACT.is_file(), "missing Configuration/engine-artifact-v4.json")
    require(SIMULATOR_CONTRACT.is_file(), "missing Configuration/engine-artifact-simulator-v4.json")
    require(VERIFIER.is_file(), "missing Tools/Engine/verify-engine-artifact.py")

    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(contract.get("schemaVersion") == 1, "artifact contract schemaVersion must be 1")
    require(contract.get("formatVersion") == 4, "artifact formatVersion must be 4")
    require(contract.get("artifactIdPrefix") == "vulpra-gecko-ios-arm64-v4-",
            "artifact ID prefix is wrong")
    require(contract.get("manifestFile") == "manifest.json", "artifact manifest path must be manifest.json")
    require(contract.get("platform") == "iphoneos", "artifact platform must be iphoneos")
    require(contract.get("architecture") == "arm64", "artifact architecture must be arm64")
    require(contract.get("requiredKernelToken") == "VulpraEngineRuntime",
            "independent runtime layout token is wrong")
    require(contract.get("runtimeResourceContainer") == "VulpraEngineRuntime",
            "device runtime resource container is wrong")
    simulator_contract = json.loads(SIMULATOR_CONTRACT.read_text(encoding="utf-8"))
    require(simulator_contract.get("platform") == "iphonesimulator",
            "Simulator artifact platform is wrong")
    require(simulator_contract.get("requiredKernelToken") == "_MainProcessInit",
            "Simulator artifact does not verify the real process startup ABI")
    require(simulator_contract.get("runtimeResourceContainer") == "GeckoView.framework",
            "Simulator runtime resource container does not match its immutable XUL layout")
    require(
        contract.get("allowedRoots")
        == ["runtime/bin", "runtime/lib", "runtime/include", "runtime/resources", "licenses"],
        "artifact allowed roots are wrong",
    )

    with tempfile.TemporaryDirectory(prefix="vulpra-engine-v4-") as temporary:
        fixtures = Path(temporary)

        valid, _ = make_fixture(fixtures, "valid")
        expect_valid(valid)

        unbound, unbound_manifest = make_fixture(fixtures, "unbound-artifact-id")
        unbound_manifest["artifactId"] = f"vulpra-gecko-ios-arm64-v4-{'0' * 64}"
        (unbound / "manifest.json").write_text(json.dumps(unbound_manifest, indent=2) + "\n", encoding="utf-8")
        expect_invalid(unbound, "content identity")

        missing_xul, _ = make_fixture(fixtures, "missing-xul")
        (missing_xul / "runtime/bin/XUL").unlink()
        expect_invalid(missing_xul, "missing declared file")

        missing_dylib, _ = make_fixture(fixtures, "missing-dylib")
        (missing_dylib / "runtime/lib/libmozglue.dylib").unlink()
        write_manifest(missing_dylib)
        expect_invalid(missing_dylib, "runtime dylib")

        for name, relative, token in (
            ("empty-headers", "runtime/include/Gecko/IOSBootstrap.h", "runtime/include"),
            ("empty-resources", "runtime/resources/omni.ja", "runtime/resources"),
            ("missing-license", "licenses/LICENSE.mozilla.txt", "license path"),
            ("missing-notice", "licenses/NOTICE.txt", "notice path"),
        ):
            fixture, _ = make_fixture(fixtures, name)
            (fixture / relative).unlink()
            write_manifest(fixture)
            expect_invalid(fixture, token)

        undeclared, _ = make_fixture(fixtures, "undeclared")
        (undeclared / "runtime/resources/extra.dat").write_bytes(b"extra")
        expect_invalid(undeclared, "undeclared payload file")

        checksum, _ = make_fixture(fixtures, "checksum")
        (checksum / "runtime/bin/XUL").write_bytes(
            PAYLOAD["runtime/bin/XUL"].replace(b"x", b"X", 1)
        )
        expect_invalid(checksum, "checksum mismatch")

        inherited_layout, _ = make_fixture(fixtures, "inherited-layout")
        (inherited_layout / "runtime/bin/XUL").write_bytes(b"xul-kernel")
        write_manifest(inherited_layout)
        expect_invalid(inherited_layout, "independent runtime layout")

        size, size_manifest = make_fixture(fixtures, "size")
        size_manifest["files"][0]["size"] += 1
        write_manifest(size, size_manifest)
        expect_invalid(size, "size mismatch")

        duplicate, duplicate_manifest = make_fixture(fixtures, "duplicate")
        duplicate_manifest["files"].append(copy.deepcopy(duplicate_manifest["files"][0]))
        write_manifest(duplicate, duplicate_manifest)
        expect_invalid(duplicate, "duplicate manifest path")

        traversal, traversal_manifest = make_fixture(fixtures, "traversal")
        traversal_manifest["files"].append({"path": "../escape", "size": 1, "sha256": "0" * 64})
        write_manifest(traversal, traversal_manifest)
        expect_invalid(traversal, "normalized repository-relative path")

        symlink, _ = make_fixture(fixtures, "symlink")
        link = symlink / "runtime/resources/link"
        link.symlink_to("../bin/XUL")
        expect_invalid(symlink, "symbolic link")

        executable, _ = make_fixture(fixtures, "executable")
        tool = executable / "runtime/resources/xpcshell"
        tool.write_bytes(b"tool")
        tool.chmod(0o755)
        write_manifest(executable)
        expect_invalid(executable, "unexpected executable")

        allowed_executables, _ = make_fixture(fixtures, "allowed-executables")
        (allowed_executables / "runtime/bin/XUL").chmod(0o755)
        (allowed_executables / "runtime/lib/libmozglue.dylib").chmod(0o755)
        expect_valid(allowed_executables)

        forbidden_cases = (
            ("framework", "runtime/resources/GeckoView.framework/GeckoView", "framework"),
            ("helper", "runtime/resources/Vulpra Helper.appex/Info.plist", "app extension"),
            ("jit", "runtime/resources/JIT/code.bin", "JIT"),
            ("patch", "runtime/resources/Patches/widget.patch", "patch"),
            ("source", "runtime/resources/Bridge.swift", "source file"),
            ("product-ui", "runtime/resources/Vulpra.app/Info.plist", "application product"),
        )
        for name, relative, token in forbidden_cases:
            fixture, _ = make_fixture(fixtures, name)
            path = fixture / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"forbidden")
            write_manifest(fixture)
            expect_invalid(fixture, token)

        wrong_fields = (
            ("format", ("formatVersion",), 3, "formatVersion"),
            ("abi", ("abiVersion",), "", "abiVersion"),
            ("platform", ("build", "platform"), "iphonesimulator", "platform"),
            ("architecture", ("build", "architecture"), "x86_64", "architecture"),
        )
        for name, keys, value, token in wrong_fields:
            fixture, manifest = make_fixture(fixtures, name)
            owner = manifest
            for key in keys[:-1]:
                owner = owner[key]
            owner[keys[-1]] = value
            write_manifest(fixture, manifest)
            expect_invalid(fixture, token)

    print("PASS: Gecko engine artifact v4 contract")


if __name__ == "__main__":
    main()
