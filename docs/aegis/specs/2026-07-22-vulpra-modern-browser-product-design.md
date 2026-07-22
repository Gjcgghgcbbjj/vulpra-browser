# Vulpra Modern Browser Product Design

Date: `2026-07-22`
Status: `approved-for-integration`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## 1. Goal

Turn the Phase 1A Gecko runtime shell into a complete, modern, efficient iOS
15+ browser while preserving the fresh Vulpra ownership boundary. The product
uses a Safari-inspired, one-handed UIKit interface, native animation, Gecko,
TrollStore-first JIT support, deterministic GitHub-hosted kernel production,
and no unnecessary client dependencies.

All functionality approved by the user on `2026-07-22` is in scope, but it is
delivered in dependency-ordered phases. "All" does not authorize a monolithic
controller, duplicate state owners, unbounded background sessions, or bundling
unrelated frameworks into the application.

## 2. Authority and baseline

- `docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md`
- `docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md`
- `docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`
- user selection of interface direction `A`, the Safari-inspired lightweight
  material design
- user approval that the complete recommended browser scope is required

The old Reynard client remains evidence-only. Its UI, stores, managers,
resources, settings hierarchy, persistence implementation, and Xcode project
must not be copied into Vulpra.

## 3. Product principles

1. Native UIKit and Core Animation are the default UI technology.
2. One canonical owner exists for every mutable state surface.
3. Background work, browser sessions, caches, downloads, and suggestions are
   bounded by explicit lifecycle policies.
4. Gecko supplies the web engine; Vulpra supplies product behavior and UI.
5. iOS 15.0, arm64, iPhone, iPad, and TrollStore-first operation remain
   compatibility requirements.
6. No third-party UI, animation, analytics, advertising, or remote-content
   framework is introduced without a separate decision.
7. Runtime and app artifacts remain generated outputs and never enter Git.
8. Each phase must leave a usable, verifiable product slice rather than a set
   of disconnected placeholders.

## 4. Product architecture

### 4.1 Application composition

- `SceneDelegate` owns the window and one root browser controller.
- `BrowserViewController` owns visible browser composition and user actions.
- `TabManager` is the only owner of tab ordering, selection, creation,
  closure, restoration, and memory-pressure suspension.
- `BrowserTab` owns one tab identity and its current metadata. It may own a
  live `GeckoSession` or a suspended restore descriptor, never both as
  competing sources of truth.
- `BrowserChromeView` owns the address field, progress, toolbar buttons, and
  chrome animation state, but not browser navigation policy.
- `TabOverviewViewController` renders tab state supplied by `TabManager` and
  routes user intents back to it.
- Feature repositories own bookmarks, history, downloads, settings, and site
  permissions separately. There is no general-purpose global store.

`RuntimeShellViewController` is retired when `BrowserViewController` becomes
the root. A compatibility wrapper is not retained.

### 4.2 Tab lifecycle and efficiency

- Only the selected tab's Gecko engine view is attached to the visible view
  hierarchy.
- Background tabs retain live sessions under normal memory conditions.
- On memory warning, inactive tabs are suspended from least recently used to
  most recently used while retaining URL, title, privacy state, and restore
  metadata.
- A suspended tab reloads when selected. The UI marks the reload without
  pretending full form/media state was preserved.
- Private tabs never persist to the normal restoration store.
- Closed tabs enter a bounded recently-closed list.
- Thumbnail production is throttled, performed off the main interaction path,
  and disabled for private tabs.

### 4.3 Persistence

Use small, feature-owned stores with versioned Codable records and atomic file
replacement for the first product version:

- tab restoration;
- bookmarks;
- history and recently closed tabs;
- browser settings;
- download metadata;
- site permission decisions.

SQLite or a third-party database is not introduced until measured scale proves
the file-backed stores inadequate. Private browsing data is memory-only.

## 5. Interface system

### 5.1 Browser chrome

