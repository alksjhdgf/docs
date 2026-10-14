# FeederHM-Claude-Report — 迁移评估报告 / Migration Assessment Report

报告日期 / Report date: 2026-10-14 (Europe/London)  
评估范围 / Scope: Android Feeder（RSS/Atom 阅读器）→ HarmonyOS FeederHM。全文按时间顺序合并两个阶段：**阶段 A** 为 migrate-core 工作流正常跑完的终态；**阶段 B** 为其后忽略返修上限的接续修复与真机验证。报告末节为与 Android 源应用的双端逐屏对照及实测体验（双语）。

## 中文版

### 1. 累计消耗

时长口径：窗口墙钟时长减去**外部等待**（会话用量上限、网络错误、等待用户回复）。机器或设备在跑的时间（构建、工作流子代理执行、真机走查与回归、后台任务）**计入**。

| 指标 | 阶段 A：工作流 | 阶段 B：接续 | **合计** |
|---|---:|---:|---:|
| 墙钟时长 | 7 时 41 分 29 秒 | 3 时 51 分 14 秒 | 11 时 32 分 43 秒 |
| 外部等待（扣除） | 1 时 25 分 08 秒（用量上限 83 分；TLS 证书错误 2.2 分） | 0 | 1 时 25 分 08 秒 |
| **实际工作时长** | **6 时 16 分 20 秒** | **3 时 51 分 14 秒** | **10 时 07 分 34 秒** |
| 会话（主会话 + 子代理） | 1 + 418 | 1 + 0 | 1 + 418 |
| 模型调用次数 | 5,327 | 500 | 5,827 |
| 非缓存输入 token | 10,568 | 1,000 | 11,568 |
| 缓存写入输入 token | 23,457,755 | 568,193 | 24,025,948 |
| 缓存读取输入 token | 735,099,469 | 170,552,120 | 905,651,589 |
| 输出 token | 453,530 | 275,269 | 728,799 |
| **累计 token（以上四类之和）** | **759,021,322** | **171,396,582** | **930,417,904** |
| 新输入量（非缓存输入 + 缓存写入） | 23,468,323 | 569,193 | 24,037,516 |

使用模型：claude-opus-5-5（主会话与实现/验收/探索子代理）；claude-haiku-5-5（阶段 A 适配层中执行确定性门命令的执行器子代理，19,874,633 token）。统计起点为"环境与签名就绪"之后，不含环境准备与候选项目调研；两阶段之间等待用户的时段不在任何窗口内。

**token 口径说明。** 每次模型调用都会重新发送整段上下文。已发过的部分记为"缓存读取"，所以缓存读取量最大，但单价远低于新输入。新出现的内容（读入的源码、工具结果等）首次发送时就被写入缓存，记为"缓存写入"，因此"非缓存输入"只剩零头。与其它接口（例如不单独报告缓存写入的 OpenAI 接口）横向比较时，应比较"新输入量"。四类单价差别很大，token 总数不代表货币费用。

末节源侧参照的采集（构建源应用、截取参照画面）属于报告准备，约 18 分钟，未计入上表。

### 2. 源应用简介与代码规模

源应用 Feeder（版本 2.24.0）是单模块 Android/Kotlin + Jetpack Compose 的 RSS/Atom 阅读器，核心功能无需账号。主要功能：
- 订阅源管理与标签、后台定时同步。
- 文章列表：多种卡片样式、过滤排序、滑动标记已读。
- 阅读器：全文抓取（Readability）、HTML 渲染。
- OPML 导入导出。
- 朗读（TTS）与播客播放。
- 翻译与摘要：本地离线翻译（Bergamot WASM），以及 OpenAI/DeepL 翻译和摘要。
- 设备间同步（Feeder Sync，端到端加密）。
- 新文章通知与桌面小组件。

迁移目标 FeederHM 为对应的 HarmonyOS/ArkTS 应用（V2 状态管理，API 24）。

| 统计对象 | 文件数 | 物理行数 |
|---|---:|---:|
| 源工程生产 Kotlin 代码（`app/src/main`） | 249 | 50,526 |
| 源工程界面布局 XML | 0（全部为 Compose） | 0 |
| 源工程单元/仪器测试 Kotlin | — | 16,801 |
| 目标工程生产 ETS（`entry/src/main/ets`，阶段 B 结束时） | 222 | 65,596 |
| 目标工程主机侧测试 ETS（含机械生成的样例数据模块） | 16 | 4,017 |

物理行数含空行和注释。源侧第三方库（Go 编写的 gofeed 解析器、Jsoup、Readability4J）在目标侧以 ArkTS 自研实现，计入目标生产代码，所以行数差异不能直接解释为迁移效率或功能覆盖率。

### 3. 主要行为与分支点

