# Vulpra Chinese-First Localization and Brand Icon Brief

Date: `2026-07-27`
Status: `approved-direction-pending-written-review`
ArchitectureReviewRequired: `no`
TDD Route: `light`

## 1. Goal

Make Simplified Chinese the primary Vulpra client language and give the app a
simple, elegant, predominantly white icon without changing runtime, browser
state, bundle identity, or distribution ownership.

Success requires a Chinese-first application on first launch, an English
fallback for non-Chinese systems, complete localization of user-visible App and
OpenIn text, and a production AppIcon asset embedded in the rebuilt IPA/TIPA.

## 2. Authority and baseline

- User request on `2026-07-27`: Chinese-first client and a simple, elegant icon.
- User-selected visual direction: predominantly white.
- User approval on `2026-07-27`: the White Porcelain Flame V direction.
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`
- `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`

The existing client experience remains authoritative for layout, interaction,
UIKit ownership, and accessibility. The independent-engine baseline remains
authoritative for runtime, package, and data-preservation boundaries.

## 3. Localization design

### 3.1 Language behavior

- Set `zh-Hans` as the Xcode development language and default localization.
- Provide `zh-Hans.lproj/Localizable.strings` for all client-visible text.
- Retain `en.lproj/Localizable.strings` as the fallback localization.
- Add localized `InfoPlist.strings` for permission descriptions and display
  metadata where system UI presents those values.
- Localize the OpenIn extension through the same two-language boundary.
- Brand name `Vulpra`, URLs, technical identifiers, and user-provided content
  remain untranslated.

Chinese-first does not override a user's explicit iOS per-app language choice.
Chinese is the development/default language; English remains available when
selected by the system or user.

### 3.2 String ownership

- Add one small Vulpra-owned localization helper for typed lookup and formatted
  strings.
- Replace user-visible hard-coded English in App and OpenIn Swift sources.
- Do not localize logger messages, persistence keys, notification names, engine
  message names, URL schemes, reuse identifiers, or SF Symbol names.
- Accessibility labels, action titles, alerts, empty states, settings rows,
  permission prompts, tab counts, and plural-sensitive formatted values are in
  scope.
- User data and Codable records store semantic values, not localized display
  strings, so changing language never migrates or deletes data.

## 4. Icon design

### 4.1 White Porcelain Flame V

- Canvas: `1024 x 1024`, opaque RGB PNG, no pre-rounded corners and no alpha.
- Background: porcelain white `#F7F8F6`, visually dominant.
- Edge separation: restrained cool-gray inset boundary near `#E4E7EA`, only
  enough to keep the icon visible against white wallpaper.
- Mark: a centered deep-graphite `V` near `#24272B`; its upper termination
  resolves into one abstract flame fold.
- Accent: one small vermilion plane near `#E85D45`, subordinate to white and
  graphite.
- Composition: generous clear space, stable silhouette, balanced optical
  center, and legibility at `20 x 20` points.
- Exclude text, letters other than the abstract V geometry, gradients, glow,
  photographic texture, detailed facial features, a globe, and generic browser
  compass imagery.

The master may be generated as a raster concept, but the selected output must
be inspected and normalized before producing the deterministic iOS asset set.

### 4.2 Asset integration

- Add a Vulpra-owned asset catalog containing `AppIcon.appiconset`.
- Produce every icon rendition required by the project's iOS 15 iPhone/iPad
  target plus the 1024-pixel marketing rendition.
- Configure `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in the canonical App
  build configuration.
- Do not add an alternate-icon feature or a second icon owner.

## 5. Compatibility and non-goals

- Preserve `com.vulpra.browser`, iOS 15.0, arm64, iPhone/iPad, OpenIn, and the
  current app/version identity.
- Preserve `TabManager`, `BrowserTab`, all Codable stores, and all existing user
  data.
- Preserve the sole `VulpraEngineKit` adapter and the precompiled Gecko runtime.
- Do not add localization frameworks, remote font/image dependencies, runtime
  language overrides, analytics, migrations, fallbacks, or duplicate resource
  owners.
- This task does not redesign browser layout, implement missing product
  features, or claim physical-device validation.

## 6. Verification and acceptance

1. Source-contract tests fail on newly introduced user-visible hard-coded
   English and require both `zh-Hans` and `en` resource sets.
2. All `.strings` and plist files parse; localization keys are unique and the
   Chinese/English key sets match.
3. The asset catalog manifest parses, names every required rendition, and each
   PNG has the declared dimensions, opaque pixels, and valid RGB/RGBA encoding.
4. Xcode builds with `zh-Hans` as its development region and embeds the AppIcon
   plus both localizations.
5. Simulator evidence shows Chinese UI and the installed app icon.
6. Portable suites, cutover readiness, package validation, SHA-256 checks, and
   ZIP integrity remain green.
7. New IPA/TIPA files replace the delivery copies in `dist/` and
   `C:\Users\niting\Desktop\Vulpra` only after validation.

## 7. Complexity budget

- Localization helper target: at most 80 maintained lines.
- Resource files remain flat by language and domain; no generated wrapper
  dependency is added.
- Existing controllers gain lookup calls, not localization policy branches.
- One asset catalog and one AppIcon owner are added.
- Expected result: `within-budget`, with no fallback or adapter entropy.

## 8. Design working artifacts

### TaskIntentDraft

- Requested outcome: Chinese-first Vulpra client and a simple, elegant,
  predominantly white icon, followed by rebuilt validated packages.
- Goal: localize all user-facing product text through standard iOS resources
  and ship the White Porcelain Flame V icon.
- Success evidence: Chinese simulator UI, visible installed icon, passing
  localization/asset tests, successful archive/package workflow, and locally
  verified IPA/TIPA.
- Stop condition: done after new verified packages are copied to the visible
  Windows desktop; needs-verification if Mac/simulator/package evidence cannot
  be refreshed.
- Non-goals: runtime changes, data migration/deletion, bundle identity changes,
  feature redesign, alternate icons, or App Store eligibility claims.

### BaselineUsageDraft

- Required baseline refs: client experience design and independent-engine
  package baseline listed in section 2.
- Acknowledged before design: both.
- Cited in design: both.
- Missing refs: none.
- Decision: `continue` after written-spec approval.

### ImpactStatementDraft

- Affected layers: App/OpenIn display strings, Info.plist localization, Xcode
  development region/resources, asset catalog, portable tests, simulator and
  package workflows.
- Canonical owners: standard `.lproj` resources, one localization helper, and
  one `AppIcon.appiconset`.
- Compatibility boundary: engine, persistence, tabs, bundle identity, platform
  target, and distribution products remain unchanged.
- Risk controls: matched localization keys, deterministic icon renditions,
  package inspection, and no runtime language override.

## 9. Self-review

- Placeholder scan: no TBD, TODO, or unresolved design choice.
- Consistency: Chinese-first behavior retains an explicit English fallback and
  respects iOS language selection.
- Scope: localization and one icon owner only.
- Ambiguity: palette, icon geometry, file ownership, package evidence, and
  completion boundary are explicit.
- Architecture: no new runtime owner, compatibility adapter, fallback, schema,
  or persistence change.

