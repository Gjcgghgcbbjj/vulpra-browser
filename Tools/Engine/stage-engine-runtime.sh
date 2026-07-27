#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ENGINE_ROOT=${VULPRA_ENGINE_ROOT:-$ROOT/.build/engine}
APP_BUNDLE=${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}
FRAMEWORKS=$APP_BUNDLE/Frameworks
ENGINE_FRAMEWORK=$FRAMEWORKS/VulpraEngineKit.framework
ENGINE_RUNTIME=$FRAMEWORKS/VulpraEngineRuntime

python3 "$ROOT/Tools/Engine/verify-engine-artifact.py" \
  --contract "${VULPRA_ENGINE_CONTRACT:-$ROOT/Configuration/engine-artifact-v4.json}" "$ENGINE_ROOT"
test -d "$ENGINE_FRAMEWORK"
mkdir -p "$FRAMEWORKS" "$ENGINE_RUNTIME/Frameworks" "$ENGINE_RUNTIME/Licenses"
cp -fL "$ENGINE_ROOT/runtime/bin/XUL" "$FRAMEWORKS/XUL"
find "$ENGINE_ROOT/runtime/lib" -maxdepth 1 -type f -name '*.dylib' -exec cp -fL {} "$FRAMEWORKS/" \;
rsync -a --delete "$ENGINE_ROOT/runtime/resources/" "$ENGINE_RUNTIME/Frameworks/"
rsync -a --delete "$ENGINE_ROOT/licenses/" "$ENGINE_RUNTIME/Licenses/"

if [ "${CODE_SIGNING_ALLOWED:-YES}" != NO ]; then
  identity=${EXPANDED_CODE_SIGN_IDENTITY:-${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}}
  test -n "$identity"
  find "$FRAMEWORKS" -maxdepth 1 -type f \( -name XUL -o -name '*.dylib' \) \
    -exec codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements {} \;
  codesign --force --sign "$identity" "$ENGINE_FRAMEWORK"
else
  find "$FRAMEWORKS" -maxdepth 1 -type f \( -name XUL -o -name '*.dylib' \) \
    -exec codesign --force --sign - {} \;
fi
