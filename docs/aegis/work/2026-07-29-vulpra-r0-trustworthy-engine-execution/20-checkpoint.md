# Vulpra R0 Trustworthy Engine Execution - Checkpoint

- Task ID: 2026-07-29-vulpra-r0-trustworthy-engine-execution
- Current todo: Task 1: define v5 producer contract
- Active slice: Create failing contract tests, contract JSON, verifier, portable registration, and commit.
- Blocked on: none
- Next step: Read current portable test patterns and implement Task 1 test-first.

## DriftCheckDraft

- Scope status: Task 1 stayed inside dormant producer metadata and portable tests.
- Compatibility status: Normal App builds and v4 lock are unchanged.
- Retirement status: Forbidden JIT tokens are contract assertions only; no old path is retired before replacement gates.
- New risk signals:
- none
- Advisory decision: continue

## Checkpoint Update

- Current todo: Task 2: materialize and audit the iOS patch series
- Active slice: Extract historical patch candidates, establish the minimal buildable series, remove JIT coordination, and bind every patch by digest.
- Completed todos:
- Task 1: v5 producer contract committed at d5577c3
- Evidence refs:
- commit:d5577c3
- Blocked on: none
- Next step: Inspect historical patch inventory and dependencies, add failing full-series fixtures, then implement strict series verification.
