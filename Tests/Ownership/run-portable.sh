#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
python3 "$ROOT/Tests/Ownership/test-product-boundary.py"
