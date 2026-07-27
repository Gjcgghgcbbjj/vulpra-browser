# Vulpra Independent Engine Completion and IPA Plan

Date: `2026-07-26`
Status: `complete`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## Plan Basis

Complete the approved dependency direction:

```text
Precompiled Gecko Runtime -> VulpraEngineKit -> Vulpra App
```

The authoritative requirements are the two `2026-07-26` design specs and
ADR-0001 through ADR-0003. They preserve `com.vulpra.browser`, iOS 15,
iPhone/iPad, OpenIn, existing Codable data, and sole `TabManager`/`BrowserTab`
ownership. They prohibit inherited GeckoView, Helper, JIT, patch, or source
build code and prohibit a runtime fallback or two active adapters.

### BaselineUsageDraft

- Required refs: both `2026-07-26` specs and ADR-0001 through ADR-0003.
- Acknowledged before plan: all required refs on `2026-07-26`.
- Cited in plan: all required refs.
- Missing refs: Mac compile/link, simulator navigation, child-process runtime,
  and package evidence; these are execution gates, not requirement gaps.
- Decision: `continue`.

### Requirement Ready Check

- Requirement source: approved product and client designs plus the user's IPA
  completion instruction.
- Acceptance: real v4 artifact, independently authored ABI/session/process
  owners, full App migration, old-path retirement, simulator navigation, and a
  validated IPA.
- Open product questions: none.
- Decision: `ready`.

### Architecture Integrity Lens

- Invariant: exactly one App-facing adapter, owned by VulpraEngineKit.
- Canonical ABI owner: `Engine/VulpraEngineKit/Internal/ABI` only.
- Canonical process owner: `Engine/VulpraEngineProcess` only.
- Compatibility carrier: content-bound v4 binary artifact only.
- Retirement falsifier: any active GeckoView/Helper/JIT/source-build target,
  App import, workflow, fallback, or packaged payload.
- Verdict: proceed with one atomic App/Xcode/package cutover.

### Complexity Budget

- Public contracts stay split by feature; raw dictionaries remain internal.
- Runtime, dispatcher, router, session, and feature owners target 350 lines per
  maintained file. Large generated Xcode project and artifact manifests are
  excluded from source-owner thresholds.
- App controllers keep existing ownership; migration changes dependency types,
  not persistence ownership.
- Result: `within-budget` if ABI and event parsing remain separate owners.

## Task 1: Freeze the executable ABI and message contract

**Files:** `Configuration/engine-abi-inventory.json`, new
`Configuration/engine-message-contract.json`, `Tests/IndependentEngine/`, and
artifact ABI evidence.

- [x] Derive startup/window/process declarations only from the three direct
  artifact headers and exported-symbol inventory.
- [x] Derive command/event schemas from packaged Gecko runtime modules.
- [x] Add negative tests for invented shutdown, interpreter selector, public
  Gecko names, opaque pointers, raw public dictionaries, and fallback.
- [x] Verify deterministic inventory and the real v4 artifact.

## Task 2: Implement the independent VulpraEngineKit runtime

**Files:** `Engine/VulpraEngineKit/Public/`,
`Engine/VulpraEngineKit/Internal/ABI/`, new `Internal/Events/`,
`Internal/Runtime/`, `Internal/Session/`, and `Internal/Features/` owners.

- [x] Complete typed settings, navigation, prompt, permission, download,
  storage, context-menu, PiP, and extension contracts used by App.
- [x] Implement the Objective-C++ runtime object conforming to
  `SwiftGeckoViewRuntime`, the dispatcher conforming to
  `SwiftEventDispatcher`, and the sole calls to `MainProcessInit` and
  `GeckoViewOpenWindow`.
- [x] Validate dictionaries at the internal router and emit typed events.
- [x] Serialize session open/close and reject callbacks after close.
- [x] Expose a Vulpra-owned application main entry and runtime/service facade.
- [x] Compile and link on macOS against the restored arm64 artifact.

## Task 3: Implement the independent child-process host

**Files:** `Engine/VulpraEngineProcess/`, process plist/config/entitlements,
and process integration tests.

- [x] Parse the extension input endpoint and own the
  `GeckoProcessExtension` implementation.
