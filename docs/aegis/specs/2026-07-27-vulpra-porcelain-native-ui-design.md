# Vulpra Porcelain Native UI Design

Date: `2026-07-27`
Status: `direction-a-approved-pending-written-review`
ArchitectureReviewRequired: `no`
TDD Route: `light`

## 1. Goal

Replace the visibly prototype-like Vulpra client presentation with the
user-selected Porcelain Native direction while preserving the independent
engine, UIKit navigation, feature owners, persistence, and product behavior.

This is an implementation-drift repair against
`2026-07-26-vulpra-client-experience-design.md`, not a new runtime or product
architecture. The current oversized floating dock, duplicate start-page search
field, excessive corner radii, generic blue accent, and flat information
hierarchy are the repair targets.

## 2. Visual system

- Primary canvas: system white with porcelain `#F7F8F6` for branded/empty
  surfaces.
- Primary ink: graphite `#24272B`.
- Secondary ink: system secondary label; no low-contrast custom gray text.
- Action/selection accent: restrained vermilion `#E85D45`.
- Private mode: teal `#2D8C82` plus an explicit privacy label/icon.
- Borders: cool gray `#E4E7EA` in light mode and system separator in dark mode.
- Destructive/warning states continue to use system semantic colors.
- Exclude blue-dominated tinting, gradients, glow, decorative blobs, beige
  fields, and stacked card treatments.

Typography uses Dynamic Type. Brand text is at most 26pt semibold; screen
titles use native navigation scale; compact labels use system body/caption
styles with zero letter spacing.

## 3. Browser chrome

The selected page remains visually dominant.

- One bottom dock, horizontally inset 8pt and bottom-inset 4pt from safe area.
- Dock radius: 12pt continuous; one 1px separator and a restrained shadow at
  no more than 0.07 opacity and 10pt blur.
- Unfocused address row: 42pt. Focused row: 48pt.
- Navigation controls: stable 44x44pt targets with SF Symbols, no text labels.
- Total dock content height, excluding the home-indicator safe area: no more
  than 102pt in normal portrait state.
- The address surface uses a subtle neutral fill and an 8pt radius; it does not
  look like a nested floating card.
- HTTPS security, hostname/URL, reload/stop, and tab count retain their current
  truthful state owners.
- During address editing, secondary controls fade/compact and the field gains
  width without guessing keyboard duration.
- Suggestions attach directly above the dock, use 8pt radius, a hairline
  border, 52pt rows, and no heavy shadow.

## 4. Start page

- Remove the second search field. The persistent browser omnibox is the only
  search/address entry.
- Show a compact 56pt White Porcelain Flame V brand mark with a restrained
  `Vulpra` label near the upper third, not a hero-sized title.
- Quick commands use a stable horizontal strip of icon-plus-Chinese-label
  controls with whole-word wrapping and 44pt minimum targets.
- Favorites and recent visits use an unframed adaptive two-column phone / three-
  column regular-width layout. Each item shows a favicon/symbol, title, and host
  with an 8pt maximum item radius.
- Empty sections are omitted; there are no decorative section cards or
  explanatory tutorial paragraphs.
- The start page scrolls and preserves space above the bottom dock.

## 5. Tabs and private mode

- Use a quiet grouped background and one native segmented control for normal
  and private collections.
- Two columns on compact phones, three on regular width, with stable aspect
  ratio and 12pt grid gaps.
- Tab cards use an 8pt radius, 1px border, page thumbnail, compact footer, title,
  hostname, and a familiar close icon.
- Selected cards use a 2px vermilion border; private selected cards use teal.
- Close controls remain at least 44pt tappable without visually dominating the
  card.
- Toolbar commands remain visible and use localized concise labels; no hidden
  gesture is required.

## 6. Library, downloads, privacy, and settings

- Native grouped lists remain the interaction owner, with consistent row
  heights, separators, SF Symbol role icons, and compact secondary values.
- Settings are grouped into General, Appearance, Privacy, and Data sections;
  existing behavior remains unchanged and no unsupported setting is added.
- Bookmarks/history retain search and deletion behavior, with clear empty-state
  symbols and concise Chinese labels.
- Downloads show localized status/bytes and a compact empty state.
- Site permissions and clear-data screens use the same grouped visual language;
  destructive rows remain system red.
- Sheet/navigation chrome is neutral and uses vermilion only for primary
  selection/action emphasis.

## 7. Motion and accessibility