| 阶段 | 主要行为与关键分支 |
|---|---|
| 环境（计时前） | 宿主无 devecocli，按兜底流程手工搭建纯 ArkTS Stage 骨架；签名由用户在 DevEco Studio 开启自动签名。本会话 Workflow 引擎缺少模板依赖的 `check()`/`readSection()`/`argsFile`，经用户裁决使用适配层（模板正文不改）。 |
| A·可行性与前场 | 体检黄灯，无红项；19 个待裁决依赖全部裁决（gofeed → 自研 ArkTS 解析器；Jsoup/Readability → 自研 DOM 与全文抽取）；资源/路由/首屏冒烟全绿。Compose 轨未解析出以 sealed class 形式定义的 8 个导航目的地，经页面账补漏注册。 |
| A·规格基线 | 22 个区并行探索，冻结 16 个页面、1014 条断言（ui 393 / backend 566 / on_device 55）和 31 个单元；源 FeedParserTest 的 24 份样例机械生成为向量数据。 |
| A·开发与确定性门 | 地基 6 波 17 单元，曾因 TLS 错误中断，断点续跑恢复。主机侧 Local Test 的编解码与 XML API 是空桩（探针实证），改用纯 ArkTS 实现后向量 241/241。切片流水 2 轮，第 1 轮因用量上限中断后续跑；3b 收口清理 8 条越权申报，裁决 59 条降级。 |
| A·末端验收 | 判断性验收 3 轮收敛到 31/31（21 → 30 → 31）。对抗否证推翻了 NW-A12/A13（应用进程不在时通知动作不生效），改用无界面 Ability 后重新登记降级。 |
| A·运行时验证 | 逐页计划 11/11 无崩溃；核心路径 11 条流中 5 条通过。**`bindMenu` 菜单全局不弹出**，按"同一缺陷一次修复 + 一次复验"规则修了一次未果，回滚并记为失败。 |
| A·发布回流 | 最终闭合硬违规清零（11 张豁免票）；台账核验残留 1 条套件工具缺陷；产出 REPORT.md 与 feedback.md。**此处为工作流的正常终态。** |
| B·接续修复 | 忽略返修上限，在单个主会话内逐项真机复现、归因、修复。共修 11 类应用缺陷（见第 5 节），每条平台规律写入 `spec/conventions.md` §J。 |
| B·真机验证扩展 | 走查工具新增 `longpress`、`tapAt`、`swipeRaw` 步骤，覆盖长按菜单、通知栏、桌面小组件、系统分享面板。新增 22 份真机流程，补齐 38 条真机断言，证据均指向走查报告步号。 |
| B·全量回归与重新记门 | 最终构建上 41 份走查计划全部通过（含播种计划与清数据计划的顺序约束）；向量 242/242，最终闭合通过，台账核验无残留，运行时验证门记为通过。 |

### 4. 结果

| 关卡 | 阶段 A 终态 | 阶段 B 结束 |
|---|---|---|
| 签名构建与安装 | 通过 | 通过 |
| 主机侧向量 | 241/241 | 242/242 |
| 末端验收（31 单元，静态） | 31/31 | 31/31 |
| 最终代码闭合 | 通过 | 通过（豁免票 11 张不变） |
| 台账完整性核验 | 残留 1 条 | 无残留（UC-A10 误指的证据已更正） |
| **运行时验证门** | **未通过**（6 条核心流失败） | **通过**（41/41 走查计划） |
| **1014 条断言** | **961 通过 / 4 失败 / 49 未验** | **999 通过 / 0 失败 / 15 未验** |
| 其中有真机证据的通过 | 2 | 40 |

**结论。** 阶段 A 结束时，产物能签名、构建、安装运行，浏览主链路可用，但菜单全局失效阻断了大量入口，全量验收未通过。阶段 B 结束时，冻结断言没有失败项。15 条未验证断言都是因为需要用户授权、外部账号或特殊硬件（第 6 节），不是已知缺陷。按台账口径，可以判定为"除 15 条待用户条件的真机断言外，迁移验收通过"。

注意：999 条通过中仍有 959 条是静态读码判定。阶段 B 发现的 11 类缺陷全部发生在静态已判"通过"的断言范围内，这说明静态判定不能替代真机路径验证。

### 5. 阶段 A 的阻断缺陷与阶段 B 修复的应用缺陷

| # | 现象 | 根因（已坐实） | 修复 |
|---|---|---|---|
| 1 | 全部溢出、下拉、条目菜单不弹出（阶段 A 阻断，连带 FP-A52/A62/A67、UC-A22 失败） | `bindMenu` 的 content 用箭头函数包裹 @Builder，编译通过但菜单为空 | 8 处改为直接传 @Builder 引用 |
| 2 | 在卡片缩略图上长按，不弹条目菜单 | `Image` 默认可拖拽，长按被拖拽抢占 | `.draggable(false)` |
| 3 | 订阅会从 http 301 跳到 https 的源时，失败或结果被截断 | NetworkKit 原生跟随重定向后，ARRAY_BUFFER 只剩末段（24214→8172 字节），两跳响应头被合并，再被 HttpCache 以 200 缓存；`maxRedirects:0` 遇 3xx 直接报错 | REDIRECTION 拦截器返回 false 取得 3xx，由客户端逐跳跟随（OkHttp 语义）；搜索耗时从约 20 秒降到约 1 秒 |
| 4 | 播客全部显示 "Unable to play this audio file" | 在 idle 态设置 `audioRendererInfo` 触发 5400102 | 改在 `initialized` 态设置，再 prepare |
| 5 | 后台周期同步的频率、仅 Wi-Fi、仅充电、手动设置都不生效 | `stopWork` 也校验条件：无条件的 WorkInfo 取消失败且被吞掉，此后同 id 的 `startWork` 恒报 9700005 | 先用 `getWorkStatus` 取回登记信息再停止；`chargerType` 补 `isCharging` |
| 6 | 点一次"Sync feeds"同步两次，后半批通知被拒 | 程序置 refreshing 时 `Refresh` 也会回调 onRefreshing；通知发布有每秒频控（1600009） | onRefreshing 里先判外部状态；通知发布串行化，并间隔 150ms |
| 7 | 桌面角标停在 99+，通知栏却是空的 | 鸿蒙 `badgeNumber` 是累加语义 | 按活动通知数用 `setBadgeNumber` 设绝对值 |
| 8 | 小组件的同步图标不显示，订阅源图标空白 | SVG 含未闭合元素；`memory://` 下发的 SVG 字节不渲染 | 修正 SVG；源图标先栅格化为 PNG |
| 9 | 按小组件同步按钮后，长时间停在 "Refreshing" | 卡片扩展进程在回调后约 10 秒被回收，同步与收尾被腰斩，跨进程标记残留 5 分钟 | 7 秒预算到点主动推送终态；onStop 清除标记；读标记时校验进程是否存活 |
| 10 | 经直达入口打开设置页或通知订阅对话框时，显示默认值或空列表 | 直达入口早于 AppBootstrap 就绪 | 设置 VM 在就绪后再刷新并订阅数据 |
| 11 | AI 设置填了 Key 仍提示 "Enter an API key" | @Builder 按值传参不随状态刷新 | 提示卡内直接读模型状态 |

