# Vulpra Browser

Vulpra Browser is a new Gecko-based browser client for iOS 15 and later, with a
UIKit and TrollStore-first direction.

This repository contains the verified Phase 0 Gecko/iOS/JIT substrate and the
Phase 1A portable/source-verified Vulpra runtime shell: a fresh four-target
native Xcode graph, one-session UIKit shell, exactly-once JIT readiness owner,
OpenIn extension, and deterministic Mac artifact/package producers. It does not
contain the inherited client, stores, resources, old Xcode project, data
migration, or release binaries.

Provenance and scope:

- source commit: `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`
- machine manifest: `docs/provenance/import-manifest.tsv`
- human boundary: `docs/provenance/substrate-boundary.md`
- efficiency policy: `docs/aegis/policies/efficiency-complexity-governance.md`
- current portable baseline:
  `docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md`

Portable verification:

```sh
./Tests/RuntimeShell/run-portable.sh
```

Mac continuation, when Xcode and the iPhoneOS SDK are available:

```sh
./Tools/Runtime/check-macos-prerequisites.sh
./Tools/Runtime/build-runtime-substrate.sh
./Tools/Release/build-app.sh
./Tools/Release/create-ipa.sh
```

Phase 1A does not prove Xcode compilation, physical-device behavior, IPA
creation, performance, or public-distribution clearance. Those remain explicit
Phase 1B gates.
