# Vulpra Runtime Shell Design

Date: `2026-07-22`
Status: `approved-for-implementation`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## 1. Goal

Create the first independently owned Vulpra application/runtime layer around
the verified Gecko/iOS/JIT substrate:

- a fresh native Xcode project;
- an iOS 15+ UIKit app target;
- GeckoView framework, Helper process extension, and OpenIn extension targets;
- minimal Gecko session startup and URL loading;
- one lightweight JIT orchestration owner;
- deterministic Mac producer and unsigned IPA packaging contracts.

The current WSL/Linux environment must complete and verify Phase 1A source,
project structure, ownership, and portable contracts. Phase 1B Xcode compilation,
Gecko production, IPA creation, and device verification remain explicit Mac
gates rather than inferred passes.

## 2. Authority and requirement sources

- `docs/aegis/baseline/2026-07-21-initial-baseline.md`
- `docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md`
- `docs/provenance/substrate-boundary.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`
- user approval on `2026-07-22` for a fresh native Xcode project and the
  no-current-Mac split between Phase 1A and Phase 1B

The audited Reynard Xcode project and client may be inspected as dependency
evidence only. Its `project.pbxproj`, application owners, UI, stores, resources,
signing team, schemes, and packaging scripts must not be copied.

## 3. Requirements

### R1. Fresh project graph

Create `Vulpra.xcodeproj` without deriving it by textual rename or copy of
`browser/Reynard.xcodeproj`.

The graph has exactly four product targets:

1. `Vulpra` — `com.apple.product-type.application`
2. `GeckoView` — `com.apple.product-type.framework`
3. `Vulpra Helper` — `com.apple.product-type.app-extension`
4. `OpenIn` — `com.apple.product-type.app-extension`

`Vulpra` depends on all three supporting targets, embeds `GeckoView.framework`,
and embeds both extensions in `PlugIns`.

The project contains one shared `Vulpra` scheme that archives the application
and builds its three dependencies. It uses synchronized source groups plus
explicit membership exceptions so `project.pbxproj` remains a compact graph
owner rather than a second source-file manifest.

### R2. Compatibility baseline

- `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
- `ARCHS = arm64`
- iPhone and iPad are supported.
- Mac Catalyst, Designed for iPhone/iPad on Mac, and visionOS are disabled.
- Simulator settings may remain structurally present for source compilation,
  but Gecko/JIT runtime acceptance is device-only.
- No hard-coded Apple development team or provisioning profile enters Git.

### R3. Product identities

- app: `com.vulpra.browser`
- GeckoView framework: `com.vulpra.browser.geckoview`
- Helper: `com.vulpra.browser.helper`
- OpenIn: `com.vulpra.browser.open-in`
- URL scheme: `vulpra`
- Helper product: `Vulpra Helper.appex`
- Helper principal class: `VulpraHelperMain`
- XPC endpoint key: `VulpraXPCListenerEndpoint`

No old runtime identity fallback is allowed.

### R4. New runtime owners

Create new Vulpra-authored application owners under `App/`:

- `main.swift`: starts JIT orchestration, then enters `GeckoRuntime.main`.
- `SceneDelegate.swift`: owns the window, root runtime shell, lifecycle
  activation, and incoming URL routing.
- `RuntimeShellViewController.swift`: owns one smoke-test Gecko session and its
  engine view.
- `RuntimeJITCoordinator.swift`: owns Gecko child-process JIT readiness
  reporting.
- `RuntimeURLRouter.swift`: validates direct `http`/`https` input and
  `vulpra://open?url=` input without storing history or session state.

These owners must not import or recreate old application managers, settings,
diagnostics, migration, tab, persistence, or browser-interface classes.

The Gecko substrate calls `UIApplicationMain` with its canonical
`AppShellDelegate`, which owns engine-level application lifecycle delivery.
`App/Info.plist` therefore owns the static scene configuration that instantiates
`SceneDelegate`; Vulpra must not add an unused second application delegate.

### R5. Runtime shell behavior

The runtime shell exists to prove engine integration, not to become the final
browser UI.

It must:

1. construct one non-private `GeckoSession`;
2. open it exactly once;
3. attach `session.engineView` using full-edge Auto Layout constraints;
4. load an incoming validated URL when present, otherwise load
   `https://example.com/` as the deterministic smoke URL;
5. set the session active/focused while foregrounded and inactive/unfocused
   while backgrounded;
6. close the session when its owner is deallocated.

It must not contain an address bar, tab strip, bookmarks, settings, history,
download UI, prompt UI, persistence, or final visual design. The entire runtime
shell is retired/replaced when `vulpra-browser-ui` introduces the real browser
owner.

### R6. JIT readiness contract

`RuntimeJITCoordinator` is the only product-level JIT orchestration owner.
It starts before `GeckoRuntime.main` and observes
`GeckoRuntime.ChildProcessDidStart`.

