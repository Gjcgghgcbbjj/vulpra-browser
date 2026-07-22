# Vulpra-First Portable Integration Baseline

Date: `2026-07-23`
Status: `vulpra-first-package-verified`
ArchitectureReviewRequired: `yes`
Current GitHub package gate: `verified` in run `29961256526`
Physical-device launch gate: `needs-verification`

## Product / requirement boundary

Vulpra is the sole product owner. The current integration is built from the
clean Vulpra repository history and imports Vulpra-authored product files by
allowlist. Reynard remains read-only startup-contract evidence and is not a
source, resource, project, data, or release dependency.

The current snapshot verifies the Vulpra-first integration plan. It does not
upgrade the entire modern-browser roadmap to accepted: provider-backed Phase 3
features and remaining Phase 2/2D depth still require their own implementation
and device evidence.

Durable rationale: `docs/aegis/adr/ADR-0002-vulpra-first-product-integration.md`.

## Snapshot identifiers

- Branch: `feature/vulpra-first-integration`
- Verified package commit:
  `5f49f3cdd62221b1bc9bb5be149b5c1be4922491`
- Clean integration base: `6fbf6ae`
- Vulpra product source donor: `7955722ce68f63e4f470837947cfdde385458b13`
- Read-only boot contract reference: Reynard `3dea55d`
- Import manifest rows: `345`
- Import manifest SHA-256:
  `50447cfb3ab0b6d62a8dcd2f1d69efa6568d9a714d37121ce6c50856ffc9567d`
- Maintained substrate delta rows: `14`
- Substrate delta manifest SHA-256:
  `2a384a0ae1823c8cfb638b3e90e73efc27deb831956ba940aaa59acad13983cf`
- Xcode graph SHA-256:
  `983ad6342bf39a7a481a880f79b23c2afa54ac4bc38cb12bcdc3f9bfcd88d901`
- App icon SHA-256:
  `545327dd3d1d3c6ad351f47e2b35f31444733841d48ac38bc49cdcee4869fe14`

## Canonical owner map

Vulpra product owners:

- `App/`: lifecycle, browser composition, tabs, UI, features, and small
  feature-owned Codable stores;
- `Configuration/`: target build settings;
- `Extensions/OpenIn/`: public share-to-Vulpra handoff;
- `Vulpra.xcodeproj/`: fresh four-target graph and shared scheme;
- `Tools/Runtime/` and `Tools/Release/`: Vulpra runtime orchestration and
  deterministic package production;
- `Tests/Browser/`, `Tests/RuntimeShell/`, and `Tests/Ownership/`: executable
  product boundaries;
- `.github/workflows/build-*.yml`: GitHub Mac producer orchestration.

Derived substrate owners:

- `Extensions/GeckoView/` and `Extensions/Helper/`: Gecko session/process
  bridging;
- `Modules/VulpraRuntime/`: low-level JIT/native support;
- `Patches/`, `Tools/Build/`, `Tools/Gecko/`, and `Vendor/`: pinned engine and
  producer substrate.

Historical headers inside derived roots remain provenance. Product roots are
machine-rejected if old Reynard identity, client roots, resources, generated
binaries, or imported-substrate classification appears.

## Target and compatibility graph

- Vulpra application: `com.vulpra.browser`
- GeckoView framework: `com.vulpra.browser.geckoview`
- Vulpra Helper extension: `com.vulpra.browser.helper`
- OpenIn extension: `com.vulpra.browser.open-in`
- Deployment target: iOS `15.0`
- Architecture: `arm64`
- Device families: iPhone and iPad
- Mac Catalyst, Designed for iPhone/iPad on Mac, and visionOS: disabled
- Hard-coded signing team/profile: absent

The app embeds GeckoView, Helper, and OpenIn. Startup is one minimal path:
start `RuntimeJITCoordinator`, enter `GeckoRuntime.main`, and let the static
scene manifest instantiate the Vulpra `SceneDelegate`.

## Integrated client state

- 35 Vulpra product Swift files and 2,693 Swift lines;
- largest product owner: `BrowserViewController.swift`, 292 lines;
- next largest owners: `TabManager.swift`, 199 lines, and
  `BrowserTab.swift`, 187 lines;
- no CocoaPods, Swift Package Manager, third-party UI, animation, analytics,
  advertising, or remote-content SDK;
- one 1024 x 1024 opaque RGB app icon, 126,581 bytes;
- background live Gecko sessions limited to six in addition to the selected
  tab;
- restored normal tabs limited to 100 and cached thumbnails limited to 12;
- bookmark/history/download/permission stores have explicit bounds;
- metadata and download persistence are throttled;
- repeated Gecko metadata callbacks no longer detach and reattach the same
  engine view.

## Runtime artifact boundary

The current exact reusable device runtime candidate is:

