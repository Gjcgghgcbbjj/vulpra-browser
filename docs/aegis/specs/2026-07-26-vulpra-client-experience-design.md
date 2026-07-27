# Vulpra Client Experience Design

Date: `2026-07-26`
Status: `approved-by-user`
ArchitectureReviewRequired: `yes`

## 1. Product direction

Vulpra is a fast, native Gecko browser for iPhone and iPad. Its client should
feel precise, calm, and responsive rather than decorative or derivative. The
browser gives the page visual priority, keeps frequent controls within easy
reach, and exposes advanced features through predictable native surfaces.

This document is the product, interface, interaction, and motion companion to
`2026-07-26-vulpra-independent-engine-product-design.md`. The engine design owns
runtime and source boundaries. This design owns what the user sees and how the
browser behaves.

## 2. Experience principles

1. **Page first** - browser chrome consumes only the space required for the
   current task.
2. **One obvious path** - one omnibox, one tab owner, one library, and one
   settings hierarchy.
3. **Fast before flashy** - motion communicates continuity and never delays an
   action or hides a slow operation.
4. **Native but distinct** - use UIKit, SF Symbols, Dynamic Type, and platform
   conventions with a Vulpra-owned palette, spacing, icon, and composition.
5. **No fake capability** - unsupported engine or service features are absent,
   not represented by inert toggles.
6. **Private means private** - private behavior is enforced by data ownership,
   not only by a different color scheme.
7. **Adaptive, not duplicated** - phone, landscape, iPad, and split view share
   behavior owners while adapting navigation density.

## 3. Information architecture

### 3.1 Primary destinations

- Browser
- Tab overview
- Start page
- Library
  - Bookmarks
  - History
  - Downloads
  - Recently closed
- Page tools
- Site information and permissions
- Extensions
- Settings

### 3.2 Navigation rules

- Browser content remains the root; feature destinations are sheets, navigation
  stacks, or iPad sidebar details rather than replacement app roots.
- Opening a library item dismisses or collapses the library and loads it in the
  selected tab unless the user explicitly requests a new tab.
- Settings and management surfaces never own or duplicate live tab state.
- Normal/private mode changes occur in the tab overview, not through a hidden
  settings toggle.
- Destructive actions use confirmation only when they are difficult to reverse
  or affect multiple records.

## 4. Adaptive layout

### 4.1 iPhone portrait

The selected page fills the viewport. A bottom browser dock contains the
omnibox and one row of navigation controls. It respects the home indicator and
keyboard without covering page controls.

```text
+----------------------------------+
| page / start-page content        |
|                                  |
|                                  |
|                                  |
+----------------------------------+
| [security] address or search     |
|  back  forward  reload  share tabs|
+----------------------------------+
```

- The dock has stable height in normal state.
- Omnibox focus expands the field and temporarily reduces secondary controls.
- Scrolling may compact the dock but never removes back, tab, or address access.
- The keyboard transition moves the dock with the system keyboard coordinator;
  it does not run an independent guessed-duration animation.

### 4.2 iPhone landscape

- The dock becomes one compact horizontal bar where width permits.
- The address field receives the flexible track; icon controls keep fixed tap
  targets.
- Page height is prioritized and text labels are removed from tool buttons.
- Safe-area and sensor-housing insets are handled explicitly.

### 4.3 iPad full width

- A compact top toolbar contains navigation, omnibox, page tools, and tab entry.
- A collapsible leading sidebar may show tabs or library navigation, but only one
  sidebar mode is visible at a time.
- The sidebar uses a restrained full-height band, not a floating card.
- Tab overview can use a wider grid while retaining the same `TabManager` data.

### 4.4 iPad split view and narrow widths

- Below the wide-layout threshold, iPad uses the phone composition with iPad
  spacing and pointer behavior.
- No control depends solely on hover.
- Tooltips identify unfamiliar icon-only controls when a pointer is available.
- Rotation and resizing preserve selected tab, omnibox edit state where valid,
  and modal navigation context.

## 5. Visual language

