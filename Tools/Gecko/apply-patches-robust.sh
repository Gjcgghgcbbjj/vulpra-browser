#!/bin/bash
set -e
cd "$1"  # Vendor/firefox
PATCH_DIR="$2"
applied=0; skipped=0
for patch in $(find "$PATCH_DIR" -name "*.patch" -type f | sort); do
  # Try patch with fuzz, then force if needed
  if patch -p1 --fuzz=3 < "$patch" >/dev/null 2>&1; then
    echo "Applied: $patch"
    applied=$((applied + 1))
  elif patch -p1 --fuzz=3 --force < "$patch" >/dev/null 2>&1; then
    echo "Applied (forced): $patch"
    applied=$((applied + 1))
  else
    echo "Skip: $patch"
    skipped=$((skipped + 1))
  fi
done
echo "Patches: $applied applied, $skipped skipped"
