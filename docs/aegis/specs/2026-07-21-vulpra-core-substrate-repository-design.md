# Vulpra Core-Substrate Repository Design

Date: `2026-07-21`
Status: `approved direction; written-spec review pending`
ArchitectureReviewRequired: `yes`
Target repository: `Gjcgghgcbbjj/vulpra-browser`
Source repository: `Gjcgghgcbbjj/reynard-browser`
Source commit: `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`

## 1. TaskIntentDraft

- **Requested outcome:** create a new Vulpra Browser repository with a fresh
  Git history, copy only the Gecko/iOS execution substrate from Reynard, and
  reimplement the complete browser client under new Vulpra ownership.
- **Goal:** retain the proven Gecko, GeckoView, Helper, JIT, device-support,
  patch, build, and packaging foundation while eliminating inherited client
  architecture, presentation, persistence, branding, and product content.
- **Success evidence:** the new repository contains an audited minimal substrate;
  produces a Vulpra-branded iOS 15+ IPA; restores the functional matrix in this
  document through new Vulpra modules; contains no copied Reynard client tree,
  legacy data migration, or hidden old-client fallback.
- **Stop condition:** the repository and staged implementation plan are complete,
  or work stops with an explicit Gecko/JIT/build dependency that cannot be
  separated from excluded client code without a new design decision.
- **Non-goals:** preserving first-version user data, retaining Reynard branding,
  preserving the old client API or source layout, App Store entitlement work,
  WebKit fallback, SwiftUI migration, or automatically adding cloud sync that
  the source product does not currently implement.

## 2. Confirmed Product Direction

- Product name: **Vulpra Browser**.
- Visual direction: original native-iOS design, minimal light/dark themes,
  bottom-address-bar-first phone layout, card-based phone tabs, iPad sidebar,
  and one-handed operation. Reynard, Firefox, and Via visual identities are not
  copied.
- Platform boundary: UIKit on iOS 15+, with TrollStore as the primary delivery
  path and existing alternate IPA/TIPA/Jailbroken packaging retained where the
  substrate supports it.
- Feature direction: the completed product restores the current user-facing
  browser capabilities rather than shipping as a permanently reduced browser.
- Compatibility direction: no migration of bookmarks, history, tabs, settings,
  downloads, or other first-version client data.

## 3. BaselineReadSetHint

Unless explicitly identified as target-repository paths, relative evidence
paths in this design refer to the source repository at pinned commit `ef14c29`.

- `docs/aegis/baseline/2026-07-19-initial-baseline.md`
- `docs/aegis/baseline/2026-07-20-frontend-redesign-baseline.md`
- `docs/aegis/specs/2026-07-19-ios16-stability-usability-design.md`
- `docs/aegis/specs/2026-07-20-browser-frontend-redesign-design.md`
- `docs/aegis/specs/2026-07-20-gecko-artifact-pipeline-brief.md`
- `docs/aegis/adr/ADR-0001-frontend-surfaces-and-gecko-feature-ownership.md`
- `README.md`
- `Package.swift`
- `.gitmodules`
- `.github/workflows/`
- `browser/Reynard.xcodeproj/project.pbxproj`
- `browser/Reynard/JIT/`
- `browser/GeckoView/`
- `browser/Helper/`
- `engine/`, `patches/`, `support/`, and `tools/`

## 4. BaselineUsageDraft

- **Required baseline refs:** existing Gecko ownership, the prior iOS 16/TrollStore
  boundary, JIT and Helper runtime boundaries, Gecko artifact pipeline, and
  current feature inventory.
- **Delivered context refs:** user approvals recorded in the 2026-07-21 design
  dialogue: new repository, Vulpra brand, complete client rewrite, full feature
  restoration, original UIKit interface, and no old-data migration.
- **Acknowledged before plan refs:** both existing baselines, current frontend
  ownership ADR, current Xcode target graph, and the audited source commit.
- **Cited in design refs:** section 3 and the import/exclusion manifests below.
- **Missing refs:** a macOS dependency-closure build of the extracted substrate,
  a Vulpra signing identity/team choice, and physical iOS 15/16 verification.
- **Decision:** `continue` for specification and planning; substrate inclusion
  remains subject to dependency-closure verification during execution.

## 5. Requirement Ready Check

- **Requirement source refs:** current user approvals and section 2.
- **Goals and scope refs:** sections 1, 6, 7, and 10.
- **User/scenario refs:** iPhone one-handed browsing, iPad sidebar browsing,
  TrollStore installation, JIT recovery, and full local browser-data workflows.
