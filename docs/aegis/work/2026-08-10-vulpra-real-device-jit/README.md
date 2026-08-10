# 真机 JIT 实现方案调研（真机性能路线 B 前置）

## 目标

回答一个问题：**真机（iphoneos）上能不能给 Vulpra 打开 JIT，有哪些可行路径？**

背景数据（详见 `docs/aegis/work/2026-08-09-vulpra-standard-benchmark/README.md`）：

- Vulpra 真机 Speedometer 3.0 同子集单次 **5.267** vs Safari 真机 **11.24**（≈2.1× 落后）
- Vulpra 真机（内容进程解释器，JIT 关）5.267 vs Simulator 中位数（JIT 关）1.959 的 ≈2.7 倍是
  **真机/模拟器硬件差**，不是 JIT 开关差（5.267 IPA 自 `b749de8` 起内容进程真机
  `JS::DisableJitBackend()`）；**JIT 开关差**待 run 31374470622（Simulator JIT 开）归档
- 实验提交 `0b9bdf7`：Simulator 保留完整 JIT backend（Ion/Baseline/Wasm），真机维持
  `JS::DisableJitBackend()`（解释器模式）——用于量化 JIT 开关差距，不代表真机方案落地

本文档是"等待编译期间"产出的真机 JIT 可选方案清单与推荐，不是已实施改动。

## 约束证据（源码级，固定上游 `27b462b22705a8860f7ab0d33aa5b4b658ae5932`）

1. **SpiderMonkey 在 Darwin 下无条件使用 MAP_JIT**：
   `js/src/jit/ProcessExecutableMemory.cpp`（`ReserveProcessExecutableMemory` 内）
   ```
   #if defined(XP_DARWIN)
     flags |= MAP_JIT;
   ```
   `XP_DARWIN` 覆盖 macOS 与 iOS，因此真机必然走 MAP_JIT 路径。

2. **iOS 上 Apple-fast-WX 的 witness API 来自私有框架 BrowserEngineCore**：
   `js/src/jit/ProcessExecutableMemory.h` 的 `XP_IOS` 分支调用
   `be_memory_inline_jit_restrict_rwx_to_rw_with_witness()` /
   `be_memory_inline_jit_restrict_rwx_to_rx_with_witness()`（`JS_USE_APPLE_FAST_WX` 下）。

3. **`js/moz.configure` 的注释直接确认**：
   `has_apple_fast_wx = kernel == "Darwin" && cpu == "aarch64"`；注释原文
   "On Apple Silicon macOS we use MAP_JIT with pthread_jit_write_protect_np …,
   while on iOS we use MAP_JIT with be_memory_inline_jit_restrict_*"。

4. **vulpra 树不是从零移植，而是主动回退了上游的 BrowserEngineKit 集成**（见 Route B）。

5. **禁用链**：`DisableJitBackend() → JitOptions.disableJitBackend → HasJitBackend()==false →
   wasm::HasPlatformSupport()==false`。Baseline Interpreter / Wasm 同样依赖 JIT backend，
   无法在 `disableJitBackend` 下单独保留。

6. **MAP_JIT 的唯一次尝试在进程级 `JS::Init()`，不是"页面 JS 首次编译时"**（决定 Route A
   附加窗口的最关键时序证据）：
   ```
   JS_Init → JS::Init（Initialization.cpp:167, frontendOnly=No）
     → js::jit::InitializeJit()                       [js/src/jit/JitContext.cpp]
        → if (HasJitBackend()) InitProcessExecutableMemory()   [JitContext.cpp:139-141]
           → ProcessExecutableMemory::init()           [js/src/jit/ProcessExecutableMemory.cpp]
              → ReserveProcessExecutableMemory(MaxCodeBytesPerProcess)   // 唯一 mmap(MAP_JIT)
   ```
   - `InitializeJit` 定义在 **`js/src/jit/JitContext.cpp`**（2026 树中 `InitializeJit.cpp`
     已不存在），其注释明说（[JitContext.cpp:128-130]）："This is the final point where we can set
     disableJitBackend = true, before we use this flag below with the HasJitBackend call."
   - `ProcessExecutableMemory` 是**进程级单例**（`MOZ_RUNINIT static ... execMemory;`），
     64 位一次性保留 `MaxCodeBytesPerProcess = 2044MB`；`init()` 有
     `MOZ_RELEASE_ASSERT(!initialized())`，失败返回 false；`AllocateExecutableMemory()`
     /`allocate()` 断言 `initialized()` → **MAP_JIT 失败后没有任何重试路径**（release 下
     后续 JIT 分配直接崩，不是回退）。

