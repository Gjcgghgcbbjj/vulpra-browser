#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
"$ROOT_DIR/Tools/Runtime/check-macos-prerequisites.sh"
"$ROOT_DIR/Tools/Runtime/verify-runtime-artifacts.sh"
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
