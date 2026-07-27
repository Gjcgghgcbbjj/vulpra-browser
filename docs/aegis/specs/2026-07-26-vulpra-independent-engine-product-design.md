# Vulpra Independent Engine Product Design

Date: `2026-07-26`
Status: `approved-by-user`
ArchitectureReviewRequired: `yes`

## 1. Decision

Vulpra will remain a Gecko browser, but its source tree will no longer contain
or compile browser integration source imported from Reynard. The only retained
external runtime boundary is a checksum-pinned, precompiled Gecko kernel
artifact. Vulpra will independently own the engine adapter, process host,
browser product, persistence, interface, animation system, tests, and package
orchestration.

The new canonical dependency direction is:

```text
Precompiled Gecko kernel artifact
             |
             v
      VulpraEngineKit
             |
             v
         Vulpra App
```

`VulpraEngineKit` is a new Vulpra-authored module. Product code must not import
`GeckoView` or expose Gecko-specific types in App-owned contracts.

## 2. Authority and supersession

This design records the user's approved direction from `2026-07-26`:

- retain the already compiled Gecko kernel;
- do not retain inherited browser integration source;
- independently implement the Vulpra engine adapter;
- make high performance, polished visual quality, fluid animation, and 120 Hz
  behavior part of acceptance.

For engine ownership and source-retirement decisions, this design supersedes:

- `docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md`;
- engine-source assumptions in
  `docs/aegis/specs/2026-07-22-vulpra-modern-browser-product-design.md`;
- owner maps in the 2026-07-22 runtime and package baselines.

The existing Vulpra product behavior, local data formats, bundle identity, iOS
15 minimum, iPhone/iPad support, and TrollStore-first direction remain valid
unless this design explicitly changes them.

## 3. Goals and non-goals

### 3.1 Goals

- Make every maintained browser integration source file Vulpra-owned.
- Treat Gecko as an opaque, versioned binary dependency with an inspectable ABI
  and reproducible checksum.
- Preserve the independent Vulpra App layer and existing user data.
- Restore complete browser behavior through a narrow, testable engine contract.
- Deliver a visually polished adaptive interface on iPhone and iPad.
- Sustain native 120 Hz interaction on supported ProMotion devices and correct
  60 Hz behavior elsewhere.
- Make runtime, memory, frame, cancellation, and failure behavior measurable.

### 3.2 Non-goals

- Rebuilding or modifying Gecko source in this repository.
- Copying, renaming, translating, or structurally reproducing Reynard client,
  GeckoView, Helper, JIT, patch, or tooling source.
- Keeping a source-level compatibility wrapper around the inherited owners.
- Shipping two active engine adapters.
- Claiming App Store eligibility; private entitlement and public-distribution
  review remain separate decisions.
- Adding sync, accounts, cloud translation, advertising, analytics, or AI while
  engine ownership and core product quality remain incomplete.

## 4. Ownership boundary

### 4.1 Allowed external artifact

The external Gecko artifact may contain only runtime material required to link
and launch the already compiled kernel:

- `XUL`;
- Gecko/NSS/media runtime dylibs;
- ABI and bootstrap headers consumed by Vulpra-owned bridge code;
- Gecko runtime modules, actors, dictionaries, localization, and default theme;
- an artifact manifest, source/build identity, licenses, notices, and SHA-256
  checksums.

The artifact is generated outside the product source tree and restored under an
untracked `.build/engine/` root. Normal application builds verify it but never
fetch, patch, or rebuild Gecko implicitly.

The artifact must not contain a reusable inherited `GeckoView.framework`, an
inherited Helper executable, inherited JIT support, or product UI code.

### 4.2 Vulpra-owned source

The following become maintained Vulpra owners:

- `Engine/VulpraEngineKit/` - engine runtime, sessions, views, events, prompts,
  permissions, downloads, storage, media, and extension contracts;
- `Engine/VulpraEngineProcess/` - independently implemented child-process host;
- `Engine/VulpraExecution/` - execution capability and future independent JIT
  boundary;
- `App/` - browser product, local state, UIKit interface, and product behavior;
- `Extensions/OpenIn/` - public OpenIn handoff;
- `Configuration/`, Xcode graph, package scripts, workflows, and tests.

### 4.3 Retired source

The new product graph must not compile or retain these imported owners:

- `Extensions/GeckoView/`;
- `Extensions/Helper/`;
- `Modules/VulpraRuntime/`;
- `Patches/`;
- imported Gecko/JIT bootstrap tools;
- Firefox and idevice source gitlinks used to reproduce the old substrate;
- the old import manifest as an active build authority.

Historical provenance remains in documentation or a repository-history export,
not in the active product graph.

## 5. VulpraEngineKit architecture

### 5.1 Public product contract

