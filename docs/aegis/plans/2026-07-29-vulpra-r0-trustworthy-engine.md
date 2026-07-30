# Vulpra R0 Trustworthy Engine Implementation Plan

Goal: Replace the unverifiable v4/vtool runtime and caller-side timing
mitigations with reproducible native device/Simulator Gecko v5 artifacts and a
typed, closed child-process lifecycle, then prove 20 of 20 independent GitHub
Simulator cold-navigation attempts.

Architecture: Normal App builds continue to consume a pinned precompiled
runtime. A repository-owned producer surface pins upstream Firefox, an ordered
auditable patch series, target-specific mozconfig, toolchain identity, and
artifact packaging. GeckoChildProcessHost owns semantic child lifecycle;
VulpraEngineProcess owns ExtensionKit/XPC resources; VulpraEngineKit tracks the
typed internal lifecycle; App code receives product-level failures only.

Tech Stack: Swift 5.9+, Objective-C++, C ABI, UIKit, ExtensionKit/NSXPC, Gecko
C++, Python 3 contract tools, POSIX shell, Xcode 26.4.1, iOS 15 deployment
target, GitHub Actions macOS 26 runners.

Baseline/Authority Refs:

- `docs/aegis/specs/2026-07-29-vulpra-power-browser-architecture-design.md`
- `docs/aegis/specs/2026-07-22-vulpra-modern-browser-product-design.md`
- `docs/aegis/specs/2026-07-26-vulpra-independent-engine-product-design.md`
- `docs/aegis/specs/2026-07-26-vulpra-client-experience-design.md`
- `docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md`
- `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`
- diagnostic runs `30277909573`, `30456751227`, and `30456757711`

Compatibility Boundary: Preserve `com.vulpra.browser`, iOS 15.0, arm64
iPhone/iPad, App/OpenIn/EngineKit/Engine Process products, normal tab Codable
records, private-tab non-restoration, IPA/TIPA products, and user-triggered
retry. Do not delete or migrate persistent user data. Do not introduce a
runtime engine fallback. Physical-device runtime remains explicitly unverified
until separate device evidence exists.

Verification:

```sh
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
git diff --check
gh workflow run produce-gecko-v5.yml --ref fix/browser-performance-20260729
gh workflow run simulator-smoke.yml --ref fix/browser-performance-20260729 \
  -f r0_attempts=20
gh workflow run build-ios-packages.yml --ref fix/browser-performance-20260729 \
  -f engine_release_tag=vulpra-engine-v5-candidate
```

Expected final evidence is a native device artifact, native Simulator artifact,
20 closed navigation traces, a green package run, no vtool/JIT-handshake/page
activation workaround, and an amended architecture record based on those runs.

## 1. Plan Basis

### Facts

- The formal branch at planning time is `a194f72` on
  `fix/browser-performance-20260729`.
- Current Simulator lock policy is
  `apple-vtool-set-build-version-iossim-15`.
- The vtool Simulator XUL and dylib code/data are the device binaries with
  changed platform metadata.
- Native Simulator A/B evidence contains one visible successful navigation and
  one live, non-crashing `about:blank` failure with the same App/Engine code.
- Packaged v4 ABI headers and XUL contain downstream surfaces absent from the
  declared upstream commit.
- The binary contains inherited JIT readiness protocol tokens while the Vulpra
  client no longer owns that protocol.
- Gecko's existing `GeckoChildProcessHost::OnChannelConnected` is the correct
  semantic point for `ipcConnected`.
- The active App still contains `reassertActivationIfNeeded`.

### Assumptions

- The historical patch tree on
  `codex/vulpra-simulator-engine-producer-20260727` is lineage evidence, not a
  trusted current source of truth.
- The minimum buildable iOS port patch set must be established by clean apply,
  native dual-target builds, ABI checks, and rendering evidence. Patch names or
  historical presence alone are insufficient.
- Private `_xpcConnection` and NSXPC decoder integration remain bounded platform
  compatibility surfaces during R0. Replacing them requires separate evidence
  and is not necessary to close the current lifecycle contract.

### Unknowns converted to tests

- Which historical iOS patches are required for the pinned Firefox snapshot.
- Whether all required process roles reach Gecko IPC connection consistently.
- Whether removing the inherited JIT wait eliminates the observed startup delay
  without exposing another process failure.
- Device runtime behavior; package construction can be checked now, execution
  cannot.

## 2. Requirement Ready Check

- Requirement source refs: approved 2026-07-29 architecture spec.
- Goals and scope refs: spec Sections 1-8 and 15.1.
- User/scenario refs: advanced iOS user, TrollStore/sideloading, GitHub
  verification except physical device.
- Requirement items: reproducible producer, native dual artifacts, typed child
  lifecycle, old-path retirement, 20-run gate, package preservation.
- Acceptance refs: spec Sections 15.1, 16, 18, and 20.
- Open blocker questions: none for plan creation; patch necessity and runtime
  behavior are explicit build/runtime tests.
- Decision: `ready`.

## 3. Baseline Usage

- Required baseline refs: architecture spec, independent-engine spec, client
  spec, ADR-0004, independent-engine baseline.
- Acknowledged before planning: all required refs plus current code, artifact
  lock, workflows, historical producer branch, official Firefox source, and A/B
  evidence.
- Cited in plan: all required refs and evidence identifiers.
- Missing refs: physical-device runtime, 120 Hz, energy, and thermal evidence.
- Decision: `continue`; missing device evidence remains an external gate.

## 4. Architecture Integrity Lens

- Invariant: every child request has one typed connected or failed outcome.
- Canonical owner/contract: GeckoChildProcessHost semantic lifecycle;
  VulpraEngineProcess platform resources; VulpraEngineKit internal tracker.
- Responsibility overlap to remove: vtool artifact identity, hidden JIT owner,
  dead argument bootstrap model, and App activation replay.
- Higher-level path: expose Gecko's existing process state rather than infer
  readiness in App code.
- Retirement/falsifier: if the pinned Gecko cannot report IPC connection and
  failure from its process manager, return to architecture review; do not add an
  App timer or fixed process count.
- Verdict: proceed.

## 5. Plan Pressure and Complexity

### Plan Pressure Test

- Owner/contract/retirement: explicit in Tasks 1-11.
- Architecture integrity: producer and Gecko process manager are repaired
  before consumers.
- Verification scope: portable, dual producer builds, Simulator runtime,
  packages, and negative retirement scans.
- Task executability: each task has exact paths, commands, expected evidence,
  and a commit boundary.
- Pressure result: `proceed`.

### Plan-Time Complexity Check

- Artifact class: high-complexity producer/runtime contract repair.
- Existing pressure: `EngineABIBridge.mm` is 295 lines,
  `VulpraEngineRuntime.swift` is 229 lines, `BrowserTab.swift` is 220 lines, and
  `simulator-smoke.yml` contains a large inline launch harness.
- Projected pressure: over-budget if lifecycle tracking and 20-attempt logic are
  added to those existing files.
