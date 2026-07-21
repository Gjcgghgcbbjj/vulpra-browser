# Vulpra Modern Browser Evidence

Evidence is appended after each implementation slice. Linux portable checks are authoritative only for source/contracts. Mac and device claims require their respective environments.

## Portable client evidence

- `./Tests/RuntimeShell/run-portable.sh` passed after browser-root retirement.
- `./Tests/Browser/run-portable.sh` passed with runtime workflow, package workflow, and 35-file client contract checks.
- All maintained Vulpra Swift owner files remain below 350 lines.
- New package dependencies: zero.
- Runtime build: GitHub run `29856427149` succeeded; runtime artifact ID
  `8512456239`, size `280583298` bytes.

## GitHub Xcode and package evidence

- Final package source commit: `88246d016124bd2f4915109ade2cc39822474b6b`.
- GitHub package run `29877342036` succeeded in 4m12s.
- Xcode graph validation, application archive, IPA/TIPA creation, package upload,
  and log upload all completed successfully.
- Package artifact: `vulpra-ios-test-29877342036`, artifact ID `8513539079`,
  size `197621073` bytes.
- The final repair sequence removed framework bridging headers, installed Gecko
  support headers as framework module headers, isolated App/Helper header
  search paths, updated Xcode 26 Swift APIs, made the Gecko payload phase
  executable, and completed Helper bundle metadata.

## Downloaded package evidence

- `/root/Desktop/Vulpra-Test/Vulpra.ipa`: `98200308` bytes.
- `/root/Desktop/Vulpra-Test/Vulpra-TrollStore.tipa`: `101460684` bytes.
- `sha256sum -c SHA256SUMS`: both files `OK`.
- `unzip -t`: no errors for IPA or TIPA.
- IPA metadata: `com.vulpra.browser`, `0.1.0 (1)`, minimum OS `15.0`,
  `CADisableMinimumFrameDurationOnPhone = true`.

## Complexity evidence

- App Swift files: `35`; total App Swift lines: `2584`.
- Largest App Swift owner: `BrowserViewController.swift`, `270` lines.
- App Swift owners at or above 350 lines: `0`.
- New third-party package dependencies: `0`.
- IPA compressed/uncompressed size: about `94 MiB` / `287 MiB`; most payload is
  the Gecko runtime rather than client feature code.

## Uncovered evidence

- No physical iOS 15.8 or 16.7 install/launch result.
- No device JIT, OpenIn, frame pacing, startup, memory, or thermal measurements.
- No public-distribution clearance claim.

## EvidenceBundleDraft

- Artifact key: github-runtime-29856427149
- Type: github-workflow
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/29856427149
- Summary: Runtime substrate workflow succeeded and uploaded exact keyed Gecko/idevice artifact 8512456239.
- Verifier: GitHub Actions conclusion success and artifact metadata query.

## EvidenceBundleDraft

- Artifact key: github-package-29877342036
- Type: github-workflow
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/29877342036
- Summary: Xcode archive, IPA/TIPA creation, package upload, and log upload succeeded.
- Verifier: GitHub Actions conclusion success and artifact 8513539079.

## EvidenceBundleDraft

- Artifact key: desktop-package-integrity
- Type: local-verification
- Source: /root/Desktop/Vulpra-Test
- Summary: Published SHA256SUMS matched IPA/TIPA and unzip integrity passed for both packages.
- Verifier: sha256sum -c SHA256SUMS and unzip -t.
