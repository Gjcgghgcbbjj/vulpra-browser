#!/usr/bin/env python3
"""Verify the repository-owned Gecko v5 producer contract."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "Tools/GeckoProducer/verify-producer.py"
CONTRACT = ROOT / "Configuration/gecko-producer-v5.json"
SERIES = ROOT / "Engine/GeckoPatches/v5/series.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def valid_contract() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "artifactFormatVersion": 5,
        "upstream": {
            "repository": "https://github.com/mozilla-firefox/firefox",
            "commit": "27b462b22705a8860f7ab0d33aa5b4b658ae5932",
        },
        "patchSeries": "Engine/GeckoPatches/v5/series.json",
        "deploymentTarget": "15.0",
        "targets": {
            "iphoneos": "aarch64-apple-ios",
            "iphonesimulator": "aarch64-apple-ios-sim",
        },
        "requiredExports": [
            "_MainProcessInit", "_GeckoViewOpenWindow", "_ChildProcessInit",
            "_GeckoChildProcessDidChange",
        ],
        "forbiddenRuntimeTokens": [
            "jit-ready-fd",
            "ReportJITStatusForChild",
            "WaitForJITReadySignal",
        ],
    }


def run_contract(path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VERIFIER), "--contract-only", str(path)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def run_full(path: Path, root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VERIFIER), "--contract", str(path), "--root", str(root)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def write_fixture(directory: Path, name: str, payload: dict[str, object]) -> Path:
    path = directory / name
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return path


def write_full_fixture(root: Path) -> Path:
    contract_path = root / "Configuration/gecko-producer-v5.json"
    contract_path.parent.mkdir(parents=True)
    contract_path.write_text(json.dumps(valid_contract(), indent=2) + "\n", encoding="utf-8")
    patch = root / "Engine/GeckoPatches/v5/platform/example.patch"
    patch.parent.mkdir(parents=True)
    patch.write_text(
        "diff --git a/example/source.cpp b/example/source.cpp\n"
        "index 111111111111..222222222222 100644\n"
        "--- a/example/source.cpp\n"
        "+++ b/example/source.cpp\n"
        "@@ -1 +1 @@\n"
        "-old value\n"
        "+new iOS value\n",
        encoding="utf-8",
    )
    series = {
        "schemaVersion": 1,
        "patches": [{
            "order": 1,
            "path": "platform/example.patch",
            "sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
            "owner": "engine-platform",
            "purpose": "Adapt example/source.cpp for the standalone iOS runtime.",
            "upstreamPaths": ["example/source.cpp"],
        }],
    }
    series_path = root / "Engine/GeckoPatches/v5/series.json"
    series_path.write_text(json.dumps(series, indent=2) + "\n", encoding="utf-8")
    return contract_path


def checked_in_patch(upstream_path: str) -> str:
    series = json.loads(SERIES.read_text(encoding="utf-8"))
    matching = [entry for entry in series["patches"]
                if entry["upstreamPaths"] == [upstream_path]]
    require(len(matching) == 1, f"missing unique patch for {upstream_path}")
    return (SERIES.parent / matching[0]["path"]).read_text(encoding="utf-8")


def verify_lifecycle_source_contract() -> None:
    host_header = checked_in_patch("ipc/glue/GeckoChildProcessHost.h")
    host = checked_in_patch("ipc/glue/GeckoChildProcessHost.cpp")
    bootstrap_header = checked_in_patch("toolkit/xre/IOSBootstrap.h")
    bootstrap = checked_in_patch("toolkit/xre/IOSBootstrap.mm")
    swift = checked_in_patch("widget/uikit/GeckoViewSwiftSupport.h")
    combined = "\n".join((host_header, host, bootstrap_header, bootstrap, swift))

    for token in (
        "GeckoChildProcessRequested = 1",
        "GeckoChildProcessExtensionConnected = 2",
        "GeckoChildProcessBootstrapAcknowledged = 3",
        "GeckoChildProcessIPCConnected = 4",
        "GeckoChildProcessFailed = 5",
        "GeckoChildProcessTerminated = 6",
        "GeckoChildProcessLifecycleObserver",
        "childProcessDidChangeWithLaunchID",
        "monotonicTimestampNanoseconds",
        "GeckoChildProcessDidChange",
        "CLOCK_MONOTONIC",
        "JS::DisableJitBackend()",
        "mLaunchID = ++gLaunchCounter",
        "mLifecycleStages",
        "mLifecycleOutcome",
    ):
        require(token in combined, f"typed Gecko lifecycle is missing {token!r}")

    owner_pairs = (
        ("GeckoChildProcessHost::AsyncLaunch", "kChildRequested"),
        ("NSExtensionProcess::StartProcess", "kChildExtensionConnected"),
        ("NSExtensionProcess::BootstrapReplyPID", "kChildBootstrapAcknowledged"),
        ("GeckoChildProcessHost::OnProcessLaunchError", "kChildFailed"),
        ("GeckoChildProcessHost::OnChannelConnected", "kChildIPCConnected"),
        ("GeckoChildProcessHost::~GeckoChildProcessHost", "kChildTerminated"),
    )
    for owner, stage in owner_pairs:
        require(owner in host and stage in host and host.index(owner) < host.rindex(stage),
                f"{stage} is not emitted by {owner}")
    for forbidden in (
        "jit-ready-fd", "ReportJITStatusForChild", "WaitForJITReadySignal",
        "RuntimeJITCoordinator", "childProcessDidStartWithPID", "ptrace", "task_for_pid",
    ):
        require(forbidden not in combined, f"retired lifecycle token remains: {forbidden}")

    toolchain = checked_in_patch("build/moz.configure/toolchain.configure")
    for token in (
        'linker in (None, "ld64")',
        'target.kernel == "Darwin"',
        '"--version" in stderr',
    ):
        require(token in toolchain, f"Xcode 26 ld64 compatibility patch is missing {token!r}")

    uikit_build = checked_in_patch("widget/uikit/moz.build")
    require("GeckoViewRuntimeSupport.h" not in uikit_build,
            "retired JIT runtime-support header remains in the iOS export graph")


def main() -> None:
    require(VERIFIER.is_file(), "missing Tools/GeckoProducer/verify-producer.py")
    require(CONTRACT.is_file(), "missing Configuration/gecko-producer-v5.json")

    with tempfile.TemporaryDirectory(prefix="vulpra-gecko-producer-v5-") as temporary:
        fixtures = Path(temporary)
        valid = valid_contract()
        result = run_contract(write_fixture(fixtures, "valid.json", valid))
        require(result.returncode == 0, result.stderr or result.stdout)
        require(result.stdout.strip() == "PASS: Gecko producer v5 contract",
                "valid contract output is not deterministic")

        invalid: list[tuple[str, dict[str, object], str]] = []

        unknown = copy.deepcopy(valid)
        unknown["fallbackArtifact"] = "v4"
        invalid.append(("unknown-field", unknown, "unknown fields"))

        missing = copy.deepcopy(valid)
        del missing["upstream"]["commit"]  # type: ignore[index]
        invalid.append(("missing-commit", missing, "missing fields"))

        malformed_commit = copy.deepcopy(valid)
        malformed_commit["upstream"]["commit"] = "not-a-commit"  # type: ignore[index]
        invalid.append(("malformed-commit", malformed_commit, "40 lowercase hex"))

        duplicate_target = copy.deepcopy(valid)
        duplicate_target["targets"]["iphonesimulator"] = "aarch64-apple-ios"  # type: ignore[index]
        invalid.append(("duplicate-target", duplicate_target, "target triples must be unique"))

        non_ios = copy.deepcopy(valid)
        non_ios["targets"]["iphonesimulator"] = "aarch64-apple-darwin"  # type: ignore[index]
        invalid.append(("non-ios-target", non_ios, "unexpected target triple"))

        duplicate_export = copy.deepcopy(valid)
        duplicate_export["requiredExports"].append("_MainProcessInit")  # type: ignore[union-attr]
        invalid.append(("duplicate-export", duplicate_export, "requiredExports contains duplicates"))

        missing_forbidden = copy.deepcopy(valid)
        missing_forbidden["forbiddenRuntimeTokens"].remove("jit-ready-fd")  # type: ignore[union-attr]
        invalid.append(("missing-forbidden", missing_forbidden, "missing required values"))

        for name, payload, expected in invalid:
            result = run_contract(write_fixture(fixtures, f"{name}.json", payload))
            require(result.returncode != 0, f"invalid fixture passed: {name}")
            require(expected in result.stderr, f"{name} did not report {expected!r}: {result.stderr}")

        duplicate_key = fixtures / "duplicate-key.json"
        duplicate_key.write_text(
            json.dumps(valid).replace('"schemaVersion": 1',
                                      '"schemaVersion": 1, "schemaVersion": 1', 1),
            encoding="utf-8",
        )
        result = run_contract(duplicate_key)
        require(result.returncode != 0 and "duplicate JSON key" in result.stderr,
                "duplicate JSON keys were not rejected")

        full_root = fixtures / "full"
        full_contract = write_full_fixture(full_root)
        result = run_full(full_contract, full_root)
        require(result.returncode == 0, result.stderr or result.stdout)
        require(result.stdout.strip() == "PASS: Gecko producer v5 patch series",
                "full series output is not deterministic")

        series_path = full_root / "Engine/GeckoPatches/v5/series.json"
        original_series = json.loads(series_path.read_text(encoding="utf-8"))
        invalid_series: list[tuple[str, dict[str, object], str]] = []

        missing_patch = copy.deepcopy(original_series)
        missing_patch["patches"][0]["path"] = "platform/missing.patch"  # type: ignore[index]
        invalid_series.append(("missing-patch", missing_patch, "missing patch file"))

        wrong_order = copy.deepcopy(original_series)
        wrong_order["patches"][0]["order"] = 2  # type: ignore[index]
        invalid_series.append(("wrong-order", wrong_order, "orders must be contiguous"))

        wrong_hash = copy.deepcopy(original_series)
        wrong_hash["patches"][0]["sha256"] = "0" * 64  # type: ignore[index]
        invalid_series.append(("wrong-hash", wrong_hash, "patch digest mismatch"))

        duplicate_path = copy.deepcopy(original_series)
        duplicate_path["patches"].append(copy.deepcopy(duplicate_path["patches"][0]))  # type: ignore[index,union-attr]
        duplicate_path["patches"][1]["order"] = 2  # type: ignore[index]
        invalid_series.append(("duplicate-path", duplicate_path, "duplicate patch path"))

        vague_purpose = copy.deepcopy(original_series)
        vague_purpose["patches"][0]["purpose"] = "iOS patch"  # type: ignore[index]
        invalid_series.append(("vague-purpose", vague_purpose, "specific purpose"))

        wrong_upstream = copy.deepcopy(original_series)
        wrong_upstream["patches"][0]["upstreamPaths"] = ["wrong.cpp"]  # type: ignore[index]
        invalid_series.append(("wrong-upstream", wrong_upstream, "upstreamPaths mismatch"))

        for name, payload, expected in invalid_series:
            series_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
            result = run_full(full_contract, full_root)
            require(result.returncode != 0, f"invalid full-series fixture passed: {name}")
            require(expected in result.stderr,
                    f"{name} did not report {expected!r}: {result.stderr}")

        series_path.write_text(json.dumps(original_series, indent=2) + "\n", encoding="utf-8")
        patch_path = full_root / "Engine/GeckoPatches/v5/platform/example.patch"
        clean_patch = patch_path.read_text(encoding="utf-8")
        patch_path.write_text(clean_patch + "+jit-ready-fd\n", encoding="utf-8")
        original_series["patches"][0]["sha256"] = hashlib.sha256(patch_path.read_bytes()).hexdigest()
        series_path.write_text(json.dumps(original_series, indent=2) + "\n", encoding="utf-8")
        result = run_full(full_contract, full_root)
        require(result.returncode != 0 and "forbidden runtime token" in result.stderr,
                "forbidden patch content was not rejected")

    result = run_contract(CONTRACT)
    require(result.returncode == 0, result.stderr or result.stdout)
    verify_lifecycle_source_contract()
    print("PASS: Gecko producer v5 contract fixtures")


if __name__ == "__main__":
    main()
