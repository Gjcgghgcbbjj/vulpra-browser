#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Accept target arg: aarch64-apple-ios (device) or aarch64-apple-ios-sim (simulator)
BUILD_TARGET="${1:-aarch64-apple-ios}"
RUST_TARGET="$BUILD_TARGET"
# Canonical output: .build/idevice/aarch64-apple-ios/release/libidevice_ffi.a
OUTPUT_LIB="$REPO_ROOT/.build/idevice/$RUST_TARGET/release/libidevice_ffi.a"
CARGO_TARGET_DIR="$REPO_ROOT/.build/idevice"
DEPLOYMENT_TARGET="15.0"

[ -f "$REPO_ROOT/Vendor/idevice/ffi/Cargo.toml" ] || {
	echo "Missing idevice source at $REPO_ROOT/Vendor/idevice/ffi" >&2
	echo "Run Tools/Runtime/build-runtime-substrate.sh on macOS." >&2
	exit 1
}

DEPLOYMENT_FLAG="-miphoneos-version-min=${DEPLOYMENT_TARGET}"

if ! rustup target list | grep -q "^$RUST_TARGET (installed)"; then
	rustup target add "$RUST_TARGET"
fi

export IPHONEOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
if [ -n "${RUSTFLAGS:-}" ]; then
  export RUSTFLAGS="${RUSTFLAGS} -C link-arg=${DEPLOYMENT_FLAG}"
else
  export RUSTFLAGS="-C link-arg=${DEPLOYMENT_FLAG}"
fi
export CARGO_TARGET_DIR

mkdir -p "$CARGO_TARGET_DIR"
cd "$REPO_ROOT/Vendor/idevice/ffi"
cargo build --release --target "$RUST_TARGET" --no-default-features --features full,ring
[ -s "$OUTPUT_LIB" ] || {
	echo "Missing idevice output: $OUTPUT_LIB" >&2
	exit 1
}
