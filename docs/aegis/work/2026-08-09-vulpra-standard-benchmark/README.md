# 标准 benchmark 基础设施（长期路线 C）

## 目标

参照 Chrome（Catapult/perf 看板）、Firefox（Raptor → Perfherder）、Safari（XCTMetric）的自动化做法，为 Vulpra 建立**可重复、可对比的标准 benchmark**：固定版本的第三方基准（Speedometer / MotionMark / JetStream），在 iOS Simulator 上自动运行、自动采集分数、以 gate 形式回归，且分数可在同一 engine 快照上跨构建比较。

本次交付的是三层路线中的 C（标准 benchmark，长期）基础设施：

- A 一键自测（30s 出 p95/max/渲染模式/内存）→ 已有 scroll/cold-start gate 覆盖
- B 真机 XCTest 自动化 → 后续（真机运行、JIT、OpenIn 真机流程仍未验证）
- **C 标准 benchmark（本次）** → Simulator 上跑固定版本第三方基准并采集分数

## 固定基准源（不可变）

| benchmark | 版本 | repository | 固定 commit | archive SHA-256 | 入口 | 自动启动 | 得分 DOM | 默认 gate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Speedometer 3.1 | 3.1 | WebKit/Speedometer | `1386415be8fef2f6b6bbdbe1828872471c5d802a` | `cfefa818…92791313` | `index.html` | `?startAutomatically=true` | `#result-number` | ✅ `enabledByDefault` |
| MotionMark 1.3.2 | 1.3.2 | WebKit/MotionMark | `0e740d50f2321d255f6176e2f57493574c735996` | `14b746f0…3c2f985` | `MotionMark/index.html` | runner 调用 `benchmarkController.startBenchmark()` | `#results .score` | ✅ `enabledByDefault` |
| JetStream 3.0 | 3.0 | WebKit/JetStream | `06785cf861ac44855f168cbbe829278c2802e6de` | `0361851e…ab16fa9` | `index.html` | `?startDelay=0` | `#result-summary .score` | ⛔ `requiresJitBackend`（默认不跑） |

基准源**永不修改**：固定 commit + SHA-256 校验后原样提取并同源伺服，保证分数跨构建可比、跨时间可回归。升级基准 = 改 `Configuration/benchmarks.json` 固定版本（提交明确审查）。

## 架构

```
Configuration/benchmarks.json        清单：设备策略、固定源、启动/得分/超时配置（schema v1）
Tools/CI/benchmark-fixture.py        fetch（下载+SHA-256+安全解包+源清单）
                                     generate（同源 runner 页：auto 启动 / controller 就绪表达式）
Engine/…/VulpraEngineSession.swift   PageTitleChanged → "Engine title: …" 公共日志（1 行）
Tools/CI/run-simulator-benchmark.sh  模拟器 harness：装 App → 开 runner URL → 等分数 title → 证据 JSON
Tools/CI/summarize-benchmark.py      语义 gate：分数>0、App 存活、launch 成功、证据链完整
Tools/CI/validate-benchmark-selection.py  选择校验：拒绝未知 id、空选择、requiresJitBackend benchmark
.github/workflows/benchmark-ci.yml   手动触发：恢复 engine → 构建/复用 App → fetch+generate → 逐 benchmark 跑 gate
Tests/IndependentEngine/test_benchmark_contract.py    portable 契约（清单/生成器/安全 tar/summarizer/JS 模拟/接线）
```

### 分数如何从页面到 gate（无 JS 注入通道）

1. runner 页与基准**同源**（同一 `http.server` 根），`/runner/<id>.html` 用 iframe 载入 `/benchmarks/<id>/…`。
2. runner 轮询 iframe DOM 得分节点；得到分数后 `document.title = "VulpraBenchmark <id> score=<text>"`。
3. GeckoView 对页面 title 变更发送 `GeckoView:PageTitleChanged`；App 现在记录
   `Engine title: VulpraBenchmark <id> score=… monotonic_ns=…`（`privacy: .public`）。
4. harness 的统一日志 predicate 捕获该行，解析出 `score`，写入 `attempt-NN.json`。
5. `summarize-benchmark.py` 做语义 gate：单次即有效 gate（用户规则：先单次通过，再谈重复次数），
   不设最小分数阈值——Simulator + 解释器模式是同一 engine 快照的相对回归代理，
   绝对值跨浏览器对比属于真机资格（路线 B）范畴。

### 关键决策

- **MotionMark 方向 gate**：MotionMark 的 Start 按钮在竖屏下被永久禁用
  （`updateStartButtonState`：`isInLandscapeOrientation=false` 时按钮不可点；iPad Pro 12.9
  竖屏 1024×1366 下永远如此）。runner 页与基准同源，因此**不等按钮**，而是等
  `benchmarkController.frameRateDetectionComplete === true`（`startReadyPath`/`startReadyValue`
  结构化就绪条件，无 eval/动态代码）后直接调用 `benchmarkController.startBenchmark()`
  ——帧率探测失败也会走到 `frameRateDeterminationComplete` 置位，保证不卡死；不改基准源码、
  不需要横屏。
- **设备**：App `TARGETED_DEVICE_FAMILY=1,2`（原生 iPad）；工作流选 iPad Pro 12.9-inch，
  竖屏 1024×1366 满足 Speedometer 3.1 的 850×650 最小视口，且无需无头旋转。