```text
vulpra-runtime-substrate-v1-b170cbc0a490f9be2332721fc82540704f677d8f8bb352c6d9bf68ee81cd43fe
artifact ID: 8512456239
artifact size: 280,583,298 bytes
```

It may be restored only when `runtime-substrate-key.sh` resolves the same name
under the selected Xcode and iPhoneOS SDK builds. A mismatch requires a runtime
rebuild; it never permits a stale runtime or a simulator runtime in a device
package.

## Portable verification evidence

The following completed successfully on the Linux/WSL host on `2026-07-23`:

```text
./Tests/Bootstrap/test-repository-shape.sh
./Tests/Bootstrap/test-repository-shape-nested-parent.sh
./Tests/Bootstrap/test-import-boundary.sh
./Tests/Bootstrap/test-gecko-substrate.sh
./Tests/Bootstrap/test-active-identity.sh
./Tests/Bootstrap/test-jit-substrate.sh
./Tests/Ownership/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 byte-compilation of every Tests/*.py file
git diff --check
```

The four zsh Gecko producer scripts could not be parsed because zsh is absent
on this host; the portable runners report that skip explicitly.

Fresh remote evidence for the verified package commit:

- Bootstrap Core run `29961240711`: `success`;
- package run `29961256526`: `success` under Xcode `26.4.1` build `17E202` and
  iPhoneOS SDK build `23E252`;
- restored exact runtime artifact name:
  `vulpra-runtime-substrate-v1-b170cbc0a490f9be2332721fc82540704f677d8f8bb352c6d9bf68ee81cd43fe`;
- installable artifact ID `8546130042`, archive size `198,414,855` bytes, and
  archive SHA-256
  `cdf716ad9eb73f31af0c73587a9a820f65f1d7ecc2b80c67ba371cbc4657622e`;
- `Vulpra.ipa`: `98,596,207` bytes, SHA-256
  `7444a53229b06869ea27cf4b38dce5cd4a8463b08f6ea45786b37e1f00b0e779`;
- `Vulpra-TrollStore.tipa`: `101,857,453` bytes, SHA-256
  `4ec90a87538cd01cf47f123f805f7ca3ba03cbc648be20cfc9b79babde28cbee`.

Local unpacked verification covered archive integrity, all four bundle IDs,
iOS `15.0`, arm64 Mach-O identity, executable modes, GeckoView, XUL, nine
top-level dylibs, Helper, OpenIn, `ptrace_jit`, 15 required ldid-signed Mach-O
targets, and embedded private entitlements.

## Complexity and size closure

- Product roots: 60 files, 301,282 bytes total; 59 text files, 3,667 lines,
  174,701 text bytes.
- `App/`: 42 files, 255,841 bytes total; 41 text files, 2,862 lines, 129,260
  text bytes.
- Runtime bridges: 74 files, 6,505 lines, 215,971 bytes.
- Tests and workflows: 24 files, 2,553 lines, 108,739 bytes.
- Project graph: 263 lines, below the 800-line budget.
- Product owners at or above 350 lines: none.
- Package-manager dependencies added: none.
- Generated Gecko, archive, IPA, TIPA, framework, or static-library outputs in
  Git: none.
- The verified TrollStore package is `3,199,653` bytes (`3.05%`) smaller than
  the replaced desktop package.
- The unpacked TrollStore app is `304,647,607` bytes: Gecko/runtime payload is
  `300,091,305` bytes (`98.50%`), while the Vulpra-owned non-engine shell is
  `4,556,302` bytes (`1.50%`).
- Raw line-oriented pressure scan also sees newline bytes inside the binary PNG
  icon; the icon is governed as a 126,581-byte resource, not a text owner.
- The only real maintained text artifact above 800 lines is the retired
  969-line Phase 0 plan; new work uses separate plans rather than growing it.

Gecko/vendor/package size remains separately governed and cannot be reported as
Vulpra client growth.

## Open evidence and acceptance boundary

- Current integration Xcode compilation: `verified` in run `29961256526`
- Asset catalog compilation and generated icon set: `verified` in run
  `29961256526`
- IPA/TIPA package creation and unpacked-bundle verification:
  `verified` from artifact `8546130042`
- iOS 15.8 and iOS 16.7 installation/launch: `needs-verification`
- Gecko page loading, Helper/JIT child readiness, OpenIn, extensions, downloads,
  permissions, restoration, and private-data behavior on device:
  `needs-verification`
- Chrome-interactive and first-session startup median/p95:
  `needs-verification`
- steady-state/per-tab memory and 60/120 Hz frame evidence:
  `needs-verification`
- public-distribution license/notices clearance: blocked outside this package
  engineering baseline

GitHub compilation and package-shape evidence are closed for commit `5f49f3c`.
The current packages were atomically delivered to
`/mnt/c/Users/niting/Desktop/Vulpra-Fixed-29944288468` and reverified in place.
Physical-device success is never inferred and requires user installation
confirmation.
