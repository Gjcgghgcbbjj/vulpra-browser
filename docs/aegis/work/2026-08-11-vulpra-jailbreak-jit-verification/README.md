# 越狱 JIT 真机验证（Dopamine 2 / rootless）

目标：在用户 Dopamine 2（隐根）真机上，验证 Vulpra 越狱 JIT 路线：装带门控补丁的
TIPA → `launchctl setenv VULPRA_ENABLE_JIT 1` → 引擎子进程 argv 带 `-enable-jit` →
不调用 `JS::DisableJitBackend()` → MAP_JIT（Dopamine "Allow JIT in Apps" 已置
CS_DEBUGGED）→ Speedometer 3 对比 5.267（解释器）。

## 前置（2026-08-11 已确认）

- 设备：Dopamine 2（rootless 隐根），iOS 15.0–16.6.1 范围
- Dopamine → Settings → **Allow JIT in Apps = 开**（2.1+ 内置，默认开）
- Vulpra TIPA：`get-task-allow` 已具备（`EngineProcess.private.entitlements`）
- 引擎：v5 系列 order 249（route-jailbreak-jit.patch）产物 + 门控注入

## 步骤

### 1. 安装 TIPA

把 `Vulpra-TrollStore.tipa`（越狱实验版 artifact）拷到 iPhone，用 TrollStore 安装
（或越狱环境直接安装；若 TrollStore 版在越狱态不生效，换越狱安装方式复测——
dolphin-ios issue #116 有巨魔版/越狱态 JIT 冲突先例）。

### 2. 开启 JIT（每次启动 Vulpra 前）

SSH 到设备（Dopamine 带 SSH/Dropbear）或设备上 NewTerm：

```sh
launchctl setenv VULPRA_ENABLE_JIT 1
```

然后打开 Vulpra。SpringBoard 启动的 app 继承 launchd 环境变量 → 主进程
`GeckoChildProcessHost` 读到 → 每个子进程 argv 注入 `-enable-jit` →
`ChildProcessInitImpl` 命中 → JIT backend 保留。

关闭 JIT（对照实验）：

```sh
launchctl unsetenv VULPRA_ENABLE_JIT
```

### 3. 确认 JIT 生效（3 个检查，从轻到重）

1. **env 确实设上了**（shell 里）：
   ```sh
   launchctl getenv VULPRA_ENABLE_JIT   # 应输出 1
   ```
2. **子进程真的带 `-enable-jit`**（argv 注入证据）：
   - Mac:`idevicesyslog | grep -i vulpra | grep -iE 'child|content|pid'`
   - 设备 NewTerm:`log stream --predicate 'process == "Vulpra"' --style compact`
     找 `EngineChildProcessEvent` 阶段日志里的 `pid=`；越狱环境可
     `ps aux | grep -i vulpra` 辅助（iOS ps 不一定显示完整 argv，以分数为准）。
3. **最终判据 = 分数差距**：JIT 开明显高于 5.267 即生效。

### 4. Speedometer 3 跑分

- 官方 https://browserbench.org/Speedometer3.0/（与 CI 同一 4-suite 子集、单次迭代）
- 记录分数到下表

## 记录表

| 环境 | 分数 | 备注 |
| --- | --- | --- |
| Vulpra 真机解释器（基线） | 5.267 | 2026-08-10，v5 r0.3 |
| **Vulpra 真机 JIT 开（本次）** | 待填 | `launchctl setenv VULPRA_ENABLE_JIT 1` |
| Vulpra 真机对照（默认关） | 待填 | unset env 后重跑，预期 ~5.267 |
| Safari 真机 | 11.24 | 2026-08-10 |

## 判定

- **通过**：JIT 开显著高于 5.267（参考 Simulator 开关差 ≈1.76×，真机预期同量级方向），
  且对照（默认关）仍 ~5.267 → 门控未破坏默认行为。
- **部分通过**：JIT 开无提升 → 查 argv 是否注入（syslog）、CS_DEBUGGED 是否置位
  （Dopamine 开关）、MAP_JIT 是否成功（崩溃/日志）。
- **失败/冲突**：越狱态下 TrollStore 版拿不到 JIT → 换越狱安装方式；Choicy 禁用注入 →
  开 Allow JIT 无效。

## 常见问题排查

