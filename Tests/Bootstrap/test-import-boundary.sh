#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

PROVENANCE=$ROOT/docs/provenance/substrate-boundary.md
[ -f "$PROVENANCE" ] || {
	echo 'FAIL: missing provenance file: docs/provenance/substrate-boundary.md' >&2
	exit 1
}
grep -q '^## Imported$' "$PROVENANCE"
grep -q '^## Excluded$' "$PROVENANCE"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import csv
import sys

root = Path(sys.argv[1])
approved = {"Vendor", "Patches", "Tools", "Extensions", "Modules"}
with (root / "docs/provenance/import-manifest.tsv").open(
    newline="", encoding="utf-8"
) as source:
    rows = list(csv.DictReader(source, delimiter="\t"))

top_levels = {row["target_path"].split("/", 1)[0] for row in rows}
unexpected = top_levels - approved
if unexpected:
    raise SystemExit(
        "FAIL: unapproved manifest top-level paths: " + ", ".join(sorted(unexpected))
    )
if top_levels != approved:
    missing = approved - top_levels
    raise SystemExit(
        "FAIL: approved manifest groups missing: " + ", ".join(sorted(missing))
    )
PY

SRC=$TMP/source
mkdir -p "$SRC/single" "$SRC/tree/sub" "$SRC/browser/Reynard/Client"
git -C "$SRC" init -q
git -C "$SRC" config user.email test@example.com
git -C "$SRC" config user.name Test
printf 'single payload\n' > "$SRC/single/file.txt"
printf 'tree a\n' > "$SRC/tree/a.txt"
printf 'tree b\n' > "$SRC/tree/sub/b.txt"
printf 'must not leak\n' > "$SRC/browser/Reynard/Client/leak.swift"
python3 - "$SRC" <<'PY'
import os
import sys

root = os.fsencode(sys.argv[1])
fixtures = (
    (b"tabtree/bad\tname.txt", b"tab\n"),
    (b"newlinetree/bad\nname.txt", b"newline\n"),
    (b"bytetree/bad-\xff.txt", b"non-utf8\n"),
)
for relative, content in fixtures:
    path = root + b"/" + relative
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as output:
        output.write(content)
unicode_path = os.path.join(sys.argv[1], "unicodetree", "数据.txt")
os.makedirs(os.path.dirname(unicode_path), exist_ok=True)
with open(unicode_path, "w", encoding="utf-8") as output:
    output.write("unicode payload\n")
PY
git -C "$SRC" add .
git -C "$SRC" commit -qm initial
SHA=$(git -C "$SRC" rev-parse HEAD)
SINGLE_HASH=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$SRC/single/file.txt")
TREE_A_HASH=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$SRC/tree/a.txt")
TREE_B_HASH=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$SRC/tree/sub/b.txt")
UNICODE_HASH=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$SRC/unicodetree/数据.txt")
IMPORTER=$ROOT/Tools/Bootstrap/import-substrate.sh
GENERATOR=$ROOT/Tools/Bootstrap/generate-import-manifest.py

run_import() {
    allowlist=$1
    target=$2
    manifest=$3
    ref=${4:-$SHA}
    "$IMPORTER" \
        --source-repo "$SRC" \
        --source-sha "$ref" \
        --allowlist "$allowlist" \
        --target-root "$target" \
        --manifest-output "$manifest"
}

expect_rejected() {
    allowlist=$1
    target=$2
    manifest=$3
    if run_import "$allowlist" "$target" "$manifest" >"$TMP/rejected.out" 2>"$TMP/rejected.err"; then
        echo "unsafe import unexpectedly succeeded: $allowlist" >&2
        exit 1
    fi
}

# A single-file mapping imports the committed blob and records its exact hash.
SINGLE_ALLOW=$TMP/single.tsv
SINGLE_TARGET=$TMP/single-target
SINGLE_MANIFEST=$TMP/single-manifest.tsv
printf 'single/file.txt\tImported/file.txt\n' > "$SINGLE_ALLOW"
printf 'dirty working tree\n' > "$SRC/single/file.txt"
run_import "$SINGLE_ALLOW" "$SINGLE_TARGET" "$SINGLE_MANIFEST" HEAD
grep -qx 'single payload' "$SINGLE_TARGET/Imported/file.txt"
printf 'source_commit\tsource_path\ttarget_path\tsha256\n%s\tsingle/file.txt\tImported/file.txt\t%s\n' \
    "$SHA" "$SINGLE_HASH" > "$TMP/expected-single.tsv"
cmp "$TMP/expected-single.tsv" "$SINGLE_MANIFEST"

