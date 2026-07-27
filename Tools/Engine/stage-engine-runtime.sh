#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ENGINE_ROOT=${VULPRA_ENGINE_ROOT:-$ROOT/.build/engine}
APP_BUNDLE=${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}
FRAMEWORKS=$APP_BUNDLE/Frameworks
ENGINE_FRAMEWORK=$FRAMEWORKS/VulpraEngineKit.framework
CONTRACT=${VULPRA_ENGINE_CONTRACT:-$ROOT/Configuration/engine-artifact-v4.json}

python3 "$ROOT/Tools/Engine/verify-engine-artifact.py" \
  --contract "$CONTRACT" "$ENGINE_ROOT"
RESOURCE_CONTAINER=$(python3 - "$CONTRACT" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["runtimeResourceContainer"])
PY
)
KERNEL_INSTALL_PATH=$(python3 - "$CONTRACT" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["runtimeKernelInstallPath"])
PY
)
ENGINE_RUNTIME=$FRAMEWORKS/$RESOURCE_CONTAINER
ENGINE_KERNEL=$FRAMEWORKS/$KERNEL_INSTALL_PATH
ENGINE_BINARY=$ENGINE_FRAMEWORK/VulpraEngineKit
KERNEL_LINK_PATH=@rpath/$KERNEL_INSTALL_PATH

test -d "$ENGINE_FRAMEWORK"
python3 - "$ENGINE_RUNTIME" "$ENGINE_KERNEL" "$FRAMEWORKS/XUL" <<'PY'
from pathlib import Path
import sys

runtime = Path(sys.argv[1])
kernel = Path(sys.argv[2])
legacy_kernel = Path(sys.argv[3])
if runtime.is_symlink():
    runtime.unlink()
if legacy_kernel != kernel and (legacy_kernel.is_file() or legacy_kernel.is_symlink()):
    legacy_kernel.unlink()
PY
mkdir -p "$FRAMEWORKS" "$ENGINE_RUNTIME/Frameworks" "$ENGINE_RUNTIME/Licenses" "$(dirname "$ENGINE_KERNEL")"
python3 - "$CONTRACT" "$ENGINE_RUNTIME/Info.plist" "$ENGINE_KERNEL" <<'PY'
import json
import os
from pathlib import Path
import plistlib
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
bundle_identifier = contract.get("runtimeResourceBundleIdentifier")
if bundle_identifier:
    info = {
        "CFBundleExecutable": Path(sys.argv[3]).name,
        "CFBundleIdentifier": bundle_identifier,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "VulpraSimulatorEngineRuntime",
        "CFBundlePackageType": "FMWK",
        "CFBundleShortVersionString": "4.0",
        "CFBundleSupportedPlatforms": ["iPhoneSimulator"],
        "CFBundleVersion": "4",
        "MinimumOSVersion": os.environ.get("IPHONEOS_DEPLOYMENT_TARGET", "15.0"),
    }
    with open(sys.argv[2], "wb") as sink:
        plistlib.dump(info, sink)
PY
cp -fL "$ENGINE_ROOT/runtime/bin/XUL" "$ENGINE_KERNEL"
if [ "$KERNEL_LINK_PATH" != "@rpath/XUL" ]; then
  if ! otool -D "$ENGINE_KERNEL" | tail -n +2 | grep -Fxq "$KERNEL_LINK_PATH"; then
    install_name_tool -id "$KERNEL_LINK_PATH" "$ENGINE_KERNEL"
  fi
  otool -L "$ENGINE_BINARY" | grep -Fq "$KERNEL_LINK_PATH ("
fi
find "$ENGINE_ROOT/runtime/lib" -maxdepth 1 -type f -name '*.dylib' -exec cp -fL {} "$FRAMEWORKS/" \;
rsync -a --delete "$ENGINE_ROOT/runtime/resources/" "$ENGINE_RUNTIME/Frameworks/"
rsync -a --delete "$ENGINE_ROOT/licenses/" "$ENGINE_RUNTIME/Licenses/"

if [ "${CODE_SIGNING_ALLOWED:-YES}" != NO ]; then
  identity=${EXPANDED_CODE_SIGN_IDENTITY:-${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}}
  test -n "$identity"
  find "$FRAMEWORKS" -maxdepth 1 -type f -name '*.dylib' \
    -exec codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements {} \;
  codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements "$ENGINE_KERNEL"
  codesign --force --sign "$identity" "$ENGINE_FRAMEWORK"
else
  find "$FRAMEWORKS" -maxdepth 1 -type f -name '*.dylib' \
    -exec codesign --force --sign - {} \;
  codesign --force --sign - "$ENGINE_KERNEL"
fi
