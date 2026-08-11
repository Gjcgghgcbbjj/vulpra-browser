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

## 更新（2026-08-11 第四轮）：not-debugged 实为探针位错误，已修复

- 上述第三轮结论（tweak 注入被禁）**作废**。真机 iOS 上 `csops(CS_OPS_STATUS)`
  的 `CS_DEBUGGED` 位于 **第 28 位 `0x10000000`**（证据：Dopamine 源码
  `/tmp/dopamine-src/BaseBin/libjailbreak/src/codesign.h`；PPSSPP PR #12421；
  Delta 模拟器 `ProcessInfo+JIT.swift`）。旧探针只查第 11 位 `0x800` → 误报
  `not-debugged`。
- 修复 `App/main.swift`（提交 `e754582`）：`debuggedMask = 0x10000000 | 0x00000800`，
  并把原始 `flags=0x%08X` 显示到起始页，避免再次误判。
- 新构建 run 31438094897（TIPA sha256 `aa0f38c6…`，build 5）已放 Win 桌面
  `Vulpra-TrollStore-jailbreak-jit-auto.tipa`；XUL 含 `-enable-jit` 门控，
  主二进制含 `CS_DEBUGGED (flags=0x%08X)` 标记。起始页预期显示
  `JIT: CS_DEBUGGED (flags=0x10000000…)`。
- 待真机确认：显示 CS_DEBUGGED + 跑分 ~9+ → 收尾清单推进；
  若仍 not-debugged 再回到第三轮的注入/版本排查；
  若启动崩溃 → appex MAP_JIT 未继承（见上方替代方案）。

## 更新（2026-08-11 第五轮）：真机显示 CS_DEBUGGED 但浏览器卡到基本用不了

- 用户装位修复版（e754582，sha aa0f38c6）后起始页显示 `JIT: CS_DEBUGGED`，
  但网页"非常卡基本用不了"。JIT 门已开但执行路径可疑。
- 关键架构事实：网页 JS（含 benchmark）跑在 **Vulpra Engine Process appex
  实例**（Gecko content 子进程）里，主 App 的 CS_DEBUGGED ≠ 子进程的
  CS_DEBUGGED。若子进程没有调试标记，MAP_JIT 在 JS::Init 失败，
  release 下后续 JIT 分配直接崩 → content 进程反复重启 = "基本用不了"。
- 诊断版 v6（43b6868，TIPA sha c0accca1，build 6）：
  - appex 每次启动自检：csops 自身 CS 标志 + 真实 mmap(MAP_JIT)+mprotect(RX)
    测试 + 启动计数器，写 /var/mobile/Documents/vulpra-jit-probe.json
    （+ /tmp 兜底），主 App 起始页 2 秒轮询显示。
  - 产物验证：XUL 仍含 -enable-jit 门控；主二进制含 appex 探针读取代码；
    appex 二进制含探针路径与 csops/mmap/mprotect 符号（短字符串字面量被
    ARM64 优化为指令立即数，字符串扫描看不到属正常）。
  - 已放 Win 桌面 Vulpra-TrollStore-jailbreak-jit-auto.tipa。
- 真机判读：
  - appex debugged=NO / mapjit=fail → 根因确认：子进程无 CS_DEBUGGED。
    修复方向：让 appex 获得调试标记（Dopamine 注入范围/每扩展开关）、
    或把网页 JS 挪回主进程（关 Fission/e10s + 关 main_process_disable_jit pref）。
  - appex debugged=yes / mapjit=ok 但卡 → 查编译压力/内存/渲染，非 MAP_JIT。

## 更新（2026-08-11 第六轮）：自适应 v7 - appex 探针驱动的模式选择

