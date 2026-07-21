#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

require_file() {
	[ -f "$ROOT/$1" ] || fail "missing $1"
}

for path in \
	Tools/Runtime/check-macos-prerequisites.sh \
	Tools/Runtime/verify-runtime-artifacts.sh \
	Tools/Runtime/build-runtime-substrate.sh; do
	require_file "$path"
done

grep -Fq 'enable-ios-target=15.0' "$ROOT/Tools/Gecko/build-gecko.sh" ||
	fail "Gecko deployment target is not 15.0"
grep -Fq 'DEPLOYMENT_TARGET="15.0"' "$ROOT/Tools/Gecko/build-idevice.sh" ||
	fail "idevice deployment target is not 15.0"
grep -Fq '.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a' "$ROOT/Tools/Gecko/build-idevice.sh" ||
	fail "idevice output is not canonical"
if grep -Fq 'Modules/VulpraRuntime/JIT/RPPairing/libidevice_ffi.a' "$ROOT/Tools/Gecko/build-idevice.sh"; then
	fail "idevice producer still writes under Modules"
fi

artifact="$ROOT/Tools/Gecko/gecko-artifact.sh"
for token in 'FORMAT_VERSION="3"' VULPRA_XCODE_BUILD VULPRA_SDK_BUILD IOSBootstrap.h GeckoViewSwiftSupport.h; do
	grep -Fq "$token" "$artifact" || fail "artifact v3 contract missing $token"
done

add_gecko="$ROOT/Tools/Build/AddGecko.sh"
grep -Fq 'Tools/Runtime/verify-runtime-artifacts.sh' "$add_gecko" ||
	fail "AddGecko does not require verified runtime artifacts"
grep -Fq '${SRCROOT}/Vendor/firefox/toolkit/mozapps/extensions/default-theme' "$add_gecko" ||
	fail "AddGecko default-theme root is wrong"
if grep -Fq '${SRCROOT}/../Vendor' "$add_gecko"; then
	fail "AddGecko escapes the repository root"
fi

prerequisite_output=$(mktemp)
trap 'rm -f "$prerequisite_output"' EXIT HUP INT TERM
set +e
"$ROOT/Tools/Runtime/check-macos-prerequisites.sh" >"$prerequisite_output" 2>&1
prerequisite_status=$?
set -e
if [ "$(uname -s)" != Darwin ]; then
	[ "$prerequisite_status" -eq 78 ] || fail "non-Darwin prerequisite status is not 78"
	grep -Fq 'needs-macos' "$prerequisite_output" || fail "non-Darwin prerequisite output is unclear"
fi

fixture=$(mktemp -d)
trap 'rm -f "$prerequisite_output"; rm -rf "$fixture"' EXIT HUP INT TERM
mkdir -p \
	"$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/bin" \
	"$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/include/GeckoView" \
	"$fixture/Vendor/firefox/toolkit/mozapps/extensions/default-theme" \
	"$fixture/.build/idevice/aarch64-apple-ios/release"
printf xul > "$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/bin/XUL"
printf dylib > "$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/bin/libfixture.dylib"
printf header > "$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/include/GeckoView/IOSBootstrap.h"
printf header > "$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/include/GeckoView/GeckoViewSwiftSupport.h"
printf theme > "$fixture/Vendor/firefox/toolkit/mozapps/extensions/default-theme/theme.css"
printf archive > "$fixture/.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a"
VULPRA_ROOT_DIR="$fixture" "$ROOT/Tools/Runtime/verify-runtime-artifacts.sh" >/dev/null ||
	fail "valid runtime artifact fixture was rejected"

rm -f "$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/include/GeckoView/IOSBootstrap.h"
if VULPRA_ROOT_DIR="$fixture" "$ROOT/Tools/Runtime/verify-runtime-artifacts.sh" >"$prerequisite_output" 2>&1; then
	fail "missing required Gecko header was accepted"
fi
grep -Fq "$fixture/Vendor/firefox/obj-aarch64-apple-ios/dist/include/GeckoView/IOSBootstrap.h" "$prerequisite_output" ||
	fail "artifact verifier did not print the exact missing path"

orchestrator="$ROOT/Tools/Runtime/build-runtime-substrate.sh"
python3 - "$orchestrator" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
ordered = [
    "check-macos-prerequisites.sh",
    "submodule update --init --recursive Vendor/firefox Vendor/idevice",
    "build-idevice.sh",
    "build-gecko.sh",
    "gecko-artifact.sh\" pack",
    "verify-runtime-artifacts.sh",
]
positions = [text.find(token) for token in ordered]
if any(position < 0 for position in positions) or positions != sorted(positions):
    raise SystemExit(f"FAIL: runtime producer order is wrong: {positions}")
PY

for script in "$ROOT"/Tools/Runtime/*.sh "$ROOT"/Tools/Gecko/*.sh "$ROOT"/Tools/Build/*.sh; do
	lines=$(wc -l < "$script" | tr -d ' ')
	[ "$lines" -lt 250 ] || fail "script exceeds 250-line budget: ${script#$ROOT/}"
done

echo "PASS: runtime artifact producer contracts"
