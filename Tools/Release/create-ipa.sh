#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ARCHIVE=${1:-$ROOT_DIR/dist/Vulpra.xcarchive}
APP_RELATIVE=Products/Applications/Vulpra.app
OUTPUT_DIR=$ROOT_DIR/dist

"$ROOT_DIR/Tools/Runtime/check-macos-prerequisites.sh"
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

# Pin canonical bundle identities into the tipa (working TrollStore baseline).
# Use Python plistlib to set CFBundleIdentifier and .vulpra-bundle-id markers.
python3 - "$app" <<'PY'
from pathlib import Path
import plistlib
import sys

app = Path(sys.argv[1])
identities = {
    app: "com.vulpra.browser",
    app / "Frameworks/GeckoView.framework": "com.vulpra.browser.geckoview",
    app / "PlugIns/Vulpra Helper.appex": "com.vulpra.browser.helper",
    app / "PlugIns/OpenIn.appex": "com.vulpra.browser.open-in",
}
for bundle, bundle_id in identities.items():
    if not bundle.is_dir():
        raise SystemExit(f"Missing bundle for identity pin: {bundle}")
    plist_path = bundle / "Info.plist"
    if plist_path.is_file():
        with plist_path.open("rb") as source:
            value = plistlib.load(source)
        value["CFBundleIdentifier"] = bundle_id
        with plist_path.open("wb") as sink:
            plistlib.dump(value, sink, sort_keys=False)
    (bundle / ".vulpra-bundle-id").write_text(bundle_id + "\n", encoding="utf-8")
PY

"$SCRIPT_DIR/build-ptrace-jit.sh" "$app/ptrace_jit" >/dev/null
ptrace_entitlements="$ROOT_DIR/Modules/VulpraRuntime/JIT/Unsandboxed/ptrace_jit.entitlements"
app_entitlements="$ROOT_DIR/App/Entitlements/Vulpra.private.entitlements"
helper_entitlements="$ROOT_DIR/Extensions/Helper/Entitlements/Vulpra-Helper.private.entitlements"

# Sign order matches Reynard create-ipa.sh: ptrace helper, frameworks, plugins, main.
ldid -S"$ptrace_entitlements" "$app/ptrace_jit"
find "$app/Frameworks" -type f \( -name '*.dylib' -o -name XUL \) -exec ldid -S {} \;
ldid -S "$app/Frameworks/GeckoView.framework/GeckoView"
ldid -S"$helper_entitlements" "$app/PlugIns/Vulpra Helper.appex/Vulpra Helper"
ldid -S "$app/PlugIns/OpenIn.appex/OpenIn"
ldid -S"$app_entitlements" "$app/Vulpra"

"$SCRIPT_DIR/package-app.sh" "$work" "$APP_RELATIVE" "$OUTPUT_DIR/.stage-tipa" "$OUTPUT_DIR/Vulpra-TrollStore.tipa"
echo "Created $OUTPUT_DIR/Vulpra.ipa and $OUTPUT_DIR/Vulpra-TrollStore.tipa"
