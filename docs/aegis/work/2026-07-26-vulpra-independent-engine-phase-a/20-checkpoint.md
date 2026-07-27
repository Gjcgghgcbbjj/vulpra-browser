# Vulpra Independent Engine Phase A - Checkpoint

- Task ID: 2026-07-26-vulpra-independent-engine-phase-a
- Current todo: Write and validate the Phase A implementation plan.
- Active slice: Planning and long-task initialization.
- Blocked on: none
- Next step: Inspect exact graph/test owners, save the plan, then execute ownership-map RED/GREEN.

## DriftCheckDraft

- Scope status: Task 1 stayed within authority and ownership contracts only.
- Compatibility status: App runtime, data, bundle identity, and active Xcode dependencies unchanged.
- Retirement status: Old owners remain staged as the sole runtime; atomic cutover requirements are now machine recorded.
- New risk signals:
- none
- Advisory decision: continue

## Checkpoint Update

- Current todo: Define and verify the binary Gecko artifact v4 layout.
- Active slice: Task 2 artifact v4 contract RED/GREEN.
- Completed todos:
- Task 1: approved authority and machine ownership map.
- Evidence refs:
- task1-ownership-red-green
- Blocked on: none
- Next step: Write fixture tests for valid and rejected v4 artifact layouts.

## DriftCheckDraft

- Scope status: Task 2 added only the v4 contract, verifier, and isolated fixtures.
- Compatibility status: Existing v3 runtime producer, App runtime, and packaging workflows remain unchanged.
- Retirement status: v4 is not production authority until a real producer artifact passes; v3 retirement trigger remains atomic cutover.
- New risk signals:
- Exact ABI payload and real producer remain unverified.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Add the VulpraEngineKit public contract skeleton.
- Active slice: Task 3 public engine contract RED/GREEN.
- Completed todos:
- Task 1: approved authority and machine ownership map.
- Task 2: binary Gecko artifact v4 contract and verifier.
- Evidence refs:
- task1-ownership-red-green
- task2-artifact-v4-red-green
- Blocked on: none
- Next step: Write structural contract tests, then add split Swift public protocol/value owners.

## DriftCheckDraft

- Scope status: Task 3 added dormant typed public contracts only.
- Compatibility status: App imports and active runtime remain unchanged; no public inherited types or fallback.
- Retirement status: Public replacement owner exists; old runtime remains active until ABI and App cutover evidence.
- New risk signals:
- Swift/Xcode compilation remains unavailable on Linux.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Add independent ABI and process-host boundaries without behavior.
- Active slice: Task 4 ABI/process boundary RED/GREEN.
- Completed todos:
- Task 1: approved authority and machine ownership map.
- Task 2: binary Gecko artifact v4 contract and verifier.
- Task 3: VulpraEngineKit public contract skeleton.
- Evidence refs:
- task3-public-contract-red-green
- Blocked on: none
- Next step: Write internal boundary tests and add minimal bridge/process bootstrap owners.

## DriftCheckDraft

- Scope status: Task 4 added bounded dormant internal/process owners only.
- Compatibility status: No external header, runtime symbol, App dependency, or user data changed.
- Retirement status: No old path retired yet; replacement internal ownership is now explicit.
- New risk signals:
- Process target type and real bootstrap remain Mac/runtime verification gates.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Add dormant independent targets to the Xcode graph.
- Active slice: Task 5 Xcode staging RED/GREEN.
- Completed todos:
- Tasks 1-4 source and contract slices.
- Evidence refs:
- task4-internal-boundaries-red-green
- Blocked on: none
- Next step: Write Xcode staging contract, add configs and dormant targets, then run old/new graph suites.

## DriftCheckDraft

- Scope status: Phase A source, contract, target staging, and readiness work stayed in scope.
- Compatibility status: App remains on exactly one old runtime path; new targets are not dependencies or embedded products; data unchanged.
- Retirement status: Retirement is prepared but not executed; all cutover gates remain open pending real artifact/ABI/Mac/runtime evidence.
- New risk signals:
- Dormant targets are structurally valid only; Xcode compilation and process product validity are unverified.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: Obtain real v4 artifact and ABI inventory for the next implementation plan.
- Active slice: Phase A verification and handoff.
- Completed todos:
- Tasks 1-6: Phase A source/contracts, dormant targets, and readiness gates.
- Evidence refs:
- task1-ownership-red-green
- task2-artifact-v4-red-green
- task3-public-contract-red-green
- task4-internal-boundaries-red-green
- task5-6-staging-readiness
- Blocked on: Mac/Xcode toolchain and exact precompiled kernel ABI artifact are not available in this Linux workspace.
- Next step: On a Mac/artifact host, produce and verify v4 artifact, record ABI symbols/headers, then write the Phase B runtime startup plan.

## Checkpoint Update

- Current todo: Design the Phase B Mac compile/link/startup experiment from the verified six-symbol export inventory.
- Active slice: Real artifact ABI inventory and v4 candidate evidence completed.
- Completed todos:
- Tasks 1-6: Phase A source/contracts, dormant targets, and readiness gates.
- Downloaded and checksum-verified GitHub artifact 8512456239; added deterministic Mach-O/header inventory tooling; produced and verified a filtered local v4 candidate.
- Evidence refs:
- task1-ownership-red-green
- task2-artifact-v4-red-green
- task3-public-contract-red-green
- task4-internal-boundaries-red-green
- task5-6-staging-readiness
- artifact-8512456239-abi-v4-candidate
- Blocked on: No external v4 producer artifact or Mac/Xcode compile evidence; XUL exposes no dedicated process-wide shutdown export or explicit interpreter-only startup selector.
- Next step: Write a Phase B plan for a Mac compile/link experiment using only MainProcessInit, GeckoViewOpenWindow, ChildProcessInit, and the three direct ABI headers; keep App and old targets unchanged until runtime evidence exists.

## DriftCheckDraft

- Scope status: Artifact investigation stayed within precompiled kernel, dylib, direct ABI header, runtime resource, and license boundaries.
- Compatibility status: App, active GeckoView/Helper runtime, bundle identity, user data, packaging workflow, and dormant target graph remain unchanged.
- Retirement status: No old owner was retired; atomic cutover remains gated on external v4 production, Mac runtime startup/process proof, App migration, and old target removal.
- New risk signals:
- The dyld export trie contains only six symbols; process-wide shutdown candidates are defined but not exported.
- ReportJITStatusForChild reports status but does not select or prove interpreter-only startup.
- The verified .build/engine v4 root is a local filtered candidate, not an external producer artifact.
- Advisory decision: needs-verification
