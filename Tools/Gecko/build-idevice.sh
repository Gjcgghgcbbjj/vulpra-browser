#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SUBMODULE_PATH="$REPO_ROOT/Vendor/idevice"
FFI_DIR="$SUBMODULE_PATH/ffi"
CARGO_TARGET_DIR="$REPO_ROOT/.build/idevice"
DEPLOYMENT_TARGET="15.0"

[ -f "$FFI_DIR/Cargo.toml" ] || {
	echo "Missing idevice source at $FFI_DIR" >&2
	echo "Run Tools/Runtime/build-runtime-substrate.sh on macOS." >&2
	exit 1
}

RUST_TARGET="${1:-aarch64-apple-ios}"
export IPHONEOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
case "$RUST_TARGET" in
	aarch64-apple-ios)
		DEPLOYMENT_FLAG="-miphoneos-version-min=${DEPLOYMENT_TARGET}"
		;;
	aarch64-apple-ios-sim)
		DEPLOYMENT_FLAG="-mios-simulator-version-min=${DEPLOYMENT_TARGET}"
		export IPHONESIMULATOR_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
		;;
	*)
		echo "Unsupported idevice Rust target: $RUST_TARGET" >&2
		exit 64
		;;
esac
OUTPUT_LIB="$CARGO_TARGET_DIR/$RUST_TARGET/release/libidevice_ffi.a"

if ! rustup target list | grep -q "^$RUST_TARGET (installed)"; then
	rustup target add "$RUST_TARGET"
fi

if [ -n "${RUSTFLAGS:-}" ]; then
  export RUSTFLAGS="${RUSTFLAGS} -C link-arg=${DEPLOYMENT_FLAG}"
else
  export RUSTFLAGS="-C link-arg=${DEPLOYMENT_FLAG}"
fi
export CARGO_TARGET_DIR

mkdir -p "$CARGO_TARGET_DIR"
cd "$FFI_DIR"
cargo build --release --target "$RUST_TARGET" --no-default-features --features full,ring
[ -s "$OUTPUT_LIB" ] || {
	echo "Missing idevice output: $OUTPUT_LIB" >&2
	exit 1
}