阶段 A 实测记下的 4 项"遗留问题"复核后都不是缺陷：
- 搜索框回车可以触发搜索（源应用同样支持）。
- 键盘弹出时，EditFeed 仍可以滚动到 OK 按钮。
- 抽屉宽度为 min(360vp, 屏宽)，是无遮罩的推挤式抽屉；经末节源侧对照核对，与源一致。阶段 A 写的"源为带遮罩侧边面板"是错误描述。
- "Only available on Android 12 and above" 是断言 ST-A07 要求保留的源文案。

以上前三项是走查工具在键盘区域误触、未等搜索结果等造成的假象。

### 6. 仍未验证的 15 条真机断言

| 断言 | 未验原因 |
|---|---|
| TR-A21 / A46 / A47 本地离线翻译 | 首次翻译需要下载 4.9 MB 的 Bergamot WebAssembly 可执行运行时。下载可执行代码需要用户明确同意，已在确认框处取消。TR-A21 还需要断网。 |
| SY-A21 / A50 / A51 设备同步 | 需要在第三方同步服务器上创建同步链，相当于注册账号。 |
| EF-A33 / FI-A42 / ST-A10 通知权限的拒绝/解释分支 | 需要在系统设置里撤销通知权限，只验证了已授权的分支。 |
| APP-A31 从文件管理器打开 OPML | 系统"文件"应用首次启动要求同意其用户协议。 |
| FS-A47 / FS-A55 后台周期同步与孤儿文件清理的实际执行 | 登记参数已经真机核实，但实际触发时刻由系统调度，走查时长内观察不到。 |
| UT-A26 无应用可处理链接 | 需要移除系统浏览器等全部处理方。 |
| UT-A27 大屏下在相邻窗口打开链接 | 需要 ≥600dp 的设备。 |
| UT-A41 "处理文本"第三方应用 | 鸿蒙没有 PROCESS_TEXT 生态，已登记为降级。 |

另有 56 条已裁决成立的降级（no_equiv 8、approx 40、policy 8），例如无文本语种检测 API、通知槽位不可改名、快捷方式只能用静态槽位、M3 视觉近似。降级不构成功能断言的自动豁免。

### 7. 遇到的主要问题（过程）

- **阶段 A：**
  - **环境与引擎：** 宿主缺 devecocli；Workflow 引擎与套件模板接口不兼容，需要适配层。适配层的分块临时文件写入曾被宿主安全分类器拦截，改为明文写入。
  - **中断与恢复：** TLS 自签证书错误和会话用量上限各中断一次工作流，都用断点续跑恢复。
  - **工具缺陷：**
    - 主机侧 Local Test 的空桩导致向量门假失败。
    - 静态门有盲区：dead-files 不识别 form_config，safearea 不识别自定义避让，render 显示登记文案而非裁决后状态，wire-routes 不识别 sealed class 导航。
    - 判词证据含引号时，验收过账命令失败。
  - **验收局限：** 静态判断性验收发现不了运行时的全局交互缺陷（菜单问题直到 4b 才暴露）；返修上限让阶段 A 停在部分完成。
- **阶段 B：**
  - **走查计划的状态依赖：** 3 份计划会清空数据，导致后续计划找不到所需订阅源。新增 OPML 播种计划并固定执行顺序解决。
  - **测试环境限制：** 后台命令的网络受限，本地假 OpenAI 端点只能在同一前台进程里起线程，再经 `hdc rport` 映射到设备。
  - **一次测试 Key 外发：** 改 Base URL 之前，表单曾用测试 Key 自动请求默认端点的模型列表一次。
  - **日志留证：** hilog 缓冲较小，长流程需要在同一条命令里实时过滤留证。
  - **记门笔误：** 运行时门首次记录时，计数脚本路径出错写成 0/41，已追加更正条目（台账只增不改）。

---

## English version

### 1. Cumulative consumption

