#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <device-artifact> <simulator-artifact>" >&2
  exit 2
fi

SOURCE=$1
OUTPUT=$2
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
VTOOL=${VULPRA_VTOOL:-xcrun vtool}
SDK_VERSION=${VULPRA_SIMULATOR_SDK_VERSION:-}

[[ -d "$SOURCE" ]] || { echo "missing device artifact: $SOURCE" >&2; exit 1; }
[[ ! -e "$OUTPUT" ]] || { echo "output already exists: $OUTPUT" >&2; exit 1; }

python3 "$ROOT/Tools/Engine/verify-engine-artifact.py" \
  --contract "$ROOT/Configuration/engine-artifact-v4.json" "$SOURCE"
if [[ -z "$SDK_VERSION" ]]; then
  SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
fi

cp -a "$SOURCE" "$OUTPUT"
for binary in "$OUTPUT/runtime/bin/XUL" "$OUTPUT"/runtime/lib/*.dylib; do
  # shellcheck disable=SC2086
  $VTOOL -arch arm64 \
    -set-build-version iossim 15.0 "$SDK_VERSION" \
    -replace -output "$binary.simulator" "$binary"
  mv "$binary.simulator" "$binary"
done

python3 - "$OUTPUT" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
path = root / "manifest.json"
manifest = json.loads(path.read_text(encoding="utf-8"))
manifest["build"]["platform"] = "iphonesimulator"
for entry in manifest["files"]:
    content = (root / entry["path"]).read_bytes()
    entry["size"] = len(content)
    entry["sha256"] = hashlib.sha256(content).hexdigest()
identity = copy.deepcopy(manifest)
identity["artifactId"] = ""
canonical = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
manifest["artifactId"] = (
    "vulpra-gecko-ios-simulator-arm64-v4-" + hashlib.sha256(canonical).hexdigest()
)
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(manifest["artifactId"])
PY

python3 "$ROOT/Tools/Engine/verify-engine-artifact.py" \
  --contract "$ROOT/Configuration/engine-artifact-simulator-v4.json" "$OUTPUT"
