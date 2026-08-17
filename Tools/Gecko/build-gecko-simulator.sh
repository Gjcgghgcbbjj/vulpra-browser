#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
FIREFOX_DIR="$ROOT_DIR/Vendor/firefox"
TARGET="aarch64-apple-ios-sim"

[ -d "$FIREFOX_DIR" ] || { echo "Missing firefox source at $FIREFOX_DIR" >&2; exit 1; }

cat >"$FIREFOX_DIR/.mozconfig" <<EOF
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-$TARGET
ac_add_options --enable-application=mobile/ios
ac_add_options --target=$TARGET
ac_add_options --enable-ios-target=15.0
# The iOS Simulator SDK does not ship macOS ApplicationServices. Gecko's
# desktop-capture WebRTC sources otherwise select the macOS implementation.
ac_add_options --disable-webrtc
ac_add_options --enable-optimize
ac_add_options --disable-debug
ac_add_options --disable-tests
EOF

rustup target add "$TARGET"
cd "$FIREFOX_DIR"
./mach build
