#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <iphoneos|iphonesimulator> <source>" >&2
  exit 64
fi

PLATFORM=$1
SOURCE=$2
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
CONTRACT=${VULPRA_GECKO_CONTRACT:-$ROOT/Configuration/gecko-producer-v5.json}

case "$PLATFORM" in
  iphoneos)
    TARGET=aarch64-apple-ios
    WEBRTC_OPTION=--enable-webrtc
    ;;
  iphonesimulator)
    TARGET=aarch64-apple-ios-sim
    WEBRTC_OPTION=--disable-webrtc
    ;;
  *)
    echo "gecko-build-error: unsupported platform: $PLATFORM" >&2
    exit 1
    ;;
esac

python3 "$ROOT/Tools/GeckoProducer/verify-producer.py" --contract "$CONTRACT"
EXPECTED_TARGET=$(python3 - "$CONTRACT" "$PLATFORM" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["targets"][sys.argv[2]])
PY
)
[[ "$TARGET" == "$EXPECTED_TARGET" ]] || {
  echo "gecko-build-error: target does not match producer contract" >&2
  exit 1
}
[[ -d "$SOURCE/.git" || -f "$SOURCE/.git" ]] || {
  echo "gecko-build-error: source is not a Git checkout: $SOURCE" >&2
  exit 1
}

MOZCONFIG=$SOURCE/.mozconfig-vulpra-$PLATFORM
cat > "$MOZCONFIG" <<EOF
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-$TARGET
ac_add_options --enable-application=mobile/ios
ac_add_options --target=$TARGET
ac_add_options --enable-ios-target=15.0
ac_add_options --enable-optimize
ac_add_options --disable-debug
ac_add_options --disable-tests
ac_add_options $WEBRTC_OPTION
EOF

MACH=${VULPRA_MACH:-$SOURCE/mach}
[[ -x "$MACH" ]] || {
  echo "gecko-build-error: missing executable mach: $MACH" >&2
  exit 1
}

if command -v rustup >/dev/null 2>&1; then
  if ! rustup target list --installed | grep -Fxq "$TARGET"; then
    rustup target add "$TARGET"
  fi
fi

(cd "$SOURCE" && MOZCONFIG="$MOZCONFIG" "$MACH" build)
printf 'PASS: built Gecko runtime platform=%s target=%s mozconfig=%s\n' \
  "$PLATFORM" "$TARGET" "$MOZCONFIG"
