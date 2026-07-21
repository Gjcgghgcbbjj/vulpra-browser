# Vulpra Browser

Vulpra Browser is a new Gecko-based browser client for iOS 15 and later, with a
UIKit and TrollStore-first direction.

This repository contains the verified Phase 0 Gecko/iOS/JIT substrate and the
implemented Vulpra modern browser client: a fresh four-target native Xcode
graph, bounded multi-tab UIKit browser, exactly-once JIT readiness owner,
OpenIn extension, local browser features, and deterministic GitHub macOS
runtime/package workflows. It does not contain the inherited client, old Xcode
project, old-data migration, third-party UI/analytics packages, or committed
release binaries.

Provenance and scope:

- source commit: `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`
- machine manifest: `docs/provenance/import-manifest.tsv`
- human boundary: `docs/provenance/substrate-boundary.md`
- efficiency policy: `docs/aegis/policies/efficiency-complexity-governance.md`
- current package baseline:
  `docs/aegis/baseline/2026-07-22-modern-browser-package-baseline.md`

Implemented client areas include normal/private tabs, restoration and
suspension, omnibox suggestions, start page, bookmarks/history/downloads,
page tools, permissions/privacy settings, Gecko addon management, native
animations, iPad/landscape adaptation, Reduce Motion, and 120 Hz opt-in.

Portable verification:

```sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
```

GitHub build evidence:

- Runtime substrate run: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/29856427149
- IPA/TIPA run: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/29877342036

Manual Mac commands, when Xcode and the iPhoneOS SDK are available:

```sh
./Tools/Runtime/check-macos-prerequisites.sh
./Tools/Runtime/build-runtime-substrate.sh
./Tools/Release/build-app.sh
./Tools/Release/create-ipa.sh
```

GitHub has compiled the Xcode graph and produced checksum-verified test IPA and
TIPA artifacts. Physical-device launch/JIT behavior, iOS 15.8/16.7 testing,
performance, and public-distribution clearance remain explicit device/release
gates.
