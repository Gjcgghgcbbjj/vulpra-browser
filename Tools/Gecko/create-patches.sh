#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h:h}"
SUBMODULE_PATH="Vendor/firefox"
PATCH_DIR="${ROOT_DIR}/Patches"

cd "$ROOT_DIR"

if [[ ! -f "Vendor/firefox-release.txt" ]]; then
    echo "Cannot get Firefox release tag: Missing Vendor/firefox-release.txt."
    exit 1
fi

RELEASE_TAG="$(tr -d '\000\r' < "Vendor/firefox-release.txt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

if [[ -z "$RELEASE_TAG" ]]; then
    echo "Cannot get Firefox release tag: Vendor/firefox-release.txt is empty."
    exit 1
fi

if ! git submodule status -- "$SUBMODULE_PATH" >/dev/null 2>&1; then
    echo "Missing submodule $SUBMODULE_PATH. Add it first, then run Tools/Gecko/update-gecko.sh."
    exit 1
fi

if ! git -C "$SUBMODULE_PATH" rev-parse -q --verify "$RELEASE_TAG^{commit}" >/dev/null 2>&1; then
    echo "Tag $RELEASE_TAG does not exist in $SUBMODULE_PATH."
    exit 1
fi

RELEASE_COMMIT="$(git -C "$SUBMODULE_PATH" rev-parse "$RELEASE_TAG^{commit}")"
PINNED_COMMIT="$(git rev-parse "HEAD:$SUBMODULE_PATH")"
HEAD_COMMIT="$(git -C "$SUBMODULE_PATH" rev-parse HEAD)"

if [[ "$RELEASE_COMMIT" != "$PINNED_COMMIT" ]]; then
    echo "Vendor/firefox-release.txt and the repository gitlink disagree."
    echo "Release: $RELEASE_TAG -> $RELEASE_COMMIT"
    echo "Gitlink: $PINNED_COMMIT"
    exit 1
fi

if [[ "$HEAD_COMMIT" != "$PINNED_COMMIT" ]]; then
    CURRENT_TAG="$(git -C "$SUBMODULE_PATH" describe --tags --exact-match HEAD 2>/dev/null || echo "no-exact-tag")"
    echo "Submodule HEAD ($HEAD_COMMIT, tag: $CURRENT_TAG) does not match the pinned gitlink ($PINNED_COMMIT)."
    echo "Run Tools/Gecko/update-gecko.sh to sync the submodule commit."
    exit 1
fi

mkdir -p "$PATCH_DIR"
echo "Cleaning old patches..."
find "$PATCH_DIR" -mindepth 1 -not -name 'LICENSE' -exec rm -rf {} +

files="$(git -C "$SUBMODULE_PATH" diff --name-only "$RELEASE_TAG")"

if [[ -z "$files" ]]; then
    echo "No changes found against $RELEASE_TAG."
    exit 0
fi

echo "Generating patches..."
for file in ${(f)files}; do
    target="$PATCH_DIR/$file.patch"
    mkdir -p "$(dirname "$target")"
    git -C "$SUBMODULE_PATH" diff --binary "$RELEASE_TAG" -- "$file" > "$target"

    if [[ ! -s "$target" ]]; then
        rm -f "$target"
    else
        echo "Wrote $target"
    fi
done

untracked="$(git -C "$SUBMODULE_PATH" ls-files --others --exclude-standard)"
if [[ -n "$untracked" ]]; then
    echo "Notice: untracked files were not included. Stage them in $SUBMODULE_PATH to include them in patches."
fi

echo "Done. Patches are in $PATCH_DIR"
