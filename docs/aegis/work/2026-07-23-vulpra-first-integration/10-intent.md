# Task Intent — Vulpra-First Integration

Date: `2026-07-23`
ArchitectureReviewRequired: `yes`

## Requested outcome

Vulpra is the independent product. Borrow only the usable GeckoView, Helper,
JIT, and verified startup/build contracts; do not create the product by
deleting pieces from Reynard.

## Scope

- select Vulpra-owned product files from commit `7955722`;
- integrate necessary substrate deltas with explicit provenance;
- repair the fresh Xcode graph from evidence-only contract comparison;
- verify and build IPA/TIPA through GitHub Actions;
- deliver the tested package to the mounted Windows desktop.

## Non-goals

- no Reynard Client, Resources, stores, Xcode project, or old-data migration;
- no Gecko rebuild unless the exact runtime identity requires it;
- no App Store/public-distribution claim;
- no physical-device success claim without user evidence.

## BaselineReadSetHint

- `docs/aegis/baseline/2026-07-21-initial-baseline.md`
- `docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md`
- `docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md`
- `docs/provenance/substrate-boundary.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`

## BaselineUsageDraft

- Required refs: all five above.
- Acknowledged before plan: all five.
- Cited in plan: all five.
- Missing refs: fresh Mac package evidence and device launch evidence.
- Decision: `continue`.

## ImpactStatementDraft

This changes product ownership, Xcode/release surfaces, and maintained
substrate deltas. Product code remains small UIKit owners with zero third-party
UI dependencies. Generated Gecko and package payloads remain outside Git and
are measured separately.

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Delivered context refs:
- none
- Acknowledged before plan:
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Cited in plan:
- docs/aegis/plans/2026-07-23-vulpra-first-proven-startup-integration.md
- docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md
- Missing refs:
- fresh GitHub package evidence
- physical-device launch evidence
- Advisory decision: continue

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Delivered context refs:
- none
- Acknowledged before plan:
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Cited in plan:
- docs/aegis/plans/2026-07-23-vulpra-first-proven-startup-integration.md
- docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-package-verification-29961256526.json
- Missing refs:
- physical-device launch and performance evidence
- Advisory decision: needs-verification