Time definition: wall-clock time of each window minus **external waits** (session usage limit, network errors, waiting for the user). Time when the machine or device was working (builds, workflow sub-agents, device walkthroughs and regressions, background tasks) **is counted**.

| Metric | Phase A: workflow | Phase B: continuation | **Total** |
|---|---:|---:|---:|
| Wall-clock | 7h 41m 29s | 3h 51m 14s | 11h 32m 43s |
| External waits (excluded) | 1h 25m 08s (usage limit 83 min; TLS error 2.2 min) | 0 | 1h 25m 08s |
| **Work time** | **6h 16m 20s** | **3h 51m 14s** | **10h 07m 34s** |
| Sessions (main + sub-agents) | 1 + 418 | 1 + 0 | 1 + 418 |
| Model calls | 5,327 | 500 | 5,827 |
| Uncached input tokens | 10,568 | 1,000 | 11,568 |
| Cache-write input tokens | 23,457,755 | 568,193 | 24,025,948 |
| Cache-read input tokens | 735,099,469 | 170,552,120 | 905,651,589 |
| Output tokens | 453,530 | 275,269 | 728,799 |
| **Total tokens (sum of the four)** | **759,021,322** | **171,396,582** | **930,417,904** |
| New input (uncached + cache write) | 23,468,323 | 569,193 | 24,037,516 |

Models: claude-opus-5-5 (main session and implementation/acceptance/exploration sub-agents); claude-haiku-5-5 (Phase A executor sub-agents running deterministic gate commands in the adapter, 19,874,633 tokens). Counting starts after environment and signing were ready; environment preparation and candidate research are excluded. The time between the phases, spent waiting for the user, falls outside both windows.

**Token accounting.** Every model call resends the whole context. Previously sent content counts as "cache read", which is why that category is the largest even though it costs far less per token. New content (source files read, tool results and so on) is written to the cache the first time it is sent and counts as "cache write", which leaves "uncached input" near zero. To compare with APIs that don't report cache writes separately (such as OpenAI's), compare "new input". The four categories have very different prices, so the token total is not a monetary cost.

Collecting the source-side reference for the final section (building the source app and capturing reference screens) was report preparation, took about 18 minutes, and is not included above.

### 2. Source application and code size

Feeder 2.24.0 is a single-module Android/Kotlin + Jetpack Compose RSS/Atom reader; core features need no account. Main features:
- Feeds and tags, with scheduled background sync.
- Article list: several card styles, filtering and sorting, swipe-to-mark-read.
- Reader: full-text extraction (Readability) and HTML rendering.
- OPML import/export.
- Read-aloud (TTS) and podcast playback.
- Translation and summaries: offline translation (Bergamot WASM), plus OpenAI/DeepL translation and summaries.
- End-to-end-encrypted cross-device sync (Feeder Sync).
- New-article notifications and a home-screen widget.

FeederHM is the HarmonyOS/ArkTS target (V2 state management, API 24).

| Counted material | Files | Physical lines |
|---|---:|---:|
| Source production Kotlin (`app/src/main`) | 249 | 50,526 |
| Source layout XML | 0 (all Compose) | 0 |
| Source unit/instrumented test Kotlin | — | 16,801 |
| Target production ETS (end of Phase B) | 222 | 65,596 |
| Target host-side test ETS (incl. generated fixture module) | 16 | 4,017 |

Physical lines include blanks and comments. The source's third-party libraries (the Go gofeed parser, Jsoup, Readability4J) were re-implemented in ArkTS and count toward the target, so line differences don't measure efficiency or coverage.

### 3. Main actions and decision points

| Stage | Main action and branch |
|---|---|
| Environment (before timing) | No devecocli on the host, so a pure ArkTS Stage scaffold was built manually; the user enabled automatic signing. The session's Workflow engine lacks the template's `check()`/`readSection()`/`argsFile`; per the user's decision an adapter was used (template bodies unchanged). |
| A · Feasibility and front-end | Yellow, no red items. All 19 open dependencies were resolved (gofeed → ArkTS parser; Jsoup/Readability → in-house DOM and extraction). Resource, route and launch smoke were green. The Compose track missed 8 navigation destinations defined as sealed classes; they were added through the page ledger. |
| A · Specification baseline | 22 parallel exploration areas; froze 16 pages, 1,014 assertions (ui 393 / backend 566 / on_device 55) and 31 units. 24 source FeedParserTest fixtures were generated into vector data. |
| A · Development and deterministic gates | Foundation: 6 waves, 17 units, with one TLS interruption resumed from a checkpoint. Host Local Test stubs its codec and XML APIs (proven by probe); after switching to pure-ArkTS implementations, vectors reached 241/241. Slices: two runs (the first interrupted by the usage limit, then resumed); 8 overreaching requests cleared and 59 degradations adjudicated. |
| A · End-stage acceptance | Three judgment rounds converged to 31/31 (21 → 30 → 31). The adversarial check refuted NW-A12/A13 (notification actions did nothing when the app process was dead); after moving to a UI-less ability, the degradation was re-registered. |
| A · Runtime validation | 11/11 per-page plans ran without crashes; 5 of 11 core flows passed. **`bindMenu` menus never opened anywhere.** Under the one-fix-one-recheck rule, a single fix was tried, failed, reverted and recorded as failed. |
| A · Release feedback | Final closure reached zero hard violations (11 waivers); ledger verification retained 1 suite-tool defect; REPORT.md and feedback.md produced. **This is the workflow's normal final state.** |
| B · Continuation fixes | Ignoring the repair limit, each defect was reproduced on device, attributed and fixed within a single main session: 11 kinds of app defects (Section 5). Each platform fact is recorded in `spec/conventions.md` §J. |
| B · Expanded device verification | The walkthrough tool gained `longpress`, `tapAt` and `swipeRaw` steps, covering long-press menus, the notification shade, home-screen widgets and the system share sheet. 22 new device flows covered 38 more device assertions, each with walkthrough-report step evidence. |
| B · Full regression and gates | All 41 walkthrough plans pass on the final build (with ordering constraints for the seed and data-wiping plans). Vectors 242/242, final closure passed, ledger verification clean, runtime gate recorded as passed. |