- **安全**：`benchmark-fixture.py fetch` 的 tar 解包是"安全 tar"——拒绝绝对路径、拒绝 `..` 穿越
  （含 strip 前完整路径校验，防止 `../evil` 借 strip 逃逸）、符号链接目标必须留在目标根内；
  portable 测试用恶意 tar 覆盖验证（曾捕获并修复 strip 逃逸缺陷）。
- **固定源一致性**：`generate` 校验 `.vulpra-source.json` 中记录的 commit 与清单一致，
  本地陈旧树会被拒绝而不是被静默伺服。
- **CI 上限**：仓库 public，GitHub job 硬上限 360 分钟；工作流 `timeout-minutes: 360`，
  默认 `attempts=1`（单次 gate），不触发 20 次重复 gate（用户规则）。

## JetStream 3.0 为何默认不跑（JIT 依赖）

JetStream 3.0 是 JS+WebAssembly 混合基准：默认 suite（`Default` tag）包含约 12 个 wasm
workload（`tsf-wasm`、`richards-wasm`、`sqlite3-wasm`、`8bitbench-wasm`、`zlib-wasm`、
`dotnet-interp/aot-wasm`、`j2cl-box2d-wasm`、`Dart-flute-todomvc-wasm`、
`Kotlin-compose-wasm`、`transformersjs-bert-wasm`、`argon2-wasm`、`gcc-loops-wasm`、
`quicksort-wasm`、`HashSet-wasm`），而 driver 在任一子测试抛错时整体中止
（`JetStreamDriver.js start()`：`catch(e) { this.reportError(...); throw e; }`），
页面还明确拒绝部分 suite（index.html："Refusing to run a partial benchmark suite"）。
因此只要有一个 wasm 测试跑不了，整个 JetStream 3.0 就不产出分数。

当前 v5 引擎在每个 Gecko 子进程（含 content 进程，基准页运行处）调用
`JS::DisableJitBackend()`（`toolkit/xre/IOSBootstrap.mm` `ChildProcessInitImpl`），
源码级证据链（固定 Firefox commit `27b462b22705a8860f7ab0d33aa5b4b658ae5932`）：

1. `js/src/vm/Initialization.cpp` `JS::DisableJitBackend()` → `js::jit::JitOptions.disableJitBackend = true`
2. `js/src/jit/JitOptions.h` `HasJitBackend()` → `return !JitOptions.disableJitBackend`
3. `js/src/wasm/WasmFeatures.cpp` `wasm::HasPlatformSupport()` → `if (!HasJitBackend()) return false`
4. `js/src/wasm/WasmFeatures.cpp` `wasm::HasSupport(cx)` → `prefEnabled && HasPlatformSupport() && …`

所以 content 进程里 `WebAssembly` 不可用（`HasSupport()==false`），完整 JetStream 3.0
gate 在当前引擎上**必挂**。因此：

- `Configuration/benchmarks.json` 中 jetstream 标记 `enabledByDefault: false`、
  `requiresJitBackend: true`，并带说明性 `notes`；
- workflow `benchmarks` 输入默认 `speedometer3,motionmark`；
- `validate-benchmark-selection.py` 拒绝显式选择 `requiresJitBackend` 的 benchmark
  （避免烧掉 5 小时必然失败的 CI gate）；
- 等 JIT 后端启用后，再恢复 JetStream 完整 suite gate（届时同步更新清单与 workflow）。


## 验证证据（本地）

- `fetch` 对 Speedometer 3.1 / MotionMark 1.3.2 走真实 codeload URL：下载 + SHA-256 校验 + 安全解包通过；
  解包树与先前人工验证的 `/tmp/bench-src` 逐字节一致（`diff -rq` 空输出）。
- JetStream 3.0 树来自同一批已验证 tarball（SHA-256 `0361851e…`），并写入源清单。
- 生成的 runner 页用 **node 执行真实 wrapper JS**（DOM mock）通过：
  Speedometer/JetStream auto-start、MotionMark controller-start（恰好调用一次 `startBenchmark`）、
  分数→title、`Error` 文本不当作分数。
- `python3 -m py_compile`（全部新增/改动 Python）+ `bash -n`（全部新增/改动 shell）通过。
- `Tests/IndependentEngine/run-portable.sh` 全套通过，含新增 `test_benchmark_contract.py`。

## 尚未完成 / 后续

- **首次真实 CI 运行**：workflow_dispatch 跑 `benchmark-ci.yml`（当前分支合入后）验证 Simulator
  上的实际分数采集与 gate 全绿（默认 `speedometer3,motionmark`，单次 gate）；这是唯一需要
  macOS/Simulator 环境的外部验证。
- **JetStream 3.0 恢复**：等引擎启用 JIT 后端（wasm 可用）后，取消 jetstream 的
  `requiresJitBackend` 阻断、把它加回默认集，再跑一次完整 suite gate。
- **真机 XCTest 自动化（路线 B）**：真机运行、JIT 真机行为、OpenIn 真机流程、App Store 分发资格。
- **跨浏览器/跨设备对比基线**：收集多轮 Simulator 分数建立回归基线；真机路线建立后可对照
  Chrome/Firefox/Safari 的公开分数。
- **分数阈值 gate**：目前不设 `minScore`；等基线稳定后可加（保留 `timeoutSeconds` 与清单扩展点）。

## 范围说明

本工作不动 20 次稳定性 gate、不重编 Gecko、不重打包 IPA/TIPA；engine-artifact-lock 保持
`vulpra-engine-v5-r0.3-candidate`。engine-cutover-gates.json / ADR-0004 / baseline 等
v4→v5 收尾项仍按既有清单另行处理。
