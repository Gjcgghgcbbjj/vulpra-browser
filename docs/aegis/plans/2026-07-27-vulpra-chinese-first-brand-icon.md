# Vulpra Chinese-First Localization and Brand Icon Implementation Plan

**Goal:** Ship a Chinese-first Vulpra client and the approved White Porcelain
Flame V icon in newly validated IPA/TIPA packages.

**Architecture:** Standard `zh-Hans.lproj` and `en.lproj` resources are the sole
display-string source; a small `VulpraL10n` helper performs lookups and
formatting. A deterministic Vulpra-owned generator produces one AppIcon asset
catalog from geometric brand parameters. Xcode's synchronized App/OpenIn roots
embed resources without a second project-file resource owner.

**Tech Stack:** UIKit, Foundation localization APIs, Xcode file-system
synchronized groups, asset catalogs, Python 3 standard library, GitHub Actions.

**Baseline/Authority Refs:**

- `docs/aegis/specs/2026-07-27-vulpra-chinese-first-brand-icon-brief.md`
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`
- `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`

**Compatibility Boundary:** Preserve `com.vulpra.browser`, iOS 15.0, arm64,
iPhone/iPad, OpenIn, `TabManager`, `BrowserTab`, Codable stores, all user data,
the sole VulpraEngineKit adapter, and the precompiled Gecko runtime. Do not add
a runtime language override, fallback adapter, migration, alternate icon, or
third-party dependency. Do not commit or move the user branch; HEAD remains
`9fb58d6bb8c1e50d09923a1c76bdac52eddfdf26`.

**Verification:** Browser/RuntimeShell/IndependentEngine portable suites,
localization and PNG structural tests, plist/Xcode parsing, simulator Chinese
UI plus installed-icon evidence, GitHub archive/package workflow, local
`sha256sum`, package validator, ZIP integrity, retired-path scan, Aegis check,
and HEAD/ref cleanup.

## Plan Basis

- Fact: UI display strings are currently embedded directly in 17 App/OpenIn
  Swift owners; no localization resource exists.
- Fact: the project uses Xcode file-system synchronized roots and has no asset
  catalog or configured AppIcon name.
- Fact: the approved visual system requires a Vulpra-owned fox/flame mark and
  restrained brand roles on neutral surfaces.
- Assumption resolved by user: the icon is predominantly white and uses the
  approved White Porcelain Flame V geometry.
- Unknown requiring runtime evidence: exact asset-catalog compiler behavior and
  rendered simulator icon under Xcode 26.4.1.

## BaselineUsageDraft

- Required refs: the three refs listed above.
- Acknowledged before planning: all three.
- Cited in plan: all three.
- Missing refs: none.
- Decision: `continue`.

## Requirement Ready Check

- Requirement source: approved brief and user visual approval.
- Goal/scope: Chinese-first resources, English fallback, one icon, rebuilt
  validated packages.
- User/scenario: Chinese-speaking primary user on iPhone/iPad; English system or
  per-app selection remains usable.
- Acceptance: brief section 6.
- Open blocker questions: none.
- Decision: `ready`.

## Architecture Integrity Lens

- Invariant: one owner for display strings and one owner for AppIcon output.
- Canonical contracts: `.lproj` key sets and `AppIcon.appiconset/Contents.json`.
- Responsibility overlap: none; controllers request localized values and do
  not choose language.
- Higher-level simplification: use synchronized resource roots instead of
  manually duplicating PBX resource entries.
- Retirement/falsifier: all user-visible hard-coded English is migrated; a
  required runtime language override or duplicate icon owner falsifies the
  plan.
- Verdict: aligned.

## Plan Pressure Test

- Owner/contract/retirement: explicit resource owners; hard-coded display text
  retires with no compatibility carrier.
- Verification: portable structural checks plus Xcode simulator and package
  evidence.
- Task executability: local generation/tests first, macOS runtime evidence last.
- Pressure result: `proceed`.

## Complexity Budget

- Target maintained source: one helper under 80 lines, one generator under 260
  lines, one focused test under 260 lines.
- Existing pressure: largest App owner is 287 lines and remains below the
  350-line client threshold.
- Projected pressure: controllers gain lookup calls only; no controller should
  cross 350 lines.
- Budget result: `within-budget`.
- Recommendation: add dedicated resource/helper/tool files; edit controllers in
  place without refactoring unrelated behavior.

## Task 1: Establish localization and icon source contracts

**Files:** create `Tests/Browser/test-localization-and-icon.py`; modify
`Tests/Browser/run-portable.sh`.

**Why:** A portable contract must distinguish localized display text from
technical strings and reject incomplete asset output before remote Xcode work.

**Impact/Compatibility:** Test-only; no runtime, persistence, or packaging
behavior changes.

**Verification:** `python3 Tests/Browser/test-localization-and-icon.py` initially
fails for missing resources, then passes after Tasks 2-4.

- [x] Write checks for development region, matching `zh-Hans`/English key sets,
  required Chinese values, localized InfoPlist values, Swift lookup usage,
  all 18 asset manifest roles, PNG dimensions/opacity, and AppIcon build setting.
- [x] Add the test to `Tests/Browser/run-portable.sh` and run it to capture RED.
- [x] Keep allowlists limited to logger text, persistence/notification keys,
  URL/scheme values, reuse identifiers, and SF Symbol names.
- [x] Run the test after each resource slice and preserve actionable failures.
- [x] Review the test diff without committing; confirm HEAD is unchanged.

## Task 2: Add Chinese-first resources and migrate display strings

**Files:** create `App/Localization/VulpraL10n.swift`,
`App/zh-Hans.lproj/Localizable.strings`, `App/en.lproj/Localizable.strings`,
`App/zh-Hans.lproj/InfoPlist.strings`, `App/en.lproj/InfoPlist.strings`, matching
OpenIn `.lproj` resources; modify App/OpenIn Swift files containing visible
English and both Info.plists as needed.

**Why:** Chinese must be the primary UI language while English remains a normal
iOS fallback and internal/data identifiers remain stable.

**Impact/Compatibility:** Display values only. Codable enum raw values, stored
titles/URLs, filenames, engine messages, and OpenIn URL routing remain stable.

**Verification:** `python3 Tests/Browser/test-localization-and-icon.py` and
`./Tests/Browser/run-portable.sh`.

- [x] Add RED assertions for every visible surface: browser chrome, start page,
  tabs, library, downloads, page tools, privacy, settings, prompts, permission
  descriptions, and OpenIn errors/display name.
- [x] Implement `VulpraL10n.text` and `VulpraL10n.format` using bundle lookup,
  then create complete matching English and Simplified Chinese key sets.
- [x] Replace visible literals with localized lookups while leaving technical
  literals and user content unchanged.
- [x] Parse `.strings`/plists and run browser portable tests GREEN.
- [x] Scan Swift sources for remaining display English, review exceptions, and
  confirm no schema/migration/data-deletion code was added.

## Task 3: Generate the White Porcelain Flame V AppIcon

**Files:** create `Tools/Brand/generate-app-icons.py`,
`App/Resources/Assets.xcassets/Contents.json`,
`App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`, generated PNG
renditions, and `docs/brand/vulpra-icon-master.svg`.

**Why:** A deterministic geometric master preserves the approved minimal icon
at small iOS sizes and avoids opaque generated-asset drift.

**Impact/Compatibility:** Adds one AppIcon owner and no runtime dependency.

**Verification:** `python3 Tools/Brand/generate-app-icons.py --check`,
`python3 Tests/Browser/test-localization-and-icon.py`, and local pixel sampling
plus image preview.

- [x] Add RED tests for all iOS 15 iPhone/iPad roles, the 1024 marketing icon,
  exact dimensions, PNG signature/chunks, opaque output, and porcelain-white
  dominant pixel ratio.
- [x] Implement standard-library supersampled rasterization for the porcelain
  field, cool-gray separation, graphite Flame V, and vermilion accent.
- [x] Generate all renditions deterministically and emit a matching asset
  catalog manifest plus human-readable SVG master.
- [x] Inspect the 1024 master and representative 20/60/180px renditions; tune
  only geometry/contrast when small-size silhouette is unclear.
- [x] Run `--check` and portable asset tests GREEN; confirm no alpha, gradient,
  text, alternate icon, or second catalog owner.

## Task 4: Integrate resources into the canonical Xcode/package graph

**Files:** modify `Configuration/Base.xcconfig`, `Configuration/App.xcconfig`,
`Vulpra.xcodeproj/project.pbxproj`, package/source-contract tests as required.

**Why:** Xcode must treat `zh-Hans` as the development language and compile the
single AppIcon catalog into the application archive.

**Impact/Compatibility:** App resource build only; targets, identifiers,
entitlements, engine staging, and extension dependencies remain unchanged.

**Verification:** all three portable suites, workflow YAML parse,
`test_cutover_readiness.py --require-cutover`, `git diff --check`.

- [x] Add RED Xcode contract assertions for `developmentRegion = zh-Hans`,
  known regions, and `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- [x] Change the canonical development language and known-region declarations;
  add the AppIcon setting only to the App configuration.
