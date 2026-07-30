#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import sys


SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
ABI_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
KERNEL_TOKEN_PATTERN = re.compile(r"^_?[A-Za-z0-9][A-Za-z0-9._-]*$")
ARTIFACT_PREFIX_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*-$")
BUNDLE_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$")


class ArtifactError(ValueError):
    pass


def fail(message: str) -> None:
    raise ArtifactError(message)


def load_json(path: Path, label: str) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"missing {label}: {path}")
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid {label}: {path}: {error}")
    if not isinstance(value, dict):
        fail(f"{label} must be a JSON object")
    return value


def normalized_path(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        fail(f"{label} must be a normalized repository-relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        fail(f"{label} must be a normalized repository-relative path: {value}")
    if str(path) != value or "\\" in value:
        fail(f"{label} must be a normalized repository-relative path: {value}")
    return value


def is_under(path: str, root: str) -> bool:
    candidate = PurePosixPath(path)
    parent = PurePosixPath(root)
    return candidate == parent or parent in candidate.parents


def validate_contract(contract: dict[str, object], repository_root: Path) -> None:
    if contract.get("schemaVersion") != 1:
        fail("contract schemaVersion must be 1")
    format_version = contract.get("formatVersion")
    if format_version not in {4, 5}:
        fail("contract formatVersion must be 4 or 5")
    prefix = contract.get("artifactIdPrefix")
    if not isinstance(prefix, str) or not ARTIFACT_PREFIX_PATTERN.fullmatch(prefix):
        fail("contract artifactIdPrefix is invalid")
    if contract.get("manifestFile") != "manifest.json":
        fail("contract manifestFile must be manifest.json")
    if contract.get("platform") not in {"iphoneos", "iphonesimulator"}:
        fail("contract platform must be iphoneos or iphonesimulator")
    if contract.get("architecture") != "arm64":
        fail("contract architecture must be arm64")
    if format_version == 4:
        token = contract.get("requiredKernelToken")
        if not isinstance(token, str) or not KERNEL_TOKEN_PATTERN.fullmatch(token):
            fail("contract requiredKernelToken is invalid")
    resource_container = normalized_path(
        contract.get("runtimeResourceContainer"), "contract runtimeResourceContainer"
    )
    if len(PurePosixPath(resource_container).parts) != 1:
        fail("contract runtimeResourceContainer must be a single directory name")
    kernel_install_path = normalized_path(
        contract.get("runtimeKernelInstallPath"), "contract runtimeKernelInstallPath"
    )
    bundle_identifier = contract.get("runtimeKernelBundleIdentifier")
    kernel_parent = PurePosixPath(kernel_install_path).parent
    if kernel_install_path == "XUL":
        if contract.get("platform") != "iphoneos" or bundle_identifier is not None:
            fail("device runtime kernel contract is invalid")
    elif (contract.get("platform") != "iphonesimulator"
          or kernel_parent.suffix != ".framework"
          or PurePosixPath(kernel_install_path).name != "XUL"
          or not isinstance(bundle_identifier, str)
          or not BUNDLE_IDENTIFIER_PATTERN.fullmatch(bundle_identifier)):
        fail("Simulator framework carrier contract is invalid")
    roots = contract.get("allowedRoots")
    if not isinstance(roots, list) or not roots:
        fail("contract allowedRoots must be a non-empty list")
    normalized = [normalized_path(root, "allowed root") for root in roots]
    if len(normalized) != len(set(normalized)):
        fail("contract allowedRoots contains duplicates")
    if format_version == 5:
        validate_v5_contract(contract, repository_root)


def validate_v5_contract(contract: dict[str, object], repository_root: Path) -> None:
    expected_keys = {
        "schemaVersion", "formatVersion", "artifactIdPrefix", "manifestFile",
        "platform", "targetTriple", "architecture", "deploymentTarget",
        "producerContract", "patchSeries", "requiredKernel", "requiredExports",
        "requiredHeaders", "forbiddenRuntimeTokens", "runtimeResourceContainer",
        "runtimeKernelInstallPath", "allowedRoots", "nonEmptyRoots",
        "forbiddenSourceExtensions", "forbiddenProductExtensions", "forbiddenSegments",
    }
    if contract.get("platform") == "iphonesimulator":
        expected_keys.add("runtimeKernelBundleIdentifier")
    if set(contract) != expected_keys:
        fail(f"v5 contract keys must be exactly: {', '.join(sorted(expected_keys))}")

    producer_path = normalized_path(contract.get("producerContract"), "producer contract")
    series_path = normalized_path(contract.get("patchSeries"), "patch series")
    producer = load_json(repository_root / producer_path, "Gecko producer contract")
    platform = contract["platform"]
    if contract.get("targetTriple") != producer.get("targets", {}).get(platform):
        fail("v5 contract target triple does not match the producer contract")
    if contract.get("deploymentTarget") != producer.get("deploymentTarget"):
        fail("v5 contract deployment target does not match the producer contract")
    if series_path != producer.get("patchSeries") or not (repository_root / series_path).is_file():
        fail("v5 contract patch series does not match the producer contract")

    exports = contract.get("requiredExports")
    producer_exports = producer.get("requiredExports")
    if (not isinstance(exports, list) or not exports or len(exports) != len(set(exports))
            or exports != producer_exports):
        fail("v5 contract required exports do not match the producer contract")
    headers = contract.get("requiredHeaders")
    if not isinstance(headers, dict) or not headers:
        fail("v5 contract requiredHeaders must be a non-empty object")
    for path, tokens in headers.items():
        normalized_path(path, "required header")
        if (not isinstance(tokens, list) or not tokens
                or not all(isinstance(token, str) and token for token in tokens)):
            fail(f"v5 required header tokens are invalid: {path}")
    forbidden = contract.get("forbiddenRuntimeTokens")
    if (not isinstance(forbidden, list) or not forbidden or len(forbidden) != len(set(forbidden))
            or forbidden != producer.get("forbiddenRuntimeTokens")):
        fail("v5 forbidden runtime tokens do not match the producer contract")


def validate_forbidden_path(path: str, contract: dict[str, object]) -> None:
    parts = PurePosixPath(path).parts
    lower_parts = tuple(part.casefold() for part in parts)
    for extension in contract["forbiddenProductExtensions"]:
        for part in parts:
            if part.casefold().endswith(extension.casefold()):
                labels = {
                    ".framework": "framework",
                    ".appex": "app extension",
                    ".app": "application product",
                }
                fail(f"forbidden {labels[extension]} in artifact: {path}")
    for segment in contract["forbiddenSegments"]:
        if segment.casefold() in lower_parts:
            label = "JIT" if segment == "JIT" else segment.rstrip("s").lower()
            fail(f"forbidden {label} path in artifact: {path}")
    suffix = PurePosixPath(path).suffix.casefold()
    if suffix in {item.casefold() for item in contract["forbiddenSourceExtensions"]}:
        fail(f"forbidden source file in artifact: {path}")


def global_exported_symbols(kernel: Path) -> set[str]:
    command = shlex.split(os.environ.get("VULPRA_NM", "nm"))
    if not command:
        fail("VULPRA_NM is empty")
    try:
        result = subprocess.run(
            [*command, "-gU", str(kernel)],
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError as error:
        fail(f"cannot execute global symbol inspector: {error}")
    if result.returncode != 0:
        fail(f"global symbol inspection failed: {result.stderr.strip()}")
    return {
        fields[-1]
        for line in result.stdout.splitlines()
        if (fields := line.split())
    }


def validate_manifest_identity(
    manifest: dict[str, object], contract: dict[str, object], repository_root: Path
) -> None:
    if contract["formatVersion"] == 5:
        validate_v5_manifest_identity(manifest, contract, repository_root)
        return
    expected_keys = {
        "formatVersion",
        "artifactId",
        "abiVersion",
        "source",
        "build",
        "licenses",
        "notices",
        "files",
    }
    if set(manifest) != expected_keys:
        fail(f"manifest keys must be exactly: {', '.join(sorted(expected_keys))}")
    if manifest.get("formatVersion") != contract["formatVersion"]:
        fail("manifest formatVersion does not match contract")
    artifact_id = manifest.get("artifactId")
    prefix = contract["artifactIdPrefix"]
    if (not isinstance(artifact_id, str) or not artifact_id.startswith(prefix)
            or not SHA256_PATTERN.fullmatch(artifact_id[len(prefix):])):
        fail("manifest artifactId is invalid")
    identity = dict(manifest)
    identity["artifactId"] = ""
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    expected_artifact_id = f"{prefix}{hashlib.sha256(canonical).hexdigest()}"
    if manifest["artifactId"] != expected_artifact_id:
        fail("manifest artifactId does not match its content identity")
    if not isinstance(manifest.get("abiVersion"), str) or not ABI_PATTERN.fullmatch(manifest["abiVersion"]):
        fail("manifest abiVersion is invalid")

    source = manifest.get("source")
    if not isinstance(source, dict):
        fail("manifest source must be an object")
    if source.get("repository") != contract["sourceRepository"]:
        fail("manifest source repository is invalid")
    if not isinstance(source.get("commit"), str) or not COMMIT_PATTERN.fullmatch(source["commit"]):
        fail("manifest source commit is invalid")

    build = manifest.get("build")
    if not isinstance(build, dict):
        fail("manifest build must be an object")
    if set(build) != {"xcodeBuild", "sdkBuild", "platform", "architecture"}:
        fail("manifest build keys are invalid")
    if build.get("platform") != contract["platform"]:
        fail("manifest build platform does not match contract")
    if build.get("architecture") != contract["architecture"]:
        fail("manifest build architecture does not match contract")
    for key in ("xcodeBuild", "sdkBuild"):
        if not isinstance(build.get(key), str) or not build[key].strip():
            fail(f"manifest build {key} is empty")


def validate_v5_manifest_identity(
    manifest: dict[str, object], contract: dict[str, object], repository_root: Path
) -> None:
    expected_keys = {
        "formatVersion", "artifactId", "abiVersion", "source", "patchSet",
        "producer", "compiledBy", "configurationSHA256", "build",
        "licenses", "notices", "files",
    }
    if set(manifest) != expected_keys:
        fail(f"v5 manifest keys must be exactly: {', '.join(sorted(expected_keys))}")
    if manifest.get("formatVersion") != 5:
        fail("manifest formatVersion does not match v5 contract")
    artifact_id = manifest.get("artifactId")
    prefix = contract["artifactIdPrefix"]
    if (not isinstance(artifact_id, str) or not artifact_id.startswith(prefix)
            or not SHA256_PATTERN.fullmatch(artifact_id[len(prefix):])):
        fail("manifest artifactId is invalid")
    identity = dict(manifest)
    identity["artifactId"] = ""
    canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    if artifact_id != f"{prefix}{hashlib.sha256(canonical).hexdigest()}":
        fail("manifest artifactId does not match its content identity")
    if manifest.get("abiVersion") != "gecko-ios-v5-abi-1":
        fail("manifest v5 ABI version is invalid")

    producer_contract_path = repository_root / contract["producerContract"]
    producer_contract = load_json(producer_contract_path, "Gecko producer contract")
    if manifest.get("source") != producer_contract.get("upstream"):
        fail("manifest source provenance does not match the producer contract")
    series_path = repository_root / contract["patchSeries"]
    expected_patch_set = {
        "series": contract["patchSeries"],
        "sha256": hashlib.sha256(series_path.read_bytes()).hexdigest(),
    }
    if manifest.get("patchSet") != expected_patch_set:
        fail("manifest patch provenance does not match the audited series")
    if manifest.get("configurationSHA256") != hashlib.sha256(producer_contract_path.read_bytes()).hexdigest():
        fail("manifest producer configuration digest is invalid")

    producer = manifest.get("producer")
    if not isinstance(producer, dict) or set(producer) != {"repository", "commit", "workflowRunId"}:
        fail("manifest producer identity is invalid")
    if producer.get("repository") != "https://github.com/Gjcgghgcbbjj/vulpra-browser":
        fail("manifest producer repository is invalid")
    if not isinstance(producer.get("commit"), str) or not COMMIT_PATTERN.fullmatch(producer["commit"]):
        fail("manifest producer commit is invalid")
    if type(producer.get("workflowRunId")) is not int or producer["workflowRunId"] < 0:
        fail("manifest producer workflow run ID is invalid")
    compiled_by = manifest.get("compiledBy")
    if (not isinstance(compiled_by, dict)
            or set(compiled_by) != {"repository", "commit", "workflowRunId", "buildFingerprint"}
            or compiled_by.get("repository") != producer.get("repository")
            or not isinstance(compiled_by.get("commit"), str)
            or COMMIT_PATTERN.fullmatch(compiled_by["commit"]) is None
            or type(compiled_by.get("workflowRunId")) is not int
            or compiled_by["workflowRunId"] < 0
            or not isinstance(compiled_by.get("buildFingerprint"), str)
            or SHA256_PATTERN.fullmatch(compiled_by["buildFingerprint"]) is None):
        fail("manifest native compilation provenance is invalid")

    build = manifest.get("build")
    expected_build_keys = {
        "mozconfigSHA256", "xcodeBuild", "sdkBuild", "platform", "targetTriple",
        "architecture", "deploymentTarget",
    }
    if not isinstance(build, dict) or set(build) != expected_build_keys:
        fail("manifest v5 build identity is invalid")
    for key in ("mozconfigSHA256",):
        if not isinstance(build.get(key), str) or not SHA256_PATTERN.fullmatch(build[key]):
            fail(f"manifest build {key} is invalid")
    for key in ("xcodeBuild", "sdkBuild"):
        if not isinstance(build.get(key), str) or not build[key].strip():
            fail(f"manifest build {key} is empty")
    for key in ("platform", "targetTriple", "architecture", "deploymentTarget"):
        if build.get(key) != contract.get(key):
            fail(f"manifest build {key} does not match contract")


def validate_entries(root: Path, manifest: dict[str, object], contract: dict[str, object]) -> list[str]:
    entries = manifest.get("files")
    if not isinstance(entries, list) or not entries:
        fail("manifest files must be a non-empty list")

    allowed_roots = contract["allowedRoots"]
    paths: list[str] = []
    entry_by_path: dict[str, dict[str, object]] = {}
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict) or set(entry) != {"path", "size", "sha256"}:
            fail(f"manifest file entry {index} is invalid")
        relative = normalized_path(entry.get("path"), f"manifest file entry {index}")
        if relative in entry_by_path:
            fail(f"duplicate manifest path: {relative}")
        if not any(is_under(relative, allowed) for allowed in allowed_roots):
            fail(f"manifest path is outside allowed roots: {relative}")
        validate_forbidden_path(relative, contract)
        size = entry.get("size")
        digest = entry.get("sha256")
        if type(size) is not int or size < 0:
            fail(f"invalid size for {relative}")
        if not isinstance(digest, str) or not SHA256_PATTERN.fullmatch(digest):
            fail(f"invalid sha256 for {relative}")
        paths.append(relative)
        entry_by_path[relative] = entry

    if paths != sorted(paths):
        fail("manifest files must be sorted by path")

    manifest_name = contract["manifestFile"]
    actual_paths: list[str] = []
    for path in root.rglob("*"):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            fail(f"symbolic link is forbidden in artifact: {relative}")
        if path.is_file() and relative != manifest_name:
            executable_allowed = relative == contract["requiredKernel"] or (
                is_under(relative, "runtime/lib") and path.suffix.casefold() == ".dylib"
            )
            if path.stat().st_mode & 0o111 and not executable_allowed:
                fail(f"unexpected executable in artifact: {relative}")
            actual_paths.append(relative)
    actual_paths.sort()

    declared = set(paths)
    actual = set(actual_paths)
    missing = sorted(declared - actual)
    if missing:
        fail(f"missing declared file: {missing[0]}")
    undeclared = sorted(actual - declared)
    if undeclared:
        fail(f"undeclared payload file: {undeclared[0]}")

    for relative in paths:
        path = root / relative
        content = path.read_bytes()
        entry = entry_by_path[relative]
        if len(content) != entry["size"]:
            fail(f"size mismatch for {relative}")
        if hashlib.sha256(content).hexdigest() != entry["sha256"]:
            fail(f"checksum mismatch for {relative}")

    required_kernel = contract["requiredKernel"]
    if required_kernel not in declared:
        fail(f"missing required kernel: {required_kernel}")
    kernel_content = (root / required_kernel).read_bytes()
    if contract["formatVersion"] == 4:
        kernel_token = contract["requiredKernelToken"].encode("ascii")
        if kernel_content.count(kernel_token) != 1:
            fail("required kernel does not own the independent runtime layout")
    else:
        exported = global_exported_symbols(root / required_kernel)
        for export in contract["requiredExports"]:
            if export not in exported:
                fail(f"required v5 exported symbol is missing: {export}")
        for relative, tokens in contract["requiredHeaders"].items():
            if relative not in declared:
                fail(f"required v5 ABI header is missing: {relative}")
            header = (root / relative).read_bytes()
            for token in tokens:
                if token.encode("ascii") not in header:
                    fail(f"required v5 lifecycle header token is missing: {token}")
        for token in contract["forbiddenRuntimeTokens"]:
            encoded = token.encode("ascii")
            if any(encoded in (root / relative).read_bytes() for relative in paths):
                fail(f"forbidden v5 runtime token is present: {token}")
    resource_token = contract["runtimeResourceContainer"].encode("ascii")
    if kernel_content.count(resource_token) != 1:
        fail("required kernel does not own the declared runtime resource layout")
    if not any(path.endswith(".dylib") and is_under(path, "runtime") for path in paths):
        fail("artifact must contain at least one runtime dylib")
    for required_root in contract["nonEmptyRoots"]:
        if not any(is_under(path, required_root) for path in paths):
            fail(f"artifact root must not be empty: {required_root}")
    return paths


def validate_legal_paths(manifest: dict[str, object], declared: set[str]) -> None:
    for key, label in (("licenses", "license path"), ("notices", "notice path")):
        values = manifest.get(key)
        if not isinstance(values, list) or not values:
            fail(f"manifest {key} must be a non-empty list")
        normalized = [normalized_path(value, label) for value in values]
        if len(normalized) != len(set(normalized)):
            fail(f"manifest {key} contains duplicates")
        for relative in normalized:
            if not is_under(relative, "licenses") or relative not in declared:
                fail(f"{label} is not a declared payload file: {relative}")


def verify(contract_path: Path, artifact_root: Path) -> tuple[str, int]:
    contract = load_json(contract_path, "artifact contract")
    repository_root = contract_path.resolve().parent.parent
    validate_contract(contract, repository_root)
    if not artifact_root.is_dir():
        fail(f"artifact root is not a directory: {artifact_root}")
    manifest = load_json(artifact_root / contract["manifestFile"], "artifact manifest")
    validate_manifest_identity(manifest, contract, repository_root)
    paths = validate_entries(artifact_root, manifest, contract)
    validate_legal_paths(manifest, set(paths))
    return manifest["artifactId"], len(paths)


def normalized_repeat_manifest(manifest: dict[str, object]) -> dict[str, object]:
    normalized = json.loads(json.dumps(manifest))
    normalized["artifactId"] = ""
    normalized["producer"]["workflowRunId"] = 0
    normalized["compiledBy"]["workflowRunId"] = 0
    return normalized


def compare_repeat_builds(contract_path: Path, first: Path, second: Path) -> None:
    verify(contract_path, first)
    verify(contract_path, second)
    first_manifest = load_json(first / "manifest.json", "first artifact manifest")
    second_manifest = load_json(second / "manifest.json", "second artifact manifest")
    if normalized_repeat_manifest(first_manifest) != normalized_repeat_manifest(second_manifest):
        fail("repeat v5 build content or provenance differs")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify a Vulpra Gecko engine artifact root.")
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--compare", type=Path)
    parser.add_argument("artifact_root", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    contract = load_json(args.contract, "artifact contract")
    version = contract.get("formatVersion", "unknown")
    try:
        artifact_id, count = verify(args.contract, args.artifact_root)
        if args.compare is not None:
            compare_repeat_builds(args.contract, args.artifact_root, args.compare)
    except ArtifactError as error:
        print(f"engine-artifact-v{version}-error: {error}", file=sys.stderr)
        return 1
    suffix = " repeat-match" if args.compare is not None else ""
    print(f"engine-artifact-v{version}-ok {artifact_id} files={count}{suffix}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
