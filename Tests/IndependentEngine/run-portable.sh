#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

python3 Tests/IndependentEngine/test_ownership.py
python3 Tests/IndependentEngine/test_artifact_contract.py
python3 Tests/IndependentEngine/test_public_contract.py
python3 Tests/IndependentEngine/test_internal_boundaries.py
python3 Tests/IndependentEngine/test_xcode_staging.py
python3 -m json.tool Configuration/engine-ownership.json >/dev/null
python3 -m json.tool Configuration/engine-artifact-v4.json >/dev/null
python3 Tests/IndependentEngine/test_cutover_readiness.py
set +e
python3 Tests/IndependentEngine/test_cutover_readiness.py --require-cutover >/tmp/vulpra-cutover-readiness.log
status=$?
set -e
test "$status" -eq 2
grep -Fq "Phase A cutover readiness: NOT READY" /tmp/vulpra-cutover-readiness.log
grep -Fq "verified v4 Gecko artifact payload" /tmp/vulpra-cutover-readiness.log
git diff --check
echo "PASS: portable independent-engine Phase A gate"
