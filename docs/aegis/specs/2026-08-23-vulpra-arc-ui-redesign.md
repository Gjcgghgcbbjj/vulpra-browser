# Vulpra Arc/Dia UI Redesign Guide

Date: `2026-08-23`  
Status: `user-approved direction; release-quality implementation gate`  
Supersedes: the v21/v22 “Chrome-style” visual treatment where this document conflicts.  
Engine boundary: unchanged. Gecko/Firefox identity, Google login behavior, autofill bridge,
scroll telemetry, tab persistence, and JIT startup paths must not regress.

## 1. Goal

Make Vulpra feel like a calm spatial browser rather than a Chrome/Safari clone.
The first release candidate must combine **personality, depth, restraint, and
production quality**: fewer persistent controls, clearer hierarchy, elegant
motion, and no unfinished-looking system action sheet as the primary product UI.

Success means a user can browse with one command pill, understand every path
without instruction, and perceive the shell as designed—not assembled.

## 2. Product principles

1. **Page owns the screen.** Web content is the primary surface. The browser is
   a quiet instrument around it.
2. **One obvious command.** The bottom capsule is the persistent command point.
   Complex actions appear only on request.
3. **Spatial, not decorative.** Depth comes from material, scale, spacing, and
   motion. No loud wallpaper, glow, or borrowed brand imagery.
4. **Minimal does not mean hidden.** Every legacy capability remains reachable
   within two deliberate taps; destructive actions remain explicit.
5. **Native quality bar.** Dynamic Type, Reduce Motion, contrast, hit targets,
   light/dark mode, iPad adaptation, and keyboard behavior are release gates.
6. **No engine risk for UI debt.** UI changes stay above EngineKit/GeckoView.

## 3. Canonical surfaces

### 3.1 Start page

- Large time-aware greeting plus compact date context.
- Small uppercase `VULPRA` wordmark; no large borrowed logo.
- One elevated search/address field with continuous corners and quiet border.
- Pinned links use roomy favicon cards, not tiny circular tiles.
- Up to three recent visits may appear below pins when available.
- A compact overflow menu exposes Private Tab, Bookmarks, History, Downloads,
  and Settings.
- Empty state remains useful but never dominates the canvas.
- Content scrolls; the background uses one extremely subtle tonal transition.

### 3.2 Browser command capsule

The old address-plus-five-button dock is retired.

Persistent capsule:

```text
[ ⋯ ]   example.com        ▢ 3
```

- Leading `⋯`: opens the command panel; it never becomes a stop button.
- Center: secure host while browsing; complete URL while editing.
- Trailing: tabs entry with count badge when more than one tab exists.
- Height is at least 58 pt; radius follows the capsule; material is translucent.
- Loading progress appears as a thin accent line inside the capsule.
- Scroll down hides the whole capsule and expands content; scroll up restores it.
- Back/forward remain available through edge gestures and command panel.
- Adjacent-tab swipe behavior remains available on the capsule.

### 3.3 Command panel

`UIAlertViewController` is not acceptable as the primary page-tools owner.

- Use an inset-grouped Vulpra command sheet with medium/large detents.
- Sections: Navigation, Page, Media, Browser.
- Rows have SF Symbols, concise labels, and no duplicated unavailable actions.
- Reload/Stop reflects current state; back/forward appear only when enabled.
- Zoom uses a selected-state command list, not another action sheet.
- Find still uses a native text alert because it requires keyboard input.

### 3.4 Tab overview

- Grouped neutral canvas, not a plain white list.
- Cards have separated thumbnail and metadata zones, continuous corners,
  restrained borders, and clear selection state.
- Normal/Private switch remains explicit.
- Close, undo, new tab, close others, reorder, and accessibility labels remain.
- Empty state offers New Tab instead of showing blank space.

## 4. Visual system

### 4.1 Color

- Neutral system backgrounds own most of the screen.
- Ember is the single active signal: progress, selection, badge, key accent.
- Teal identifies private mode; red remains destructive/error-only.
- Accent must not flood cards, backgrounds, or headings.
- All semantic combinations must pass WCAG AA in light and dark modes.

### 4.2 Shape, elevation, and typography

- Repeated cards: 16–20 pt continuous corners.
- Command capsule: capsule geometry / approximately 29 pt continuous corner.
- One restrained shadow per floating layer; no stacked card-in-card shadows.
- Hairlines provide separation where blur alone is insufficient.
- Display text scales with `.largeTitle`; metadata with semantic text styles.
- Fixed sizes are allowed only for icons/badges; body text supports Dynamic Type.

## 5. Interaction contract

- Tap center capsule: edit URL/search.
- Leading capsule control: command panel.
- Trailing capsule control: tab overview.
- Scroll down/up: hide/show capsule without overlaying page controls.
- Left/right edge: back/forward.
- Capsule horizontal swipe: adjacent tab.
- Start-page search submits through the same resolver as omnibox.
- Keyboard moves the capsule with `keyboardLayoutGuide`; no guessed timing.
- Reduce Motion replaces spring/scale effects with immediate state changes.

## 6. Architecture boundaries

| Concern | Owner |
| --- | --- |
| Root composition/engine attachment | `BrowserViewController` |
| Persistent capsule rendering | `BrowserChromeView` |
| Start composition/link cards | `StartPageViewController`, `StartPageLinkCard` |
| Command presentation model | `VulpraCommandSheet` |
| Action routing | `PageToolsController` + root delegate |
| Tab truth | `TabManager` |
| Card rendering | `TabCardCell` |

`BrowserViewController` must remain under the project’s 350-line ownership
budget. Delegate routing belongs in focused extensions; do not grow the root.

## 7. Release gates

No release claim is valid until all of the following pass:

1. Portable browser/runtime gates relevant to this checkout.
2. Browser client source contract, including 350-line owner budget.
3. Swift syntax/type review of changed files.
4. GitHub Xcode build/package workflow green.
5. Device smoke evidence: cold launch, start page, Google login unchanged,
   open/navigate/multiple tabs/private tab, scroll hide/show, editing above
   keyboard, command panel actions, tab overview undo/new/close, dark/light,
   Dynamic Type, Reduce Motion, iPad rotation/split view.
6. No debug logging in Release and no accidental engine/API behavior change.

Local tests cannot prove physical-device or GitHub build acceptance; those gates
must remain explicitly reported rather than inferred.

## 8. Non-goals

- Do not introduce SwiftUI/third-party UI frameworks.
- Do not implement Spaces, vertical tabs, profiles, sync, AI, or themes.
- Do not alter Gecko identity, login fingerprint, storage formats, or JIT flow.
- Do not replace every secondary settings/library screen in this slice if their
  existing native hierarchy remains usable; unify their accent/material only.
