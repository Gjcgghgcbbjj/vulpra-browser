#!/usr/bin/env python3
"""Portable fixtures for native Gecko v5 producer tools."""

from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import shutil
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
SNAPSHOT = ROOT / "Tools/GeckoProducer/build-snapshot.py"
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
    write(fake_mach, """#!/bin/sh
printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \
  "$MOZCONFIG" "$*" "$CC" "$HOST_CC" "$WASM_CC" "$MOZBUILD_STATE_PATH" \
  "$MOZ_BUILD_DATE" "$SOURCE_DATE_EPOCH" \
  > "$VULPRA_MACH_LOG"
""", executable=True)
    environment = os.environ.copy()
    environment.update({
        "PATH": "/usr/bin:/bin",
        "VULPRA_MACH": str(fake_mach),
        "VULPRA_MACH_LOG": str(mach_log),
        "VULPRA_TARGET_CC": "/fixture/xcode/clang",
        "VULPRA_TARGET_CXX": "/fixture/xcode/clang++",
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
                "--enable-bootstrap=cbindgen,clang,sysroot-wasm32-wasi" in contents and
                "--enable-linker=ld64" in contents and
                "--enable-optimize" in contents and
                "--disable-debug" in contents and
                "--disable-tests" in contents,
                f"{platform} mozconfig is incomplete")
        require(str(mozconfig) in mach_log.read_text(encoding="utf-8"),
                "build did not pass the generated MOZCONFIG to mach")
        mach_invocation = mach_log.read_text(encoding="utf-8")
        require("|/fixture/xcode/clang|/fixture/xcode/clang|" in mach_invocation,
                "build did not keep target and host compilation on Xcode clang")
        require("/.build/gecko-toolchains/clang/bin/clang|" in mach_invocation,
                "build did not isolate WASI compilation to the bootstrapped Gecko clang")
        require("|20260713164006|1783960806" in mach_invocation,
                "build did not pin Firefox build time to the upstream commit")

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
    write(dist / "bin/plugin-container", b"unused-child-tool", executable=True)
    exported_resource = source / "browser/app/application.ini"
    write(exported_resource, "[App]\nName=Vulpra\n")
    (dist / "bin").mkdir(parents=True, exist_ok=True)
    (dist / "bin/application.ini").symlink_to(exported_resource)
    exported_header = source / "widget/uikit/GeckoViewSwiftSupport.h"
    write(exported_header, "// GeckoViewSwiftSupport.h\n")
    exported_path = dist / "include/GeckoView/GeckoViewSwiftSupport.h"
    exported_path.parent.mkdir(parents=True, exist_ok=True)
    exported_path.symlink_to(exported_header)
    write(dist / "include/GeckoView/IOSBootstrap.h", "// IOSBootstrap.h\n")
    write(source / ".vulpra-build-provenance.json", json.dumps({
        "schemaVersion": 1,
        "compiledBy": {
            "repository": "https://github.com/Gjcgghgcbbjj/vulpra-browser",
            "commit": "0" * 40, "workflowRunId": 0, "buildFingerprint": "1" * 64,
        },
    }))

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
        require("runtime/resources/plugin-container" not in names,
                "artifact packaged a dist executable as a runtime resource")
        require(all(not member.mode & 0o111 for member in members
                    if member.name.startswith("runtime/resources/")),
                "artifact resource unexpectedly retains an executable mode")
        manifest_file = archive.extractfile("manifest.json")
        require(manifest_file is not None, "artifact manifest is missing")
        manifest = json.load(manifest_file)
    require(manifest["formatVersion"] == 5 and
            manifest["source"]["commit"] == PINNED_COMMIT and
            manifest["build"]["platform"] == "iphonesimulator" and
            manifest["build"]["targetTriple"] == "aarch64-apple-ios-sim" and
            manifest["build"]["mozBuildDate"] == "20260713164006" and
            manifest["build"]["sourceDateEpoch"] == 1783960806 and
            manifest["build"]["mozconfigSHA256"] == hashlib.sha256(mozconfig.read_bytes()).hexdigest() and
            manifest["producer"]["workflowRunId"] == 0,
            "artifact manifest lost producer content identity")
    require(manifest["compiledBy"]["workflowRunId"] == 0 and
            manifest["compiledBy"]["buildFingerprint"] == "1" * 64,
            "artifact manifest lost native compilation provenance")

    exported_path.unlink()
    outside_header = base / "outside-header.h"
    write(outside_header, "// outside\n")
    exported_path.symlink_to(outside_header)
    result = run([
        "python3", str(PACKAGE), "--contract", str(CONTRACT),
        "--platform", "iphonesimulator", "--dist", str(dist),
        "--mozconfig", str(mozconfig), "--output", str(base / "escaped.tar.gz"),
    ], env=environment)
    require(result.returncode != 0 and "resolves outside Gecko source" in result.stderr,
            "packaging accepted an exported header link outside the pinned source")
    exported_path.unlink()
    write(exported_path, "// GeckoViewSwiftSupport.h\n")

    outside_resource = base / "outside-resource"
    write(outside_resource, "outside\n")
    (dist / "bin/unsafe-resource").symlink_to(outside_resource)
    result = run([
        "python3", str(PACKAGE), "--contract", str(CONTRACT),
        "--platform", "iphonesimulator", "--dist", str(dist),
        "--mozconfig", str(mozconfig), "--output", str(base / "unsafe.tar.gz"),
    ], env=environment)
    require(result.returncode != 0 and "resolves outside Gecko source" in result.stderr,
            "packaging accepted a resource link outside the pinned source")
    (dist / "bin/unsafe-resource").unlink()

    exported_directory = dist / "include/GeckoView"
    shutil.rmtree(exported_directory)
    outside_headers = base / "outside-headers"
    write(outside_headers / "GeckoViewSwiftSupport.h", "// outside support\n")
    write(outside_headers / "IOSBootstrap.h", "// outside bootstrap\n")
    exported_directory.symlink_to(outside_headers, target_is_directory=True)
    result = run([
        "python3", str(PACKAGE), "--contract", str(CONTRACT),
        "--platform", "iphonesimulator", "--dist", str(dist),
        "--mozconfig", str(mozconfig), "--output", str(base / "unsafe-parent.tar.gz"),
    ], env=environment)
    require(result.returncode != 0 and "resolves outside Gecko source" in result.stderr,
            "packaging accepted an ABI header beneath an escaping parent link")


def test_build_snapshot(base: Path) -> None:
    source = base / "snapshot-source"
    dist = source / "obj-aarch64-apple-ios-sim/dist"
    mozconfig = source / ".mozconfig-vulpra-iphonesimulator"
    write(mozconfig, "ac_add_options --target=aarch64-apple-ios-sim\n")
    write(source / "LICENSE", "MPL 2.0 fixture\n")
    write(source / "toolkit/content/license.html", "third party fixture\n")
    write(dist / "bin/XUL", b"native-simulator-XUL", executable=True)
    write(dist / "lib/libmozglue.dylib", b"native-simulator-dylib", executable=True)
    linked_resource = source / "browser/app/application.ini"
    write(linked_resource, "[App]\nName=Vulpra\n")
    (dist / "bin/application.ini").symlink_to(linked_resource)
    write(dist / "include/GeckoView/GeckoViewSwiftSupport.h", "// support\n")
    write(dist / "include/GeckoView/IOSBootstrap.h", "// bootstrap\n")

    archive = base / "snapshot.tar.gz"
    common = [
        "--contract", str(CONTRACT),
        "--platform", "iphonesimulator",
        "--xcode-build", "17E202",
        "--sdk-build", "23E252",
    ]
    result = run([
        "python3", str(SNAPSHOT), "create", *common,
        "--source", str(source),
        "--producer-commit", "1" * 40,
        "--producer-run-id", "123",
        "--output", str(archive),
    ])
    require(result.returncode == 0, result.stderr or result.stdout)
    with tarfile.open(archive, "r:gz") as snapshot:
        members = snapshot.getmembers()
        require(all(not member.issym() and not member.islnk() for member in members),
                "build snapshot contains a link")
        linked = snapshot.extractfile("dist/bin/application.ini")
        require(linked is not None and linked.read() == linked_resource.read_bytes(),
                "build snapshot did not materialize a source-internal dist link")
        snapshot_manifest = snapshot.extractfile("snapshot.json")
        require(snapshot_manifest is not None and
                json.load(snapshot_manifest)["buildIdentity"]["reproducibleBuild"] == {
                    "mozBuildDate": "20260713164006",
                    "sourceDateEpoch": 1783960806,
                }, "build snapshot lost reproducible build inputs")

    extracted = base / "extracted-snapshot"
    extract_common = [*common, "--expected-producer-run-id", "123"]
    result = run([
        "python3", str(SNAPSHOT), "extract", *extract_common,
        "--archive", str(archive), "--output", str(extracted),
    ])
    require(result.returncode == 0, result.stderr or result.stdout)
    require((extracted / "dist/bin/application.ini").read_bytes() == linked_resource.read_bytes(),
            "verified build snapshot extraction lost resource content")
    provenance = json.loads(
        (extracted / ".vulpra-build-provenance.json").read_text(encoding="utf-8")
    )
    require(provenance["compiledBy"]["workflowRunId"] == 123 and
            len(provenance["compiledBy"]["buildFingerprint"]) == 64,
            "verified snapshot extraction lost native compilation provenance")
    result = run([
        "python3", str(SNAPSHOT), "extract", *common,
        "--expected-producer-run-id", "124",
        "--archive", str(archive), "--output", str(base / "wrong-run"),
    ])
    require(result.returncode != 0 and "producer run identity mismatch" in result.stderr,
            "build snapshot accepted a different requested producer run")

    tampered = base / "tampered-snapshot.tar.gz"
    with tarfile.open(archive, "r:gz") as source_archive:
        with tarfile.open(tampered, "w:gz") as target_archive:
            for member in source_archive.getmembers():
                source_file = source_archive.extractfile(member)
                require(source_file is not None, "snapshot fixture contains a non-file member")
                content = source_file.read()
                if member.name == "dist/bin/application.ini":
                    content += b"tampered\n"
                    member.size = len(content)
                target_archive.addfile(member, io.BytesIO(content))
    result = run([
        "python3", str(SNAPSHOT), "extract", *extract_common,
        "--archive", str(tampered), "--output", str(base / "tampered-output"),
    ])
    require(result.returncode != 0 and "content identity mismatch" in result.stderr,
            "build snapshot accepted content that disagrees with its inventory")

    result = run([
        "python3", str(SNAPSHOT), "extract",
        *["17E203" if item == "17E202" else item for item in extract_common],
        "--archive", str(archive), "--output", str(base / "wrong-toolchain"),
    ])
    require(result.returncode != 0 and "toolchain identity mismatch" in result.stderr,
            "build snapshot accepted a different Xcode build")

    outside = base / "outside-resource"
    write(outside, "outside\n")
    # Replace a captured resource with a link outside the pinned source tree.
    unsafe = dist / "bin/unsafe-resource"
    unsafe.symlink_to(outside)
    result = run([
        "python3", str(SNAPSHOT), "create", *common,
        "--source", str(source),
        "--producer-commit", "1" * 40,
        "--producer-run-id", "124",
        "--output", str(base / "unsafe-snapshot.tar.gz"),
    ])
    require(result.returncode != 0 and "resolves outside Gecko source" in result.stderr,
            "build snapshot accepted a dist link outside the pinned source")
    unsafe.unlink()

    exported_directory = dist / "include/GeckoView"
    shutil.rmtree(exported_directory)
    outside_headers = base / "snapshot-outside-headers"
    write(outside_headers / "GeckoViewSwiftSupport.h", "// outside support\n")
    write(outside_headers / "IOSBootstrap.h", "// outside bootstrap\n")
    exported_directory.symlink_to(outside_headers, target_is_directory=True)
    result = run([
        "python3", str(SNAPSHOT), "create", *common,
        "--source", str(source),
        "--producer-commit", "1" * 40,
        "--producer-run-id", "125",
        "--output", str(base / "unsafe-parent-snapshot.tar.gz"),
    ])
    require(result.returncode != 0 and "resolves outside Gecko source" in result.stderr,
            "build snapshot accepted a header beneath an escaping parent link")


def main() -> None:
    for tool in (FETCH, APPLY, BUILD, PACKAGE, SNAPSHOT):
        require(tool.is_file(), f"missing producer tool: {tool.relative_to(ROOT)}")
    source = "\n".join(
        tool.read_text(encoding="utf-8")
        for tool in (FETCH, APPLY, BUILD, PACKAGE, SNAPSHOT)
    )
    forbidden_transform = "v" + "tool"
    require(forbidden_transform not in source and "set-build-version" not in source,
            "native producer retains a Mach-O platform transform")

    require(WORKFLOW.is_file(), "missing dual-platform Gecko v5 workflow")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "workflow_dispatch:",
        "release_tag:",
        "publish_release:",
        "reuse_build_run_id:",
        "default: vulpra-engine-v5-candidate",
        "default: false",
        "runs-on: macos-26",
        "platform: [iphoneos, iphonesimulator]",
        "/Applications/Xcode_26.4.1.app",
        "fetch-source.sh",
        "apply-series.py",
        "build-runtime.sh",
        "build-snapshot.py",
        "gecko-v5-build-snapshot-${{ matrix.platform }}-${{ github.run_id }}",
        "gh run download \"$reuse_run_id\"",
        "github.event_name == 'workflow_dispatch' && github.run_id || 'push'",
        "package-runtime.py",
        "promote-engine-artifacts.py",
        "Verify cross-target identity and native distinction",
        "retention-days: 30",
        "gh release upload",
    ):
        require(token in workflow, f"Gecko v5 workflow is missing {token!r}")
    require("produce-simulator-artifact.sh" not in workflow and
            forbidden_transform not in workflow and "--clobber" not in workflow,
            "Gecko v5 workflow retains an old or destructive producer path")
    require("cancel-in-progress: false" in workflow,
            "Gecko producer may cancel an in-progress expensive compilation")
    require(workflow.index("Upload verified build snapshot") <
            workflow.index("Package content-bound runtime"),
            "Gecko build snapshot is not persisted before fallible packaging")
    require("dist=\".build/package-source/dist\"" in workflow and
            ".build/gecko-source/obj-$triple/dist" not in workflow,
            "normal packaging does not exercise the verified snapshot path")
    require(workflow.index("promote-engine-artifacts.py") <
            workflow.index("Publish verified prerelease pair"),
            "full artifact verification does not precede release publication")

    with tempfile.TemporaryDirectory(prefix="vulpra-gecko-producer-tools-") as temporary:
        base = Path(temporary)
        test_fetch(base)
        test_apply(base)
        test_build(base)
        test_package(base)
        test_build_snapshot(base)

    print("PASS: native Gecko v5 producer and packaging fixtures")


if __name__ == "__main__":
    main()
