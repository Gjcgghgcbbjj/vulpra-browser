# Vulpra Initial Baseline

Date: `2026-07-21`
Status: `bootstrap-in-progress`

## Product / Requirement Baseline
Vulpra is a new Gecko browser client for iOS 15+ with no Reynard user-data compatibility.
Efficiency is a Product non-negotiable: Vulpra-authored binary, resources,
runtime performance, dependencies, and maintained complexity must remain
explicitly budgeted rather than hidden by Gecko/vendor payload.

## Architecture / Runtime Boundary Baseline
Only audited Gecko, GeckoView, Helper, low-level JIT, idevice, patch, and build substrate may be imported.
Efficiency is an Architecture non-negotiable: production source, tests, build
tools, specs, plans, and work records are maintained complexity surfaces, with
imported `Vendor/` and raw `Patches/` measured separately.

No third-party dependency may be added without documenting its requirement,
binary/runtime cost, security/update owner, and native-alternative comparison.

Task 2 evidence snapshot as of `2026-07-21` is within budget:
`Tools/Bootstrap/import-substrate.sh` is 157 lines,
`Tools/Bootstrap/generate-import-manifest.py` is 437 lines, and
`Tests/Bootstrap/test-import-boundary.sh` is 275 lines. The generator and
boundary test require an owner split if responsibilities or size grow
materially. No third-party dependencies are present. Client binary/resource,
IPA, startup, memory, and frame-budget measurements remain
`needs-verification` until macOS/device evidence exists.

Exact implementation-file counts are dated evidence, not durable authority.
Durable budgets, measurement protocol, dependency gates, and closure rules are
owned by `docs/aegis/policies/efficiency-complexity-governance.md`.

## Compatibility Boundary
No old client, UI, persistence, brand resource, app entry point, or Xcode project enters this repository.
