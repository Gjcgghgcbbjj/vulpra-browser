#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys


SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
ABI_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
KERNEL_TOKEN_PATTERN = re.compile(r"^_?[A-Za-z0-9][A-Za-z0-9._-]*$")
ARTIFACT_PREFIX_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*-$")


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


def validate_contract(contract: dict[str, object]) -> None:
    if contract.get("schemaVersion") != 1:
        fail("contract schemaVersion must be 1")
    if contract.get("formatVersion") != 4:
        fail("contract formatVersion must be 4")
    prefix = contract.get("artifactIdPrefix")
    if not isinstance(prefix, str) or not ARTIFACT_PREFIX_PATTERN.fullmatch(prefix):
        fail("contract artifactIdPrefix is invalid")
    if contract.get("manifestFile") != "manifest.json":
        fail("contract manifestFile must be manifest.json")
    if contract.get("platform") not in {"iphoneos", "iphonesimulator"}:
        fail("contract platform must be iphoneos or iphonesimulator")
    if contract.get("architecture") != "arm64":
        fail("contract architecture must be arm64")
    token = contract.get("requiredKernelToken")
    if not isinstance(token, str) or not KERNEL_TOKEN_PATTERN.fullmatch(token):
        fail("contract requiredKernelToken is invalid")
    resource_container = normalized_path(
        contract.get("runtimeResourceContainer"), "contract runtimeResourceContainer"
    )
    if len(PurePosixPath(resource_container).parts) != 1:
        fail("contract runtimeResourceContainer must be a single directory name")
    resource_alias = contract.get("runtimeResourceAlias")
    if resource_alias is not None:
        resource_alias = normalized_path(resource_alias, "contract runtimeResourceAlias")
        if (contract.get("platform") != "iphonesimulator"
                or len(PurePosixPath(resource_alias).parts) != 1
                or not resource_alias.endswith(".framework")
                or resource_alias == resource_container):
            fail("contract runtimeResourceAlias must be a distinct Simulator framework directory name")
    roots = contract.get("allowedRoots")
    if not isinstance(roots, list) or not roots:
        fail("contract allowedRoots must be a non-empty list")
    normalized = [normalized_path(root, "allowed root") for root in roots]
    if len(normalized) != len(set(normalized)):
        fail("contract allowedRoots contains duplicates")


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


def validate_manifest_identity(manifest: dict[str, object], contract: dict[str, object]) -> None:
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
    kernel_token = contract["requiredKernelToken"].encode("ascii")
    if (root / required_kernel).read_bytes().count(kernel_token) != 1:
        fail("required kernel does not own the independent runtime layout")
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
    validate_contract(contract)
    if not artifact_root.is_dir():
        fail(f"artifact root is not a directory: {artifact_root}")
    manifest = load_json(artifact_root / contract["manifestFile"], "artifact manifest")
    validate_manifest_identity(manifest, contract)
    paths = validate_entries(artifact_root, manifest, contract)
    validate_legal_paths(manifest, set(paths))
    return manifest["artifactId"], len(paths)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify a Vulpra Gecko engine artifact v4 root.")
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("artifact_root", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        artifact_id, count = verify(args.contract, args.artifact_root)
    except ArtifactError as error:
        print(f"engine-artifact-v4-error: {error}", file=sys.stderr)
        return 1
    print(f"engine-artifact-v4-ok {artifact_id} files={count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
