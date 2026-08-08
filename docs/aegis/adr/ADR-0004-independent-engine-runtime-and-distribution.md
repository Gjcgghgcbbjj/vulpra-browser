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

## Amendment - 2026-07-29 - Final distribution is verified at snapshot ac5e6ff with package identity 0.2.0 (4) / porcelain-zh-v4-20260728. The Simulator evidence boundary now distinguishes historical same-runtime-tree executable rendering from the current GitHub-hosted rerun gate: the historical loopback page completed and rendered visibly, but three formal reruns did not close the hosted gate, so Simulator status remains needs-verification.

- Status: amended

### Source Evidence

- Package run 30398876901; historical loopback runs 30388203550, 30389904599, and 30389908011; formal hosted Simulator reruns 30393594180, 30395172252, and 30397230869; snapshot ac5e6ff and local artifact validation.
### Change Summary

Final distribution is verified at snapshot ac5e6ff with package identity 0.2.0 (4) / porcelain-zh-v4-20260728. The Simulator evidence boundary now distinguishes historical same-runtime-tree executable rendering from the current GitHub-hosted rerun gate: the historical loopback page completed and rendered visibly, but three formal reruns did not close the hosted gate, so Simulator status remains needs-verification.

### Compatibility Boundary

Preserve com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, TabManager/BrowserTab/VulpraEngineKit ownership, the pinned v4 artifact, and standard IPA plus TrollStore TIPA outputs.

### Retirement Impact

No fallback, duplicate runtime owner, GeckoView, Helper, JIT, source-build client path, or alternate artifact was restored. Hosted runner drift is recorded as a verification gap, not as a compatibility path.

### Baseline Sync

- Needed: needed
- Target: docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md
- Action: update baseline
- Reason: The final package version, UI fingerprint, hashes, package run, historical executable evidence, and current hosted Simulator needs-verification state replace the prior simulator-and-package-verified snapshot claim.

### Evidence References

- docs/aegis/work/2026-07-26-vulpra-independent-engine-completion/90-evidence.md
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30398876901
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30389904599
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30397230869
### Boundary

This amendment is an advisory Aegis Method Pack record. It does not grant completion authority or replace project-authoritative architecture sources.

---

## Amendment - 2026-08-08 - Gecko v5 r0.3 repeat-verified pair is the locked
engine; the hosted Simulator R0 gate is 20/20 under the evidence-loss-proof
contract; the final package is bound to the same snapshot. The v4/vtool
simulator derivation, old contract files, and retired harness paths are removed;
only device/simulator native v5 kernels remain.

### Source Evidence
- Engine/VulpraEngineKit/Internal/Lifecycle/EngineLifecycles.swift (terminal
  state machine; ready-only-fails on non-recoverable main exit)
- Engine/VulpraEngineKit/Internal/Process/EngineChildProcessLifecycle.swift
  (typed child launch state machine: requested -> extensionConnected ->
  bootstrapAcknowledged -> ipcConnected)
- Engine/VulpraEngineProcess/EngineProcessRequest.swift (protocolVersion=2,
  typed XPC endpoint handoff validation)
- Tools/CI/run-simulator-navigation.sh (warm settle evidence unconditional +
  persisted unified-log fallback; gate-http-dispatch delivery)
- Tools/CI/summarize-r0-engine-gate.py (20-attempt contract:
  locationMatched, pageCompleted, renderedDarkPixels>=1000, crashCount==0,
  deliveryMethod=gate-http-dispatch, warmSettleSeconds>=0,
  gateDispatchStatus=0, no open/failed child launches,
  p95<=15000ms max<=30000ms)
- Configuration/engine-artifact-lock.json (v5, producer 30598301958,
  Firefox 27b462b, releaseTag vulpra-engine-v5-r0.3-candidate)
- Tests/IndependentEngine/test_cutover_readiness.py --require-r0-complete
  (verified; cutover-ready)

### Change Summary
- Promoted Gecko v5 r0.3 pair: producer runs 30598301958 (device+simulator)
  and 30598347174 (device+simulator); repeat compile verified; promotion run
  30613021710; selected producer 30598301958; artifactFormatVersion=5.
- Locked engine: Configuration/engine-artifact-lock.json (v5,
  vulpra-engine-v5-r0.3-candidate, Firefox 27b462b, compiledBy 30598301958).
- Hosted Simulator R0 gate: run 31237088851 @ 4b2dc58, 20/20 attempts,
  deliveryMethod=gate-http-dispatch, p95=1810ms max=1961ms,
  warm settle evidence >=0 on all attempts, open/failed launches=0.
- Final package: run 31244000908 @ 4b2dc58; Vulpra.ipa
  0971a3ad2744ebfb8881021ceb08f7d62dd8a762997ba245fa3c115bbaf039fc; Vulpra-TrollStore.tipa 5adc09ba48cb757a9814c13250d21c935fdac213c033cb8e0834d32f6f351802.
- Simulator evidence contract upgraded: warm settle is recorded unconditionally
  when the app is alive; navigation completion falls back to a throttled
  persisted unified-log snapshot when the live stream drops events
  (run 31220738161 attempt-01 root cause).
- v4/vtool paths retired: produce-simulator-artifact.sh, old Simulator
  workflow, v4 contracts, legacy artifact/Simulator tests, vtool-derived
  simulator binary path. Simulator kernel is now a native iphonesimulator
  build, not a vtool-mangled device binary.

### Compatibility Boundary
- Gecko v5 kernel and Swift/App layer are frozen at 4b2dc58 for this package;
  no engine recompile is required for App/EngineKit-only changes.
- Device and Simulator kernels are independent native builds with identical
  verified source inputs; binary identity audit (annex 19) shows packaged
  XUL == verified artifact except signature plumbing.

### Retirement Impact
- v4 contract files, produce-simulator-artifact.sh, old Simulator workflow,
  and legacy v4 tests are gone; retirement is asserted by
  Tests/IndependentEngine/test_cutover_readiness.py --require-r0-complete
  (retired paths + active-root token scan).

### Baseline Sync
- docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md:
  status package-verified-simulator-20-20; independent engine cutover
  complete-v5-r0.3; hosted Simulator gate verified-20-20; last amended
  2026-08-08; v5 lock values + final package hashes; physical device/JIT/
  OpenIn/App Store remain needs-verification.

### Evidence References
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30598301958
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30598347174
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30613021710
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/31237088851
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/31244000908

### Boundary
- This amendment is an advisory Aegis record. Physical-device behavior,
  JIT-on-device, OpenIn-on-device, and App Store distribution eligibility are
  NOT claimed by this amendment and remain external validation items.
