# Vulpra Runtime Shell Phase 1A Implementation Plan

> Execute inline in the isolated `feature/vulpra-runtime-shell` worktree. Do not
> use subagents. Follow the approved design and stop on any excluded-client
> dependency or unresolved Xcode ownership contradiction.

**Goal:** Commit a fresh four-target native Xcode graph, minimal iOS 15+ UIKit
runtime shell, exactly-once JIT readiness owner, deterministic Gecko/idevice
producer contracts, and unsigned IPA/TIPA packaging tools that pass all Linux
portable gates while leaving Mac/Xcode/device evidence explicitly open.

**Architecture:** `Vulpra.xcodeproj` owns products, dependencies, membership,
and build phases. Small `.xcconfig` files own settings. `App/` owns launch,
scene, URL routing, the smoke Gecko session, and JIT orchestration. Existing
`Extensions/GeckoView`, `Extensions/Helper`, and `Modules/VulpraRuntime` remain
the substrate. `Tools/Runtime` owns prerequisite/artifact production;
`Tools/Release` owns archive/package production. Generated artifacts remain in
`.build/` and `dist/`.

**Tech Stack:** Swift 5, Objective-C/Objective-C++, C, UIKit, GeckoView, Xcode
OpenStep project format, XML plist/scheme files, POSIX shell, Python 3 portable
tests, GitHub Actions Ubuntu portable gate.

**Baseline/Authority Refs:**

- `docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md`
- `docs/aegis/baseline/2026-07-21-initial-baseline.md`
- `docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md`
- `docs/provenance/substrate-boundary.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`

**Compatibility Boundary:** iOS deployment target 15.0; arm64 device-first;
TrollStore-first private entitlement profile; no old Client/UI/store/resource/
Xcode/data owner; no old identity fallback; no generated archive in maintained
source roots. Passing Linux checks proves Phase 1A source/contracts only, not
Xcode compilation, IPA creation, or device operation.

**Verification:** Each task has a targeted RED/GREEN check and commit. Final
portable closeout runs all Bootstrap and RuntimeShell tests, artifact/package
fixtures, shell/Python/plist/XML validation, manifest regeneration, active
identity, complexity/dependency inventories, Aegis bundle/check, and clean Git
status. Phase 1B commands remain unexecuted until a Mac is available.

## Plan Basis

### BaselineUsageDraft

- Required refs: approved runtime-shell design, initial baseline, ADR-0001,
  substrate boundary, efficiency policy.
- Acknowledged before plan: all five.
- Cited in plan: all five.
- Missing refs: fresh Xcode/SDK, Gecko producer, IPA, and iOS 15.8 device
  evidence.
- Decision: `continue` for Phase 1A; `needs-verification` for Phase 1B.

### Requirement Ready Check

- Requirement source: approved written design plus user selection of no-current-
  Mac execution.
- Goal/scope/scenario: confirmed.
- Requirement items: R1-R12 in the approved design.
- Acceptance: portable Phase 1A and Mac Phase 1B are separately defined.
- Open blocker questions: none for Phase 1A.
- Decision: `ready`.

### Architecture Integrity Lens

- Invariant: exactly one owner for target membership, launch, URL routing, JIT
  readiness, artifact production, and packaging.
- Canonical contracts: four-target Xcode graph; Gecko child readiness pipe;
  `.build/` and `dist/` generated roots.
- Responsibility overlap: `Utils.m` is one shared source compiled into two
  binaries, not forked logic; no copied JIT controller or package script.
- Higher-level simplification: `.xcconfig` removes duplicated per-configuration
  settings; separate portable package helper avoids test-only branches.
- Retirement/falsifier: old Xcode/client/JIT UI remain absent; any required old
  owner stops execution.
- Verdict: `proceed`, with ADR/baseline sync at closeout.

### Plan Pressure Test

- Owner/contract/retirement: explicit.
- Verification: portable semantic contracts plus deferred Mac evidence.
- Executability: all Phase 1A commands run on Linux; Mac commands are recorded,
  not reported as executed.
- Pressure result: `proceed`.