### 4. Outcome

| Gate | Phase A final state | End of Phase B |
|---|---|---|
| Signed build and install | Passed | Passed |
| Host vectors | 241/241 | 242/242 |
| End-stage acceptance (31 units, static) | 31/31 | 31/31 |
| Final code closure | Passed | Passed (11 waivers unchanged) |
| Ledger integrity | 1 residual | Clean (misdirected UC-A10 evidence corrected) |
| **Runtime validation** | **Failed** (6 core flows) | **Passed** (41/41 plans) |
| **1,014 assertions** | **961 passed / 4 failed / 49 unverified** | **999 passed / 0 failed / 15 unverified** |
| Passes with device evidence | 2 | 40 |

**Verdict.** At the end of Phase A, the app could be signed, built, installed and run, and the main browsing path worked, but menus were broken everywhere, which blocked many entry points; full acceptance did not pass. At the end of Phase B, no frozen assertion fails. The 15 unverified ones need user consent, an external account or special hardware (Section 6); none is a known defect. By the ledger, the migration passes acceptance except for those 15 device assertions that are waiting on user-side conditions.

Note: 959 of the 999 passes are still static code-reading judgments. All 11 kinds of defects found in Phase B were within assertions that static review had already marked as passing, so static judgment doesn't replace device verification.

### 5. Phase A's blocking defect and app defects fixed in Phase B

1. **Menus never opened**, including all overflow, dropdown and item menus. This was Phase A's blocking defect; FP-A52/A62/A67 and UC-A22 failed because of it. `bindMenu` content was wrapped in an arrow function. Fixed at 8 sites by passing the @Builder reference directly.
2. **Long-pressing a card thumbnail didn't open the item menu.** `Image` is draggable by default, so the drag pre-empted the long press. Fixed with `draggable(false)`.
3. **http feeds redirecting to https failed or returned truncated bodies.** NetworkKit's native redirect following kept only the last chunk of an ARRAY_BUFFER result (24,214 → 8,172 bytes) and merged both hops' headers, and HttpCache then cached that result. Redirects are now followed manually after a REDIRECTION interceptor stops native following. As a side effect, search went from about 20s to about 1s.
4. **No podcast could play.** `audioRendererInfo` was set while the AVPlayer was idle, which raised 5400102. It's now set in the `initialized` state.
5. **Periodic-sync settings never took effect.** `stopWork` rejects a condition-less WorkInfo; the failure was swallowed, so every later `startWork` failed with 9700005. Fixed by stopping with the WorkInfo from `getWorkStatus`, and by adding `isCharging` alongside `chargerType`.
6. **One "Sync feeds" tap synced twice, and half the notifications were rejected.** `Refresh` fires `onRefreshing` when `refreshing` is set programmatically, and notification publishing has a per-second limit (1600009). Fixed by guarding `onRefreshing`, and by serializing publishing with a 150ms interval.
7. **The badge stuck at 99+ while the shade was empty.** HarmonyOS `badgeNumber` adds rather than sets. The badge is now set to an absolute count from active notifications.
8. **Widget sync icon and feed icons were missing.** The SVG was malformed, and SVG bytes sent via `memory://` don't render. Fixed the SVG and rasterize feed icons to PNG.
9. **The widget stayed on "Refreshing" after a sync tap.** The form-extension process is killed about 10s after the callback. Fixed with a 7-second budget that pushes the final state, clearing the sync marker in `onStop`, and checking that the marker's process is still alive.
10. **Settings showed defaults or an empty list when opened via a direct entry.** The entry arrived before bootstrap finished. The Settings ViewModel now refreshes and subscribes after `ready()`.
11. **The AI settings dialog kept saying "Enter an API key".** A @Builder value parameter doesn't refresh. The card now reads the model state directly.

Phase A's four "leftover issues" turned out not to be defects:
- Enter does trigger search, as it does in the source app.
- EditFeed can be scrolled to OK with the keyboard open.
- The drawer is a scrim-less push drawer of width min(360vp, screen), matching the source as checked against the Android source (final section); Phase A's "side sheet with a scrim" was a misdescription.
- The "Android 12" text is the source string, which ST-A07 requires.

The first three were walkthrough-tool artifacts, such as a swipe landing on the keyboard or not waiting for search results.

### 6. 15 device assertions still unverified