- [x] Confirm synchronized groups include App/OpenIn localization resources and
  the catalog without manual duplicate PBX build files.
- [x] Run all portable suites and cutover checks GREEN.
- [x] Review the full diff for owner drift, fallback growth, user-data changes,
  oversized files, and retired-path regressions; keep HEAD unchanged.

## Task 5: Build, inspect, package, and deliver

**Files:** temporary CI commit-tree ref only; replace `dist/Vulpra.ipa`,
`dist/Vulpra-TrollStore.tipa`, `dist/SHA256SUMS`; update work evidence/baseline
only with actual run IDs and hashes.

**Why:** Source/resource checks do not prove Xcode asset compilation, Chinese UI
rendering, installed icon appearance, signing, or final package contents.

**Impact/Compatibility:** Generated deliverables only. Temporary refs are
deleted; the user branch is neither committed nor moved.

**Verification:** successful simulator and package workflows; package validator,
`sha256sum -c`, `unzip -tq`, artifact inspection for `zh-Hans.lproj`, `en.lproj`,
and compiled AppIcon; final desktop hashes.

- [x] Create a metadata-complete commit tree without changing HEAD, push an
  exact temporary `ci/vulpra-chinese-icon-*` ref, and run simulator smoke.
- [x] Inspect screenshot/log evidence for Chinese UI, visible icon, navigation,
  child process survival, and no crash; repair the canonical owner if needed.
