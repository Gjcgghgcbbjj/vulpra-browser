# Notices and Provenance

Vulpra-authored repository material is licensed under SPDX `GPL-3.0-only`
unless a file states otherwise.

The precompiled Gecko runtime is derived from Mozilla Firefox commit
`27b462b22705a8860f7ab0d33aa5b4b658ae5932`. Runtime packages retain the
Mozilla Public License and third-party notices as content-bound files under
their `licenses/` root. They are staged into `VulpraEngineKit.framework` during
the application build.

Historical import provenance is retained only in:

- `docs/provenance/import-manifest.tsv`
- `docs/provenance/substrate-boundary.md`

Those documents describe retired source paths and do not define the active
build graph. The repository contains no Gecko source, patch producer, runtime
source-build workflow, or device-control library.