- **Requirement item refs:** sections 8 through 12.
- **Acceptance/verification refs:** sections 14 and 15.
- **Open blocker questions:** none for planning. Bundle identifiers use the
  defaults in section 9 unless changed before remote publication/signing.
- **Decision:** `ready`.

## 6. First-Principles Decision Review

### First-principles invariants

- **Non-negotiable goal:** obtain an independently owned Vulpra browser client
  without discarding the difficult Gecko-on-iOS substrate that already builds.
- **Non-negotiable constraints:** Gecko remains the renderer; JIT, GeckoView,
  Helper, patches, submodules, and packaging must remain coherent; iOS 15+ and
  UIKit remain supported; copied code retains applicable license and copyright
  notices.
- **Historical assumptions to delete:** the existing client layout, stores,
  oversized UIKit controllers, product copy, target names, and bundle identity
  are not required merely because the engine substrate originated in Reynard.

### Owner/retirement matrix

- **New canonical owner:** the Vulpra repository and modules described in
  section 9.
- **Old owner:** all code under the existing Reynard client and product layers.
- **Compat-only carrier:** none. The source repository may be consulted as
  reference but is never linked, vendored, or used as a runtime fallback.
- **Delete-first/retirement trigger:** excluded client files never enter the new
  repository. Any accidentally imported excluded path is removed before the
  first substrate commit.

### Falsification matrix

- If Gecko/JIT/Helper cannot build without a specific excluded file, classify
  that file by responsibility rather than copying its containing directory.
- If the file is substrate glue, extract and rename the minimal responsibility.
- If the file carries browser product behavior, replace it with a Vulpra-owned
  protocol or implementation.
- If the dependency cannot be separated without changing Gecko/runtime
  contracts, stop that slice for architecture review.

### Verdict

- **Adopt:** fresh repository plus audited minimal substrate import.
- **Reject:** copying the whole source tree and deleting afterward.
- **Reject:** preserving old/new client implementations in parallel.

## 7. Options and Selected Approach

### Option A: rewrite in the current repository

Rejected because it leaves the product tied to inherited history and creates a
long-lived broken-build window during broad deletion.

### Option B: create a second app target in the current repository

Rejected because it temporarily duplicates product ownership and increases the
risk that old stores, resources, or controllers leak into the new client.

### Option C: fresh repository with audited substrate import

Selected. It provides the clearest ownership boundary and ensures that every
non-substrate file enters Vulpra only through an explicit design decision.

## 8. Import and Exclusion Boundary

### 8.1 Candidate substrate imports

The following are candidates, not a blanket copy list. Each import must pass
the dependency-closure and product-behavior checks in section 13.

- `engine/firefox/` submodule and `engine/release.txt`.
- `patches/` and patch configuration required for the pinned Gecko release.
- `support/idevice/` submodule.
- `browser/GeckoView/` Gecko process/session bridge.
- `browser/Helper/` helper process bridge.
- JIT implementation currently under `browser/Reynard/JIT/`, moved under
  `Modules/VulpraRuntime/JIT/` with imports, names, and product-facing messages
  reviewed individually.
- Required Objective-C/Swift bridging declarations.
- Required entitlements and extension plist capabilities, rewritten under
  Vulpra identifiers.
- `tools/development/` and `tools/release/`, renamed/reworked where they encode
  Reynard paths or product names.
- Gecko artifact and IPA packaging workflows after identity/path review.
- `LICENSE`, `LICENSE.firefox`, retained file-level notices, and a new
  `NOTICE.md`/provenance manifest.

### 8.2 Explicit exclusions

- `browser/Reynard/Client/` in full.
- Existing `browser/Reynard/BrowserCore/` and
  `browser/Reynard/StabilityCore/`; needed policies are re-specified and
  rewritten under Vulpra ownership.
- Existing `AppDelegate.swift`, `SceneDelegate.swift`, client startup and
  migration code.
- Existing stores, schemas, migrations, browser preferences, and backup format.
- Existing homepage, chrome, tab, sidebar, library, settings, search, context
  menu, add-on UI, site settings, and recovery UI.
- Existing app icons, launch screen, product strings, screenshots, update feeds,
  release notes, source metadata, bundle identifiers, and Reynard-branded URL
  schemes.
- Existing client tests that validate old owners or old persistence formats.

### 8.3 Reference-only rule

