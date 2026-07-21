#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ROOT_DIR=${VULPRA_ROOT_DIR:-$DEFAULT_ROOT}
GECKO_DIST="$ROOT_DIR/Vendor/firefox/obj-aarch64-apple-ios/dist"
IDEVICE_ARCHIVE="$ROOT_DIR/.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a"
DEFAULT_THEME="$ROOT_DIR/Vendor/firefox/toolkit/mozapps/extensions/default-theme"

missing=0
require_file() {
	if [ ! -s "$1" ]; then
		echo "Missing runtime artifact: $1" >&2
		missing=1
	fi
}

require_file "$GECKO_DIST/bin/XUL"
require_file "$GECKO_DIST/include/GeckoView/IOSBootstrap.h"
require_file "$GECKO_DIST/include/GeckoView/GeckoViewSwiftSupport.h"
require_file "$IDEVICE_ARCHIVE"

found_dylib=0
for dylib in "$GECKO_DIST/bin/"*.dylib; do
	if [ -s "$dylib" ]; then
		found_dylib=1
		break
	fi
done
if [ "$found_dylib" -ne 1 ]; then
	echo "Missing runtime artifact: $GECKO_DIST/bin/*.dylib" >&2
	missing=1
fi

if [ ! -d "$DEFAULT_THEME" ] || ! find "$DEFAULT_THEME" -type f -print -quit | grep -q .; then
	echo "Missing runtime artifact: $DEFAULT_THEME" >&2
	missing=1
fi

[ "$missing" -eq 0 ] || {
	echo "Run Tools/Runtime/build-runtime-substrate.sh on macOS." >&2
	exit 1
}

echo "runtime-artifacts-ok"
