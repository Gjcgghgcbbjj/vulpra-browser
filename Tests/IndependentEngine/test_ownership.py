#!/usr/bin/env python3
"""Verify the independent-engine ownership manifest is deterministic."""

from __future__ import annotations

import json
import posixpath
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Configuration" / "engine-ownership.json"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def paths_are_normalized(paths: list[str]) -> bool:
    return all(
        path
        and not path.startswith("/")
        and "\\" not in path
        and posixpath.normpath(path) == path
        and ".." not in Path(path).parts
        for path in paths
    )


def main() -> None:
    require(MANIFEST.is_file(), "missing Configuration/engine-ownership.json")
    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"invalid ownership JSON: {error}")

    require(data.get("schemaVersion") == 1, "ownership schema version must be 1")
    require(data.get("state") == "staged", "Phase A ownership state must be staged")
    transition = data.get("transition", {})
    require(transition.get("allowed") == ["staged", "atomic-cutover", "independent"],
            "ownership transition states are incomplete or reordered")
    cutover = transition.get("cutover", {})
    for key in ("requiresSingleActiveAdapter", "rejectAppFallback", "requiresOldOwnerRemoval"):
        require(cutover.get(key) is True, f"cutover rule {key} must be true")

    artifact = data.get("externalArtifact", {})
    require(artifact.get("kind") == "checksum-pinned-gecko-kernel",
            "external artifact kind is not the approved kernel boundary")
    require(artifact.get("root") == ".build/engine", "artifact root must be .build/engine")
    require(artifact.get("allowedClasses") == ["runtime", "licenses", "manifest"],
            "artifact classes are not the approved set")

    owned = data.get("ownedRoots", [])
    retired = data.get("retiredRoots", [])
    preserved = data.get("preservedOwners", [])
    require(owned and retired and preserved, "ownership groups must not be empty")
    all_paths = owned + retired + [artifact["root"]]
    require(len(all_paths) == len(set(all_paths)), "configured ownership paths must be unique")
    require(paths_are_normalized(all_paths), "configured paths must be normalized repository-relative paths")
    require("Engine/VulpraEngineKit" in owned, "VulpraEngineKit must be a future owner")
    require("Extensions/GeckoView" in retired, "inherited GeckoView must be retired")
    require("Modules/VulpraRuntime" in retired, "inherited JIT runtime must be retired")
    require(data.get("activeAdapter") == {
        "staged": "Extensions/GeckoView",
        "atomic-cutover": "Engine/VulpraEngineKit",
        "independent": "Engine/VulpraEngineKit",
    }, "active adapter ownership map is wrong")
    rules = data.get("rules", [])
    require(any(re.search(r"exactly one active engine adapter", rule, re.I) for rule in rules),
            "single active adapter invariant is missing")
    require(any(re.search(r"fallback", rule, re.I) for rule in rules),
            "fallback prohibition is missing")
    print("PASS: independent engine ownership contract")


if __name__ == "__main__":
    main()
