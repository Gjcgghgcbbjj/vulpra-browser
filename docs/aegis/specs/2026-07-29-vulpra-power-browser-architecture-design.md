# Vulpra Power Browser Product and Platform Architecture

Date: `2026-07-29`
Status: `approved-by-user-pending-written-review`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## 1. Purpose

Vulpra will become a Gecko browser for advanced iOS users, distributed first
through TrollStore and sideloading. Desktop-class extensions and deep
customization are the product differentiator. Reliability, speed, fluidity,
and privacy are release requirements rather than optional feature tracks.

This design replaces incremental timing fixes with explicit platform owners,
contracts, provenance, data boundaries, and release gates. It also defines the
order in which the broader product is allowed to grow.

## 2. Approved Product Position

The approved position is:

> A fast, reliable, privacy-preserving Gecko browser for advanced iOS users,
> distinguished by desktop-class extension and customization capabilities.

The product priorities are:

1. Trustworthy engine and process behavior.
2. Daily-driver speed, stability, and privacy.
3. Extensions and customization as the visible differentiator.
4. Containers, workflows, automation, and encrypted services after the first
   three layers are proven.

The product does not attempt to become an App Store mass-market browser or a
cross-platform account service in this design cycle.

## 3. Evidence and Current-State Findings

### 3.1 Source snapshot

- Formal implementation branch: `fix/browser-performance-20260729`
- Reviewed snapshot: `57b6389a5b7f82a9e49fd651302a0c192ab034c3`
- Diagnostic branch: `diagnostic/native-simulator-gecko-20260729`
- Diagnostic snapshot: `5a85471`
- Native Simulator producer run: `30277909573`
- Native Simulator A/B runs: `30456751227` and `30456757711`

GitHub evidence:

- <https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30277909573>
- <https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30456751227>
- <https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30456757711>
- <https://github.com/mozilla-firefox/firefox/blob/27b462b22705a8860f7ab0d33aa5b4b658ae5932/widget/uikit/GeckoViewSwiftSupport.h>

The diagnostic branch is evidence-only. It changes workflow and artifact lock
inputs and is not an implementation branch to merge wholesale.

### 3.2 Confirmed engine findings

1. The vtool Simulator artifact copies device XUL and dylibs and changes their
   Mach-O platform metadata. Code and data sections are byte-identical to the
   device binaries. It is not a native Simulator Gecko build.
2. A native `aarch64-apple-ios-sim` Gecko artifact can render successfully,
   but the same App and Engine integration also produces a non-crashing blank
   `about:blank` run. Native compilation is required but is not the complete
   white-screen repair.
3. Successful evidence had six Engine Process instances; failed evidence had
   four. A fixed process count is not a valid readiness contract because Gecko
   launches process roles on demand.
4. `VEKChildProcessStart` returns success after it obtains a private libxpc
   connection and calls `ChildProcessInit`. This does not prove that Gecko's
   child IPC channel reached `PROCESS_CONNECTED`.
5. `Vulpra:RuntimeReady` proves that the main runtime dispatcher activated. It
   does not prove that any requested child process is ready.
6. `EngineProcessBootstrap.swift` defines a role, token, and parent PID model
   that is not connected to the active ExtensionKit endpoint path. Structural
   tests currently preserve this dead ownership model.
7. The artifact manifest claims upstream Firefox commit
   `27b462b22705a8860f7ab0d33aa5b4b658ae5932`, while packaged ABI headers and
   XUL contain downstream child-start, PiP, and JIT surfaces absent from that
   upstream snapshot. The current artifact cannot be reproduced from the
   provenance it declares.
8. Packaged symbols and strings include `jit-ready-fd`,
   `ReportJITStatusForChild`, child process start notification, and JIT failure
   output. The current Vulpra runtime does not own the retired JIT handshake.
9. The formal branch still contains a page-side
   `reassertActivationIfNeeded` path. This is a consumer-side timing mitigation,
   not a child-process lifecycle repair.

Physical-device Gecko behavior remains unverified. Simulator evidence must not
be generalized to device correctness.

## 4. First-Principles Decision

### 4.1 Invariants

- Every requested Gecko child process reaches a typed connected state or a
  typed terminal failure.
- The engine process manager owns semantic child state.
- The iOS process extension owns ExtensionKit/XPC resource lifetime only.
- The App never infers engine readiness from delays, process counts, blank
  pixels, or repeated activation.
