#!/bin/sh

set -eu

"${SRCROOT}/Tools/Runtime/verify-runtime-artifacts.sh"

GECKO_DIST_BIN="${GECKO_DIST}/bin"
APP_BUNDLE="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FRAMEWORKS_DIR="${APP_BUNDLE}/Frameworks"
GECKOVIEW_FW="${FRAMEWORKS_DIR}/GeckoView.framework"
GECKOVIEW_FW_FRAMEWORKS="${GECKOVIEW_FW}/Frameworks"

SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}}"
DEFAULT_THEME_SRC="${SRCROOT}/Vendor/firefox/toolkit/mozapps/extensions/default-theme"

mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${GECKOVIEW_FW_FRAMEWORKS}"

# copy dylibs and XUL, then sign
cp -fL "${GECKO_DIST_BIN}/"*.dylib "${FRAMEWORKS_DIR}/"
cp -fL "${GECKO_DIST_BIN}/XUL" "${FRAMEWORKS_DIR}/XUL"

# XUL is spawned directly as the helper's GRE executable (Utils.m posix_spawn).
# Its Gecko dependencies are @rpath/*, and @rpath inside a spawned binary
# resolves against the spawned binary's OWN LC_RPATH — which is either absent
# or points at build-machine paths — so dyld aborts the spawn with ENOENT
# even though every library sits right here. Rewrite each reference to
# @loader_path and make sure the library is physically present.
for dep in $(otool -L "${FRAMEWORKS_DIR}/XUL" | awk '/@rpath\// {gsub("@rpath/", "", $1); print $1}'); do
	if [ ! -f "${FRAMEWORKS_DIR}/${dep}" ]; then
		for src_dir in "${GECKO_DIST_BIN}" "${GECKO_DIST}/lib"; do
			if [ -f "${src_dir}/${dep}" ]; then
				cp -fL "${src_dir}/${dep}" "${FRAMEWORKS_DIR}/${dep}"
				break
			fi
		done
	fi
	if [ -f "${FRAMEWORKS_DIR}/${dep}" ]; then
		install_name_tool -change "@rpath/${dep}" "@loader_path/${dep}" "${FRAMEWORKS_DIR}/XUL" || true
	fi
done

if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]; then
	[ -n "$SIGN_IDENTITY" ] || {
		echo "Missing expanded code-sign identity" >&2
		exit 1
	}
	for file in "${FRAMEWORKS_DIR}/XUL" "${FRAMEWORKS_DIR}/"*.dylib; do
		if [ -f "${file}" ]; then
			codesign --force --sign "${SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements "${file}"
		fi
	done
fi

# copy the rest of the files, excluding the ones we already copied and the test files
rsync -pvtrlL --delete --exclude "XUL" --exclude "*.dylib" --exclude "Test*" --exclude "test_*" --exclude "*_unittest" "${GECKO_DIST_BIN}/" "${GECKOVIEW_FW_FRAMEWORKS}"

# default theme missing error fix
mkdir -p "${GECKOVIEW_FW_FRAMEWORKS}/default-theme"
cp -RfL "${DEFAULT_THEME_SRC}/" "${GECKOVIEW_FW_FRAMEWORKS}/default-theme/"
echo "resource default-theme file:default-theme/" >> "${GECKOVIEW_FW_FRAMEWORKS}/chrome.manifest"

# Signing is deferred to create-ipa.sh for unsigned CI archives.
if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]; then
	codesign --force --sign "${SIGN_IDENTITY}" "${GECKOVIEW_FW}"
fi