## 实验编译状态（run 31374470622）

- **iphonesimulator job 失败**（2026-08-10 11:30 UTC，`Build native runtime` 阶段 1h47m 处）：
  `js/src/jit/ProcessExecutableMemory.cpp:999: error: 'pthread_jit_write_protect_np' is
  unavailable: not available on iOS`。根因：`0b9bdf7` 把 `markExecutable` 的守卫从
  `fast-WX && !XP_IOS` 放宽为 `fast-WX`，但 **iOS Simulator SDK 不声明 macOS-only 的
  `pthread_jit_write_protect_np`**（模拟器运行时虽是 macOS，SDK 仍是 iOS）。
- **修复**（`Engine/GeckoPatches/v5/platform/js/src/jit/ProcessExecutableMemory.cpp.patch`）：
  守卫改为 `fast-WX && (!XP_IOS || TARGET_OS_SIMULATOR)`；模拟器分支用 `dlsym(RTLD_DEFAULT,
  "pthread_jit_write_protect_np")` 运行时解析（模拟器运行时=macOS，符号必然存在）；真机
  （`TARGET_OS_SIMULATOR==0`）不编译该分支。`verify-producer.py` 通过，patch 已在固定上游
  验证可干净应用。
- **iphoneos job 单独成功也无法 promote**：`promote-repeat-verified-pair` 需要双平台成对产物，
  旧 run 无 sccache（早于 `8b80d6d` 修复启动），失败即全丢；重跑走修复后的工作流
  （restore + always() 保存 sccache）。
- 教训：**模拟器构建的编译期平台差异不等于真机**——`TARGET_OS_SIMULATOR` 下 SDK 仍是 iOS
  SDK，macOS-only API 必须 dlsym 或条件排除；这已在 ADR-0005 草案的验证清单里。

## 编译后执行清单（run 31384820854 绿后）

前置事实：promote 是 **repeat 门控**（`promote-engine-artifacts.py promote` 需要
`--producer-run-id` 与 `--repeat-producer-run-id` 两个不同 run 的成对产物，哈希一致才写
lock），因此 JIT 实验引擎要进 benchmark-ci 需要**两次全量编译**。

1. run 31384820854 两 job 全绿（iphoneos + iphonesimulator，patch = dlsym 修复版）。
2. **再触发一次同 commit 的 producer run**（workflow_dispatch，无代码改动）作为 repeat：
   `gh workflow run produce-gecko-v5.yml --ref fix/browser-performance-20260729`。
   两次 run 产物须哈希一致（repeat-verified gate）。
3. 两个 run 都绿后 dispatch promote：
   `gh workflow run produce-gecko-v5.yml --ref fix/browser-performance-20260729 -f promote_run_id=<主> -f repeat_producer_run_id=<repeat> -f release_tag=vulpra-engine-v5-jit-sim-candidate`
   （tag 用**新 candidate**，不动 r0.3-candidate 现役基线）。
4. 把 promote 产出的 `engine-v5-promotion-<run>.json` 换成 `Configuration/engine-artifact-lock.json`
   （releaseTag/compiledBy* 随新 run），commit + push。
5. push 触发的 benchmark-ci 会按新 lock 消费 **Simulator JIT 开** 引擎跑 Speedometer 3.0
   子集；拿分数对比 Simulator JIT 关中位数 **1.959**，把差值归档到
   `docs/aegis/work/2026-08-09-vulpra-standard-benchmark/README.md`（修正后的"JIT 开关差"
   口径：5.267 是解释器分数，不作为 JIT 开证据）。
6. 归档后评估：差值显著 → 真机 Route A/A' 冒烟（需真机 + StikDebug/debugserver）；ADR-0005
   草案按证据转 recorded（token 策略拆分 + opt-in gate）。
