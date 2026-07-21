# Vulpra Runtime Shell - Checkpoint

- Task ID: 2026-07-22-vulpra-runtime-shell
- Current todo: Write and review the Phase 1 runtime-shell design specification.
- Active slice: Design specification
- Blocked on: Mac/Xcode evidence is deferred by user choice, not blocking Phase 1A.
- Next step: Write the approved native-Xcode design, self-review it, commit it, and request written-spec approval.

## Checkpoint Update

- Current todo: Obtain user approval of the committed Phase 1A written design, then transition to implementation planning.
- Active slice: Written design review gate
- Completed todos:
- Explored the verified baseline, source Xcode graph, Gecko/JIT/Helper contracts, artifact state, and Linux host capability.
- User selected no-current-Mac Phase 1A/Phase 1B evidence split and approved the fresh native Xcode project approach.
- Written design specification completed and self-reviewed.
- Evidence refs:
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Blocked on: User written-spec review is required before implementation planning.
- Next step: Commit the design/work records and ask the user to approve or request changes.

## DriftCheckDraft

- Scope status: Design remains limited to runtime shell Phase 1A and Mac producer contracts; tabs/data/final browser UI/features remain excluded.
- Compatibility status: iOS 15.0, TrollStore-first, exact Vulpra identities, no old client/data/Xcode fallback, and explicit Mac needs-verification boundary are preserved.
- Retirement status: Old project/client/JIT controller/release scripts remain retired by non-copy; the runtime smoke shell has a named future retirement owner.
- New risk signals:
- The compact synchronized-group pbxproj design depends on modern Xcode semantic validation that cannot run on Linux.
- Advisory decision: pause-for-user

## Checkpoint Update

- Current todo: Execute Task 1: create and verify the fresh Xcode graph and configuration owners.
- Active slice: Task 1 Xcode graph RED/GREEN implementation
- Completed todos:
- Approved runtime-shell design committed and user-confirmed.
- Ten-task Phase 1A implementation plan written and self-reviewed.
- Evidence refs:
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- docs/aegis/plans/2026-07-22-vulpra-runtime-shell.md
- Blocked on: Mac/Xcode compilation evidence remains deferred to Phase 1B and does not block portable Task 1.
- Next step: Commit the approved plan, write the failing Xcode graph test, verify RED, then implement the minimal graph under the 800-line budget.

## DriftCheckDraft

- Scope status: Planning remains limited to Phase 1A runtime shell and producer contracts; tabs, data, final UI, and release claims remain excluded.
- Compatibility status: iOS 15.0, arm64, TrollStore-first, no old identity/data/Xcode fallback, and Mac evidence deferral remain intact.
- Retirement status: Old client/project/JIT UI/release owners remain absent; RuntimeShellViewController remains an explicitly temporary smoke owner.
- New risk signals:
- Hand-authored objectVersion 77 synchronized groups require later validation by current Xcode.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 2: add app metadata, entitlement profiles, and pure URL routing.
- Active slice: Task 2 product identity and URL input contracts
- Completed todos:
- Approved runtime-shell design and ten-task implementation plan.
- Task 1 fresh Xcode graph and configuration owners pass portable RED/GREEN verification.
- Evidence refs:
- Tests/RuntimeShell/test-xcode-graph.py
- Vulpra.xcodeproj/project.pbxproj
- Configuration/Base.xcconfig
- Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme
- Blocked on: Current Xcode semantic acceptance remains Phase 1B needs-verification; no Phase 1A blocker.
- Next step: Commit Task 1, then write the failing product-contract test before creating App/Info.plist, entitlements, and RuntimeURLRouter.swift.

## DriftCheckDraft

- Scope status: Task 1 added only the fresh project/configuration owners and structural test; no browser UI, data, or old client code entered.
- Compatibility status: iOS 15.0, arm64, iPhone/iPad, TrollStore-first future entitlements, generated .build/dist roots, and no signing team remain explicit.
- Retirement status: The old Xcode project remains absent; synchronized groups and xcconfigs are the sole new graph/settings owners.
- New risk signals:
- The hand-authored objectVersion 77 graph still requires current-Xcode validation in Phase 1B.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 3: implement the minimal UIKit Gecko runtime shell.
- Active slice: Task 3 one-session UIKit Gecko smoke owner
- Completed todos:
- Task 1 fresh Xcode graph and configuration owners.
- Task 2 product metadata, entitlement profiles, Helper entitlement retirement, and pure URL router pass portable verification.
- Evidence refs:
- Tests/RuntimeShell/test-product-contracts.py
- App/Info.plist
- App/RuntimeURLRouter.swift
- docs/provenance/import-manifest.tsv
- Blocked on: Swift/UIKit/Gecko compilation remains Phase 1B needs-verification; source-contract work can continue.
- Next step: Commit Task 2, then write the failing runtime-shell test before adding main, app delegate, scene delegate, and one-session view controller.

## DriftCheckDraft

- Scope status: Task 2 added identity/input contracts only; no Gecko session, tabs, persistence, settings, or final browser UI.
- Compatibility status: Exact Vulpra identities, iOS 15 families, one URL scheme, minimal private permissions, and no old identity/data fallback remain intact.
- Retirement status: get-task-allow and uncertain web-browser/persona/storage permissions are absent; URL routing has one canonical pure owner.
- New risk signals:
- Private entitlement acceptance remains device/signing evidence for Phase 1B.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 4: add the exactly-once JIT readiness owner and bridge cleanup.
- Active slice: Task 4 exactly-once child JIT readiness orchestration
- Completed todos:
- Task 1 fresh Xcode graph and configuration owners.
- Task 2 product metadata, entitlement profiles, and URL router.
- Task 3 minimal one-session UIKit Gecko runtime shell, canonical missing-engine handling, and AppDelegate owner correction.
- Evidence refs:
- Tests/RuntimeShell/test-runtime-shell.py
- App/RuntimeShellViewController.swift
- Extensions/GeckoView/Session/GeckoSession.swift
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Blocked on: RuntimeJITCoordinator and bridging header are not implemented yet; Mac compilation remains deferred.
- Next step: Commit Task 3, then write the failing JIT orchestration/header-closure test before creating RuntimeJITCoordinator and the bridging header.

## DriftCheckDraft

- Scope status: Task 3 remains one-session smoke integration; no tab, data, settings, downloads, prompt UI, or final chrome owner was added.
- Compatibility status: Static scene manifest composes with Gecko AppShellDelegate; iOS 15 identities and URL contract remain unchanged; missing view degrades visibly without renderer fallback.
- Retirement status: The planned dead AppDelegate owner is retired before creation; GeckoSession fatal path is retired in favor of the canonical App failure owner; old source project remains rejected.
- New risk signals:
- Static scene-manifest behavior and the adjusted GeckoSession path still require Xcode/device evidence in Phase 1B.
- Advisory decision: continue
