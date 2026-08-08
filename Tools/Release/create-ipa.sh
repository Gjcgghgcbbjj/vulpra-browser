#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ARCHIVE=${1:-$ROOT_DIR/dist/Vulpra.xcarchive}
APP_RELATIVE=Products/Applications/Vulpra.app
OUTPUT_DIR=$ROOT_DIR/dist

command -v ldid >/dev/null 2>&1 || { echo "Missing ldid" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Missing python3" >&2; exit 1; }
[ -d "$ARCHIVE/$APP_RELATIVE" ] || { echo "Missing archive app: $ARCHIVE/$APP_RELATIVE" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

"$SCRIPT_DIR/package-app.sh" "$ARCHIVE" "$APP_RELATIVE" "$OUTPUT_DIR/.stage-ipa" "$OUTPUT_DIR/Vulpra.ipa"

work=$(mktemp -d "${TMPDIR:-/tmp}/vulpra-tipa.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/Products/Applications"
cp -R "$ARCHIVE/$APP_RELATIVE" "$work/$APP_RELATIVE"
app="$work/$APP_RELATIVE"

plutil -replace VulpraDistributionProfile -string trollstore "$app/Info.plist"

app_entitlements="$ROOT_DIR/App/Entitlements/Vulpra.private.entitlements"
process_entitlements="$ROOT_DIR/Engine/VulpraEngineProcess/EngineProcess.private.entitlements"

find "$app/Frameworks" -type f \( -name '*.dylib' -o -name XUL \) -exec ldid -S {} \;
ldid -S "$app/Frameworks/VulpraEngineKit.framework/VulpraEngineKit"
ldid -S"$process_entitlements" "$app/PlugIns/Vulpra Engine Process.appex/Vulpra Engine Process"
# Real-device GPU/Metal contract: the signed appex must carry IOKit user
# clients + no-sandbox (4b2dc58 device feedback: lag, scroll half-beat,
# overheating from swgl software-rendering fallback).
ldid -e "$app/PlugIns/Vulpra Engine Process.appex/Vulpra Engine Process" \
  > "$work/engine-process.entitlements.plist"
python3 - "$work/engine-process.entitlements.plist" <<'PY_ENT'
import plistlib
import sys

with open(sys.argv[1], "rb") as source:
    ent = plistlib.load(source)
required = ["IOSurfaceRootUserClient", "AGXDeviceUserClient",
            "AGXSharedUserClient", "AGXCommandQueue", "AGXDevice"]
if ent.get("com.apple.private.security.no-sandbox") is not True:
    raise SystemExit("FAIL: signed appex missing com.apple.private.security.no-sandbox")
iokit = ent.get("com.apple.security.iokit-user-client-class")
if iokit != required:
    raise SystemExit(f"FAIL: signed appex iokit-user-client-class mismatch: {iokit}")
PY_ENT
ldid -S "$app/PlugIns/OpenIn.appex/OpenIn"
ldid -S"$app_entitlements" "$app/Vulpra"

"$SCRIPT_DIR/package-app.sh" "$work" "$APP_RELATIVE" "$OUTPUT_DIR/.stage-tipa" "$OUTPUT_DIR/Vulpra-TrollStore.tipa"
python3 "$ROOT_DIR/Tools/Engine/validate-ipa.py" "$OUTPUT_DIR/Vulpra.ipa"
python3 "$ROOT_DIR/Tools/Engine/validate-ipa.py" --require-signatures "$OUTPUT_DIR/Vulpra-TrollStore.tipa"
echo "Created $OUTPUT_DIR/Vulpra.ipa and $OUTPUT_DIR/Vulpra-TrollStore.tipa"