Excluded source may be inspected to inventory behavior or understand a Gecko
contract, but it must not be copied into Vulpra and cosmetically renamed. A new
Vulpra implementation must have a documented owner and tests derived from the
approved requirement, not from preserving the old class structure.

## 9. Target Repository and Architecture

Default local path: `/root/vulpra-browser`

Default remote: `https://github.com/Gjcgghgcbbjj/vulpra-browser`

Default identifiers:

- App: `com.vulpra.browser`
- Gecko extension: `com.vulpra.browser.geckoview`
- Helper: `com.vulpra.browser.helper`
- Open In extension: `com.vulpra.browser.openin`
- URL scheme: `vulpra`

Proposed structure:

```text
vulpra-browser/
├── App/
│   ├── VulpraApp/
│   └── Resources/
├── Modules/
│   ├── VulpraRuntime/
│   ├── VulpraCore/
│   ├── VulpraData/
│   ├── VulpraFeatures/
│   ├── VulpraUI/
│   └── VulpraDiagnostics/
├── Extensions/
│   ├── GeckoView/
│   ├── Helper/
│   └── OpenIn/
├── Vendor/
│   ├── firefox/
│   └── idevice/
├── Patches/
├── Tools/
├── Tests/
└── docs/
```

Ownership:

- `VulpraApp`: process/scene entry points and dependency composition only.
- `VulpraRuntime`: Gecko lifecycle, JIT state, Helper/extension readiness,
  session attachment, degraded modes, and runtime recovery.
- `VulpraCore`: browser domain contracts, tab/navigation models, feature
  capability contracts, and portable policies.
- `VulpraData`: the only owner for Vulpra local persistence, transactions,
  schemas, backup/restore formats, and clearing data.
- `VulpraFeatures`: downloads, extensions, user scripts, blocking, translation,
  site permissions, media, and other feature coordinators.
- `VulpraUI`: UIKit presentation and interaction, with no duplicate persistence
  or Gecko execution owner.
- `VulpraDiagnostics`: privacy-bounded runtime events and export.

Dependency direction:

```text
Gecko / Helper / JIT substrate
             ↓
        VulpraRuntime
             ↓
 VulpraCore ← VulpraData
             ↓
      VulpraFeatures
             ↓
         VulpraUI
             ↓
         VulpraApp
```

UI does not directly own Gecko execution or persistent state. Runtime and
feature modules depend on protocols in `VulpraCore`, not on UIKit controllers.

## 10. Functional Restoration Matrix

### 10.1 Browsing shell

- URL/search entry, suggestions, navigation, reload/stop, progress, page title,
  favicon, desktop/mobile mode, page zoom, find in page, and external URL open.
- Phone bottom bar by default; safe top-bar alternative; responsive iPad layout.
- Context menus, link/image preview, text selection actions, file/date/color/
  select inputs, permission prompts, and share actions.

### 10.2 Tabs and sessions

- Regular and private tabs, create/select/reorder/close, undo close, card grid,
  iPad sidebar, lifecycle flush, crash/process recovery, and deterministic
  startup behavior.
- Vulpra defines a new persistence schema. No old schema reader or migrator is
  included.

### 10.3 Local data and library

- Homepage, favorites, bookmarks/folders, history, frequently visited sites,
  recent/closed tabs, downloads, site metadata/favicons, clear-data workflows,
  and local backup/restore for approved portable data.

### 10.4 Web and power features

- Gecko extensions and permission management.
- Content blocking and filter configuration.
- User scripts.
- Night mode/content appearance.
- Page translation.
- Site permissions, user-agent overrides, language configuration, compatibility
  settings, privacy controls, and configurable toolbar actions.
- Media session and picture-in-picture where supported by the Gecko substrate.

### 10.5 Reliability and delivery

- JIT state and actionable recovery.
- Explicit degraded mode rather than a silent success state.
- Privacy-bounded diagnostics and export.
- Open In extension.
- IPA, TrollStore TIPA, and jailbroken packaging supported by the substrate.
- Reusable Gecko artifact workflow and checksum/manifest verification.

## 11. Data Design

- Vulpra starts with a new schema version `1` and a new application container.
- No Reynard bundle identifier, app group, database, preferences domain, or
  backup artifact is read.
- `VulpraData` is the single persistence owner.
- Regular tabs, bookmarks, history, downloads, settings, permissions, user
  scripts, and filters use explicit repositories backed by one transactional
  database/file boundary selected during implementation planning.
- Private tabs and private browsing records are memory-only unless an approved
  requirement explicitly states otherwise.