For every child-process notification with a positive PID:

1. validate positive PID and normalized process type;
2. process only `tab` children for JIT attachment;
3. call `JITEnabler.shared.enableJIT(forPID:hasTXMSupport:)` on one serial
   queue;
4. register a 4.5-second readiness deadline on a separate state queue, before
   the Gecko child's own five-second wait expires;
5. call `ReportJITStatusForChild` exactly once for the first accepted
   notification for that PID, reporting `true` only after successful attachment
   and `false` for non-tab, unsupported, deadline, or attachment-failure cases;
6. remove the pending PID atomically before reporting, so a late attachment
   completion after the deadline cannot write to a closed readiness pipe;
7. prevent duplicate concurrent attachment for the same PID;
8. report all still-pending PIDs as disabled during teardown, then detach
   active sessions.

Notifications without a positive PID cannot be correlated to a Gecko readiness
pipe and are logged then ignored. Duplicate notifications for an already
pending or completed PID are ignored rather than reported twice.

The initial `hasTXMSupport` value is always `false`. TXM policy is out of
Phase 1A and may be added only with device evidence.

There is no copied retry policy, JIT setting, JIT-less UI, failure controller,
or diagnostics exporter. Failure is logged with `os.Logger` and reported to
Gecko so the child process cannot remain blocked waiting for a readiness signal.

### R7. Header and bridge ownership

Create `App/Bridging/Vulpra-Bridging-Header.h` containing only the contracts the
app consumes:

- `JITEnabler.h`
- `Utils.h`
- `<GeckoView/GeckoView.h>` or the smallest generated Gecko headers needed for
  `ReportJITStatusForChild`, `DeviceOSVersion`, and `JITRuntimeInfo`

Do not copy `UIKit+Private.h` or any old client bridge.

The stale `#import "TSUtils.h"` in `GeckoView.h` has no repository or generated
owner and no consumer in the imported GeckoView tree. Delete that import rather
than adding a compatibility header.

`Modules/VulpraRuntime/Native/Utils.m` remains one canonical shared-native
source and may compile into both the app and GeckoView binaries because the JIT
path consumes entitlement/spawn functions while `GeckoRuntime.swift` consumes
the jetsam function. No target-specific fork or copied implementation is
allowed; growth beyond this three-function boundary triggers an owner split.

### R8. Build-setting ownership

Build settings live in small checked-in configuration owners:

- `Configuration/Base.xcconfig`
- `Configuration/App.xcconfig`
- `Configuration/GeckoView.xcconfig`
- `Configuration/Helper.xcconfig`
- `Configuration/OpenIn.xcconfig`

`project.pbxproj` owns target membership, dependencies, products, phases, and
configuration references only. It must not duplicate large linker/search-path
lists across Debug and Release.

Canonical generated artifact locations:

- Gecko dist: `$(SRCROOT)/Vendor/firefox/obj-aarch64-apple-ios/dist`
- idevice archive: `$(SRCROOT)/.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a`
- archive/package output: `$(SRCROOT)/dist/`

Generated artifacts stay untracked and never appear inside `Modules/`.

### R9. Entitlement profiles

Create newly authored Vulpra entitlement files; do not copy source branding or
comments.

Standard app entitlement:

- `com.apple.developer.kernel.increased-memory-limit`

TrollStore/private app entitlement contains only Phase 1 runtime needs:

- `application-identifier = com.vulpra.browser`
- extended virtual addressing
- increased memory limit
- private memorystatus access
- platform application
- no-sandbox
- GPU IOSurface/AGX user-client classes
- required NSURLSession/cache Mach lookup names

Do not include the source project's uncertain web-browser entitlement,
persona-management entitlement, storage exceptions, or `get-task-allow` in the
release TrollStore profile without evidence.

Helper standard/private entitlements remain Vulpra-owned; their application
identifier must match `com.vulpra.browser.helper`.

### R10. Gecko and idevice producer contract

Update the producer tools so the repository has one explicit sequence:

1. initialize exact Firefox and idevice gitlinks;
2. apply the audited patches;
3. build idevice FFI for `aarch64-apple-ios` with deployment target 15.0 into
   `.build/idevice/.../libidevice_ffi.a`;
4. build Gecko with deployment target 15.0;
5. verify the Gecko artifact key, Xcode/SDK fingerprint, required headers,
   `XUL`, required dylibs, and default theme;
6. invoke the Xcode archive producer.

The Xcode build must fail clearly when Gecko or idevice outputs are absent. It
must not silently fetch, rebuild, or fall back to a stale artifact inside a
normal app target build.

### R11. Unsigned IPA packaging contract

Create new Vulpra release scripts rather than copying the old release scripts.
The producer must:

- archive the `Vulpra` scheme with signing disabled when producing the unsigned
  base archive;
