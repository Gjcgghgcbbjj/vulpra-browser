# Vulpra R0 Trustworthy Engine Execution - Intent

## TaskIntentDraft

- Requested outcome: Implement every task in the approved R0 trustworthy Gecko v5 plan and report only after completion.
- Goal: Implement every task in the approved R0 trustworthy Gecko v5 plan and report only after completion.
- Success evidence:
- All 11 task implementations, portable suites, repeat native producer runs, 20-of-20 Simulator gate, green package run, retirement scans, ADR and baseline closure.
- Stop condition: Done only when all R0 evidence gates pass; otherwise blocked, needs-verification, or scope-exceeded is recorded without a false completion claim.
- Non-goals:
- R1-R3 feature implementation, physical-device runtime claims, App Store release, or persistent user-data deletion.
- Scope: Execute docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md Tasks 1-11.
- Change kinds:
- architecture
- Risk hints:
- Gecko source/patch provenance, ExtensionKit lifecycle ABI, GitHub macOS builds, and destructive internal retirement.

## BaselineReadSetHint

- docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md
- docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md
- docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Acknowledged before plan:
- none
- Cited in plan:
- none
- Missing refs:
- docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md
- docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Advisory decision: needs-baseline-readback

## ImpactStatementDraft

- Compatibility boundary: Preserve bundle ID, iOS 15 arm64, App/OpenIn/EngineKit/Engine Process products, Codable data, user retry, IPA/TIPA, and persistent user data.
- Affected layers:
- Engine producer, Gecko lifecycle ABI, EngineKit, App workaround retirement, CI, package distribution, ADR/baseline.
- Owners:
- GeckoChildProcessHost / VulpraEngineProcess / VulpraEngineKit / repository producer contracts
- Invariants:
- Every requested launch reaches exactly one ipcConnected or typed failed outcome; normal App builds consume one verified precompiled v5 runtime with no fallback.
- Non-goals:
- R1-R3 feature implementation, physical-device runtime claims, App Store release, or persistent user-data deletion.

These records are Method Pack drafts / hints, not authoritative runtime decisions.

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md
- docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Delivered context refs:
- none
- Acknowledged before plan:
- docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md
- docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Cited in plan:
- docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md
- docs/aegis/plans/2026-07-29-vulpra-r0-trustworthy-engine.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Missing refs:
- none
- Advisory decision: continue
