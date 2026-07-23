# Todo Checkpoint — Vulpra-First Integration

Updated: `2026-07-23`

## TodoCheckpointDraft

- Current todo: finish the verified commit, push the integration branch, and
  build the current IPA/TIPA packages.
- Completed:
  - restored `/root/reynard-browser` to a clean read-only reference;
  - created the isolated `feature/vulpra-first-integration` worktree;
  - established Vulpra product ownership and substrate provenance gates;
  - imported only Vulpra-owned product roots and 14 audited substrate deltas;
  - repaired the fresh Xcode graph, startup, embedding, signing, and package
    contracts;
  - added the Vulpra icon and bounded high-frequency view, persistence,
    session, and thumbnail paths;
  - passed the full portable gate;
  - created ADR-0002 and the Vulpra-first portable baseline.
- Active slice: pre-push verification and diff review.
- Evidence:
  - `evidence-bundle-draft-portable-full-gate-2026-07-23.json`;
  - `docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md`;
  - `docs/provenance/substrate-deltas.tsv`.
- Blocked on: nothing.
- Next: run a fresh full gate, review the exact staged inventory, commit, push,
  and dispatch `build-ios-packages.yml`.

## ResumeStateHint

- Worktree:
  `/root/.config/aegis/worktrees/vulpra-browser/vulpra-first-integration`
- Branch: `feature/vulpra-first-integration`
- Parent plan:
  `docs/aegis/plans/2026-07-23-vulpra-first-proven-startup-integration.md`
- Unsafe assumption: GitHub compilation, package integrity, and device launch
  remain open until fresh evidence exists.

## DriftCheckDraft

- Serves original intent: yes.
- Inside compatibility boundary: yes; iOS 15, arm64, and all four Vulpra
  identities remain unchanged.
- New duplicate owner/fallback: no.
- Retirement explicit: yes; Reynard product ownership, diagnostic startup
  branches, and the fake simulator smoke owner remain retired.
- New risk: current-branch Xcode/asset/package evidence and physical-device
  launch are still open.
- Evidence decision: `continue`.

## Checkpoint Update

- Current todo: commit and push the verified integration branch, then build and verify IPA/TIPA packages
- Active slice: verified commit, push, and GitHub package build
- Completed todos:
- restored /root/reynard-browser to a clean read-only reference
- created the isolated feature/vulpra-first-integration worktree
- established Vulpra product ownership and substrate provenance gates
- imported only Vulpra-owned product roots and 14 audited substrate deltas
- repaired the fresh Xcode graph, startup, embedding, signing, and package contracts
- added the Vulpra icon and bounded high-frequency view, persistence, session, and thumbnail paths
- passed the fresh full portable pre-push gate
- created ADR-0002 and the Vulpra-first portable baseline
- Evidence refs:
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-portable-full-gate-2026-07-23.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-prepush-full-gate-2026-07-23.json
- docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md
- Blocked on: none
- Next step: commit, push, dispatch build-ios-packages.yml, and monitor to terminal success or a logged repair

## DriftCheckDraft

- Scope status: Vulpra remains the sole product owner; only the stale Phase 0 test scope was narrowed to the exact legacy Reynard paths it owns.
- Compatibility status: iOS 15, arm64, and all four Vulpra identities remain unchanged.
- Retirement status: Reynard product owners and broad false-positive bootstrap rule remain retired; no fallback or duplicate owner added.
- New risk signals:
- GitHub Xcode/package evidence and physical-device launch remain open.
- Advisory decision: continue

## Checkpoint Update

