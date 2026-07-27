# ADR-0004 - Independent Engine Runtime and Distribution Boundary

Status: `recorded-from-work`
Date: `2026-07-27`

## Source Evidence

- Independent-engine completion work; visible simulator run 30213751790; final package run 30215026323.
## Context

The prior runtime shell depended on GeckoView, Helper, JIT coordination, patch/source-build paths, and a v3 runtime artifact. The completed cutover replaces those owners with an independently authored VulpraEngineKit and child-process host over a verified precompiled v4 Gecko runtime.

## Decision

Use Precompiled Gecko Runtime -> VulpraEngineKit -> Vulpra App as the only dependency direction. VulpraEngineKit owns the sole App adapter, ABI bridge, session command queue, typed events, and native view lifecycle. VulpraEngineProcess owns native NSXPCListenerEndpoint transport and ChildProcessInit. GitHub workflows restore the verified v4 binary artifact, build without Gecko source, prove visible simulator navigation, and produce validated IPA/TIPA packages. No runtime fallback or JIT path is retained.

## Alternatives Considered

- Retain the GeckoView/Helper/JIT substrate behind a compatibility adapter; rejected because it preserves duplicate owners and inherited integration source.
- Rebuild or patch Gecko during normal App/package builds; rejected because the verified precompiled artifact is the only allowed compatibility carrier.
- Archive NSXPCListenerEndpoint into NSData; rejected by platform evidence because NSXPCListenerEndpoint may only be encoded by NSXPCCoder.
## Consequences

- Normal builds are smaller in ownership scope and deterministic, but depend on the pinned v4 artifact and private ABI headers. Simulator/package evidence is reproducible; physical-device compatibility and public release review remain separate gates.
## Compatibility Boundary

Preserve com.vulpra.browser, iOS 15.0, arm64 iPhone/iPad, OpenIn, existing Codable data, and TabManager/BrowserTab ownership. Do not delete or migrate user data.

## Retirement Impact

GeckoView sources and target, old Helper, RuntimeJITCoordinator, ptrace/JIT producers, Patches, Tools/Gecko, source-build workflows, Firefox/idevice gitlinks, and fallback paths are retired. Historical provenance remains documentation only.

## Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Action: create snapshot
- Reason: The decision changes the runtime owner, process transport, artifact contract, Xcode products, retirement set, evidence model, and package validation boundary.

## Evidence References

- docs/aegis/work/2026-07-26-vulpra-independent-engine-completion/90-evidence.md
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30213751790
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30215026323
## Supersedes

- ADR: docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- Reason: The independent engine removes the temporary GeckoView/JIT runtime-shell architecture and its v3 artifact boundary.
## Boundary

This ADR is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.

## Amendment - 2026-07-27 - Main-actor runtime/session ownership, native-only ready transition, protocol injection, ABI borrowed-value lifetime, Engine Process cleanup, repository-pinned engine artifacts, and install-visible package UI identity are now enforced as the independent-engine boundary.

- Status: amended

### Source Evidence

- Simulator run 30239461150 and package run 30240301567 from snapshot 95338aadf837906c8baa8b3f4896d8f7acdee997.
### Change Summary

Main-actor runtime/session ownership, native-only ready transition, protocol injection, ABI borrowed-value lifetime, Engine Process cleanup, repository-pinned engine artifacts, and install-visible package UI identity are now enforced as the independent-engine boundary.

### Compatibility Boundary

Preserve com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, and TabManager/BrowserTab ownership.

### Retirement Impact

No fallback or duplicate runtime owner was added; GeckoView, Helper, JIT, source-build, and alternate artifact paths remain retired.

### Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Action: update baseline
- Reason: The runtime actor/ready ownership, artifact lock, package version/fingerprint, final run IDs, and package hashes changed current-state evidence.

### Evidence References

- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30239461150
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30240301567
### Boundary

This amendment is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.
