# Vulpra R0 Trustworthy Engine Execution - Checkpoint

- Task ID: 2026-07-29-vulpra-r0-trustworthy-engine-execution
- Current todo: Task 1: define v5 producer contract
- Active slice: Create failing contract tests, contract JSON, verifier, portable registration, and commit.
- Blocked on: none
- Next step: Read current portable test patterns and implement Task 1 test-first.

## DriftCheckDraft

- Scope status: Task 1 stayed inside dormant producer metadata and portable tests.
- Compatibility status: Normal App builds and v4 lock are unchanged.
- Retirement status: Forbidden JIT tokens are contract assertions only; no old path is retired before replacement gates.
- New risk signals:
- none
- Advisory decision: continue

## Checkpoint Update

- Current todo: Task 2: materialize and audit the iOS patch series
- Active slice: Extract historical patch candidates, establish the minimal buildable series, remove JIT coordination, and bind every patch by digest.
- Completed todos:
- Task 1: v5 producer contract committed at d5577c3
- Evidence refs:
- commit:d5577c3
- Blocked on: none
- Next step: Inspect historical patch inventory and dependencies, add failing full-series fixtures, then implement strict series verification.

## Checkpoint Update

- Current todo: Task 9: produce, compare, and atomically promote the native Gecko v5 pair
- Active slice: Run the pinned dual-platform producer to green twice, compare normalized artifacts, publish one pair, and promote the lock.
- Completed todos:
- Task 1: v5 producer contract (d5577c3)
- Task 2: audited Gecko iOS v5 patch series (5d4da42)
- Task 3: native runtime producer tools (996dc8b)
- Task 4: dual-platform producer workflow (3fd8445 and follow-up fixes)
- Task 5: lifecycle ABI and producer hardening through f11d5d3; successful pair still pending
- Task 6: internal child lifecycle owner (b749de8, f635168)
- Task 7: typed ExtensionKit requests (71ee8fa)
- Task 8: activation replay retirement (47c8319)
- Evidence refs:
- run:30480717151:host-linker-fixed-cbindgen-missing
- commit:01c20bc
- commit:f11d5d3
- Blocked on: none
- Next step: Wait for producer run 30481555028, repair only its first typed producer failure if needed, then obtain two green same-commit runs.

## DriftCheckDraft

- Scope status: Tasks 1-8 remain inside the approved R0 producer, lifecycle, process-host, and App workaround boundaries; Task 9 implementation is local but unpromoted.
- Compatibility status: The checked-in lock remains v4 until real v5 pair promotion; no runtime fallback or user-data migration was added.
- Retirement status: Activation replay and dead bootstrap ownership are retired; v4/vtool paths remain only until the replacement producer and R0 gates pass.
- New risk signals:
- GitHub Xcode 26 producer dependencies must be explicit; host linker is fixed and cbindgen is now pinned, but the new run is pending.
- Advisory decision: needs-verification

## Checkpoint Update - Verified Producer Recovery Boundary

- Current todo: Task 9: produce, compare, and atomically promote the native Gecko v5 pair
- Active slice: Prove the generalized `dist` packaging fix, establish one verified build snapshot pair, reuse it for the second same-commit producer run, compare outputs, and promote.
- Additional completed work:
- Both native builds in run `30483927701` completed; packaging exposed an exported-header symlink.
- Both native builds in run `30496390637` completed; packaging exposed a second legitimate Mozilla `dist/bin` resource symlink.
- Generalized source-contained `dist` symlink materialization committed at `3c0cdd9`; escaping links remain rejected.
- Deterministic, content-inventoried build snapshot recovery committed at `0cc03f0`; normal and reuse packaging share the verified snapshot path.
- Evidence refs:
- run:30483927701:native-builds-green-header-packaging-failure
- run:30496390637:native-builds-green-resource-packaging-failure
- commit:3c0cdd9
- commit:0cc03f0
- run:30521266433:generalized-packaging-verification-in-progress
- run:30524481875:build-snapshot-producer-pending
- Blocked on: none
- Next step: Observe run `30521266433`; then let `30524481875` establish both snapshots, dispatch a same-commit reuse run, compare both native pairs, publish one pair, and atomically promote the lock.

