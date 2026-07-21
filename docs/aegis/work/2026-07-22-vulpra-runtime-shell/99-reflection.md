# Vulpra Runtime Shell - Reflection

## Phase 1A outcome

Tasks 1-9 established the fresh four-target native Xcode graph, new Vulpra
runtime owners, exactly-once JIT readiness contract, public-only OpenIn path,
macOS runtime/release producers, deterministic portable fixtures, and a single
Ubuntu portable gate. The implementation remains inside the approved boundary:
no inherited client/UI/store/resource/data owner and no generated artifact is
tracked.

## Direction corrections

Direct substrate evidence changed two planned details without growing fallback
paths: Gecko's `AppShellDelegate` remains the sole application delegate, so an
unused Vulpra AppDelegate was not created; and GeckoSession now leaves a missing
engine view observable so the App failure owner can degrade visibly instead of
terminating first. The stale TSUtils import, iOS 13 producer settings, Modules
archive output, artifact v2, and duplicate workflow commands were retired.

## Complexity closure

All new runtime owners are below 220 lines, the project graph is 259 lines, all
producer scripts are below 250 lines, no package-manager dependency or image
asset was added, and the only maintained file at or above 800 lines remains the
retired Phase 0 plan. Runtime binary size and performance metrics require a real
artifact/device and remain needs-verification.

## Remaining boundary

Phase 1B must run the recorded Mac sequence, validate the graph with current
Xcode, rebuild Gecko/idevice, create IPA/TIPA outputs, install on iOS 15.8 and
16.7, verify OpenIn/JIT behavior, collect startup/memory/frame evidence, and
resolve public-distribution notices. Phase 1A must not be described as IPA-ready,
device-verified, performance-complete, or release-ready.

Method Pack output does not grant completion authority.
