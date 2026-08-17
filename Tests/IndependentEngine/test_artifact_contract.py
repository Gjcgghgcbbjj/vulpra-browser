#!/usr/bin/env python3
"""Exercise the v4 engine artifact verifier with deterministic fixtures."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VERIFIER_PATH = ROOT / "Tools/Engine/verify-engine-artifact.py"
spec = importlib.util.spec_from_file_location("verify_engine_artifact", VERIFIER_PATH)
assert spec and spec.loader
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def write_file(root: Path, name: str, contents: bytes) -> None:
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(contents)


def make_fixture(root: Path) -> None:
    payload = {
        "runtime/bin/XUL": b"xul-kernel",
        "runtime/lib/libmozglue.dylib": b"mozglue",
        "runtime/include/vulpra-engine.h": b"#ifndef VULPRA_ENGINE_H\n",
        "runtime/resources/default-theme/manifest.json": b"{}",
        "licenses/LICENSE": b"GPL-3.0-only\n",
    }
    entries = []
    for path, contents in payload.items():
        write_file(root, path, contents)
        entries.append({
            "path": path,
            "kind": {
                "runtime/bin": "binary",
                "runtime/lib": "dylib",
                "runtime/include": "header",
                "runtime/resources": "resource",
                "licenses": "notice",
            }[next(prefix for prefix in ("runtime/bin", "runtime/lib", "runtime/include", "runtime/resources", "licenses") if path == prefix or path.startswith(prefix + "/"))],
            "size": len(contents),
            "sha256": hashlib.sha256(contents).hexdigest(),
        })
    entries.sort(key=lambda item: item["path"])
    (root / "manifest.json").write_text(json.dumps({
        "formatVersion": 4,
        "artifactKind": "vulpra-gecko-kernel",
        "platform": "iphoneos",
        "architecture": "arm64",
        "abiVersion": "vulpra-gecko-abi-v1",
        "sourceIdentity": "firefox-test-source",
        "buildIdentity": "fixture-v4",
        "licenses": ["licenses/LICENSE"],
        "files": entries,
    }, indent=2) + "\n", encoding="utf-8")


def expect_invalid(root: Path, message: str) -> None:
    try:
        verifier.validate_artifact(root)
    except verifier.ArtifactError:
        return
    raise AssertionError(f"expected invalid fixture: {message}")


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        make_fixture(root)
        verifier.validate_artifact(root)

        (root / "runtime/bin/XUL").unlink()
        expect_invalid(root, "missing XUL")
        make_fixture(root)
        manifest = json.loads((root / "manifest.json").read_text())
        manifest["files"][0]["sha256"] = "0" * 64
        (root / "manifest.json").write_text(json.dumps(manifest))
        expect_invalid(root, "checksum mismatch")
        make_fixture(root)
        manifest = json.loads((root / "manifest.json").read_text())
        manifest["files"].append(dict(manifest["files"][0]))
        (root / "manifest.json").write_text(json.dumps(manifest))
        expect_invalid(root, "duplicate path")
        make_fixture(root)
        write_file(root, "runtime/resources/GeckoView.framework/Info.plist", b"bad")
        manifest = json.loads((root / "manifest.json").read_text())
        bad = {"path": "runtime/resources/GeckoView.framework/Info.plist", "kind": "resource", "size": 3, "sha256": hashlib.sha256(b"bad").hexdigest()}
        manifest["files"].append(bad)
        manifest["files"].sort(key=lambda item: item["path"])
        (root / "manifest.json").write_text(json.dumps(manifest))
        expect_invalid(root, "forbidden inherited framework")
        make_fixture(root)
        (root / "runtime/resources/link").symlink_to(root / "runtime/bin/XUL")
        manifest = json.loads((root / "manifest.json").read_text())
        manifest["files"].append({"path": "runtime/resources/link", "kind": "resource", "size": 10, "sha256": hashlib.sha256(b"xul-kernel").hexdigest()})
        manifest["files"].sort(key=lambda item: item["path"])
        (root / "manifest.json").write_text(json.dumps(manifest))
        expect_invalid(root, "symlink")
    print("PASS: engine artifact v4 contract fixtures")


if __name__ == "__main__":
    main()
