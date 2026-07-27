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
ENGINE_RUNTIME=$FRAMEWORKS/$RESOURCE_CONTAINER

test -d "$ENGINE_FRAMEWORK"
mkdir -p "$FRAMEWORKS" "$ENGINE_RUNTIME/Frameworks" "$ENGINE_RUNTIME/Licenses"
cp -fL "$ENGINE_ROOT/runtime/bin/XUL" "$FRAMEWORKS/XUL"
find "$ENGINE_ROOT/runtime/lib" -maxdepth 1 -type f -name '*.dylib' -exec cp -fL {} "$FRAMEWORKS/" \;
rsync -a --delete "$ENGINE_ROOT/runtime/resources/" "$ENGINE_RUNTIME/Frameworks/"
rsync -a --delete "$ENGINE_ROOT/licenses/" "$ENGINE_RUNTIME/Licenses/"
python3 - "$CONTRACT" "$FRAMEWORKS" "$RESOURCE_CONTAINER" <<'PY'
import json
from pathlib import Path
import shutil
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
resource_alias = contract.get("runtimeResourceAlias")
if resource_alias:
    frameworks = Path(sys.argv[2])
    resource_container = Path(sys.argv[3])
    alias_path = frameworks / resource_alias
    if alias_path.is_symlink() or alias_path.is_file():
        alias_path.unlink()
    elif alias_path.exists():
        shutil.rmtree(alias_path)
    alias_path.symlink_to(resource_container)
PY

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
