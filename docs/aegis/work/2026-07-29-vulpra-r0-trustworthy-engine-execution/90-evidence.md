# Vulpra R0 Trustworthy Engine Execution - Evidence

No evidence has been recorded yet.

## EvidenceBundleDraft

- Artifact key: task1-producer-contract
- Type: test
- Source: commit:d5577c3; Tests/IndependentEngine/test_gecko_producer_v5.py; Tests/IndependentEngine/run-portable.sh
- Summary: Task 1 contract fixtures and the complete portable independent-engine gate passed; strict JSON keys, pinned upstream, dual iOS triples, exports, and forbidden runtime tokens are enforced.
- Verifier: python3 Tests/IndependentEngine/test_gecko_producer_v5.py && ./Tests/IndependentEngine/run-portable.sh && git diff --check

## EvidenceBundleDraft

- Artifact key: task9-native-pair-305983
- Type: github-promotion
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30613021710
- Summary: Two independent native device/Simulator producer runs 30598301958 and 30598347174 on 8fa770c completed with matching build fingerprints; promotion repeat-compare and atomic lock passed, and r0.3 prerelease assets were roundtrip-verified.
- Verifier: GitHub run 30613021710 promote-repeat-verified-pair job; Configuration/engine-artifact-lock.json
