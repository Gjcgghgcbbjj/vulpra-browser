# Proof Bundle - 2026-07-22-vulpra-runtime-shell

## Method Pack Boundary

This proof bundle is an advisory Aegis Method Pack record. It does not determine evidence sufficiency, produce authoritative `GateDecision`, or grant `completion authority`.

## Task Intent

- Requested outcome: Create a fresh iOS 15+ UIKit Xcode graph and minimal Vulpra runtime shell around the verified GeckoView, Helper, and low-level JIT substrate, with reproducible Mac producer steps for the first unsigned IPA.
- Scope: Design, plan, and implement vulpra-runtime-shell Phase 1A plus Mac producer/gate scripts only.

## Impact

- Compatibility boundary: Deployment target 15.0; arm64 device-first; TrollStore/private entitlements are packaging-specific; no old identity or data compatibility; public portable checks must not claim Mac completion.
- Non-goals:
- Final address bar, tab UI, persistence, settings, downloads, add-ons UI, release signing, performance acceptance, or public distribution.

## Evidence Bundle Refs

- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-phase1a-design-self-review.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-phase1a-design-spec.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-phase1a-implementation-plan.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task1-xcode-graph.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task10-final-portable-closeout.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task2-product-contracts.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task3-owner-amendment.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task3-runtime-shell.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task4-jit-orchestration.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task5-open-in.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task6-runtime-artifacts.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task7-release-packaging.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task8-portable-gate.json
- docs/aegis/work/2026-07-22-vulpra-runtime-shell/evidence-bundle-draft-task9-baseline-adr.json

## Drift Check

- Scope status: All Phase 1A planned source/project/tool/test/documentation tasks are complete; tabs/data/final UI were not started.
- Compatibility status: Portable contracts align with iOS 15 arm64 TrollStore-first requirements, but Apple-platform acceptance is unverified.
- Retirement status: All named old/duplicate paths remain retired; RuntimeShellViewController retains its future browser-UI replacement trigger.
- Advisory decision: needs-verification