| 现象 | 排查 |
| --- | --- |
| TIPA 装不上/装完不出现 | TrollStore 版本；确认装的是 `Vulpra-TrollStore-jailbreak-jit.tipa`（不是旧版 `Vulpra-TrollStore.tipa`） |
| 启动即崩 | 检查 Choicy 是否对 Vulpra 禁了 tweak 注入（Dopamine Allow JIT 依赖注入，被禁则无效）；崩溃报告看是否 MAP_JIT/exec-mem 相关 |
| 打开正常但分数无提升 | `launchctl getenv VULPRA_ENABLE_JIT` 确认=1；确认 Dopamine → Settings → Allow JIT in Apps 开；syslog 看 argv 是否注入 |
| 越狱态下 JIT 反而没开 | 巨魔版在越狱态已知有冲突先例（dolphin-ios #116）；换越狱环境直接安装 TIPA 复测 |
| 重启后回到解释器 | `launchctl setenv` 重启后失效，重启后重设一次即可（与每次开浏览器无关） |

## 与既有路线的衔接

- 真机冒烟通过 → ADR-0005 转 recorded 前置之一（差值已归档 2026-08-11）
- 数值归档到 `docs/aegis/work/2026-08-09-vulpra-standard-benchmark/README.md`

## 更新（2026-08-11 第二轮）

### 真机 5.363 = JIT 未生效（记录为证据）

- 用户装 jailbreak-jit TIPA 后跑出 **5.363**（基线 5.267，仅 +1.8%）→ JIT 未生效。
- 结论：`launchctl setenv VULPRA_ENABLE_JIT` 的 SSH 前置在用户侧不可行（"跑不了"），
  真机侧无法执行 → env 从未注入 → 子进程无 `-enable-jit` → 解释器模式。**不能据此判定
  appex CS_DEBUGGED 缺失**，该未知项仍未解。
- 工程产物侧复核通过：release 引擎 manifest `patchSet.sha256` =
  `b7f11022…`（order 249 门控），XUL 二进制含 `-enable-jit`；桌面
  `Vulpra-TrollStore-jailbreak-jit.tipa` sha256 `f067caa9…` 即新包；
  旧包（e46c607）XUL 无门控字符串。

### 新方案：App 内自动探测 CS_DEBUGGED 并自启 JIT（无 SSH 依赖）

- commit `b143b54` / `2d97b00`：`App/main.swift` 启动时 `csops(CS_OPS_STATUS)` 读自身
  CS flags；命中 `CS_DEBUGGED (0x800)`（Dopamine "Allow JIT in Apps" 置位）→
  `setenv("VULPRA_ENABLE_JIT","1")` → 引擎父进程照常注入 `-enable-jit` 子进程 argv。
- 非越狱/未置位 → 不设 env → 保持解释器（默认不破坏）；模拟器分支跳过。
- 打包 run `31433697877`（3m38s）：`Vulpra-TrollStore-jailbreak-jit-auto.tipa`
  sha256 `7b14385b0361be5ef73d77c47151ee0bbd135f28815dc9097c9044271b82cf63`，
  App build 0.2.0 (5)，uiFingerprint `porcelain-zh-v4-jit-auto-20260811`；
  XUL 门控字符串在场，App 二进制含 `Real-device JIT` 日志与 `VULPRA_ENABLE_JIT`。

### 判定分支（用户装 auto 版后）

- 分数 ~9+ → JIT 生效，appex CS_DEBUGGED 判据成立 → 走收尾清单。
- 仍 ~5.3 → 主 App 未置 CS_DEBUGGED（Choicy 禁注入/开关未生效）→ 查
  `log stream --predicate 'subsystem == "com.vulpra.browser"'` 看
  `Real-device JIT:` 日志分支。
- 闪退 → appex 未继承 CS_DEBUGGED（MAP_JIT 失败）→ 换越狱直装/StikDebug/引擎侧方案。

## 更新（2026-08-11 第三轮）：真机判据落地

- 用户装 auto 版（run 31435973444，sha256 `32502362…`）后跑分 **5.584**（≈基线），
  起始页自检显示 **`JIT: not-debugged`** → 主 App 进程没有 CS_DEBUGGED。
- 依据 Dopamine 源码（`BaseBin/launchdhook/src/jbserver/jbdomain_systemwide.c`）：
  check-in 时 `fullyDebugged = markAppsAsDebugged` 只对路径前缀
  `/private/var/containers/Bundle/Application` 或 `${JBROOT}/Applications` 的进程生效，
  且 **依赖 dyldhook/systemhook 注入链（即 tweak 注入）**——官方 release note 明确
  "Allow JIT in Apps" 对 Choicy 禁用注入的 App 无效。
- 结论：用户设备 tweak 注入被禁（Choicy 或 Dopamine 每 App 注入开关）→ check-in 未发生
  → 无 CS_DEBUGGED → 引擎子进程无 `-enable-jit` → 解释器 5.584。
- 下一步：用户开启 Vulpra 的 tweak 注入 → Restart SpringBoard → 重开 Vulpra，
  起始页应为 `JIT: CS_DEBUGGED` → 跑分预期 ~9+。
- 若开启注入后仍 not-debugged：查 Dopamine 版本（≥2.1）、safe mode、每 App 注入列表。
