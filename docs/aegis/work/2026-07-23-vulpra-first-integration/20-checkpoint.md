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