- Every distributed runtime is traceable to upstream source, downstream
  patches, build configuration, toolchain, and artifact content.
- Private behavior is enforced by data ownership and storage partitioning.
- Extensions receive only explicitly granted capabilities.

### 4.2 Assumptions removed

- A pinned binary is not reproducible when its patchset and build inputs are
  missing.
- A synchronous ABI return is not child readiness.
- Main runtime readiness is not renderer or network-process readiness.
- A fixed number of child processes is not a success condition.
- A private mode Boolean is not a sufficient future isolation model.
- Retired source code is not actually retired if the shipped binary still
  requires its protocol.

### 4.3 Smallest sufficient stable repair

The smallest sufficient repair is a reproducible, minimal Gecko producer plus
an internal typed child lifecycle projected into VulpraEngineKit. Normal App
builds continue to consume precompiled artifacts and do not build Gecko.

An App-only state machine is insufficient because it cannot observe Gecko's
actual child state and cannot remove hidden binary dependencies. Restoring the
old GeckoView/Helper/JIT client would restore duplicate owners and is rejected.

## 5. Architecture Options

### 5.1 Selected: modular App with an owned Engine Platform

- Keep the current App as a modular monolith while it is small.
- Maintain VulpraEngineKit as the stable App-facing engine SDK.
- Maintain a separate reproducible Gecko producer and minimal patchset.
- Introduce protocols and composition at owner boundaries, not a framework per
  directory.
- Split physical modules only after dependency and build-time evidence justifies
  it.

This is selected because it gives strong ownership without premature package
and Xcode target overhead.

### 5.2 Rejected: immediate multi-framework decomposition

This would improve compile-time visibility but add resource, target, protocol,
and build-graph overhead disproportionate to the current App and Engine source
size. Logical boundaries come first.

### 5.3 Rejected: controller and singleton continuation

Keeping feature stores globally accessible and adding capabilities directly to
`BrowserViewController` has the smallest textual diff but creates overlapping
owners. It would repeat the timing-patch failure mode at the product layer.

## 6. Target Dependency Direction

```text
Vulpra App Composition
        |
        +-- Browser Core
        +-- Privacy Core
        +-- Extension Platform
        +-- Library / Downloads / Settings
                         |
                  VulpraEngineKit Public API
                         |
                  Engine Internal / ABI
                         |
              Versioned Gecko Runtime Artifact
                         |
             Reproducible Gecko Producer
```

Dependencies flow toward stable contracts. UI controllers do not include
artifact headers, decode Gecko dictionaries, access raw XPC objects, or become
process lifecycle owners.

## 7. Canonical Owners

### 7.1 App composition

`AppComposition` constructs repositories, policies, managers, and controllers.
Existing `*.shared` feature stores migrate to injected instances when their
feature slice is implemented. This is an incremental owner migration, not a
big-bang rewrite.

### 7.2 Browser Core

- `TabManager` remains the sole owner of tab order, selection, creation,
  closure, restoration, and memory-pressure suspension.
- `BrowserTab` owns one tab's session, navigation state, restore descriptor,
  and visible engine surface.
- A live session and a suspended restore descriptor are mutually exclusive
  active representations.
- Browser controllers render state and route user intent. They do not own
  persistence or engine recovery policy.

### 7.3 Privacy Core

`PrivacyPolicyService` computes an immutable effective policy from global,
browsing-context, site, private-mode, and extension rules. Feature code and
EngineKit consume the resulting policy; they do not independently read privacy
settings and reinterpret them.

`BrowsingDataCoordinator` is the only orchestrator for clearing a browsing
context across Gecko storage, history, permissions, restoration, and extension
storage.

### 7.4 Extension Platform

`ExtensionManager` owns package identity, installation, versions, enablement,
updates, and lifecycle. `ExtensionCapabilityBroker` is the only path by which
an extension may access tabs, hosts, downloads, clipboard, storage, or private
contexts.

Extensions do not directly access `TabManager`, Browser Core repositories,
App files, raw EngineSession objects, or native code.

### 7.5 Engine Platform

- Gecko `GeckoChildProcessHost` owns child ID, role, launch state, IPC connected
  state, launch failure, and termination semantics.
- `VulpraEngineProcess` owns each ExtensionKit request, NSXPCConnection, and
  NSExtensionContext resource lifetime.
- VulpraEngineKit projects typed internal lifecycle events and maps public
  failures to runtime/session/navigation states.
- The App sees product-level runtime, session, navigation, and renderer failure
  states. It does not see child PID or private XPC details.

