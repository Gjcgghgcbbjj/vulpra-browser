# Vulpra Independent Engine Completion and IPA - Reflection

## Outcome

The repository now has one engine path: the verified precompiled Gecko v4
runtime feeds VulpraEngineKit, and the App depends only on VulpraEngineKit.
The independent Engine Process receives the native XPC endpoint and starts
child processes without the retired Helper or JIT owners.

## Evidence

- Simulator run `30239461150` built `0.2.0 (2)`, passed both native EngineKit
  XCTest cases, rendered the Chinese Porcelain start page, attached the native
  engine view, rendered Example Domain with `40077` dark pixels, survived 60
  seconds, connected Engine Process instances, and produced no crash report.
- Final package run `30240301567` used the same snapshot
  `95338aadf837906c8baa8b3f4896d8f7acdee997`, archived with Xcode 26.4.1, and
  produced the IPA/TIPA now stored in `dist/` and on the Windows desktop.
- Local SHA-256, ZIP, bundle identity, artifact identity, arm64 Mach-O content,
  package UI fingerprint, localization/icon resources, and TIPA
  signature-structure validation passed for both final packages.
- All portable suites, cutover readiness, old-path scans, workspace checks,
  and `git diff --check` passed.

## Architecture Review

The cutover retains exactly one adapter and one process host. Runtime/session
state is main-actor isolated, native readiness has one transition owner, App
composition injects engine protocols, ABI borrowed-value lifetimes are explicit,
and Engine Process connections are reclaimed. No fallback, duplicate owner,
archived endpoint transport, source-build path, or JIT path was introduced.
ADR-0004 supersedes the old runtime-shell decision and records this hardening
amendment; the baseline records the current owner and evidence boundaries.

## Compatibility And Retirement

`com.vulpra.browser`, iOS 15.0, arm64 iPhone/iPad, OpenIn, Codable persistence,
and TabManager/BrowserTab ownership are preserved. Retirement was internal
code deletion only; no user data was deleted or migrated.

## Residual Risk

The current GitHub `macos-26` runner does not contain Xcode 16.4, so iOS 18.5
simulator evidence could not be refreshed. Physical-device installation,
iOS 15.8/16.7 behavior, performance, and public distribution review remain
outside this verified source/simulator/package completion boundary.

Method Pack output does not grant completion authority.
