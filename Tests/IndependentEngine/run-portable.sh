#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

python3 "$ROOT/Tests/IndependentEngine/test_ownership.py"
python3 "$ROOT/Tests/IndependentEngine/test_gecko_producer_v5.py"
python3 "$ROOT/Tests/IndependentEngine/test_gecko_producer_tools.py"
python3 "$ROOT/Tests/IndependentEngine/test_child_process_lifecycle.py"
python3 "$ROOT/Tests/IndependentEngine/test_engine_artifact_v5.py"
python3 "$ROOT/Tests/IndependentEngine/test_macho_repeat_identity.py"
python3 "$ROOT/Tests/IndependentEngine/test_r0_gate_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_abi_inventory.py"
python3 "$ROOT/Tests/IndependentEngine/test_message_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_public_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_internal_boundaries.py"
python3 "$ROOT/Tests/IndependentEngine/test_runtime_hardening.py"
python3 "$ROOT/Tests/IndependentEngine/test_storage_clear_flags.py"
python3 "$ROOT/Tests/IndependentEngine/test_security_state_event.py"
python3 "$ROOT/Tests/IndependentEngine/test_tracking_protection_real.py"
python3 "$ROOT/Tests/IndependentEngine/test_clipboard_permission.py"
python3 "$ROOT/Tests/IndependentEngine/test_fullscreen_event.py"
python3 "$ROOT/Tests/IndependentEngine/test_webshare.py"
python3 "$ROOT/Tests/IndependentEngine/test_privacy_usage_descriptions.py"
python3 "$ROOT/Tests/IndependentEngine/test_xcode_staging.py"
python3 "$ROOT/Tests/IndependentEngine/test_pref_channel_contract.py"
python3 "$ROOT/Tests/IndependentEngine/test_cutover_readiness.py"

echo "PASS: portable independent-engine gate"