### 5.1 Palette

Vulpra uses neutral system surfaces plus two restrained brand roles:

- **Ember** - primary command, active selection, progress, and brand mark.
- **Teal** - private-mode identity and positive privacy/security status.
- **System red** - destructive actions and security failures only.
- **System yellow** - warnings and degraded execution state.
- **System backgrounds and labels** - primary content hierarchy.

The interface must not become a field of tinted orange, teal, purple, beige, or
dark slate. Brand colors appear as signals against neutral surfaces. Gradients,
decorative glow, orbs, and bokeh are excluded.

All semantic colors meet WCAG contrast expectations in light/dark appearance
and increased-contrast mode. Security state never relies on color alone.

### 5.2 Typography

- Use Dynamic Type text styles, not viewport-scaled font sizes.
- Product mark: restrained display treatment on the start page only.
- Screen titles: native navigation-title scale.
- Section headings: compact and scan-oriented.
- URLs: monospaced digits are optional; hostname emphasis is achieved through
  semantic label weight, not mixed tiny text.
- Letter spacing remains zero.
- Labels use whole-word wrapping; narrow fragments such as `Book\nmark\ns` are
  a release-blocking layout defect.

### 5.3 Shape and depth

- Repeated content cards use a maximum 8-point corner radius.
- The browser dock may use a 12-point continuous corner radius because it is one
  persistent tool surface, not a repeated card.
- Sheets and menus use native presentation geometry.
- Elevation is communicated with subtle material separation and one restrained
  shadow; stacked card-inside-card layouts are prohibited.
- Borders are preferred over heavy shadows for selected tab and library state.

### 5.4 Icons and assets

- Use SF Symbols for standard commands such as back, reload, share, close,
  download, settings, and tab management.
- Icon buttons keep at least 44x44-point hit targets.
- The Vulpra app icon and compact fox/flame mark are original raster/vector
  assets owned by Vulpra.
- Site favicons and page thumbnails display actual page identity when available;
  generic imagery is a fallback, not the primary presentation.
- Empty states use a compact Vulpra-owned illustration or relevant symbol and a
  direct action; no stock imagery is used.

## 6. Browser chrome

### 6.1 Omnibox

The omnibox is the only address/search editor in the product.

- Start page content does not render a second search field.
- Unfocused state shows the hostname with HTTPS/security state.
- Focused state shows the complete editable URL or query.
- Clear, paste, copy, scan, and submit actions follow native editing menus and
  keyboard behavior.
- Direct URLs, hosts, search queries, and supported internal pages resolve
  deterministically.
- HTTPS upgrade failure produces a clear recovery choice rather than silently
  leaving the user on a blank page.

### 6.2 Suggestions

Suggestion groups are visually labeled and bounded:

- open tabs;
- bookmarks;
- recent history;
- search completion, only when a real provider is configured and enabled.

Results update without changing the dock's geometry. Highlighted text remains
readable with Dynamic Type. Requests are debounced and cancellable. Private tabs
do not query or contribute normal history suggestions.

The existing nonfunctional remote-suggestion toggle is removed until the
provider contract exists.

### 6.3 Load and security state

- Reload changes to stop only while the selected tab is loading.
- Progress uses a thin stable track and fades only after completion.
- Security state distinguishes secure, insecure, certificate error, local page,
  and unknown states with icon plus accessible text.
- Site information opens from the security control and owns per-origin
  permissions and data actions.

## 7. Start page

The start page is content, not a second browser shell.

### 7.1 Composition

1. Compact Vulpra brand mark.
2. Favorites.
3. Recent visits.
4. Recently closed tabs.
5. Active/recent downloads when present.

Only enabled, nonempty sections appear. A section header provides its relevant
management command. The global omnibox remains the search entry.

### 7.2 Responsive sections

- Quick destinations use a two-column compact-phone or three-column regular-
  phone grid; iPad selects a stable column count from container width.
- Action labels remain one or two whole-word lines.
- Favorites show favicon, title, and hostname without decorative card nesting.
- Empty sections do not leave vertical gaps.
- Users can reorder and hide sections from start-page customization.

