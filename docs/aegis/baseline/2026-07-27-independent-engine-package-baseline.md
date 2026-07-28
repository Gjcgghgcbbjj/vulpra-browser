# Vulpra Independent Engine Package Baseline

Date: `2026-07-27`
Last amended: `2026-07-29`
Status: `package-verified-simulator-needs-verification`
ArchitectureReviewRequired: `yes`
Independent engine cutover: `complete`
Historical loopback executable evidence: `available`
Current hosted Simulator gate: `needs-verification`
Physical-device validation: `needs-verification`

## Evidence Boundary

This snapshot records the completed dependency direction:

```text
Precompiled Gecko Runtime -> VulpraEngineKit -> Vulpra App
```

Final Xcode archive/package run `30398876901` passed from snapshot
`ac5e6ffddcd135a540af5fdbc49ee14a150527b7`. The workflow and local validation
proved the standard IPA and TrollStore TIPA, including ZIP integrity, 2671-file
payloads, bundle/version/UI identity, pinned engine artifact, distribution
profile and signatures, executable fingerprint, and absence of retired
GeckoView/Helper payloads. Matching artifacts are present in `dist/` and on the
Windows desktop.

Historical loopback runs `30388203550`, `30389904599`, and `30389908011`
provide executable rendering evidence across iOS 26.5, 26.4, and 26.2. In run
`30389904599` at snapshot `f52adf04e2fdb49c37a0f0584d88f71c51782e67`,
the fixture received a second `GET /` with status 200, the App logged the
loopback engine location and successful page completion, multiple Engine
Process connections were active, the App survived without a crash, and the
screenshot visibly rendered `Vulpra Engine Ready`. The recalibrated
`height / 12 ..< height / 8` content band contains 12266 dark pixels; the
corresponding blank screenshot contains zero. Runtime/package-owned paths are
identical between `f52adf04` and `ac5e6ff`; only Simulator workflow/test
calibration differs in the compared validation surface. These runs retain an
overall workflow conclusion of failure because their earlier pixel band missed
the visible heading, so they are executable evidence rather than a green final
gate.

Three formal hosted reruns did not close that gate. Run `30393594180` timed out
during migration/boot of the second iOS 26.5 Simulator. Runs `30395172252` and
`30397230869` pinned iOS 26.4 and received the loopback `GET /` response, but
the engine remained `about:blank` and the screenshot content band stayed at
zero. All three builds succeeded, all seven native EngineKit tests passed, the
App stayed alive, and no crash was produced. After the bounded three workflow
adjustments, the current GitHub-hosted Simulator result is therefore
`needs-verification`, not passed.

## Compatibility And Products

- Bundle identity: `com.vulpra.browser`
- Deployment target: iOS `15.0`
- Architecture: `arm64`
- Device families: iPhone and iPad
- Products: Vulpra app, VulpraEngineKit framework, Vulpra Engine Process
  extension, and OpenIn extension
- Preserved state: existing Codable tab/settings/library data; private tabs
  remain excluded from restoration
- Distribution outputs: standard IPA and TrollStore TIPA
- Installed package identity: `0.2.0 (4)`, Chinese development region
  `zh-Hans`, and UI fingerprint `porcelain-zh-v4-20260728` in both
  `Info.plist` and the App executable
- `Vulpra.ipa` SHA-256:
  `c61435d2bd196cc49ec9cf054b318191a12d7fa7944c8b02e2bba7f0a53f553b`
- `Vulpra-TrollStore.tipa` SHA-256:
  `2228d83ba84feee717fccf5704110b9b4030b5a1cb0edd1458952b8aa1de5484`

No user-data deletion or migration was introduced.

## Current Ownership

- `VulpraEngineKit` is the sole App-facing engine adapter and owns runtime,
  session, typed events/features, ABI bridging, command serialization, and
  native engine views.
- Runtime and session mutable state are `@MainActor` isolated; native
  `Vulpra:RuntimeReady` is the sole ready transition. App composition injects
  the public `EngineRuntime` protocol through the browser/tab owners.
- `VulpraEngineProcess` is the sole child-process host and transports the
  native `NSXPCListenerEndpoint` through ExtensionKit/XPC, reclaiming each
  connection and extension context on interruption or invalidation.
- `TabManager` remains the sole tab collection/selection owner.
- `BrowserTab` remains the sole per-tab model/session owner.
- GitHub Actions is the macOS build, simulator evidence, and package producer.
- The precompiled v4 artifact is the only compatibility carrier.

## Artifact And Signing Boundary

- Artifact ID:
  `vulpra-gecko-ios-arm64-v4-fb98d5119a6c3e53ea96015a78a19269fef447a88fdf37a14b1bf0bc63e91ba9`
- Artifact build: Xcode build `17E202`, SDK build `23E252`, `iphoneos`, `arm64`
- Normal builds restore and verify this artifact; they do not fetch Gecko
  source or rebuild it.
- `Configuration/engine-artifact-lock.json` pins the release tag, archive
  SHA-256, artifact ID, and source commit used by simulator and package runs.
- ABI headers define synchronous borrowed-value lifetimes, and callers keep
  bridged Foundation values alive for the complete ABI call.
- Package validation compares resources and licenses byte-for-byte.
- Runtime Mach-O validation compares artifact-backed non-signature load
  commands and section content, while validating final architecture and
  required signatures separately.

## Retired Paths

The active graph and repository no longer contain GeckoView adapter sources,
the old Helper, RuntimeJITCoordinator, ptrace/JIT producers, Gecko patches,
Gecko source-build tools/workflows, Firefox/idevice gitlinks, or a runtime
fallback. Historical provenance documents remain documentation only.

This is `delete-first` internal code retirement. There is no compatibility
exception and no persistent-state deletion.

## Verification Evidence

```text
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
python3 Tests/IndependentEngine/test_cutover_readiness.py --require-cutover
GitHub package run 30398876901
GitHub historical loopback executable run 30389904599
GitHub hosted Simulator reruns 30393594180, 30395172252, 30397230869
sha256sum -c dist/SHA256SUMS
unzip -t Vulpra.ipa and Vulpra-TrollStore.tipa
git diff --check
```

## Remaining External Validation

- Installation and launch on physical iOS 15.8 and iOS 16.7 devices
- A fresh green GitHub-hosted Simulator navigation run from the final source
  and workflow snapshot
- Physical-device OpenIn, permission, download, background-media, memory, and
  60/120 Hz performance evidence
- Public distribution and third-party notice review

The IPA/TIPA package boundary is verified. Historical visible Simulator
rendering remains valid executable evidence, but it does not substitute for the
current hosted gate. Physical-device and public-release checks remain separate
external gates.
