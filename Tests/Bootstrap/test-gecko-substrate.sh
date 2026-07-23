#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
SOURCE_SHA=ef14c2997ae7dfdb44155240ec64fea3140ba9e1
FIREFOX_SHA=27b462b22705a8860f7ab0d33aa5b4b658ae5932
IDEVICE_SHA=92323d1262598cfcb31aa54ef94c26bb26c5c7a0

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

require_path() {
	[ -e "$ROOT/$1" ] || fail "missing imported path: $1"
}

require_path Vendor/firefox-release.txt
require_path Patches
require_path Tools/Gecko
require_path Tools/Build/AddGecko.sh
require_path .gitmodules
require_path .gitattributes
require_path docs/provenance/import-manifest.tsv

EXPECTED_ALLOWLIST=$(mktemp)
trap 'rm -f "$EXPECTED_ALLOWLIST"' EXIT HUP INT TERM
cat > "$EXPECTED_ALLOWLIST" <<'EOF'
engine/release.txt	Vendor/firefox-release.txt
patches	Patches
tools/development	Tools/Gecko
browser/Scripts/AddGecko.sh	Tools/Build/AddGecko.sh
EOF
head -n 4 "$ROOT/Tools/Bootstrap/import-allowlist.tsv" | cmp "$EXPECTED_ALLOWLIST" - ||
	fail "import allowlist differs from the approved Task 3 boundary"
grep -Fqx 'Patches/** -whitespace' "$ROOT/.gitattributes" ||
	fail "imported patch payloads are not exempted from diff whitespace checks"

python3 - "$ROOT" "$SOURCE_SHA" <<'PY'
from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import stat
import sys

root = Path(sys.argv[1])
source_sha = sys.argv[2]
manifest_path = root / "docs/provenance/import-manifest.tsv"

expected_targets = {"Vendor/firefox-release.txt", "Tools/Build/AddGecko.sh"}
expected_targets.update(
    path.relative_to(root).as_posix()
    for tree in (root / "Patches", root / "Tools/Gecko")
    for path in tree.rglob("*")
    if path.is_file()
)

actual_build_tools = {
    path.relative_to(root).as_posix()
    for path in (root / "Tools/Build").rglob("*")
    if path.is_file()
}
if actual_build_tools != {"Tools/Build/AddGecko.sh"}:
    raise SystemExit(f"FAIL: Tools/Build inventory mismatch: {sorted(actual_build_tools)}")

if len(expected_targets) != 272:
    raise SystemExit(
        f"FAIL: expected 272 imported regular files, found {len(expected_targets)}"
    )

patch_targets = {path for path in expected_targets if path.startswith("Patches/")}
if len(patch_targets) != 262 or any(not path.endswith(".patch") for path in patch_targets):
    raise SystemExit("FAIL: Patches must contain exactly 262 .patch files")

expected_tools = {
    f"Tools/Gecko/{name}"
    for name in (
        "apply-patches.sh",
        "build-gecko-simulator.sh",
        "build-gecko.sh",
        "build-idevice.sh",
        "create-patches.sh",
        "gecko-artifact.sh",
        "test-gecko-artifact.sh",
        "update-gecko.sh",
    )
}
actual_tools = {path for path in expected_targets if path.startswith("Tools/Gecko/")}
if actual_tools != expected_tools:
    raise SystemExit(
        "FAIL: Tools/Gecko inventory mismatch: "
        f"missing={sorted(expected_tools - actual_tools)}, "
        f"extra={sorted(actual_tools - expected_tools)}"
    )

with manifest_path.open(newline="", encoding="utf-8") as source:
    rows = list(csv.DictReader(source, delimiter="\t"))

if len({row["target_path"] for row in rows}) != len(rows):
    raise SystemExit("FAIL: manifest contains duplicate target paths")

task3_rows = [row for row in rows if row["target_path"] in expected_targets]
if len(task3_rows) != 272:
    raise SystemExit(f"FAIL: manifest must contain 272 Task 3 rows, found {len(task3_rows)}")

manifest_targets = {row["target_path"] for row in task3_rows}
if manifest_targets != expected_targets:
    raise SystemExit(
        "FAIL: manifest target set mismatch: "
        f"missing={sorted(expected_targets - manifest_targets)}, "
        f"extra={sorted(manifest_targets - expected_targets)}"
    )

for row in task3_rows:
    target = row["target_path"]
    if row["source_commit"] != source_sha:
        raise SystemExit(f"FAIL: non-canonical source commit for {target}")
    if target == "Vendor/firefox-release.txt":
        expected_source = "engine/release.txt"
    elif target == "Tools/Build/AddGecko.sh":
        expected_source = "browser/Scripts/AddGecko.sh"
    elif target.startswith("Patches/"):
        expected_source = "patches/" + target.removeprefix("Patches/")
    elif target.startswith("Tools/Gecko/"):
        expected_source = "tools/development/" + target.removeprefix("Tools/Gecko/")
    else:
        raise SystemExit(f"FAIL: unexpected manifest target: {target}")
    if row["source_path"] != expected_source:
        raise SystemExit(f"FAIL: source mapping mismatch for {target}")

    target_path = root / target
    target_stat = target_path.lstat()
    if not stat.S_ISREG(target_stat.st_mode):
        raise SystemExit(f"FAIL: imported target is not a regular file: {target}")
    digest = hashlib.sha256(target_path.read_bytes()).hexdigest()
    if row["sha256"] != digest:
        raise SystemExit(f"FAIL: stale manifest hash for {target}")
