#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"

python3 Tests/RuntimeShell/test-xcode-graph.py
python3 Tests/RuntimeShell/test-product-contracts.py
python3 Tests/RuntimeShell/test-runtime-shell.py
python3 Tests/RuntimeShell/test-jit-orchestration.py
python3 Tests/RuntimeShell/test-open-in.py
Tests/RuntimeShell/test-runtime-artifacts.sh
Tests/RuntimeShell/test-release-packaging.sh
Tools/Gecko/test-gecko-artifact.sh
python3 Tests/Browser/test-runtime-workflow.py
python3 Tests/Browser/test-package-workflow.py
python3 Tests/Browser/test-browser-client.py

find Tools Tests -type f -name '*.sh' -print | LC_ALL=C sort | while IFS= read -r script; do
	case "$(head -n 1 "$script")" in
		'#!/bin/sh')
			sh -n "$script"
			command -v dash >/dev/null 2>&1 && dash -n "$script"
			;;
		'#!/bin/bash'|'#!/usr/bin/env bash') bash -n "$script" ;;
		'#!/bin/zsh'|'#!/usr/bin/env zsh')
			if command -v zsh >/dev/null 2>&1; then zsh -n "$script"; else echo "Skipping unavailable zsh: $script"; fi
			;;
		*) echo "Unsupported script interpreter: $script" >&2; exit 1 ;;
	esac
done

python3 - <<'PY'
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

for root in (Path("App"), Path("Extensions"), Path("Modules")):
    for path in sorted(root.rglob("*")):
        if path.suffix in (".plist", ".entitlements"):
            with path.open("rb") as source:
                plistlib.load(source)
ET.parse("Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme")
print("PASS: product plists and shared scheme parse")
PY

git diff --check
echo "PASS: portable runtime-shell gate"
