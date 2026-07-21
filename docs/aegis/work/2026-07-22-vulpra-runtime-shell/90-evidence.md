# Vulpra Runtime Shell - Evidence

No evidence has been recorded yet.

## EvidenceBundleDraft

- Artifact key: phase1a-design-spec
- Type: design-spec
- Source: docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Summary: Written design pins the fresh four-target native Xcode graph, iOS 15.0 identities, six new runtime owners, 4.5-second exactly-once JIT readiness contract, generated artifact boundaries, unsigned packaging contract, portable/Mac evidence split, and complexity budgets.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: phase1a-design-self-review
- Type: review
- Source: docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Summary: Self-review passed placeholder, internal consistency, scope, ambiguity, owner, falsifier, compatibility, retirement, ADR-signal, line-pressure, and Aegis workspace checks; written user review remains pending.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: phase1a-implementation-plan
- Type: implementation-plan
- Source: docs/aegis/plans/2026-07-22-vulpra-runtime-shell.md
- Summary: Approved ten-task inline Phase 1A plan defines fresh Xcode graph, runtime owners, JIT contract, artifact/package producers, portable gate, baseline closeout, and explicit Phase 1B deferral.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task1-xcode-graph
- Type: portable-verification
- Source: Tests/RuntimeShell/test-xcode-graph.py; Vulpra.xcodeproj/project.pbxproj; Configuration/*.xcconfig; Vulpra.xcscheme
- Summary: Portable graph contract passed: exactly four targets, app dependencies and embeds, ordered artifact/copy phases, objectVersion 77 synchronized groups, 24-character IDs, five xcconfigs, iOS 15 arm64 settings, one XML-valid shared scheme, no signing identity, active identity pass; pbxproj 259 lines and all Task 1 files below 800.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task2-product-contracts
- Type: portable-verification
- Source: Tests/RuntimeShell/test-product-contracts.py; App/Info.plist; App/Entitlements; App/RuntimeURLRouter.swift; Extensions/Helper/Entitlements; docs/provenance/import-manifest.tsv
- Summary: Product-contract RED/GREEN passed: four bundle IDs, one vulpra URL scheme, one UIKit scene, launch dictionary, iPhone/iPad arm64 iOS 15 contract, exact minimal standard/private app entitlements, corrected Helper identity with get-task-allow removed, pure http/https and vulpra://open URL router. All plists, active identity, import boundary, graph, manifest, and diff checks pass; router is 43 lines.
- Verifier: root
