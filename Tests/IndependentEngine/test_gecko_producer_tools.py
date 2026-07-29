#!/usr/bin/env python3
"""Portable fixtures for native Gecko v5 producer tools."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "Configuration/gecko-producer-v5.json"
FETCH = ROOT / "Tools/GeckoProducer/fetch-source.sh"
APPLY = ROOT / "Tools/GeckoProducer/apply-series.py"
BUILD = ROOT / "Tools/GeckoProducer/build-runtime.sh"
PACKAGE = ROOT / "Tools/GeckoProducer/package-runtime.py"
WORKFLOW = ROOT / ".github/workflows/produce-gecko-v5.yml"
PINNED_COMMIT = "27b462b22705a8860f7ab0d33aa5b4b658ae5932"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def write(path: Path, content: str | bytes, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(content, str):
        path.write_text(content, encoding="utf-8")
    else:
        path.write_bytes(content)
    if executable:
        path.chmod(path.stat().st_mode | stat.S_IXUSR)


def run(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, check=False, **kwargs)


def test_fetch(base: Path) -> None:
    fake_bin = base / "fake-bin"
    log = base / "git.log"
    fake_git = fake_bin / "git"
    write(fake_git, f"""#!/bin/sh
set -eu
printf '%s\\n' "$*" >> "$VULPRA_FAKE_GIT_LOG"
if [ "$1" = init ]; then mkdir -p "$2/.git"; exit 0; fi
if [ "$1" = -C ] && [ "$3" = rev-parse ]; then printf '%s\\n' {PINNED_COMMIT}; exit 0; fi
if [ "$1" = -C ] && [ "$3" = status ]; then exit 0; fi
exit 0
""", executable=True)
    destination = base / "fetched"
    environment = os.environ.copy()
    environment.update({
        "PATH": f"{fake_bin}:/usr/bin:/bin",
        "VULPRA_FAKE_GIT_LOG": str(log),
    })
    result = run([str(FETCH), str(CONTRACT), str(destination)], env=environment)
    require(result.returncode == 0, result.stderr or result.stdout)
    operations = log.read_text(encoding="utf-8")
    require("fetch --depth=1 origin " + PINNED_COMMIT in operations,
            "fetch tool did not fetch the pinned commit")
    require("checkout --detach FETCH_HEAD" in operations,
            "fetch tool did not create a detached checkout")
    result = run([str(FETCH), str(CONTRACT), str(destination)], env=environment)
    require(result.returncode != 0 and "destination already exists" in result.stderr,
            "fetch tool accepted a pre-populated destination")


def test_apply(base: Path) -> None:
    fixture = base / "apply-root"
    source = base / "apply-source"
    verifier = fixture / "Tools/GeckoProducer/verify-producer.py"
    write(verifier, "#!/usr/bin/env python3\nraise SystemExit(0)\n", executable=True)
    subprocess.run(["git", "init", "-q", str(source)], check=True)
    subprocess.run(["git", "-C", str(source), "config", "user.email", "test@example.invalid"], check=True)
    subprocess.run(["git", "-C", str(source), "config", "user.name", "Vulpra Test"], check=True)
    write(source / "example.txt", "before\n")
    subprocess.run(["git", "-C", str(source), "add", "example.txt"], check=True)
    subprocess.run(["git", "-C", str(source), "commit", "-qm", "fixture"], check=True)
    head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()

    patch = fixture / "Engine/GeckoPatches/v5/platform/example.patch"
    write(patch,
          "diff --git a/example.txt b/example.txt\n"
          "index 90be1dd..2ae38f5 100644\n"
          "--- a/example.txt\n+++ b/example.txt\n"
          "@@ -1 +1 @@\n-before\n+after\n")
    series = {"schemaVersion": 1, "patches": [{
        "order": 1,
        "path": "platform/example.patch",
        "sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
        "owner": "engine-platform",
        "purpose": "Adapt the fixture for standalone iOS.",
        "upstreamPaths": ["example.txt"],
    }]}
    write(fixture / "Engine/GeckoPatches/v5/series.json", json.dumps(series))
    contract = {
        "upstream": {"commit": head},
        "patchSeries": "Engine/GeckoPatches/v5/series.json",
    }
    contract_path = fixture / "Configuration/gecko-producer-v5.json"
    write(contract_path, json.dumps(contract))
    result = run([
        "python3", str(APPLY), "--contract", str(contract_path),
        "--source", str(source), "--root", str(fixture),
    ])
    require(result.returncode == 0, result.stderr or result.stdout)
    require((source / "example.txt").read_text(encoding="utf-8") == "after\n",
            "apply tool did not apply the ordered patch")
    result = run([
        "python3", str(APPLY), "--contract", str(contract_path),
        "--source", str(source), "--root", str(fixture),
    ])
    require(result.returncode != 0 and "must be clean" in result.stderr,
            "apply tool accepted an already modified source checkout")


def test_build(base: Path) -> None:
    source = base / "build-source"
    (source / ".git").mkdir(parents=True)
    mach_log = base / "mach.log"
    fake_mach = base / "fake-mach"
    write(fake_mach, "#!/bin/sh\nprintf '%s|%s\\n' \"$MOZCONFIG\" \"$*\" > \"$VULPRA_MACH_LOG\"\n",
          executable=True)
    environment = os.environ.copy()
    environment.update({
        "PATH": "/usr/bin:/bin",
        "VULPRA_MACH": str(fake_mach),
        "VULPRA_MACH_LOG": str(mach_log),
    })
    expected = {
        "iphoneos": "aarch64-apple-ios",
        "iphonesimulator": "aarch64-apple-ios-sim",
    }
    for platform, triple in expected.items():
        result = run([str(BUILD), platform, str(source)], env=environment)
        require(result.returncode == 0, result.stderr or result.stdout)
        mozconfig = source / f".mozconfig-vulpra-{platform}"
        contents = mozconfig.read_text(encoding="utf-8")
        require(f"--target={triple}" in contents and
                "--enable-application=mobile/ios" in contents and
                "--enable-ios-target=15.0" in contents and
                "--enable-linker=ld64" in contents and
                "--enable-optimize" in contents and
                "--disable-debug" in contents and
                "--disable-tests" in contents,
                f"{platform} mozconfig is incomplete")
        require(str(mozconfig) in mach_log.read_text(encoding="utf-8"),
                "build did not pass the generated MOZCONFIG to mach")

    source_mach = source / "mach"
    write(source_mach,
          "#!/bin/sh\nprintf '%s|%s\\n' \"$MOZCONFIG\" \"$*\" > \"$VULPRA_MACH_LOG\"\n",
          executable=True)
    relative_environment = environment.copy()
    relative_environment.pop("VULPRA_MACH")
    result = run([str(BUILD), "iphoneos", source.name], env=relative_environment, cwd=base)
    require(result.returncode == 0, result.stderr or result.stdout)
    require(str(source / ".mozconfig-vulpra-iphoneos") in mach_log.read_text(encoding="utf-8"),
            "build did not canonicalize a relative source checkout")


def test_package(base: Path) -> None:
    source = base / "package-source"
    dist = source / "obj-aarch64-apple-ios-sim/dist"
    mozconfig = source / ".mozconfig-vulpra-iphonesimulator"
    write(mozconfig, "ac_add_options --target=aarch64-apple-ios-sim\n")
    write(source / "LICENSE", "MPL 2.0 fixture\n")
    write(source / "toolkit/content/license.html", "third party fixture\n")
    write(dist / "bin/XUL", b"native-simulator-XUL", executable=True)
    write(dist / "bin/libmozglue.dylib", b"native-simulator-dylib", executable=True)
    write(dist / "bin/application.ini", "[App]\nName=Vulpra\n")
    for header in (
        "GeckoViewRuntimeSupport.h", "GeckoViewSwiftSupport.h", "IOSBootstrap.h"
    ):
        write(dist / f"include/GeckoView/{header}", f"// {header}\n")

    environment = os.environ.copy()
    for name in ("GITHUB_ACTIONS", "GITHUB_SHA", "GITHUB_RUN_ID"):
        environment.pop(name, None)
    environment.update({
        "VULPRA_XCODE_BUILD": "17E202",
        "VULPRA_SDK_BUILD": "23E252",
    })
    outputs = [base / "runtime-a.tar.gz", base / "runtime-b.tar.gz"]
    for output in outputs:
        result = run([
            "python3", str(PACKAGE), "--contract", str(CONTRACT),
            "--platform", "iphonesimulator", "--dist", str(dist),
            "--mozconfig", str(mozconfig), "--output", str(output),
        ], env=environment)
        require(result.returncode == 0, result.stderr or result.stdout)
    require(outputs[0].read_bytes() == outputs[1].read_bytes(),
            "packaging is not byte-for-byte deterministic")

    with tarfile.open(outputs[0], "r:gz") as archive:
        members = archive.getmembers()
        names = [member.name for member in members]
        require(all(not member.issym() and not member.islnk() for member in members),
                "artifact contains a link")
        require(all(not name.startswith("/") and ".." not in Path(name).parts for name in names),
                "artifact contains an unsafe path")
        require("runtime/bin/XUL" in names and "runtime/lib/libmozglue.dylib" in names,
                "artifact is missing native runtime binaries")
        manifest_file = archive.extractfile("manifest.json")
        require(manifest_file is not None, "artifact manifest is missing")
        manifest = json.load(manifest_file)
    require(manifest["formatVersion"] == 5 and
            manifest["source"]["commit"] == PINNED_COMMIT and
            manifest["build"]["platform"] == "iphonesimulator" and
            manifest["build"]["targetTriple"] == "aarch64-apple-ios-sim" and
            manifest["build"]["mozconfigSHA256"] == hashlib.sha256(mozconfig.read_bytes()).hexdigest() and
            manifest["producer"]["workflowRunId"] == 0,
            "artifact manifest lost producer content identity")

    (dist / "bin/unsafe-resource").symlink_to("application.ini")
    result = run([
        "python3", str(PACKAGE), "--contract", str(CONTRACT),
        "--platform", "iphonesimulator", "--dist", str(dist),
        "--mozconfig", str(mozconfig), "--output", str(base / "unsafe.tar.gz"),
    ], env=environment)
    require(result.returncode != 0 and "symbolic links are forbidden" in result.stderr,
            "packaging accepted an unsafe resource link")


def main() -> None:
    for tool in (FETCH, APPLY, BUILD, PACKAGE):
        require(tool.is_file(), f"missing producer tool: {tool.relative_to(ROOT)}")
    source = "\n".join(tool.read_text(encoding="utf-8") for tool in (FETCH, APPLY, BUILD, PACKAGE))
    forbidden_transform = "v" + "tool"
    require(forbidden_transform not in source and "set-build-version" not in source,
            "native producer retains a Mach-O platform transform")

    require(WORKFLOW.is_file(), "missing dual-platform Gecko v5 workflow")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "workflow_dispatch:",
        "release_tag:",
        "publish_release:",
        "default: vulpra-engine-v5-candidate",
        "default: false",
        "runs-on: macos-26",
        "platform: [iphoneos, iphonesimulator]",
        "/Applications/Xcode_26.4.1.app",
        "fetch-source.sh",
        "apply-series.py",
        "build-runtime.sh",
        "package-runtime.py",
        "Verify cross-target identity and native distinction",
        "retention-days: 30",
        "gh release upload",
    ):
        require(token in workflow, f"Gecko v5 workflow is missing {token!r}")
    require("produce-simulator-artifact.sh" not in workflow and
            forbidden_transform not in workflow and "--clobber" not in workflow,
            "Gecko v5 workflow retains an old or destructive producer path")

    with tempfile.TemporaryDirectory(prefix="vulpra-gecko-producer-tools-") as temporary:
        base = Path(temporary)
        test_fetch(base)
        test_apply(base)
        test_build(base)
        test_package(base)

    print("PASS: native Gecko v5 producer and packaging fixtures")


if __name__ == "__main__":
    main()
