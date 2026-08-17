#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h:h}"
SUBMODULE_PATH="Vendor/firefox"
FIREFOX_URL="https://github.com/mozilla-firefox/firefox"

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
	echo "Missing submodule $SUBMODULE_PATH. Add it first, then run this script."
	exit 1
fi

if ! PINNED_COMMIT="$(git rev-parse "HEAD:$SUBMODULE_PATH" 2>/dev/null)"; then
	echo "Cannot resolve the pinned Firefox gitlink at $SUBMODULE_PATH."
	exit 1
fi

TAG_REF="refs/tags/$RELEASE_TAG"

echo "Updating existing submodule at $SUBMODULE_PATH"
git submodule set-url -- "$SUBMODULE_PATH" "$FIREFOX_URL"
git submodule sync -- "$SUBMODULE_PATH"
git submodule update --init --depth 1 -- "$SUBMODULE_PATH"

echo "Fetching release tag $RELEASE_TAG for pin verification..."
if ! git -C "$SUBMODULE_PATH" fetch --depth 1 origin tag "$RELEASE_TAG"; then
	echo "Release tag $RELEASE_TAG does not exist in $FIREFOX_URL."
	exit 1
fi

RELEASE_COMMIT="$(git -C "$SUBMODULE_PATH" rev-parse "$TAG_REF^{commit}")"
if [[ "$RELEASE_COMMIT" != "$PINNED_COMMIT" ]]; then
	echo "Firefox release metadata and the repository gitlink disagree."
	echo "Release: $RELEASE_TAG -> $RELEASE_COMMIT"
	echo "Gitlink: $PINNED_COMMIT"
	exit 1
fi

git -C "$SUBMODULE_PATH" checkout --detach "$PINNED_COMMIT"
HEAD_COMMIT="$(git -C "$SUBMODULE_PATH" rev-parse HEAD)"

if [[ "$HEAD_COMMIT" != "$PINNED_COMMIT" ]]; then
	echo "Failed to checkout the pinned Firefox commit."
	echo "Expected: $PINNED_COMMIT"
	echo "Actual:   $HEAD_COMMIT"
	exit 1
fi