## 8. Engine Producer and Artifact Contract

### 8.1 Producer source of truth

The Gecko producer must pin:

- upstream repository and commit;
- ordered Vulpra patchset commit and aggregate digest;
- mozconfig and configure arguments;
- Rust, Clang, Xcode, SDK, Python, and build-host fingerprints;
- deployment target and target triple;
- packaging and normalization tool versions;
- ABI version and exported header digests.

The exact same upstream and patchset inputs produce separate native device and
Simulator artifacts. Device binaries are never converted into Simulator
binaries by editing Mach-O metadata.

### 8.2 Minimal downstream patch policy

The producer carries only iOS port behavior and Vulpra lifecycle ABI that
cannot be expressed by the upstream artifact. Each patch has a purpose, an
upstream source reference, tests, and a retirement condition.

The non-JIT runtime must remove the inherited `jit-ready-fd` and
`ReportJITStatusForChild` handshake rather than waiting for a client owner that
no longer exists. A future JIT implementation requires a separate approved
design and must not be hidden inside the correctness path.

### 8.3 Child lifecycle ABI

The producer exposes internal events with:

```text
launchID
Gecko childID
processType
pid (when known)
stage
monotonic timestamp
typed failure (when present)
```

Required stages are:

```text
requested
extensionConnected
bootstrapAcknowledged
ipcConnected
failed
terminated
```

`bootstrapAcknowledged` is the iOS bootstrap PID reply. `ipcConnected` is the
Gecko IPC channel-connected state, not a renamed PID callback. Every requested
launch must have one connected or failed outcome. Counts remain demand-driven.

### 8.4 Artifact verification

Verification covers platform load commands, architecture, required exports,
headers, resource completeness, provenance, patch digest, and content hashes.
Repeat builds compare normalized non-signature Mach-O content and resources;
codesigning and documented nondeterministic metadata are evaluated separately.

## 9. Unified Browsing Context

The current private Boolean evolves into an explicit context:

```swift
struct BrowsingContext {
    let id: BrowsingContextID
    let persistence: Persistence
    let storagePartition: EngineStoragePartitionID
    let historyPolicy: HistoryPolicy
    let suggestionPolicy: SuggestionPolicy
    let extensionPolicy: ExtensionPolicy
}
```

Built-in forms are:

- `default`: persistent normal browsing;
- `private`: ephemeral and destroyed when the final private context owner
  closes;
- `container(id)`: persistent identity with isolated engine storage and policy.

A tab is created in one browsing context and cannot silently change context.
Moving a URL to another identity creates a new tab. This prevents live cookie,
permission, and extension state from crossing partitions.

Permissions are keyed by context, origin, and permission kind. Extension grants
are keyed by extension and context policy. Private history, suggestions,
thumbnails, restoration records, and temporary permission decisions remain in
memory only.

## 10. Persistence Architecture

Use storage according to data shape:

- Versioned JSON with atomic replacement: settings, build identity, and small
  tab restore descriptors.
- SQLite: history, bookmarks, download metadata, permissions, containers, and
  extension metadata.
- Gecko partitions: cookies, cache, IndexedDB, and web-origin data.
- Keychain: account tokens, encryption keys, and secrets.
- Memory-only repositories: private history, suggestions, temporary grants,
  and private extension state.

SQLite infrastructure owns connections, transactions, and migrations only.
Feature repositories own tables and queries. There is no general-purpose
`DatabaseManager.shared` or untyped row access in controllers.

All schemas have explicit versions. Migrations execute transactionally. A
failed migration preserves the prior source data and stops writes. After a JSON
to SQLite migration is verified, the old reader and any dual-write path are
retired. Persistent user-data deletion requires separately scoped confirmation;
this design does not authorize it.

## 11. Privacy Policy

The effective policy is:

```text
global policy
intersection browsing-context policy
intersection site exception
intersection private restriction
intersection extension grant
= effective policy
```

Required defaults:

- Private contexts do not write history, restore records, thumbnails, or
  suggestion caches.
- Remote suggestions are disabled in private contexts.
- Extensions cannot access private contexts without a separate grant.
- Clearing history does not delete bookmarks or user-downloaded files.
- User-initiated private downloads may preserve their files, while private
  download metadata is removed when the private context closes by default.
- Telemetry is absent by default. Any future telemetry requires an explicit
  product and data-flow design.