## 8. Tabs and private browsing

### 8.1 Tab overview

- A segmented control switches between Normal and Private collections.
- Cards show thumbnail, title, hostname, activity/crash state, and a familiar
  close icon.
- Card dimensions use explicit aspect ratio and container-relative columns.
- Selection, close, reorder, close others, and undo close are available without
  hidden gestures.
- Swipe-to-close is optional acceleration; the close button remains available.
- Recently closed normal tabs persist within a bounded retention policy.

### 8.2 Tab strip and sidebar

- Wide iPad layouts may show a vertical tab sidebar.
- The selected tab is obvious through shape, icon, and label treatment.
- Pinned or grouped tabs are deferred until their persistence and interaction
  model is explicitly designed.

### 8.3 Private mode

- Private mode uses neutral dark/light surfaces with a teal privacy mark and
  explicit `Private` title; it is not represented by purple tint alone.
- Private tabs do not write normal history, restoration, thumbnails, recently
  closed state, suggestions, permissions, or download metadata beyond the
  current private lifecycle unless the user exports a file.
- App-switcher snapshots are obscured while a private tab is selected.
- Closing the final private context destroys its in-memory product state and
  requests engine-private data cleanup.

## 9. Library

The library uses one navigation owner with dedicated sections.

### 9.1 Bookmarks

- Create, edit, move, search, and delete bookmarks.
- Create, rename, move, and delete folders.
- Choose destination folder when saving a page.
- Detect duplicate URL saves and offer edit/open rather than silently ignoring.
- Support stable manual order and an explicit title/date sort mode.

### 9.2 History

- Group visits by Today, Yesterday, previous seven days, and earlier dates.
- Search title and URL.
- Delete one visit, a selected range, a timeframe, or all history.
- Clearing product history also requests matching Gecko history removal and
  reports partial failure instead of claiming success unconditionally.

### 9.3 Downloads

- Separate Active and Completed sections.
- Show filename, received/expected bytes, progress, state, and destination.
- Show speed and remaining time only when measurements are stable.
- Pause/resume appears only when the engine supports it.
- Cancel, retry, reveal/share, and delete-file actions reflect actual state.
- Check available capacity before accepting large known-length downloads.
- Clean abandoned partial files without deleting completed user files.

### 9.4 Recently closed

- Persist a bounded normal-tab list with title, URL, and close time.
- Restore one item or clear the list.
- Never include private tabs.

## 10. Page tools and site controls

### 10.1 Page tools

The page-tools sheet contains commands relevant to the current page:

- share;
- add/edit bookmark;
- find in page;
- request desktop/mobile site;
- page zoom;
- copy URL;
- open QR scanner;
- enter PiP when supported;
- extension actions when available.

Unavailable commands are omitted instead of disabled without explanation.

### 10.2 Find in page

- Uses a compact keyboard-attached bar with previous, next, match count, and
  close controls.
- Empty query and no-match states do not shift the browser layout.
- Closing find restores page focus predictably.

### 10.3 Site information

- Shows origin, security state, connection/certificate summary when available,
  current permissions, tracking protection state, and site data actions.
- Per-site permission choices are Ask, Allow, and Block when the engine contract
  supports all three; otherwise only truthful supported choices appear.
- Clearing one site's data reports completion or failure for each data class.

## 11. Prompts, permissions, and files

- Web alerts, confirmations, text prompts, selects, authentication, color/date
  controls, and file selection use type-appropriate native UI.
- Only one prompt is presented per session at a time; later prompts queue or
  fail according to the engine contract.
- Permission prompts identify the requesting origin and capability.
- Camera/microphone requests reconcile browser decisions with iOS system
  authorization and explain a system-settings requirement when denied globally.
- File pickers support accepted types, multiple selection, cancellation, and
  scoped file access without retaining stale security-scoped URLs.
- Prompt cancellation on tab close or navigation completes the engine request
  exactly once.

## 12. Extensions and media