### Plan-Time Complexity Check

- Project graph target: below 800 lines; use synchronized groups and xcconfigs.
- Runtime owner target: below 250 lines each; JIT coordinator below 220.
- Producer/package scripts: below 250 lines each.
- Tests: separate graph, runtime, artifact, and packaging owners below 350.
- Existing pressure: retired 969-line Phase 0 plan only.
- Recommendation: add owner files; do not extend the existing 308-line import
  boundary test with runtime responsibilities.

## Task 1: Create the fresh Xcode graph and configuration owners

**Files:** create `Vulpra.xcodeproj/project.pbxproj`,
`Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme`,
`Configuration/{Base,App,GeckoView,Helper,OpenIn}.xcconfig`, and
`Tests/RuntimeShell/test-xcode-graph.py`.

**Why:** establish an independently owned graph without copying the old project
or introducing a project generator.

**Impact/Compatibility:** graph-only; referenced source directories may be added
in later tasks. No Mac completion claim.

**Complexity Budget:** `project.pbxproj < 800` lines; each xcconfig `< 100`.
If explicit file references cross the budget, revise synchronized-group
exceptions rather than accepting the overrun.

- [ ] **Write the failing graph test.** Create an executable Python test that
  requires `Vulpra.xcodeproj`, parses balanced OpenStep braces/comments, and
  asserts exactly these target tuples:
  `Vulpra/application`, `GeckoView/framework`,
  `Vulpra Helper/app-extension`, `OpenIn/app-extension`. Require one shared
  Vulpra scheme, app dependencies on all support targets, framework/plugin embed
  phases, five xcconfig references, source group paths, no `Reynard` token,
  no team ID/profile, and `project.pbxproj < 800` lines.
- [ ] **Verify RED.** Run
  `python3 Tests/RuntimeShell/test-xcode-graph.py`; expect
  `FAIL: missing Vulpra.xcodeproj/project.pbxproj`.
- [ ] **Implement the minimal graph.** Hand-author object version 77 project
  objects with deterministic 24-character IDs. Use synchronized groups for
  `App`, `Modules`, `Extensions/GeckoView`, `Extensions/Helper`, and
  `Extensions/OpenIn`; add membership exceptions for plists, entitlements,
  `ptrace_jit.c`, Helper-only files, and shared `Utils.m`. Put the artifact
  preflight shell phase before Sources and the Gecko payload copy phase after
  embed phases. Base settings include iOS 15.0, arm64, no Catalyst/Mac/visionOS,
  and no signing team. App settings link `GeckoView`, Gecko libraries, and the
  generated idevice archive. Create Debug/Release configs and one shared scheme.
- [ ] **Verify GREEN.** Run the graph test, XML-parse the scheme with Python,
  run `git diff --check`, and confirm no new file is 800+ lines.
- [ ] **Commit.** `git add Vulpra.xcodeproj Configuration Tests/RuntimeShell && git commit -m "build: add fresh Vulpra Xcode graph"`.

## Task 2: Add app metadata, entitlement profiles, and URL routing

**Files:** create `App/Info.plist`,
`App/Entitlements/Vulpra.entitlements`,
`App/Entitlements/Vulpra.private.entitlements`,
`App/RuntimeURLRouter.swift`, and
`Tests/RuntimeShell/test-product-contracts.py`; modify the Xcode graph only if
membership exceptions need correction.

**Why:** pin iOS 15 identity and input contracts before engine/UI code.

**Impact/Compatibility:** no persistence or old URL scheme. Invalid input degrades
to the smoke URL without a second parser/fallback.

- [ ] **Write the failing product-contract test.** Require app/GeckoView/Helper/
  OpenIn bundle IDs, `vulpra` scheme, scene manifest, `UILaunchScreen`, iPhone+
  iPad families, app entitlement key sets, absence of uncertain web-browser/
  persona/storage/get-task-allow keys, and router source with only `http`,
  `https`, and `vulpra://open?url=` cases.