- Credentials, cookies, form content, and full URLs are excluded from diagnostic
  export by default.

## 12. Brand and Documentation Boundary

- Rename app, targets, schemes, products, bundle identifiers, URL schemes,
  display names, helper labels, update metadata, and package names to Vulpra.
- Create new icons, launch screen, colors, typography tokens, screenshots, and
  README copy.
- Do not reuse Reynard/Firefox/Via icons, screenshots, marketing language, or
  visual trade dress.
- Preserve required licenses and file-level notices for copied substrate.
- Add `NOTICE.md` containing the source repository URL, imported source commit,
  imported component list, and license mapping.
- Acknowledgements describe inherited substrate factually without preserving
  the old project's promotional voice.

## 13. Substrate Extraction Protocol

For every candidate path:

1. Identify its runtime responsibility and direct build references.
2. Search imports, Xcode membership, script paths, plist references, bundle
   identifiers, generated outputs, and environment assumptions.
3. Classify each dependency as substrate, product behavior, build metadata, or
   unused/dead.
4. Import only substrate and required build metadata.
5. Replace product behavior with a Vulpra-owned interface or implementation.
6. Rename product identity before the first buildable Vulpra commit.
7. Run lingering-reference checks for `Reynard`, `minh-ton`, old bundle IDs,
   old app groups, old URL schemes, and excluded client paths.
8. Verify that Gecko/JIT/Helper build and package without the source repository.

The source repository is not used as a submodule or runtime dependency.

## 14. Verification Strategy

### 14.1 Import gate

- Imported-path manifest matches the approved substrate boundary.
- No `browser/Reynard/Client` file or old product resource exists.
- All submodules and patches resolve from the new repository.
- License/provenance manifest covers every copied source group.
- Old product names are absent from Vulpra user-facing identity, bundle/runtime
  contracts, and new owner names. They may remain only in preserved copyright
  or provenance notices and in imported low-level patch symbols whose rename
  would change the audited substrate; each such symbol is listed in the import
  manifest.

### 14.2 Portable gate

- Unit tests for domain policies, tab/session state, persistence transactions,
  backup validation, permissions, toolbar validation, translation, blocking,
  user scripts, and recovery decisions.
- Shell syntax, plist/JSON/string-catalog validation, forbidden-reference
  searches, and `git diff --check`.

### 14.3 macOS/Xcode gate

- Xcode target/scheme enumeration.
- Debug and release archive builds.
- Gecko artifact download/verification and local-link smoke checks.
- Extension embedding, entitlements, Info.plist, bundle ID, and IPA structure
  validation.

### 14.4 Physical-device gate

- iOS 15.8 and iOS 16.7, covering arm64 and arm64e where hardware is available.
- Cold/warm start, JIT success/failure/retry, tab/session recovery, background
  termination, memory pressure, downloads, media/PiP, extensions, permissions,
  private browsing, data clearing, VoiceOver, Dynamic Type, Reduce Motion, and
  60/120 Hz interaction evidence.

## 15. Acceptance Criteria

1. `/root/vulpra-browser` is a standalone fresh Git repository with no history
   dependency on Reynard.
2. Its initial import identifies source commit `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`.
3. No excluded client source or Reynard product asset is present.
4. All retained source/build files are covered by the import manifest and
   applicable notices.
5. Vulpra targets use the identity defaults in section 9 unless explicitly
   amended before publication.
6. A Vulpra-branded IPA can be produced using the retained Gecko artifact and
   packaging model.
7. Every feature in section 10 is implemented through a named Vulpra owner and
   verified at the appropriate gate.
8. No old client fallback, old persistence reader, or parallel store exists.
9. The source Reynard repository remains unchanged except for this design and
   later planning/evidence documents.
10. Release readiness is not claimed until macOS/Xcode and physical-device
    gates pass.

## 16. Anti-Entropy Declaration

- **Deletion Class:** `code-retirement` and `contract-carrying code` exclusion.
- **Old Path/Object:** Reynard client, product resources, persistence formats,
  target identity, and client tests.
- **New Canonical Owner:** Vulpra modules and targets.
- **Expected Preserved Behavior:** Gecko rendering, JIT, Helper/extension
  process integration, engine patches, device support, artifact construction,
  and IPA packaging.
- **Expected Retired Behavior:** all inherited client ownership, old branding,
  old data compatibility, and old UI/store fallback.
- **External Boundary Touched:** yes; Gecko, idevice, signing/entitlements, and
  package formats.
