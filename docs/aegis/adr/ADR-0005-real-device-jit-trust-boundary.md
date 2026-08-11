# ADR-0005 - Real-Device JIT Trust Boundary

Status: `draft`
Date: `2026-08-10`

## Context

ADR-0004（2026-07-27）退役了 v3 GeckoView/Helper/RuntimeJITCoordinator 基座并决策
"No runtime fallback or JIT path is retained."。该禁令针对的是 **JIT-ready 进程编排基座**
（`RuntimeJITCoordinator`、`jit-ready-fd`/`ReportJITStatusForChild`/`WaitForJITReadySignal`
协议 token、ptrace/task_for_pid 生产者），并非 SpiderMonkey 的 Ion/Baseline/Wasm 后端本身。

新证据（2026-08-10，详见 `docs/aegis/work/2026-08-10-vulpra-real-device-jit/README.md`）：

- **合约实证**：Simulator JIT 实验 run 31374470622（`0b9bdf7`）"Verify producer inputs" 已通过
  → 启用 SM JIT backend 本身不违反 patch 合约（forbidden token 是编排符号，不是后端）。
- **性能证据（口径已更正）**：真机 Speedometer 3.0 同子集 Vulpra **5.267**（内容进程解释器模式，
  自 `b749de8` 起真机 `JS::DisableJitBackend()`）vs Safari **11.24**（≈2.1× 落后）；Simulator
  JIT 关中位数 **1.959**。5.267/1.959 ≈2.7 倍是**真机/模拟器硬件差**，不是 JIT 开关差。
- **JIT 开关差已实测归档（2026-08-11）**：Simulator 同引擎同子集，JIT 开
  `scoreMedian=3.451`（run 31425316658，`vulpra-engine-v5-jit-sim-candidate`）vs 关
  `1.959` → **≈1.76×（+76%）**，纯编译后端差距（Ion/Baseline vs 解释器），已归档到
  `docs/aegis/work/2026-08-09-vulpra-standard-benchmark/README.md`。
- **越狱 JIT 路线落地（2026-08-11）**：opt-in 门控补丁（order 249，
  `Engine/GeckoPatches/v5/platform/real-device-jit/route-jailbreak-jit.patch`，
  `-enable-jit` argv 触发，默认关）已提交；双 run 编译绿（31427742238/31427779392）、
  promote 为 `vulpra-engine-v5-jit-jailbreak-candidate`、TIPA 打包验证通过
  （engine `vulpra-gecko-ios-arm64-v5-a0d6128a…`，`vulpra-package-ok` 48 files，
  sha256 `f067caa9…`）；真机冒烟清单见
  `docs/aegis/work/2026-08-11-vulpra-jailbreak-jit-verification/README.md`。
- **源码时序（固定上游 `27b462b2`）**：MAP_JIT 每进程只在 `JS::Init()` 尝试一次
  （`Initialization.cpp:167 → JitContext.cpp InitializeJit → InitProcessExecutableMemory →
  ProcessExecutableMemory::init()`，单例、断言 `!initialized()`、失败无重试）；在
  `ChildProcessInitImpl` 于 `XRE_InitChildProcess` 前调 `JS::DisableJitBackend()` 时，
  content 进程 `HasJitBackend()==false` → 跳过 MAP_JIT → 解释器模式。

- **主进程路径实证（2026-08-11）**：主进程也创建 JS runtime
  （`nsXPConnect::InitJSContext → InitJSEngine → JS_InitWithFailureDiagnostic`，
  `js/xpconnect/src/nsXPConnect.cpp:120`），但上游 `javascript.options.main_process_disable_jit`
  pref 在 `XP_IOS` 下为 true → 主进程同样 `DisableJitBackend()`，从不尝试 MAP_JIT；5.267 能跑通
  的机制由此闭环（与 content 子进程的 `ChildProcessInitImpl` 禁用互为独立）。
- **Route A' 源码级审查（2026-08-11）**：`allocate()` 失败语义 = `Linker::newCode →
  `fail(cx)`（`ReportOutOfMemory`），非静默回退；但 `BaselineCompile` 仅在
  `Method_CantCompile` 时 `disableBaselineCompile()`，allocate 失败走 `Method_Error` →
  **编译失败不永久禁用 script，attach 后 warm-up 重触发即可 JIT，无需重启进程**；
  `CanLikelyAllocateMoreExecutableMemory()` 未 init 时返回 true，拦不住编译入口 →
  每次失败尝试都报 OOM，OOM 传播需真机冒烟观察（详见 work README）。
- **appex 可附加性（2026-08-11，源码级）**：App 与 Engine Process 的 entitlements 均含
  `get-task-allow=true`；StikDebug 核心 attach 为 PID 级 `vAttach`（`debugApp(withPID:)`），
  外部动作/JS 脚本可对任意 PID 附加 → Route A/A' 的"附加对象 = content appex 子进程"成立，
  待真机 iOS 版本冒烟确认。

