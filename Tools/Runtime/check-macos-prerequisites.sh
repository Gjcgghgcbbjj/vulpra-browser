#!/bin/sh
set -eu

if [ "$(uname -s)" != Darwin ]; then
	echo "needs-macos: runtime substrate production requires macOS" >&2
	exit 78
fi

missing=""
for command in git xcode-select xcodebuild xcrun rustup cargo python3 tar rsync shasum zsh; do
	if ! command -v "$command" >/dev/null 2>&1; then
		missing="$missing $command"
	fi
done

if [ -n "$missing" ]; then
	echo "Missing macOS runtime producer commands:$missing" >&2
	exit 1
fi

xcode_build=$(xcodebuild -version | awk '/Build version/ {print $3}')
sdk_build=$(xcrun --sdk iphoneos --show-sdk-build-version)
[ -n "$xcode_build" ] || { echo "Unable to resolve Xcode build version" >&2; exit 1; }
[ -n "$sdk_build" ] || { echo "Unable to resolve iPhoneOS SDK build version" >&2; exit 1; }

printf 'macos-prerequisites-ok xcode_build=%s sdk_build=%s\n' "$xcode_build" "$sdk_build"