- Current todo: close durable evidence, commit and push the package-engineering result, and retain device launch as user verification
- Active slice: evidence closeout and final branch verification
- Completed todos:
- established Vulpra as the sole product owner with audited substrate provenance
- integrated the Vulpra-owned client, fresh Xcode graph, runtime shell, release packaging, and app icon
- passed the full portable gate and repaired the stale Phase 0 false-positive rule
- repaired the Bootstrap shallow-checkout failure at the workflow owner and passed run 29961240711
- built the exact runtime-backed IPA/TIPA packages successfully in run 29961256526
- verified package hashes, zip structure, bundle IDs, iOS 15 arm64 compatibility, engine, extensions, signatures, and entitlements
- atomically replaced the Windows desktop test packages and verified them in place
- Evidence refs:
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-github-runs-5f49f3c-2026-07-23.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-package-verification-29961256526.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-windows-desktop-delivery-29961256526.json
- Blocked on: none
- Next step: update the portable baseline and plan status, bundle/check the Aegis workspace, run final gates, commit/push evidence closeout, and monitor the final Bootstrap run

## DriftCheckDraft

- Scope status: Package engineering remains Vulpra-first; no Reynard Client, Resources, Xcode project, stores, or compatibility owner was introduced.
- Compatibility status: GitHub package evidence verifies iOS 15.0 arm64 configuration and all four Vulpra bundle identities; physical-device behavior remains external.
- Retirement status: The broad Phase 0 false-positive rule and shallow Bootstrap checkout were retired; no runtime fallback or duplicate product owner was added.
- New risk signals:
- Physical-device installation/launch and performance evidence remain needs-user-verification.
- Advisory decision: continue

## Checkpoint Update

- Current todo: commit and push the evidence closeout, then monitor the final Bootstrap run
- Active slice: final evidence commit and remote Bootstrap confirmation
- Completed todos:
- completed Vulpra-first product integration and complexity governance
- passed local portable, ownership, runtime-shell, browser, workflow, plist, and workspace gates
- passed GitHub Bootstrap Core run 29961240711
- passed GitHub Xcode package run 29961256526 using the exact runtime artifact
- verified IPA/TIPA identity, iOS 15 arm64 structure, engine, extensions, signatures, entitlements, hashes, and archive integrity
- atomically replaced and reverified the Windows desktop packages
- updated the baseline, plan checklist, evidence bundle, proof bundle, and reflection
- Evidence refs:
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-final-local-closeout-gate-2026-07-23.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-package-verification-29961256526.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-windows-desktop-delivery-29961256526.json
- Blocked on: none
- Next step: commit and push documentation/evidence closeout, monitor the automatically triggered Bootstrap run to terminal success, then hand off the TrollStore package for physical-device verification

## DriftCheckDraft

- Scope status: All planned integration, package, verification, and desktop-delivery work is complete inside the Vulpra-first boundary.
- Compatibility status: GitHub and local package evidence verify iOS 15.0 arm64 configuration and all four Vulpra identities; device runtime remains unobserved.
- Retirement status: Reynard product ownership, diagnostic startup branches, fake simulator smoke ownership, the broad Phase 0 false-positive rule, and shallow Bootstrap checkout are retired.
- New risk signals:
- Physical-device launch and performance remain needs-user-verification; no package-engineering blocker remains.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: obtain physical-device launch result for startup-repair package 29981831300
- Active slice: physical-device verification of direct Gecko startup
- Completed todos:
- falsified GeckoView/Helper runpath hypothesis with a locally repacked device test
- identified startup JIT activation as the only build-time launch difference in the last bootable run logs
- removed RuntimeJITCoordinator from App/main.swift and passed the full portable gate
- built and verified run 29981831300 and replaced the Windows desktop packages
- Evidence refs:
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-startup-root-cause-2026-07-23.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-startup-repair-29981831300.json
- docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-windows-desktop-delivery-29981831300.json
- Blocked on: user installation and launch result on physical iOS device
- Next step: install Vulpra-Fixed-29981831300/Vulpra-TrollStore.tipa and report whether it remains open

## DriftCheckDraft

- Scope status: Vulpra remains the sole product owner; the repair removes one startup path and adds no product fallback.
- Compatibility status: iOS 15.0, arm64, bundle identities, engine artifact, UI, persistence, and package shape remain unchanged.
- Retirement status: Startup activation of RuntimeJITCoordinator is retired; its staged source remains inactive until page-process/JIT behavior is separately device-verified.
- New risk signals:
- Physical-device launch and Gecko page-process behavior for run 29981831300 remain unverified.
- Advisory decision: needs-verification