Production and CI logs must not contain page content, form values, cookies,
authorization headers, tokens, private URLs, or private-context site identity.

## 12. Extension Capability Model

Effective extension access is:

```text
manifest request
intersection platform support
intersection user grant
intersection browsing-context policy
= effective capabilities
```

The first capability set covers bounded active-tab operations, declared host
patterns, content scripts, isolated extension storage, toolbar action,
downloads, clipboard, content/network blocking, and separately granted private
context access.

The first release excludes arbitrary native code, unrestricted filesystem
access, silent full-history or bookmark access, unbounded background work,
unreviewed native messaging, and direct access to Browser Core or EngineSession
owners.

Capability decisions are auditable by extension ID, context ID, capability,
target class, and decision. Audit data excludes page content, secrets, private
URLs, and extension storage content.

JavaScript exceptions, permission rejection, timeout, and resource exhaustion
are isolated at the extension task boundary. Gecko may share native processes
between extensions, so the product does not claim unavailable per-extension
native process isolation. A shared engine crash may affect related pages, but
must not corrupt App state or terminate browser chrome.

## 13. Search and Interaction Performance

### 13.1 Omnibox pipeline

```text
input generation
-> URL resolver
-> parallel indexed local providers
-> bounded ranker
-> immediate local snapshot
-> optional cancellable remote provider
-> validated merged snapshot
```

History, bookmarks, and open tabs query independently and return bounded
results. SQLite indexes normalized URL, host, and title fields. Every input
generation cancels or invalidates older remote work. A stale generation cannot
replace current UI state.

Database scans and network requests do not execute on the main thread. UI
applies only changed snapshots and keeps stable row geometry.

### 13.2 Page scrolling

- Engine progress, location, and title updates are coalesced before rendering.
- Equivalent state within one run-loop turn renders once.
- Scrolling does not generate thumbnails, synchronously write history, or
  refresh unrelated settings.
- Browser chrome consumes bounded scroll deltas without rebuilding constraints
  per frame.
- Toolbar, progress, counter, and suggestion row dimensions remain stable.
- Thumbnail, history commit, and session checkpoint work runs after interaction
  or on an appropriate background executor.

`os_signpost` instruments startup, omnibox queries, navigation, first visible
frame, tab switching, scrolling, and memory-pressure suspension. CI exports
aggregated durations and anonymous trace identifiers only.

## 14. Failure and Recovery Semantics

Internal and public state maps to typed phases:

```text
starting
ready
degraded(reason)
failed(stage, reason)
terminated(reason)
```

Failures originate at the correct engine, process, persistence, privacy, or
extension owner. The App renders recovery state but does not replay activation,
delay navigation, or run unbounded retries.

Renderer failure presents a recovery surface. User-initiated retry remains a
valid command. POST, upload, form submission, and other non-idempotent work is
never automatically replayed. A GET session may be rebuilt only when the engine
contract explicitly marks it recoverable. Repeated failure enters a stable
degraded state instead of a restart loop.

The start page, omnibox, settings, bookmarks, history, and extension management
remain usable when the engine is unavailable.

## 15. Product Stages and Gates

### 15.1 R0 - trustworthy engine

Scope:

- reproducible minimal Gecko patchset;
- native device and Simulator artifacts;
- typed child lifecycle;
- removal of vtool, hidden JIT wait, and page activation reassertion;
- truthful artifact provenance.

GitHub acceptance:

- 20 independent Simulator create/install/cold-launch/navigation attempts pass
  20 of 20;
- every attempt proves target location, page completion, and a nonblank
  deterministic screenshot;
- every child request reaches `ipcConnected` or a typed `failed` state;
- no anonymous missing request, fixed process-count assertion, activation
  replay, or automatic navigation timing workaround remains;
- load-to-complete p95 is at most 15 seconds and no attempt exceeds 30 seconds;
- repeat producer builds pass normalized code, resource, ABI, provenance, and
  manifest comparison;
- device IPA and TIPA builds pass while physical-device runtime status remains
  explicitly unverified.

Existing search and rendering performance safeguards remain active, but R1
feature expansion and an R1 release claim do not proceed until the R0 contract
is green.

### 15.2 R1 - reliable daily use

Scope includes indexed search, smooth page interaction, bounded tabs, crash
recovery, downloads, media, permissions, history, bookmarks, private browsing,
tracking protection, and HTTPS-first behavior.

Acceptance:

- local suggestions over 10,000 history/bookmark fixtures complete under 50 ms
  at p95 on the pinned CI environment;
