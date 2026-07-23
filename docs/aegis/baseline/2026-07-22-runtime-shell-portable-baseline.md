# Vulpra Runtime Shell Portable Baseline

Date: `2026-07-22`
Status: `runtime-shell-portable-verified`
ArchitectureReviewRequired: `yes`
Phase 1 overall: `needs-verification`

## Evidence boundary

This snapshot records Phase 1A source, ownership, build-contract, and Linux
portable evidence at implementation snapshot commit
`1e3f64c513910dcc2c0b854d6c6a18b9f0333b27`. It does not claim that Xcode has
compiled the project, that Gecko or idevice were rebuilt, that an IPA exists,
or that a physical device has launched the app.

- Import manifest rows: `345`
- Import manifest SHA-256: `c57545ed2f745e02c52a9adec7ea607d59d55b3220a8b4d52c4ce79ef58253c6`
- Xcode graph SHA-256: `deb0a92db9c71c5af443ef9d34c693caa10698f2ede575018571cec882ab525c`
- Gecko artifact contract SHA-256: `d1e38d64a4f88f1ab90c52abc5f2ad1b488d6f4a0bc4ef775e61bef7660e4b02`
- Portable runner SHA-256: `54feedf3a9a6d36b7a5d192616d8595a24aaca2e634c4def65bd29966d9f5d5c`

## Current target and compatibility graph

- Vulpra — `com.apple.product-type.application` — `com.vulpra.browser`
- GeckoView — `com.apple.product-type.framework` — `com.vulpra.browser.geckoview`
- Vulpra Helper — `com.apple.product-type.app-extension` — `com.vulpra.browser.helper`
- OpenIn — `com.apple.product-type.app-extension` — `com.vulpra.browser.open-in`
- Deployment target: `15.0`
- Architecture: `arm64`
- Device families: iPhone and iPad
- Mac Catalyst, Designed for iPhone/iPad on Mac, and visionOS: disabled
- Signing team/profile in Git: absent

`Vulpra` depends on and embeds all three supporting products. The project uses
objectVersion 77 synchronized groups and five small xcconfig owners. Current
Xcode semantic acceptance remains a Mac gate.

## Runtime ownership

- Gecko `AppShellDelegate` remains the sole application delegate.
- `App/Info.plist` statically creates the one `SceneDelegate`.
- `RuntimeShellViewController` owns one temporary smoke `GeckoSession`, embeds
  its engine view, and loads `https://example.com/` when no valid input exists.
- `RuntimeURLRouter` is the only `http`/`https` and `vulpra://open?url=` parser.
- `RuntimeJITCoordinator` is the only product JIT readiness owner. It uses one
  attach queue, one state queue, a 4.5-second deadline, atomic pending removal,
  and at-most-once reporting with `hasTXMSupport = false`.
- OpenIn uses one public `NSExtensionContext.open` path and one MainActor finish
  gate. No private/responder fallback is installed.

No tabs, stores, persistence, settings, migration, old-data compatibility,
address bar, final browser chrome, or inherited client owner is present.

## Artifact and package contracts

- Gecko dist: `Vendor/firefox/obj-aarch64-apple-ios/dist`
- idevice archive: `.build/idevice/aarch64-apple-ios/release/libidevice_ffi.a`
- archives and packages: `dist/`
- Gecko artifact format: `v3`, keyed by Xcode build, iPhoneOS SDK build,
  Firefox commit/release, patch hashes, and build/contract scripts
- Required Gecko payload: `IOSBootstrap.h`, `GeckoViewSwiftSupport.h`, `XUL`,
  at least one dylib, include tree, and default theme
- Package outputs defined but not produced: `Vulpra.ipa` and
  `Vulpra-TrollStore.tipa`, plus deterministic `SHA256SUMS`

Normal Xcode builds verify artifacts and never fetch or rebuild them. Packaging
works on copied staging trees and must not mutate the xcarchive.

## Portable verification evidence

The following passed on Linux/WSL2:

```text
./Tests/Bootstrap/test-repository-shape.sh
./Tests/Bootstrap/test-repository-shape-nested-parent.sh
./Tests/Bootstrap/test-import-boundary.sh
./Tests/Bootstrap/test-gecko-substrate.sh
./Tests/Bootstrap/test-active-identity.sh
./Tests/Bootstrap/test-jit-substrate.sh
./Tests/RuntimeShell/run-portable.sh
python /root/.codex/aegis/scripts/aegis-workspace.py check --root .
git diff --check
```

The portable runner covers project graph, product metadata, runtime shell, JIT,
OpenIn, runtime artifacts, deterministic packaging, Gecko artifact fixtures,
shell syntax, plist/XML parsing, and diff whitespace. Ubuntu CI installs no
packages and checks out no submodules.

## Efficiency and complexity snapshot

Implementation snapshot tracked files: `433`.

- Vendor/Patches: 263 files, 26,526 lines, 928,012 bytes
- Runtime substrate: 74 files, 6,478 lines, 215,204 bytes
- Project/config/app: 18 files, 959 lines, 47,595 bytes
- Tests/tools/CI: 34 files, 3,389 lines, 132,469 bytes
- Documentation: 35 files, 4,173 lines, 257,136 bytes
- New project graph: 259 lines
- Runtime owners: main 7, SceneDelegate 48, shell 95, URL router 43, JIT 142
- OpenIn owner: 104 lines
- Release scripts: 18/20/35/77 lines
- Maintained files at or above 800 lines: only the retired 969-line Phase 0 plan
- Third-party package-manager dependencies added: none
- Vulpra image/asset payload added: none
- Generated Gecko/archive/IPA committed: none

Performance remains outside Linux evidence:

- Chrome-interactive startup median/p95: `needs-verification`
- First-Gecko-session-ready median/p95: `needs-verification`
- Steady-state/per-tab memory median/p95: `needs-verification`
- 60/120 Hz frame p95 and hitch rate: `needs-verification`

## Explicit Phase 1B gates

- Xcode compilation: `needs-verification`
- Gecko rebuild: `needs-verification`
- idevice archive production: `needs-verification`
- IPA/TIPA creation: `needs-verification`
- entitlement installation and ldid signing: `needs-verification`
- OpenIn device behavior: `needs-verification`
- JIT child attachment/readiness timing: `needs-verification`
- iOS 15.8 launch: `needs-verification`
- iOS 16.7 launch: `needs-verification`
- startup/memory/frame performance: `needs-verification`
- public distribution clearance and idevice notices: blocked

## Mac continuation

Run from the repository root on a supported Mac:

```text
./Tools/Runtime/check-macos-prerequisites.sh
./Tools/Runtime/build-runtime-substrate.sh
./Tools/Release/build-app.sh
./Tools/Release/create-ipa.sh
```

A failure must repair the canonical graph/producer owner. It does not authorize
copying the old project/client or adding private OpenIn/JIT fallback paths.