App code depends on Vulpra-owned protocols and value types:

- `EngineRuntime` owns process-wide startup, readiness, locale, shutdown, and
  capability reporting.
- `EngineSession` owns one browsing context and exposes navigation, loading,
  focus, visibility, settings, find-in-page, media, and lifecycle commands.
- `EngineView` is the UIKit surface attached to the selected tab.
- `EngineNavigationObserver` reports location, title, history state, new-window,
  and close requests.
- `EngineProgressObserver` reports start, stop, progress, crash, and kill state.
- `EnginePromptHandler`, `EnginePermissionHandler`, and
  `EngineDownloadHandler` use Vulpra value types and async cancellation.
- `EngineStorage` owns browsing-data operations.
- `EngineExtensionService` owns extension list/install/enable/disable/uninstall
  behavior after core session parity is complete.

No public App-facing type may contain `Gecko`, raw event dictionaries, engine
window identifiers, or opaque pointers.

### 5.2 Internal layers

`VulpraEngineKit` has four internal layers:

1. **ABI bridge** - the only C/Objective-C++ owner allowed to include Gecko
   artifact headers or hold opaque engine pointers.
2. **Event router** - validates and converts engine messages into typed Vulpra
   events. Unknown or malformed payloads fail closed and are logged.
3. **Session owner** - serializes lifecycle changes, ensures exactly-once open
   and close, and prevents callbacks after teardown.
4. **Feature adapters** - prompt, permission, download, storage, media, and
   extension behavior built on typed events.

UIKit product controllers do not parse engine payload dictionaries.

### 5.3 Threading and cancellation

- Runtime and session state use explicit serial executors or queues.
- UIKit view creation and mutation are `MainActor`-isolated.
- Engine callbacks enter through one router and are delivered on documented
  executors.
- Every async request has one completion owner, a cancellation path, and a
  deadline where the engine requires a response.
- Session close atomically rejects later callbacks and releases its engine view.
- No synchronous main-thread wait may depend on an engine or child-process
  callback.

### 5.4 Child-process host

`VulpraEngineProcess` independently implements the minimum executable/extension
contract required by the precompiled kernel. Its bundle identity, bootstrap
arguments, endpoint transfer, lifecycle, crash reporting, and entitlements are
specified and tested by Vulpra.

The child host contains no browser product state and cannot become a second tab
or session owner.

### 5.5 Execution and JIT

Inherited low-level JIT and idevice source are retired. The first independent
runtime milestone must function in interpreter mode and report its execution
capability honestly.

High-performance product completion requires a separate Vulpra-owned execution
implementation for supported TrollStore environments. It must sit behind
`EngineExecutionCapability`, remain optional for correctness, and never block a
child process indefinitely when unavailable. Its design and device evidence are
a dedicated implementation slice, not a reason to preserve inherited JIT code.

## 6. App migration

- Replace every `import GeckoView` in `App/` with `import VulpraEngineKit`.
- Replace Gecko delegate conformances with Vulpra engine protocols.
- Keep `TabManager` as the sole tab lifecycle owner.
- Keep `BrowserTab` as the sole owner of one optional `EngineSession`.
- Preserve normal-tab restoration and exclude private tabs from persistence.
- Preserve existing Codable settings, bookmark, history, download, permission,
  and tab records unless a separately reviewed migration is necessary.
- Introduce an `EngineFactory` only for dependency injection and tests; there is
  no runtime fallback to the inherited adapter.

## 7. Visual system

The authoritative client appearance, information architecture, feature surface,
and interaction specification is
`docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`. The requirements
below are the engine design's cross-boundary constraints, not a replacement for
that client specification.

### 7.1 Product character

Vulpra should feel native, quiet, fast, and focused. It uses system typography,
materials, symbols, accessibility behavior, and platform navigation conventions
without visually cloning another browser.

### 7.2 Responsive composition

- iPhone portrait, iPhone landscape, iPad full screen, and iPad split view use
  explicit adaptive layouts.
- Fixed five-across text actions are prohibited on compact widths.
- Start-page actions use a responsive two- or three-column grid with stable icon
  and label dimensions.
- Long localized labels wrap intentionally to at most two lines or move to a
  wider layout; words must not break into narrow vertical fragments.
- Browser chrome reserves stable dimensions for the address field, progress,
  navigation buttons, and tab count.
- Controls use SF Symbols and accessibility labels; compact tool buttons do not
  repeat visible explanatory text.
- Dynamic Type, VoiceOver, increased contrast, Reduce Transparency, and Reduce
  Motion are acceptance cases rather than best-effort additions.

### 7.3 Animation system

The animation owner is a small Vulpra motion system, not scattered duration and
spring constants.

- Address focus, chrome collapse, tab selection, tab insertion/removal, overview
  presentation, progress completion, and privacy-cover transitions are
  interruptible.