- 用户尚未回报 v6 探针结果；趁等待产出 v7（75f8c5e，TIPA sha 5c5cba63，build 7）：
  - `App/main.swift` 启动时读 appex 探针文件：`mapjit`/`mprotect` 含 "fail"
    → 不设 VULPRA_ENABLE_JIT（解释器模式，保证流畅，~5.5）；否则照常开 JIT。
    探针文件每次 appex 启动重写 → 模式自愈（将来 appex 可 JIT 后自动恢复）。
  - JIT 模式下进程池缩减：`dom.ipc.processPrelaunch.fission.number=0` +
    `dom.ipc.processCount=2`（避免多实例 JIT 进程内存压力/jetsam 重启）；
    解释器模式维持 2/4 基线。已避开 `processPrelaunch.enabled`
    （不在 pref 契约快照内，fission.number 即真实旋钮）。
  - 起始页第一行直接显示所选模式（JIT开启 / 解释器回退+原因）。
- 待用户回报：v6/v7 起始页两行 + 机型/iOS 版本 + Speedometer。
- 若确认 appex 无法 MAP_JIT（mapjit=fail）：推进"网页 JS 跑在主进程"方案
  （主进程已确认 CS_DEBUGGED；需关 e10s/Fission 可行性核实 + 翻
  main_process_disable_jit pref）。

## 更新（2026-08-11 第七轮）：v8 探针正证门控 + 主进程路线可行性调研

### v8（ba52e6f，build 8）：探针必须"正证可 JIT"才开

- v7 的缺陷：探针文件不存在时（v5 直升 v7、或首次安装后首启）默认开 JIT——
  若该机 appex 无法 MAP_JIT，首启仍会进入"卡到基本用不了"的崩溃循环，直到
  用户杀掉重开第二次才自愈。对"最终交付流畅版"不可接受。
- v8 反转门控（`App/Build/VulpraJitProbe.swift` `appexJITAvailable()`）：
  JIT 仅在探针**同时满足 mapjit=="ok" && mprotect=="ok"** 时开启；探针缺失
  或含 fail → 解释器模式（流畅 ~5.5），起始页第一行显示原因
  （`appex探针未就绪(首启解释器,重启后自动评估JIT)` 或
  `appex无法JIT(mapjit=.. mprotect=..)`）。探针每次 appex 启动重写 →
  设备一旦证明可 JIT，下次启动自动升级。三个分支（fail/ok-但卡/成功）下
  该改动均严格更优，不依赖待测数据。
- 验证：三套 portable gate 全绿（Browser / RuntimeShell / IndependentEngine）；
  `generate-build-identity.py --check` 通过；build identity 0.2.0 (8)
  fingerprint `porcelain-zh-v4-jit-probe-required-20260811`。
- 打包 run 31483222670（head ba52e6f）。桌面交付时 v7 保留为备份文件名，
  `Vulpra-TrollStore-jailbreak-jit-auto.tipa` = v8。
- 真机判读口径不变：起始页第二行 appex 探针
  （flags/debugged/mapjit/mprotect/launches/pid）是决策依据。

### 主进程路线（分支 1 后备）源码级可行性调研结论

若 v6/v7/v8 探针确认 appex debugged=NO/mapjit=fail，把网页 JS 挪回主进程
需要同时满足以下三条件，**均不成立或需重编引擎**：

1. **关 e10s**：`BrowserTabsRemoteAutostart()`（nsAppRunner.cpp:557-600）在
   父进程只认 `MOZ_FORCE_DISABLE_E10S=1` env（MOZILLA_OFFICIAL 下还需
   `xpc::AreNonLocalConnectionsDisabled()`=true，独立浏览器成立）；关后
   FissionAutostart 同步强制 false（nsAppRunner.cpp:940-947）→ 网页 JS 进
   主进程。主进程读 env 可靠（v5 已证），可在 main.swift setenv。**但**：