- verify app/framework/extension bundle identifiers before packaging;
- compile `ptrace_jit.c` with the iPhoneOS SDK and deployment target 15.0;
- place `ptrace_jit` at the app bundle root and sign it with its dedicated
  entitlement file for TrollStore output;
- create `Vulpra.ipa` and `Vulpra-TrollStore.tipa`;
- sign only the copied packaging workspace, never mutate the `.xcarchive`;
- refuse to package when required binaries or entitlement files are absent;
- emit a SHA-256 manifest for package outputs.

Public-distribution clearance remains blocked by the existing provenance
issues; package creation is local engineering evidence only.

### R12. OpenIn behavior

Create a new minimal OpenIn implementation that:

- accepts one shared web URL;
- constructs `vulpra://open?url=<encoded URL>`;
- uses `NSExtensionContext.open(_:completionHandler:)` as its single canonical
  host-opening path;
- completes or cancels its extension request exactly once;
- uses Vulpra error domains and strings.

No old OpenIn source is copied. If the public extension open API does not work
on a physical target, device evidence must drive a design amendment; Phase 1A
must not pre-install multiple private/public fallbacks.

## 4. Target membership

| Source root | Vulpra | GeckoView | Vulpra Helper | OpenIn |
| --- | --- | --- | --- | --- |
| `App/**` | compile | no | no | no |
| `Modules/VulpraRuntime/**` | compile except `ptrace_jit.c` | `Native/Utils.m` only if GeckoView requires it | no | no |
| `Extensions/GeckoView/**` | link framework | compile | no | no |
| `Extensions/Helper/ExtensionBridge.{h,mm}` | no | compile | compile/link through GeckoView as required | no |
| `Extensions/Helper/{Helper.swift,main.m}` | no | excluded | compile | no |
| `Extensions/OpenIn/**` | no | no | no | compile |
| plist/entitlement/config files | referenced only | referenced only | referenced only | referenced only |

A portable membership test must fail if old client-like roots or generated
archives enter any synchronized source group.

## 5. Data and control flow

```text
CommandLine
  -> RuntimeJITCoordinator.start
  -> GeckoRuntime.main
     -> UIApplication / Gecko AppShellDelegate
        -> Info.plist scene manifest / SceneDelegate
        -> RuntimeURLRouter
        -> RuntimeShellViewController
           -> GeckoSession.open
           -> attach engineView
           -> GeckoSession.load

GeckoRuntime child notification
  -> RuntimeJITCoordinator serial queue
  -> JITEnabler
  -> ReportJITStatusForChild(success/failure exactly once)

Share URL
  -> OpenIn
  -> vulpra://open?url=
  -> SceneDelegate
  -> RuntimeURLRouter
  -> RuntimeShellViewController.load
```

No runtime state is persisted in Phase 1.

## 6. Error handling

- Missing Gecko/idevice artifact: producer or Xcode preflight fails with the
  exact missing path and corrective command.
- Invalid incoming URL: ignore it and retain/load the smoke URL.
- Missing Gecko engine view after open: show a plain in-process failure label
  and record one log entry; do not introduce a fallback renderer.
- JIT failure: report disabled status to Gecko and log the error; no modal UI.
- OpenIn extraction/open failure: cancel the extension request with a Vulpra
  error exactly once.
- Missing Mac tools on Linux: prerequisite verifier returns a distinct
  `needs-macos` result; portable checks still run.

## 7. Verification strategy

### Phase 1A portable gate

Tests must verify:

- four and only four Xcode product targets;
- target dependency/embed graph;
- iOS 15.0 and arm64 contract;
- exact bundle IDs, URL scheme, Info.plist, entitlement, and Helper/XPC identity;
- target membership and exclusion rules;
- no copied old Xcode project, client, UI, store, resource, migration, or
  generated static archive;
- one JIT owner and exactly-once reporting paths by source contract inspection;
- local quoted-header closure and deletion of stale `TSUtils.h` import;
- deterministic packaging fixture and refusal cases;
- plist parsing, shell/Python syntax, active identity, import boundary, and
  existing Phase 0 gates;
- maintained-file pressure, dependency inventory, and separate size accounting.

Portable tests do not claim Swift/Objective-C or pbxproj semantic compilation.

### Phase 1B Mac gate

The Mac verification record must include:

- exact target Git commit;
- Xcode and SDK versions;
- exact Firefox/idevice commits;
- Gecko artifact key/checksum;
- `xcodebuild -list` target/scheme output;
- Debug and Release-equivalent device archive commands;
- built product bundle IDs, deployment minimums, linked architectures, and
  embedded products;
- unsigned IPA and TrollStore TIPA checksums;
- installation/launch result on iOS 15.8 before Phase 1 completion is upgraded
  from `needs-verification`.

## 8. Efficiency and complexity budget