- old remote work never replaces a newer query and never blocks local results;
- remote suggestions are disabled by default for private contexts;
- pinned 60 Hz Simulator scroll evidence has p95 frame interval below 20 ms
  and no main-thread stall above 100 ms;
- a 20-tab pressure scenario does not crash and memory warnings suspend inactive
  tabs in LRU order;
- closing a private context produces zero persistent history, restoration,
  thumbnail, suggestion-cache, permission, or extension-storage increment;
- renderer failure shows a typed recoverable or terminal state, never a blank
  page with hidden retries.

Simulator timing is a controlled comparative proxy. It does not establish
physical-device 120 Hz, energy, thermal, or memory-termination behavior.

### 15.3 R2 - extensions and customization

Scope includes explicit-source installation, enable/disable/uninstall/update,
content scripts, isolated storage, toolbar actions, user scripts, content
filtering, gestures, toolbar customization, and shortcut commands.

Acceptance:

- all privileged operations pass through `ExtensionCapabilityBroker`;
- permission upgrades require renewed approval;
- disabling an extension stops its content and background work;
- package manifest, source, version, and content digest are verified;
- extension exception, timeout, or resource limit does not terminate browser
  chrome or corrupt another extension's state;
- an explicit compatibility matrix reports supported and unsupported APIs.

### 15.4 R3 - advanced privacy and efficiency

Scope includes container tabs, workspaces, vertical tabs, command palette,
automation, and separately designed encrypted sync.

Acceptance:

- containers do not share cookies, storage, or permissions;
- deleting one container does not delete another context's data;
- automation uses the same capability authorization as extensions;
- sync services receive ciphertext and minimum necessary metadata only;
- cloud unavailability does not degrade local browsing.

Passwords, Passkeys, translation, and AI assistance require separate provider
and security designs and are not implied by R3.

## 16. Verification Matrix

1. Portable contracts verify owners, dependency direction, artifact provenance,
   forbidden fallbacks, and retirement.
2. Swift unit tests verify lifecycle, search ordering/cancellation, permissions,
   migrations, and private zero-persistence behavior.
3. Engine integration tests verify requested/connected/failed process paths,
   session navigation, and renderer recovery.
4. GitHub Simulator tests verify cold starts, deterministic navigation,
   screenshots, scrolling, tab pressure, and signpost budgets.
5. Package validation verifies IPA/TIPA structure, ABI, entitlements, resources,
   manifest, patch digest, and checksums.
6. Physical-device validation later covers iOS 15/16 installation, 60/120 Hz,
   energy, thermal load, memory termination, downloads, media, permissions, and
   long-running use.

Until device gates pass, builds are test or candidate releases rather than a
fully verified stable release.

## 17. Release and Rollback

- Canary validates a new Gecko artifact before stable references it.
- App and Gecko use an explicit compatibility version. Builds never select the
  latest runtime implicitly.
- Rollback changes the repository lock to one complete previously verified
  artifact. There is no runtime dual-engine fallback.
- A release publishes App packages, engine provenance, checksums, known limits,
  and evidence references.
- A schema change that cannot safely read data written by the newer version
  blocks application downgrade rather than risking silent corruption.

## 18. Retirement and Migration

### 18.1 Delete-first internal retirement

After their replacement gates pass, retire together with their dedicated tests
and configuration:

- `Tools/Engine/produce-simulator-artifact.sh`;
- `.github/workflows/produce-simulator-artifact.yml`;
- the `apple-vtool-set-build-version-iossim-15` artifact policy;
- the vtool Simulator v4 archive and lock identity;
- inherited non-JIT `jit-ready-fd` and `ReportJITStatusForChild` producer logic;
- dead `EngineProcessBootstrap` role/token/parent-PID parsing;
- structural tests that require the dead bootstrap model;
- `reassertActivationIfNeeded` and related page-side activation state;
- automatic delay or navigation replay introduced only to mask process
  readiness gaps.

User-triggered reload/retry and typed recoverable failure handling are expected
behavior and are not retired.

### 18.2 Compatibility and data safety

Existing bundle identity, iOS 15 deployment target, iPhone/iPad support,
OpenIn, normal tab restoration, Codable records, IPA, and TIPA outputs remain
compatibility requirements.

Internal code and derived artifacts use `delete-first`. Published package and
artifact contracts require high-risk boundary verification. Persistent user
records use transactional migration and `confirmation-first` for any actual
destructive cleanup. No persistent-state deletion is authorized by this spec.