- Bottom floating material toolbar using `UIVisualEffectView`.
- Address/search field with URL, query, security, and load-state presentation.
- Back, forward, reload/stop, share, and tab-count controls.
- Thin top-edge page progress indicator.
- Compact chrome while scrolling and expanded chrome during address editing.
- iPad uses a wider adaptive composition, not a duplicated controller tree.
- Light mode, dark mode, Dynamic Type, VoiceOver, increased contrast, and
  Reduce Motion are supported.

### 5.2 Animation and gesture contract

Use interruptible `UIViewPropertyAnimator` or standard Core Animation:

- address focus expansion and keyboard transition;
- page progress interpolation and completion fade;
- button press scaling and light haptic feedback;
- tab-card insertion, selection, dismissal, and overview transitions;
- horizontal address-bar swipe to change tabs;
- upward tab-button gesture to open the overview;
- edge navigation gestures;
- lightweight chrome collapse during page scrolling.

Normal transition duration is `0.18-0.35s`. Reduce Motion replaces spatial
transitions with short fades. No Lottie, continuous particles, animated remote
backgrounds, or permanent full-screen live blur is allowed.

## 6. Functional requirements

### 6.1 Navigation and omnibox

- Parse direct HTTP/HTTPS URLs and search text deterministically.
- Support configurable search engines and a default engine.
- Provide bounded suggestions from bookmarks, history, open tabs, and optional
  remote search suggestions.
- Support paste-and-go, copy URL, reload, stop, back, forward, page load/error
  state, and external URL routing.
- Remote suggestions are cancellable, debounced, optional, and excluded from
  private mode unless explicitly enabled.

### 6.2 Tabs

- Create, select, reorder, and close tabs.
- Close other tabs, undo close, and show recently closed tabs.
- Render a card-grid overview with title, URL, and permitted thumbnail.
- Separate normal and private tab collections.
- Restore normal tabs after application restart.
- Expose bounded tab/session and thumbnail policies in settings where useful.

### 6.3 Start page

- Search entry, favorites, recent visits, recently closed tabs, downloads, and
  private browsing entry.
- User-controlled section visibility and ordering.
- Local lightweight artwork only; no news feed, advertising, or remote content
  recommendation owner.

### 6.4 Bookmarks and history

- Add, edit, move, search, and delete bookmarks and folders.
- Record normal top-level visits with bounded retention.
- Search and delete individual or ranged history entries.
- Clear history without silently clearing unrelated saved data.
- Recently closed tabs remain a separate bounded record.

### 6.5 Page tools and media

- Find in page, desktop/mobile site request, page zoom, share, copy URL,
  external open, image context actions, pull to refresh, and QR scanning.
- Reader mode is offered only when page extraction succeeds.
- Picture in Picture and background media controls use the existing Gecko
  media delegation boundary.
- Translation is a separate provider contract and remains disabled until a
  provider and privacy behavior are selected.

### 6.6 Downloads

- Receive Gecko download requests and represent active/completed downloads.
- Show progress, speed, destination, failure, pause/resume when supported,
  cancellation, preview, share, and deletion.
- Stream downloads to disk; never buffer complete payloads in memory.
- Check available capacity and clean abandoned partial files.
- Download records remain metadata; user files remain in a dedicated files
  location.

### 6.7 Privacy and security

- Private tabs do not write normal history, restoration, suggestions, or
  thumbnails and are removed when the private session closes.
- Tracking protection supports standard, strict, and user-defined policy.
- HTTPS-first navigation, popup/redirect protection, and clear security status
  are provided.
- A site permission center owns camera, microphone, location, notifications,
  autoplay, and persistent decisions.
- Users can clear data for one site or configured data classes globally.
- Private browsing obscures the application-switcher snapshot.
- Content blocking and Gecko extension permissions have explicit user-facing
  controls.

### 6.8 Settings

- Search engine and suggestion policy.
- Start-page sections.
- appearance and theme behavior.
- default desktop/mobile mode and page zoom.
- downloads and storage cleanup.
- privacy, tracking protection, history retention, and site permissions.
- extension enablement and permissions.
- version, build fingerprint, licenses, and notices.

