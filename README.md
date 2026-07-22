# Vulpra Browser

Vulpra is an independently owned Gecko browser client for iOS 15 and later.
The product uses UIKit, supports iPhone and iPad, and currently targets
TrollStore-first installation.

## Ownership boundary

Vulpra is **not** produced by copying Reynard and deleting visible features.

- Vulpra owns `App/`, `Configuration/`, `Extensions/OpenIn/`,
  `Vulpra.xcodeproj`, product tests, resources, workflows, and release tools.
- The audited GeckoView, Helper, JIT, patch, and producer roots are retained
  only as the browser-engine substrate.
- The Reynard client, resources, stores, Xcode project, old identifiers, and
  old-data compatibility paths are not build inputs.

Some files under the derived substrate keep their original source headers or
historical attribution. Those references describe provenance; they are not
Vulpra product UI or product ownership. `Tests/Ownership/run-portable.sh`
enforces this boundary.

## Integrated product modules

The current Vulpra-owned client includes:

- Gecko tabs with normal/private separation, restoration, bounded live
  sessions, bounded thumbnails, and memory-pressure cleanup;
- a native bottom browser chrome, progress UI, gestures, Reduce Motion support,
  dark appearance, and the 120 Hz display opt-in;
- local omnibox suggestions, configurable search engines, HTTPS-first routing,
  bookmarks, history, start-page quick sites, and recently closed tab state;
- downloads, sharing, page tools, find in page, zoom, desktop mode, QR scanning,
  image saving, and Picture in Picture integration;
- site permissions, browsing-data controls, tracking-protection settings, and
  Gecko extension installation/enablement management;
- a newly authored Vulpra icon and no inherited product assets.

The broader product design remains tracked in
`docs/aegis/specs/2026-07-22-vulpra-modern-browser-product-design.md`. Passing
the current integration gate does not by itself claim every later provider or
device-hardening requirement in that design.

## Build model

Normal app builds reuse an exact runtime artifact when its Firefox, idevice,
patch, build-script, Xcode, and SDK identity matches. Product/UI changes alone
do not require rebuilding Gecko.

GitHub Actions owns the Mac build path:

- `build-runtime-substrate.yml` builds Gecko and idevice only when required;
- `build-ios-packages.yml` restores the matching runtime, archives Vulpra, and
  produces `Vulpra.ipa` plus `Vulpra-TrollStore.tipa`;
- generated runtime and package outputs remain outside Git.

Manual package dispatch:

```bash
gh workflow run build-ios-packages.yml \
  --repo Gjcgghgcbbjj/vulpra-browser \
  --ref feature/vulpra-first-integration
```

## Portable verification

Run from the repository root:

```bash
./Tests/Bootstrap/test-repository-shape.sh
./Tests/Bootstrap/test-import-boundary.sh
./Tests/Ownership/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
```

Portable checks cover ownership, identities, Xcode graph structure, packaging
contracts, product complexity, plist parsing, and generated-output boundaries.
Only a fresh GitHub Xcode build can prove compilation and package creation;
only installation on a physical device can prove launch behavior.

## Provenance and decisions

- `docs/provenance/product-boundary.md`
- `docs/provenance/substrate-boundary.md`
- `docs/provenance/import-manifest.tsv`
- `docs/provenance/substrate-deltas.tsv`
- `docs/aegis/adr/ADR-0002-vulpra-first-product-integration.md`
- `docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md`

See `LICENSE`, `LICENSE.firefox`, and `NOTICE.md` for license and attribution
information.
