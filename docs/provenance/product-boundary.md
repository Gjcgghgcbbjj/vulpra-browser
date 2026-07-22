# Vulpra Product Ownership Boundary

Date: `2026-07-23`
Status: `active`

## Canonical product owner

Vulpra is authored and maintained in this repository. The following roots are
product-owned rather than imported substrate:

- `App/`
- `Configuration/`
- `Extensions/OpenIn/`
- `Vulpra.xcodeproj/`
- `Tools/Release/`
- `Tools/Runtime/`
- `Tests/Browser/`
- `Tests/RuntimeShell/`
- Vulpra build/package and real runtime-producer workflows under
  `.github/workflows/`

These roots own UI, browser behavior, state, persistence, configuration,
target membership, release orchestration, and product verification. They must
not appear in `docs/provenance/import-manifest.tsv` or
`docs/provenance/substrate-deltas.tsv`.

## Derived substrate

Only GeckoView, Helper, low-level JIT/native code, Gecko patches, audited build
tools, and pinned external sources retain Reynard/upstream lineage. Their
responsibility and attribution remain in `substrate-boundary.md` and the import
manifest. Vulpra-maintained changes to those files are recorded separately in
`substrate-deltas.tsv`.

## Reference-only repository

The bootable Reynard repository is not a source dependency, Git submodule,
project dependency, product fallback, or release input. It may be inspected to
identify a necessary low-level launch, target graph, embedding, entitlement,
or signing contract. Any adopted value must be implemented at the matching
Vulpra owner and verified by Vulpra tests.

## Prohibited product inheritance

- Reynard Client, BrowserCore, StabilityCore, screens, managers, stores, and
  compatibility layers;
- Reynard resources, icons, launch assets, strings, screenshots, and product
  copy;
- Reynard Xcode project, schemes, signing team, provisioning settings, and
  release scripts;
- reading or migrating old Reynard application data;
- keeping both projects or both product owners active “for safety.”

## Evidence

Before transfer, the selected Vulpra product tree at commit `7955722` was
compared with audited Reynard commit
`ef14c2997ae7dfdb44155240ec64fea3140ba9e1`. There were zero exact file matches.
Seven normalized similarity signals were reviewed as short platform contracts,
protocol adapter shapes, or CI producer structure; none authorizes importing a
Reynard product owner.