- Better boundaries: add `EngineChildProcessLifecycle.swift`,
  `EngineProcessRequest.swift`, `Tools/GeckoProducer/`, and reusable CI scripts.
- Recommendation: add focused owner files and extract the smoke harness; keep
  ABI forwarding in the existing bridge.

## 6. File Map

Create:

- `Configuration/gecko-producer-v5.json`
- `Engine/GeckoPatches/v5/series.json`
- `Engine/GeckoPatches/v5/**/*.patch`
- `Tools/GeckoProducer/fetch-source.sh`
- `Tools/GeckoProducer/apply-series.py`
- `Tools/GeckoProducer/build-runtime.sh`
- `Tools/GeckoProducer/package-runtime.py`
- `Tools/GeckoProducer/verify-producer.py`
- `.github/workflows/produce-gecko-v5.yml`
- `Engine/VulpraEngineKit/Internal/Process/EngineChildProcessLifecycle.swift`
- `Engine/VulpraEngineProcess/EngineProcessRequest.swift`
- `Tools/Engine/promote-engine-artifacts.py`
- `Configuration/engine-artifact-device-v5.json`
- `Configuration/engine-artifact-simulator-v5.json`
- `Tools/CI/run-simulator-navigation.sh`
- `Tools/CI/summarize-r0-engine-gate.py`
- `Tests/IndependentEngine/test_gecko_producer_v5.py`
- `Tests/IndependentEngine/test_child_process_lifecycle.py`
- `Tests/IndependentEngine/test_engine_artifact_v5.py`
- `Tests/IndependentEngine/test_r0_gate_contract.py`

Modify:

- `Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.h`
- `Engine/VulpraEngineKit/Internal/ABI/EngineABIBridge.mm`
- `Engine/VulpraEngineKit/Internal/ABI/EngineABI.swift`
- `Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift`
- `Engine/VulpraEngineKit/Internal/Process/VulpraEngineProcessHost.swift`
- `Engine/VulpraEngineProcess/EngineProcessExtension.swift`
- `App/Browser/BrowserTab.swift`
- `App/Browser/BrowserViewController.swift`
- `Configuration/engine-artifact-lock.json`
- `Configuration/engine-abi-inventory.json`
- `Configuration/engine-cutover-gates.json`
- `Configuration/Base.xcconfig`
- `Tools/Engine/verify-engine-artifact.py`
- `Tools/Engine/stage-engine-runtime.sh`
- `Tools/Engine/relocate-simulator-kernel-link.sh`
- `Tools/Release/build-app.sh`
- `.github/workflows/simulator-smoke.yml`
- `.github/workflows/build-ios-packages.yml`
- `Tests/VulpraEngineKitTests/VulpraEngineKitTests.swift`
- `Tests/IndependentEngine/run-portable.sh`
- `Tests/IndependentEngine/test_internal_boundaries.py`
- `Tests/IndependentEngine/test_runtime_hardening.py`
- `Tests/IndependentEngine/test_xcode_staging.py`
- `Tests/IndependentEngine/test_cutover_readiness.py`
- `Tests/Browser/test-package-workflow.py`
- `Tests/Browser/test-package-identity.py`
- `Tools/Engine/validate-ipa.py`
- `Tests/RuntimeShell/test-package-validator.py`
- `README.md`
- architecture ADR/baseline after runtime evidence

Delete only after v5 gates pass:

- `Tools/Engine/produce-simulator-artifact.sh`
- `.github/workflows/produce-simulator-artifact.yml`
- `Tests/IndependentEngine/test_simulator_producer.py`
- `Tests/IndependentEngine/test_artifact_contract.py`
- `Configuration/engine-artifact-v4.json`
- `Configuration/engine-artifact-simulator-v4.json`
- `Engine/VulpraEngineProcess/EngineProcessBootstrap.swift`

## Task 1: Define the v5 producer contract

Files:

- Create `Configuration/gecko-producer-v5.json`.
- Create `Tools/GeckoProducer/verify-producer.py`.
- Create `Tests/IndependentEngine/test_gecko_producer_v5.py`.
- Modify `Tests/IndependentEngine/run-portable.sh`.

Why: Make upstream, patch ordering, toolchain, targets, ABI, and forbidden
retired protocols machine-verifiable before importing or building any source.

Impact/Compatibility: Dormant producer metadata only. Normal App builds and the
v4 lock remain unchanged.

The contract must have this shape:

```json
{
  "schemaVersion": 1,
  "artifactFormatVersion": 5,
  "upstream": {
    "repository": "https://github.com/mozilla-firefox/firefox",
    "commit": "27b462b22705a8860f7ab0d33aa5b4b658ae5932"
  },
  "patchSeries": "Engine/GeckoPatches/v5/series.json",
  "deploymentTarget": "15.0",
  "targets": {
    "iphoneos": "aarch64-apple-ios",
    "iphonesimulator": "aarch64-apple-ios-sim"
  },
  "requiredExports": [
    "_MainProcessInit",
    "_GeckoViewOpenWindow",
    "_ChildProcessInit"
  ],
  "forbiddenRuntimeTokens": [
    "jit-ready-fd",
    "ReportJITStatusForChild",
    "WaitForJITReadySignal"
  ]
}
```

Verification:

```sh
python3 Tests/IndependentEngine/test_gecko_producer_v5.py
./Tests/IndependentEngine/run-portable.sh
```

Expected: malformed commit, missing target, duplicate export, non-iOS target,
and incomplete forbidden-token fixtures fail; the checked-in contract passes
contract-only validation. Patch ordering and digest failures become active in
Task 2 when the series exists.

- [ ] Write `test_gecko_producer_v5.py` with temporary valid/invalid contract
  fixtures and a failing assertion that the real verifier exists; run it and
  confirm `FAIL: missing Tools/GeckoProducer/verify-producer.py`.
- [ ] Add the JSON contract exactly as above and rerun; confirm RED now reports
  the missing verifier rather than a malformed contract.
- [ ] Implement `verify-producer.py --contract-only` using `json`, `hashlib`,
  and `pathlib`; reject unknown/missing fields, non-40-hex commits, duplicate
  targets/exports, non-iOS target triples, and missing forbidden tokens.
- [ ] Add the test to `run-portable.sh`; run both exact verification commands
  and `git diff --check`, expecting `PASS: Gecko producer v5 contract`.
- [ ] Commit only these files with
  `git commit -m "build: define reproducible Gecko v5 producer contract"`.

## Task 2: Materialize and audit the iOS patch series

Files:

- Create `Engine/GeckoPatches/v5/series.json`.
- Create reviewed patch files under `Engine/GeckoPatches/v5/`.
- Extend `Tools/GeckoProducer/verify-producer.py`.
- Extend `Tests/IndependentEngine/test_gecko_producer_v5.py`.

Why: Replace the hidden binary/source mismatch with an ordered, content-bound,
reviewable patch source of truth.