7. 若 repeat 门控两次产物不一致：先查 `REPRODUCIBLE_BUILD`（mozBuildDate/sourceDateEpoch）
   与 sccache 缓存扰动，再决定是否跳过 repeat（需治理放行，勿默认）。

## 治理约束（最重要的前置门槛）

任何真机 JIT 路线首先是一个**信任边界变更**，不是纯代码问题：

- **ADR-0004**（2026-07-27，`docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md`）
  决策原文："No runtime fallback or JIT path is retained."
- **R0 Trustworthy Engine 计划**（2026-07-29）把"无 JIT 就绪协议 token + `ChildProcessInitImpl`
  调 `JS::DisableJitBackend()` + `strings XUL` 不含禁止 token"列为验收项。
- 强制机制（字节级）：
  - `Tools/GeckoProducer/verify-producer.py`：`forbiddenRuntimeTokens`（合约）+ patch 内容
    禁止 `jit-ready-fd` / `ReportJITStatusForChild` / `WaitForJITReadySignal` /
    `RuntimeJITCoordinator` / `ptrace` / `task_for_pid`。
  - `Tools/Engine/validate-ipa.py`：`FORBIDDEN_RUNTIME_TOKENS` 扫描最终包内二进制，
    `FORBIDDEN_PATH_TOKENS` 含 `ptrace_jit`、`/jit/`、`geckoview.framework` 等。

结论：**开启真机 JIT 必须新立 ADR 变更信任边界**（撤销 ADR-0004 的 "no JIT" 条款），并同步修改
verify-producer.py / validate-ipa.py / test-package-validator.py 及 baseline 文档。
这是 Route A/B 共用的第一个 gate，代码工作量在其次。

**重要边界（实证）**：Simulator JIT 实验（run 31374470622，`0b9bdf7`）的
"Verify producer inputs" 已通过——即**启用 JIT backend 本身不违反 patch 合约**。
forbidden tokens（`jit-ready-fd` / `ReportJITStatusForChild` / `WaitForJITReadySignal`）
针对的是 Gecko 层的 **JIT-ready 进程编排符号**（R0 已从 patch 系列移除），不是
SpiderMonkey Ion/Baseline/Wasm 后端。含义：
- 真机 Route A（去掉 `DisableJitBackend`，不恢复 JIT-ready 编排）在 patch 层合约兼容；
- 真正的治理障碍是 ADR-0004 的语义（"no JIT path retained"）与 validate-ipa 对新二进制的
  token 扫描结果——需要新 ADR 明确边界，而非技术不可行。


## 进程架构（Route A/B 的落地对象）

**Gecko 主进程 = Vulpra.app 自身**，不是 appex：

- `App/main.swift` → `VulpraEngineApplicationMain` → `VulpraEngine.runtime.runMain` →
  `VEKRuntimeMain` → `MainProcessInit`（主进程路径，跑在 Vulpra.app 进程里）。
- `Vulpra Engine Process.appex`（NSExtension，`com.apple.ar.viewer` 扩展点 +
  `_MultipleInstances`）→ `EngineProcessExtension` → `VulpraEngineProcessHost.start` →
  `engineABIChildProcessStart` → `ChildProcessInit`（**Gecko 子进程**路径）。
- Fission 开：`applyProcessPoolPolicy()` 设 `dom.ipc.processPrelaunch.fission.number=2`、
  `dom.ipc.processCount=4` → **网页 JS（含 benchmark）跑在 content 子进程 = appex 实例**，
  主进程只跑 Gecko chrome JS。

**`JS::DisableJitBackend()` 只在子进程**：`IOSBootstrap.mm` 的 `ChildProcessInitImpl` 里
（真机 `#if !TARGET_OS_SIMULATOR`）；**`MainProcessInit` 从不调用**。

