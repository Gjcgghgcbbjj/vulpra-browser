# Vulpra Initial Baseline

Date: `2026-07-21`
Status: `substrate-import-verified`
ArchitectureReviewRequired: `yes`

## Product / Requirement Baseline

Vulpra is a new Gecko-based browser client for iOS 15 and later. The product
direction is UIKit, TrollStore-first, and independent client ownership while
retaining only the audited Gecko/iOS/JIT substrate.

Phase 0 verifies the repository and portable substrate boundary. It does not
claim that an Xcode project, app shell, IPA, signing flow, physical-device
runtime, or public release is ready.

Product non-negotiables remain:

- no inherited Reynard client, UI, persistence, resources, or old-data
  migration/fallback;
- no browser feature owner is copied merely to preserve the source layout;
- Vulpra-authored binary, resources, runtime performance, dependencies, and
  maintained complexity are budgeted separately from Gecko/vendor payload;
- iOS 15+ support remains mandatory for future app targets.

## Verified source and repository snapshot

- Audited source repository:
  <https://github.com/Gjcgghgcbbjj/reynard-browser>
- Audited source commit:
  `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`
- Verified substrate/CI snapshot commit before this closeout:
  `90018873d1b9b60078af1d2ecce6a2bfe30115aa`
- Import manifest rows: `345`
- Import manifest SHA-256:
  `5d098442dc04d3f8bc61c70ff9af569380e9242ff1bfe682d3de9c0b67f24bbb`
- Approved manifest top-level roots: `Vendor`, `Patches`, `Tools`,
  `Extensions`, `Modules`
- Firefox gitlink: `Vendor/firefox` at
  `27b462b22705a8860f7ab0d33aa5b4b658ae5932`,
  <https://github.com/mozilla-firefox/firefox>
- idevice gitlink: `Vendor/idevice` at
  `92323d1262598cfcb31aa54ef94c26bb26c5c7a0`,
  <https://github.com/jkcoxson/idevice>

The exact regular-file mapping is owned by
`docs/provenance/import-manifest.tsv`; the human-readable responsibility,
license, attribution, and falsifier boundary is owned by
`docs/provenance/substrate-boundary.md`.

## Architecture / Runtime Boundary Baseline

Verified imported responsibility groups are:

- 262 raw Gecko/iOS patches and one Firefox release metadata file;
- 8 Gecko/idevice build and artifact tools;
- 59 GeckoView/Helper bridge files;
- 15 low-level JIT/native files;
- 2 exact external gitlinks.

The active owner split is:

- Gecko and its patch set own rendering/engine substrate;
- GeckoView and Helper own process/session bridging only;
- `Modules/VulpraRuntime` owns low-level JIT/native substrate only;
- future Vulpra client plans must create new UI/domain/store owners rather than
  reviving excluded source owners.

The low-level JIT complexity split is verified: endpoint connectivity
monitoring has one 263-line owner in `JITEndpointMonitor.m`, while
`JITSupport.m` is 583 lines. No product-level JIT controller or UIKit failure
interface is present.

## Active identity baseline

No active Reynard runtime fallback is accepted. Verified Vulpra contracts
include:

- `VulpraXPCListenerEndpoint`, `VulpraHelperMain`,
  `Vulpra.ProcessBootstrap`, `VulpraExtension`, and `Vulpra Helper.appex`;
- `Vulpra:Features:*` and `vulpra-*` add-on install identifiers;
- `com.vulpra.browser.jit.enabler*`,
  `com.vulpra.browser.jit.support*`, and
  `com.vulpra.browser.jit.ddi*`;
- `Vulpra.JIT`, `VulpraDebug`, `[VULPRA_DEBUG]`, display name `Vulpra`,
  `com.vulpra.browser.jit.endpoint-monitor-failed`,
  `vulpra-download.tmp`, and `vulpra_mmap`.

Historical source-project text is limited to exact preserved provenance forms:
38 patch attribution URL lines and 67 imported file-header lines. Source paths
in the manifest are provenance and are not active target identity.

## Compatibility and exclusion baseline

Absent and forbidden unless the architecture/design is explicitly amended:

- inherited `Client`, `BrowserCore`, `StabilityCore`, and product orchestration;
- old UIKit screens, navigation, settings, failure UI, and UI tests;
- stores, persistence, schemas, old preferences/databases, and migration code;
- icons, launch assets, screenshots, localized product copy, and other old
  resources;
- source Xcode project, schemes, signing state, built products, IPA/TIPA,
  frameworks, derived data, caches, and `libidevice_ffi.a`;
