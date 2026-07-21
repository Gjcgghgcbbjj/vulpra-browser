#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
XCODE_APP=${1:-}
[ -n "$XCODE_APP" ] || { echo "Usage: runtime-substrate-key.sh <Xcode.app>" >&2; exit 64; }

VULPRA_XCODE_BUILD=${VULPRA_XCODE_BUILD:-$(xcodebuild -version | awk '/Build version/ {print $3}')}
VULPRA_SDK_BUILD=${VULPRA_SDK_BUILD:-$(xcrun --sdk iphoneos --show-sdk-build-version)}
export VULPRA_XCODE_BUILD VULPRA_SDK_BUILD

gecko_key=$($ROOT_DIR/Tools/Gecko/gecko-artifact.sh key "$XCODE_APP")
firefox_commit=$(git -C "$ROOT_DIR" rev-parse HEAD:Vendor/firefox)
idevice_commit=$(git -C "$ROOT_DIR" rev-parse HEAD:Vendor/idevice)
digest=$({
    printf 'gecko=%s\n' "$gecko_key"
    printf 'firefox=%s\n' "$firefox_commit"
    printf 'idevice=%s\n' "$idevice_commit"
    cd "$ROOT_DIR"
    find Patches -type f -name '*.patch' -print0 | sort -z | xargs -0 shasum -a 256
    shasum -a 256 Tools/Gecko/build-idevice.sh Tools/Runtime/build-runtime-substrate.sh
} | shasum -a 256 | awk '{print $1}')
printf 'vulpra-runtime-substrate-v1-%s\n' "$digest"
