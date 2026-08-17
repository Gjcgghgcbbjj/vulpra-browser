# Vulpra Modern Browser Package Baseline

Date: `2026-07-22`
Status: `github-package-verified`
ArchitectureReviewRequired: `yes`
Phases 2A-2D: `source-and-package-complete`
Physical-device validation: `needs-verification`

## Evidence boundary

This snapshot records the implemented modern browser client, the successful
GitHub macOS runtime and package workflows, and local integrity verification of
the downloaded test packages. It does not claim launch, JIT, animation, memory,
or browsing behavior on a physical iOS device.

- Package source commit: `88246d016124bd2f4915109ade2cc39822474b6b`
- Runtime workflow: `29856427149` (`success`)
- Package workflow: `29877342036` (`success`)
- Package artifact: `vulpra-ios-test-29877342036`, artifact ID `8513539079`
- Downloaded package directory: `/root/Desktop/Vulpra-Test`
- `Vulpra.ipa` SHA-256:
  `a7bc0d1f213dfd21bab1a4687662c0b1e2f365450ed61d9aa0e2b5cf03f499f5`
- `Vulpra-TrollStore.tipa` SHA-256:
  `6f41fc1bb021b7be752f537955dddac41d7e97bd1ad2a2d9f9fdfb85f0079817`

## Current compatibility and target graph

- Deployment target: iOS `15.0`
- Architecture: `arm64`
- Device families: iPhone and iPad
- Distribution direction: TrollStore-first test packages
- Products: Vulpra app, GeckoView framework, Vulpra Helper extension, OpenIn
  extension
- Package metadata: `com.vulpra.browser`, version `0.1.0 (1)`
- ProMotion opt-in: `CADisableMinimumFrameDurationOnPhone = true`
- Mac Catalyst, Designed for iPhone/iPad on Mac, and visionOS: disabled

## Current ownership map

- `SceneDelegate` creates the one `BrowserViewController` root.
- `BrowserViewController` composes browser chrome, selected engine view, local
  feature controllers, privacy overlay, and native transitions.
- `TabManager` is the sole `BrowserTab` lifecycle and selection owner.
- `BrowserTab` owns one `GeckoSession` and its page/session state.
- Feature-specific stores own settings, bookmarks, history, downloads, site
  permissions, and tab restoration through bounded Codable persistence.
- `RuntimeJITCoordinator` remains the only child JIT readiness owner.
- GitHub Actions owns macOS runtime and IPA/TIPA build orchestration; shell
  scripts remain the canonical producers invoked by the workflows.

`RuntimeShellViewController` is deleted. No compatibility wrapper, copied old
client, duplicate tab owner, third-party UI framework, or in-package Gecko
rebuild path remains.

## Implemented client surface

- Normal/private tabs, create/close/close-others/undo/switch/restore/suspend
- Address and search resolution with local bookmark/history/tab suggestions
- Back/forward/reload/stop/progress and Safari-style bottom material chrome
- Start page, bookmarks, history, downloads, and recently closed tabs
- Find in page, desktop mode, zoom, QR scanning, sharing, and context actions
- Prompt/file-picker handling, picture in picture, and background audio
- Site permissions, privacy-data clearing, HTTPS-first, and tracking protection
- Gecko addon list/install/enable/disable/uninstall management
- iPad/landscape adaptation, Reduce Motion behavior, and 120 Hz opt-in

Phase 3 service-backed features remain excluded; there are no fake sync,
translation, cloud, or account-provider implementations.

## Runtime and package artifact boundary

- Gecko runtime artifact:
  `vulpra-runtime-substrate-v1-b170cbc0a490f9be2332721fc82540704f677d8f8bb352c6d9bf68ee81cd43fe`
- Runtime artifact ID: `8512456239`
- Runtime artifact size: `280583298` bytes
- The package workflow resolves the exact runtime identity, downloads and
  verifies it, and does not rebuild Gecko.
- The package workflow archives with Xcode `26.4.1`, creates IPA and TrollStore
  TIPA outputs, emits `SHA256SUMS`, and uploads build logs separately.
- `unzip -t` passed for both downloaded packages and `sha256sum -c` matched both
  published checksums.

## Efficiency and complexity snapshot

- App Swift files: `35`
- App Swift lines: `2584`
- Largest App Swift owner: `BrowserViewController.swift`, `270` lines
- App Swift owners at or above 350 lines: `0`
- New third-party package dependencies: `0`
- App source payload: `39` files, `124004` bytes
- Test source payload: `18` non-cache files, `81318` bytes
- IPA compressed size: `98200308` bytes
- TIPA compressed size: `101460684` bytes
- IPA uncompressed payload: `300891009` bytes across `2674` entries

Most package size is the Gecko runtime payload rather than client UI/state
code. The client remains split into bounded owners instead of one browser
controller monolith.

## Verification evidence

The following passed after the final package repair:

```text
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
git diff --check
GitHub runtime run 29856427149
GitHub package run 29877342036
(cd /root/Desktop/Vulpra-Test && sha256sum -c SHA256SUMS)
unzip -t /root/Desktop/Vulpra-Test/Vulpra.ipa
unzip -t /root/Desktop/Vulpra-Test/Vulpra-TrollStore.tipa
```

## Remaining device gates

- iOS 15.8 and iOS 16.7 installation and launch
- Main and child-process JIT readiness on device
- OpenIn extension handoff on device
- Download, permission, addon, PiP, background-audio, and private-mode behavior
- 60/120 Hz frame pacing, startup time, memory, and thermal measurements
- Public distribution clearance and third-party notice review

These are uncovered runtime/product gates, not source or package-build failures.

