#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
command -v xcodebuild >/dev/null 2>&1 || { echo "Missing xcodebuild" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Missing python3" >&2; exit 1; }
python3 "$ROOT_DIR/Tools/Build/generate-build-identity.py" --check
python3 "$ROOT_DIR/Tools/Engine/verify-engine-artifact.py" \
	--contract "$ROOT_DIR/Configuration/engine-artifact-device-v5.json" \
	"${VULPRA_ENGINE_ROOT:-$ROOT_DIR/.build/engine}"
mkdir -p "$ROOT_DIR/dist"

xcodebuild \
	-project "$ROOT_DIR/Vulpra.xcodeproj" \
	-scheme Vulpra \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-archivePath "$ROOT_DIR/dist/Vulpra.xcarchive" \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	${VULPRA_SWIFT_FLAGS:+SWIFT_ACTIVE_COMPILATION_CONDITIONS="$VULPRA_SWIFT_FLAGS"} \
	archive
