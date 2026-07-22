# Evidence — Vulpra-First Integration

## Initial boundary evidence

- `/root/reynard-browser` is clean at `3dea55d` and remains evidence-only.
- The integration branch starts from Vulpra Phase 0 commit `6fbf6ae`.
- The Vulpra product allowlist comes from commit
  `7955722ce68f63e4f470837947cfdde385458b13`.
- Normalized comparison against audited Reynard commit
  `ef14c2997ae7dfdb44155240ec64fea3140ba9e1` found zero exact Vulpra product
  file matches. Seven high-similarity signals were short platform contracts,
  protocol adapters, or CI structure and were individually reviewed.

## Ownership and substrate evidence

- Product roots contain no active `Reynard`, `com.minh-ton`, `BrowserCore`, or
  `StabilityCore` identity.
- Reynard Client, Resources, Xcode project, old stores, old-data migration,
  generated binaries, diagnostic IPA workflow, and fake simulator label smoke
  workflow were not imported.
- `docs/provenance/substrate-deltas.tsv` records 14 maintained derived-file
  changes with baseline/current hashes and reasons.
- The current runtime artifact candidate remains reusable only by exact key.

## Product and efficiency evidence

- 35 Vulpra product Swift files, 2,693 Swift lines.
- Largest product owners: BrowserViewController 292 lines, TabManager 199,
  BrowserTab 187.
- No product package-manager or third-party UI/animation/analytics dependency.
- One opaque RGB 1024 x 1024 Vulpra icon, 126,581 bytes.
- Live background sessions, restored tabs, thumbnails, bookmarks, history,
  downloads, and permissions use explicit bounds.
- Gecko metadata callbacks no longer detach/re-attach the same engine view.
- Failed page loads clear the success marker before history evaluation.

## Portable full gate

Fresh command exit: `0` on `2026-07-23`.

Covered:

- all Bootstrap ownership/substrate/identity/JIT checks;
- Ownership, RuntimeShell, and Browser portable runners;
- deterministic release packaging fixture;
- every shell script under `Tools/` and `Tests/` with an available parser;
- every Python test module byte-compiled;
- plist/XML parsing and `git diff --check`.

Uncovered:

- four zsh producer scripts because zsh is unavailable on this Linux host;
- Swift/UIKit, Objective-C, asset-catalog, linker, archive, ldid, and device
  behavior until the GitHub and physical-device gates run.

Machine-readable evidence:
`evidence-bundle-draft-portable-full-gate-2026-07-23.json`.

## EvidenceBundleDraft

- Artifact key: prepush-full-gate-2026-07-23
- Type: command-output
- Source: full Bootstrap, Ownership, RuntimeShell, Browser, shell syntax, Python byte-compile, workflow YAML, plist, git diff, and legacy-path regression probe
- Summary: Fresh pre-push gate passed after narrowing a stale Phase 0 check to reject only legacy Reynard product paths; all Vulpra product ownership gates remain active.
- Verifier: root Codex session, fresh command exit 0

## EvidenceBundleDraft

- Artifact key: github-runs-5f49f3c-2026-07-23
- Type: workflow-run
- Source: Bootstrap Core run 29961240711 and Build Vulpra IPA and TIPA run 29961256526 at commit 5f49f3cdd62221b1bc9bb5be149b5c1be4922491
- Summary: Both GitHub Actions runs completed successfully. Xcode 26.4.1 build 17E202, iPhoneOS SDK 23E252, exact runtime key b170cbc0..., archive and package creation all passed.
- Verifier: GitHub Actions terminal conclusions read through gh CLI

## EvidenceBundleDraft

- Artifact key: package-verification-29961256526
- Type: artifact-verification
- Source: .build/deliveries/29961256526/package-verification.json and GitHub artifact 8546130042
- Summary: Artifact zip and both packages passed checksum and zip integrity checks; four bundle IDs, iOS 15.0, arm64, Gecko/XUL/dylibs, Helper/OpenIn, executable modes, 15 signed Mach-O targets, ptrace_jit, and private entitlements were verified.
- Verifier: local deterministic package inspection, exit 0

## EvidenceBundleDraft

- Artifact key: windows-desktop-delivery-29961256526
- Type: delivery
- Source: /mnt/c/Users/niting/Desktop/Vulpra-Fixed-29944288468
- Summary: Atomically replaced Vulpra.ipa, Vulpra-TrollStore.tipa, and SHA256SUMS; post-replacement checksum and archive integrity checks passed. BUILD-INFO.txt records run, commit, artifact, iOS, and architecture.
- Verifier: local Windows-mounted desktop verification, exit 0

## EvidenceBundleDraft

- Artifact key: final-local-closeout-gate-2026-07-23
- Type: command-output
- Source: full portable regression suite, shell/Python/YAML/plist validation, Aegis workspace check, git diff check, and maintained-file pressure report
- Summary: Final local closeout gate passed. Product remains 35 Swift files with no owner at 350 lines; the only >=800 text owner is the retired Phase 0 plan, while the PNG line count is a binary scan artifact.
- Verifier: root Codex session, fresh command exit 0