- [ ] **Verify RED.** Run the test; expect missing `App/Info.plist`.
- [ ] **Implement metadata and router.** Use an XML plist with no asset catalog
  dependency. Implement `RuntimeURLRouter.resolve(_:) -> URL?` as a pure type:
  direct web URLs pass, custom scheme extracts one `url` item and revalidates
  web scheme, all else returns nil. Author standard/private entitlement plists
  from the approved key inventory.
- [ ] **Verify GREEN.** Run the product test and parse every new plist with
  `plistlib`; run active identity and diff checks.
- [ ] **Commit.** `git add App Vulpra.xcodeproj Tests/RuntimeShell && git commit -m "feat: define Vulpra runtime identity"`.

## Task 3: Implement the minimal UIKit Gecko runtime shell

**Files:** create `App/main.swift`, `App/AppDelegate.swift`,
`App/SceneDelegate.swift`, `App/RuntimeShellViewController.swift`, and
`Tests/RuntimeShell/test-runtime-shell.py`.

**Why:** prove one Gecko session can be owned without reviving browser UI,
tabs, stores, or migration.

**Impact/Compatibility:** smoke-only owner; explicitly retired by the future
browser UI plan. No final chrome or state persistence.

- [ ] **Write the failing runtime-shell test.** Require the four files and assert
  `main.swift` calls JIT start before `GeckoRuntime.main`; AppDelegate contains
  only launch/scene configuration; SceneDelegate owns one window/root and routes
  incoming URLs; the view controller owns one `GeckoSession`, opens once,
  embeds `engineView` with constraints, loads `https://example.com/`, toggles
  active/focused state, and closes on teardown. Reject tokens for tabs, stores,
  preferences, migration, address bar, bookmarks, downloads, or WebKit.
- [ ] **Verify RED.** Run the test; expect missing `App/main.swift`.
- [ ] **Implement minimal source.** `main.swift` imports Foundation, UIKit, and
  GeckoView. SceneDelegate creates a plain system-background window and exposes
  one `open(_:)` call to the runtime shell. The view controller shows a small
  failure label only when `engineView` is absent; it never creates a fallback
  renderer.
- [ ] **Verify GREEN.** Run runtime-shell, product-contract, graph, plist, active
  identity, and diff checks. Measure each owner; none may exceed 250 lines.
- [ ] **Commit.** `git add App Tests/RuntimeShell && git commit -m "feat: add minimal Gecko runtime shell"`.

## Task 4: Add the exactly-once JIT readiness owner and bridge cleanup

**Files:** create `App/RuntimeJITCoordinator.swift`,
`App/Bridging/Vulpra-Bridging-Header.h`, and
`Tests/RuntimeShell/test-jit-orchestration.py`; modify
`Extensions/GeckoView/View/GeckoView.h` to remove the stale `TSUtils.h` import.

**Why:** unblock every Gecko child readiness pipe without copying old JIT UI,
settings, retry policy, or diagnostics.

**Impact/Compatibility:** JIT success is TrollStore-first; failure becomes
explicit Gecko JIT-disabled status. No silent wait/fallback.

**Repair Track:** stale `TSUtils.h` has no owner and must be deleted, not shimmed.
**Retirement Track:** source JITController/UI remains absent; this coordinator
is the only product owner.

- [ ] **Write the failing orchestration test.** Require coordinator and bridge;
  assert one attach queue, one state queue, a 4.5-second deadline, pending PID
  ownership, duplicate suppression, tab-only enablement, false reporting for
  non-tab/failure/deadline/teardown, atomic pending removal before
  `ReportJITStatusForChild`, `hasTXMSupport: false`, and no copied retry/UI/
  prefs/diagnostics tokens. Add quoted-header closure that fails on `TSUtils.h`.
- [ ] **Verify RED.** Run it; expect missing coordinator or unresolved
  `TSUtils.h`.
- [ ] **Implement minimal owner.** Observe the exact Gecko notification; create
  a per-PID pending token on the state queue; schedule 4.5-second false finish;
  run attachment on the attach queue; finish on state queue only if still
  pending; call the C report once after removal. On teardown, finish pending
  false, remove observer, and detach sessions. Keep logging via `os.Logger`.
  Bridge only JIT/native/Gecko public contracts. Delete the stale import.
