#!/bin/sh
set -eu

[ "$#" -eq 4 ] || {
	echo "Usage: package-app.sh <archive> <app-relative-path> <stage-dir> <output.ipa|output.tipa>" >&2
	exit 64
}
ARCHIVE=$1
APP_RELATIVE=$2
STAGE=$3
OUTPUT=$4
APP="$ARCHIVE/$APP_RELATIVE"

python3 - "$APP" <<'PY'
from pathlib import Path
import plistlib
import sys

app = Path(sys.argv[1])
expected = {
    app: "com.vulpra.browser",
    app / "Frameworks/VulpraEngineKit.framework": "com.vulpra.browser.engine-kit",
    app / "PlugIns/Vulpra Engine Process.appex": "com.vulpra.browser.engine-process",
    app / "PlugIns/OpenIn.appex": "com.vulpra.browser.open-in",
}
for bundle, bundle_id in expected.items():
    if not bundle.is_dir():
        raise SystemExit(f"Missing packaged product: {bundle}")
    marker = bundle / ".vulpra-bundle-id"
    plist = bundle / "Info.plist"
    if marker.is_file():
        actual = marker.read_text().strip()
    elif plist.is_file():
        with plist.open("rb") as source:
            actual = plistlib.load(source).get("CFBundleIdentifier")
    else:
        raise SystemExit(f"Missing bundle identity marker: {bundle}")
    if actual != bundle_id:
        raise SystemExit(f"Bundle identity mismatch for {bundle}: {actual}")

frameworks = app / "Frameworks"
engine_kit = frameworks / "VulpraEngineKit.framework"
engine_runtime = frameworks / "VulpraEngineRuntime"
if not (frameworks / "XUL").is_file():
    raise SystemExit(f"Missing packaged runtime: {app / 'Frameworks/XUL'}")
if not any(frameworks.glob("*.dylib")):
    raise SystemExit(f"Missing packaged runtime: {app / 'Frameworks/*.dylib'}")
if not (engine_runtime / "Frameworks/application.ini").is_file():
    raise SystemExit(f"Missing packaged resources: {engine_runtime / 'Frameworks/application.ini'}")
if not any((engine_runtime / "Licenses").glob("*")):
    raise SystemExit(f"Missing packaged licenses: {engine_runtime / 'Licenses'}")

framework_bundles = {path.name for path in frameworks.glob("*.framework")}
if framework_bundles != {"VulpraEngineKit.framework"}:
    raise SystemExit(f"Unexpected embedded framework set: {sorted(framework_bundles)}")
plugin_bundles = {path.name for path in (app / "PlugIns").glob("*.appex")}
if plugin_bundles != {"Vulpra Engine Process.appex", "OpenIn.appex"}:
    raise SystemExit(f"Unexpected app extension set: {sorted(plugin_bundles)}")
unexpected_root_executables = [
    path.name for path in app.iterdir()
    if path.is_file() and path.name != "Vulpra" and path.stat().st_mode & 0o111
]
if unexpected_root_executables:
    raise SystemExit(f"Unexpected app executable set: {sorted(unexpected_root_executables)}")
PY

python3 - "$STAGE" <<'PY'
from pathlib import Path
import shutil, sys
stage = Path(sys.argv[1])
if stage.exists():
    shutil.rmtree(stage)
(stage / "Payload").mkdir(parents=True)
PY
cp -R "$APP" "$STAGE/Payload/Vulpra.app"
mkdir -p "$(dirname "$OUTPUT")"

python3 - "$STAGE" "$OUTPUT" <<'PY'
from pathlib import Path
import stat, sys, zipfile
stage, output = map(Path, sys.argv[1:])
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(p for p in stage.rglob("*") if p.is_file()):
        info = zipfile.ZipInfo(path.relative_to(stage).as_posix(), (1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (stat.S_IMODE(path.stat().st_mode) & 0xFFFF) << 16
        archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
PY

output_dir=$(CDPATH= cd -- "$(dirname "$OUTPUT")" && pwd)
manifest="$output_dir/SHA256SUMS"
for package in "$output_dir"/*.ipa "$output_dir"/*.tipa; do
	[ -f "$package" ] || continue
	hash=$(shasum -a 256 "$package" | awk '{print $1}')
	printf '%s  %s\n' "$hash" "$(basename "$package")"
done | LC_ALL=C sort > "$manifest"
[ -s "$OUTPUT" ] || { echo "Package was not created: $OUTPUT" >&2; exit 1; }
