# Vulpra Browser

Vulpra Browser is a new Gecko-based browser client for iOS 15 and later, with a
UIKit and TrollStore-first direction.

This repository currently contains the verified Phase 0 Gecko/iOS/JIT substrate
boundary. It deliberately does not contain the inherited Reynard client, UI,
stores, resources, Xcode project, old-data migration, or release binaries.
Future client work must use new Vulpra owners and may not broaden the audited
import boundary without a design amendment.

Provenance and scope:

- source commit: `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`
- machine manifest: `docs/provenance/import-manifest.tsv`
- human boundary: `docs/provenance/substrate-boundary.md`
- efficiency policy: `docs/aegis/policies/efficiency-complexity-governance.md`

Phase 0 portable verification does not by itself prove Xcode compilation,
physical-device behavior, IPA readiness, or public-distribution license
clearance.