## DriftCheckDraft - Producer Recovery

- Scope status: Recovery remains producer-side and preserves the approved precompiled-artifact boundary.
- Compatibility status: App runtime, v4 selected lock, user data, user retry, and physical-device verification status are unchanged.
- Retirement status: Direct packaging from the transient Gecko objdir is replaced by one continuously exercised verified snapshot path; no runtime fallback was added.
- New risk signals:
- The first snapshot-producing run must prove GitHub artifact size and cross-run download behavior on `macos-26`.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: Task 9: produce, compare, and atomically promote the native Gecko v5 pair
- Active slice: Wait for the remaining iphoneos compilation in run 30527839573, repackage its two snapshots on b720f05, compare both independent compile pairs, publish one pair, and promote.
- Completed todos:
- Tasks 1-8: implementation complete
- Task 9 recovery boundary: verified snapshot create/upload/restore and final pair for compile run 30527818938 via producer run 30538440725
- Evidence refs:
- run:30527818938:independent-native-pair-and-snapshots-success
- run:30527839573:simulator-native-snapshot-success-device-pending
- run:30538440725:snapshot-reuse-pair-success
- manifest:30538440725:producer-b720f05-compiledBy-30527818938-3478b01
- Blocked on: none
- Next step: When run 30527839573 uploads the iphoneos snapshot, dispatch a b720f05 reuse run with publish_release=true, then download and compare both quick-run artifacts.

## DriftCheckDraft

- Scope status: Tasks 1-8 remain inside approved R0 boundaries; Task 9 has proved one independent native pair and the snapshot recovery path, while the second device compilation remains pending.
- Compatibility status: The repository lock remains v4; no runtime fallback, fixed process count, user-data migration, or physical-device claim was added.
- Retirement status: v4/vtool paths remain only until native pair promotion and the 20-attempt gate pass; remote rollback assets remain untouched.
- New risk signals:
- The second independent iphoneos compile has not yet reached snapshot upload.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: Task 9: prove reproducible native Gecko v5 pair and atomically promote
- Active slice: Run two independent native builds from 10df6cb with pinned MOZ_BUILD_DATE/SOURCE_DATE_EPOCH, then compare every file and promote one verified pair.
- Completed todos:
- Tasks 1-8: implementation complete
- Snapshot recovery proved by quick runs 30538440725 and 30541283317
- Full artifact verification moved before publication; executable tool payloads and false kernel/staging coupling retired
- Evidence refs:
- run:30545348862:valid-pair-compiledBy-30527818938
- run:30545352638:valid-pair-compiledBy-30527839573
- compare:30545348862-vs-30545352638:build-date-nondeterminism-detected
- commit:10df6cb:pin-reproducible-build-time
- run:30547145772:reproducible-native-build-1
- run:30547176227:reproducible-native-build-2
- Blocked on: none
- Next step: Wait for both 10df6cb native pairs, require full verifier success, download and compare normalized content, then publish a fresh tag through quick provenance packaging.

## DriftCheckDraft

- Scope status: Task 9 remains producer-side; real artifacts exposed and corrected contract classification, staging ownership, and build-time nondeterminism before lock promotion.
- Compatibility status: Repository lock remains v4; no runtime fallback, fixed process count, user-data change, or physical-device claim was added.
- Retirement status: Shallow producer verification, executable dist tools, and v5 kernel-to-App-container string coupling are retired; v4 paths await successful native promotion and Simulator gate.
- New risk signals:
- Pinned build time must eliminate all binary/resource differences across runs 30547145772 and 30547176227.
- Advisory decision: needs-verification

## Checkpoint Update

