# Vulpra Initial Baseline

Date: `2026-07-21`
Status: `empty-repository-before-substrate-import`

## Product / Requirement Baseline
Vulpra is a new Gecko browser client for iOS 15+ with no Reynard user-data compatibility.

## Architecture / Runtime Boundary Baseline
Only audited Gecko, GeckoView, Helper, low-level JIT, idevice, patch, and build substrate may be imported.

## Compatibility Boundary
No old client, UI, persistence, brand resource, app entry point, or Xcode project enters this repository.
