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

## EvidenceBundleDraft

- Artifact key: task3-runtime-shell
- Type: portable-verification
- Source: Tests/RuntimeShell/test-runtime-shell.py; App/main.swift; App/SceneDelegate.swift; App/RuntimeShellViewController.swift; Extensions/GeckoView/Session/GeckoSession.swift
- Summary: One-session runtime-shell RED/GREEN passed: JIT startup precedes GeckoRuntime.main, static scene manifest uses one SceneDelegate/window/root, validated incoming URLs reach one GeckoSession, engineView is edge-constrained, deterministic smoke URL loads, active/focused lifecycle updates, teardown closes the session, and missing engine view remains observable for one plain failure label. Owner lines: main 6, SceneDelegate 48, shell 95, router 43.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task3-owner-amendment
- Type: architecture-amendment
- Source: Patches/widget/uikit/nsAppShell.mm.patch; docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md; docs/aegis/plans/2026-07-22-vulpra-runtime-shell.md
- Summary: Direct substrate evidence shows UIApplicationMain hardcodes Gecko AppShellDelegate. Design and plan were amended to keep it as the sole application delegate and let Info.plist instantiate SceneDelegate, avoiding dead AppDelegate code. GeckoSession fatal handling was narrowed so the App failure owner can execute. Legacy-project regression guard now rejects only the retired source graph, not Vulpra.xcodeproj.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task4-jit-orchestration
- Type: portable-verification
- Source: Tests/RuntimeShell/test-jit-orchestration.py; App/RuntimeJITCoordinator.swift; App/Bridging/Vulpra-Bridging-Header.h; Extensions/GeckoView/View/GeckoView.h
- Summary: Exactly-once JIT orchestration RED/GREEN passed: one attach queue, one state queue, positive PID validation, normalized tab-only attach, 4.5-second deadline, pending/completed duplicate suppression, atomic pending removal before one report, false non-tab/deadline/failure/teardown reporting, late completion suppression, hasTXMSupport false, observer removal, detach, 142-line owner, minimal bridge closure, and direct TSUtils import retirement.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task5-open-in
- Type: portable-verification
- Source: Tests/RuntimeShell/test-open-in.py; Extensions/OpenIn/Info.plist; Extensions/OpenIn/OpenInViewController.swift
- Summary: OpenIn RED/GREEN passed: exactly one web-URL activation rule, Vulpra principal/error identities, UTType URL extraction, URLComponents-encoded vulpra://open query, one NSExtensionContext.open call, one MainActor completion gate, one complete and one cancel path, no private workspace/responder API, and a 104-line owner.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task6-runtime-artifacts
- Type: portable-verification
- Source: Tests/RuntimeShell/test-runtime-artifacts.sh; Tools/Runtime; Tools/Gecko; Tools/Build/AddGecko.sh; docs/provenance/import-manifest.tsv
- Summary: Runtime artifact RED/GREEN passed: Gecko and idevice deploy at 15.0; Cargo output is .build/idevice/aarch64-apple-ios/release/libidevice_ffi.a with no Modules write; format v3 keys include Xcode and SDK builds, Firefox/patch/build inputs, reject stale format/SDK, and require IOSBootstrap/GeckoViewSwiftSupport/XUL/dylibs/theme; non-Darwin prerequisite exits 78 needs-macos; orchestrator orders submodules, patching, idevice, Gecko, pack, verify; AddGecko verifies and uses repository-root paths. All scripts under 250 lines and no generated output appeared.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task7-release-packaging
- Type: portable-verification
- Source: Tests/RuntimeShell/test-release-packaging.sh; Tools/Release
- Summary: Release packaging RED/GREEN passed: unsigned generic-iOS archive command, iOS 15 arm64 ptrace compile, archive/app/stage/output package owner, exact four bundle identities, required Gecko products, deterministic fixed-metadata Payload zip, sorted SHA256SUMS, refusal cases, copied-stage ldid entitlement flow, no archive mutation, no team/profile/plist identity rewrite. Script lines are 18/20/35/77 and no output artifact appeared.
- Verifier: root

## EvidenceBundleDraft

- Artifact key: task8-portable-gate
- Type: portable-verification
- Source: .github/workflows/bootstrap-core.yml; Tests/RuntimeShell/run-portable.sh; Tests/Bootstrap/test-repository-shape.sh
- Summary: Canonical portable gate passed: existing ubuntu-latest workflow keeps submodules false and no package installs, runs all six Bootstrap tests then one RuntimeShell runner; runner executes graph/product/runtime/JIT/OpenIn/artifact/package fixtures, Gecko artifact regression, interpreter-aware shell syntax, plist/scheme parsing, and diff check. Nested Git-root regression and Aegis workspace check pass.
- Verifier: root