真机 JIT 可选路线（详见 work README）：A debugserver 动态签名（开发/测试）、
A' 懒初始化 + 可重试 MAP_JIT（开发/测试，推荐）、B BrowserEngineKit witness API
（仅 EU 发行）、C allow-jit（Apple 拒绝，platform-tilt #3）、D 非 MAP_JIT（无证据）。

## Decision（草案，差值归档已完成；待真机冒烟后转 recorded）

把 ADR-0004 的笼统 "no JIT path is retained" 重界定为 **JIT 编排边界（orchestration
boundary）**，后端与编排分开治理：

- **保留禁令（不变）**：JIT-ready 编排 token（`jit-ready-fd` / `ReportJITStatusForChild` /
  `WaitForJITReadySignal` / `RuntimeJITCoordinator`）；`ptrace` / `task_for_pid` 生产者；
  path token（`geckoview.framework` / `ptrace_jit` / `/jit/` 等）；从固定已验证引擎产物回退。
- **新增允许（本 ADR 转 recorded 后生效）**：Gecko 进程内执行 SM Ion/Baseline/Wasm JIT 后端，
  以显式 opt-in（**启动参数 argv**，源码级确认：appex 由 launchd 启动、XPC 启动消息
无 env 通道，getenv 不可靠；argv 链路 `AsyncLaunch → mChildArgs.mArgs → XPC "argv" →
HandleBootstrapMessage → ChildProcessInitImpl` 完整可用）门控，默认保持解释器模式。
- **路线策略**：
  - Route A / A' 仅限开发/测试 TIPA 与 benchmark/回归 gate；**禁止进入发行包**。
  - Route B 仅在 EU 合规 gate（90% WPT / 80% Test262、Apple 安全承诺）下考虑，目标市场
    确认前不投入。
  - 默认发行维持解释器模式（5.267 基线）。

转 recorded 前必须完成的配套变更：`Configuration/gecko-producer-v5.json` /
`Tools/GeckoProducer/verify-producer.py` / `Tools/Engine/validate-ipa.py` 的 forbidden-token
策略拆分（编排禁、后端放行），并新增 opt-in JIT 构建的包验证覆盖。

## Alternatives Considered

- **保持 ADR-0004 原样（永不 JIT）**：把"编排禁令（应保留）"与"SM 后端启用（合约兼容、性能
  差距主导）"混为一谈；2.1× 真机落后是当前最大可用性差距，且后端启用已被 run 31374470622
  证实不违反 patch 合约。
- **Route C（allow-jit entitlement）**：Apple 拒绝（platform-tilt #3），iOS 不授予第三方，
  排除。
- **Route D（非 MAP_JIT 可执行内存）**：iOS 无对应 entitlement 证据，不投入。
- **把 5.267 当作"JIT 开"证据**：已更正——e46c607 IPA 内容进程解释器运行，不构成 JIT 收益
  证据；JIT 差值以 run 31374470622 归档为准。

## Consequences

- 治理：ADR-0004 "no JIT" 条款按后端/编排拆分；token 策略更新；opt-in gate；benchmark 证据归档。
- 验证：opt-in JIT 构建新增校验（编排 token 仍禁、后端放行），verify-producer/validate-ipa 同步。
- 分发：非 EU App Store 路径不变（解释器）；开发/测试 TIPA 可用 Route A/A'。

## Compatibility Boundary

不变：com.vulpra.browser、iOS 15.0、arm64 iPhone/iPad、OpenIn、既有数据与
TabManager/BrowserTab 归属、固定引擎产物 pin。

## Retirement Impact

无新增退役项；编排基座保持退役状态。本 ADR **不复活** RuntimeJITCoordinator / ptrace 生产者。

## Baseline Sync

- Needed: pending（真机 appex 附加冒烟之后；Simulator JIT 开关差值已于 2026-08-11 归档）
- Target: 2026-08-12（真机冒烟完成后）

## Evidence References

- docs/aegis/work/2026-08-10-vulpra-real-device-jit/README.md
- docs/aegis/work/2026-08-09-vulpra-standard-benchmark/README.md
- docs/aegis/adr/ADR-0004-independent-engine-runtime-and-distribution.md
- https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/31374470622 （Simulator JIT 实验，Verify producer inputs 通过）
- https://github.com/StikDebug/StikDebug （PID 级 vAttach / debugApp(withPID:)，2026-08-11 源码核验）
- 本地源码：`App/Entitlements/Vulpra.private.entitlements`、`Engine/VulpraEngineProcess/EngineProcess.private.entitlements`（get-task-allow=true）、`js/xpconnect/src/nsXPConnect.cpp`、`modules/libpref/init/StaticPrefList.yaml`（main_process_disable_jit）
- https://github.com/mozilla/platform-tilt/issues/3 （iOS allow-jit 申请被拒）
- SideStore JIT 文档 / osy iOS 18.4b1 逆向分析（工具时效，work README 引用）

## Supersedes

- 转 recorded 后：修订 ADR-0004 的 "No runtime fallback or JIT path is retained" 条款
  （仅 SM 后端范围；编排禁令保留）。

## Boundary

本 ADR 是 Aegis Method Pack 咨询记录（draft），不授予完成权限，也不代表项目授权来源变更。
