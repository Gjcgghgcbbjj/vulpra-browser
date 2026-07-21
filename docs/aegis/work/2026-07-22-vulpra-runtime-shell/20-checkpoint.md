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