- **Source-of-Truth Data Risk:** none; the new repository does not mutate old
  installations or their data.
- **User Confirmation Required:** no for source import/exclusion; any later
  operation that deletes a remote repository or live user data requires its own
  scoped confirmation.

### Retirement Decision

- **Path:** `delete-first` by non-import.
- **Why:** old product code has no external compatibility requirement in the
  new repository, and the user explicitly rejected old-data compatibility.
- **Non-edits:** do not delete or rewrite the source repository; do not alter
  live device data; do not retain hidden compatibility readers.

### Verification Plan

- **Main-path check:** Vulpra builds and carries all required behavior through
  new owners.
- **Lingering-reference check:** old product names, identifiers, resources, and
  client paths are absent from user-facing identity and Vulpra-owned contracts;
  preserved attribution and manifest-listed low-level patch symbols are the
  only permitted exceptions.
- **Negative check:** old databases/preferences are not discovered or loaded.
- **Boundary check:** Gecko/JIT/Helper, entitlements, artifacts, and packaging
  remain functional.

## 17. Product Risk Lens

- **Value:** clear product ownership, lower inherited client entropy, original
  brand/UI, and a maintainable base for full-feature development.
- **Non-goals:** fastest possible short-term feature delivery or source-level
  compatibility with the first IPA.
- **Trade-offs:** a longer path to full parity, new persistence and UI defects,
  and renewed device-validation cost in exchange for a clean client boundary.
- **Decision needed:** none before implementation planning; signing/team and
  remote publication details may be finalized at their execution gates.

## 18. Architecture Integrity Lens

- **Invariant:** Gecko execution and iOS runtime integration remain coherent
  while client behavior has exactly one Vulpra owner.
- **Canonical owner/contract:** substrate owns engine/process/JIT mechanics;
  Vulpra modules own product behavior and data.
- **Responsibility overlap:** prohibited between imported substrate and new
  client modules; product-facing behavior discovered in substrate candidates
  must be extracted or replaced.
- **Higher-level simplification:** import a verified dependency closure instead
  of inheriting the source directory structure.
- **Retirement/falsifier:** any required runtime path that still depends on an
  excluded client owner falsifies the current extraction boundary and triggers
  architecture review.
- **Verdict:** `proceed`, with ADR and new-repository baseline creation required
  after the first verified substrate import.

## 19. Baseline Role Alignment

- **Product/Requirement Baseline:** this approved Vulpra direction supersedes
  the prior requirement to evolve the Reynard client in place.
- **Architecture/Runtime Boundary Baseline:** Gecko, patches, GeckoView, Helper,
  JIT, idevice support, and packaging remain valid substrate candidates; old
  client/store ownership does not carry into Vulpra.
- **Result:** `Design Defect` in the previous in-place frontend direction for
  the newly selected product goal; the previous work remains historical
  evidence rather than Vulpra authority.
- **Scope:** `both`.
- **Next action:** create the Vulpra implementation plan, then establish a new
  dual baseline and ADR in the new repository after substrate verification.

## 20. Complexity Budget

- **Artifact class:** high-complexity repository extraction, architecture,
  product rewrite, persistence replacement, and delivery migration.
- **Target artifacts:** new repository, Xcode target graph, six Vulpra modules,
  extensions, vendor substrate, patches, tools, tests, and documentation.
- **Current pressure:** the source client contains roughly 91,000 lines across
  about 260 client files plus tightly coupled Xcode/build metadata.
- **Projected pressure:** high but bounded by module ownership and staged
  vertical delivery.
- **Budget result:** `at-risk` if planned as one task; `within-budget` only when
  decomposed into independently buildable stages.
- **Planned governance:** substrate import, runtime shell, core browsing,
  session/data, library, advanced features, UI/accessibility, and release gates
  are separate plan sections with explicit acceptance and no parallel owners.

### Plan-Time Complexity Check

- **Better file boundary:** new repository and named modules rather than edits
  inside the old client tree.
- **Recommendation:** `split task`; keep each phase buildable and require
  feature-owner and lingering-reference verification before proceeding.

## 21. ADR Signals

After verified implementation evidence exists, record decisions for:

1. fresh-repository substrate provenance and dependency direction;
2. Vulpra runtime versus client feature ownership;
3. Vulpra persistence and no-migration boundary;
4. Gecko artifact and packaging ownership in the new repository.

The ADRs must be recorded from verified work and synchronized into the new
repository baseline; this design does not pre-accept unimplemented decisions.