PY

[ "$(git -C "$ROOT" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | wc -l | tr -d ' ')" = 2 ] ||
	fail ".gitmodules must define exactly two submodules"
[ "$(git -C "$ROOT" config -f .gitmodules --get submodule.Vendor/firefox.path)" = "Vendor/firefox" ] ||
	fail "Firefox submodule path mismatch"
[ "$(git -C "$ROOT" config -f .gitmodules --get submodule.Vendor/firefox.url)" = "https://github.com/mozilla-firefox/firefox" ] ||
	fail "Firefox submodule URL mismatch"
[ "$(git -C "$ROOT" config -f .gitmodules --get submodule.Vendor/idevice.path)" = "Vendor/idevice" ] ||
	fail "idevice submodule path mismatch"
[ "$(git -C "$ROOT" config -f .gitmodules --get submodule.Vendor/idevice.url)" = "https://github.com/jkcoxson/idevice" ] ||
	fail "idevice submodule URL mismatch"

[ "$(git -C "$ROOT" ls-files -s -- Vendor/firefox)" = "$(printf '160000 %s 0\tVendor/firefox' "$FIREFOX_SHA")" ] ||
	fail "Firefox gitlink mismatch"
[ "$(git -C "$ROOT" ls-files -s -- Vendor/idevice)" = "$(printf '160000 %s 0\tVendor/idevice' "$IDEVICE_SHA")" ] ||
	fail "idevice gitlink mismatch"

if git -C "$ROOT" ls-files | grep -Eq '(^|/)browser/Reynard/Client/|(^|/)Reynard\.xcodeproj/|(^|/)Resources/'; then
	fail "legacy client, source Xcode project, or product resource leaked into the substrate"
fi

if grep -R -n -E \
	'engine/release\.txt|engine/firefox|support/idevice|tools/development|browser/Reynard/JIT/RPPairing|REYNARD_ROOT_DIR|reynard-gecko-ios-arm64|reynard-artifact-escape|/patches([/"[:space:]]|$)|find patches([[:space:]]|$)' \
	"$ROOT/Tools/Gecko" "$ROOT/Tools/Build"; then
	fail "legacy build path or active artifact identity remains"
fi

grep -Fq 'Vendor/firefox-release.txt' "$ROOT/Tools/Gecko/apply-patches.sh" ||
	fail "release metadata path was not ported"
grep -Fq 'Vendor/firefox' "$ROOT/Tools/Gecko/build-gecko.sh" ||
	fail "Firefox path was not ported"
for script in apply-patches.sh create-patches.sh update-gecko.sh; do
	grep -Fq 'HEAD:$SUBMODULE_PATH' "$ROOT/Tools/Gecko/$script" ||
		fail "$script does not enforce the canonical Firefox gitlink"
done
grep -Fq 'Vendor/idevice' "$ROOT/Tools/Gecko/build-idevice.sh" ||
	fail "idevice path was not ported"
grep -Fq '.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a' "$ROOT/Tools/Gecko/build-idevice.sh" ||
	fail "idevice output path is not the generated .build owner"
if grep -Fq 'Modules/VulpraRuntime/JIT/RPPairing/libidevice_ffi.a' "$ROOT/Tools/Gecko/build-idevice.sh"; then
	fail "idevice producer still writes a generated archive under Modules"
fi
grep -Fq 'VULPRA_ROOT_DIR' "$ROOT/Tools/Gecko/gecko-artifact.sh" ||
	fail "artifact root environment variable was not ported"
grep -Fq 'vulpra-gecko-ios-arm64' "$ROOT/Tools/Gecko/gecko-artifact.sh" ||
	fail "artifact identity was not ported"
grep -Fq '../vulpra-artifact-escape' "$ROOT/Tools/Gecko/test-gecko-artifact.sh" ||
	fail "artifact escape fixture identity was not ported"
grep -Fq 'Vendor/firefox/toolkit/mozapps/extensions/default-theme' "$ROOT/Tools/Build/AddGecko.sh" ||
	fail "AddGecko default-theme path was not ported"

for script in "$ROOT"/Tools/Gecko/*.sh "$ROOT"/Tools/Build/*.sh; do
	IFS= read -r shebang < "$script"
	case "$shebang" in
		'#!/bin/sh')
			sh -n "$script"
			if command -v dash >/dev/null 2>&1; then
				dash -n "$script"
			fi
			;;
		'#!/bin/bash'|'#!/usr/bin/env bash')
			bash -n "$script"
			;;
		'#!/bin/zsh'|'#!/usr/bin/env zsh')
			if command -v zsh >/dev/null 2>&1; then
				zsh -n "$script"
			else
				echo "Skipping unavailable zsh syntax check: ${script#$ROOT/}"
			fi
			;;
		*) fail "unsupported shell interpreter in ${script#$ROOT/}: $shebang" ;;
	esac
done

"$ROOT/Tools/Gecko/test-gecko-artifact.sh"

echo "Gecko substrate checks passed."