Impact/Compatibility: The historical `Patches/` tree is lineage input only.
No historical target, Helper, JIT client, or runtime fallback is restored.

Use this read-only extraction to establish candidates:

```sh
rm -rf .build/gecko-patch-audit
mkdir -p .build/gecko-patch-audit
git archive codex/vulpra-simulator-engine-producer-20260727 Patches \
  | tar -x -C .build/gecko-patch-audit
find .build/gecko-patch-audit/Patches -type f -name '*.patch' \
  | LC_ALL=C sort > .build/gecko-patch-audit/candidates.txt
```

Every `series.json` entry must contain:

```json
{
  "order": 1,
  "path": "platform/example.patch",
  "sha256": "64 lowercase hex characters",
  "owner": "engine-platform",
  "purpose": "specific iOS behavior supplied by this patch",
  "upstreamPaths": ["exact/upstream/path"]
}
```

Repair Track:

- Root cause: the distributed artifact contains unrecorded downstream changes.
- Canonical owner: ordered v5 series plus checked content digest.
- Stable repair: each applied patch is declared, hashed, cleanly applicable,
  and covered by a producer or runtime test.

Retirement Track:

- Old owner: historical branch patch tree and implicit v4 binary contents.
- Status: evidence-only, never loaded by normal producer execution.
- Deletion trigger: none in this task; branch cleanup requires separate user
  confirmation after v5 evidence is retained.

Verification:

```sh
python3 Tools/GeckoProducer/verify-producer.py \
  --contract Configuration/gecko-producer-v5.json
rg -n 'jit-ready-fd|ReportJITStatusForChild|WaitForJITReadySignal|RuntimeJITCoordinator' \
  Engine/GeckoPatches/v5 && exit 1 || true
```

- [ ] Extend the test with missing patch, reordered `order`, wrong hash,
  duplicate path, vague purpose, and forbidden-token patch fixtures; run and
  confirm the current contract-only verifier accepts at least one invalid full
  series.
- [ ] Extract candidates with the exact commands above; classify each required
  iOS build/runtime patch and copy only reviewed patches into the v5 directory.
  Split mixed process/JIT patches so retained files contain no JIT readiness
  pipe, attach, ptrace, or client coordination hunks.
- [ ] Write `series.json` in dependency order with one content digest and
  specific purpose per patch. Extend the verifier to require exact file-set
  equality between the series and directory and to recompute every SHA-256.
- [ ] Run full producer verification and the forbidden-token scan. Expected:
  `PASS: Gecko producer v5 patch series`; manually inspect `git diff --stat`
  to ensure no old App, Helper, idevice, or JIT product source was imported.
- [ ] Commit the audited patch source with
  `git commit -m "build: own audited Gecko iOS v5 patch series"`.

## Task 3: Build and package native device and Simulator artifacts

Files:

- Create `Tools/GeckoProducer/fetch-source.sh`.
- Create `Tools/GeckoProducer/apply-series.py`.
- Create `Tools/GeckoProducer/build-runtime.sh`.
- Create `Tools/GeckoProducer/package-runtime.py`.
- Extend producer tests.

Why: Build each Apple platform from source with the correct target triple and
produce a truthful format-v5 manifest.

Impact/Compatibility: Producer-only. `.build/gecko-source` and object trees are
derived and ignored. Normal App builds still restore archives.

Required command interface:

```sh
./Tools/GeckoProducer/fetch-source.sh Configuration/gecko-producer-v5.json \
  .build/gecko-source
python3 Tools/GeckoProducer/apply-series.py \
  --contract Configuration/gecko-producer-v5.json \
  --source .build/gecko-source
./Tools/GeckoProducer/build-runtime.sh iphoneos .build/gecko-source
./Tools/GeckoProducer/build-runtime.sh iphonesimulator .build/gecko-source
python3 Tools/GeckoProducer/package-runtime.py \
  --contract Configuration/gecko-producer-v5.json \
  --platform iphonesimulator --dist .build/gecko-source/obj-aarch64-apple-ios-sim/dist \
  --mozconfig .build/gecko-source/.mozconfig-vulpra-iphonesimulator \
  --output .build/vulpra-engine-ios-simulator-native-arm64-v5.tar.gz
```

`build-runtime.sh` must generate target-specific mozconfig. Both targets use
`--enable-application=mobile/ios`, `--enable-ios-target=15.0`, optimize,
non-debug, and no tests. Simulator uses `aarch64-apple-ios-sim` and may disable
unsupported WebRTC sources; device uses `aarch64-apple-ios`. Neither script may
run `vtool` or edit Mach-O platform metadata. It writes the exact selected
configuration to `.mozconfig-vulpra-iphoneos` or
`.mozconfig-vulpra-iphonesimulator` under the source directory and passes that
path through `MOZCONFIG`; packaging fails if that file is missing.

The v5 manifest must add these fields:

| Field | Required value |
| --- | --- |
| `formatVersion` | integer `5` |
| `source.repository` | `https://github.com/mozilla-firefox/firefox` |
| `source.commit` | `27b462b22705a8860f7ab0d33aa5b4b658ae5932` |
| `patchSet.series` | `Engine/GeckoPatches/v5/series.json` |
| `patchSet.sha256` | SHA-256 of the exact checked-in series file bytes |
| `producer.repository` | `https://github.com/Gjcgghgcbbjj/vulpra-browser` |
| `producer.commit` | local fixture zero commit or exact `GITHUB_SHA` |
| `producer.workflowRunId` | local fixture `0` or positive `GITHUB_RUN_ID` |
| `configurationSHA256` | SHA-256 of exact `gecko-producer-v5.json` bytes |
| `build.mozconfigSHA256` | SHA-256 of exact generated target mozconfig bytes |
| `build.xcodeBuild` | nonempty build identifier from pinned Xcode |
| `build.sdkBuild` | nonempty build identifier from the selected SDK |
| `build.platform` | `iphoneos` or `iphonesimulator` |
| `build.targetTriple` | the contract triple for `build.platform` |
| `build.architecture` | `arm64` |
| `build.deploymentTarget` | `15.0` |

Local fixtures use producer commit `0000000000000000000000000000000000000000`
and run ID `0`; CI requires real `GITHUB_SHA` and `GITHUB_RUN_ID`.

Verification:

```sh
python3 Tests/IndependentEngine/test_gecko_producer_v5.py
./Tests/IndependentEngine/run-portable.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck Tools/GeckoProducer/fetch-source.sh \
    Tools/GeckoProducer/build-runtime.sh
fi
if rg -n 'vtool|set-build-version' Tools/GeckoProducer; then exit 1; fi
git diff --check
```

- [ ] Add fixture tests for detached upstream checkout, ordered clean patch
  application, target-specific mozconfig, no vtool invocation, safe tar paths,
  and manifest content identity; verify RED for all four missing tools.
- [ ] Implement `fetch-source.sh` with `git init`, pinned shallow fetch,
  detached checkout, and exact HEAD verification; it must reject a dirty or
  pre-populated destination.
