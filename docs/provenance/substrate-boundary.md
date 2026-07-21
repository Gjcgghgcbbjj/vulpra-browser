# Vulpra Phase 0 Substrate Boundary

- Status: `substrate-boundary-recorded`
- Audited source repository: <https://github.com/Gjcgghgcbbjj/reynard-browser>
- Audited source commit: `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`
- Import manifest: `docs/provenance/import-manifest.tsv`
- Manifest rows: `345`
- Scope: Gecko/iOS process substrate and low-level JIT support only

This report is the human-readable boundary paired with the machine-readable
manifest. A target file copied from the audited source must appear in the
manifest; the two pinned Git submodules are recorded separately because Git
tracks them as gitlinks rather than regular imported files.

## Imported

Only these five manifest top-level groups are approved:

| Target group | Manifest rows | Retained responsibility |
| --- | ---: | --- |
| `Vendor/` | 1 | Firefox release pin metadata. |
| `Patches/` | 262 | Audited Gecko/iOS patch set. |
| `Tools/` | 8 | Gecko/idevice build, patch, artifact, and framework-copy tooling. |
| `Extensions/` | 59 | GeckoView bridge and Helper process bridge. |
| `Modules/` | 15 | Low-level JIT, RPPairing/DDI, ptrace, and native utilities. |

The two exact external gitlinks are:

| Target | Commit | URL |
| --- | --- | --- |
| `Vendor/firefox` | `27b462b22705a8860f7ab0d33aa5b4b658ae5932` | <https://github.com/mozilla-firefox/firefox> |
| `Vendor/idevice` | `92323d1262598cfcb31aa54ef94c26bb26c5c7a0` | <https://github.com/jkcoxson/idevice> |

The imported responsibility boundary includes only:

1. the pinned Firefox release metadata, patch set, and reproducible artifact
   tooling;
2. GeckoView session/process integration and the Helper XPC/process bridge;
3. low-level JIT enablement, RPPairing/DDI mechanics, unsandboxed ptrace helper,
   and shared native utilities;
4. exact submodule pins needed by that substrate.

The prebuilt Gecko artifact was not copied into Git and was not rebuilt during
Phase 0. The first macOS producer pass must perform one final rebuild after all
Vulpra patch identities are fixed, then verify its checksum and build metadata.

## Excluded

The following source responsibilities are deliberately absent:

- `browser/Reynard/Client/` and all inherited browser-client ownership;
- `browser/Reynard/BrowserCore/`, `StabilityCore/`, product orchestration, and
  the old product-level `JITController.swift`;
- UIKit screens, navigation shells, failure UI, settings, menus, and old UI
  tests;
- old stores, schemas, persistence readers/writers, preferences, caches,
  history/bookmark/download/session databases, and migration code;
- `browser/Reynard/Resources/`, icons, screenshots, launch assets, colors,
  localized product copy, and visual trade dress;
- `browser/Reynard.xcodeproj`, schemes, target membership, signing settings,
  packaging products, and previously built binaries;
- old application extensions and product targets not included in the exact
  `Extensions/GeckoView` and `Extensions/Helper` boundary;
- generated `libidevice_ffi.a`, IPA/TIPA files, Gecko frameworks, derived data,
  caches, and other build output;
- old data discovery, import, fallback, or migration paths.

Excluded source may be inspected to understand a substrate contract, but it may
not be copied and cosmetically renamed. New client behavior must be implemented
under a later Vulpra plan with a new owner and tests.

## Active identity replacements

Active runtime/product identity is Vulpra-owned. No compatibility fallback to
an old Reynard identifier is retained.

