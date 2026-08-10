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

4. **当前 Vulpra entitlements 现状**（`App/Entitlements/`）：
   `Vulpra.private.entitlements` 已有 `get-task-allow`、`com.apple.private.security.no-sandbox`、
   `com.apple.developer.web-browser`、`extended-virtual-addressing`（TrollStore/开发签名路径）；
   **没有** `com.apple.security.cs.allow-jit`，**没有** `com.apple.developer.web-browser-engine.host`。
   EngineProcess Appex 的对外 entitlements 为空（App Store 重签场景）。

5. **禁用链**：`DisableJitBackend() → JitOptions.disableJitBackend → HasJitBackend()==false →
   wasm::HasPlatformSupport()==false`。Baseline Interpreter / Wasm 同样依赖 JIT backend，
   无法在 `disableJitBackend` 下单独保留。

## 路线对比

### A. debugserver 动态签名（开发/测试用，真机 benchmark gate 可行）

- 机制：用开发证书签 App（带 `get-task-allow`）→ 附加 `debugserver` 给进程置 `CS_DEBUGGED`
  → 内核允许该进程 mprotect 在 RW/RX 间切换（APRR 下不能同时 RWX）→ MAP_JIT 可成功。
  原理详见 Saagar Jha《Jailed Just-In-Time Compilation on iOS》。
- 现成工具：SideJITServer、AltStore JIT、Jitterbug。
- **支持范围**：SideStore 文档标注 iOS 17.4–18.x，**排除 18.4 beta 1**。
- **iOS 18.4b1 起 Apple 已修补**：osy 逆向分析确认 TXM 新增 `com.apple.private.cs.debugger`
  检查（仅 debugserver 进程可做 debug mapping），gist 全文为证据。
- 限制：**不可 App Store 分发**，仅限开发/侧载场景；但 Vulpra 的 TIPA 分发路径
  （TrollStore + `get-task-allow` 已具备）天然满足前置条件。
- 结论：**真机 JIT benchmark gate 走这条**，成本最低、不动 Gecko 源码。

### B. BrowserEngineCore / BrowserEngineKit witness API（发行，仅 EU）

- 上游 Firefox 已经在铺路：
  - Bug 1887759 "Link to BrowserEngineCore on iOS"（elm 分支 D205740，
    `199096b2e93e6ccda6cb1e467bb2ad5201cb6e0f`）——引入 `be_memory_*_with_witness`。
  - Bug 1883457 Part 2 "Use be_memory_inline_jit_restrict_* APIs for JIT on iOS"
    （cedar 分支，autoland `1080811a9d3dc3193ddf4b5a36575cfe2e455cc4`）——为 iOS 启用
    `JS_USE_APPLE_FAST_WX`。
- Apple 侧要求（官方页面 + Apple Developer 文档《Protecting Code Compiled Just-In-Time》）：
  - 需 entitlement：`com.apple.developer.web-browser-engine.host`、extension entitlement、
    `allow-jit`、`extended-virtual-addressing`；仅 EU 分发，且需满足 90% WPT、80% Test262、
    安全承诺等条件（iOS 17.4+ / iPadOS 18+）。
- 现状差距：vulpra 树只 patch 了 entitlement 文件，**没有链接 BrowserEngineCore framework**；
  需要移植上游 cedar 分支的 patch 集并接入 BrowserEngineKit 的 extension 体系。
- 结论：**EU 发行路线的正解**，工作量最大；在 Vulpra 目标市场不在 EU 时不做。

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

1. **真机 benchmark gate（近期）**：路线 A。Vulpra TIPA 已带 `get-task-allow`，用开发证书 +
   debugserver（SideJITServer）附加后重跑 Speedometer 3.0 同子集，对齐 Safari 11.24 基线，
   把"JIT 落后 2.1 倍"细化为"同机 JIT 差距"与"引擎自身差距"。
2. **发行（默认）**：维持解释器模式（5.267 基线）。JIT 发行需要路线 B（EU）或 Apple 政策变化，
   两者都不受我们控制。
3. **目标 EU 时**：重估路线 B，跟踪 Firefox cedar 分支 JIT-on-iOS 补丁集，评估移植到 vulpra
   v5 patch 体系（`Engine/GeckoPatches/v5/`）。

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
- [ ] 评估 SideJITServer 对 Vulpra TIPA 的附加流程（前置条件 `get-task-allow` 已具备）
- [ ] 路线 A 生效后重跑真机 Speedometer 3.0，与 5.267 / 11.24 对齐
- [ ] 若走 EU：跟踪 Firefox cedar JIT-on-iOS patch 集，评估 cherry-pick 到 v5 patch 体系
