#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

"$SCRIPT_DIR/check-macos-prerequisites.sh"
cd "$ROOT_DIR"

"$ROOT_DIR/Tools/Gecko/update-gecko.sh"
git submodule update --init --depth 1 Vendor/idevice
"$ROOT_DIR/Tools/Gecko/apply-patches.sh"
"$ROOT_DIR/Tools/Gecko/build-idevice.sh"
"$ROOT_DIR/Tools/Gecko/build-gecko.sh"

developer_dir=$(xcode-select -p)
xcode_app=$(basename "$(dirname "$(dirname "$developer_dir")")")
VULPRA_XCODE_BUILD=$(xcodebuild -version | awk '/Build version/ {print $3}')
VULPRA_SDK_BUILD=$(xcrun --sdk iphoneos --show-sdk-build-version)
export VULPRA_XCODE_BUILD VULPRA_SDK_BUILD
artifact=${VULPRA_GECKO_ARTIFACT:-$ROOT_DIR/dist/gecko-runtime-v3.tar.gz}

"$ROOT_DIR/Tools/Gecko/gecko-artifact.sh" pack "$artifact" "$xcode_app"
"$SCRIPT_DIR/verify-runtime-artifacts.sh"

printf 'runtime-substrate-built artifact=%s xcode_build=%s sdk_build=%s\n' \
	"$artifact" "$VULPRA_XCODE_BUILD" "$VULPRA_SDK_BUILD"