| Source identity | Active Vulpra identity |
| --- | --- |
| `ReynardXPCListenerEndpoint` | `VulpraXPCListenerEndpoint` |
| `ReynardHelperMain` | `VulpraHelperMain` |
| `Reynard.ProcessBootstrap` | `Vulpra.ProcessBootstrap` |
| `ReynardExtension` | `VulpraExtension` |
| `Reynard Helper.appex` | `Vulpra Helper.appex` |
| `Reynard:Features:*` | `Vulpra:Features:*` |
| `reynard-*` add-on install IDs | `vulpra-*` |
| `com.minh-ton.Reynard.JITEnabler*` | `com.vulpra.browser.jit.enabler*` |
| `com.minh-ton.Reynard.JITSupport*` | `com.vulpra.browser.jit.support*` |
| `com.minh-ton.Reynard.DDIManager*` | `com.vulpra.browser.jit.ddi*` |
| `Reynard.JIT` | `Vulpra.JIT` |
| `ReynardDebug` | `VulpraDebug` |
| tunnel display name `Reynard` | `Vulpra` |
| `me-minh-ton.jit.endpoint-monitor-failed` | `com.vulpra.browser.jit.endpoint-monitor-failed` |
| `[REYNARD_DEBUG]` | `[VULPRA_DEBUG]` |
| `reynard-download.tmp` | `vulpra-download.tmp` |
| `reynard_mmap` | `vulpra_mmap` |

There is no exception for an active low-level Reynard symbol. Historical source
paths in the manifest and preserved attribution text are provenance, not active
runtime contracts.

## Attribution and permitted historical text

Copied notices are not removed merely to make a broad name search empty. The
active-identity gate permits only exact normalized provenance lines listed in
`Tools/Bootstrap/active-identity-allowlist.txt`:

- 38 attribution URL lines in the imported patch set;
- 67 imported file-header lines carrying the source-project name: 52 under
  `Extensions/`, 14 under `Modules/`, and 1 under `Tools/`.

The allowlist file also contains normalized matching forms for patch-added
lines. It is verification configuration and is not counted as an additional
imported attribution occurrence. Any new historical-name occurrence outside
these exact forms fails the active-identity gate.

## License mapping

| Material | Governing notice/license evidence | Phase 0 treatment |
| --- | --- | --- |
| Vulpra-authored repository material | Root `LICENSE`, GPL-3.0 text; `NOTICE.md` declares `GPL-3.0-only` | Retained as the repository default. |
| Source-project `Extensions/`, `Modules/`, and copied build tooling | Audited source root `LICENSE` plus retained file-level copyright/provenance headers | Treated as inherited GPL-3.0-only material unless a file-specific notice states otherwise. |
| Gecko patch material | Patch-local MPL notices and `LICENSE.firefox` (MPL-2.0) | Kept separate under `Patches/`; notices remain intact. |
| `Vendor/firefox` gitlink | Mozilla upstream repository at the exact pinned commit | Upstream Mozilla and bundled third-party licenses apply; no Firefox source is copied into this repository. |
| `Vendor/idevice` gitlink | jkcoxson/idevice upstream repository at the exact pinned commit | Upstream license scope must be verified at checkout/package time; see blocker below. |

### Publication blockers

Phase 0 local boundary verification is not publication clearance:

1. `Patches/mobile/shared/modules/geckoview/FormAutoFillKeywords.sys.mjs.patch`
   says its keyword tables were converted from
   `SafariShared.framework/WBSFormAutoFillKeywords.json`.
2. `Patches/mobile/shared/modules/geckoview/FormFieldClassifier.sys.mjs.patch`
   says it ports relevant portions of SafariShared classifier behavior from
   minified framework JavaScript.

Those two patches must be independently rewritten from a publishable
specification, removed, or supported by documented redistribution permission
before any public release.

The pinned `Vendor/idevice` gitlink does not place an independent LICENSE text
in this repository. Before distributing an idevice binary or
`libidevice_ffi.a`, the producer must capture the pinned checkout's license
text, verify whether generated FFI bindings carry additional terms, and include
the required notices. Until then idevice binary redistribution remains blocked.

## Boundary falsifier

If compilation or runtime closure requires any excluded client, UI, store,
resource, Xcode-project, product-controller, or old-data path, this extraction
boundary is falsified. Stop the next implementation phase, classify the missing
responsibility, and amend the architecture/plan; do not broaden the import or
add a fallback silently.

## Verification contract

The boundary remains valid only while all of these are true:

- every regular imported file is represented by one of the 345 manifest rows
  and its SHA-256 matches;
- manifest targets use exactly the five approved top-level groups;
- the two gitlinks remain pinned to the commits and URLs above;
- excluded roots, old product assets, old data paths, JIT UI/controller files,
  and generated archives remain absent;
- active identity and exact-attribution tests pass;
- Vendor/Patches size is measured separately from Vulpra-maintained code.
