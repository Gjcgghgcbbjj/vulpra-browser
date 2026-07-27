# Vulpra Porcelain Native UI Implementation Plan

**Goal:** Repair the prototype-like Vulpra interface into the approved
Porcelain Native direction and deliver refreshed Chinese-first IPA/TIPA files.

**Architecture:** Existing UIKit view owners retain behavior and state. A
bounded semantic appearance owner supplies porcelain/graphite/vermilion/teal
roles; browser chrome, start page, tab grid, and feature lists each implement
their own presentation without duplicating navigation or data ownership.

**Tech Stack:** UIKit, Core Animation, SF Symbols, Dynamic Type, standard asset
catalogs, Python portable source contracts, Xcode simulator screenshots.

**Baseline/Authority Refs:**

- `docs/aegis/specs/2026-07-27-vulpra-porcelain-native-ui-design.md`
- `docs/aegis/specs/2026-07-27-vulpra-chinese-first-brand-icon-brief.md`
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`
- `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`

**Compatibility Boundary:** Preserve engine/process/session behavior, all
product actions, `TabManager`/`BrowserTab`, Codable records, user data,
identifiers, iOS 15, OpenIn, and the four-target graph. Do not copy old client
UI, add SwiftUI/third-party UI, or move/commit the user branch HEAD.

**Verification:** New portable UI contracts, all existing portable suites,
Chinese start-page and HTTPS-page simulator screenshots, icon/resource/package
inspection, local SHA/signature/ZIP validation, and desktop delivery.

## Planning checks

- Requirement Ready Check: `ready`; user selected direction A and approved the
  written design.
- Architecture Integrity: existing view owners are canonical; no parallel UI
  layer or state owner is needed.
- Plan Pressure: `proceed`; visual verification expands the simulator workflow
  but does not alter engine runtime evidence.
- Complexity: all target files are below 180 lines except the 287-line browser
  controller, which needs no visual-policy growth. New helpers stay below 100
  lines; no App file may cross 350 lines.
- Retirement: duplicate start-page search UI is internal code retirement using
  `delete-first`; the persistent browser omnibox remains the sole owner.

## Task 1: Freeze Porcelain Native source contracts

**Files:** create `Tests/Browser/test-porcelain-ui.py`; modify
`Tests/Browser/run-portable.sh` and stale localized source assertions.

**Why:** Prevent regression to duplicate search, oversized radii/shadows, blue
accent, unstable controls, and unlocalized accessibility labels.

**Verification:** capture RED with `python3 Tests/Browser/test-porcelain-ui.py`,
then GREEN after Tasks 2-4.

- [x] Assert semantic colors, 12pt dock/8pt item radii, 44pt controls, and
  bounded chrome height contracts.
- [x] Assert StartPage has no `UITextField`, tab cards use 8pt radius and
  private teal selection, and list screens own empty states/setting sections.
- [x] Update browser source tests to check localization keys rather than retired
  English literals.
- [x] Add the UI contract to the portable runner and capture expected RED.
- [x] Review test scope for technical-string false positives; do not commit.

## Task 2: Implement shared appearance and browser chrome

**Files:** modify `App/UI/VulpraAppearance.swift`, `BrowserChromeView.swift`,
`OmniboxSuggestionsView.swift`, `PressableButton.swift`, and progress styling.

**Why:** The loaded-page screenshot is dominated by a heavy floating white
panel and generic blue accent instead of page-first neutral chrome.

**Verification:** UI contract plus Browser portable gate; remote loaded-page
simulator screenshot in Task 5.

- [x] Add semantic porcelain, graphite, vermilion, private teal, separator, and
  surface roles with dark/increased-contrast behavior.
- [x] Reduce dock/address/suggestion radii and shadow, add hairline separation,
  and keep 44pt stable tool targets.
- [x] Make address focus compact the secondary row without geometry overlap;
  retain truthful URL/security/load/tab states.
- [x] Reduce press animation amplitude and keep Reduce Motion behavior.
- [x] Run source contracts GREEN and inspect line/owner budgets.

## Task 3: Recompose start page and tabs

**Files:** modify `StartPageViewController.swift`, `TabCardCell.swift`,
`TabOverviewViewController.swift`; create `App/UI/VulpraBrandMarkView.swift`.

**Why:** Remove the duplicate search owner and establish a coherent branded
start surface and restrained tab grid.

**Verification:** UI/localization tests; simulator start-page screenshot; loaded
page regression.

- [x] Remove StartPage `UITextField` and its delegate path while preserving
  quick-site opening and feature actions.
- [x] Add compact code-native brand mark from the approved icon geometry,
  scroll-safe content, whole-word action labels, and two/three-column quick sites.
- [x] Set tab card radius to 8pt, consistent border/footer, selected
  vermilion/private teal state, and stable close target.
- [x] Tune overview spacing/background/segmented presentation for compact and
  regular widths without duplicating tab state.
- [x] Run source contracts and confirm no second omnibox/fallback owner exists.

## Task 4: Unify lists, settings, and empty states

**Files:** create `App/UI/VulpraEmptyStateView.swift`; modify settings, library,
downloads, permissions, and privacy controllers where presentation requires.

**Why:** Feature screens need the same quiet hierarchy rather than one flat,
unstructured list.

**Verification:** Browser portable gate, localization key parity, file-size
budget, and Xcode compilation.

- [x] Implement one compact empty-state view with symbol/title only.
- [x] Add empty states to bookmarks/history/downloads/permissions where data is
  absent and refresh them after mutations.
- [x] Group settings into General, Appearance, Privacy, and Data using the same
  existing rows/actions; add semantic SF Symbol roles.
- [x] Apply grouped background/separator/tint conventions without nested cards.
- [x] Run UI/localization/browser contracts GREEN and inspect CJK string lengths.

## Task 5: Integrate, screenshot, package, and deliver

**Files:** finish Xcode language/AppIcon integration; extend simulator workflow
for start and loaded-page screenshots; replace `dist/` and Windows desktop
delivery; update Aegis evidence with actual run IDs/hashes.

**Why:** Portable source checks cannot prove compiled assets, Chinese UI,
on-screen proportions, engine visibility, signing, or final package contents.

**Verification:** all portable suites, successful simulator and package runs,
manual screenshot review, package validator, SHA-256, ZIP integrity, localized
resource/AppIcon inspection, Aegis check, temporary-ref cleanup, unchanged HEAD.

- [x] Set `zh-Hans` development/known regions and AppIcon build setting; run all
  portable suites and `--require-cutover`.
- [x] Extend simulator smoke to capture the initial Chinese start page before
  relaunching with the deterministic HTTPS URL; keep page-pixel/crash/process
  evidence intact.
- [x] Push only a temporary commit-tree ref, run simulator, review both images,
  and repair canonical UI owners if visual defects remain.
- [x] Run final package workflow, download and validate IPA/TIPA, localization,
  AppIcon, signatures/content, SHA, and ZIP structure.
- [x] Copy to `C:\Users\niting\Desktop\Vulpra`, delete every temporary UI CI
  ref, bundle/check Aegis evidence, and confirm HEAD remains
  `9fb58d6bb8c1e50d09923a1c76bdac52eddfdf26`.

## Risks and self-review

- Simulator automation can prove the start and loaded browser states directly;
  dark mode, every modal, iPad, and physical-device visuals remain explicit
  uncovered scope unless additional direct evidence is obtained.
- Removing the start search does not remove search capability; the persistent
  browser omnibox remains accessible on the start page.
- No placeholders, alternate visual owner, data mutation, or runtime fallback
  is present in this plan.
- Every design acceptance item maps to Tasks 1-5 and final package evidence.
