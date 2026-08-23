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

# `file` prints "Mach-O 64-bit executable arm64" on macOS but
# "Mach-O 64-bit arm64 executable" on GNU file; accept both word orders.
macho_list=$(find "$APP" -type f \( -perm -111 -o -name '*.dylib' -o -name 'XUL' \) -exec file {} \; \
    | awk -F: '/Mach-O 64-bit (executable arm64|arm64 executable)|Mach-O 64-bit (dynamically linked shared library arm64|arm64 dynamically linked shared library)/ {print $1}')
macho_count=$(printf '%s\n' "$macho_list" | grep -c .)

# ── 1. every Mach-O carries a code signature (LC_CODE_SIGNATURE) ─────────
printf '%s\n' "$macho_list" | while IFS= read -r bin; do
    [ -n "$bin" ] || continue
    if ! otool -l "$bin" | grep -q "LC_CODE_SIGNATURE"; then
        echo "AUDIT FAIL: unsigned (no LC_CODE_SIGNATURE): ${bin#$WORK/}" >&2
        exit 1
    fi
done || exit 1
echo "audit: $macho_count arm64 Mach-O binaries, all code-signed"

# ── 2. mandatory entitlements on the three privileged binaries ───────────
for required in com.apple.private.memorystatus com.apple.private.security.no-sandbox platform-application com.apple.developer.web-browser; do
    ldid -e "$APP/Vulpra" | grep -q "$required" ||
        fail "main binary lost $required"
done
ldid -e "$APP/PlugIns/Vulpra Helper.appex/Vulpra Helper" | grep -q "platform-application" ||
    fail "helper appex lost platform-application"
ldid -e "$APP/ptrace_jit" | grep -q "platform-application" ||
    fail "ptrace_jit lost platform-application"
echo "audit: privileged binaries carry mandatory entitlements"

# ── 2b. default-browser candidacy ──────────────────────────────────────────
# The picker only lists apps whose Info.plist registers the web schemes.
python3 - "$APP" <<'PY'
import plistlib, sys
from pathlib import Path
app = Path(sys.argv[1])
info = plistlib.loads((app / "Info.plist").read_bytes())
schemes = {s.lower() for t in info.get("CFBundleURLTypes", []) for s in t.get("CFBundleURLSchemes", [])}
missing = {"http", "https"} - schemes
assert not missing, f"audit FAIL: default-browser schemes missing from Info.plist: {sorted(missing)}"
print("audit: default-browser web schemes registered")
PY

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
