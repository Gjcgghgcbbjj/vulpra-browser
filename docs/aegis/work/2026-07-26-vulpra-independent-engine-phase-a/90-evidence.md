# Vulpra Independent Engine Phase A - Evidence

No evidence has been recorded yet.

## EvidenceBundleDraft

- Artifact key: task1-ownership-red-green
- Type: test
- Source: Tests/IndependentEngine/test_ownership.py; Configuration/engine-ownership.json
- Summary: RED rejected the missing ownership manifest; GREEN passed the independent ownership runner, JSON parsing, and git diff check.
- Verifier: ./Tests/IndependentEngine/run-portable.sh && python3 -m json.tool Configuration/engine-ownership.json >/dev/null && git diff --check

## EvidenceBundleDraft

- Artifact key: task2-artifact-v4-red-green
- Type: test
- Source: Configuration/engine-artifact-v4.json; Tools/Engine/verify-engine-artifact.py; Tests/IndependentEngine/test_artifact_contract.py
- Summary: Artifact v4 fixture matrix passed twice deterministically; Python compilation, JSON parsing, diff checks, and existing RuntimeShell/Browser regressions passed.
- Verifier: ./Tests/IndependentEngine/run-portable.sh && ./Tests/RuntimeShell/run-portable.sh && ./Tests/Browser/run-portable.sh

## EvidenceBundleDraft

- Artifact key: task3-public-contract-red-green
- Type: test
- Source: Engine/VulpraEngineKit/Public; Tests/IndependentEngine/test_public_contract.py
- Summary: Public contract structural gate and all existing portable regressions passed; no Swift compiler is available on this Linux host.
- Verifier: ./Tests/IndependentEngine/run-portable.sh && ./Tests/RuntimeShell/run-portable.sh && ./Tests/Browser/run-portable.sh

## EvidenceBundleDraft

- Artifact key: task4-internal-boundaries-red-green
- Type: test
- Source: Engine/VulpraEngineKit/Internal/ABI; Engine/VulpraEngineProcess; Tests/IndependentEngine/test_internal_boundaries.py
- Summary: ABI/process structural gate, plist parsing, independent suite, and existing RuntimeShell/Browser regressions passed; ABI implementation remains explicitly unavailable.
- Verifier: ./Tests/IndependentEngine/run-portable.sh && ./Tests/RuntimeShell/run-portable.sh && ./Tests/Browser/run-portable.sh

## EvidenceBundleDraft

- Artifact key: task5-6-staging-readiness
- Type: test
- Source: Vulpra.xcodeproj; Configuration/EngineKit.xcconfig; Configuration/EngineProcess.xcconfig; Configuration/engine-cutover-gates.json; Tests/IndependentEngine
- Summary: Dormant target graph and readiness gates passed; require-cutover correctly returned status 2 with all twelve external/migration gates open.
- Verifier: ./Tests/IndependentEngine/run-portable.sh; python3 Tests/IndependentEngine/test_cutover_readiness.py --require-cutover (expected exit 2)

## EvidenceBundleDraft

- Artifact key: artifact-8512456239-abi-v4-candidate
- Type: binary-inspection
- Source: GitHub artifact 8512456239; Configuration/engine-abi-inventory.json; Tools/Engine/inventory-engine-abi.py; abi-inventory-artifact-8512456239.json; .build/engine/manifest.json
- Summary: Checksum-verified artifact 8512456239 yielded a deterministic six-symbol dyld export inventory. A filtered local v4 candidate with 2654 files passed the content-bound verifier, but it is not external producer evidence; process-wide shutdown and interpreter-only startup remain unproved.
- Verifier: ./Tests/IndependentEngine/run-portable.sh; python3 Tools/Engine/verify-engine-artifact.py --contract Configuration/engine-artifact-v4.json .build/engine; deterministic inventory cmp against artifact ZIP sha256 3919792d79f06969b210532bbca88ec4c822f7dba5b9fdae1741a4e8b11b1e75