- Button press: 80ms down / 120ms release via transform only.
- Omnibox focus: 220ms interruptible, keyboard-coordinated.
- Progress completion: 160ms opacity transition with stable geometry.
- Tab insert/remove: native collection updates around 220ms.
- Reduce Motion replaces spatial motion with at most 120ms fades.
- All icon-only controls keep localized accessibility labels and 44pt targets.
- Dynamic Type, CJK labels, dark mode, increased contrast, and reduced
  transparency must not clip or overlap.

## 8. File ownership

- `VulpraAppearance`: semantic palette, radii, separators, and native appearance
  defaults only.
- `BrowserChromeView`: dock/address/control layout and focus presentation.
- `StartPageViewController`: start content composition; no second omnibox.
- `TabCardCell` and `TabOverviewViewController`: tab-grid presentation only.
- Existing feature controllers own their list content and actions.
- One reusable compact empty-state view may be added; no generic design-system
  framework or third-party UI dependency is introduced.
- The AppIcon generator remains the brand source; a separate compact brand-mark
  imageset may be derived from the same geometry for the start page.

## 9. Compatibility and non-goals

- Preserve `com.vulpra.browser`, iOS 15, iPhone/iPad, OpenIn, arm64, the current
  Xcode targets, and package outputs.
- Preserve `TabManager`, `BrowserTab`, Codable stores, user data, navigation
  actions, privacy rules, and the sole VulpraEngineKit adapter.
- No feature invention, persistence migration, data deletion, alternate engine,
  compatibility fallback, SwiftUI rewrite, or copied Reynard client UI.
- No claim of complete physical-device visual/performance validation without
  direct evidence.

## 10. Acceptance

1. Portable UI contracts reject duplicate start-page search, dock radius/height
   regressions, oversized tab-card radii, blue primary accent, and missing
   localized accessibility labels.
2. iPhone simulator screenshots cover the blank/start page and a loaded HTTPS
   page in Chinese-first configuration.
3. Screenshots show no overlap, clipping, malformed CJK wrapping, blank engine
   content, or page chrome consuming disproportionate height.
4. AppIcon and compact brand mark render from the same porcelain/graphite/
   vermilion geometry.
5. Light/dark source contracts use semantic colors; runtime screenshot evidence
   covers light mode, with dark/physical-device coverage kept explicit if not
   available.
6. Existing browser, runtime, cutover, package, localization, icon, and ZIP/
   signature tests remain green.
7. Newly validated IPA/TIPA replace `dist/` and the visible Windows desktop
   delivery only after simulator/package evidence succeeds.

## 11. Complexity budget

- `BrowserChromeView`: target below 230 lines.
- `StartPageViewController`: target below 230 lines.
- `TabOverviewViewController` and `TabCardCell`: each below 180 lines.
- Shared empty-state/brand presentation helpers: each below 100 lines.
- No App controller may cross the existing 350-line owner gate.
- Net entropy is stable only if the duplicate start search path is deleted and
  no parallel UI framework, fallback layout, or duplicate state owner appears.

## 12. Working artifacts

### TaskIntentDraft

- Requested outcome: make the whole client interface visually polished, simple,
  and elegant, using selected direction A.
- Goal: implement Porcelain Native across chrome, start page, tabs, lists, and
  settings, then deliver new Chinese-first icon-bearing packages.
- Success evidence: reviewed simulator screenshots, passing UI/localization/
  runtime/package gates, and validated desktop IPA/TIPA.
- Stop: done only after the refreshed packages are delivered; needs-verification
  if macOS simulator/package evidence cannot be refreshed.
- Non-goals: engine/persistence redesign, copied old UI, fake features, user-data
  deletion, or public-release claims.

### BaselineUsageDraft

- Required refs: approved client experience design, independent-engine package
  baseline, Chinese-first/icon brief, and this UI design.
- Acknowledged refs: all.
- Missing refs: none.
- Decision: `continue` after written review.

### ImpactStatementDraft

- Affected layers: UIKit presentation, localized resource usage, brand mark
  assets, UI structural tests, simulator screenshots, and final packages.
- Canonical owners: existing view/controllers plus bounded appearance/empty-state
  helpers.
- Invariants: one tab owner, one engine adapter, one omnibox, one icon/brand
  geometry, no user-data mutation.
- Compatibility: product identity, target graph, engine, data, and functional
  actions remain unchanged.

## 13. Self-review

- Placeholder scan: no unresolved design choice.
- Scope: all principal existing surfaces are covered without inventing features.
- Consistency: porcelain UI uses the same palette/mark as the approved icon.
- Layout: explicit stable radii, heights, grids, and touch targets replace vague
  aesthetic language.
- Architecture: redesign stays within existing UIKit view owners and retires the
  duplicate search path instead of adding a second UI layer.

