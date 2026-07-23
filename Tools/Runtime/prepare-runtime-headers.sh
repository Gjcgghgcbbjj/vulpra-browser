#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ROOT_DIR=${VULPRA_ROOT_DIR:-$DEFAULT_ROOT}

case "${PLATFORM_NAME:-iphoneos}" in
	iphonesimulator) TARGET_TRIPLE=aarch64-apple-ios-sim ;;
	iphoneos|'') TARGET_TRIPLE=aarch64-apple-ios ;;
	*)
		echo "Unsupported Apple platform: ${PLATFORM_NAME}" >&2
		exit 64
		;;
esac

SOURCE_DIR="$ROOT_DIR/Vendor/firefox/obj-$TARGET_TRIPLE/dist/include/GeckoView"
OUTPUT_DIR="$ROOT_DIR/.build/runtime-headers/GeckoView"
mkdir -p "$OUTPUT_DIR"

for name in IOSBootstrap.h GeckoViewSwiftSupport.h GeckoViewRuntimeSupport.h; do
	source="$SOURCE_DIR/$name"
	output="$OUTPUT_DIR/$name"
	[ -s "$source" ] || {
		echo "Missing runtime header: $source" >&2
		exit 1
	}
	cp -fL "$source" "$output"
	[ -s "$output" ] || {
		echo "Failed to stage runtime header: $output" >&2
		exit 1
	}
done

echo "runtime-headers-ok"
