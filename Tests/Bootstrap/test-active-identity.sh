#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)

python3 - "$ROOT" <<'PY'
from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import plistlib
import re
import stat
import sys

root = Path(sys.argv[1])
allowlist_path = root / "Tools/Bootstrap/active-identity-allowlist.txt"
if not allowlist_path.is_file():
    raise SystemExit("FAIL: missing active identity allowlist")

allowed_provenance = {
    line.rstrip("\n")
    for line in allowlist_path.read_text(encoding="utf-8").splitlines()
    if line and not line.startswith("#")
}
excluded_files = {
    allowlist_path,
    root / "Tools/Bootstrap/import-allowlist.tsv",
}

scan_roots = [root / name for name in ("Extensions", "Modules", "Tools", ".github", "Patches")]
scan_files = sorted(
    path
    for scan_root in scan_roots
    if scan_root.exists()
    for path in scan_root.rglob("*")
    if path.is_file() and path not in excluded_files
)

forbidden = (
    r"ReynardXPCListenerEndpoint",
    r"ReynardHelperMain",
    r"Reynard\.ProcessBootstrap",
    r"ReynardExtension",
    r"Reynard Helper\.appex",
    r"Reynard:Features",
    r"installId.{0,80}reynard-",
    r"reynard://",
    r"com\.minh-ton",
    r"me\.minh-ton",
    r"REYNARD_DEBUG",
    r"reynard-download\.tmp",
    r"reynard_mmap",
    r"REYNARD:",
)

for pattern in forbidden:
    expression = re.compile(pattern)
    for path in scan_files:
        for line_number, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if expression.search(line):
                relative = path.relative_to(root)
                raise SystemExit(
                    f"FAIL: forbidden active identity {pattern!r} at {relative}:{line_number}"
                )

old_identity = re.compile(r"Reynard|reynard|REYNARD")
for path in scan_files:
    relative = path.relative_to(root)
    if old_identity.search(relative.as_posix()):
        raise SystemExit(f"FAIL: old product identity remains in path: {relative}")
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        if not old_identity.search(line):
            continue
        normalized = line[1:] if relative.parts[0] == "Patches" and line.startswith("+") else line
        if normalized in allowed_provenance:
            continue
        raise SystemExit(
            f"FAIL: non-provenance old identity at {relative}:{line_number}: {line.strip()}"
        )

expected_files = {
    path.relative_to(root).as_posix()
    for tree in (root / "Extensions/GeckoView", root / "Extensions/Helper")
    for path in tree.rglob("*")
    if path.is_file()
}
if len(expected_files) != 59:
    raise SystemExit(f"FAIL: expected 59 GeckoView/Helper files, found {len(expected_files)}")

manifest_path = root / "docs/provenance/import-manifest.tsv"
with manifest_path.open(newline="", encoding="utf-8") as source:
    rows = list(csv.DictReader(source, delimiter="\t"))
extension_rows = [row for row in rows if row["target_path"].startswith("Extensions/")]
manifest_targets = {row["target_path"] for row in extension_rows}
if len(extension_rows) != 59 or manifest_targets != expected_files:
    raise SystemExit("FAIL: GeckoView/Helper manifest coverage mismatch")

renamed_entitlements = {
    "Extensions/Helper/Entitlements/Vulpra-Helper.entitlements":
        "browser/Helper/Entitlements/Reynard-Helper.entitlements",
    "Extensions/Helper/Entitlements/Vulpra-Helper.private.entitlements":
        "browser/Helper/Entitlements/Reynard-Helper.private.entitlements",
}
for row in extension_rows:
    target = row["target_path"]
    if target in renamed_entitlements:
        expected_source = renamed_entitlements[target]
    elif target.startswith("Extensions/GeckoView/"):
        expected_source = "browser/GeckoView/" + target.removeprefix("Extensions/GeckoView/")
    else:
        expected_source = "browser/Helper/" + target.removeprefix("Extensions/Helper/")
    if row["source_path"] != expected_source:
        raise SystemExit(f"FAIL: source mapping mismatch for {target}")
    target_path = root / target
    if not stat.S_ISREG(target_path.lstat().st_mode):
        raise SystemExit(f"FAIL: imported target is not a regular file: {target}")
    digest = hashlib.sha256(target_path.read_bytes()).hexdigest()
    if row["sha256"] != digest:
        raise SystemExit(f"FAIL: stale manifest hash for {target}")

with (root / "Extensions/Helper/Info.plist").open("rb") as source:
    helper_info = plistlib.load(source)
principal = helper_info["NSExtension"]["NSExtensionPrincipalClass"]
if principal != "VulpraHelperMain":
    raise SystemExit(f"FAIL: Helper principal class mismatch: {principal}")

with (root / "Extensions/Helper/Entitlements/Vulpra-Helper.private.entitlements").open("rb") as source:
    helper_entitlements = plistlib.load(source)
if helper_entitlements.get("application-identifier") != "com.vulpra.browser.helper":
    raise SystemExit("FAIL: Helper application identifier mismatch")

required_contracts = {
    "Extensions/Helper/Helper.swift": (
        "VulpraXPCListenerEndpoint",
        "Vulpra.ProcessBootstrap",
        "@objc(VulpraHelperMain)",
        "final class VulpraHelperMain",
    ),
    "Extensions/GeckoView/Session/Features/SessionFeatureBridge.swift": (
        "Vulpra:Features:GetCapabilities",
        "Vulpra:Features:NightMode",
        "Vulpra:Features:ContentBlocking",
        "Vulpra:Features:UserScripts",
        "Vulpra:Features:Privacy",
    ),
    "Extensions/GeckoView/Addons/AddonRuntimeCommands.swift": ('"installId": "vulpra-',),
    "Patches/ipc/glue/NSExtensionUtils.mm.patch": (
        "com.vulpra.browser.extension-launch",
        "Vulpra Helper.appex",
        "VulpraExtension",
        "VulpraXPCListenerEndpoint",
    ),
    "Patches/ipc/glue/GeckoChildProcessHost.cpp.patch": ("VULPRA_DEBUG",),
    "Patches/widget/uikit/ExternalResponseService.mm.patch": ("vulpra-download.tmp",),
    "Patches/js/src/jit/ProcessExecutableMemory.cpp.patch": ("vulpra_mmap",),
}
for relative, values in required_contracts.items():
    content = (root / relative).read_text(encoding="utf-8")
    for value in values:
        if value not in content:
            raise SystemExit(f"FAIL: missing Vulpra contract {value!r} in {relative}")
PY

echo "Active identity checks passed."