- `project.pbxproj` target: below 800 lines by using synchronized groups and
  `.xcconfig` owners; crossing 800 requires a graph-generation or owner-split
  review, not hidden acceptance.
- each runtime owner target: below 250 lines;
- `RuntimeJITCoordinator`: below 220 lines and no UI/settings/diagnostics owner;
- each producer/release script: below 250 lines;
- each portable test owner: below 350 lines; split graph, packaging, and runtime
  contract tests rather than extending `test-import-boundary.sh` indefinitely;
- no new third-party package manager or project generator;
- `.build/`, `dist/`, archives, frameworks, static libraries, and IPA/TIPA are
  generated outputs and measured separately;
- Vulpra app source/resource delta, Gecko/vendor delta, and package delta are
  reported independently.

## 9. Alternatives and decision hygiene

### Rejected: copy and strip the old project

It is textually smaller but retains hidden membership, deployment, signing,
client, and packaging assumptions. It violates the fresh-graph requirement.

### Rejected: XcodeGen or Tuist

It reduces pbxproj editing but creates a third-party build dependency and a
second generated-source contract before the first app exists.

### Rejected: custom project generator

A Vulpra-specific generator would add a new schema, generator owner, generated
artifact, and verification surface for a four-target graph. The complexity is
not justified.

### Adopted: checked-in native project plus xcconfig owners

This is the smallest sufficient zero-dependency graph. Portable tests enforce
its contract; Xcode remains the semantic validator on Mac.

## 10. Architecture integrity and falsifiers

- Invariant: one canonical owner per launch, URL routing, JIT readiness,
  target membership, artifact production, and packaging responsibility.
- No duplicate renderer or JIT fallback is introduced.
- Generated outputs never become maintained source owners.
- Discovery that GeckoView compilation requires an excluded client owner
  falsifies the extraction boundary and stops implementation for architecture
  review.
- Discovery that a generated Gecko header or library is missing triggers a
  producer-contract repair, not a copied compatibility header, unless upstream
  evidence proves that header is a real public contract.
- Discovery that OpenIn requires a private host-opening API triggers a targeted
  design amendment after device evidence; no multi-path fallback is added in
  advance.

## 11. ADR and baseline signals

Completion should amend or create architecture memory for:

- the checked-in native Xcode graph and `.xcconfig` ownership split;
- the Phase 1A portable versus Phase 1B Mac evidence boundary;
- the product-level JIT readiness owner and exactly-once child report contract;
- the generated artifact locations and no-build-inside-app-target rule.

The baseline must remain `needs-verification` for Xcode/IPA/device facts until
fresh Mac evidence exists.

## 12. Acceptance boundary

Phase 1A is complete when the project, new sources, producer/package contracts,
and all portable tests are committed and clean, with no excluded owner or
unresolved complexity overrun.

Phase 1 overall remains `needs-verification` until Phase 1B produces fresh Mac
archive, IPA/TIPA, and iOS 15.8 launch evidence. Phase 2 tabs/data work does not
start merely because Phase 1A portable checks pass.

## Appendix A. Task intent and baseline usage

### TaskIntentDraft

- Outcome: fresh iOS 15+ Vulpra runtime shell around the verified substrate.
- Success evidence: four-target project, new runtime owners, deterministic
  artifact/package contracts, portable gates, then separate Mac evidence.
- Stop: excluded-client dependency, scope expansion into browser features, or
  unresolved graph/runtime ownership.
- Non-goals: final browser UI/data/features and public release.

### BaselineUsageDraft

- Required refs: initial baseline, ADR-0001, substrate boundary, efficiency
  policy.
- Acknowledged before design: all four.
- Cited in design: all four.
- Missing refs: Mac/Xcode producer and device evidence.
- Decision: `continue` for Phase 1A; `needs-verification` for Phase 1B.

### Requirement Ready Check

- Requirement sources: baseline, ADR, follow-up sequence, and user approvals.
- Goals/scope/scenario: confirmed.
- Acceptance criteria: separated into portable Phase 1A and Mac Phase 1B.
- Open blocker questions: none for design/planning; Mac availability remains a
  verification dependency.
- Decision: `ready`.

### First-principles review

- First principle: boot one Gecko session in an independently owned Vulpra app
  and release every child from the JIT readiness wait.
- Non-negotiables: fresh graph, iOS 15+, TrollStore-first, no old client/data,
  zero new generator dependency, explicit evidence boundaries.
- Historical assumptions deleted: old pbxproj, deployment target 16, hard-coded
  team, old settings/UI/diagnostics, generated archive inside source roots.
- Smallest sufficient path: native four-target graph, xcconfigs, five small app
  owners, and deterministic producer scripts.
- Escalation signal: dependency on excluded client code or missing substrate
  contract that cannot be repaired at its real producer/owner.