| Assertions | Why they remain unverified |
|---|---|
| TR-A21/A46/A47 (offline translation) | Needs a 4.9 MB executable Bergamot WASM runtime download, which requires the user's explicit consent; cancelled at the confirmation dialog. TR-A21 also needs the network off. |
| SY-A21/A50/A51 (device sync) | Needs creating a sync chain on a third-party server, which amounts to registering an account. |
| EF-A33, FI-A42, ST-A10 (permission denial and rationale branches) | Needs revoking the notification permission in system settings; only the granted branch was verified. |
| APP-A31 (open OPML from the file manager) | The system Files app requires accepting its user agreement on first launch. |
| FS-A47, FS-A55 (actual background execution of periodic sync and orphan cleanup) | Scheduling parameters were verified on device; actual execution time is up to the system and wasn't observable within the walkthrough. |
| UT-A26 (no app can handle a link) | Would require removing every link handler, including the browser. |
| UT-A27 (adjacent window on large screens) | Needs a device of at least 600dp. |
| UT-A41 ("process text" with third-party apps) | HarmonyOS has no PROCESS_TEXT ecosystem; registered as a degradation. |

56 adjudicated degradations remain (no_equiv 8, approx 40, policy 8), for example: no text-language detection, fixed notification slots, static-slot shortcuts, M3 visual approximations. They don't automatically waive functional assertions.

### 7. Main problems encountered

- **Phase A:**
  - **Environment and engine:** no devecocli on the host, and an engine/template interface mismatch required an adapter. The adapter's chunked temp-file writes were blocked by the host safety classifier and changed to plain writes.
  - **Interruptions:** a TLS error and a usage limit each interrupted a workflow; both were resumed from checkpoints.
  - **Tool defects:**
    - Host Local Test stubs produced false vector failures.
    - Static gates have blind spots: dead-files misses form_config, safearea misses custom inset providers, render shows registration text instead of adjudicated status, and wire-routes misses sealed-class navigation.
    - Ledger posting failed on verdict evidence containing quotes.
  - **Acceptance limits:** static acceptance can't detect runtime-wide interaction defects (the menu problem surfaced only in 4b), and the repair limit left Phase A partially complete.
- **Phase B:**
  - **Plan state dependencies:** 3 plans wipe app data, which removed feeds that later plans needed. An OPML seeding plan and a fixed execution order resolve this.
  - **Test environment limits:** background commands have restricted networking, so the local mock OpenAI endpoint had to run in a thread inside the same foreground process and be mapped to the device with `hdc rport`.
  - **One test-key leak:** before the Base URL was changed, the form once auto-requested the model list from the default endpoint with the test key.
  - **Log evidence:** the hilog buffer is small, so long flows need live filtering within the same command.
  - **Gate typo:** the first runtime-gate record read "0/41" because of a path bug in the counting script; a correcting entry was appended (the ledger is append-only).

---

## 附录：产物与截图位置 / Appendix: artefacts and screenshots

| 内容 / Content | 位置 / Location |
|---|---|
| 阶段 A 终态产物（工程、spec、签名 HAP）/ Phase A final-state outputs | `outcomes/FeederHM-Claude/` |
| 阶段 B 最终产物（工程、spec、走查报告与证据、签名 HAP）/ Phase B final outputs | `outcomes/FeederHM-Claude-continued/` |
| 阶段 A 终态画面（中文界面）/ Phase A final-state screens (Chinese UI) | `screenshots/FeederHM-Claude/` |
| 阶段 B 走查关键画面 / Phase B walkthrough key screens | `screenshots/FeederHM-Claude-continued/` |
| 源侧 Android 参照 / Android source reference | `screenshots/Feeder-Android-source/` |
| 对比用目标侧画面 / Target screens used in the comparison | `screenshots/FeederHM-Claude-compare/` |

---

## 双端对照与实测 / Side-by-side comparison and hands-on

### 对照条件 / Capture conditions

**采集条件：** 源侧为 `input/Feeder` 构建的 debug 版（2.24.0，应用名显示为 FeederD），全新安装；目标侧为阶段 B 最终构建。两侧界面语言均为英文。两侧数据不同步（订阅源、已读状态、时间不同），只比较界面结构与行为，不比较具体条目。

**Capture conditions:** the source is a debug build of `input/Feeder` (2.24.0, shown as FeederD), freshly installed; the target is the final Phase B build. Both UIs are in English. Data differs between the two (feeds, read state, times), so only UI structure and behaviour are compared, not specific items.

### 逐屏对照 / Screen-by-screen comparison

