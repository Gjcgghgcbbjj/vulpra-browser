#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
for name in build-app.sh build-ptrace-jit.sh package-app.sh create-ipa.sh; do
	[ -f "$ROOT/Tools/Release/$name" ] || { echo "FAIL: missing Tools/Release/$name" >&2; exit 1; }
done

fail() { echo "FAIL: $*" >&2; exit 1; }
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
archive="$fixture/Vulpra.xcarchive"
app="$archive/Products/Applications/Vulpra.app"
mkdir -p "$app/Frameworks/GeckoView.framework" "$app/PlugIns/Vulpra Helper.appex" "$app/PlugIns/OpenIn.appex"
printf '%s\n' com.vulpra.browser > "$app/.vulpra-bundle-id"
printf '%s\n' com.vulpra.browser.geckoview > "$app/Frameworks/GeckoView.framework/.vulpra-bundle-id"
printf '%s\n' com.vulpra.browser.helper > "$app/PlugIns/Vulpra Helper.appex/.vulpra-bundle-id"
printf '%s\n' com.vulpra.browser.open-in > "$app/PlugIns/OpenIn.appex/.vulpra-bundle-id"
printf xul > "$app/Frameworks/XUL"
printf dylib > "$app/Frameworks/libfixture.dylib"

tree_hash() {
	find "$1" -type f -print | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$file"; done | sha256sum | awk '{print $1}'
}
before=$(tree_hash "$archive")
mkdir -p "$fixture/out"
"$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app "$fixture/stage-ipa" "$fixture/out/Vulpra.ipa"
"$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app "$fixture/stage-tipa" "$fixture/out/Vulpra-TrollStore.tipa"
after=$(tree_hash "$archive")
[ "$before" = "$after" ] || fail "packager modified the archive"

python3 - "$fixture/out/Vulpra.ipa" "$fixture/out/Vulpra-TrollStore.tipa" <<'PY'
import sys, zipfile
for path in sys.argv[1:]:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
    if not names or not all(name.startswith("Payload/") for name in names):
        raise SystemExit(f"FAIL: invalid Payload archive: {path}")
    for required in ("Payload/Vulpra.app/Frameworks/XUL", "Payload/Vulpra.app/PlugIns/OpenIn.appex/.vulpra-bundle-id"):
        if required not in names:
            raise SystemExit(f"FAIL: missing {required}")
PY

manifest="$fixture/out/SHA256SUMS"
[ "$(wc -l < "$manifest" | tr -d ' ')" = 2 ] || fail "checksum manifest must contain two packages"
first_manifest=$(cat "$manifest")
first_ipa=$(sha256sum "$fixture/out/Vulpra.ipa" | awk '{print $1}')
"$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app "$fixture/stage-repeat" "$fixture/out/Vulpra.ipa"
[ "$first_ipa" = "$(sha256sum "$fixture/out/Vulpra.ipa" | awk '{print $1}')" ] || fail "package bytes are not deterministic"
[ "$first_manifest" = "$(cat "$manifest")" ] || fail "checksum manifest is not deterministic"

mv "$app/Frameworks/XUL" "$app/Frameworks/XUL.missing"
if "$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app "$fixture/stage-missing" "$fixture/out/missing.ipa" >/dev/null 2>&1; then
	fail "missing XUL was accepted"
fi
mv "$app/Frameworks/XUL.missing" "$app/Frameworks/XUL"

printf '%s\n' wrong.bundle > "$app/PlugIns/OpenIn.appex/.vulpra-bundle-id"
if "$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app "$fixture/stage-wrong" "$fixture/out/wrong.ipa" >/dev/null 2>&1; then
	fail "wrong bundle identity was accepted"
fi

build_app="$ROOT/Tools/Release/build-app.sh"
grep -Fq 'generic/platform=iOS' "$build_app" || fail "archive destination is wrong"
grep -Fq 'CODE_SIGNING_ALLOWED=NO' "$build_app" || fail "unsigned archive flag is missing"
grep -Fq 'Tools/Runtime/verify-runtime-artifacts.sh' "$build_app" || fail "archive does not verify runtime artifacts"
grep -Fq -- '-miphoneos-version-min=15.0' "$ROOT/Tools/Release/build-ptrace-jit.sh" || fail "ptrace deployment target is wrong"
grep -Fq 'ptrace_jit.entitlements' "$ROOT/Tools/Release/create-ipa.sh" || fail "ptrace entitlement signing is missing"
grep -Fq 'ldid' "$ROOT/Tools/Release/create-ipa.sh" || fail "TrollStore signing owner is missing"
if grep -R -n -E 'DEVELOPMENT_TEAM|PROVISIONING_PROFILE|plutil.*CFBundleIdentifier' "$ROOT/Tools/Release"; then
	fail "release producer contains signing identity or bundle rewrite"
fi

for script in "$ROOT"/Tools/Release/*.sh; do
	sh -n "$script"
	[ "$(wc -l < "$script" | tr -d ' ')" -lt 250 ] || fail "release script exceeds 250 lines"
done

echo "PASS: deterministic Vulpra release packaging"