- [ ] **Verify GREEN.** Run orchestration, local-header, runtime-shell, JIT
  substrate, active identity, and diff checks. Coordinator must be `< 220` lines.
- [ ] **Commit.** `git add App Extensions/GeckoView/View/GeckoView.h Tests/RuntimeShell && git commit -m "feat: orchestrate Vulpra child JIT readiness"`.

## Task 5: Add the new OpenIn extension owner

**Files:** create `Extensions/OpenIn/Info.plist`,
`Extensions/OpenIn/OpenInViewController.swift`, and
`Tests/RuntimeShell/test-open-in.py`.

**Why:** prove external URL delivery without copying the old extension or
starting final browser UI.

**Impact/Compatibility:** one public host-opening path only. A physical-device
failure triggers a design amendment; no pre-emptive private fallback.

- [ ] **Write the failing extension test.** Require a one-web-URL activation
  rule, Vulpra principal/error identity, extraction using UniformTypeIdentifiers,
  encoded `vulpra://open?url=`, exactly one completion/cancellation gate, and
  `NSExtensionContext.open`. Reject `LSApplicationWorkspace`, responder-chain
  `openURL:`, Reynard strings, and multiple opening functions.
- [ ] **Verify RED.** Run it; expect missing OpenIn source.
- [ ] **Implement minimal extension.** Use one completion-state boolean guarded
  on main actor; load the first URL provider, create the custom URL, call
  `extensionContext.open`, then complete or cancel exactly once.
- [ ] **Verify GREEN.** Run OpenIn, product, graph, plist, active identity, and
  diff checks.
- [ ] **Commit.** `git add Extensions/OpenIn Tests/RuntimeShell && git commit -m "feat: add Vulpra OpenIn extension"`.

## Task 6: Govern Gecko and idevice artifact production

**Files:** modify `Tools/Gecko/build-gecko.sh`,
`Tools/Gecko/build-idevice.sh`, `Tools/Gecko/gecko-artifact.sh`,
`Tools/Gecko/test-gecko-artifact.sh`, and `Tools/Build/AddGecko.sh`; create
`Tools/Runtime/check-macos-prerequisites.sh`,
`Tools/Runtime/verify-runtime-artifacts.sh`,
`Tools/Runtime/build-runtime-substrate.sh`, and
`Tests/RuntimeShell/test-runtime-artifacts.sh`.

**Why:** generated libraries/framework payload need one producer and must never
write into maintained modules or rebuild silently inside Xcode.

**Impact/Compatibility:** artifact format advances from v2 to v3 because iOS
15.0 and SDK fingerprint enter the key. No artifact is built on Linux.

**Repair Track:** idevice output currently pollutes `Modules/` and both producer
scripts target iOS 13.0.
**Retirement Track:** old output path and deployment target are deleted with no
compatibility copy.

- [ ] **Write the failing artifact tests.** Require deployment `15.0`, idevice
  output `.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a`, no write
  under Modules, format v3 key sensitivity to Xcode+SDK+Firefox+patch/build
  inputs, required `IOSBootstrap.h`/`GeckoViewSwiftSupport.h`, XUL/dylibs/theme,
  Linux `needs-macos` status, and build orchestration order. Extend fixture
  assertions for stale format/SDK rejection.
- [ ] **Verify RED.** Run tests; expect old iOS 13/module output failures.
- [ ] **Implement producer contracts.** Change Gecko/idevice deployment to 15.0;
  put Cargo target/output under `.build/idevice`; make prerequisite checker
  read-only and return code 78 with `needs-macos` on non-Darwin; make artifact
  verifier print exact missing paths; make orchestrator call prerequisite,
  submodule, idevice, Gecko, artifact verify in order. Advance artifact key/
  manifest to v3 with `VULPRA_XCODE_BUILD` and `VULPRA_SDK_BUILD`. Correct
  AddGecko root paths and require verified payload before copying.
- [ ] **Verify GREEN.** Run runtime artifact and Gecko artifact fixtures,
  gecko-substrate regression, shell syntax, active identity, import manifest
  regeneration, and diff checks. Confirm no generated file appears.