| 画面 / Screen | 源 / Source (Android Feeder) | 目标 / Target (HarmonyOS FeederHM) |
|---|---|---|
| 订阅源文章列表 / Feed article list | <img src="screenshots/Feeder-Android-source/src-feed-home.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-feed-home.png" width="240"> |
| 侧边抽屉（推挤式、无遮罩） / Drawer (push style, no scrim) | <img src="screenshots/Feeder-Android-source/src-drawer.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-drawer.png" width="240"> |
| 文章阅读 / Article | <img src="screenshots/Feeder-Android-source/src-article.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-article.png" width="240"> |
| 列表溢出菜单 / List overflow menu | <img src="screenshots/Feeder-Android-source/src-overflow-menu.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-overflow-menu.png" width="240"> |
| 文章菜单 / Article menu | <img src="screenshots/Feeder-Android-source/src-article-menu.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-article-menu.png" width="240"> |
| 条目长按菜单 / Item long-press menu | <img src="screenshots/Feeder-Android-source/src-item-menu.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-item-menu.png" width="240"> |
| 设置 / Settings | <img src="screenshots/Feeder-Android-source/src-settings.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-settings.png" width="240"> |
| 添加订阅源（搜索） / Add feed (search) | <img src="screenshots/Feeder-Android-source/src-search-feed.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-search-feed.png" width="240"> |
| 编辑订阅源 / Edit feed | <img src="screenshots/Feeder-Android-source/src-edit-feed.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/tgt-edit-feed.png" width="240"> |
| 系统分享面板 / System share sheet | <img src="screenshots/Feeder-Android-source/src-share-sheet.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-share-item-sheet.png" width="240"> |
| 新文章通知（展开） / New-article notifications (expanded) | <img src="screenshots/Feeder-Android-source/src-notifications-expanded.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-notify-expanded.png" width="240"> |
| 通知动作按钮 / Notification actions | <img src="screenshots/Feeder-Android-source/src-notification-actions.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-notify-item-actions.png" width="240"> |
| 朗读播放条 / Read-aloud bar | <img src="screenshots/Feeder-Android-source/src-readaloud.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-readaloud-playing.png" width="240"> |
| 播客播放条 / Podcast bar | <img src="screenshots/Feeder-Android-source/src-podcast-playing.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-podcast-c1-playing.png" width="240"> |
| OPML 导出（系统保存器） / OPML export (system saver) | <img src="screenshots/Feeder-Android-source/src-opml-export-picker.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/opml-export-picker.png" width="240"> |
| 桌面长按快捷方式 / Launcher shortcuts | <img src="screenshots/Feeder-Android-source/src-shortcuts.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-shortcuts-menu.png" width="240"> |
| 桌面小组件 / Home-screen widget | <img src="screenshots/Feeder-Android-source/src-widget.png" width="240"> | <img src="screenshots/FeederHM-Claude-compare/flow-widget-feedernews-before.png" width="240"> |

### 对照结果 / Comparison results

#### 中文

**一致项（逐屏核对）：**
- 列表溢出菜单 10 项、文章菜单 4 项（目标多出的 "Summarize" 只在配置了摘要 API 时出现，源同样如此）、条目长按菜单 7 项，名称与顺序都相同。
- 抽屉为推挤式、无遮罩，与 UM-A01 一致。
- 文章页字段及顺序相同：标题、源名、作者时间、阅读时长、正文。
- 编辑订阅源的字段顺序相同。
- 回车可以触发搜索。
- 单条通知的动作按钮都是 Open link in web browser 加 Mark as read。
- 朗读条都是"停止 / 暂停 / 下一段 / 语言"四个按钮。
- 播客条都是"停止 / 暂停 / 后退 10 秒 / 前进 10 秒"，并有进度条。
- OPML 导出的默认文件名格式相同（`feeder-export-<日期>-<当日秒数>.opml`）。
- 分享内容都是标题加文章链接。

**差异项：**
- **快捷方式：** 源侧是以订阅源标题命名的动态快捷方式；目标侧是 "Recent feed 1/2/3" 静态槽位（已登记降级，点击同样直达最近使用的源）。
- **动态配色：** 源在 Android 12 以上可开启；目标置灰并显示源文案（平台无壁纸取色）。
- **通知分组：** Android 把汇总通知作为分组头并显示条数；HarmonyOS 把 "Updated feeds" 作为单独一条列在组内。这是系统呈现差异。
- **小组件标题图标：** 源侧白色 F 图标在浅色卡片上几乎看不见；目标侧改为可着色 SVG 后清晰可见，比源略好。
- **图标不一致：** 目标侧使用鸿蒙系统符号（`sys.symbol`），部分图标与源 Material 图标形状或语义不同：
  - 列表顶栏的过滤图标：源为由长到短的三条横线，目标为两条滑杆。
  - 悬浮按钮"全部标为已读"：源为双勾，目标为叠放的勾选方框；按钮底色也不同（源随动态配色为浅紫，目标为浅绿）。
  - 溢出菜单：
    - 全部标为已读：源为双勾，目标为叠放方框。
    - 同步：源为带箭头的刷新，目标为圆环箭头。
    - 编辑：源为实心铅笔，目标为方框加笔。
    - 删除、设置：源为实心垃圾桶、实心齿轮，目标为线框样式。
    - 导入/导出 OPML 与收藏：源为上下双向箭头，目标为向中间汇聚的箭头，语义偏差最明显。
  - 文章顶栏：源为"在浏览器打开"的窗口箭头图标，目标为指南针；阅读模式图标在源为实心、在目标为线框。
  - 文章菜单：分享图标在源为三点连线，目标为环形箭头；朗读图标形状也不同。另外目标菜单的图标贴近左缘，略有裁切。
  - 小组件标题图标见上一条。
- **视觉细节：**
  - 设置页左缩进比源大。
  - 文章菜单和条目长按菜单的弹出位置与源不同：源的文章菜单靠右边缘、条目菜单靠左；目标的文章菜单更宽且偏左、条目菜单靠右。
  - 开关样式为鸿蒙原生样式（approx 降级）。

#### English