- [ ] Implement `apply-series.py`, `build-runtime.sh`, and
  `package-runtime.py` with the interfaces and manifest fields above. Package
  XUL, dylibs, three ABI headers, resources, licenses, and notices only.
- [ ] Run producer fixture tests, portable gates, `shellcheck` when available,
  and `git diff --check`; expected output includes both target triples and
  `PASS: native v5 packaging fixtures`.
- [ ] Commit with
  `git commit -m "build: produce native Gecko v5 runtime artifacts"`.

## Task 4: Add the dual-platform GitHub producer

Files:

- Create `.github/workflows/produce-gecko-v5.yml`.
- Extend `Tests/IndependentEngine/test_gecko_producer_v5.py`.

Why: Make GitHub the reproducible macOS/Xcode producer and preserve complete
build evidence for both native targets.

Impact/Compatibility: New manual workflow only. It does not change App artifact
selection yet.

Workflow requirements:

- `workflow_dispatch` input `release_tag`, default
  `vulpra-engine-v5-candidate`;
- Boolean `workflow_dispatch` input `publish_release`, default `false`;
- matrix platform `iphoneos` and `iphonesimulator`;
- pinned `/Applications/Xcode_26.4.1.app` and macOS 26 runner;
- source fetch, patch verification/application, bootstrap, native build,
  package, and artifact verification;
- upload archives, manifest, environment, patch verification, symbols, and
  build logs;
- final job downloads both products and verifies identical source/patch/config
  identity and distinct platforms/content;
- only `publish_release=true` uploads the verified pair to the named GitHub
  prerelease, without `--clobber` unless existing asset hashes match.

Verification:

```sh
python3 Tests/IndependentEngine/test_gecko_producer_v5.py
gh workflow run produce-gecko-v5.yml \
  --ref fix/browser-performance-20260729 \
  -f release_tag=vulpra-engine-v5-candidate \
  -f publish_release=false
producer_run_id="$(gh run list --workflow produce-gecko-v5.yml \
  --branch fix/browser-performance-20260729 --event workflow_dispatch \
  --limit 1 --json databaseId --jq '.[0].databaseId')"
test -n "$producer_run_id"
gh run watch "$producer_run_id" --exit-status
```

- [ ] Add structural workflow tests for runner, matrix, Xcode, target tools,
  manifests, cross-target comparison, retention, and prerelease upload.
- [ ] Run `python3 Tests/IndependentEngine/test_gecko_producer_v5.py` and
  confirm RED because `.github/workflows/produce-gecko-v5.yml` is missing.
- [ ] Implement the workflow with one build job per target and one promotion
  job. Never call `produce-simulator-artifact.sh` or `vtool`.
- [ ] Run portable tests and YAML inspection locally, then commit with
  `git commit -m "ci: build native Gecko v5 device and Simulator runtimes"` and
  push the branch because GitHub cannot execute unpushed workflow content.
- [ ] Dispatch and watch the producer with the exact commands above. Record the
  resolved run ID and archive hashes from downloaded manifests. On failure,
  repair only the producer/source owner in a new commit, push, and rerun until
  the external GREEN result is obtained.

## Task 5: Export Gecko child lifecycle at the semantic owner

Files:

- Modify the v5 patches for:
  `ipc/glue/GeckoChildProcessHost.h`,
  `ipc/glue/GeckoChildProcessHost.cpp`,
  `toolkit/xre/IOSBootstrap.h`,
  `toolkit/xre/IOSBootstrap.mm`, and
  `widget/uikit/GeckoViewSwiftSupport.h`.
- Modify `Engine/GeckoPatches/v5/series.json` hashes/purposes.
- Extend producer tests.

Why: Report requested, platform-created, bootstrap-acknowledged, IPC-connected,
failed, and terminated states from Gecko instead of inferring them in App code.

Impact/Compatibility: Adds an internal ABI surface. Existing MainProcessInit,
ChildProcessInit, and GeckoViewOpenWindow signatures stay binary-compatible.

The Objective-C callback contract must use fixed-width identifiers and a closed
stage enum:

```objc
typedef NS_ENUM(int32_t, GeckoChildProcessStage) {
  GeckoChildProcessRequested = 1,
  GeckoChildProcessExtensionConnected = 2,
  GeckoChildProcessBootstrapAcknowledged = 3,
  GeckoChildProcessIPCConnected = 4,
  GeckoChildProcessFailed = 5,
  GeckoChildProcessTerminated = 6,
};

typedef NS_ENUM(int32_t, GeckoChildProcessFailureCode) {
  GeckoChildProcessFailureNone = 0,
  GeckoChildProcessFailureExtensionStart = 1,
  GeckoChildProcessFailureXPCTransport = 2,
  GeckoChildProcessFailureBootstrapReply = 3,
  GeckoChildProcessFailureProcessLaunch = 4,
  GeckoChildProcessFailureIPCBeforeConnection = 5,
};

@protocol GeckoChildProcessLifecycleObserver <NSObject>
- (void)childProcessDidChangeWithLaunchID:(uint64_t)launchID
                                  childID:(int32_t)childID
                                      pid:(int32_t)pid
                              processType:(NSString *)processType
                                    stage:(GeckoChildProcessStage)stage
             monotonicTimestampNanoseconds:(uint64_t)monotonicTimestampNanoseconds
                              failureCode:(GeckoChildProcessFailureCode)failureCode
                                   reason:(NSString * _Nullable)reason;
@end
```

The parent Gecko process samples `clock_gettime(CLOCK_MONOTONIC, ...)` at each
semantic transition and emits nanoseconds on that single clock domain. Tests
reject zero or regressive timestamps for one launch; wall-clock time is never
used for lifecycle ordering. Non-failed events require failure code `none` and
no reason. Failed events require one nonzero closed code; optional diagnostic
reason text is capped at 160 UTF-8 bytes and cannot contain URLs or browsing
data.

Event ownership is exact:

| Stage | Gecko emission point |
| --- | --- |
| `requested` | `GeckoChildProcessHost::AsyncLaunch`, after `PrepareLaunch` succeeds and before launcher dispatch |
| `extensionConnected` | successful `ExtensionKitProcess::StartProcess` callback after the process resource is stored |
| `bootstrapAcknowledged` | valid bootstrap reply after positive PID validation and before resolving the launch promise |
| `ipcConnected` | `GeckoChildProcessHost::OnChannelConnected`, after the process state becomes connected |
| `failed` | `GeckoChildProcessHost::OnProcessLaunchError`, once per pre-connection launch failure |
| `terminated` | `GeckoChildProcessHost` destruction, before ExtensionKit/XPC/process resources are released |

The host stores per-launch emitted-stage/outcome bits so callback races cannot
produce duplicate outcomes. The launcher carries the host's launch ID and
child identity; it does not allocate a second ID.

The main Swift runtime object is the observer. Gecko emits:

