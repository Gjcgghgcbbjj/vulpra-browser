# Vulpra Independent Engine Phase A - Intent

## TaskIntentDraft

- Requested outcome: Begin implementation of the approved binary-Gecko-only Vulpra architecture and complete the Phase A ownership, artifact, target, and retirement boundary.
- Goal: Establish machine-verified independent engine owners and a staged, no-fallback cutover path from inherited GeckoView/Helper/JIT source.
- Success evidence:
- Approved specs, executable Phase A plan, ownership and artifact contract tests, VulpraEngineKit and process target skeletons, and explicit old-owner retirement gates.
- Stop condition: Stop as done when Phase A gates pass; as needs-verification when Mac/Xcode evidence is unavailable; as blocked on an unverified Gecko ABI requirement; or as scope-exceeded if App behavior migration is required before the planned cutover.
- Non-goals:
- Implement Gecko ABI calls, migrate browser feature delegates, delete user data, claim device performance, or ship a release in Phase A.
- Scope: Phase A only: authority status, machine ownership map, binary artifact v4 verifier, independent target skeletons, staged Xcode graph, provenance gates, and retirement preparation.
- Change kinds:
- architecture
- Risk hints:
- High: replaces engine ownership and Xcode target boundaries; Linux cannot prove Xcode linkage or device behavior.

## BaselineReadSetHint

- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- docs/aegis/policies/efficiency-complexity-governance.md

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Acknowledged before plan:
- none
- Cited in plan:
- none
- Missing refs:
- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Advisory decision: needs-baseline-readback

## ImpactStatementDraft

- Compatibility boundary: Preserve bundle identity, iOS 15 minimum, App data formats, TabManager/BrowserTab ownership, OpenIn, and current runtime path until atomic product cutover.
- Affected layers:
- provenance, engine artifact, Xcode graph, engine contracts, process host, CI tests
- Owners:
- Engine/VulpraEngineKit, Engine/VulpraEngineProcess, Tools/Engine, Tests/IndependentEngine
- Invariants:
- App has one engine contract and no runtime fallback; precompiled Gecko is the only external compatibility carrier.
- Non-goals:
- Implement Gecko ABI calls, migrate browser feature delegates, delete user data, claim device performance, or ship a release in Phase A.

These records are Method Pack drafts / hints, not authoritative runtime decisions.

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Delivered context refs:
- none
- Acknowledged before plan:
- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Cited in plan:
- docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md
- docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- docs/aegis/adr/ADR-0003-modern-browser-ownership-and-github-distribution.md
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Missing refs:
- none
- Advisory decision: continue