- [ ] **Commit.** `git add Tools Tests/RuntimeShell docs/provenance/import-manifest.tsv && git commit -m "build: govern Vulpra runtime artifacts"`.

## Task 7: Add archive, ptrace, IPA, and TIPA producers

**Files:** create `Tools/Release/build-app.sh`,
`Tools/Release/build-ptrace-jit.sh`, `Tools/Release/package-app.sh`,
`Tools/Release/create-ipa.sh`, and
`Tests/RuntimeShell/test-release-packaging.sh`.

**Why:** provide deterministic Phase 1B commands without copying or mutating the
old release workflow.

**Impact/Compatibility:** scripts operate only in `dist/` and temporary staging.
Public release remains blocked; output is engineering evidence.

- [ ] **Write the failing package fixture.** Build a fake
  `dist/Vulpra.xcarchive/Products/Applications/Vulpra.app` containing fake
  GeckoView, Helper, OpenIn, XUL, and dylib files. Require the portable packager
  to verify bundle-ID marker files, refuse missing products, avoid modifying the
  archive, create Payload archives named `Vulpra.ipa` and
  `Vulpra-TrollStore.tipa`, and write deterministic SHA-256 output manifest.
  Source-contract assertions require xcodebuild signing-off archive, iPhoneOS
  clang deployment 15.0, ptrace entitlements, ldid signing in a copied stage,
  and no hard-coded team/plutil bundle-ID rewrite.
- [ ] **Verify RED.** Run the fixture; expect missing release scripts.
- [ ] **Implement four small owners.** `build-app.sh` runs the exact generic iOS
  archive command after runtime artifact verification. `build-ptrace-jit.sh`
  compiles into `.build/ptrace-jit` and optionally signs a requested output.
  `package-app.sh` accepts archive/app/stage/output paths and performs only
  validation, copy, zip, and checksums. `create-ipa.sh` composes ptrace/signing
  and portable packaging without mutating the archive.
- [ ] **Verify GREEN.** Run package fixture twice and compare manifests; run all
  refusal cases, shell syntax, active identity, generated-output absence, and
  diff checks. Each script must be `< 250` lines.
- [ ] **Commit.** `git add Tools/Release Tests/RuntimeShell && git commit -m "build: add Vulpra IPA producers"`.

## Task 8: Add one canonical portable runtime-shell gate

**Files:** create `Tests/RuntimeShell/run-portable.sh`; modify
`.github/workflows/bootstrap-core.yml`,
`Tests/Bootstrap/test-repository-shape.sh`, and
`Tests/Bootstrap/test-repository-shape-nested-parent.sh`.

**Why:** prevent project/runtime/package drift without adding another workflow
owner.

**Impact/Compatibility:** Ubuntu remains dependency-free and does not initialize
submodules or claim Xcode compilation.

- [ ] **Write the failing shape/CI checks.** Require `run-portable.sh` and require
  the existing workflow to invoke it after all Bootstrap tests. Require the
  runner to execute graph, product, runtime shell, JIT, OpenIn, artifact, and
  packaging tests. Update nested fixture required paths so its intended Git-root
  failure remains first.
- [ ] **Verify RED.** Run repository shape; expect missing runtime-shell runner
  or workflow command.
- [ ] **Implement the runner and workflow update.** Runner uses `set -eu`, finds
  repository root, invokes each executable test in a fixed order, syntax-checks
  maintained scripts, parses all plists/scheme XML, and ends with diff check.
  Workflow installs no packages and keeps `submodules: false`.
- [ ] **Verify GREEN.** Run Bootstrap suite, runtime runner, workflow YAML parse,
  no-install scan, shell syntax, Aegis check, and diff check.
- [ ] **Commit.** `git add .github Tests && git commit -m "ci: verify Vulpra runtime shell contracts"`.

## Task 9: Record the Phase 1A portable baseline and architecture decision

**Files:** create
`docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md`;
create or amend a target ADR through the Aegis helper; modify
`docs/aegis/INDEX.md`, the runtime-shell work records, and any README/building
entry needed to point Mac users to the producer sequence.

