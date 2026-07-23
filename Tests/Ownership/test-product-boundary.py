#!/usr/bin/env python3
"""Enforce Vulpra product ownership separately from derived substrate code."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]

PRODUCT_ROOTS = (
    Path("App"),
    Path("Configuration"),
    Path("Extensions/OpenIn"),
    Path("Vulpra.xcodeproj"),
    Path("Tools/Release"),
    Path("Tools/Runtime"),
)

REQUIRED_PRODUCT_FILES = {
    Path("App/main.swift"),
    Path("App/SceneDelegate.swift"),
    Path("App/Browser/BrowserViewController.swift"),
    Path("App/Browser/TabManager.swift"),
    Path("App/UI/BrowserChromeView.swift"),
    Path("App/Persistence/AtomicJSONStore.swift"),
    Path("Configuration/Base.xcconfig"),
    Path("Extensions/OpenIn/OpenInViewController.swift"),
    Path("Vulpra.xcodeproj/project.pbxproj"),
    Path("Tools/Release/create-ipa.sh"),
    Path("Tools/Runtime/verify-runtime-artifacts.sh"),
}

PRODUCT_WORKFLOWS = {
    Path(".github/workflows/build-ios-packages.yml"),
    Path(".github/workflows/build-runtime-substrate.yml"),
    Path(".github/workflows/build-simulator-runtime.yml"),
    Path(".github/workflows/simulator-launch.yml"),
}

DERIVED_ROOTS = (
    "Extensions/GeckoView/",
    "Extensions/Helper/",
    "Modules/VulpraRuntime/",
    "Patches/",
    "Tools/Build/",
    "Tools/Gecko/",
    "Vendor/",
)

TEXT_SUFFIXES = {
    ".c",
    ".h",
    ".m",
    ".mm",
    ".plist",
    ".sh",
    ".swift",
    ".xcconfig",
    ".yml",
    ".yaml",
}

FORBIDDEN_ACTIVE_PATTERNS = {
    "old product name": re.compile(r"\bReynard\b|\breynard\b"),
    "old bundle owner": re.compile(r"com\.minh-ton|me\.minh-ton"),
    "old client root": re.compile(r"browser/Reynard|(?:^|/)Client/"),
    "old architecture owner": re.compile(r"\bBrowserCore\b|\bStabilityCore\b"),
}

GENERATED_SUFFIXES = {
    ".a",
    ".dylib",
    ".framework",
    ".ipa",
    ".pyc",
    ".tipa",
    ".xcarchive",
}


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def is_under(path: Path, roots: tuple[Path, ...]) -> bool:
    return any(path == root or root in path.parents for root in roots)


missing_roots = [str(path) for path in PRODUCT_ROOTS if not (ROOT / path).exists()]
if missing_roots:
    fail("missing Vulpra product roots: " + ", ".join(missing_roots))

missing_files = sorted(str(path) for path in REQUIRED_PRODUCT_FILES if not (ROOT / path).is_file())
if missing_files:
    fail("missing Vulpra product files: " + ", ".join(missing_files))

missing_workflows = sorted(str(path) for path in PRODUCT_WORKFLOWS if not (ROOT / path).is_file())
if missing_workflows:
    fail("missing Vulpra product workflows: " + ", ".join(missing_workflows))

xcode_projects = sorted(path.relative_to(ROOT) for path in ROOT.glob("*.xcodeproj"))
if xcode_projects != [Path("Vulpra.xcodeproj")]:
    fail(f"expected only Vulpra.xcodeproj, found: {xcode_projects}")

scan_roots = PRODUCT_ROOTS + tuple(PRODUCT_WORKFLOWS)
for scan_root in scan_roots:
    absolute = ROOT / scan_root
    candidates = [absolute] if absolute.is_file() else absolute.rglob("*")
    for path in candidates:
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if path.suffix in GENERATED_SUFFIXES or any(part in {"__pycache__", "DerivedData", "dist"} for part in relative.parts):
            fail(f"generated output leaked into product source: {relative}")
        if path.suffix not in TEXT_SUFFIXES and path.name != "project.pbxproj":
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        for label, expression in FORBIDDEN_ACTIVE_PATTERNS.items():
            if expression.search(content):
                fail(f"{label} found in Vulpra product file: {relative}")

manifest_path = ROOT / "docs/provenance/import-manifest.tsv"
with manifest_path.open(newline="", encoding="utf-8") as source:
    import_rows = list(csv.DictReader(source, delimiter="\t"))
for row in import_rows:
    target = Path(row["target_path"])
    if is_under(target, PRODUCT_ROOTS):
        fail(f"Vulpra product file is incorrectly classified as imported substrate: {target}")

delta_path = ROOT / "docs/provenance/substrate-deltas.tsv"
if not delta_path.is_file():
    fail("missing substrate delta manifest")
with delta_path.open(newline="", encoding="utf-8") as source:
    delta_rows = list(csv.DictReader(source, delimiter="\t"))
delta_targets: set[str] = set()
for row in delta_rows:
    target = row["target_path"]
    if not target.startswith(DERIVED_ROOTS):
        fail(f"substrate delta targets a product or unknown root: {target}")
    if target in delta_targets:
        fail(f"duplicate substrate delta target: {target}")
    delta_targets.add(target)
    target_path = ROOT / target
    if not target_path.is_file():
        fail(f"substrate delta target is missing: {target}")
    current_hash = hashlib.sha256(target_path.read_bytes()).hexdigest()
    if row["current_sha256"] != current_hash:
        fail(f"stale current hash in substrate delta: {target}")
    try:
        baseline_bytes = subprocess.check_output(
            ["git", "-C", str(ROOT), "show", f'{row["baseline_commit"]}:{target}']
        )
    except subprocess.CalledProcessError as error:
        fail(f"cannot resolve substrate delta baseline for {target}: {error}")
    baseline_hash = hashlib.sha256(baseline_bytes).hexdigest()
    if row["baseline_sha256"] != baseline_hash:
        fail(f"wrong baseline hash in substrate delta: {target}")
    if baseline_hash == current_hash:
        fail(f"no-op substrate delta should not be recorded: {target}")
    if row["owner"] != "Vulpra substrate maintenance":
        fail(f"wrong substrate delta owner: {target}")
    if not row["reason"].strip():
        fail(f"missing substrate delta reason: {target}")

changed_imports: set[str] = set()
for row in import_rows:
    target = row["target_path"]
    target_path = ROOT / target
    if not target_path.is_file():
        continue
    try:
        baseline_bytes = subprocess.check_output(
            ["git", "-C", str(ROOT), "show", f"6fbf6aece2524707f590f66a1d69eaf7f11ce2c7:{target}"],
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        continue
    if hashlib.sha256(baseline_bytes).digest() != hashlib.sha256(target_path.read_bytes()).digest():
        changed_imports.add(target)
if changed_imports != delta_targets:
    fail(
        "substrate delta coverage mismatch: "
        f"missing={sorted(changed_imports - delta_targets)}, "
        f"extra={sorted(delta_targets - changed_imports)}"
    )

tracked = subprocess.check_output(
    ["git", "-C", str(ROOT), "ls-files", "-co", "--exclude-standard"], text=True
).splitlines()
for value in tracked:
    path = Path(value)
    if path.suffix in GENERATED_SUFFIXES or "__pycache__" in path.parts:
        fail(f"generated file present in repository worktree: {path}")

dependency_markers = ("Podfile", "Cartfile", "Package.resolved")
unexpected_dependencies = [name for name in dependency_markers if (ROOT / name).exists()]
if unexpected_dependencies:
    fail("unapproved product dependency manifests: " + ", ".join(unexpected_dependencies))

print("PASS: Vulpra product ownership boundary")