- `requested` when AsyncLaunch accepts one child ID/type;
- `extensionConnected` when the iOS ExtensionKit process has been obtained;
- `bootstrapAcknowledged` after a valid PID reply;
- `ipcConnected` from `OnChannelConnected`;
- `failed` from launch rejection or a channel error before `ipcConnected`, with
  a bounded reason code;
- `terminated` when a connected process is invalidated/observed dead or when
  platform resources are released after a prior `failed` outcome.

Repair Track: `ipcConnected`, not PID reply, is the success signal.

Retirement Track: replace the existing JIT-oriented
`childProcessDidStartWithPID:processType:` callback and remove all pipe/status
exports. Do not retain both callbacks.

Verification:

```sh
python3 Tests/IndependentEngine/test_gecko_producer_v5.py
python3 Tools/GeckoProducer/verify-producer.py \
  --contract Configuration/gecko-producer-v5.json
if rg -n 'jit-ready-fd|ReportJITStatusForChild|WaitForJITReadySignal|RuntimeJITCoordinator' \
  Engine/GeckoPatches/v5; then exit 1; fi
git diff --check
```

- [ ] Add source-contract tests that require every stage at the exact Gecko
  owner method and reject PID callback/JIT tokens; run RED against the current
  patch series.
- [ ] Modify the process-host patches to allocate a monotonic 64-bit launch ID,
  carry existing child ID/type, and emit the six events without changing
  process-state transitions.
- [ ] Modify the Swift support/bootstrap patches to forward the typed observer
  call and remove `ReportJITStatusForChild`, `jit-ready-fd`, and the five-second
  wait. `ChildProcessInitImpl` calls `JS::DisableJitBackend()` before
  `XRE_InitChildProcess` without waiting on a host-owned signal.
- [ ] Run full patch verification, commit with
  `git commit -m "engine: expose typed Gecko child lifecycle"`, and push the
  branch so the changed patch series is available to GitHub.
- [ ] Dispatch the producer twice from the same pushed commit: first with
  `publish_release=false`, then, only after it is green, with
  `publish_release=true`. For each run, verify both XULs export the lifecycle
  ABI/header while `strings XUL` contains none of the forbidden JIT tokens.
  Record both run IDs; repair any producer failure in a new scoped commit, then
  restart both runs from that new commit.

## Task 6: Track child lifecycle inside VulpraEngineKit

Files:

- Create
  `Engine/VulpraEngineKit/Internal/Process/EngineChildProcessLifecycle.swift`.
- Modify `EngineABIBridge.h`, `EngineABIBridge.mm`, `EngineABI.swift`, and
  `VulpraEngineRuntime.swift`.
- Modify `Tests/VulpraEngineKitTests/VulpraEngineKitTests.swift`.
- Create/extend `Tests/IndependentEngine/test_child_process_lifecycle.py`.

Why: Enforce legal lifecycle transitions and terminal closure without exposing
private process details to the public App API.

Impact/Compatibility: Internal EngineKit ABI changes together with Gecko v5.
Public `EngineRuntime`, `EngineSession`, and App APIs remain unchanged.

Use these internal Swift types:

```swift
enum EngineChildProcessStage: Int32, Sendable {
    case requested = 1
    case extensionConnected = 2
    case bootstrapAcknowledged = 3
    case ipcConnected = 4
    case failed = 5
    case terminated = 6
}

enum EngineChildProcessFailureCode: Int32, Sendable {
    case none = 0
    case extensionStart = 1
    case xpcTransport = 2
    case bootstrapReply = 3
    case processLaunch = 4
    case ipcBeforeConnection = 5
    case terminatedBeforeOutcome = 6
    case invalidTransition = 7
}

struct EngineChildProcessEvent: Equatable, Sendable {
    let launchID: UInt64
    let childID: Int32
    let processIdentifier: Int32?
    let processType: String
    let stage: EngineChildProcessStage
    let monotonicTimestampNanoseconds: UInt64
    let failureCode: EngineChildProcessFailureCode
    let reason: String?
}
```

`EngineChildProcessLifecycle` accepts events on the runtime owner executor,
rejects unknown/duplicate/regressive transitions, records the latest state by
launch ID, and produces an internal failure when a request terminates without
ever connecting or failing. PID `0` maps to nil. Type and reason strings are
copied during the ABI call.

The legal success path is `requested -> extensionConnected ->
bootstrapAcknowledged -> ipcConnected -> terminated`. `failed` may replace any
pre-connection next step, and a later `terminated` only closes resources; it
does not create a second outcome. If `terminated` arrives before either
`ipcConnected` or `failed`, the tracker records one synthetic
`terminated-before-outcome` internal failure before closing. A launch ID can
therefore enter exactly one outcome set: connected or failed, never both.

The C callback signature is:

```c
typedef void (*VulpraEngineChildProcessHandler)(
    void *context, uint64_t launchID, int32_t childID, int32_t pid,
    const void *processType, int32_t stage,
    uint64_t monotonicTimestampNanoseconds, int32_t failureCode,
    const void *reason);

void *VEKRuntimeCreate(void *context, VulpraEngineEventHandler eventHandler,
                       VulpraEngineChildProcessHandler childProcessHandler);
```

`eventHandler` retains its current product-event behavior. The new child
handler is main-runtime internal plumbing only; child-side `VEKRuntime` objects
created by `VEKChildProcessStart` pass a null child handler and never become a
second lifecycle owner.

The existing 20-second EngineKit startup watchdog remains a bounded failure
guard, never a readiness signal. It cannot replay activation/navigation or
start another process. Before runtime-ready, a typed child failure fails startup
immediately; a watchdog expiry reports `engine-bootstrap-timeout` plus anonymous
open launch IDs (if any). After runtime-ready, child termination is recorded as
an internal engine failure for the owning session/recovery surface without
changing App-visible APIs in R0.

Verification:

```sh
python3 Tests/IndependentEngine/test_child_process_lifecycle.py
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
git diff --check
```

- [ ] Add Swift tests for the successful sequence, failure before connection,
  duplicate event, stage/timestamp regression, termination after connection,
  and unknown stage; add a structural test rejecting public PID/process type;
  run RED.
- [ ] Add the internal lifecycle owner and update `VEKRuntimeCreate` plus
  `VEKRuntime` to conform to the Gecko observer and forward borrowed strings
  through the C handler.
- [ ] Update Swift ABI declarations and `VulpraEngineRuntime` construction to
  copy and route child events on its existing owner executor. Log launch ID,
  child ID, type, stage, monotonic timestamp, failure code, and bounded reason
  without URL or browsing data.
- [ ] Run portable tests and structural public-boundary scans. Expected: legal
  lifecycle fixtures pass and no public EngineKit file contains PID or Gecko
  process-role API.
- [ ] Commit with
  `git commit -m "engine: track child process lifecycle internally"`, push, and
  run EngineKit tests on GitHub Simulator. Invalid transition tests must produce
  one typed internal failure; external failure requires a new scoped fix commit.

