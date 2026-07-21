#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
SOURCE_REPO=$ROOT
SOURCE_SHA=HEAD
ALLOWLIST=$ROOT/Tools/Bootstrap/import-allowlist.tsv
TARGET_ROOT=$ROOT
MANIFEST=$ROOT/docs/provenance/import-manifest.tsv

usage() {
    echo "Usage: $0 [--source-repo PATH] [--source-sha SHA] [--allowlist FILE] [--target-root DIR] [--manifest-output FILE]"
    echo "Uses an exclusive lock adjacent to TARGET_ROOT; hostile external target-tree mutation during import is unsupported."
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source-repo|--source-sha|--allowlist|--target-root|--manifest-output)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            option=$1
            value=$2
            shift 2
            case "$option" in
                --source-repo) SOURCE_REPO=$value ;;
                --source-sha) SOURCE_SHA=$value ;;
                --allowlist) ALLOWLIST=$value ;;
                --target-root) TARGET_ROOT=$value ;;
                --manifest-output) MANIFEST=$value ;;
            esac
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

SOURCE_SHA=$(git -C "$SOURCE_REPO" rev-parse --verify "$SOURCE_SHA^{commit}") || {
    echo "Invalid source commit" >&2
    exit 2
}

TARGET_ROOT=$(python3 - "$TARGET_ROOT" <<'PY'
import os
import sys

path = os.path.abspath(sys.argv[1])
if path.startswith("//"):
    path = "/" + path.lstrip("/")
print(path)
PY
)

LOCK=$TARGET_ROOT.import-substrate.lock
if ! mkdir "$LOCK" 2>/dev/null; then
    echo "Importer lock is already held or cannot be created: $LOCK" >&2
    exit 2
fi
STAGE=
cleanup() {
    if [ -n "$STAGE" ] && [ -d "$STAGE" ]; then
        rm -rf "$STAGE"
    fi
    rmdir "$LOCK" 2>/dev/null || :
}
trap cleanup EXIT HUP INT TERM

# Complete preflight happens before creating the target root or staging files.
PLAN_JSON=$(PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT" "$SOURCE_REPO" "$SOURCE_SHA" "$ALLOWLIST" "$TARGET_ROOT" <<'PY'
import importlib.util
import json
import os
import sys

root, source_repo, commit, allowlist, target_root = sys.argv[1:]
module_path = os.path.join(root, "Tools", "Bootstrap", "generate-import-manifest.py")
spec = importlib.util.spec_from_file_location("import_manifest", module_path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
mappings, files = module.build_import_plan(source_repo, commit, allowlist)
module.validate_target_paths(target_root, files, mappings)
print(json.dumps({
    "mappings": [mapping.__dict__ for mapping in mappings],
    "files": [import_file.__dict__ for import_file in files],
}))
PY
) || exit 2

STAGE=$(mktemp -d)
mkdir "$STAGE/source" "$STAGE/payload"
printf '%s\n' "$PLAN_JSON" > "$STAGE/plan.json"

python3 - "$STAGE/plan.json" <<'PY' > "$STAGE/sources"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    plan = json.load(source)
for mapping in plan["mappings"]:
    print(mapping["source"])
PY

while IFS= read -r source_path || [ -n "$source_path" ]; do
    git -C "$SOURCE_REPO" archive "$SOURCE_SHA" -- "$source_path" |
        tar -x -C "$STAGE/source"
done < "$STAGE/sources"

python3 - "$STAGE" <<'PY'
import json
import os
import shutil
import stat
import sys

stage = sys.argv[1]
with open(os.path.join(stage, "plan.json"), encoding="utf-8") as source:
    plan = json.load(source)
for item in plan["files"]:
    source_path = os.path.join(stage, "source", *item["source"].split("/"))
    target_path = os.path.join(stage, "payload", *item["target"].split("/"))
    source_stat = os.lstat(source_path)
    if not stat.S_ISREG(source_stat.st_mode):
        raise SystemExit(f"Archived source is not a regular file: {item['source']}")
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    shutil.copy2(source_path, target_path)
PY

PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT" "$STAGE" "$TARGET_ROOT" "$SOURCE_SHA" "$MANIFEST" <<'PY'
import importlib.util
import json
import os
import sys

root, stage, target_root, commit, manifest = sys.argv[1:]
module_path = os.path.join(root, "Tools", "Bootstrap", "generate-import-manifest.py")
spec = importlib.util.spec_from_file_location("import_manifest", module_path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
with open(os.path.join(stage, "plan.json"), encoding="utf-8") as source:
    plan = json.load(source)
files = [module.ImportFile(**item) for item in plan["files"]]
mappings = [module.Mapping(**item) for item in plan["mappings"]]
module.transactional_publish(
    commit,
    mappings,
    files,
    os.path.join(stage, "payload"),
    target_root,
    manifest,
)
PY