**实证（5.267）的"优雅降级"真实机制 = 跳过，不是失败容错**：`IOSBootstrap.mm.patch`
在 `ChildProcessInitImpl` 里、`XRE_InitChildProcess` **之前**调用 `JS::DisableJitBackend()` →
content 子进程走到 `JS::Init()` 时 `HasJitBackend()==false` → `InitializeJit` 里
`InitProcessExecutableMemory()` **根本不执行** → 解释器模式，全程没有 MAP_JIT 尝试（也就没有
"失败"可言）。

**时序修正（源码级）**：MAP_JIT 唯一尝试点 = content 子进程**启动早期的 `JS::Init()`**
（`XRE_InitChildProcess` 内部），不是"页面 JS 首次编译时"。推论：
- Route A 若只去掉 `DisableJitBackend`、而不赶在 **`JS::Init` 之前**附加 debugserver，
  content 子进程会在启动早期因 `JS::Init()` 失败而无法启动（prelaunch 池进程同样）——
  **不是优雅降级**。
- 旧结论"首帧 JS 前附加即可"不成立；正确窗口是 **spawn 瞬间（JS_Init 前）**，或走下方
  **A' 懒重试补丁**把窗口放宽到"首次 JIT 分配前"。

**子进程 PID 已在 Swift 层暴露**：`GeckoChildProcessDidChange`（`GeckoChildProcessHost.cpp.patch`）
→ `EngineChildProcessEvent.processIdentifier: Int32?`（`EngineChildProcessLifecycle.swift`）→
Route A 可做 **PID 感知附加**（harness 监听子进程生命周期拿到 PID，逐个 attach debugserver）。

**iOS 内容进程 JIT 代码 W^X 已开**：`StaticPrefList.yaml.patch` 把
`javascript.options.content_process_write_protect_code` 在 `XP_IOS` 下置 `true`（与 OpenBSD 同
口径）→ Route A/B 下 JIT 代码走 W^X（MAP_JIT + witness / CS_DEBUGGED mprotect 兼容）。

## 路线对比

### A. debugserver 动态签名（开发/测试用，真机 benchmark gate 可行）

- 机制：App 用开发证书签（带 `get-task-allow`）→ 附加 `debugserver` 给进程置 `CS_DEBUGGED`
  → 内核允许该进程 mprotect 在 RW/RX 间切换（APRR 下不能同时 RWX）→ MAP_JIT 可成功。
  原理详见 Saagar Jha《Jailed Just-In-Time Compilation on iOS》。
- 现成工具（2026-06 SideStore 文档口径，时效性以该页为准）：
  - **StikDebug**（原 StikJIT，当前推荐）：iOS 17.4–18.x（**排除 18.4b1**）；本地 VPN +
    pairing file + 挂载 DDI 后"select an app（须 get-task-allow）→ attach a debugger"。
  - **SideJITServer**：iOS 17.0–17.3 的替代方案；Windows/macOS/Linux 同网段 +
    pymobiledevice3。
  - **iOS 26 又封堵**：SideStore 文档标注 iOS 26 起 JIT 再次失效，支持列表仅限
    UTM/Amethyst/MeloNX/maciOS/DolphiniOS/Geode/Manic EMU/Flycast/MeloCafe/ARMSX2/DukeX
    等（截至 2026-06-17，**无浏览器**），26.6/27 仅少量 App 可用。
- **iOS 18.4b1 起 Apple 已修补**：osy 逆向分析确认 TXM 新增 `com.apple.private.cs.debugger`
  检查（仅 debugserver 进程可做 debug mapping）。
- 限制：**不可 App Store 分发**，仅限开发/侧载场景；Vulpra 的 TIPA 分发路径
  （TrollStore + `get-task-allow` 已具备）满足前置条件。

**Vulpra 落地步骤（草稿）**：

1. 改 `IOSBootstrap.mm`：把真机上 `ChildProcessInitImpl` 里无条件的 `JS::DisableJitBackend()`
   改为按环境变量/启动参数决定（默认关，benchmark 时开）。**这步是必须的**——当前真机构建在
   子进程硬禁 JIT，而 benchmark JS 跑在 content 子进程，不改代码则附加 debugserver 也没用。
