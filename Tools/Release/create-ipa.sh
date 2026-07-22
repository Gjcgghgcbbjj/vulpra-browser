#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ARCHIVE=${1:-$ROOT_DIR/dist/Vulpra.xcarchive}
APP_RELATIVE=Products/Applications/Vulpra.app
OUTPUT_DIR=$ROOT_DIR/dist

"$ROOT_DIR/Tools/Runtime/check-macos-prerequisites.sh"
command -v ldid >/dev/null 2>&1 || { echo "Missing ldid" >&2; exit 1; }
[ -d "$ARCHIVE/$APP_RELATIVE" ] || { echo "Missing archive app: $ARCHIVE/$APP_RELATIVE" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

"$SCRIPT_DIR/package-app.sh" "$ARCHIVE" "$APP_RELATIVE" "$OUTPUT_DIR/.stage-ipa" "$OUTPUT_DIR/Vulpra.ipa"

work=$(mktemp -d "${TMPDIR:-/tmp}/vulpra-tipa.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/Products/Applications"
cp -R "$ARCHIVE/$APP_RELATIVE" "$work/$APP_RELATIVE"
app="$work/$APP_RELATIVE"

"$SCRIPT_DIR/build-ptrace-jit.sh" "$app/ptrace_jit" >/dev/null
ptrace_entitlements="$ROOT_DIR/Modules/VulpraRuntime/JIT/Unsandboxed/ptrace_jit.entitlements"
app_entitlements="$ROOT_DIR/App/Entitlements/Vulpra.private.entitlements"
helper_entitlements="$ROOT_DIR/Extensions/Helper/Entitlements/Vulpra-Helper.private.entitlements"
ldid -S"$ptrace_entitlements" "$app/ptrace_jit"
find "$app/Frameworks" -type f \( -name '*.dylib' -o -name XUL \) -exec ldid -S {} \;
ldid -S "$app/Frameworks/GeckoView.framework/GeckoView"
ldid -S"$helper_entitlements" "$app/PlugIns/Vulpra Helper.appex/Vulpra Helper"
ldid -S "$app/PlugIns/OpenIn.appex/OpenIn"
ldid -S"$app_entitlements" "$app/Vulpra"

"$SCRIPT_DIR/package-app.sh" "$work" "$APP_RELATIVE" "$OUTPUT_DIR/.stage-tipa" "$OUTPUT_DIR/Vulpra-TrollStore.tipa"
echo "Created $OUTPUT_DIR/Vulpra.ipa and $OUTPUT_DIR/Vulpra-TrollStore.tipa"
