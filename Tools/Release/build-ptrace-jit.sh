#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OUTPUT=${1:-$ROOT_DIR/.build/ptrace-jit/ptrace_jit}
SOURCE="$ROOT_DIR/Modules/VulpraRuntime/JIT/Unsandboxed/ptrace_jit.c"

"$ROOT_DIR/Tools/Runtime/check-macos-prerequisites.sh"
mkdir -p "$(dirname "$OUTPUT")"
xcrun --sdk iphoneos clang \
	-arch arm64 \
	-miphoneos-version-min=15.0 \
	-O2 \
	-fvisibility=hidden \
	"$SOURCE" \
	-o "$OUTPUT"
chmod 0755 "$OUTPUT"
[ -s "$OUTPUT" ] || { echo "Missing ptrace_jit output: $OUTPUT" >&2; exit 1; }
printf '%s\n' "$OUTPUT"