- Current todo: Task 10: run the 20-attempt R0 Simulator gate
- Active slice: Use the promoted v5 r0.3 lock to build and run 20 fresh Simulator navigation attempts.
- Completed todos:
- Tasks 1-8: implementation complete
- Task 9: two independent native v5 pairs repeat-compared and promoted (runs 30598301958, 30598347174; promotion 30613021710)
- Evidence refs:
- run:30598301958:device-and-simulator-builds-green
- run:30598347174:device-and-simulator-builds-green
- run:30613021710:repeat-compare-promotion-release-lock
- Blocked on: none
- Next step: Commit and push the v5 lock/workflow tag update, dispatch simulator-smoke.yml with engine_release_tag=vulpra-engine-v5-r0.3-candidate and r0_attempts=20, then download and reverify the gate.

## DriftCheckDraft

- Scope status: Tasks 1-9 remain producer/runtime-boundary work; v5 native pair promotion is complete and Task 10 is the next bounded gate.
- Compatibility status: v5 r0.3 lock and release are promoted; App identity, persistence, package shape, and user retry are unchanged.
- Retirement status: v4/vtool paths remain until the 20-attempt Simulator gate and package/retirement Task 11 pass.
- New risk signals:
- Physical-device runtime and JIT evidence remain external and unverified.
- Simulator gate must execute from pushed 8fa770c lock/workflow state.
- Advisory decision: needs-verification

## Checkpoint Update - 2026-08-08: R0 gate 20/20 green + final package bound

- Current todo: Task 10/11 completed for the final snapshot; remaining todos are
  final-review / external physical-device gates.
- Active slice: none (gate closed on the promoted v5 r0.3 lock).
- Completed todos:
  - Task 10: 20-attempt R0 Simulator gate passed on HEAD `4b2dc58`
    (run `31237088851`): location 20/20, page completed 20/20,
    rendered dark pixels 845360, app alive 20/20, crash 0/20,
    162 requested / 162 connected / 0 failed / 0 open child launches,
    p95 load-to-complete `1810ms`, max `1961ms`,
    deliveryMethod `gate-http-dispatch`, gateDispatchStatus=0 on all attempts.
  - Root cause + fix for prior attempt-07/10 failures: RDD process 5s startup
    timeout killed the rdd child before IPC connect; EngineKit-only fix
    `4b2dc58` raises `media.rdd-process.startup-timeout-ms` to 30000 via
    `GeckoView:Preferences:SetPref` before ready. Evidence:
    docs/aegis/work/2026-07-29-vulpra-r0-trustworthy-engine-execution/
    30-rdd-startup-timeout-root-cause.md
  - Task 11: final package run `31244000908` @ `4b2dc58`:
    Vulpra.ipa SHA-256 `0971a3ad2744ebfb8881021ceb08f7d62dd8a762997ba245fa3c115bbaf039fc`,
    Vulpra-TrollStore.tipa SHA-256
    `5adc09ba48cb757a9814c13250d21c935fdac213c033cb8e0834d32f6f351802`.
  - `python3 Tests/IndependentEngine/test_cutover_readiness.py --require-r0-complete`
    → `cutover-ready`; v4/vtool retired-path scan passes.
  - `Configuration/engine-cutover-gates.json` updated:
    repeatProducerRunIds/repeatCompileRunIds `[30598301958, 30598347174]`,
    selectedProducerRunId `30598301958`, promotionRunId `30613021710`,
    simulatorGateRunId `31237088851`, packageRunId `31244000908`.
  - ADR-0004 amended and baseline
    `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`
    synced to v5 r0.3 with 20/20 gate + final package hashes.
- Evidence refs:
  - run:30598301958:device-and-simulator-builds-green
  - run:30598347174:device-and-simulator-builds-green
  - run:30613021710:repeat-compare-promotion-release-lock
  - run:31237088851:r0-engine-gate-20-20
  - run:31244000908:ipa-tipa-validation-sha256-pass
  - commit:4b2dc58:rdd-startup-timeout-enginekit-fix
- Blocked on: none.
- Next step: final verification commands (portable suites, `--require-r0-complete`,
  Aegis workspace check, retirement scan) then push the evidence set; physical
  device/JIT/OpenIn/App Store distribution remain external validation gates.

## DriftCheckDraft - R0 closed

- Scope status: Tasks 1-11 complete on the final snapshot; the v5 r0.3 lock,
  20/20 hosted Simulator gate, and final package are bound to HEAD `4b2dc58`.
