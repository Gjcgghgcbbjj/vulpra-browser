#!/usr/bin/env python3
import json
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Configuration/engine-ownership.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def require_path(value: object, label: str) -> str:
    require(isinstance(value, str) and value != "", f"{label} must be a non-empty path")
    path = PurePosixPath(value)
    require(not path.is_absolute(), f"{label} must be repository-relative: {value}")
    require(".." not in path.parts and "." not in path.parts, f"{label} is not normalized: {value}")
    require(str(path) == value and "\\" not in value, f"{label} must use normalized POSIX form: {value}")
    return value


def require_unique_paths(values: object, label: str) -> list[str]:
    require(isinstance(values, list) and values, f"{label} must be a non-empty list")
    paths = [require_path(value, f"{label} entry") for value in values]
    require(len(paths) == len(set(paths)), f"{label} contains duplicate paths")
    return paths


def main() -> None:
    require(MANIFEST.is_file(), "missing Configuration/engine-ownership.json")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    require(manifest.get("schemaVersion") == 1, "ownership schemaVersion must be 1")
    require(manifest.get("state") == "independent", "final ownership state must be independent")

    authority = manifest.get("authority")
    require(isinstance(authority, dict), "authority must be an object")
    expected_authority = {
        "engineDesign": "docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md",
        "clientDesign": "docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md",
    }
    require(authority == expected_authority, "authority must name both approved designs exactly")
    for name, relative in authority.items():
        require_path(relative, f"authority.{name}")
        spec = ROOT / relative
        require(spec.is_file(), f"authority file is missing: {relative}")
        require("Status: `approved-by-user`" in spec.read_text(encoding="utf-8"), f"authority is not approved: {relative}")

    artifact = manifest.get("externalArtifact")
    require(isinstance(artifact, dict), "externalArtifact must be an object")
    require(
        artifact.get("onlyCompatibilityCarrier") == "precompiled-gecko-kernel",
        "precompiled Gecko must be the only compatibility carrier",
    )
    require(
        artifact.get("allowedClasses")
        == [
            "kernel-binary",
            "runtime-dylib",
            "abi-header",
            "runtime-resource",
            "license",
            "notice",
            "checksum-manifest",
        ],
        "external artifact classes do not match the approved boundary",
    )

    expected_owned = {
        "Engine/VulpraEngineKit",
        "Engine/VulpraEngineProcess",
        "Engine/VulpraExecution",
        "App",
        "Extensions/OpenIn",
        "Configuration",
        "Tools/Engine",
        "Tests/IndependentEngine",
    }
    owned = set(require_unique_paths(manifest.get("ownedRoots"), "ownedRoots"))
    require(owned == expected_owned, "ownedRoots do not match the approved Vulpra owners")

    expected_retired = {
        "Extensions/GeckoView",
        "Extensions/Helper",
        "Modules/VulpraRuntime",
        "Patches",
        "Tools/Gecko",
        "Vendor/firefox",
        "Vendor/idevice",
    }
    retired = set(require_unique_paths(manifest.get("retiredRoots"), "retiredRoots"))
    require(retired == expected_retired, "retiredRoots do not match the inherited owner set")
    require(owned.isdisjoint(retired), "ownedRoots and retiredRoots must not overlap")

    expected_preserved = {
        "App/Browser/BrowserTab.swift",
        "App/Browser/TabManager.swift",
        "App/Persistence",
        "App/Library",
        "App/Settings",
        "Extensions/OpenIn",
    }
    preserved = set(require_unique_paths(manifest.get("preservedOwners"), "preservedOwners"))
    require(preserved == expected_preserved, "preservedOwners do not match approved product/data owners")
    for relative in preserved:
        require((ROOT / relative).exists(), f"preserved owner is missing: {relative}")

    historical = set(require_unique_paths(manifest.get("historicalOnly"), "historicalOnly"))
    require(
        historical
        == {
            "docs/provenance/import-manifest.tsv",
            "docs/provenance/substrate-boundary.md",
        },
        "historical provenance boundary is incomplete",
    )

    transitions = manifest.get("transitions")
    require(isinstance(transitions, list) and len(transitions) == 2, "exactly two ownership transitions are required")
    require(
        [(item.get("from"), item.get("to")) for item in transitions if isinstance(item, dict)]
        == [("staged", "atomic-cutover"), ("atomic-cutover", "independent")],
        "ownership transitions must be staged -> atomic-cutover -> independent",
    )
    for transition in transitions:
        requirements = transition.get("requirements")
        require(
            isinstance(requirements, list) and requirements and len(requirements) == len(set(requirements)),
            f"transition requirements are missing or duplicated: {transition}",
        )

    invariants = manifest.get("invariants")
    require(
        invariants
        == {
            "activeEngineAdapters": 1,
            "runtimeFallbackAllowed": False,
            "simultaneousOldAndNewAppAdaptersAllowed": False,
            "persistentDataDeletionAllowed": False,
        },
        "single-owner, no-fallback, or data-preservation invariant is missing",
    )

    print("PASS: independent engine ownership contract")


if __name__ == "__main__":
    main()