2. **关 `javascript.options.main_process_disable_jit`**（StaticPrefList.yaml:9946，
   XP_IOS 默认 true，mirror:always）：主进程 `nsXPConnect::InitJSContext →
   InitJSEngine` 在启动早期读取该静态 pref，一旦 `DisableJitBackend()` 执行
   便单向不可逆；运行时 `GeckoView:Preferences:SetPref`（markReady 阶段）
   太晚。需启动前注入（引擎 patch / app 内 defaults pref 机制，均需验证）。
3. **非 e10s 渲染路径**：本 iOS 平台补丁围绕远端渲染构建
   （widget/uikit + RemoteLayerTreeOwner + CompositorBridgeChild 等）；进程内
   渲染（InProcessCompositorWidget 补丁存在但覆盖面未验证）整链路无人跑过，
   风险高。

结论：主进程路线 = 引擎重编（patch main_process_disable_jit 的 iOS 默认 /
   加启动前 pref 注入）+ 全新渲染路径真机验证，成本高、风险大，**作为最后手段**；
   优先在 appex 侧找 CS_DEBUGGED（Dopamine 每 App tweak 注入开关/Choicy 对
   Vulpra 的注入状态、重启 SpringBoard 后重测），因为 v6/v7 探针可直接给出
   appex 真实 CS 状态。

### Dopamine 源码复核（appex 应继承 CS_DEBUGGED）

- `launchdhook/src/jbserver/jbdomain_systemwide.c:213-226`：check-in 按
  进程自身 `procPath` 前缀（`/private/var/containers/Bundle/Application` 或
  `/var/jb/Applications`）+ `jbsetting(markAppsAsDebugged)` 置
  `fullyDebugged` → `cs_allow_invalid`。appex 路径在前缀内。
- `systemhook/src/common/common.c` spawn hook 对全部 spawn 注入
  `DYLD_INSERT_LIBRARIES`（除非 Choicy 对该 app 关注入）。
- 因此主 App 显示 CS_DEBUGGED 时 appex **大概率同样 debugged**（v6 探针直接
  验证）。若 appex 显示 NO：先查 Dopamine → Vulpra 的 tweak 注入开关 /
  Choicy 设置 / 重启 SpringBoard 后再测，再考虑主进程路线。

## 更新（2026-08-11 第八轮）：v8 已打包交付

- 打包 run 31483222670（head ba52e6f，conclusion=success）：
  - TIPA sha256 `bf567ea8e1d20b9e22de23c590b7e861c9a2cd9f7192f0fd9098e7b444a36252`
    （artifact `vulpra-independent-ios-31483222670`，包内 SHA256SUMS 一致）
  - App build 0.2.0 (8)，fingerprint `porcelain-zh-v4-jit-probe-required-20260811`
  - 验证：CFBundleVersion=8；主二进制含 `appex JIT not proven` 日志与全部 v8
    中文探针串（字节级确认：`appex探针未就绪` @402288、`appex无法JIT` @402352、
    `首启解释器,重启后自动评估JIT` @402309）；XUL `-enable-jit` 门控 count=2；
    appex 二进制含探针路径。
- 桌面布局（Win 桌面）：
  - `Vulpra-TrollStore-jailbreak-jit-auto.tipa` = **v8**（sha bf567ea8）
  - `Vulpra-jailbreak-jit-auto.ipa` = v8
  - `Vulpra-TrollStore-jailbreak-jit-auto-v7备份.tipa` / `...-v7备份.ipa` = v7 备份
  - `Vulpra-JIT自动开启版说明.txt` 已更新为 v8 测试指引（首启解释器属正常，
    打开过网页后重启一次自动评估 JIT）
  - 本地副本：/root/Vulpra-ba52e6f-jit-probe-required.tipa / .ipa
- 待用户回报：v8 起始页两行（重点 appex 探针）+ 机型/iOS + Speedometer。
- 分支判读（沿用第六/七轮口径）：mapjit=fail → 主进程路线（需引擎重编，
  调研结论见第七轮）；mapjit=ok 但卡 → 内存/编译压力分支；mapjit=ok 且 ~9 → 收尾。