# HEAD is canonicalized to a full OID and reruns produce an identical manifest.
awk -F '\t' -v sha="$SHA" 'NR == 2 && $1 == sha { found=1 } END { exit !found }' "$SINGLE_MANIFEST"
cp "$SINGLE_MANIFEST" "$TMP/first-single-manifest.tsv"
printf 'dirty again\n' > "$SRC/single/file.txt"
run_import "$SINGLE_ALLOW" "$SINGLE_TARGET" "$SINGLE_MANIFEST" HEAD
cmp "$TMP/first-single-manifest.tsv" "$SINGLE_MANIFEST"

# A tree mapping expands to exact source/target rows sorted by target path.
TREE_ALLOW=$TMP/tree.tsv
TREE_TARGET=$TMP/tree-target
TREE_MANIFEST=$TMP/tree-manifest.tsv
printf 'tree\tMapped\n' > "$TREE_ALLOW"
run_import "$TREE_ALLOW" "$TREE_TARGET" "$TREE_MANIFEST"
printf 'source_commit\tsource_path\ttarget_path\tsha256\n%s\ttree/a.txt\tMapped/a.txt\t%s\n%s\ttree/sub/b.txt\tMapped/sub/b.txt\t%s\n' \
    "$SHA" "$TREE_A_HASH" "$SHA" "$TREE_B_HASH" > "$TMP/expected-tree.tsv"
cmp "$TMP/expected-tree.tsv" "$TREE_MANIFEST"

# Tree replacement never merges stale files from an earlier target tree.
printf 'stale\n' > "$TREE_TARGET/Mapped/stale.txt"
run_import "$TREE_ALLOW" "$TREE_TARGET" "$TREE_MANIFEST"
[ ! -e "$TREE_TARGET/Mapped/stale.txt" ]
! grep -q 'stale.txt' "$TREE_MANIFEST"
cmp "$TMP/expected-tree.tsv" "$TREE_MANIFEST"

# A stale regular file at the exact mapped tree root is replaced by the tree.
rm -rf "$TREE_TARGET/Mapped"
printf 'stale mapped root\n' > "$TREE_TARGET/Mapped"
run_import "$TREE_ALLOW" "$TREE_TARGET" "$TREE_MANIFEST"
[ -d "$TREE_TARGET/Mapped" ]
grep -qx 'tree a' "$TREE_TARGET/Mapped/a.txt"
grep -qx 'tree b' "$TREE_TARGET/Mapped/sub/b.txt"
cmp "$TMP/expected-tree.tsv" "$TREE_MANIFEST"

# A single-file mapping replaces an existing directory at its exact target.
rm -rf "$SINGLE_TARGET/Imported/file.txt"
mkdir "$SINGLE_TARGET/Imported/file.txt"
printf 'stale child\n' > "$SINGLE_TARGET/Imported/file.txt/stale.txt"
run_import "$SINGLE_ALLOW" "$SINGLE_TARGET" "$SINGLE_MANIFEST"
[ -f "$SINGLE_TARGET/Imported/file.txt" ]
grep -qx 'single payload' "$SINGLE_TARGET/Imported/file.txt"
cmp "$TMP/expected-single.tsv" "$SINGLE_MANIFEST"

# Valid UTF-8 Unicode names import and manifest exactly.
UNICODE_ALLOW=$TMP/unicode.tsv
UNICODE_TARGET=$TMP/unicode-target
UNICODE_MANIFEST=$TMP/unicode-manifest.tsv
printf 'unicodetree\tUnicode\n' > "$UNICODE_ALLOW"
run_import "$UNICODE_ALLOW" "$UNICODE_TARGET" "$UNICODE_MANIFEST"
grep -qx 'unicode payload' "$UNICODE_TARGET/Unicode/数据.txt"
printf 'source_commit\tsource_path\ttarget_path\tsha256\n%s\tunicodetree/数据.txt\tUnicode/数据.txt\t%s\n' \
    "$SHA" "$UNICODE_HASH" > "$TMP/expected-unicode.tsv"
cmp "$TMP/expected-unicode.tsv" "$UNICODE_MANIFEST"

# Invalid manifest destinations fail before any mapped target mutation.
printf 'old target payload\n' > "$SINGLE_TARGET/Imported/file.txt"
cp "$SINGLE_MANIFEST" "$TMP/manifest-before-invalid-destination.tsv"
INVALID_MANIFEST=$TMP/invalid-manifest-destination
mkdir "$INVALID_MANIFEST"
if run_import "$SINGLE_ALLOW" "$SINGLE_TARGET" "$INVALID_MANIFEST" >"$TMP/invalid-manifest.out" 2>"$TMP/invalid-manifest.err"; then
    echo 'directory manifest destination unexpectedly succeeded' >&2
    exit 1
