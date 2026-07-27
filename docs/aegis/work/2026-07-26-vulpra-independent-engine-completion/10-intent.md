# Vulpra Independent Engine Completion and IPA - Intent

## TaskIntentDraft

- Requested outcome: Complete the precompiled Gecko to VulpraEngineKit to Vulpra App architecture and deliver a verified IPA.
- Goal: Implement the independent engine adapter and process host, atomically migrate the App, retire inherited runtime owners, and package a verified installable IPA.
- Success evidence:
- A content-bound v4 artifact, Mac/Xcode compile and link, simulator navigation, independent child process, zero old runtime references/targets/workflows, and a validated IPA containing VulpraEngineKit but no GeckoView/old Helper/JIT payload.
- Stop condition: done only after the IPA exists and package/runtime gates pass; blocked only on an external dependency after repeated attempts; needs-verification when implementation exists without Mac/device evidence; scope-exceeded if completing would require Gecko source rebuild or retaining inherited integration source.
- Non-goals:
- Rebuild or patch Gecko source, retain idevice/JIT/GeckoView/old Helper, delete user data, or claim App Store eligibility.
- Scope: VulpraEngineKit runtime/session/event/feature implementation, independent process host, App protocol migration, atomic Xcode/workflow/package cutover, source retirement, Mac CI, simulator smoke, and IPA validation.
- Change kinds:
- architecture
- Risk hints:
- Private Gecko ABI, Objective-C/Swift bridging, iOS extension bootstrap, data preservation, atomic target removal, signing, and lack of local Xcode.

## BaselineReadSetHint

- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- Acknowledged before plan: all required refs on `2026-07-26`.
- Cited in plan: all required refs in
  `docs/aegis/plans/2026-07-26-vulpra-independent-engine-completion.md`.
- Missing refs: none; Mac/runtime/package evidence remains an execution gate.
- Advisory decision: continue

## ImpactStatementDraft

- Compatibility boundary: Preserve com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, TabManager/BrowserTab ownership, and existing browser behavior.
- Affected layers:
- engine artifact, ABI bridge, process host, App engine contracts, Xcode graph, runtime workflows, release packaging
- Owners:
- Engine/VulpraEngineKit; Engine/VulpraEngineProcess; App; Tools/Engine; release workflows
- Invariants:
- Exactly one active engine adapter; no runtime fallback; no inherited integration source; preserved bundle identity and user data.
- Non-goals:
- Rebuild or patch Gecko source, retain idevice/JIT/GeckoView/old Helper, delete user data, or claim App Store eligibility.

These records are Method Pack drafts / hints, not authoritative runtime decisions.