### 12.1 Extensions

- List user-installed extensions with icon, name, version, enabled state, and
  risk-relevant permissions.
- Installation presents requested permissions before commit.
- Details expose enable/disable, permissions, options, and uninstall.
- Popup UI uses a bounded dedicated presentation, not navigation of the selected
  page to the popup URL.
- Extension failures remain isolated from browser chrome and other tabs.

### 12.2 Media

- Background audio reflects real engine playback state.
- Lock-screen/control-center metadata is updated and cleared with session state.
- PiP is offered only when the current media session supplies a valid playback
  surface and controls.
- Media controls remain functional after tab switches, suspension, and
  interruption where the engine supports continuity.

## 13. Settings

Settings are grouped rather than presented as one flat table.

### General

- Search engine
- Real search-suggestion provider policy
- New-tab/start-page sections
- Default mobile/desktop mode
- Default zoom

### Appearance

- System/light/dark appearance
- Toolbar placement where supported
- Start-page customization
- Motion follows system Reduce Motion; no independent force-animation toggle

### Privacy and security

- Tracking protection with behaviorally distinct levels
- HTTPS-first behavior and recovery policy
- History retention
- Site permissions
- Clear browsing data with timeframe and data-class selection

### Downloads

- Destination behavior
- Completed-record retention
- Storage usage and cleanup

### Extensions

- Installed extension management
- Permission review

### About

- Version and build fingerprint
- Gecko artifact identity
- Licenses and notices
- Diagnostics export without private browsing data

Settings whose behavior is not implemented are not shown.

## 14. Failure and empty states

Every major surface defines loading, empty, error, and recovery states.

- Engine startup failure: retry, diagnostics, and clear statement that page
  content is unavailable; browser data remains accessible.
- Tab process crash: page-specific recovery without closing other tabs.
- Offline/navigation failure: preserve entered URL and expose retry.
- Certificate failure: dedicated warning with no misleading secure indicator.
- Download failure: retain record and allow retry/remove.
- Empty bookmarks/history/downloads/extensions: concise state plus one relevant
  action, without tutorial prose.
- Partial data-clear failure: report affected classes instead of showing a
  generic success alert.

## 15. Motion specification

All timings are defaults subject to direct device measurement.

| Interaction | Duration | Mechanism | 120 Hz requirement |
| --- | ---: | --- | --- |
| Button press/release | 80/120 ms | transform + opacity | no layout pass |
| Omnibox focus | 220 ms | interruptible property animator | keyboard-coordinated |
| Chrome compact/expand | 180 ms | transform + opacity | page viewport stable |
| Tab selection | 220 ms | interactive crossfade/transform | warm attach in one frame |
| Tab card insert/remove | 240 ms | collection update animator | stable grid tracks |
| Overview presentation | 280 ms | interruptible transform | no thumbnail capture inline |
| Progress completion | 160 ms | opacity | no geometry shift |
| Privacy cover | 120 ms | opacity | immediate on background |

- Custom display links use the screen's supported frame-rate range and do not
  force 60 Hz on ProMotion hardware.
- Animations modify transform, opacity, or precomputed geometry on the critical
  path.
- Rasterization is used only after measurement proves a benefit and is removed
  when content changes frequently.
- Reduce Motion replaces spatial movement with a fade of at most 120 ms or an
  immediate state change.

## 16. Performance integration

The client shares the engine specification's frame budgets:

- p95 at or below `8.33 ms` on 120 Hz devices;
- p95 at or below `16.67 ms` on 60 Hz devices;
- hitch rate below `1%` for each deterministic interaction workload;
- no interaction-critical main-thread task above `50 ms`.

Additional client rules:

- Use diffable or explicitly bounded collection updates; never reload a full
  tab/library collection for a single item change without evidence.
- Decode thumbnails and favicons off the main thread and downsample to display
  size before caching.
- Cache formatted display models where repeated formatting shows measurable
  cost; do not add speculative caches.
- Persist stores on serial background owners and flush lifecycle-critical state
  explicitly before suspension.