Settings screens are feature-owned sections. One oversized settings controller
or untyped key-value dictionary is not allowed.

### 6.9 Extensions

- List installed Gecko extensions.
- Enable, disable, install, uninstall, show permissions, open settings, and
  present supported extension popup UI.
- Extension failures are isolated from browser chrome and tab ownership.
- A remote extension catalog is not required for initial completion; local or
  explicitly supplied packages are sufficient until catalog policy is defined.

### 6.10 Later service-backed capabilities

Cross-device sync, password management, Passkey management, remote
translation, and AI page assistance are in the complete roadmap but require
separate security/provider designs before implementation. Their UI must not be
stubbed into early phases.

## 7. GitHub kernel and release production

### 7.1 Runtime substrate workflow

Add a manually dispatchable macOS GitHub Actions workflow that:

1. checks out the Vulpra repository without eagerly cloning the entire Firefox
   history;
2. resolves the pinned Firefox and idevice gitlinks;
3. records Xcode and iPhoneOS SDK fingerprints;
4. derives a runtime cache identity from Firefox, idevice, patches, build
   scripts, artifact contracts, Xcode, and SDK;
5. restores a matching runtime artifact when one exists;
6. otherwise builds Gecko and `libidevice_ffi.a` for arm64 iOS 15.0;
7. verifies XUL, dylibs, public headers, default theme, and idevice archive;
8. uploads the Gecko archive, idevice archive, manifests, and SHA256 checksums.

The workflow is the orchestration owner. Existing `Tools/Gecko` and
`Tools/Runtime` scripts remain the producer/verification owners; GitHub YAML
must not duplicate their build logic.

### 7.2 Application workflow

The later app workflow restores and verifies the exact runtime substrate,
archives the four-target Xcode graph, produces unsigned IPA and TrollStore
TIPA packages, verifies architecture/identities/entitlements, and uploads
packages plus checksums. It must not rebuild Gecko when a matching verified
runtime artifact exists.

No release readiness claim is made until GitHub macOS execution succeeds and
physical iOS 15/16 device verification completes.

## 8. Delivery phases

### Phase 2A - Kernel CI and browser frame

- GitHub runtime substrate workflow and artifact identity.
- Browser root, tab model/manager, active Gecko view ownership.
- address bar, navigation controls, progress, share, and native chrome.
- tab overview, essential gestures, animations, dark mode, and accessibility.

### Phase 2B - Local browser product

- start page, tab restoration, bookmarks, history, recently closed tabs.
- private tabs, settings foundation, find in page, desktop mode, zoom, page
  actions, QR scanning, and basic PiP/media integration.

### Phase 2C - Downloads, privacy, and extensions

- download manager and files integration.
- tracking protection, HTTPS-first, permission center, per-site data cleanup.
- extension management and content-blocking controls.

### Phase 2D - Release and device hardening

- GitHub app archive, IPA/TIPA production, signing/identity verification.
- iOS 15.8 and iOS 16.7 installation and functional verification.
- startup, memory, tab pressure, download, animation, and 60/120 Hz evidence.
- crash/session recovery and public notices/license completion.

### Phase 3 - Separate security/provider designs

- sync, passwords, Passkeys, translation provider, and optional AI assistance.

## 9. Verification and acceptance

Each phase requires:

- portable source/contract tests on Linux;
- macOS Xcode build evidence for Mac-owned outputs;
- deterministic artifact identity and checksum verification;
- targeted tests for state owners and persistence boundaries;
- lifecycle, error, cancellation, and memory-pressure tests;
- accessibility and Reduce Motion review for new UI;
- `git diff --check`, clean generated-output boundaries, and no committed
  binaries.

Final product acceptance additionally requires installation on iOS 15.8 and
iOS 16.7, Gecko page loading, JIT child readiness, multi-tab use, private-data
separation, downloads, permissions, extensions, restoration, and IPA/TIPA
installation evidence.

## 10. Complexity and performance governance

