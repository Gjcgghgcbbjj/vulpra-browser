# ADR-0003 - Modern Browser Ownership and GitHub Distribution Boundary

Status: `recorded-from-work`
Date: `2026-07-22`

## Source Evidence

- Completed Vulpra modern-browser work record, runtime run 29856427149, package run 29877342036, portable suites, and downloaded package checksums.
## Context

The temporary one-session runtime shell needed to become a bounded multi-tab browser without restoring the inherited client. The project also needed one reproducible macOS owner for the expensive Gecko substrate and installable iOS packages while development continued from a non-macOS host.

## Decision

BrowserViewController is the application root owner, TabManager is the sole BrowserTab lifecycle owner, feature stores own bounded local state, and GitHub Actions is the macOS build orchestration owner. Runtime artifacts are built once, keyed exactly, then restored for IPA/TIPA packaging without rebuilding Gecko.

## Alternatives Considered

- Retain RuntimeShellViewController and add features around it; rejected because it would preserve a temporary owner and concentrate unrelated browser state.
- Copy the inherited browser client or add third-party browser/UI frameworks; rejected because it would restore excluded complexity and duplicate owners.
- Rebuild Gecko during every IPA job or rely on an undocumented local Mac flow; rejected because it increases build time, weakens artifact identity, and makes distribution non-reproducible.
## Consequences

- The client remains dependency-light and owner-bounded, while macOS builds are reproducible and the 4-hour Gecko result is reused. GitHub credentials and artifact retention become operational dependencies, and physical-device behavior remains a separate evidence gate.
## Compatibility Boundary

iOS 15.0+, arm64, iPhone/iPad, TrollStore-first, four bundle products, exactly-once JIT readiness, public OpenIn handoff, no inherited-client compatibility, and no public-release claim.

## Retirement Impact

RuntimeShellViewController and the one-session smoke owner are deleted. No fallback client, duplicate tab owner, in-job Gecko rebuild, framework bridging header, or private OpenIn path remains.

## Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md
- Action: create snapshot
- Reason: The work changes the root owner, state ownership map, distribution owner, verified artifact boundary, and package evidence state.

## Evidence References

- docs/aegis/work/2026-07-22-vulpra-modern-browser/90-evidence.md
- docs/aegis/specs/2026-07-22-vulpra-modern-browser-product-design.md
- Tests/Browser/run-portable.sh
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/29877342036
## Boundary

This ADR is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.
