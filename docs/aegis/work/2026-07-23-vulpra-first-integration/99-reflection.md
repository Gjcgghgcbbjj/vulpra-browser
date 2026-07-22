# Reflection — Vulpra-First Integration

Date: `2026-07-23`

## Goal

Create and package a Vulpra-owned iOS 15+ browser client while retaining only
the audited GeckoView, Helper, JIT, patch, and build substrate. Deliver the
verified IPA/TIPA to the mounted Windows desktop without reviving Reynard
product ownership.

## Result

- Vulpra is the sole owner of the app lifecycle, browser UI, features,
  persistence, settings, Xcode graph, runtime orchestration, and packaging.
- GitHub Bootstrap run `29961240711` and package run `29961256526` completed
  successfully for package commit `5f49f3c`.
- Artifact `8546130042` passed checksum, archive, bundle, architecture,
  runtime, extension, executable-mode, code-signature, and entitlement checks.
- The current packages were atomically installed at
  `/mnt/c/Users/niting/Desktop/Vulpra-Fixed-29944288468` and reverified there.

## Debugging lessons

Two stale verification assumptions were found rather than bypassed:

1. the Phase 0 Gecko test rejected every Xcode project and resource directory,
   so it was narrowed to reject only the retired Reynard product paths;
2. the GitHub Bootstrap checkout was shallow even though provenance validation
   reads pinned baseline commit `6fbf6ae`, so the workflow owner now fetches
   history and the repository-shape gate enforces that contract.

Neither repair added a runtime fallback, compatibility owner, or duplicate
product path.

## Complexity reflection

- 35 product Swift files, 2,693 Swift lines, and no product owner at or above
  350 lines.
- No third-party UI, animation, analytics, advertising, CocoaPods, or Swift
  Package Manager dependency was added.
- The unpacked TrollStore app is `304,647,607` bytes. The separately governed
  Gecko/runtime payload is `98.50%`; the Vulpra-owned non-engine shell is
  `4,556,302` bytes (`1.50%`).
- The new TIPA is `3,199,653` bytes (`3.05%`) smaller than the replaced desktop
  package.

## Boundary and residual risk

The product shell has zero active Reynard product-identity matches. The Gecko
payload retains one ordinary English dictionary word and two source-provenance
comments; they are not product owners or user-interface branding and are not
silently removed.

Physical-device installation, process launch, Gecko page load, Helper/JIT
readiness, OpenIn behavior, and 60/120 Hz performance remain
`needs-user-verification`. Package engineering success is not treated as device
success.

## Decision

The Vulpra-first integration, GitHub compilation, package verification, and
Windows desktop delivery scope reached its planned stop condition. Continue
only with device evidence or the next approved feature-depth plan.
