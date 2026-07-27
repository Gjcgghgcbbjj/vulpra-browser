# Vulpra Runtime and Package Identity Repair

Date: `2026-07-27`
Status: `completed`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## Goal

Repair the reviewed runtime ownership and lifecycle risks, then produce a
Chinese-first Porcelain Native package whose installed identity can be proven
from both `Info.plist` and the App executable.

## Root Cause Evidence

The previously delivered IPA contains `VulpraBrandMarkView`,
`VulpraEmptyStateView`, the Porcelain UI localization keys, `zh-Hans` resources,
and `CFBundleDevelopmentRegion=zh-Hans`. Its version nevertheless remained
`0.1.0 (1)`, identical to earlier packages. The repair therefore treats stale
or ambiguous installation identity as the packaging defect and adds an
enforced version/fingerprint contract instead of creating another UI path.

## Work

1. Make native `Vulpra:RuntimeReady` the sole transition to ready and remove the
   unused `contentProcessLimit` promise.
2. Put runtime/session mutable state on `@MainActor`; keep ABI callbacks as the
   explicit hop from native queues to the main actor.
3. Inject `EngineRuntime` at the App composition root. `BrowserTab` and
   `TabManager` depend only on public engine protocols and keep their existing
   ownership.
4. State the ABI borrowed-value lifetime contract and keep ObjC values alive
   for each synchronous ABI call.
5. Reclaim Engine Process connections and extension contexts on interruption or
   invalidation.
6. Pin engine release tag, archive SHA-256, manifest artifact ID, and source
   commit in a repository lock; make both workflows enforce it.
7. Increment the package to `0.2.0 (2)` and embed
   `porcelain-zh-v2-20260727` in `Info.plist` and the App executable. Make the
   package validator reject missing or stale UI identity.
8. Run portable gates, simulator Chinese/Porcelain screenshots and navigation,
   then rebuild and validate IPA/TIPA before replacing desktop delivery.

## Compatibility Boundary

Preserve `com.vulpra.browser`, iOS 15, iPhone/iPad, OpenIn, Codable data,
`TabManager`/`BrowserTab` ownership, and the sole VulpraEngineKit adapter. Do
not add a fallback, migrate/delete user data, move the user branch HEAD, or
change the active target graph beyond tests required for these contracts.

## Acceptance

- Portable tests cover actor isolation, unique ready transition, protocol
  injection, ABI lifetime wording, XPC cleanup, artifact lock, and package UI
  identity.
- The simulator screenshot visibly shows the Chinese Porcelain Native start
  page, and HTTPS navigation survives 60 seconds without a crash.
- Both final packages validate as `0.2.0 (2)` with
  `porcelain-zh-v2-20260727` in the plist and executable.
- `dist/` and the Windows desktop delivery contain the newly validated files
  and hashes; temporary CI refs are removed and the original HEAD is unchanged.
