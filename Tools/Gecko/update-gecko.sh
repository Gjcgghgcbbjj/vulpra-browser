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

# Resolve the pinned Firefox commit. Prefer the git submodule gitlink,
# but fall back to the release tag if this is an orphan commit (no submodule ref).
PINNED_COMMIT=""
if git rev-parse "HEAD:$SUBMODULE_PATH" >/dev/null 2>&1; then
	PINNED_COMMIT="$(git rev-parse "HEAD:$SUBMODULE_PATH")"
	echo "Resolved pinned commit from submodule gitlink: $PINNED_COMMIT"
fi
if [[ -z "$PINNED_COMMIT" ]]; then
	echo "No submodule gitlink (orphan commit). Cloning from release tag $RELEASE_TAG..."
	rm -rf "$SUBMODULE_PATH"
	git clone --depth 1 --branch "$RELEASE_TAG" "$FIREFOX_URL" "$SUBMODULE_PATH"
	PINNED_COMMIT="$(git -C "$SUBMODULE_PATH" rev-parse HEAD)"
	echo "Resolved pinned commit from release tag: $PINNED_COMMIT"
fi

echo "Using Firefox commit: $PINNED_COMMIT"

echo "Ensuring checkout at $PINNED_COMMIT"
if [ ! -d "$SUBMODULE_PATH/.git" ]; then
	git clone --depth 1 "$FIREFOX_URL" "$SUBMODULE_PATH"
fi
# Fetch the exact commit if not present (shallow clone may not have it).
if ! git -C "$SUBMODULE_PATH" cat-file -e "$PINNED_COMMIT" 2>/dev/null; then
	git -C "$SUBMODULE_PATH" fetch --depth 1 origin "$PINNED_COMMIT"
fi
git -C "$SUBMODULE_PATH" checkout --detach "$PINNED_COMMIT"
HEAD_COMMIT="$(git -C "$SUBMODULE_PATH" rev-parse HEAD)"

if [[ "$HEAD_COMMIT" != "$PINNED_COMMIT" ]]; then
	echo "Failed to checkout the pinned Firefox commit."
	echo "Expected: $PINNED_COMMIT"
	echo "Actual:   $HEAD_COMMIT"
	exit 1
fi
