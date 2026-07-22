# ADR-0002 - Vulpra-First Product Integration

Status: `recorded-from-work`
Date: `2026-07-23`

## Source Evidence

- docs/aegis/work/2026-07-23-vulpra-first-integration, the integration plan, ownership gates, and the verified clean worktree diff
## Context

The compiled Vulpra client and a proven Gecko startup contract existed on separate histories. Making Reynard the product owner and deleting visible pieces would retain the wrong client, project, resources, data owners, and future compatibility pressure.

## Decision

Keep the clean Vulpra repository as the sole product owner. Transfer only independently authored Vulpra App, Configuration, OpenIn, Xcode, runtime/release, test, and workflow roots by allowlist; retain GeckoView, Helper, JIT, patches, and build tools only as provenance-tracked substrate; use the bootable Reynard repository only to inspect necessary launch, embedding, runpath, signing, and packaging contracts.

## Alternatives Considered

- Copy or merge the bootable Reynard product and remove unwanted screens; rejected because the old client and product ownership would remain canonical.
- Rebuild the Gecko/iOS/JIT substrate from scratch; rejected because it discards an expensive audited runtime without improving Vulpra product ownership.
- Keep both Vulpra and Reynard product paths behind compatibility fallbacks; rejected because it creates duplicate owners and masks integration defects.
## Consequences

- Vulpra owns all UI, browser behavior, stores, resources, identities, project graph, and release orchestration; substrate-derived files remain visibly attributed and machine-audited.
- The exact runtime artifact may be reused when its Firefox, idevice, patch, producer, Xcode, and SDK identity matches; product changes do not force a Gecko rebuild.
- GitHub package success proves compilation and package shape only; physical-device launch remains a separate user-confirmed gate.
## Compatibility Boundary

iOS 15.0+, arm64, iPhone and iPad, four Vulpra bundle identities, TrollStore-first TIPA packaging, no old client/data/resource compatibility, and no public release claim.

## Retirement Impact

The Reynard product route, copied project/resources/client, diagnostic startup branches, fake simulator label smoke path, and duplicate product owners are retired. Reynard remains read-only evidence and is never a build input.

## Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md
- Action: create snapshot
- Reason: The owner map, compatibility boundary, product/runtime split, reusable artifact boundary, and current verification state changed materially.

## Evidence References

- docs/aegis/plans/2026-07-23-vulpra-first-proven-startup-integration.md
- docs/provenance/product-boundary.md
- docs/provenance/substrate-deltas.tsv
- Tests/Ownership/run-portable.sh
- Tests/RuntimeShell/run-portable.sh
- Tests/Browser/run-portable.sh
## Boundary

This ADR is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.
