#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
python3 Tests/Browser/test-package-workflow.py
python3 Tests/Browser/test-package-identity.py
python3 Tests/Browser/test-browser-client.py
python3 Tests/Browser/test-browser-compatibility.py
python3 Tests/Browser/test-localization-and-icon.py
python3 Tests/Browser/test-porcelain-ui.py
echo 'PASS: portable browser product gate'