**Matches (checked screen by screen):**
- The list overflow menu (10 items), article menu (4 items; the target's extra "Summarize" appears only when a summary API is configured, as in the source) and item long-press menu (7 items) have the same names and order.
- The drawer is a push drawer without a scrim (UM-A01).
- Article page fields and order match: title, feed name, author/time, reading time, body.
- Edit-feed field order matches.
- Enter triggers search.
- Single notifications have the same actions: Open link in web browser and Mark as read.
- The read-aloud bar has the same four buttons: stop, pause, next, language.
- The podcast bar has the same controls (stop, pause, −10s, +10s) and a progress bar.
- The OPML export default filename uses the same format: `feeder-export-<date>-<seconds of day>.opml`.
- Shared content is the title plus the article link.

**Differences:**
- **Shortcuts:** the source uses dynamic shortcuts named after feeds; the target uses static "Recent feed 1/2/3" slots (a registered degradation; tapping still opens the most recent feed).
- **Dynamic colors:** available on the source on Android 12+; disabled on the target with the source string shown (no wallpaper colour API).
- **Notification grouping:** Android uses the summary as the group header with a count; HarmonyOS lists "Updated feeds" as a separate entry in the group. This is a system rendering difference.
- **Widget header icon:** the source's white F icon is nearly invisible on the light card; the target's tintable SVG is clearly visible, slightly better than the source.
- **Icon mismatches:** the target uses HarmonyOS system symbols (`sys.symbol`), and some icons differ in shape or meaning from the source's Material icons:
  - List top-bar filter: three lines of decreasing length on the source; two sliders on the target.
  - "Mark all as read" FAB: a double check on the source; stacked checked squares on the target. The button colour also differs (light purple from dynamic colours on the source, light green on the target).
  - Overflow menu:
    - Mark all as read: a double check on the source; stacked squares on the target.
    - Sync: a refresh arrow on the source; a circular arrow on the target.
    - Edit: a filled pencil on the source; a square with a pen on the target.
    - Delete and Settings: a filled trash can and a filled gear on the source; outlined versions on the target.
    - OPML and saved-article import/export: up/down arrows on the source; arrows converging to the middle on the target. This is the clearest change of meaning.
  - Article top bar: "open in browser" is a window-with-arrow icon on the source and a compass on the target; the reader-mode icon is filled on the source and outlined on the target.
  - Article menu: Share is three connected dots on the source and a circular arrow on the target; the read-aloud icon also differs. The target menu's icons sit against the left edge and are slightly clipped.
  - The widget header icon is covered in the previous item.
- **Visual details:**
  - The target's Settings page has a wider left indent.
  - The article and item menus pop up in different places: on the source the article menu is anchored at the right edge and the item menu sits on the left; on the target the article menu is wider and further left, and the item menu sits on the right.
  - Toggles use the HarmonyOS native style (an approx degradation).

### 实测体验 / Hands-on experience

#### 中文

**阶段 A 终态**（中文界面，截图见本节末）：浏览主链路可用，但溢出菜单、过滤菜单、设置下拉点了都没有反应，很多功能失去入口。

**阶段 B 结束**：
- **能完成的操作：**
  - 菜单、长按菜单、分享。
  - 编辑和删除订阅源，OPML 与收藏的导入导出。
  - 朗读与播客，音量键翻页。
  - 通知与通知动作、桌面小组件、快捷方式。
  - AI 设置，明文 http 订阅源。
- **与源相比：** 主要差别都是平台限制带来的降级（快捷方式命名、动态配色、通知分组呈现），以及部分图标与源不一致（尤其导入/导出、过滤、在浏览器打开等图标）和少量弹出位置、间距这类视觉细节。

截图不构成新增的功能验收；功能结论以台账为准。

---

#### English

**Phase A final state** (Chinese UI; screenshots at the end of this section): the main browsing path worked, but the overflow menu, filter menu and settings dropdowns did nothing when tapped, leaving many features without an entry point.

**End of Phase B**:
- **Everything below works:**
  - Menus, long-press menus and sharing.
  - Editing and deleting feeds; OPML and saved-article import/export.
  - Read-aloud and podcasts; volume-key paging.
  - Notifications and their actions, the home-screen widget and shortcuts.
  - AI settings; cleartext http feeds.
- **Compared with the source:** the main differences are platform-driven degradations (shortcut naming, dynamic colors, notification grouping) plus some icons that don't match the source (notably import/export, filter and open-in-browser) and small visual details such as popup positions and spacing.

Screenshots don't add functional acceptance; the ledger is the basis for functional conclusions.

---

### 阶段 A 终态画面 / Phase A final-state screens

| 订阅列表首页 / Feed home | 侧边抽屉 / Drawer | 文章阅读 / Article | 设置 / Settings | 添加订阅源 / Add feed |
|---|---|---|---|---|
| <img src="screenshots/FeederHM-Claude/FeederHM-Feed-Home.png" width="180"> | <img src="screenshots/FeederHM-Claude/FeederHM-Drawer.png" width="180"> | <img src="screenshots/FeederHM-Claude/FeederHM-Article.png" width="180"> | <img src="screenshots/FeederHM-Claude/FeederHM-Settings.png" width="180"> | <img src="screenshots/FeederHM-Claude/FeederHM-SearchFeed.png" width="180"> |