- No maintained product owner should exceed 350 lines without an explicit
  split review.
- No view controller owns persistence, engine orchestration, and UI state at
  the same time.
- Suggestions, histories, recently closed tabs, thumbnails, downloads, and
  caches have explicit bounds.
- No additional package dependency is expected through Phase 2D.
- Any dependency proposal must report binary size, startup, memory, privacy,
  license, and removal cost.
- Every phase reports source-line pressure, dependency count, generated
  artifact leakage, archive/IPA size, startup time, memory, and animation
  responsiveness when the required platform is available.
- Gecko size is reported separately from Vulpra-authored client growth.

## 11. Compatibility boundary and non-goals

Must remain stable:

- iOS 15.0 deployment and arm64 device target;
- four current Xcode products and bundle identities;
- one `RuntimeJITCoordinator` and exactly-once child readiness contract;
- public `NSExtensionContext.open` OpenIn behavior;
- Gecko and idevice artifact verification boundaries;
- unsigned archive plus TrollStore-first package direction.

Non-goals for Phase 2A-2D:

- copying the inherited Reynard client;
- adding advertising, analytics, news feeds, or engagement SDKs;
- shipping fake sync, password, Passkey, translation, or AI placeholders;
- claiming App Store/public distribution clearance without license and device
  evidence;
- keeping the runtime smoke shell after the real browser root is active.

## 12. Design review lenses

### TaskIntentDraft

- Outcome: complete modern Vulpra client and GitHub-hosted build pipeline.
- Success evidence: verified phased functionality, deterministic runtime and
  package artifacts, device evidence, and bounded complexity/performance.
- Stop condition: Phase 2D acceptance is complete; Phase 3 capabilities stop at
  separately approved provider/security designs.
- Primary risk: feature breadth creating duplicate owners or unbounded state.

### BaselineUsageDraft

- Required baseline refs: runtime shell design/baseline, ADR-0002, efficiency
  policy.
- Acknowledged before design refs: all required refs.
- Cited in design refs: all required refs.
- Missing refs: real GitHub macOS and device evidence.
- Decision: `continue` for design and portable implementation;
  `needs-verification` for Mac/device claims.

### Requirement Ready Check

- Requirement source: user-approved complete feature checklist and selected UI
  direction.
- Acceptance source: this phased verification and acceptance section.
- Open blocker: service/provider choices for Phase 3 only.
- Decision: `ready` for Phases 2A-2D; `needs-user-decision` before individual
  Phase 3 services.

### Architecture Integrity Lens

- Invariant: exactly one canonical owner for each state and lifecycle surface.
- Canonical path: Scene -> Browser root -> TabManager -> BrowserTab/GeckoSession;
  feature repositories remain lateral owned services.
- Responsibility overlap: the smoke shell is deleted; no compatibility owner.
- Higher-level simplification: use feature-owned Codable stores before adding a
  database abstraction.
- Verdict: aligned, with ADR and baseline sync required after implementation.

### Product Risk Lens

- Value: a complete daily-use browser rather than an engine demonstration.
- Trade-off: staged delivery is longer but prevents an untestable monolith.
- Non-goal: visual or feature parity obtained by copying the old client.
- Decision: implement all approved functions through ordered phases.

### Plan-Time Complexity Check

- Current pressure: the runtime shell is small; Gecko/JIT substrate is already
  isolated; product owners do not yet exist.
- Projected pressure: high if UI, tabs, persistence, downloads, permissions,
  and settings share owners.
- Better boundary: separate UI composition, tab lifecycle, and feature stores.
- Recommendation: multiple executable phase plans with per-phase complexity
  closeout; never one monolithic implementation plan.

## 13. ADR and baseline signals

Implementation changes the application root owner, introduces the tab and
persistence ownership model, and establishes GitHub Actions as the Mac build
orchestration owner. Completion must create or amend an ADR for those durable
decisions and replace the Phase 1A portable baseline with phase-specific
verified baselines. Proposed design text alone is not runtime authority.