- Gesture-driven transitions track user input and preserve velocity on finish or
  cancellation.
- Layout-affecting work is prepared before animation; per-frame constraint-tree
  reconstruction is prohibited.
- Core Animation transforms and opacity are preferred for interaction-critical
  transitions.
- Standard interaction animations target 160-280 ms; longer transitions require
  a product-specific reason.
- Reduce Motion replaces spatial transitions with short fades or immediate state
  changes while preserving completion semantics.

## 8. Performance contract

### 8.1 Frame pacing

On supported ProMotion hardware, the app opts into 120 Hz and must not install a
60 Hz display-link or animation cap.

Acceptance workloads include address editing, tab swipe, overview presentation,
tab-card scrolling, start-page scrolling, settings navigation, and switching
between warm engine sessions.

- 120 Hz frame budget: `8.33 ms`.
- 60 Hz frame budget: `16.67 ms`.
- p95 frame time must remain within the applicable frame budget.
- A hitch is a frame above `1.5x` budget.
- Hitch rate must remain below `1%` for each deterministic workload.
- No transition may display sustained frame pacing below the device refresh
  class because of Vulpra UI work.

### 8.2 Responsiveness

- Main-thread tasks above `50 ms` during interactive workflows are defects.
- Warm tab selection must update chrome and attach the prepared view within one
  display frame; engine content readiness is measured separately.
- Omnibox local suggestions are bounded and cancellable and must not perform disk
  reads on each keystroke.
- Thumbnail capture, JSON encoding, download bookkeeping, and artifact checks do
  not run on the interaction-critical main-thread path.

### 8.3 Startup and memory evidence

Two startup endpoints are measured separately:

- chrome interactive;
- first engine session ready to accept navigation.

Cold and warm runs report median and p95 from at least five samples. Memory
evidence reports initial browser state, one warm tab, five warm tabs, suspended
tabs, and private-tab teardown. Absolute release thresholds are set only after
the first independent runtime baseline, then become regression gates.

### 8.4 Test devices

Performance completion requires direct evidence from:

- one supported 120 Hz iPhone or iPad;
- one supported 60 Hz device;
- iOS 15.8 and iOS 16.7 compatibility devices or an explicitly approved revised
  compatibility matrix.

Simulator screenshots and source-contract tests do not satisfy physical-device
performance acceptance.

## 9. Delivery phases

### Phase A - Boundary and artifact

- Record a machine-readable ownership map.
- Define the binary-only Gecko artifact v4 contract.
- Add positive and negative provenance gates.
- Create the `VulpraEngineKit` and process-host targets.
- Remove inherited owners from the active Xcode build graph.

### Phase B - Runtime and browsing core

- Runtime startup/readiness and independent process host.
- Session open/close, engine view, navigation, title, progress, crash handling.
- One normal tab, then multi-tab selection, suspension, and restoration.
- Real simulator launch and basic HTTP/HTTPS navigation evidence.

### Phase C - Daily browser features

- Prompt and file picker behavior.
- Site and media permissions.
- Downloads and storage clearing.
- Find in page, desktop mode, zoom, sharing, context actions, and private tabs.
- Unit and integration tests use Vulpra-owned typed contracts.

### Phase D - Extensions, media, and execution

- Extension lifecycle and permission surface.
- PiP and background media.
- Independent execution/JIT capability for supported environments.
- Failure isolation and interpreter-mode fallback.

### Phase E - Product quality and release evidence

- Responsive visual-system completion and accessibility review.
- 60/120 Hz frame evidence and animation repair.
- Startup, memory, thermal, download, private-mode, and recovery evidence.
- IPA/TIPA integrity, notices, and physical-device compatibility.
- Delete all retired imported source and verify no active reference remains.

## 10. Verification

### 10.1 Ownership checks

- No active source path appears in the old import manifest target set.
- No `App/` file imports `GeckoView`.
- No active Xcode target compiles `Extensions/GeckoView`, `Extensions/Helper`,
  `Modules/VulpraRuntime`, or `Patches`.
- The external artifact contains only allowlisted runtime entries.
- The artifact checksum, build identity, ABI version, and notices are verified
  before compilation.

### 10.2 Automated tests

- Pure Swift tests cover App stores, tab state, omnibox resolution, typed engine
  events, cancellation, and lifecycle state machines.
- Engine tests use a deterministic fake ABI below `VulpraEngineKit`, not a fake
  product owner above it.
- macOS CI compiles all iOS targets against the exact binary artifact.
- Simulator CI launches the real client, opens a local deterministic page,
  exercises navigation, and captures visual evidence.
- Package CI creates and validates IPA/TIPA without compiling inherited source.

### 10.3 Manual and device tests

