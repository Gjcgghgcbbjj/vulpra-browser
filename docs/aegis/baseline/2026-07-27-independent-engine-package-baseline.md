# Vulpra Independent Engine Package Baseline

Date: `2026-07-27`
Status: `simulator-and-package-verified`
ArchitectureReviewRequired: `yes`
Independent engine cutover: `complete`
Physical-device validation: `needs-verification`

## Evidence Boundary

This snapshot records the completed dependency direction:

```text
Precompiled Gecko Runtime -> VulpraEngineKit -> Vulpra App
```

It is supported by final Xcode archive/package run `30240301567` and visible HTTPS
simulator navigation run `30239461150`, both from snapshot
`95338aadf837906c8baa8b3f4896d8f7acdee997`. The simulator evidence contains the
Chinese Porcelain start page and rendered Example Domain page, passed a `40077`
dark-pixel content check, and passed both native EngineKit XCTest cases. The run
recorded native view attachment, successful page completion, connected Engine
Process instances, 60-second process survival, and no crash report.

Xcode 16.4 was requested again in run `30214000855`, but the current
`macos-26` runner did not contain `/Applications/Xcode_16.4.app`. This is an
environment availability gap, not a compile or runtime failure. Xcode 26.4.1
and the iOS 26.4 simulator supplied the current executable evidence.

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
- Installed package identity: `0.2.0 (2)`, Chinese development region
  `zh-Hans`, and UI fingerprint `porcelain-zh-v2-20260727` in both
  `Info.plist` and the App executable
- `Vulpra.ipa` SHA-256:
  `77dbc62795c5f2adee8f259e3e62f4f326b0590f8a4bb399af5b99cacd34063f`
- `Vulpra-TrollStore.tipa` SHA-256:
  `1d1391fc7e11a4f0091e468034e2df402b71e3dc02e6e0a36ea2ed8b527e947f`

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
GitHub simulator run 30239461150
GitHub package run 30240301567
git diff --check
```

## Remaining External Validation

- Installation and launch on physical iOS 15.8 and iOS 16.7 devices
- Physical-device OpenIn, permission, download, background-media, memory, and
  60/120 Hz performance evidence
- Public distribution and third-party notice review

These are device/product-release gates outside the verified independent-engine
source, simulator navigation, and IPA/TIPA package boundary.