- Blur/material count is bounded; full-screen live blur during scrolling is
  prohibited.
- Measure SwiftUI/UIKit or custom rendering choices before introducing another
  UI framework. UIKit remains the default owner.

## 17. Accessibility and localization

- All controls have stable accessibility labels, values, traits, and order.
- Tab cards announce title, host, selected/private state, and close action.
- Dynamic Type is tested through accessibility sizes without clipped controls.
- Bold Text, Button Shapes, Increased Contrast, Reduce Transparency, and Reduce
  Motion are verified.
- VoiceOver can complete navigation, tab switching, private mode, bookmark save,
  download management, permission decisions, and data clearing.
- All user-facing text moves to localized resources before release evidence.
- Layout tests include intentionally long English and CJK labels.

## 18. Acceptance matrix

### Required viewports

- compact iPhone portrait at iOS 15 dimensions;
- current standard iPhone portrait;
- large ProMotion iPhone portrait;
- iPhone landscape;
- iPad full screen portrait and landscape;
- iPad 1/2 and 1/3 split-view widths.

### Visual acceptance

- No overlapping, clipped, truncated-command, or broken-word UI.
- No duplicate omnibox/search field.
- No nested cards or decorative page-section cards.
- Selected, private, loading, disabled, error, and focused states are visually
  distinct and accessible.
- Light/dark/increased-contrast screenshots are reviewed at each viewport.
- Actual page thumbnails, favicons, and brand assets render correctly.

### Functional acceptance

- Core navigation and tab workflows complete without hidden gestures.
- Bookmarks, history, downloads, recently closed, permissions, and settings have
  complete create/update/delete or truthful capability behavior.
- Private data does not leak into normal stores or snapshots.
- Every async prompt/download/permission action terminates exactly once.
- Engine failure remains recoverable without losing unrelated product data.

### Motion acceptance

- Animations are interruptible during rapid repeated actions.
- Rotation, backgrounding, keyboard changes, and tab close do not leave partial
  transforms or disabled controls.
- 60/120 Hz Instruments traces satisfy the performance contract.
- Reduce Motion behavior is verified independently.

## 19. Implementation ownership

Likely client owners are refined rather than replaced:

- `BrowserViewController` - composition and routing only.
- `BrowserChromeView` - dock/top-toolbar presentation.
- new bounded motion tokens/animators under `App/UI/Motion/`.
- `StartPageViewController` - section composition without an omnibox.
- `TabOverviewViewController` - normal/private overview and adaptive grid.
- feature-specific library, download, privacy, extension, and settings owners.
- stores remain separate from views and gain missing update/query operations.

No view controller may own persistence, engine lifecycle, and feature UI at the
same time. A controller approaching 350 lines requires an owner split before
more behavior is added.

## 20. Design review records

### Product risk lens

- Value: a distinctive daily-use client rather than a collection of feature
  entry points.
- Primary risk: broad visual changes hiding incomplete behavior.
- Control: each surface requires functional, state, accessibility, animation,
  and performance acceptance together.
- Non-goal: visual similarity to Safari, Firefox, or the retired Reynard client.

### Architecture integrity lens

- Invariant: UI state reflects one product owner and one engine capability.
- Canonical owners: App feature controllers/stores and VulpraEngineKit typed
  contracts.
- Duplicate paths retired: second start-page search field, flat duplicate
  navigation, inherited popup/page behavior, and inert settings.
- Falsifier: a visual surface that needs to parse raw Gecko messages or retain a
  second copy of tab state.
- Verdict: proceed with bounded client owners and shared adaptive composition.

### Plan-time complexity check

- Current pressure: the prototype is small but behavior and visual states are
  incomplete; adding all behavior to existing controllers would exceed owner
  budgets.
- Better boundary: split motion, presentation models, store operations, and
  engine capabilities by responsibility.
- Budget result: `at-risk`, governed by feature slices and the 350-line review
  threshold.
- Verification: screenshot matrix, unit/UI tests, simulator flows, and physical
  60/120 Hz evidence.