fi
grep -qx 'old target payload' "$SINGLE_TARGET/Imported/file.txt"
cmp "$TMP/manifest-before-invalid-destination.tsv" "$SINGLE_MANIFEST"

# A deterministic mid-publish failure restores old targets and old manifest.
printf 'old tree a\n' > "$TREE_TARGET/Mapped/a.txt"
printf 'old tree b\n' > "$TREE_TARGET/Mapped/sub/b.txt"
cp "$TREE_MANIFEST" "$TMP/manifest-before-rollback.tsv"
if VULPRA_IMPORT_TEST_FAIL_AFTER_PUBLISH=1 run_import "$TREE_ALLOW" "$TREE_TARGET" "$TREE_MANIFEST" >"$TMP/rollback.out" 2>"$TMP/rollback.err"; then
    echo 'injected publish failure unexpectedly succeeded' >&2
    exit 1
fi
grep -qx 'old tree a' "$TREE_TARGET/Mapped/a.txt"
grep -qx 'old tree b' "$TREE_TARGET/Mapped/sub/b.txt"
cmp "$TMP/manifest-before-rollback.tsv" "$TREE_MANIFEST"

# An existing importer lock rejects a second writer without target changes.
mkdir "$TREE_TARGET.import-substrate.lock"
expect_rejected "$TREE_ALLOW" "$TREE_TARGET" "$TREE_MANIFEST"
rmdir "$TREE_TARGET.import-substrate.lock"
grep -qx 'old tree a' "$TREE_TARGET/Mapped/a.txt"
run_import "$TREE_ALLOW" "$TREE_TARGET" "$TREE_MANIFEST"

# A manifest at or below a literal mapped root is rejected before mutation.
EMBEDDED_MANIFEST=$TREE_TARGET/Mapped/provenance.tsv
printf 'old embedded manifest\n' > "$EMBEDDED_MANIFEST"
cp "$TREE_TARGET/Mapped/a.txt" "$TMP/tree-before-manifest-overlap.txt"
if run_import "$TREE_ALLOW" "$TREE_TARGET" "$EMBEDDED_MANIFEST" >"$TMP/manifest-overlap.out" 2>"$TMP/manifest-overlap.err"; then
    echo 'manifest inside mapped root unexpectedly succeeded' >&2
    exit 1
fi
grep -q 'Manifest path overlaps mapped target root' "$TMP/manifest-overlap.err"
cmp "$TMP/tree-before-manifest-overlap.txt" "$TREE_TARGET/Mapped/a.txt"
grep -qx 'old embedded manifest' "$EMBEDDED_MANIFEST"

# Equivalent target-root spellings contend on the same canonical lock.
LOCK_TARGET=$TMP/equivalent-lock-target
mkdir "$LOCK_TARGET"
printf 'unchanged\n' > "$LOCK_TARGET/marker.txt"
mkdir "$LOCK_TARGET.import-substrate.lock"
if run_import "$SINGLE_ALLOW" "$LOCK_TARGET/" "$TMP/lock-trailing-manifest.tsv" >"$TMP/lock-trailing.out" 2>"$TMP/lock-trailing.err"; then
    echo 'trailing-slash target bypassed canonical importer lock' >&2
    exit 1
fi
if run_import "$SINGLE_ALLOW" "$TMP/./equivalent-lock-target" "$TMP/lock-dot-manifest.tsv" >"$TMP/lock-dot.out" 2>"$TMP/lock-dot.err"; then
    echo 'dot-component target bypassed canonical importer lock' >&2
    exit 1
fi
if (
    cd "$TMP"
    "$IMPORTER" \
        --source-repo "$SRC" \
        --source-sha "$SHA" \
        --allowlist "$SINGLE_ALLOW" \
        --target-root equivalent-lock-target \
        --manifest-output "$TMP/lock-relative-manifest.tsv"
) >"$TMP/lock-relative.out" 2>"$TMP/lock-relative.err"; then
    echo 'relative target bypassed canonical importer lock' >&2
    exit 1
fi
rmdir "$LOCK_TARGET.import-substrate.lock"
grep -qx 'unchanged' "$LOCK_TARGET/marker.txt"
[ ! -e "$LOCK_TARGET/Imported/file.txt" ]
[ ! -e "$TMP/lock-trailing-manifest.tsv" ]
[ ! -e "$TMP/lock-dot-manifest.tsv" ]
[ ! -e "$TMP/lock-relative-manifest.tsv" ]

