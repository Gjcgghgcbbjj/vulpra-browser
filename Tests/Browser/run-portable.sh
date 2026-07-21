#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
python3 Tests/Browser/test-runtime-workflow.py
python3 Tests/Browser/test-package-workflow.py
python3 Tests/Browser/test-browser-client.py
echo 'PASS: portable browser product gate'
