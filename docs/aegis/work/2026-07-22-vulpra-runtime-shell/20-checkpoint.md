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
