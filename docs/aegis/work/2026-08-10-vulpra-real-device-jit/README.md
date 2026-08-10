# 真机 JIT 实现方案调研（真机性能路线 B 前置）

## 目标

回答一个问题：**真机（iphoneos）上能不能给 Vulpra 打开 JIT，有哪些可行路径？**

背景数据（详见 `docs/aegis/work/2026-08-09-vulpra-standard-benchmark/README.md`）：

- Vulpra 真机 Speedometer 3.0 同子集单次 **5.267** vs Safari 真机 **11.24**（≈2.1× 落后）
- Vulpra 真机（JIT 开）是 Simulator 中位数（JIT 关）的 ≈2.7 倍 → JIT 是性能大头，已被实测证实
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

## 进程架构（Route A/B 的落地对象）

Gecko JS 不在主 App 进程跑，而在 **`Vulpra Engine Process.appex`**（NSExtension host，
`Info.plist` 用 `com.apple.ar.viewer` 扩展点 + `_MultipleInstances`）以及其派生的
NSExtension 子进程（WebContent/Rendering/Networking，`GeckoChildProcessHost.cpp` 的
`NSExtensionProcess::StartProcess`）。`IOSBootstrap.mm` 的 `ChildProcessInitImpl` 在每个
子进程里调用 `JS::DisableJitBackend()`。

这决定了：Route A 的 debugserver 附加目标是 **appex/子进程**，不是主 App 进程。

## 路线对比

### A. debugserver 动态签名（开发/测试用，真机 benchmark gate 可行）

- 机制：App 用开发证书签（带 `get-task-allow`）→ 附加 `debugserver` 给进程置 `CS_DEBUGGED`
  → 内核允许该进程 mprotect 在 RW/RX 间切换（APRR 下不能同时 RWX）→ MAP_JIT 可成功。
  原理详见 Saagar Jha《Jailed Just-In-Time Compilation on iOS》。
- 现成工具：SideJITServer、AltStore JIT、Jitterbug；SideJITServer 支持 iOS 17+，需
  Windows/macOS/Linux + pymobiledevice3，无线/USB 均可。
- **支持范围**：SideStore 文档标注 iOS 17.4–18.x，**排除 18.4 beta 1**。
- **iOS 18.4b1 起 Apple 已修补**：osy 逆向分析确认 TXM 新增 `com.apple.private.cs.debugger`
  检查（仅 debugserver 进程可做 debug mapping）。
- 限制：**不可 App Store 分发**，仅限开发/侧载场景；Vulpra 的 TIPA 分发路径
  （TrollStore + `get-task-allow` 已具备）满足前置条件。

**Vulpra 落地步骤（草稿）**：

1. 改 `IOSBootstrap.mm`：把真机上无条件的 `JS::DisableJitBackend()` 改为按环境变量/启动参数
   决定（默认关，benchmark 时开）。JIT backend 本来就编译进 iphoneos 二进制，只是运行时禁用。
2. 重新产出 iphoneos 引擎 → 打包 TIPA。
3. 真机用 SideJITServer 对 JS 宿主进程附加 debugserver（先附加后启动/先启动后附加需验证，
   MAP_JIT 必须在 CS_DEBUGGED 已置位后才分配）。
4. 带开 JIT 的启动参数跑 Speedometer 3.0 同子集，与 5.267 / 11.24 对齐。

**开放问题**：SideJITServer 的交互是"选择要开 JIT 的 App"，面向主进程；Vulpra 的 JS 在
appex/子进程。附加到 NSExtension 子进程（多个实例、动态 PID）的可行性是 Route A 的
**关键未知项**，需要一次真机冒烟验证。

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
4. 移植口径参考：Bug 1887759（elm D205740，`199096b2e93e6ccda6cb1e467bb2ad5201cb6e0f`）
   + Bug 1883457 Part 2（cedar，autoland `1080811a9d3dc3193ddf4b5a36575cfe2e455cc4`）。

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
- https://hg.mozilla.org/integration/autoland/rev/1080811a9d3dc3193ddf4b5a36575cfe2e455cc4 （Bug 1883457 Part 2，iOS JIT）
- https://hg.mozilla.org/projects/elm/rev/199096b2e93e6ccda6cb1e467bb2ad5201cb6e0f （Bug 1887759，链接 BrowserEngineCore）
- https://github.com/nythepegasus/SideJITServer （debugserver 动态签名工具）
- https://gist.githubusercontent.com/osy/8940e5ae5f24646b808f58d197883ca5/raw （iOS 18.4b1 修补逆向分析）
- https://docs.sidestore.io/docs/advanced/jit （JIT 附加支持范围）

## 下一步

- [ ] 编译 run `31374470622`（Simulator JIT 实验）结果出来后，把 Simulator JIT 开/关分数差归档
- [ ] 治理评估：新 ADR 草案（撤销 ADR-0004 "no JIT" 的边界与 token 策略）
- [ ] Route A 真机冒烟：SideJITServer 能否附加到 Vulpra Engine Process.appex / NSExtension 子进程
- [ ] Route A 通过后：`IOSBootstrap.mm` JIT 开关改为启动参数控制 + 重打 TIPA + 重跑 Speedometer
- [ ] 若走 EU：按 Route B 表格撤销 v5 回退，跟踪 Firefox cedar JIT-on-iOS patch 集