- Launch, navigation, child-process recovery, private teardown, downloads,
  permissions, extensions, PiP, background audio, and OpenIn.
- Dynamic Type, VoiceOver, light/dark appearance, contrast, Reduce Motion, and
  rotation/split-view behavior.
- Instruments-based frame, startup, memory, and thermal runs using recorded
  workloads and raw samples.

## 11. Retirement and compatibility

Retirement class: `code-retirement` and `contract-carrying code`.

Decision: `delete-first` from the active product graph. The precompiled Gecko
artifact is the only `compat-exception`, supported by direct binary dependency
evidence and an exact manifest. No live user data is deleted.

During implementation, old source may be inspected only from repository history
or a separate reference worktree. It is not copied into `VulpraEngineKit`, not
compiled in parallel, and not retained as a runtime fallback. A missing behavior
is repaired in the new canonical owner.

## 12. Complexity budget

- No maintained source file should exceed 350 lines without owner review.
- No engine public protocol combines runtime, session, storage, and feature
  responsibilities.
- Raw payload parsing exists in one event-router layer.
- No third-party package is added for UI or animation.
- Engine, App, tests, artifact payload, and generated output are measured
  separately.
- A feature slice that adds a fallback must name and retire the path it replaces.

## 13. Design review records

### TaskIntentDraft

- Outcome: a source-independent Vulpra browser using only a precompiled Gecko
  kernel boundary.
- Success evidence: ownership gates, independent engine source, real browsing,
  full package evidence, polished responsive UI, and 60/120 Hz device metrics.
- Stop condition: all inherited runtime source is retired and the independent
  product satisfies functional, visual, performance, and device gates.
- Non-goals: Gecko rebuild, inherited source compatibility, unrelated online
  services, and public-release claims without evidence.

### BaselineReadSetHint

- `docs/provenance/substrate-boundary.md`
- `docs/provenance/import-manifest.tsv`
- `docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md`
- `docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md`
- `docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md`
- `docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`

### BaselineUsageDraft

- Required refs: all BaselineReadSetHint entries.
- Acknowledged before design: yes.
- Missing evidence: exact binary ABI closure, independent process-host runtime
  proof, independent execution/JIT design, and physical-device metrics.
- Decision: `continue` for design and planning; implementation completion remains
  `needs-verification` until those gates pass.

### Requirement Ready Check

- Requirement source: user direction on `2026-07-26`.
- Goal and scope: independent Vulpra source, precompiled Gecko only.
- Acceptance: functional browser parity, visual quality, responsiveness,
  accessibility, package integrity, and 60/120 Hz evidence.
- Open blocker: none for planning; external Mac and device evidence remains an
  execution gate.
- Decision: `ready` after user review of this written spec.

### First-principles and architecture integrity

- Non-negotiable goal: Vulpra owns all maintained integration and product source.
- Non-negotiable constraint: retain the already compiled Gecko kernel.
- Assumption removed: the imported GeckoView/Helper/JIT source graph must remain
  because the binary kernel was built around it.
- New canonical owner: `VulpraEngineKit` and `VulpraEngineProcess`.
- Old owners: imported GeckoView, Helper, JIT, patch, and build-source roots.
- Compatibility carrier: only the manifest-verified Gecko binary artifact.
- Falsifier: if browsing requires compiling an imported source owner, this
  design has not been achieved.
- Verdict: proceed with independent adapter design and delete-first retirement.

### ImpactStatementDraft

- Affected layers: artifact contract, Xcode graph, runtime startup, process host,
  App engine imports, testing, packaging, performance, and provenance.
- Preserved owners: Vulpra App product state, local data stores, TabManager,
  BrowserTab responsibility, OpenIn, and bundle identity.
- Retired owners: all inherited runtime integration source.
- Data risk: no live-data deletion; existing Codable files remain authoritative.
- ADR signal: required after implementation proves the new runtime boundary.
- Baseline sync: required after independent runtime and package verification.

### Product risk lens

- Value: source ownership, clearer maintenance, a distinctive polished browser,
  and measurable native performance.
- Trade-off: substantially more runtime work than packaging the inherited
  bridge as a binary framework.
- Primary risk: recreating a broad event surface before the core session path is
  proven.
- Control: deliver typed engine capabilities in dependency order and keep
  unsupported features visibly unavailable until implemented.

### Plan-time complexity check

- Current imported bridge pressure: approximately 4,247 Swift lines plus Helper
  and low-level JIT source.
- App dependency surface: 14 App files currently import GeckoView.
- Better boundary: one engine module with ABI, event, session, and bounded
  feature subowners.
- Budget result: `at-risk` due runtime breadth, governed by phased delivery,
  typed owners, 350-line review thresholds, and no dual adapter.
- Recommendation: create a durable implementation plan split by runtime
  capability and evidence gate.
