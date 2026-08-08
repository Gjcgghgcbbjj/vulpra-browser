# RDD startup-timeout root cause and runtime fix (2026-08-08)

## Symptom (gate run 31230715239, HEAD 14811be)

20-attempt Simulator gate completed all attempts but FAILED the strict
lifecycle contract on attempts 7 and 10:

- launch 4 (rdd) went `bootstrapAcknowledged -> terminated` with NO
  `ipcConnected`; attempt 7 additionally left launch 8 (rdd) open.
- Summarizer error: `launch 4 stage is skipped or regressive:
  bootstrapAcknowledged -> terminated`.
- Navigation itself was healthy in both attempts (locationMatched,
  pageCompleted, crashCount=0).

## Evidence that this is a real process kill, not an evidence-collection gap

From `attempt-07-system.log` (raw unified log, NOT the merged evidence):

```
01:21:02.435 child-lifecycle launch=4 child=4 type=rdd pid=0 stage=2
01:21:02.435 child-lifecycle launch=4 child=4 type=rdd pid=72616 stage=3
01:21:02.463 child-lifecycle launch=4 child=4 type=rdd pid=72616 stage=6
01:21:02.463 Vulpra[72442] invalidated because the current process cancelled
            the connection by calling xpc_connection_cancel()
01:21:02.469 Vulpra Engine Process[72616] Received unexpected XPC event type: error
01:21:02.498 launchd_sim signal service: caller = Vulpra[72442], value = 0x9
```

The parent (Vulpra app, pid 72442) cancelled the XPC connection and SIGKILLed
the RDD extension process 28 ms after its bootstrap acknowledgement. No crash
files exist for these PIDs; the kill is initiated by the parent.

## Correlation (all 20 attempts)

| rdd launch | request->ack | result |
|---|---|---|
| attempt 7 L4  | 7.6 s  | killed after ack (no ipcConnected) |
| attempt 7 L8  | 6.8 s  | killed after ack (no ipcConnected) |
| attempt 10 L4 | 5.8 s  | killed after ack (no ipcConnected) |
| attempt 7 L10 | 0.6 s  | ipcConnected OK |
| attempt 10 L8 | 3.6 s  | ipcConnected OK |

Only RDD launches that took longer than 5 s to reach bootstrap acknowledgement
were killed. GPU (13.4 s), socket (12.6 s) and tab (up to 9.8 s) launches
survived because only the RDD process host has an asynchronous startup timer.

## Mechanism (upstream Firefox 27b462b, FIREFOX_152_0_6_RELEASE)

`dom/media/ipc/RDDProcessHost::Launch()`:

```cpp
int32_t timeoutMs = StaticPrefs::media_rdd_process_startup_timeout_ms();
// 5000 by default (modules/libpref/init/StaticPrefList.yaml)
if (timeoutMs) {
  // If this runs before WhenProcessHandleReady resolves, abort the launch.
  GetMainThreadSerialEventTarget()->DelayedDispatch(
      NS_NewRunnableFunction("RDDProcessHost::Launchtimeout",
                             [this, liveToken = mLiveToken]() {
                               if (!*liveToken || mTimerChecked) return;
                               InitAfterConnect(false);
                             }),
      timeoutMs);
}
```

`InitAfterConnect(false)` -> `RejectPromise()` ->
`RDDProcessManager::DestroyProcess()` -> `RDDProcessHost::Shutdown()` ->
`KillHard("NormalShutdown")` (SIGKILL) -> `GeckoChildProcessHost` destructor ->
`NotifyChildLifecycle(kChildTerminated)`.

By contrast `GPUProcessHost::Launch()` has no async timer; its
`layers.gpu-process.startup-timeout-ms` is only enforced by the blocking
`WaitForLaunch()` path that the iOS async launch does not use.
`SocketProcessHost` has no startup timeout at all. So RDD is the only process
type in the pool with a fail-fast async startup timer, and the 5 s default is
too tight for ExtensionKit bootstrap under CI-simulator load.

## Fix (EngineKit-only, no Gecko recompile)

`Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift`

- On `Vulpra:RuntimeReady`, before completing ready observers, dispatch
  `GeckoView:Preferences:SetPref` with
  `media.rdd-process.startup-timeout-ms = 30000` (PREF_INT, user branch).
- The Gecko parent process handles this message via
  `GeckoViewPreferences.setPreference` (verified present in the shipped
  artifact `bin/modules/GeckoViewPreferences.sys.mjs`), which updates the
  `mirror: always` static pref before any RDD process is launched.
- Value choice: observed worst case 7.6 s bootstrap under load; 30 s keeps a
  fail-fast safety net while matching the engine bootstrap timeout scale
  (20 s).

## Why not other options

- Not a harness/evidence bug: the kill is visible in raw unified-log and is a
  genuine engine-side process termination.
- Not relaxing the lifecycle contract: `bootstrapAcknowledged -> terminated`
  without `ipcConnected` is a real failure mode and stays a gate failure.
- Not changing producer inputs (mobile.js patch): would require a Gecko
  recompile; the runtime SetPref path avoids touching the verified engine
  artifact (vulpra-engine-v5-r0.3-candidate).

## Verification remaining

- Native EngineKit tests + portable gates locally.
- Full 20-attempt R0 gate on the new HEAD; all rdd launches must reach
  `ipcConnected` (no terminated-before-outcome) under load.
