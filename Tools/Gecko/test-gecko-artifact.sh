#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
HELPER="$SCRIPT_DIR/gecko-artifact.sh"
FIXTURE="$(mktemp -d)"
MIRROR="$(mktemp -d)"
FIREFOX_COMMIT=0123456789abcdef0123456789abcdef01234567
trap 'rm -rf "$FIXTURE" "$MIRROR"' EXIT HUP INT TERM

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

mkdir -p \
	"$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/bin" \
	"$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/include" \
	"$FIXTURE/Vendor/firefox/toolkit/mozapps/extensions/default-theme" \
	"$FIXTURE/Patches/widget" \
	"$FIXTURE/Tools/Gecko"

printf '%s\n' 'FIREFOX_TEST_RELEASE' > "$FIXTURE/Vendor/firefox-release.txt"
printf '%s\n' 'patch-v1' > "$FIXTURE/Patches/widget/test.patch"
printf '%s\n' '#!/bin/sh' 'echo build' > "$FIXTURE/Tools/Gecko/build-gecko.sh"
printf '%s\n' 'xul' > "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/bin/XUL"
printf '%s\n' 'dylib' > "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/bin/libfixture.dylib"
printf '%s\n' 'header' > "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/include/test.h"
printf '%s\n' 'generated-header' > "$FIXTURE/generated-header.h"
ln -s "$FIXTURE/generated-header.h" "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/include/generated.h"
printf '%s\n' 'theme' > "$FIXTURE/Vendor/firefox/toolkit/mozapps/extensions/default-theme/theme.css"

key_one="$(VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" key Xcode_26.4.1.app)"
key_repeat="$(VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" key Xcode_26.4.1.app)"
[ "$key_one" = "$key_repeat" ] || fail "artifact key is not stable"

mkdir -p "$MIRROR/Vendor" "$MIRROR/Patches/widget" "$MIRROR/Tools/Gecko"
cp "$FIXTURE/Vendor/firefox-release.txt" "$MIRROR/Vendor/firefox-release.txt"
cp "$FIXTURE/Patches/widget/test.patch" "$MIRROR/Patches/widget/test.patch"
cp "$FIXTURE/Tools/Gecko/build-gecko.sh" "$MIRROR/Tools/Gecko/build-gecko.sh"
key_mirror="$(VULPRA_ROOT_DIR="$MIRROR" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" key Xcode_26.4.1.app)"
[ "$key_one" = "$key_mirror" ] || fail "artifact key depends on the absolute checkout path"

key_commit_changed="$(VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT=1111111111111111111111111111111111111111 "$HELPER" key Xcode_26.4.1.app)"
[ "$key_one" != "$key_commit_changed" ] || fail "Firefox commit change did not change key"

printf '%s\n' 'patch-v2' > "$FIXTURE/Patches/widget/test.patch"
key_changed="$(VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" key Xcode_26.4.1.app)"
[ "$key_one" != "$key_changed" ] || fail "patch change did not change key"

archive="$FIXTURE/gecko.tar.gz"
VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" pack "$archive" Xcode_26.4.1.app
[ -s "$archive" ] || fail "pack did not create archive"

rm -rf "$FIXTURE/Vendor/firefox"
VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" restore "$archive" Xcode_26.4.1.app
VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" verify Xcode_26.4.1.app
[ -s "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/bin/XUL" ] || fail "XUL was not restored"
[ -s "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/bin/libfixture.dylib" ] || fail "dylib was not restored"
[ -s "$FIXTURE/Vendor/firefox/toolkit/mozapps/extensions/default-theme/theme.css" ] || fail "theme was not restored"
[ ! -L "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/include/generated.h" ] || fail "absolute header symlink was not dereferenced"
grep -Fqx 'generated-header' "$FIXTURE/Vendor/firefox/obj-aarch64-apple-ios/dist/include/generated.h" || fail "dereferenced header content was not restored"

if VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" verify Xcode_26.5.app >/dev/null 2>&1; then
	fail "mismatched Xcode key was accepted"
fi

printf '%s\n' 'not a gzip archive' > "$FIXTURE/corrupt.tar.gz"
if VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" restore "$FIXTURE/corrupt.tar.gz" Xcode_26.4.1.app >/dev/null 2>&1; then
	fail "corrupt archive was accepted"
fi

python3 - "$FIXTURE/unsafe.tar.gz" <<'PY'
import io
import sys
import tarfile

with tarfile.open(sys.argv[1], "w:gz") as archive:
    info = tarfile.TarInfo("../vulpra-artifact-escape")
    payload = b"escape"
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))
PY

rm -f "$FIXTURE/../vulpra-artifact-escape"
if VULPRA_ROOT_DIR="$FIXTURE" VULPRA_FIREFOX_COMMIT="$FIREFOX_COMMIT" "$HELPER" restore "$FIXTURE/unsafe.tar.gz" Xcode_26.4.1.app >/dev/null 2>&1; then
	fail "unsafe archive member was accepted"
fi
[ ! -e "$FIXTURE/../vulpra-artifact-escape" ] || fail "unsafe archive escaped root"

echo "Gecko artifact contract tests passed."
