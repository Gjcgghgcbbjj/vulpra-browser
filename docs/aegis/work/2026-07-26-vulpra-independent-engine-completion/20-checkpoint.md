# Vulpra Independent Engine Completion and IPA - Checkpoint

- Task ID: 2026-07-26-vulpra-independent-engine-completion
- Current todo: Implement Task 1 message contracts and Task 2 EngineKit runtime from the real artifact ABI.
- Active slice: Independent runtime contracts and implementation.
- Blocked on: Mac/Xcode execution requires a remote runner and current changes are not committed or pushed.
- Completed todos: completion plan written from approved baselines and real ABI inventory.
- Evidence refs: `docs/aegis/plans/2026-07-26-vulpra-independent-engine-completion.md`.
- Next step: add failing runtime/message source-contract tests, then implement EngineKit owners.

## Checkpoint Update

- Current todo: Build and locally validate final IPA/TIPA from the metadata-complete snapshot.
- Active slice: Final package reproduction, local validation, evidence bundle, and CI ref cleanup.
- Completed todos:
- Implemented independent VulpraEngineKit runtime, ABI bridge, deterministic session queue, and native view lifecycle.
- Implemented native Engine Process endpoint transport and verified child-process connections.
- Migrated the App and Xcode graph, retired all old runtime/JIT/source-build paths, and preserved product/data contracts.
- Verified visible HTTPS simulator navigation and candidate IPA/TIPA packaging.
- Closed cutover gates and recorded ADR-0004 plus the independent-engine baseline.
- Evidence refs:
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30213751790
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30214371123
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- Blocked on: Final metadata-complete package run and local artifact download are still pending.
- Next step: Create a metadata-complete commit-tree ref, run the package workflow, replace dist, validate locally, bundle Aegis evidence, then remove every temporary CI ref.

## DriftCheckDraft

- Scope status: Implementation remains within the approved independent-engine and IPA scope.
- Compatibility status: com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, and TabManager/BrowserTab ownership are preserved.
- Retirement status: Old adapter, Helper, JIT, patch, source-build, gitlink, and fallback paths are retired with no compatibility exception.
- New risk signals:
- Xcode 16.4 is absent from the current macos-26 runner; physical-device validation remains outside the package completion boundary.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: Assemble the final proof bundle and remove every temporary CI ref.
- Active slice: Final proof bundle, verification-before-completion, and CI ref cleanup.
- Completed todos:
- Implemented independent VulpraEngineKit runtime, ABI bridge, deterministic session queue, and native view lifecycle.
- Implemented native Engine Process endpoint transport and verified child-process connections.
- Migrated the App and Xcode graph, retired all old runtime/JIT/source-build paths, and preserved product/data contracts.
- Verified visible HTTPS simulator navigation and final IPA/TIPA packaging.
- Closed cutover gates, recorded ADR-0004 and the independent-engine baseline, and placed locally validated packages in dist.
- Evidence refs:
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30213751790
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30215026323
- dist/SHA256SUMS
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- Blocked on: none
- Next step: Run Aegis bundle/check and final verification, delete all local/remote ci/vulpra-independent-engine refs, and confirm the user branch HEAD remains unchanged.

## DriftCheckDraft

- Scope status: All implemented and packaged behavior remains within the approved independent-engine and IPA scope.
- Compatibility status: Bundle identity, iOS 15 target, iPhone/iPad, OpenIn, Codable data, and TabManager/BrowserTab ownership are preserved.
- Retirement status: Old adapter, Helper, JIT, patch, source-build, gitlink, and fallback paths are absent from the active graph and package.
- New risk signals:
- Xcode 16.4 is unavailable on the current runner; physical-device and public-release evidence remain separate external gates.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Close final evidence and workspace integrity for the runtime/package identity repair.
- Active slice: Final verification and evidence closure.
- Completed todos:
- Repaired runtime/session actor ownership, ready transition, dependency injection, ABI lifetime, and Engine Process cleanup.
- Pinned engine artifact identity and enforced package version/UI fingerprint.
- Passed final simulator run 30239461150 and package run 30240301567 from snapshot 95338aad.
- Validated and copied IPA/TIPA/SHA256SUMS to dist and the Windows desktop.
- Removed every temporary runtime-package-identity CI ref while preserving user HEAD and index.
- Evidence refs:
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30239461150
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30240301567
- dist/SHA256SUMS
- /mnt/c/Users/niting/Desktop/Vulpra/SHA256SUMS
- Blocked on: none
- Next step: No source/package task work remains; physical-device coverage stays an external release gate.

## DriftCheckDraft

- Scope status: The repair and package identity work remained inside the approved independent-engine, Chinese-first UI, and IPA/TIPA delivery scope.
- Compatibility status: com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, and TabManager/BrowserTab ownership remain preserved.
- Retirement status: GeckoView, Helper, JIT, source-build, alternate artifact, and fallback paths remain retired; no duplicate owner was introduced.
- New risk signals:
- Physical-device installation and public distribution remain outside this evidence boundary.
- Advisory decision: continue
