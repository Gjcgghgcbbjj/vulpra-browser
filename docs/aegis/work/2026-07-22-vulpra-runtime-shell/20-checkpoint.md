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