## Task 7: Type the ExtensionKit request and retire dead bootstrap ownership

Files:

- Create `Engine/VulpraEngineProcess/EngineProcessRequest.swift`.
- Modify producer patches that create the NSExtensionItem userInfo.
- Modify `VulpraEngineProcessHost.swift` and `EngineProcessExtension.swift`.
- Delete `EngineProcessBootstrap.swift`.
- Modify `Tests/IndependentEngine/test_internal_boundaries.py` and process
  lifecycle tests.

Why: Correlate ExtensionKit resource logs with Gecko launch identity and remove
the unused argument-based role/token/parent PID model.

Impact/Compatibility: The endpoint remains a native NSXPCListenerEndpoint. New
metadata is versioned and transported in the same NSExtensionItem userInfo.

Use these exact keys:

```text
VulpraEngineProcessProtocolVersion = 2
VulpraXPCListenerEndpoint
VulpraChildLaunchID
VulpraGeckoChildID
VulpraGeckoProcessType
```

`EngineProcessRequest` validates protocol version `2`, UInt64 launch ID,
positive Int32 child ID, nonempty bounded process type, and endpoint type. It
does not convert Gecko process type into a Vulpra-owned closed role enum.

`VulpraEngineProcessHost.start` changes from `Bool` to `throws`; its only local
errors are unavailable private connection bridge or missing native XPC handle.
It still does not claim semantic child readiness.

Repair Track: endpoint and identity arrive in one typed ExtensionKit request.

Retirement Track: delete command-line role, endpoint token, and parent-PID
parsing plus tests that require them. No compatibility exception exists because
the model has no active consumer.

Verification:

```sh
python3 Tests/IndependentEngine/test_internal_boundaries.py
python3 Tests/IndependentEngine/test_child_process_lifecycle.py
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
git diff --check
```

- [ ] Replace current structural expectations with tests for the v2 userInfo
  request, malformed metadata cancellation, structured correlated logs, and
  absence of `--vulpra-process-role`; run RED.
- [ ] Patch the Gecko NSExtension request creator to add version/launch/child/type
  metadata while preserving the native endpoint and NSXPCCoder path.
- [ ] Implement `EngineProcessRequest`, use it in the extension, change ProcessHost
  to `throws`, and delete `EngineProcessBootstrap.swift` plus its stale tests.
- [ ] Run all portable tests and confirm structural request/retirement checks
  are green.
- [ ] Commit with
  `git commit -m "engine: type ExtensionKit child requests"`, push, and run a
  one-attempt GitHub Simulator smoke. Logs must correlate request
  received/connected/released by launch ID and child ID without a fixed role
  count or ready claim.

## Task 8: Remove caller-side activation replay

Files:

- Modify `App/Browser/BrowserTab.swift`.
- Modify `App/Browser/BrowserViewController.swift`.
- Modify `Tests/Browser/test-browser-client.py`.

Why: Remove the App-side workaround after process lifecycle is observable at
the correct owner.

Impact/Compatibility: User-triggered retry/reload and ordinary selected-tab
`setActive`/`setFocused` behavior remain. Only per-load reassertion is removed.

Retire:

```text
didReassertActivationForLoad
reassertActivationIfNeeded
the BrowserViewController call to that helper
tests requiring extra SetActive/SetFocused dispatch
```

Preserve:

```text
BrowserTab.retry(settings:)
BrowserTab.setActive(_:)
selected-tab activation on actual scene/tab transitions
```

Verification:

```sh
python3 Tests/Browser/test-browser-client.py
./Tests/Browser/run-portable.sh
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
git diff --check
```

- [ ] Change the browser contract test to reject all retired tokens and require
  user retry plus selected-tab activation; run RED on the current source.
- [ ] Remove the per-load property/helper/call and any load lifecycle mutation
  used only by that path. Do not alter navigation or progress coalescing.
- [ ] Search the repository for activation delays/replay and classify every
  remaining hit as real scene/tab state, user retry, test text, or stale logic;
  remove stale logic rather than allow-listing it.
- [ ] Run Browser, IndependentEngine, and RuntimeShell portable suites and
  verify only real scene/tab activation and user retry remain.
- [ ] Commit with
  `git commit -m "fix: retire page-side engine activation replay"`, push, and
  run the one-attempt Simulator smoke. Lifecycle logs must close without the
  retired extra activation dispatch.

## Task 9: Add v5 artifact contracts and atomic promotion

Files:

- Create both v5 artifact contract JSON files.
- Create `Tools/Engine/promote-engine-artifacts.py`.
- Extend `verify-engine-artifact.py`.
- Create `Tests/IndependentEngine/test_engine_artifact_v5.py`.
- Modify staging, lock, ABI inventory, workflows, and cutover gates.

Why: Promote only a matching, verified native pair and make source/patch/build
identity part of the App dependency lock.

Producer recovery boundary: A successful expensive native build is immediately
materialized as a deterministic, content-inventoried `dist` packaging-input
snapshot and uploaded before final packaging. Normal packaging re-extracts this
snapshot, so the recovery path is continuously exercised. A manual run may set
`reuse_build_run_id` to skip fetch/patch/bootstrap/build only when the snapshot
matches the current source, patch series, producer contract, generated
mozconfig, build script, target, and Xcode/SDK identity. Packaging or workflow
changes do not invalidate the compiled snapshot; build-input changes do. The
snapshot contains regular file bytes only, never source-tree symlinks or a
portable whole-object-directory cache.

A snapshot-reuse run is recovery evidence for the original compilation and
does not count as the second independent repeat build. The repeat-build gate
still requires two distinct native compilations from the same commit and build
inputs. If downstream packaging fails after either compilation, a reuse run of
that compilation may supply its successful final artifact without repeating
the expensive compile.

Impact/Compatibility: v4 remains selected until the promotion command succeeds
with real producer artifacts. After promotion, App and package builds select
only v5; there is no runtime fallback.

Resolve the two successful same-commit producer runs and promote with:

```sh
mapfile -t producer_run_ids < <(gh run list --workflow produce-gecko-v5.yml \
  --branch fix/browser-performance-20260729 --event workflow_dispatch \
  --commit "$(git rev-parse HEAD)" --status success --limit 2 \
  --json databaseId --jq '.[].databaseId')
test "${#producer_run_ids[@]}" -eq 2
producer_run_id="${producer_run_ids[0]}"
test -n "$producer_run_id"
python3 Tools/Engine/promote-engine-artifacts.py \
  --release-tag vulpra-engine-v5-candidate \
  --producer-run-id "$producer_run_id" \
  --device-archive .build/candidate/vulpra-engine-ios-arm64-v5.tar.gz \
  --simulator-archive .build/candidate/vulpra-engine-ios-simulator-native-arm64-v5.tar.gz \
  --lock Configuration/engine-artifact-lock.json
```