2. 重新产出 iphoneos 引擎 → 打包 TIPA。
3. 附加 debugserver：**必须在每个 content 子进程的 `JS::Init()` 之前**（≈spawn 瞬间、
   进程启动早期）完成——MAP_JIT 唯一尝试点在那里，错过即该进程终局无 JIT。可行方式：
   (a) PID 感知的 spawn 瞬间自动附加（`EngineChildProcessEvent.processIdentifier` 已暴露；
       `debugserver --attach <pid>` 抢在 `XRE_InitChildProcess → JS_Init` 之前）；或
   (b) 用下方 **A'（懒重试补丁）**把窗口放宽到"benchmark 页面加载前"，此时交互式
       StikDebug"选 App"流程才来得及。仅靠交互式附加（启动后数秒）赶不上 appex 的 JS_Init。
4. 带开 JIT 的启动参数跑 Speedometer 3.0 同子集，与 5.267 / 11.24 对齐。

**开放问题**：

1. **工具对 appex 子进程的支持**：StikDebug/SideJITServer 的交互是"选择 App（主进程）附加
   调试器"；官方支持列表（截至 2026-06）没有浏览器。Vulpra 的 JS 在 content 子进程
   （NSExtension 多实例、动态 PID）——需要验证工具能否按 PID 附加 appex，或改用
   `debugserver --attach <pid>` 手动流程（PID 已由 `EngineChildProcessEvent` 提供）。
2. **Fission 下每新增 content 进程都要在 JS_Init 前附加**：prelaunch=2 的预启动进程在
   prelaunch 阶段就会跑 `JS::Init()`——若那时未附加，预启动进程直接启动失败，不是"留到页面加载
   再补"。需要 `fission.autostart=false` / 减小 prelaunch 数来留出附加窗口，或直接用 A' 懒重试
   补丁绕开该问题（推荐）。
3. **iOS 版本**：iOS 18.4b1+ / iOS 26+ 的修补状态需按用户真机版本重新确认。
4. **主进程是否调用 `JS::Init`**：`MainProcessInit` 对 JIT 从不禁用，但 Vulpra.app 主进程
   是否实际创建 JS runtime（`GeckoViewOpenWindow` 在 main 侧有调用）未实证。5.267 能跑通说明
   主进程要么不建 runtime、要么 MAP_JIT 在该路径成功——需要真机确认，影响 Route A 的附加对象清单
   （若主进程也走 `JS::Init`，同样要在 JS_Init 前附加或走 A'）。


### A'（推荐变体）：懒初始化 + 可重试 MAP_JIT（代码改动最小）

动机：Route A 原案的附加窗口被锁死在"`JS::Init` 之前（spawn 瞬间）"，交互式工具赶不上、
prelaunch 池也危险。把 MAP_JIT 尝试**延迟到首次 JIT 分配**并**失败可重试**后，窗口变成
"首次 JIT 编译前"（benchmark 加载前，秒级且用户可控）。

改动（3 处小 patch，建议直接并入 `0b9bdf7` 实验系列）：
1. `js/src/jit/JitContext.cpp` `InitializeJit()`：把
   `if (HasJitBackend()) { if (!InitProcessExecutableMemory()) return false; }` 改为
   `if (HasJitBackend()) { (void)InitProcessExecutableMemory(); }`（失败 soft-fail + 日志）
   → `JS::Init()` 不再因 MAP_JIT 失败而失败，进程以解释器正常启动。
2. `js/src/jit/ProcessExecutableMemory.cpp` `ProcessExecutableMemory::allocate()`：入口加
   `if (!initialized()) { if (HasJitBackend() && !init()) return nullptr; }`
   （懒初始化 + 重试）。注意并发：`init()` 内含 `MOZ_RELEASE_ASSERT(!initialized())`，需要
   once/锁语义防双跑（`allocate()` 已持 `lock_`，`init()` 不上锁 → 无死锁，但要防 double-init）。
3. 确认 `ExecutableAllocator::systemAlloc` 的 nullptr 既有回退路径：`createPool` 已有失败检查，
   Ion/Baseline 单次编译失败应回退解释器（release 下 `MOZ_ASSERT` 不生效，需真机冒烟确认不崩）。

