#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CONTRACT=${VULPRA_ENGINE_CONTRACT:-$ROOT/Configuration/engine-artifact-v4.json}
ENGINE_BINARY=${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}/VulpraEngineKit

KERNEL_INSTALL_PATH=$(python3 - "$CONTRACT" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["runtimeKernelInstallPath"])
PY
)
KERNEL_LINK_PATH=@rpath/$KERNEL_INSTALL_PATH

test -f "$ENGINE_BINARY"
if [ "$KERNEL_LINK_PATH" != "@rpath/XUL" ]; then
  if otool -L "$ENGINE_BINARY" | grep -Fq "@rpath/XUL ("; then
    install_name_tool -change "@rpath/XUL" "$KERNEL_LINK_PATH" "$ENGINE_BINARY"
  fi
fi
otool -L "$ENGINE_BINARY" | grep -Fq "$KERNEL_LINK_PATH ("