**Why:** distinguish verified source/contracts from missing Mac/IPA/device facts
and preserve the new Xcode/JIT/artifact ownership trade-offs.

**Impact/Compatibility:** documentation only; status must not say IPA-ready.

- [ ] **Write the failing baseline test.** Extend repository shape to require a
  latest baseline status `runtime-shell-portable-verified`, exact target graph/
  bundle IDs/deployment target, current commit and manifest/artifact contract
  hashes, size/line accounting, passing portable commands, and explicit
  `needs-verification` entries for Xcode, Gecko rebuild, IPA/TIPA, OpenIn device
  behavior, and iOS 15.8 launch.
- [ ] **Verify RED.** Run shape test; expect missing runtime-shell baseline.
- [ ] **Implement closeout records.** Record exact Phase 1A evidence and separate
  Vendor/Patches, active runtime, project/config, app source, tests/tools, and
  generated-output deltas. Run ADR creation gate and record checked-in native
  graph, portable/Mac evidence split, exactly-once JIT owner, and generated
  artifact locations. Update work checkpoint/evidence/drift/reflection and
  bundle/check. Add concise Mac command sequence:
  `check-macos-prerequisites.sh`, `build-runtime-substrate.sh`,
  `build-app.sh`, `create-ipa.sh`.
- [ ] **Verify GREEN.** Run shape, Aegis check, baseline/ADR index checks,
  placeholder scan, complexity report, and diff checks.
- [ ] **Commit.** `git add docs Tests/Bootstrap && git commit -m "docs: baseline Vulpra runtime shell source"`.

## Task 10: Run Phase 1A final closeout

**Files:** verification only, except deterministic work-record bundle updates if
needed.

**Why:** establish fresh evidence at the exact final commit before any Phase 1A
completion claim.

- [ ] **Run the full portable gate.** Execute all six Bootstrap tests,
  `Tools/Gecko/test-gecko-artifact.sh`,
  `Tests/RuntimeShell/run-portable.sh`, all maintained shell syntax checks,
  Python compile checks, plist/scheme/workflow parsing, manifest regeneration+
  compare, active identity, exclusion scans, dependency inventory, maintained
  pressure report, Aegis checks, and `git diff --check`.
- [ ] **Verify repository hygiene.** Require clean feature-worktree status, no
  generated archive/library/framework/IPA tracked, and no remote operation.
- [ ] **Record exact uncovered scope.** Linux has not run xcodebuild/zsh/macOS
  producer/device tests; Phase 1 overall remains `needs-verification`.
- [ ] **Update deterministic proof bundle if required.** Re-run Aegis bundle and
  check; commit only if generated work evidence changes.
- [ ] **Stop at Phase 1A.** Do not begin tabs/data or final UI. Hand off the exact
  Phase 1B Mac command sequence and final commit.

## Risks and stop conditions

- `PBXFileSystemSynchronizedRootGroup` semantics require a modern Xcode. If Mac
  validation rejects the graph, repair the graph owner; do not copy the old
  project.
- Generated Gecko headers may reveal a missing real producer contract. Repair
  the patch/build artifact owner; do not add fabricated compatibility headers.
- `libidevice_ffi.a` licensing must be captured before distribution.
- OpenIn's public host-opening path is unverified on device. Do not add a private
  fallback without device evidence and a design amendment.
- JIT attachment that exceeds 4.5 seconds reports disabled before Gecko's five-
  second timeout; late completion must never report again.
- Two SafariShared-derived patches remain public-release blockers.
- Any dependency on inherited Client/UI/store/resource/data/Xcode owners stops
  execution for architecture review.

## Retirement

- The Phase 0 bootstrap plan remains closed.
- Old Reynard project/client/JIT controller/OpenIn/release scripts remain absent.
- `RuntimeShellViewController` is a deliberate smoke owner and retires when the
  approved browser UI owner lands.
- Phase 1A closes at portable source verification; Phase 1B Mac evidence is a
  separate continuation, not a silent fallback or assumed pass.
