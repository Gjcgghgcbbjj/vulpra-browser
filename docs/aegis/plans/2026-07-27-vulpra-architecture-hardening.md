# Vulpra Architecture Hardening Plan

Date: `2026-07-27`
Status: `in-progress`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## Goal

Close the reviewed lifecycle, ABI ownership, distribution-boundary, artifact,
test, and build-identity gaps without restoring retired Gecko/JIT owners or
changing user data.

## Architecture

`VulpraEngineKit` remains the sole engine adapter. The ObjC ABI bridge owns
native callback leases; runtime and session actors own typed state machines;
the App composition tree owns explicit session shutdown; release profiles own
distribution capability checks; one build identity file owns package identity.

## Tech Stack

Swift/UIKit, Objective-C++, XCTest, Python contract tests, shell release tools,
Xcode/GitHub Actions.

## Baseline/Authority Refs

- `docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md`
- `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`
- Architecture review findings accepted by the user's `全部修复` instruction.

## Compatibility Boundary

Preserve `com.vulpra.browser`, iOS 15, iPhone/iPad, OpenIn, Codable user data,
Chinese-first Porcelain UI, `TabManager`/`BrowserTab` ownership, and the sole
precompiled-engine path. Do not add fallbacks or migrate/delete persistent data.

## Verification

- Native tests exercise callback cancellation, runtime/session terminal states,
  retry, and explicit shutdown.
- Portable gates enforce simulator-lock usage, release-profile separation, and
  one build-identity owner.
- `git diff --check` and all three portable suites pass.
- Simulator/device packaging remains an external CI gate when macOS/Xcode or
  signed-device execution is unavailable locally.

## Work

1. Replace borrowed async ABI callback pointers with owned, once-only leases;
   invalidate them without freeing storage still referenced by Swift.
2. Add typed runtime/session terminal states, bounded startup, observable
   failures, retry, and remove the dead split startup contract.
3. Add an explicit App shutdown chain that closes every native session before
   scene owners are released.
4. Define standard and TrollStore distribution profiles, validate required
   native capabilities, and make the no-op sandbox decision explicit/fail-fast.
5. Make simulator CI consume `engine-artifact-lock.json.simulator` directly.
6. Replace token-only confidence with behavior tests around the new owners.
7. Move version/build/fingerprint to one build-identity source and derive all
   validators/workflows from it.
8. Update ADR/baseline evidence, run regression gates, and inspect complexity.

## Retirement

Delete duplicate package identity constants and the unused public startup/
pending-request promises once their current consumers are proven absent. No
compatibility carrier is retained for internal-only APIs.
