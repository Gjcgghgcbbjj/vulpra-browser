# ADR-0001 - Phase 0 Substrate Ownership Boundary

Status: `recorded-from-work`
Date: `2026-07-21`

## Source Evidence

- /root/reynard-browser/docs/aegis/work/2026-07-21-vulpra-repository-bootstrap plus target commits b6c65dc, 12397ee, 9001887, and 5c3a1e3
## Context

Vulpra needs an independently owned iOS 15+ browser client while retaining the expensive, already-audited Gecko-on-iOS, Helper, and low-level JIT substrate. Continuing inside the inherited client would preserve oversized owners, old identity, stores, UI, resources, Xcode coupling, and migration pressure; rewriting the engine substrate would discard validated work.

## Decision

Use a fresh standalone Vulpra repository. Import only regular files covered by the manifest at source commit ef14c2997ae7dfdb44155240ec64fea3140ba9e1 under the five roots Vendor, Patches, Tools, Extensions, and Modules; pin Firefox and idevice as exact gitlinks; rename active runtime contracts to Vulpra; exclude the inherited client, UI, stores, resources, Xcode project, binaries, and old-data compatibility. Future product features must use new Vulpra owners and separate plans.

## Alternatives Considered

- Continue evolving the Reynard repository in place and delete old owners incrementally; rejected because history, target graph, identity, data compatibility, and duplicate-owner pressure would remain coupled.
- Reimplement Gecko/iOS/JIT integration from scratch; rejected because it discards the difficult validated substrate without improving client ownership.
- Copy the broader client and cosmetically rename it; rejected because it violates the full client rewrite and no-migration product requirement.
## Consequences

- The repository has an inspectable 345-row import boundary and no old client fallback, so client complexity cannot hide inside inherited structure.
- A new Xcode graph, runtime shell, domain/store/UI owners, final Gecko rebuild, device evidence, and release packaging still must be implemented in later plans.
- Two SafariShared-derived patches and idevice binary/FFI notice scope remain publication blockers.
## Compatibility Boundary

Future targets must support iOS 15+ and TrollStore-first packaging, but Phase 0 preserves no Reynard bundle/runtime identifier, no old client API, and no old-data discovery or migration. Any dependency on an excluded owner falsifies this ADR boundary and requires architecture review rather than a silent fallback.

## Retirement Impact

The inherited client, UI, stores, resources, Xcode project, old product identity, and data compatibility paths are retired by non-import. The Phase 0 bootstrap plan retires after portable closeout; later scopes use new plans and may not grow this import boundary without an amendment.

## Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-21-initial-baseline.md
- Action: update baseline
- Reason: The baseline already records the verified current owner, dependency, identity, exclusion, complexity, and evidence state; it now needs an explicit citation to this ADR as the reason record.

## Evidence References

- docs/provenance/substrate-boundary.md
- docs/provenance/import-manifest.tsv
- docs/aegis/baseline/2026-07-21-initial-baseline.md
- /root/reynard-browser/docs/aegis/work/2026-07-21-vulpra-repository-bootstrap/proof-bundle.md
## Boundary

This ADR is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.