- Compatibility status: App identity, persistence, package shape, and user
  retry are unchanged; engine remains the promoted v5 r0.3 artifact.
- Retirement status: v4/vtool paths are retired and asserted by
  `--require-r0-complete` (retired paths + active-root token scan).
- New risk signals: none from the closed R0 gate; physical-device runtime and
  JIT evidence remain external and unverified.
- Advisory decision: needs-verification for physical-device/JIT/OpenIn/App
  Store; hosted Simulator R0 is verified.

## Checkpoint Update - 2026-08-09: real-device perf/RDD fixes re-verified, final snapshot

- Current todo: R0 gates re-closed on the final snapshot after the
  real-device GPU entitlement fix, RDD SetPref verification, and
  content-process termination diagnosis; remaining todos are final
  closeout commands and external physical-device gates.
- Active slice: final verification + package binding on HEAD `5942698`.
- Completed todos:
  - Real-device perf fix (`7fc9601`): EngineProcess.appex now carries the
    same `iokit-user-client-class` (5 Metal/AGX clients) + `no-sandbox`
    as the App so the GPU process can create a Metal device on-device
    instead of falling back to software WebRender (卡顿/发热/滑动慢半拍).
  - RDD startup-timeout fix re-verified on the final snapshot:
    `GeckoView:Preferences:SetPref` for
    `media.rdd-process.startup_timeout_ms = 30000` (pref name + type 64
    corrected in `c096583`, ABI callback verification in `a3d6bb4`/
    `6d2f17f`).
  - Single-attempt gate: run `31288215667` @ `8aea481` PASS (also proves
    the os_log `EngineSessionID` interpolation fix compiles).
  - 20-attempt R0 gate: run `31288670337` @ `8aea481` **20/20 passed**:
    161 child launches requested / 161 connected / 0 failed / 0 open,
    p95 load-to-complete `1623ms`, max `3111ms`
    (bounds p95<=15000ms, max<=30000ms), deliveryMethod
    `gate-http-dispatch` with `gateDispatchStatus=0`.
  - RDD SetPref delivery evidence: `rdd-timeout-pref-set verified
    pref=media.rdd-process.startup_timeout_ms expected=30000 isSet=true`
    on 76 evidence lines across attempts; 0 `isSet=false` / timed-out /
    error lines. Gecko confirmed the user-branch pref was set.
  - Content-process termination diagnosis (`8aea481`): BrowserTab logs
    `content process terminated tab=<uuid> reason=<reason>` (category
    `browser-tab`) and exposes `lastTerminationReason` until the next
    session opens; url/title/back-forward state and thumbnail are kept so
    the tab can offer recovery instead of a silent white flash reload.
  - `engine-cutover-gates.json` updated:
    repeatProducerRunIds/repeatCompileRunIds `[30598301958, 30598347174]`,
    selectedProducerRunId `30598301958`, promotionRunId `30613021710`,
    simulatorGateRunId `31288670337`, packageRunId `<pending>`.
  - Portable suites pass locally on the final snapshot
    (IndependentEngine + Browser + RuntimeShell);
    `--require-r0-complete` -> `cutover-ready`.
- Evidence refs:
  - run:30598301958:device-and-simulator-builds-green
  - run:30598347174:device-and-simulator-builds-green
  - run:30613021710:repeat-compare-promotion-release-lock
  - run:31288215667:single-attempt-gate-pass
  - run:31288670337:r0-engine-gate-20-20-final
  - commit:8aea481:didTerminate-reason-diagnosis
  - commit:5942698:final-gates-json
- Blocked on: none.
- Next step: final package run `31294387233` binding `5942698`, copy
  IPA/TIPA to the Windows desktop, then run the final verification
  commands (portable suites, `--require-r0-complete`, Aegis workspace
  check, retirement scan) and push the evidence set. Physical-device
  validation (Metal/WebRender smoothness, swipe-up reload triage,
  OpenIn, JIT, App Store distribution) remains an external gate awaiting
  user retest of the new package.