效果：
- 无 debugserver：进程启动不崩；每次 JIT 分配返回 nullptr → 单次编译回退，页面仍解释器运行。
- debugserver 附加后（`CS_DEBUGGED` 置位）：首次 JIT 分配重试 `mmap(MAP_JIT)` 成功 → 此后
  Ion/Baseline 全走 JIT，无需重启进程。
- 与 Route A step 1（`DisableJitBackend` 改启动参数控制）共用前置改动，唯一差别是时序窗口。

待真机验证：
- CS_DEBUGGED 置位后 `mmap(MAP_JIT)` 在本真机 iOS 版本上确实成功（iOS 18.4b1+ / iOS 26+
  修补状态按真机确认）。
- 分配失败路径对 Ion/Baseline 编译确实只回退不崩（release 构建）。
- 先解释器后 JIT 的混合态对 benchmark 无影响（benchmark 页面加载在附加之后，首次编译即 JIT）。

### B. BrowserEngineCore / BrowserEngineKit witness API（发行，仅 EU）

**重要更正：这不是"从零移植"，而是"撤销 v5 补丁系列里对上游集成的回退"。**

vulpra 的固定上游（mozilla-firefox/firefox `27b462b2`，2026-07-13）**已经包含**上游
Firefox 的 iOS JIT/进程集成：

- `js/src/jit/ProcessExecutableMemory.h` 的 `XP_IOS` witness 分支（base 自带，`0b9bdf7`
  只是为 Simulator 放宽了条件）
- `ipc/glue/ExtensionKitUtils.h/.mm`（ExtensionKit 进程）
- `ipc/glue/GeckoChildProcessHost.cpp` 的 `ExtensionKitProcess`（WebContent/Rendering/Networking）
- `ipc/chromium/src/base/message_pump_kqueue.cc` 的 `be_kevent64`（BrowserEngineCore）
- `ipc/glue/moz.build` 的 `OS_LIBS += ["-framework BrowserEngineKit"]`

vulpra v5 补丁系列（`Engine/GeckoPatches/v5/`）**主动回退**了上述集成，改用 reynard-browser
风格的 NSExtension 进程（不依赖 EU entitlement，iOS 13+ 可用）：

| patch | 回退内容 |
| --- | --- |
| `platform/ipc/chromium/src/base/message_pump_kqueue.cc.patch` | `be_kevent64` → `kevent64` |
| `platform/ipc/glue/moz.build.patch` | `ExtensionKitUtils` → `NSExtensionUtils`；删 `-framework BrowserEngineKit` |
| `platform/ipc/glue/NSExtensionUtils.h/.mm.patch` | 新增 `NSExtensionProcess` |
| `platform/ipc/glue/ExtensionKitUtils.h/.mm.patch` | 标记 "now unused" |
| `platform/ipc/glue/GeckoChildProcessHost.cpp/.h.patch` | `ExtensionKitProcess` → `NSExtensionProcess` |

**Route B = 撤销这些回退 + EU entitlement + 治理变更**：

1. 恢复 `-framework BrowserEngineKit`、ExtensionKitUtils、`ExtensionKitProcess`、
   `be_kevent64`（BrowserEngineCore witness 路径 base 已就绪）。
2. App 侧补 entitlement：`com.apple.developer.web-browser-engine.host` + extension
   entitlement（`allow-jit`、`extended-virtual-addressing`）；仅 EU 分发，需满足 90% WPT、
   80% Test262、安全承诺等（Apple 官方要求，iOS 17.4+ / iPadOS 18+）。
3. **治理**：ADR-0004 "no JIT" 条款撤销 + verify-producer/validate-ipa 的 forbidden token
   放行或重定义（BrowserEngineKit 内容进程很可能引入 `jit-ready-fd`/`ReportJITStatusForChild`
   之类 token，需先确认再改合约）。
