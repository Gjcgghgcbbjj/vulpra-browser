#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)

require() {
	[ -e "$ROOT/$1" ] || { echo "FAIL: missing imported path: $1" >&2; exit 1; }
}

require Modules/VulpraRuntime/JIT/JITEnabler.m
require Modules/VulpraRuntime/JIT/RPPairing/JITEndpointMonitor.m
require Modules/VulpraRuntime/Native/Utils.m

[ ! -e "$ROOT/Modules/VulpraRuntime/JIT/JITController.swift" ] || exit 1
[ ! -d "$ROOT/Modules/VulpraRuntime/JIT/Interface" ] || exit 1
[ ! -e "$ROOT/Modules/VulpraRuntime/JIT/RPPairing/libidevice_ffi.a" ] || exit 1

python3 - "$ROOT" <<'PY'
from pathlib import Path
import csv
import hashlib
import plistlib
import stat
import sys

root = Path(sys.argv[1])
module_root = root / "Modules/VulpraRuntime"
files = {p.relative_to(root).as_posix() for p in module_root.rglob("*") if p.is_file()}
if len(files) != 15:
    raise SystemExit(f"FAIL: expected 15 low-level JIT/native files, found {len(files)}")

for forbidden in ("JITController.swift", "JITFailure.swift", "libidevice_ffi.a"):
    if any(Path(path).name == forbidden for path in files):
        raise SystemExit(f"FAIL: excluded/generated JIT file imported: {forbidden}")

with (root / "docs/provenance/import-manifest.tsv").open(newline="", encoding="utf-8") as source:
    rows = list(csv.DictReader(source, delimiter="\t"))
module_rows = [row for row in rows if row["target_path"].startswith("Modules/")]
if len(module_rows) != 15 or {row["target_path"] for row in module_rows} != files:
    raise SystemExit("FAIL: JIT/native manifest coverage mismatch")

for row in module_rows:
    target = root / row["target_path"]
    if not stat.S_ISREG(target.lstat().st_mode):
        raise SystemExit(f"FAIL: non-regular module target: {row['target_path']}")
    if hashlib.sha256(target.read_bytes()).hexdigest() != row["sha256"]:
        raise SystemExit(f"FAIL: stale manifest hash: {row['target_path']}")

support = root / "Modules/VulpraRuntime/JIT/RPPairing/JITSupport.m"
monitor = root / "Modules/VulpraRuntime/JIT/RPPairing/JITEndpointMonitor.m"
if sum(1 for _ in support.open(encoding="utf-8")) >= 800:
    raise SystemExit("FAIL: JITSupport.m remains above the 800-line pressure threshold")
for symbol in ("registerJITEndpointForPID", "unregisterJITEndpointForPID", "resetJITEndpointMonitor"):
    if symbol not in monitor.read_text(encoding="utf-8"):
        raise SystemExit(f"FAIL: endpoint monitor owner missing {symbol}")

required = {
    "Modules/VulpraRuntime/JIT/JITErrors.m": ("Vulpra.JIT",),
    "Modules/VulpraRuntime/JIT/JITEnabler.m": ("com.vulpra.browser.jit.enabler",),
    "Modules/VulpraRuntime/JIT/RPPairing/DDIManager.swift": ("com.vulpra.browser.jit.ddi",),
    "Modules/VulpraRuntime/JIT/RPPairing/JITSupport.m": (
        "com.vulpra.browser.jit.support",
        "VulpraDebug",
        '"Vulpra"',
    ),
    "Modules/VulpraRuntime/JIT/RPPairing/JITEndpointMonitor.m": (
        "com.vulpra.browser.jit.endpoint-monitor-failed",
    ),
    "Modules/VulpraRuntime/JIT/RPPairing/JITUtils.m": ("[VULPRA_DEBUG]",),
}
for relative, values in required.items():
    content = (root / relative).read_text(encoding="utf-8")
    for value in values:
        if value not in content:
            raise SystemExit(f"FAIL: missing JIT identity {value!r} in {relative}")

with (root / "Modules/VulpraRuntime/JIT/Unsandboxed/ptrace_jit.entitlements").open("rb") as source:
    plistlib.load(source)
PY

echo "JIT substrate checks passed."