## 19. Non-goals

- App Store mass-market distribution in this cycle.
- Cross-platform account and product implementation.
- Reintroducing the retired GeckoView/Helper/JIT client graph.
- Building Gecko during normal App or package builds.
- Full Chrome Web Store or every WebExtension API in the first extension
  release.
- Native extension code or unrestricted native messaging.
- Remote content feeds, advertising, analytics, or default telemetry.
- Claiming device, 120 Hz, energy, or thermal verification from Simulator data.

## 20. Baseline and ADR Impact

The product requirement baseline is directionally aligned with the existing
modern browser and client experience designs. The runtime architecture baseline
contains a confirmed design defect: it declares patch/source-build and JIT
paths retired while the shipped artifact contains unrecorded downstream ABI and
JIT protocol surfaces.

Result: `Design Defect`, scope `architecture`.

After implementation evidence passes, ADR-0004 and the independent-engine
baseline must be superseded or amended to state:

- normal App builds consume precompiled Gecko and do not compile it;
- the Gecko producer explicitly maintains a minimal, auditable patchset;
- device and Simulator artifacts are native builds;
- Gecko owns semantic child lifecycle and VulpraEngineProcess owns platform
  resource lifetime;
- non-JIT correctness has no inherited JIT handshake;
- the new artifact version and verification evidence replace v4 claims.

No ADR is amended merely because this proposed design was approved. Durable
architecture memory is updated after implementation and verification.

## 21. Working Artifacts

### TaskIntentDraft

- Outcome: an advanced-user iOS Gecko browser with extensions/customization as
  differentiation and reliability, speed, privacy, and fluidity as hard gates.
- Success evidence: R0 through R3 gates, with GitHub evidence now and explicit
  physical-device gates later.
- Stop condition: each stage stops when its owner contracts and gates are green;
  new feature stages do not bypass failed prerequisites.
- Non-goals: mass-market App Store, cross-platform service, JIT restoration,
  runtime fallback, and unsupported compatibility claims.

### BaselineReadSetHint

- `docs/aegis/specs/2026-07-22-vulpra-modern-browser-product-design.md`
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`
- `docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md`
- `docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md`
- `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`
- current App, Engine, artifact contracts, workflow, binary audit, and GitHub A/B
  evidence listed in Section 3.

### BaselineUsageDraft

- Required refs: product design, client design, independent engine design,
  ADR-0004, independent-engine baseline, current code, artifacts, and A/B runs.
- Cited in design: all required references by role or finding.
- Missing refs: physical-device runtime, 120 Hz, energy, and thermal evidence.
- Decision: continue with Simulator and package design while preserving explicit
  external validation gates.

### ImpactStatementDraft

- Affected layers: Gecko producer, artifacts, ABI, process host, EngineKit,
  Browser Core, Privacy Core, Extension Platform, persistence, CI, release,
  baselines, and ADRs.
- New canonical owners: Sections 7 through 12.
- Preserved invariants: bundle identity, iOS 15, existing product data, tab
  ownership, OpenIn, IPA, and TIPA.
- Compatibility: no runtime fallback and no destructive data migration.
- Main risk: custom Gecko iOS maintenance and private platform integration.

### Architecture Integrity Lens

- Invariant: process and data state have exactly one semantic owner.
- Canonical contract: Gecko child lifecycle, typed EngineKit API, browsing
  context, PrivacyPolicyService, and ExtensionCapabilityBroker.
- Responsibility overlap removed: page activation reassertion, dead bootstrap
  role model, hidden JIT owner, singleton feature access, and extension direct
  access.
- Higher-level simplification: repair producer and owner contracts instead of
  adding caller-side retries.
- Falsifier: if Gecko cannot expose IPC-connected and failure states at its
  existing process manager, the lifecycle ABI design must return for review;
  App-side inference is not an accepted fallback.
- Verdict: proceed to implementation planning after written-spec review.

### Complexity Budget

- Artifact class: high-complexity cross-module architecture and migration.
- Current pressure: App controllers and Engine session/ABI files are moderately
  concentrated; singleton repositories and untyped internal payloads increase
  coupling pressure.
- Planned governance: modular monolith, composition root, typed owner contracts,
  separate producer surface, staged migration, and delete-first retirement.
- Recommendation: add focused owner files and split implementation tasks; do
  not create a framework for every feature or perform a big-bang rewrite.
