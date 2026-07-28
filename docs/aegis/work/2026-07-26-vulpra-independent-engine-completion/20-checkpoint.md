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

## Checkpoint Update - Integrated Client and Patched Simulator Runtime

- Current todo: Replace the failed experimental Simulator runtime with the patched producer artifact, then run one integrated simulator/package delivery.
- Active slice: Await producer run 30277909573 after completing client performance, website compatibility, and icon-first Porcelain UI work.
- Completed todos:
- Coalesced tab persistence, omnibox suggestions, and progress completion animation updates.
- Added deterministic localhost/IP/port/search parsing and structured query encoding.
- Routed Gecko `OnLoadError` into a typed, URL-preserving failure with explicit retry and HTTP-upgrade recovery; no automatic downgrade or fallback renderer was added.
- Refined start-page symbols/labels, address state icon, tab-count badge, and tab toolbar symbols while preserving Chinese-first Porcelain presentation.
- Advanced install-visible identity to `0.2.0 (3)` / `porcelain-zh-v3-20260728` through the canonical build identity owner.
- Passed all three portable suites, build-identity generation/check, compileall, and diff check.
- Snapshot a751acd passed remote Xcode compilation and six EngineKit tests in run 30287131207; its screenshot exposed and drove the centered-brand repair. Navigation did not run because bounded `simctl terminate` timed out after the first screenshot, so this run is preliminary evidence only.
- Evidence refs:
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30287131207
- /root/.cache/vulpra-simulator-30287131207/simulator-start-page.png
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30277909573
- Blocked on: patched Simulator Gecko producer run 30277909573 remains in `Build Simulator Gecko`.
- Next step: Download the producer artifact, assemble and verify the canonical 2654-file simulator v4 archive, update the lock/release asset, then run the final integrated simulator and package workflows.

## DriftCheckDraft

- Scope status: Client changes remain inside the approved client-experience, architecture-hardening, and final IPA delivery scope.
- Compatibility status: `com.vulpra.browser`, iOS 15, iPhone/iPad, OpenIn, Codable persistence, and sole TabManager/BrowserTab/VulpraEngineKit owners are preserved.
- Retirement status: No WebKit, GeckoView, JIT, source-build client path, automatic HTTP downgrade, or runtime fallback was introduced; the producer source build remains isolated and temporary.
- New risk signals: Final simulator navigation and the seventh native load-error test still require the patched artifact and a fresh macOS run.
- Advisory decision: needs-verification

## Checkpoint Update - Icon-First Client Polish

- Current todo: Assemble and verify the patched Simulator artifact, then run the final integrated simulator/package delivery.
- Active slice: Await producer run 30277909573 after completing the icon-first client polish.
- Completed todos:
- Replaced the misleading share entry with a truthful `ellipsis.circle` page-tools entry.
- Replaced the text-only page-tools action sheet with one native symbol-led sheet while retaining `PageToolsController` as the sole coordinator.
- Replaced history and permission clear labels with accessible trash icons and added semantic symbols to privacy-data commands.
- Advanced install-visible identity to `0.2.0 (4)` / `porcelain-zh-v4-20260728`.
- Passed all three portable suites, build-identity generation/check, compileall, and diff check after the UI changes.
- Evidence refs:
- `Tests/Browser/test-porcelain-ui.py`
- `Tests/Browser/test-localization-and-icon.py`
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30277909573
- Blocked on: patched Simulator Gecko producer run 30277909573 remains in `Build Simulator Gecko`.
- Next step: Download the producer artifact, assemble and verify the canonical 2654-file simulator v4 archive, update the lock/release asset, then run the final integrated simulator and package workflows.

## DriftCheckDraft

- Scope status: The icon-first changes remain inside the approved Porcelain client presentation and final delivery scope.
- Compatibility status: Existing feature delegates, storage owners, engine contracts, bundle identity, and iOS 15 target remain unchanged.
- Retirement status: `PageToolsController` remains the sole page-tools coordinator; no parallel UI owner or fallback renderer was introduced.
- New risk signals: The new sheet and centered brand still require a fresh Xcode build and simulator screenshot.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: Preserve the verified IPA/TIPA delivery while externalizing the current hosted Simulator rerun as needs-verification.
- Active slice: Final evidence, ADR/baseline sync, and temporary CI ref cleanup.
- Completed todos:
- Final snapshot ac5e6ff passed package run 30398876901 and produced validated IPA/TIPA artifacts.
- Validated hashes, ZIP integrity, package metadata, signatures, artifact identity, executable fingerprint, and absence of retired payloads; copied matching artifacts to dist and the Windows desktop.
- Retained executable loopback rendering evidence from runs 30388203550, 30389904599, and 30389908011; run 30389904599 visibly rendered Vulpra Engine Ready and completed the page.
- Ran three bounded formal Simulator retries 30393594180, 30395172252, and 30397230869; all built, passed seven native tests, kept the App alive, and produced no crash, but none closed the hosted rendering gate.
- Evidence refs:
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30398876901
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30389904599
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30397230869
- dist/SHA256SUMS
- /mnt/c/Users/niting/Desktop/Vulpra/SHA256SUMS
- Blocked on: The current GitHub-hosted Simulator rerun is not green: run 30393594180 timed out during Simulator boot, while runs 30395172252 and 30397230869 fetched the loopback fixture but remained about:blank.
- Next step: Run a fresh hosted macOS Simulator gate after the runner/runtime drift is understood; do not claim full Simulator completion from the historical executable evidence alone.

## DriftCheckDraft

- Scope status: The final fixture/workflow calibration and package delivery stayed inside the approved independent-engine, Chinese-first UI, and IPA/TIPA scope.
- Compatibility status: com.vulpra.browser, iOS 15, iPhone/iPad, OpenIn, Codable data, build identity 0.2.0 (4), and TabManager/BrowserTab/VulpraEngineKit ownership remain preserved.
- Retirement status: GeckoView, Helper, JIT, source-build client paths, alternate artifacts, duplicate owners, and runtime fallbacks remain retired; no compatibility exception was introduced.
- New risk signals:
- The package gate is verified, but current GitHub-hosted Simulator reruns do not reproduce the earlier visible loopback page completion.
- Physical-device installation and public distribution remain outside this evidence boundary.
- Advisory decision: needs-verification
