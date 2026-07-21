# Vulpra Runtime Shell - Intent

## TaskIntentDraft

- Requested outcome: Create a fresh iOS 15+ UIKit Xcode graph and minimal Vulpra runtime shell around the verified GeckoView, Helper, and low-level JIT substrate, with reproducible Mac producer steps for the first unsigned IPA.
- Goal: Deliver Phase 1A source, project, ownership, and portable evidence without importing the Reynard client; leave Xcode compilation and IPA production as an explicit Phase 1B Mac gate.
- Success evidence:
- A committed Vulpra.xcodeproj with Vulpra/GeckoView/Vulpra Helper/OpenIn targets, new runtime-shell owners, Vulpra identities, iOS 15.0 settings, deterministic artifact/packaging contracts, passing portable graph tests, and no excluded client dependency.
- Stop condition: Done when Phase 1A source/project/contracts pass portable gates; needs-verification when only Mac/Xcode/IPA/device evidence remains; blocked if imported substrate requires excluded client code; scope-exceeded if tabs/data/final browser UI enter the slice.
- Non-goals:
- Final address bar, tab UI, persistence, settings, downloads, add-ons UI, release signing, performance acceptance, or public distribution.
- Scope: Design, plan, and implement vulpra-runtime-shell Phase 1A plus Mac producer/gate scripts only.
- Change kinds:
- architecture
- Risk hints:
- Linux cannot run xcodebuild; pbxproj target membership, generated Gecko headers, idevice archive linkage, private entitlements, and child-process JIT handshake require careful owner and evidence separation.

## BaselineReadSetHint

- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Acknowledged before plan:
- none
- Cited in plan:
- none
- Missing refs:
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md
- docs/provenance/substrate-boundary.md
- docs/aegis/policies/efficiency-complexity-governance.md
- Advisory decision: needs-baseline-readback

## ImpactStatementDraft

- Compatibility boundary: Deployment target 15.0; arm64 device-first; TrollStore/private entitlements are packaging-specific; no old identity or data compatibility; public portable checks must not claim Mac completion.
- Affected layers:
- XcodeGraph
- AppRuntime
- GeckoView
- Helper
- JIT
- Packaging
- Owners:
- Vulpra.xcodeproj owns target membership; Configuration owns build settings; App/Runtime owns launch and smoke-session orchestration; RuntimeJITCoordinator owns child JIT reporting; Tools/Runtime and Tools/Release own generated artifacts and packaging.
- Invariants:
- No inherited client/UI/store/resource/Xcode/data owner enters the repository; Gecko child processes are always released from the JIT readiness wait with an explicit success/failure report.
- Non-goals:
- Final address bar, tab UI, persistence, settings, downloads, add-ons UI, release signing, performance acceptance, or public distribution.

These records are Method Pack drafts / hints, not authoritative runtime decisions.
