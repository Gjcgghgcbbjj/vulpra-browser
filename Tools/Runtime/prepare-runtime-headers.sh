#!/bin/sh
# prepare-runtime-headers.sh — ensure Gecko headers are available in the
# active dist directory (device or simulator) for the Xcode build.
#
# The "Materialize pinned Gecko headers" workflow step patches and copies
# headers into the device dist path. This script mirrors them into the
# simulator dist path when building for iphonesimulator.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

DEVICE_DIST="$ROOT_DIR/Vendor/firefox/obj-aarch64-apple-ios/dist"
SIM_DIST="$ROOT_DIR/Vendor/firefox/obj-aarch64-apple-ios-sim/dist"

# If sim dist exists, copy GeckoView headers from the device dist (which
# was populated by the materialize step) into the sim dist include dir.
if [ -d "$SIM_DIST" ]; then
    SIM_INCLUDE="$SIM_DIST/include/GeckoView"
    mkdir -p "$SIM_INCLUDE"
    for header in IOSBootstrap.h GeckoViewSwiftSupport.h GeckoViewRuntimeSupport.h; do
        src="$DEVICE_DIST/include/GeckoView/$header"
        dst="$SIM_INCLUDE/$header"
        if [ -f "$src" ] && [ ! -f "$dst" ]; then
            cp "$src" "$dst"
        fi
    done
    echo "Simulator GeckoView headers prepared."
else
    echo "Simulator dist not found; skipping header preparation."
fi
