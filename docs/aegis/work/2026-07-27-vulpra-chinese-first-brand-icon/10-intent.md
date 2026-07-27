# Vulpra Chinese-First Localization and Brand Icon - Intent

## TaskIntentDraft

- Requested outcome: Make the client Chinese-first, add the approved predominantly white Vulpra icon, rebuild and deliver validated IPA/TIPA packages.
- Goal: Ship Chinese-first UI and the White Porcelain Flame V icon without changing runtime, data, or bundle identity.
- Success evidence:
- Chinese simulator UI and installed icon, passing portable contracts, successful archive/package workflow, validated desktop IPA/TIPA.
- Stop condition: Done after validated packages are copied to the visible Windows desktop; needs-verification if remote Xcode evidence cannot be refreshed.
- Non-goals:
- Runtime redesign, schema migration, alternate icons, new feature work, or App Store eligibility.
- Scope: App and OpenIn localization resources, one localization helper, one deterministic AppIcon owner, Xcode resource integration, tests, simulator/package evidence, desktop delivery.
- Change kinds:
- interface
- Risk hints:
- Localization completeness, small-size icon clarity, Xcode asset compilation, package resource inclusion, and preserving the independent-engine/data boundary.

## BaselineReadSetHint

- docs/aegis/specs/2026-07-27-vulpra-chinese-first-brand-icon-brief.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-27-vulpra-chinese-first-brand-icon-brief.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Acknowledged before plan:
- none
- Cited in plan:
- none
- Missing refs:
- docs/aegis/specs/2026-07-27-vulpra-chinese-first-brand-icon-brief.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Advisory decision: needs-baseline-readback

## ImpactStatementDraft

- Compatibility boundary: Preserve com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, TabManager/BrowserTab, VulpraEngineKit, and branch HEAD.
- Affected layers:
- App/OpenIn UI resources and Xcode packaging
- Owners:
- App localization resources and AppIcon asset catalog
- Invariants:
- One localization owner, one icon owner, no runtime fallback, no user-data change.
- Non-goals:
- Runtime redesign, schema migration, alternate icons, new feature work, or App Store eligibility.

These records are Method Pack drafts / hints, not authoritative runtime decisions.