4. 移植口径参考（已逐一核实到提交级）：
   - **Bug 1883457 Part 2** "Use be_memory_inline_jit_restrict_* APIs for JIT on iOS"
     （2024-03-25，Nika Layzell）= 原始引入，改动 3 个文件：
     `js/moz.configure`（iOS 启用 `JS_USE_APPLE_FAST_WX`）、`js/src/jit/JitOptions.cpp`、
     `js/src/jit/ProcessExecutableMemory.cpp`。提交 `a599ba35bf94`（fork 内重落地；
     首版 `3e0732554342` 因 StaticPrefList.yaml 构建破损被 `2ccc6b35c619` 回退）。
   - **Bug 1887759** "Link to BrowserEngineCore on iOS"（elm，2024-03-27，
     `199096b2e93e6ccda6cb1e467bb2ad5201cb6e0f`）= 链接 BrowserEngineCore。
   - **Bug 1927599 Part 4** "Inline JIT calls on iOS"（2025-12-16，
     `c3e0176a0945`）= 按 BrowserEngineCore 文档把 witness 调用内联进 header——
     **固定上游 `27b462b2` 的 `ProcessExecutableMemory.h` 内容来源**（已对比 base 文件确认：
     `#include <BrowserEngineCore/BEMemory.h>` + 构造/析构直接调
     `be_memory_inline_jit_restrict_rwx_to_rw/rx_with_witness()`）。

结论：**EU 发行路线的正解，工作量 = 撤销回退 + entitlement + 治理变更**；在目标市场不在 EU
时不做。

### C. allow-jit entitlement（不可行）

- `com.apple.security.cs.allow-jit` 是 **macOS Hardened Runtime 专属** entitlement；
  iOS 不授予第三方。mozilla/platform-tilt issue #3 明确申请 iOS 等价 entitlement，未果。
- 结论：**排除**。

### D. 非 MAP_JIT 替代（证据不足）

- 可执行内存的非 MAP_JIT 路径（如 `allow-unsigned-executable-memory`）同样是 macOS Hardened
  Runtime 概念，**iOS 上不存在**（osy 分析确认 iOS 无此 entitlement）。
- 解释器/无 JIT 模式（现状）不构成"JIT 实现方案"。
- 结论：**无证据支持，不投入**。

## 推荐

1. **先立治理变更评估（两个路线共用）**：新 ADR 撤销 ADR-0004 "no JIT" 条款，明确新的信任
   边界与 token 策略。这是第一步，决定后续所有代码工作是否值得做。
2. **真机 benchmark gate（近期）**：路线 A。前置 `get-task-allow` 已具备；先做一次真机
   冒烟验证 NSExtension 子进程能否被 debugserver 附加（关键未知项），通过后再改
   `IOSBootstrap.mm` 的 JIT 开关 + 重打 TIPA。
3. **发行（默认）**：维持解释器模式（5.267 基线）。JIT 发行需要路线 B（EU）+ 治理变更，
   都不受我们单方面控制。
4. **目标 EU 时**：重估路线 B，按上表撤销回退，跟踪 Firefox cedar JIT-on-iOS 补丁集。

## 核心引用

- https://github.com/mozilla/platform-tilt/issues/3 （iOS allow-jit 申请被拒的权威证据）
- https://developer.apple.com/cn/support/alternative-browser-engines/ （EU 替代浏览器引擎要求）
- https://developer.apple.com/documentation/browserenginekit/protecting-code-compiled-just-in-time （witness API）
- https://github.com/mozilla-firefox/firefox/commit/a599ba35bf94b3ae3d093ead7fae9767ce62e1e3 （Bug 1883457 Part 2，iOS 启用 JS_USE_APPLE_FAST_WX + witness API）
- https://github.com/mozilla-firefox/firefox/commit/c3e0176a09450e8a87c029c0cbdec0fca8f87a26 （Bug 1927599 Part 4，内联 witness 调用，base 27b462b2 内容来源）
- https://hg.mozilla.org/projects/elm/rev/199096b2e93e6ccda6cb1e467bb2ad5201cb6e0f （Bug 1887759，链接 BrowserEngineCore）
- https://github.com/nythepegasus/SideJITServer （debugserver 动态签名工具，iOS 17.0-17.3）
- https://gist.githubusercontent.com/osy/8940e5ae5f24646b808f58d197883ca5/raw （iOS 18.4b1 修补逆向分析）
- https://docs.sidestore.io/docs/advanced/jit （StikDebug/SideJITServer 支持范围与 iOS 26 现状，2026-06-17 口径）
