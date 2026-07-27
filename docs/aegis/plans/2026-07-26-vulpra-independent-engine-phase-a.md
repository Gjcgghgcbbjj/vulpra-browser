# Vulpra Independent Engine Phase A Implementation Plan

**Goal:** Begin the approved binary-Gecko-only architecture by establishing
machine-verifiable ownership and artifact contracts, adding independent
`VulpraEngineKit` and `VulpraEngineProcess` target skeletons, and defining an
atomic cutover gate that cannot become a runtime fallback.

**Architecture:** The existing GeckoView/Helper path remains the sole product
runtime only while the replacement targets are dormant. The new source roots
are authored independently and may not import or compile inherited source.
App dependency changes occur only after an independently implemented ABI bridge
can satisfy the typed engine contract; that later cutover removes the old
targets in the same slice. The precompiled Gecko kernel is the sole external
compatibility carrier.

**Tech Stack:** Swift 5, Objective-C++, UIKit, Foundation, Xcode OpenStep project
format, JSON contracts, Python 3 contract tests, POSIX shell runners.

**Baseline/Authority Refs:**

- `docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md`
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`
- `docs/provenance/substrate-boundary.md`
- `docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md`
- `docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md`
- `docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md`
- `docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md`
- `docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`

**Compatibility Boundary:** Preserve `com.vulpra.browser`, iOS 15, iPhone/iPad,
TrollStore-first packaging, OpenIn, existing Codable data, and the sole
`TabManager`/`BrowserTab` ownership model. Do not mutate or delete user data.
Do not route App traffic through the replacement targets until atomic cutover.

**Verification:** Linux portable gates prove ownership JSON, artifact fixture
validation, source-token boundaries, project structure, and deterministic
tests. They do not prove Xcode compilation, Gecko ABI linkage, simulator launch,
device behavior, JIT, or 60/120 Hz performance. Those remain explicit Mac and
physical-device gates.

ArchitectureReviewRequired: `yes`
TDD Route: `light`

## Plan Basis

### BaselineUsageDraft

- Required baseline refs: all nine authority refs listed above.
- Acknowledged before plan: all nine refs were read on `2026-07-26`.
- Cited in plan: all nine refs.
- Missing refs: exact binary ABI closure, independent process bootstrap proof,
  Mac/Xcode compilation, simulator navigation, and physical-device evidence.
- Decision: `continue` for source/contracts; `needs-verification` for runtime and
  device claims.

### Requirement Ready Check

- Requirement source: both approved `2026-07-26` design specifications and the
  user's explicit instruction to begin implementation.
- Goal and scope: binary Gecko only; independently owned bridge, process host,
  client, tests, and packaging.
- Acceptance: machine ownership gates, exact artifact validation, typed public
  contracts, staged targets, no fallback, and an explicit retirement trigger.
- Open blocker: none for Phase A source/contracts. Exact ABI calls are excluded
  until a header/symbol inventory is recorded.
- Decision: `ready`.

### Fact / Assumption / Unknown

- Fact: 14 App Swift files currently import `GeckoView`.
- Fact: the Xcode graph currently builds GeckoView and Vulpra Helper and embeds
  both products into the app.
- Fact: existing v3 artifacts are restored under `Vendor/firefox` and include
  GeckoView-specific bridge headers plus an idevice archive.
- Assumption: the precompiled kernel exposes enough stable ABI to launch without
  compiling inherited bridge source; Phase B must falsify or confirm this.
- Unknown: exact required headers, exported symbols, process bootstrap messages,
  and interpreter-mode startup sequence.

### Ripple Signal Triage

- Direct consumers: App imports, Xcode target dependencies, runtime artifact
  workflows, packaging scripts, portable graph/product tests, simulator jobs.
- Phase A affected consumers: documentation, independent tests, dormant targets,
  and the new artifact verifier only.
- Deferred consumers: App, package embedding, runtime workflows, and simulator
  launch change during the atomic cutover plan.
- Result: broaden structural verification now; do not rewrite production
  workflows before the v4 artifact has real producer evidence.

### Architecture Integrity Lens

- Invariant: App has exactly one active engine adapter and no fallback.
- Canonical future owners: `Engine/VulpraEngineKit`,
  `Engine/VulpraEngineProcess`, and `Tools/Engine`.
- Current temporary owner: inherited GeckoView/Helper remains the only active
  runtime until the replacement is independently functional.
- Responsibility overlap: dormant replacement targets contain contracts and
  independently authored source only; they do not wrap, import, or invoke the
  old adapter.
- Higher-level simplification: one ownership manifest drives positive and
  negative path checks instead of scattering path lists across tests.
- Retirement falsifier: if atomic cutover requires a compatibility wrapper or
  leaves either old target active, the design has not been achieved.
- Verdict: `proceed` with a staged target and atomic retirement trigger.

### Anti-Entropy Declaration

- Deletion class: `code-retirement` and `contract-carrying code`.
- Old path: imported GeckoView, Helper, VulpraRuntime, patches, source producer,
  and their Xcode targets.
- New canonical owner: VulpraEngineKit, VulpraEngineProcess, VulpraExecution,
  and the binary artifact contract.
- Preserved behavior: existing App/data identity and eventually full browser
  behavior.
- Retired behavior: inherited integration, inherited JIT, source build path, and
  all compatibility fallback.
- External boundary: yes, checksum-pinned Gecko binary only.
- Source-of-truth data risk: none in Phase A.
- User confirmation required: no for code retirement; persistent data is out of
  scope and cannot be deleted.

Retirement Decision:

- Path: `delete-first` at atomic cutover; temporary dormant target staging before
  cutover.
- Why: deleting the currently active adapter before the replacement can launch
  would intentionally break the product, while compiling both into App would
  violate the single-owner invariant.
- Non-edits: no user data, bundle identity, App feature behavior, packaging
  workflow, or active target dependency changes in Tasks 1-4.

### Plan Pressure Test

- Owner/contract/retirement: explicit and machine-checkable.
- Architecture integrity: no App-facing wrapper around GeckoView is introduced.
- Verification scope: exact Linux tests; Mac/device claims remain open.
- Task executability: Tasks 1-5 run on Linux; Task 6 records the boundary for the
  next plan rather than pretending ABI work is complete.
- Pressure result: `proceed`.

### Complexity Budget

- Artifact class: shared contracts, engine adapter, process host, build graph,
  and test/tool owners.
- Target artifacts: each Swift/Objective-C++ owner below 350 lines; each Python
  test/verifier below 350 lines; `project.pbxproj` below 800 lines.
- Current pressure: project graph 263 lines; existing App owners remain under
  the repository's 350-line owner review threshold.
- Projected pressure: within budget if public engine types are split by runtime,
  session, events, and capabilities rather than one facade.
- Planned governance: no third-party dependency, no generic manager, no raw
  Gecko payload in public types, and separate fixture/artifact tests.
- Budget result: `within-budget` for Phase A.

## Task 1: Approve authority and add a machine ownership map

**Files:** modify the two `2026-07-26` specs; create
`Configuration/engine-ownership.json`,
`Tests/IndependentEngine/test_ownership.py`, and
`Tests/IndependentEngine/run-portable.sh`.

**Why:** replace prose-only ownership with one deterministic source that can
reject accidental compilation or retention of inherited owners.

**Impact/Compatibility:** documentation and tests only. The ownership map marks
the current state as `staged` and names `atomic-cutover` as the only transition;
it does not grant the old source long-term compatibility.

- [ ] **Write the failing test.** Require schema version 1, approved spec paths,
  allowed external artifact classes, future owned roots, retired roots, preserved
  owners, `staged -> atomic-cutover -> independent` states, and a cutover rule
  that rejects App fallback or simultaneous active adapters. Require every
  configured path to be normalized, unique, and repository-relative.
- [ ] **Verify RED.** Run
  `python3 Tests/IndependentEngine/test_ownership.py`; expect a missing
  `Configuration/engine-ownership.json` failure.
- [ ] **Implement minimal ownership JSON.** Record only source owners and
  transition rules already approved by the design. Do not record generated
  outputs or infer ABI headers.
- [ ] **Verify GREEN.** Run the independent runner, `python3 -m json.tool` on the
  manifest, and `git diff --check`.
- [ ] **Commit boundary:** stage the two specs, ownership JSON, tests, plan, work
  records, and index as one reviewable planning/authority change. Do not create a
  Git commit unless the user requests it.

## Task 2: Define and verify the binary Gecko artifact v4 layout

**Files:** create `Configuration/engine-artifact-v4.json`,
`Tools/Engine/verify-engine-artifact.py`, and
`Tests/IndependentEngine/test_artifact_contract.py`; modify the independent
runner.

**Why:** make the sole external compatibility carrier exact, inspectable, and
safe before any bridge code consumes it.

**Impact/Compatibility:** the verifier reads a supplied `.build/engine` fixture
or restored root. It does not fetch, patch, or build Gecko and does not replace
the v3 production workflow until external v4 producer evidence exists.

- [ ] **Write the failing fixture tests.** Cover a valid manifest and payload;
  missing XUL; missing dylib; empty headers/resources; undeclared file; checksum
  mismatch; size mismatch; duplicate manifest path; absolute/traversal path;
  symlink; forbidden GeckoView framework, Helper, JIT, patch, source, executable,
  and product UI entries; wrong platform/architecture/format/ABI.
- [ ] **Verify RED.** Run the artifact test and expect the missing verifier or
  contract failure.
- [ ] **Implement minimal contract and verifier.** Require `formatVersion: 4`,
  artifact/build/source identity, platform `iphoneos`, architecture `arm64`, ABI
  version, licenses/notices, and a sorted file list containing relative path,
  byte size, and lowercase SHA-256. Allow only `runtime/bin`, `runtime/lib`,
  `runtime/include`, `runtime/resources`, and `licenses`.
- [ ] **Verify GREEN.** Run the independent runner twice, confirm deterministic
  output, run Python bytecode compilation, and run `git diff --check`.
- [ ] **Commit boundary:** stage contract, verifier, and tests together; do not
  alter v3 workflows in this task.

## Task 3: Add the VulpraEngineKit public contract skeleton

**Files:** create `Engine/VulpraEngineKit/Public/EngineCapabilities.swift`,
`EngineRuntime.swift`, `EngineSession.swift`, `EngineEvents.swift`, and
`EngineView.swift`; create
`Tests/IndependentEngine/test_public_contract.py`; modify the runner.

**Why:** give App a Vulpra-owned typed boundary before any Gecko ABI details or
feature migration are introduced.

**Impact/Compatibility:** dormant source only. It must not import GeckoView,
expose Gecko names, raw dictionaries, opaque pointers, or implement a fallback.

- [ ] **Write the failing contract test.** Require the approved public owners and
  signatures for runtime readiness/capabilities, session lifecycle/navigation,
  view attachment, navigation/progress/crash events, and exactly-once async
  request cancellation. Reject `Gecko`, `[String: Any]`, `Unsafe*Pointer`,
  `NotificationCenter`, singleton state, WebKit, and inherited imports.
- [ ] **Verify RED.** Run the test and expect missing public source files.
- [ ] **Implement minimal public types.** Use Swift value types and protocols;
  isolate UIKit view access to `@MainActor EngineView`; use identifiers owned by
  Vulpra and `Sendable` values where valid. Do not create an ABI implementation.
- [ ] **Verify GREEN.** Run structural tests, compile platform-neutral Swift
  value-type sources when the host Swift toolchain permits, check file sizes,
  and run `git diff --check`.
- [ ] **Commit boundary:** stage public contracts and tests only.

## Task 4: Add independent ABI and process-host boundaries without behavior

**Files:** create `Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.h`,
`EngineABIBridge.mm`, `Engine/VulpraEngineProcess/Info.plist`,
`EngineProcessBootstrap.swift`, and
`Tests/IndependentEngine/test_internal_boundaries.py`; modify the runner.

**Why:** constrain Gecko headers and opaque pointers to one internal layer and
make child-process bootstrap ownership explicit before implementing calls.

**Impact/Compatibility:** the ABI bridge declares only a Vulpra-owned lifecycle
surface and does not include an unverified Gecko header. The process skeleton
validates bootstrap input but cannot launch Gecko yet.

- [ ] **Write failing boundary tests.** Require Gecko artifact headers to be
  includable only under `Internal/ABI`; reject them from Public and App; require
  opaque pointer storage only in the `.mm` owner; require process bootstrap
  arguments to be typed, validated, and free of browser/tab/product state.
- [ ] **Verify RED.** Run the test and expect missing internal/process owners.
- [ ] **Implement minimal boundaries.** Define a C-compatible Vulpra ABI bridge
  lifecycle declaration with unavailable implementation status; define a
  Foundation process bootstrap parser for documented Vulpra-owned arguments.
  Do not fabricate Gecko symbol names or start a process.
- [ ] **Verify GREEN.** Run the independent runner, plist parsing, forbidden-token
  scans, file budgets, and `git diff --check`.
- [ ] **Commit boundary:** stage internal/process skeletons and tests together.

## Task 5: Add dormant independent targets to the Xcode graph

**Files:** create `Configuration/EngineKit.xcconfig` and
`Configuration/EngineProcess.xcconfig`; modify
`Vulpra.xcodeproj/project.pbxproj`,
`Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme`,
`Tests/IndependentEngine/test_xcode_staging.py`, and the independent runner.

**Why:** make the new owners buildable and reviewable without routing App
traffic through an incomplete engine.

**Impact/Compatibility:** add `VulpraEngineKit.framework` and
`Vulpra Engine Process.appex` targets, but do not add them as Vulpra target
dependencies or embed products. Existing GeckoView/Helper remains the sole
active runtime for this staging state.

- [ ] **Write the failing Xcode staging test.** Require both independent targets,
  source groups, configs, bundle identities, iOS 15/arm64 settings, and no
  inherited root membership. Require Vulpra not to depend on or embed either new
  product during `staged`; reject EngineKit dependency on GeckoView and reject
  simultaneous new/old products in App framework or extension embed phases.
- [ ] **Verify RED.** Run the test and expect missing target/config failures.
- [ ] **Implement minimal graph additions.** Add deterministic project IDs,
  synchronized groups, build phases, products, configs, and scheme build entries.
  Keep App dependency and embed phases unchanged.
- [ ] **Verify GREEN.** Run old and new graph tests, XML/plist parsing, target
  tuple checks, line budgets, and `git diff --check`.
- [ ] **Commit boundary:** stage graph/config/test changes together.

## Task 6: Close Phase A source evidence and prepare atomic cutover

**Files:** create `Tests/IndependentEngine/test_cutover_readiness.py`; modify
`README.md`, the independent runner, work checkpoint/evidence/drift records, and
the Aegis index if needed.

**Why:** prevent the dormant staging state from being mistaken for completed
independence and provide an exact entry condition for the Phase B ABI plan.

**Impact/Compatibility:** no active runtime changes. Phase A remains
`needs-verification` for Xcode and ABI behavior until external evidence exists.

- [ ] **Write the readiness test.** Report, without passing cutover, the exact
  remaining blockers: verified v4 artifact, ABI header/symbol inventory,
  interpreter-mode runtime startup, independent child process, App protocol
  migration, old target removal, package update, simulator navigation, and
  physical-device evidence. Fail if a runtime fallback appears.
- [ ] **Verify RED.** Run readiness in `--require-cutover` mode and expect a
  deterministic not-ready result listing all remaining gates.
- [ ] **Implement source closeout.** Document that new targets are dormant and
  old runtime ownership is temporary; write the next-plan inputs without
  claiming independent runtime completion.
- [ ] **Verify GREEN.** Run Bootstrap, RuntimeShell, Browser, and IndependentEngine
  portable suites; run JSON/plist/XML validation, Python compilation, forbidden
  source scans, complexity report, dependency inventory, `git diff --check`,
  and Aegis workspace check/bundle.
- [ ] **Commit boundary:** stage closeout records. Do not commit, delete old code,
  or change production workflows without explicit subsequent execution scope.

## Risks

- The precompiled kernel may not expose a sufficient stable ABI; Phase B must
  inspect exact headers and symbols rather than reproduce inherited bridge code.
- An app-extension target may not match the kernel's process bootstrap contract;
  Xcode and runtime evidence must decide the target product type.
- Existing v3 workflows build and package inherited source. They remain current
  only until verified v4 production and atomic cutover, not as a fallback.
- Linux structural tests can miss Swift/Objective-C++ type and linkage failures.
- Broad App migration can accidentally alter persistence or privacy behavior;
  it belongs in a separate capability-ordered plan.

## Retirement And Follow-Up

- Phase A retirement status: prepared, not executed.
- Phase B entry evidence: exact artifact v4 payload plus ABI/header/symbol
  inventory and a Mac capable of compiling the independent bridge.
- Atomic cutover must migrate App imports and delegates, switch dependencies and
  embeds, remove old targets and source roots from the graph, and update
  packaging in one no-fallback workstream.
- After runtime/package verification, create or supersede the architecture ADR
  and baseline; do not rewrite the old ADR as if it had always described the new
  architecture.
