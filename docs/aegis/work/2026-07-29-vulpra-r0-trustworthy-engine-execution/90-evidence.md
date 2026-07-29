# Vulpra R0 Trustworthy Engine Execution - Evidence

No evidence has been recorded yet.

## EvidenceBundleDraft

- Artifact key: task1-producer-contract
- Type: test
- Source: commit:d5577c3; Tests/IndependentEngine/test_gecko_producer_v5.py; Tests/IndependentEngine/run-portable.sh
- Summary: Task 1 contract fixtures and the complete portable independent-engine gate passed; strict JSON keys, pinned upstream, dual iOS triples, exports, and forbidden runtime tokens are enforced.
- Verifier: python3 Tests/IndependentEngine/test_gecko_producer_v5.py && ./Tests/IndependentEngine/run-portable.sh && git diff --check