The tool reads both manifests, computes archive hashes, rejects
source/patch/config mismatch or same-platform binaries, and writes the complete
lock atomically. The resolved workflow run must equal the run recorded in both
manifests.

The v5 verifier requires format 5 provenance, correct target triple/platform,
required lifecycle header/export, and absence of forbidden JIT tokens. Its
repeat-build comparison normalizes only archive metadata and
`producer.workflowRunId`, then requires equal code, resources, ABI headers,
source, patch, configuration, and remaining manifest fields for the same
platform. Artifact IDs are content-bound with platform-specific prefixes.
`Configuration/engine-cutover-gates.json` records both repeat producer run IDs
and the selected published run ID so later evidence writeback does not infer
them from branch ordering.

Verification:

```sh
python3 Tests/IndependentEngine/test_engine_artifact_v5.py
python3 Tests/IndependentEngine/test_xcode_staging.py
python3 Tests/IndependentEngine/test_cutover_readiness.py --require-cutover
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
git diff --check
```

- [ ] Add v5 fixture tests for provenance mismatch, patch mismatch, wrong target,
  vtool-identical sections, forbidden token, missing lifecycle ABI, unsafe
  archive, and atomic promotion failure; run RED.
- [ ] Implement v5 contracts/verifier and promotion tool. Keep v4 verifier
  support only while v4 remains selected during this task.
- [ ] Upload a verified build snapshot before packaging and prove that a
  `reuse_build_run_id` run rejects unsafe links, tampered content, and every
  mismatched build identity while avoiding native recompilation.
- [ ] Download both successful same-commit producer runs from Task 5. Compare
  their normalized device outputs and normalized Simulator outputs, then run
  promotion with the selected run's actual ID and inspect the resulting lock.
  Update `Configuration/Base.xcconfig`, staging/relocation, release build,
  workflows, inventory, and cutover gates to consume the v5 platform entry
  directly.
- [ ] Run all portable suites and verify manifest, archive, source, patch,
  configuration, run, and platform identities match.
- [ ] Commit with
  `git commit -m "build: promote native Gecko v5 artifacts atomically"`, push,
  and run one GitHub Simulator smoke from the promoted lock. Any failure must
  repair the reported producer/staging owner in a new commit.

## Task 10: Extract and enforce the 20-attempt R0 Simulator gate

Files:

- Create `Tools/CI/run-simulator-navigation.sh`.
- Create `Tools/CI/summarize-r0-engine-gate.py`.
- Modify `.github/workflows/simulator-smoke.yml`.
- Create `Tests/IndependentEngine/test_r0_gate_contract.py`.
- Modify `Tests/IndependentEngine/run-portable.sh` and runtime hardening tests.

Why: Convert one-off screenshots and log greps into repeated, closed lifecycle
and performance evidence.

Impact/Compatibility: Default manual smoke may run one attempt. R0 acceptance
uses input `r0_attempts=20`; every attempt creates, installs on, boots, and
deletes a fresh Simulator.

Each attempt writes one JSON object containing:

```json
{
  "attempt": 1,
  "locationMatched": true,
  "pageCompleted": true,
  "renderedDarkPixels": 12266,
  "loadToCompleteMs": 12863,
  "appSurvived": true,
  "crashCount": 0,
  "lifecycleEvents": [
    {
      "launchID": 1,
      "childID": 1,
      "processType": "content",
      "pid": null,
      "stage": "requested",
      "monotonicTimestampNanoseconds": 1000000000,
      "failureCode": "none",
      "reason": null
    },
    {
      "launchID": 1,
      "childID": 1,
      "processType": "content",
      "pid": null,
      "stage": "extensionConnected",
      "monotonicTimestampNanoseconds": 1002000000,
      "failureCode": "none",
      "reason": null
    },
    {
      "launchID": 1,
      "childID": 1,
      "processType": "content",
      "pid": 321,
      "stage": "bootstrapAcknowledged",
      "monotonicTimestampNanoseconds": 1003000000,
      "failureCode": "none",
      "reason": null
    },
    {
      "launchID": 1,
      "childID": 1,
      "processType": "content",
      "pid": 321,
      "stage": "ipcConnected",
      "monotonicTimestampNanoseconds": 1005000000,
      "failureCode": "none",
      "reason": null
    }
  ],
  "requestedLaunchIDs": [1],
  "connectedLaunchIDs": [1],
  "failedLaunchIDs": [],
  "openLaunchIDs": []
}
```

The summarizer requires attempts `1...N` exactly once, all functional Booleans,
nonblank threshold, zero crashes, and valid ordered lifecycle events. It derives
the four launch-ID arrays from events, rejects a stored/derived mismatch, zero
or regressive timestamps, duplicate requests, an open launch, or a launch in
both outcome sets. For R0 it also requires 20 successes, p95 load-to-complete at
most 15000 ms, and max at most 30000 ms. It never requires a fixed number of
process requests.

Verification:

```sh
python3 Tests/IndependentEngine/test_r0_gate_contract.py
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
git diff --check
gh workflow run simulator-smoke.yml \
  --ref fix/browser-performance-20260729 -f r0_attempts=20
simulator_run_id="$(gh run list --workflow simulator-smoke.yml \
  --branch fix/browser-performance-20260729 --event workflow_dispatch \
  --limit 1 --json databaseId --jq '.[0].databaseId')"
test -n "$simulator_run_id"
gh run watch "$simulator_run_id" --exit-status
rm -rf .build/r0-engine-gate
gh run download "$simulator_run_id" -n r0-engine-gate \
  -D .build/r0-engine-gate
python3 Tools/CI/summarize-r0-engine-gate.py --attempts 20 \
  --input .build/r0-engine-gate/attempts \
  --output .build/r0-engine-gate/reverified-summary.json
```

- [ ] Add fixture tests for missing/duplicate attempt, blank screenshot, crash,
  missing/duplicate request event, zero/regressive timestamp, stored/derived
  set mismatch, open child request, child in both outcome sets, p95 failure,
  max failure, and valid 20-attempt summary; run RED.
- [ ] Extract the existing fixture/server/simctl/log/screenshot logic into
  `run-simulator-navigation.sh` with parameters for app, runtime, device type,
  attempt index, output directory, and URL. Remove duplicated inline logic from
  YAML.
- [ ] Implement the summarizer and workflow loop. Start log collection before
  launch, preserve per-attempt artifacts, and clean each Simulator in a trap.
- [ ] Run fixture and portable tests, then commit with
  `git commit -m "ci: enforce repeated R0 engine lifecycle gate"` and push the
  workflow/harness candidate.
- [ ] Run `simulator-smoke.yml` with `r0_attempts=20`. Download evidence and
  verify `r0_attempts=20`, `r0_passed=20`, `p95<=15000`, `max<=30000`, and zero
  open lifecycle requests. Repair only the owner indicated by typed failure in
  a new commit and repeat the full gate.

## Task 11: Prove packages, retire v4 paths, and sync architecture records

Files:

- Modify `.github/workflows/build-ios-packages.yml`,
  `Tools/Engine/validate-ipa.py`, `Tests/Browser/test-package-workflow.py`,
  `Tests/Browser/test-package-identity.py`,
  `Tests/RuntimeShell/test-package-validator.py`, and
  `Tests/IndependentEngine/test_cutover_readiness.py`.
- Delete vtool producer/workflow/test, `test_artifact_contract.py`, and both v4
  contracts.
- Modify `README.md`,
  `docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md`, and
  `docs/aegis/baseline/2026-07-27-independent-engine-package-baseline.md`.

Why: Finish both repair and retirement tracks. A green v5 path is incomplete
while the old artifact producer, dead contracts, or inaccurate architecture
record remain active.

Impact/Compatibility: Normal builds and packages select the promoted v5 device
artifact. Bundle/version/profile/signature/resource behavior and user data stay
unchanged. Repository v4 build paths are deleted only after producer and
20-attempt gates are green; published v4 release assets remain external
rollback artifacts, never a runtime fallback.

Repair Track:

- Build IPA/TIPA with the promoted v5 device artifact.
- Verify package runtime matches the v5 lock and contains required ABI.
- Preserve bundle/version/profile/signature/resource validation.

Retirement Track:

- Delete vtool script/workflow/test and both v4 contracts.
- Remove v4, vtool policy, old PID callback, JIT readiness, dead bootstrap, and
  activation replay references from active configuration/source/tests.
- Do not delete remote branches or GitHub artifacts in this task.

Anti-Entropy Declaration:

- Deletion class: internal code, contract-carrying code, and derived artifact
  references.
- New canonical owner: v5 producer/contracts/lifecycle.
- Preserved behavior: App builds, packages, navigation, user retry, user data.
- Retired behavior: metadata-converted Simulator, hidden JIT wait, dead process
  argument model, automatic activation replay.
- Source-of-truth data risk: none; no user records are deleted.
- Confirmation required: no for listed repository paths; yes for any later
  remote branch/artifact deletion.

Verification:

```sh
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
test ! -e Tools/Engine/produce-simulator-artifact.sh
test ! -e .github/workflows/produce-simulator-artifact.yml
test ! -e Tests/IndependentEngine/test_simulator_producer.py
test ! -e Tests/IndependentEngine/test_artifact_contract.py
test ! -e Configuration/engine-artifact-v4.json
test ! -e Configuration/engine-artifact-simulator-v4.json
if rg -n 'apple-vtool-set-build-version-iossim-15|produce-simulator-artifact|engine-artifact-(simulator-)?v4|vulpra-engine-v4-candidate|jit-ready-fd|ReportJITStatusForChild|EngineProcessBootstrap|reassertActivationIfNeeded' \
  App Engine/VulpraEngineKit Engine/VulpraEngineProcess Engine/GeckoPatches \
  Tools/Release .github README.md; then exit 1; fi
git diff --check
gh workflow run build-ios-packages.yml \
  --ref fix/browser-performance-20260729 \
  -f engine_release_tag=vulpra-engine-v5-candidate
package_run_id="$(gh run list --workflow build-ios-packages.yml \
  --branch fix/browser-performance-20260729 --event workflow_dispatch \
  --commit "$(git rev-parse HEAD)" --limit 1 \
  --json databaseId --jq '.[0].databaseId')"
test -n "$package_run_id"
gh run watch "$package_run_id" --exit-status
```

The final `rg` must have no runtime/build-path matches. v5 contract tests and
producer metadata continue to name forbidden tokens as negative assertions;
historical docs may describe retired evidence, but neither is a runtime owner.

- [ ] Change package/cutover tests to require v5 device provenance and reject
  every retired active-path token.
- [ ] Run the three portable suites and confirm RED while v4/vtool files still
  exist or package validation still accepts v4 provenance.
- [ ] Switch the package workflow and local package validators to the v5 lock.
  Keep this local until repository retirement is part of the same cutover
  candidate; do not dispatch a workflow for an unpushed revision.
- [ ] Delete the listed v4/vtool source, workflow, tests, and contracts; update
  portable gates so they prove absence rather than silently stop checking. Run
  every portable suite and `git diff --check`, then commit the cutover with
  `git commit -m "engine: complete trustworthy Gecko v5 cutover"`, push, and
  dispatch the package workflow with the exact commands above. Download IPA/TIPA
  and verify package hashes, ABI, entitlements, profiles, resources, and absence
  of retired payloads. A failure creates a scoped fix commit, push, and full
  package rerun before proceeding.
- [ ] With the two producer run IDs, the Task 10 20-attempt Simulator run ID,
  and the green package run ID, use `aegis:recording-architecture-decisions` to
  amend ADR-0004 and update the independent-engine baseline with only actual
  evidence. Run `python3 /root/.codex/aegis/scripts/aegis-workspace.py check
  --root .`, `python3 Tests/IndependentEngine/test_cutover_readiness.py
  --require-r0-complete`, every portable suite, and `git diff --check`; commit with
  `git commit -m "docs: record trustworthy Gecko v5 evidence"` and push. Do not
  claim physical-device runtime verification.

## 7. Final Completion Check

Before claiming R0 complete:

1. Run `aegis:verification-before-completion` with
   `ArchitectureReviewRequired: yes`.
2. Confirm all 11 task commits are present and no unrelated branch content was
   merged.
3. Confirm producer, Simulator, and package run URLs are recorded.
4. Confirm the 20-attempt summary and every per-attempt JSON are downloadable.
5. Confirm the formal branch is clean and pushed.
6. Report physical-device runtime as unverified, not passed.
7. Do not begin the R1 SQLite/browsing-context plan until the R0 evidence gate
   is green.

## 8. Risks and Stop Conditions

- If the audited patch series cannot cleanly apply to the pinned upstream,
  stop and repair/rebase patch ownership; do not change upstream silently.
- If a lifecycle event cannot be emitted from Gecko's true process transition,
  return to architecture review; do not synthesize it from a timer.
- If removing JIT handshake prevents interpreter-mode content startup, inspect
  the producer patch and supported Gecko JIT-disable path; do not restore the
  retired client coordinator as a fallback.
- If v5 changes device packaging, preserve v4 packages as external release
  artifacts but do not add runtime selection logic.
- If migration work touches persistent user records, stop under the data
  destruction guard and request separately scoped confirmation.
- If GitHub runner variance alone violates timing while all functional/lifecycle
  gates pass, collect at least three full 20-attempt runs before proposing a
  revised performance threshold. Threshold revision requires design review,
  not an inline workflow edit.

## 9. Deferred Work

After R0 passes, write separate plans for:

- R1 indexed SQLite repositories, browsing context, private zero-persistence,
  omnibox, scrolling, and memory-pressure gates;
- R2 extension manager, package verification, capability broker, and
  compatibility matrix;
- R3 containers, workspaces, automation, and encrypted sync security design.

These are intentionally absent from R0 implementation tasks.
