# Vulpra Independent Engine Package Baseline

Date: `2026-07-27`
Last amended: `2026-08-09`
Status: `package-verified-simulator-20-20`
ArchitectureReviewRequired: `yes`
Independent engine cutover: `complete-v5-r0.3`
Historical loopback executable evidence: `available`
Current hosted Simulator gate: `verified-20-20`
Final snapshot: `5942698` (real-device GPU entitlements + verified RDD timeout + termination diagnosis)
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

## Gecko v5 R0 Cutover (2026-08-08)

The v4/vtool simulator derivation is retired. Device and Simulator kernels are
independent native builds of Gecko v5 (`vulpra-engine-v5-r0.3-candidate`,
Firefox source `27b462b22705a8860f7ab0d33aa5b4b658ae5932`, patch set SHA-256
`5515f9eae2973b6c545243ae8c11bb22179660ebd97419fb56211f7c6ac5a1e1`).

- Repeat-verified producer pair: runs `30598301958` (selected) and
  `30598347174` (repeat), both compiling native device + Simulator kernels
  with byte-identical repeat-build Mach-O identity.
- Immutable promotion: run `30613021710` (`vulpra-engine-v5-r0.3-candidate`).
- Hosted Simulator R0 gate (final snapshot): single-attempt run
  `31288215667` and 20-attempt run `31288670337` at HEAD `8aea481`
  (final docs commit `5942698`), **20/20 attempts passed**: 161 child
  launches requested / 161 connected / 0 failed / 0 open,
  p95 load-to-complete `1623ms`, max `3111ms`
  (bounds: p95<=15000ms, max<=30000ms), deliveryMethod
  `gate-http-dispatch` with `gateDispatchStatus=0` on all attempts.
- RDD startup-timeout pref delivery verified: `rdd-timeout-pref-set
  verified pref=media.rdd-process.startup_timeout_ms expected=30000
  isSet=true` on 76 evidence lines, 0 isSet=false/timed-out (the 5 s
  default was the earlier failure mechanism; 30 s user-branch pref is now
  confirmed delivered by the packaged GeckoViewPreferences handler).
- Final package: run `31294387233` at HEAD `5942698`, IPA/TIPA validated
  with SHA-256 below (pending completion).
- The Simulator R0 gate measures warm-engine navigation lifecycle stability
  on software WebRender; physical-device Metal/WebRender, JIT, OpenIn,
  and App Store distribution eligibility remain external gates.

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
- `Vulpra.ipa` SHA-256 (run `31244000908`):
  `0971a3ad2744ebfb8881021ceb08f7d62dd8a762997ba245fa3c115bbaf039fc`
- `Vulpra-TrollStore.tipa` SHA-256 (run `31244000908`):
  `5adc09ba48cb757a9814c13250d21c935fdac213c033cb8e0834d32f6f351802`

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
- The precompiled v5 artifact pair is the only compatibility carrier; v4/vtool paths are retired.

## Artifact And Signing Boundary

- Device artifact ID (lock `engine-artifact-lock.json`):
  `vulpra-gecko-ios-arm64-v5-5fe3932ab145e6ce1239c33d056583ac6ee9882165a387d8ea1d97cc8964d0f1`
  (archive SHA-256 `93c40859e5f12ef62ab58871abdb8b6ce480321879417a8364b87811dc4f4140`)
- Simulator artifact ID:
  `vulpra-gecko-ios-simulator-native-arm64-v5-839950aff3edeb2d97223fe4590315757bf3818eba875dbf07502c789031999c`
  (archive SHA-256 `c544df105bc8971481948e9e9dba8d4bf86c61900d9d3006bc65df578aaa9e0d`)
- Artifact build: Xcode build `17E202`, SDK build `23E252`, deployment target
  `15.0`, built-in reproducible time `20260713164006` (not CI wall time)
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
python3 Tests/IndependentEngine/test_cutover_readiness.py --require-r0-complete  (cutover-ready)
./Tests/IndependentEngine/run-portable.sh  (14/14)
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
GitHub engine producer pair 30598301958 + 30598347174 (repeat compile verified)
GitHub promotion run 30613021710
GitHub hosted Simulator R0 gate 31288670337 (20/20, final snapshot)
GitHub final package run 31294387233 (IPA/TIPA + SHA-256, final snapshot)
sha256sum -c dist/SHA256SUMS
unzip -t Vulpra.ipa and Vulpra-TrollStore.tipa
git diff --check
```

## Remaining External Validation

- Installation and launch on physical iOS 15.8 and iOS 16.7 devices
- Physical-device OpenIn, permission, download, background-media, memory, and
  60/120 Hz performance evidence
- Public distribution and third-party notice review

The IPA/TIPA package boundary is verified. Historical visible Simulator
rendering remains valid executable evidence, but it does not substitute for the
current hosted gate. Physical-device and public-release checks remain separate
external gates.