- [x] Run the package workflow from the verified snapshot and download the
  final IPA/TIPA artifact into `dist/`.
- [x] Validate SHA-256, signature/content, ZIP integrity, localization resources,
  AppIcon compilation, cutover readiness, and all portable regressions.
- [x] Copy validated files to `C:\Users\niting\Desktop\Vulpra`, delete all
  local/remote `ci/vulpra-chinese-icon-*` refs, run Aegis bundle/check, and
  confirm HEAD remains `9fb58d6bb8c1e50d09923a1c76bdac52eddfdf26`.

## Risks and retirement

- White-background icons can disappear on white wallpaper; the cool-gray inset
  separation and graphite silhouette are required, not optional decoration.
- Hard-coded English retirement is `delete-first` code retirement. The new
  canonical owner is the matched `.lproj` key set; there is no compatibility
  exception.
- English localization is a supported product language, not a runtime fallback
  path.
- No live state, schema, or user data is deleted. Persistent-state confirmation
  is therefore not triggered.
- Xcode 16.4 availability and physical-device evidence remain external residual
  risks unless the current runner/device environment changes.

## Plan self-review

- Spec coverage: every brief acceptance item maps to Tasks 1-5.
- Placeholder scan: no unresolved implementation choice or placeholder.
- Type consistency: controllers call one localization helper; resources share
  identical keys; one AppIcon build setting names one catalog owner.
- Compatibility: runtime, persistence, identifiers, target graph, and user data
  are explicit non-edits.
- Verification: local structural, Xcode simulator, archive/package, and local
  delivery checks are all represented.
- Complexity: dedicated owners stay within stated budgets; no fallback,
  adapter, or unrelated refactor is introduced.
