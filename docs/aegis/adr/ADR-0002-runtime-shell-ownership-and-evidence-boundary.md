# ADR-0002 - Runtime Shell Ownership and Evidence Boundary

Status: `recorded-from-work`
Date: `2026-07-22`

## Source Evidence

- Runtime-shell work record, Tasks 1-8 commits, portable runner, and direct Gecko AppShellDelegate evidence.
## Context

Vulpra needs a compact iOS 15 runtime around Gecko without restoring the inherited client. The graph, application lifecycle, JIT child readiness, generated artifacts, OpenIn handoff, and Linux-versus-Mac evidence each needed one canonical owner.

## Decision

Use a checked-in native four-target synchronized-group Xcode graph with xcconfig settings; retain Gecko AppShellDelegate and instantiate one Vulpra SceneDelegate from the static scene manifest; use one temporary GeckoSession shell, one exactly-once JIT coordinator, public-only OpenIn handoff, .build/dist generated roots, artifact format v3, and a strict portable-source versus Mac/device evidence split.

## Alternatives Considered

- Copy and rename the inherited Xcode project/client; rejected because it restores excluded owners and complexity.
- Add XcodeGen/Tuist or another project owner; rejected because four targets remain compact in the native graph and an extra dependency adds ownership/update cost.
- Create a second AppDelegate or private OpenIn/JIT fallbacks; rejected because direct substrate evidence identifies existing canonical owners and no device evidence justifies duplicate paths.
## Consequences

- The repository has inspectable single owners and dependency-free portable gates, but current-Xcode compilation, generated binaries, packaging, device behavior, and performance remain explicit Phase 1B evidence.
- RuntimeShellViewController is temporary and retires when the separately planned browser UI owner lands.
## Compatibility Boundary

iOS 15.0+, arm64, iPhone/iPad, TrollStore-first; no old client/data/Xcode identity compatibility and no public release claim.

## Retirement Impact

Old project/client/JIT UI/release owners remain absent; AppDelegate dead code, TSUtils shim, iOS 13 producer settings, artifact v2, Modules-generated archive, and private OpenIn fallback are retired.

## Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- Action: create snapshot
- Reason: The decision establishes the current graph, owner map, artifact/package contracts, compatibility boundary, retirement state, and evidence split.

## Evidence References

- docs/aegis/work/2026-07-22-vulpra-runtime-shell/90-evidence.md
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Tests/RuntimeShell/run-portable.sh
## Boundary

This ADR is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.