- `JITController.swift` and the old JIT `Interface/` UI tree.

No old installation or user data is read, migrated, mutated, or deleted by this
repository. Discovery of a required dependency on any excluded owner falsifies
the current extraction boundary and stops the next phase for architecture
review; it does not authorize a broad copy or compatibility fallback.

## Portable verification evidence

The following commands passed on the Linux host during closeout:

```text
./Tests/Bootstrap/test-repository-shape.sh
./Tests/Bootstrap/test-repository-shape-nested-parent.sh
./Tests/Bootstrap/test-import-boundary.sh
./Tests/Bootstrap/test-gecko-substrate.sh
./Tests/Bootstrap/test-active-identity.sh
./Tests/Bootstrap/test-jit-substrate.sh
./Tools/Gecko/test-gecko-artifact.sh
find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 YAML parse of .github/workflows/bootstrap-core.yml
git diff --check
```

Additional verified facts:

- manifest target hashes match all 345 regular imported files;
- manifest targets use exactly the five approved roots;
- both gitlinks match their exact URL/commit contract;
- no excluded client/resource/Xcode/generated binary path was found;
- workflow uses `ubuntu-latest`, `actions/checkout@v4`,
  `submodules: false`, and installs no packages;
- the target repository has no configured remote.

## Efficiency and Complexity Closure

- Budget status: `within-budget` with one governed documentation pressure
  signal.
- Raw imported `Vendor/` metadata plus `Patches/`:
  263 regular files, 26,526 logical lines, 928,012 bytes.
- Active imported runtime bridges (`Modules/` plus `Extensions/`):
  74 files, 6,485 logical lines, 215,380 bytes.
- Maintained tooling/tests/CI (`Tools/`, `Tests/`, `.github/`):
  19 files, 2,184 logical lines, 81,869 bytes at the pre-closeout snapshot.
- Maintained files at or above 800 lines: the 969-line Phase 0 implementation
  plan only. It is fixed-scope evidence and retires from active execution after
  this closeout; future work uses separate plans rather than growing it.
- Largest maintained runtime owner: `JITSupport.m`, 583 lines.
- Largest maintained tool: `generate-import-manifest.py`, 437 lines.
- Largest maintained portable test after Task 8 assertions:
  `test-import-boundary.sh`, 308 lines.
- Dependencies added: no package-manager dependency. The two external gitlinks
  are audited substrate pins, not fetched by portable CI.
- Vulpra app binary delta: `0`; Vulpra product resource delta: `0`;
  committed IPA/TIPA delta: `0`; committed Gecko artifact delta: `0`.
- Chrome-interactive startup median/p95: `needs-verification`.
- First-Gecko-session-ready startup median/p95: `needs-verification`.
- Steady-state/per-tab memory median/p95: `needs-verification`.
- 60/120 Hz frame p95 and hitch rate: `needs-verification`.
- Regression versus a verified app artifact: `needs-verification`.
- Completion impact: Phase 0 portable substrate boundary is complete; runtime,
  performance, and release gates remain open.

The durable measurement protocol and dependency gate remain owned by
`docs/aegis/policies/efficiency-complexity-governance.md`.

## Missing evidence and publication blockers

Not covered by this baseline:

- macOS `zsh` syntax checks for four Gecko scripts;
- macOS `plutil`, Swift/Objective-C compilation, Xcode target membership,
  linking, signing, entitlement installation, and app launch;
- a final Gecko rebuild after Vulpra patch identity changes, with Xcode/SDK
  fingerprint and artifact checksum;
- GitHub-hosted execution of the new workflow (the local repository has no
  remote), and Ruby YAML parsing (Ruby is absent on the Linux host);
- physical-device verification on iOS 15.8 and iOS 16.7;
- startup, memory, and 60/120 Hz frame measurements;
- unsigned/signed IPA or TrollStore installation evidence;
- public-distribution clearance for the two SafariShared-derived patches;
- pinned idevice LICENSE/FFI notice capture for binary distribution.

These are explicit `needs-verification` or publication-blocked items, not
implicit passes.

## Next-plan boundary

Phase 0 authorizes planning of `vulpra-runtime-shell` only: a new Xcode graph,
Vulpra app/Helper/OpenIn targets, final Gecko artifact production/linking,
low-level JIT orchestration, and the first unsigned iOS 15+ IPA. It does not
authorize importing excluded client code or beginning later tabs/data/UI/
library/power-feature/release work without their separate plans and gates.