- [x] Convert the `NSXPCListenerEndpoint` to the required XPC connection in the
  Objective-C++ ABI owner and call only `ChildProcessInit`.
- [x] Keep tab/browser/product state out of the extension.
- [x] Verify extension launch/connection evidence on macOS/simulator.

## Task 4: Migrate the App contract atomically

**Files:** all App files that import or name GeckoView types, while preserving
`TabManager`, `BrowserTab`, and Codable record owners.

- [x] Replace every App `import GeckoView` with `import VulpraEngineKit`.
- [x] Move startup to the Vulpra-owned main entry.
- [x] Migrate tab/session/view/navigation/progress, prompts, permissions,
  downloads, storage, context menu, PiP, and extension calls to typed APIs.
- [x] Remove inherited JIT coordination and represent current execution mode
  honestly as interpreter without fabricating an ABI switch.
- [x] Preserve normal-tab restoration and private-tab exclusion.
- [x] Run App source-contract and Codable compatibility checks.

## Task 5: Perform the Xcode and runtime artifact cutover

**Files:** `Vulpra.xcodeproj`, schemes, xcconfigs, runtime staging scripts, and
build workflows.

- [x] Make Vulpra depend on/embed VulpraEngineKit and Vulpra Engine Process.
- [x] Remove GeckoView and old Helper targets, build phases, products, configs,
  runpaths, and source membership in the same change.
- [x] Stage verified v4 XUL/dylibs/resources/headers/licenses without fetching or
  rebuilding Gecko during a normal App build.
- [x] Preserve OpenIn and canonical bundle identifiers.
- [x] Assert one adapter and zero old target references.

## Task 6: Retire inherited sources and workflows

**Files:** `Extensions/GeckoView`, `Extensions/Helper`,
`Modules/VulpraRuntime`, `Patches`, `Tools/Gecko`, old runtime/source workflows,
gitlinks, obsolete configs/tests, README, ownership/cutover manifests.

- [x] Delete old integration/JIT/patch/source-build owners after all references
  are removed.
- [x] Keep historical provenance documentation only.
- [x] Update portable tests so old roots and tokens are failures.
- [x] Set ownership state to independent only after runtime/package evidence.

## Task 7: Compile, launch, and verify navigation on macOS

**Files:** GitHub macOS workflow plus downloaded logs/screenshots.

- [x] Restore the pinned v4 artifact and verify it before compilation.
- [x] Build device archive and simulator application with Xcode.
- [x] Launch in a real simulator, navigate to a deterministic local/HTTPS page,
  capture UI/process logs, and prove process survival.
- [x] Confirm the independent process extension connects and no old runtime
  product is loaded.
- [x] Iterate only from real compiler/linker/runtime evidence.

## Task 8: Package and validate IPA/TIPA

**Files:** `Tools/Release/`, package workflow, `dist/`, completion evidence.

- [x] Package `Vulpra.ipa` and TrollStore TIPA from the verified archive.
- [x] Validate ZIP integrity, Mach-O architectures, bundle IDs, plists,
  entitlements/signatures, XUL/dylibs/resources/licenses, EngineKit, process
  extension, and OpenIn.
- [x] Reject GeckoView.framework, old Helper, ptrace/JIT, idevice, patch, or
  source payloads and references.
- [x] Record SHA-256 and download the verified IPA into local `dist/`.
- [x] Close every cutover gate with concrete evidence, run all portable suites,
  Aegis bundle/check, and `git diff --check` before reporting completion.

## Compatibility and Retirement

No data migration or deletion is authorized. Existing JSON models and bundle
identity remain unchanged. There is no compatibility adapter: old runtime
sources remain active only until Task 5's atomic switch, then Tasks 5 and 6
remove their graph and files together. Failure to compile or launch rolls the
current implementation task back for repair; it does not reopen a fallback
design.

## Verification Commands

```bash
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
python3 Tools/Engine/verify-engine-artifact.py --root .build/engine
python3 Tools/Engine/inventory-engine-abi.py --root .build/engine --output /tmp/abi.json
git diff --check
```

macOS evidence additionally requires `xcodebuild archive`, simulator install /
launch/navigation, extension logs, and IPA validation. Linux success never
closes those gates.
