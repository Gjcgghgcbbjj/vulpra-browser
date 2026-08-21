#!/bin/sh
# Static device-compatibility audit for the packaged TrollStore TIPA.
# Verifies, without any physical device:
#   1. every Mach-O in Payload/ carries an embedded entitlements/signature blob
#   2. the main binary embeds the memorystatus entitlement (jetsam fix precondition)
#   3. Info.plist exposes file sharing (UIFileSharingEnabled) for log retrieval
#   4. dependency closure: every @rpath LC_LOAD_DYLIB resolves inside the bundle
#   5. all binaries are arm64 device slices (no simulator contamination)
set -eu

[ "$#" -eq 1 ] || { echo "Usage: audit-tipa.sh <Vulpra-TrollStore.tipa>" >&2; exit 64; }
TIPA=$1
[ -f "$TIPA" ] || { echo "Missing tipa: $TIPA" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
unzip -q "$TIPA" -d "$WORK"
APP="$WORK/Payload/Vulpra.app"
[ -d "$APP" ] || { echo "AUDIT FAIL: Payload/Vulpra.app missing" >&2; exit 1; }

fail() { echo "AUDIT FAIL: $*" >&2; exit 1; }

macho_list=$(find "$APP" -type f \( -perm -111 -o -name '*.dylib' -o -name 'XUL' \) -exec file {} \; \
    | awk -F: '/Mach-O 64-bit executable arm64|Mach-O 64-bit dynamically linked shared library arm64/ {print $1}')
macho_count=$(printf '%s\n' "$macho_list" | grep -c .)

# ── 1+2. entitlements / signature blobs ──────────────────────────────────
printf '%s\n' "$macho_list" | while IFS= read -r bin; do
    [ -n "$bin" ] || continue
    if ! ldid -e "$bin" 2>/dev/null | grep -q "<dict>"; then
        echo "AUDIT FAIL: no embedded entitlements/signature: ${bin#$WORK/}" >&2
        exit 1
    fi
done || exit 1
echo "audit: $macho_count arm64 Mach-O binaries, all carry entitlement blobs"

ldid -e "$APP/Vulpra" | grep -q "com.apple.private.memorystatus" ||
    fail "main binary lost com.apple.private.memorystatus entitlement"
ldid -e "$APP/Vulpra" | grep -q "com.apple.private.security.no-sandbox" ||
    fail "main binary lost no-sandbox entitlement"

# ── 3. file sharing keys for USB log retrieval ───────────────────────────
plutil -extract UIFileSharingEnabled raw "$APP/Info.plist" | grep -q true ||
    fail "Info.plist missing UIFileSharingEnabled"
plutil -extract LSSupportsOpeningDocumentsInPlace raw "$APP/Info.plist" | grep -q true ||
    fail "Info.plist missing LSSupportsOpeningDocumentsInPlace"

# ── 4. dependency closure (@rpath must resolve inside the bundle) ────────
unresolved=0
while IFS= read -r bin; do
    [ -n "$bin" ] || continue
    for dep in $(otool -L "$bin" | tail -n +2 | awk '{print $1}'); do
        case "$dep" in
            @rpath/*)
                base=${dep#@rpath/}
                if ! find "$APP" -name "$(basename "$base")" -print -quit | grep -q .; then
                    echo "unresolved: ${bin#$WORK/} -> $dep" >> "$WORK/unresolved.txt"
                    unresolved=$((unresolved + 1))
                fi
                ;;
        esac
    done
done <<EOF
$macho_list
EOF
[ "$unresolved" -eq 0 ] || { sed 's/^/AUDIT FAIL: /' "$WORK/unresolved.txt" >&2; exit 1; }
echo "audit: dependency closure resolved for all binaries"

# ── 5. no simulator slices anywhere ──────────────────────────────────────
if find "$APP" -type f -exec file {} \; | grep -q "iphonesimulator\|x86_64"; then
    fail "simulator slice contaminated the device package"
fi
echo "audit: no simulator contamination"

echo "TIPA device-compat audit PASSED ($macho_count Mach-O binaries verified)"