# Unsafe expanded Git filenames are rejected before target writes.
for unsafe_tree in tabtree newlinetree bytetree; do
    unsafe_allow=$TMP/$unsafe_tree.tsv
    unsafe_target=$TMP/$unsafe_tree-target
    printf '%s\tUnsafe\n' "$unsafe_tree" > "$unsafe_allow"
    expect_rejected "$unsafe_allow" "$unsafe_target" "$TMP/$unsafe_tree-manifest.tsv"
    [ ! -e "$unsafe_target" ]
done

# Source and target traversal are rejected before target writes.
BAD_SOURCE=$TMP/bad-source.tsv
printf '../single/file.txt\tEscape/file.txt\n' > "$BAD_SOURCE"
expect_rejected "$BAD_SOURCE" "$TMP/bad-source-target" "$TMP/bad-source-manifest.tsv"
[ ! -e "$TMP/bad-source-target" ]
BAD_TARGET=$TMP/bad-target.tsv
printf 'single/file.txt\t../outside.txt\n' > "$BAD_TARGET"
expect_rejected "$BAD_TARGET" "$TMP/bad-target-root" "$TMP/bad-target-manifest.tsv"
[ ! -e "$TMP/outside.txt" ]
[ ! -e "$TMP/bad-target-root" ]

# Duplicate literal targets and non-canonical aliases are rejected.
DUP=$TMP/duplicate.tsv
printf 'single/file.txt\tX/file\ntree/a.txt\tX/file\n' > "$DUP"
expect_rejected "$DUP" "$TMP/duplicate-target" "$TMP/duplicate-manifest.tsv"
ALIAS_SLASH=$TMP/alias-slash.tsv
printf 'single/file.txt\tX/file\ntree/a.txt\tX//file\n' > "$ALIAS_SLASH"
expect_rejected "$ALIAS_SLASH" "$TMP/alias-slash-target" "$TMP/alias-slash-manifest.tsv"
ALIAS_DOT=$TMP/alias-dot.tsv
printf 'single/file.txt\tX/file\ntree/a.txt\t./X/file\n' > "$ALIAS_DOT"
expect_rejected "$ALIAS_DOT" "$TMP/alias-dot-target" "$TMP/alias-dot-manifest.tsv"

# Expanded tree/file collisions and file/directory ancestor conflicts fail.
EXPANDED=$TMP/expanded.tsv
printf 'tree\tX\nsingle/file.txt\tX/a.txt\n' > "$EXPANDED"
expect_rejected "$EXPANDED" "$TMP/expanded-target" "$TMP/expanded-manifest.tsv"
ANCESTOR=$TMP/ancestor.tsv
printf 'single/file.txt\tX\ntree/a.txt\tX/child\n' > "$ANCESTOR"
expect_rejected "$ANCESTOR" "$TMP/ancestor-target" "$TMP/ancestor-manifest.tsv"

# Symlinked target roots and destination parents cannot redirect writes.
OUTSIDE_ROOT=$TMP/outside-root
mkdir "$OUTSIDE_ROOT"
ln -s "$OUTSIDE_ROOT" "$TMP/symlink-root"
expect_rejected "$SINGLE_ALLOW" "$TMP/symlink-root" "$TMP/symlink-root-manifest.tsv"
[ ! -e "$OUTSIDE_ROOT/Imported/file.txt" ]
PARENT_TARGET=$TMP/parent-target
OUTSIDE_PARENT=$TMP/outside-parent
mkdir "$PARENT_TARGET" "$OUTSIDE_PARENT"
ln -s "$OUTSIDE_PARENT" "$PARENT_TARGET/Imported"
expect_rejected "$SINGLE_ALLOW" "$PARENT_TARGET" "$TMP/symlink-parent-manifest.tsv"
[ ! -e "$OUTSIDE_PARENT/file.txt" ]

# Empty and comments-only allowlists create only the manifest header.
EMPTY_ALLOW=$TMP/empty.tsv
EMPTY_MANIFEST=$TMP/empty-manifest.tsv
printf '# no imports\n\n   # still no imports\n' > "$EMPTY_ALLOW"
run_import "$EMPTY_ALLOW" "$TMP/empty-target" "$EMPTY_MANIFEST"
printf 'source_commit\tsource_path\ttarget_path\tsha256\n' > "$TMP/header-only.tsv"
cmp "$TMP/header-only.tsv" "$EMPTY_MANIFEST"

# The public positional generator invocation expands tree mappings itself.
DIRECT_MANIFEST=$TMP/direct-manifest.tsv
python3 "$GENERATOR" "$SRC" HEAD "$TREE_ALLOW" "$DIRECT_MANIFEST" --target-root "$TREE_TARGET"
cmp "$TMP/expected-tree.tsv" "$DIRECT_MANIFEST"

echo 'Import boundary checks passed.'
