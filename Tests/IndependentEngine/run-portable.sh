#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

python3 "$ROOT/Tests/IndependentEngine/test_ownership.py"
python3 "$ROOT/Tests/IndependentEngine/test_artifact_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_simulator_derivation.py"
python3 "$ROOT/Tests/IndependentEngine/test_abi_inventory.py"
python3 "$ROOT/Tests/IndependentEngine/test_message_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_public_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_internal_boundaries.py"
python3 "$ROOT/Tests/IndependentEngine/test_runtime_hardening.py"
python3 "$ROOT/Tests/IndependentEngine/test_xcode_staging.py"
python3 "$ROOT/Tests/IndependentEngine/test_cutover_readiness.py"

echo "PASS: portable independent-engine gate"
