# HMigBot 迁移工作流评估总报告 / HMigBot Migration Workflow Evaluation

报告日期 / Report date: 2026-10-14

本报告汇总两次 Android → HarmonyOS 迁移测试，重点评价 `migrate-core` 工作流本身的效果，而非单个应用的迁移细节。两次测试的完整记录见：
- `WeatherApp-Codex-Report.md`、`WeatherApp-Codex-Operation-Log.md`
- `FeederHM-Claude-Report.md`、`FeederHM-Claude-Operation-Log.md`

工作流机制说明见 `HMigBot-Migration-Workflow-Mechanism.md`。

This report summarizes two Android → HarmonyOS migration runs and evaluates the `migrate-core` workflow itself rather than the details of either app. Full records are in the two project reports and operation logs; the mechanism is described in `HMigBot-Migration-Workflow-Mechanism.md`.

---

## 中文版

### 1. 两次测试概览

两次测试不是受控对照：源应用的规模和技术栈不同，执行代理、模型和 workflow 引擎也都不同。下表只用于并列呈现，不宜直接换算成"谁更好"。

| 项目 | 测试一：WeatherApp | 测试二：Feeder |
|---|---|---|
| 源应用 | 天气预报（Java + XML 布局 + Protobuf 存储） | RSS/Atom 阅读器（Kotlin + Jetpack Compose） |
| 源生产代码 | 30 文件 / 3,237 行（另有 9 个布局、14 个 proto） | 249 文件 / 50,526 行 |
| 体检结论 | standard 档 | standard 档，黄灯；81 个依赖，19 个待裁决 |
| 执行代理与模型 | Codex，openai/gpt-6.1-sol | Claude Code，claude-opus-5-5（另有 claude-haiku-5-5 执行器） |
| workflow 引擎 | DevEco 原生引擎 | Claude Code Workflow 工具加适配层（原引擎内置能力缺失） |
| 冻结规模 | 2 个页面、6 个切片、113 条断言 | 16 个页面、31 个单元、1014 条断言 |
| 目标生产代码 | 18 文件 / 3,338 行（另有生成的 Protobuf 代码 3,390 行） | 222 文件 / 65,596 行（含自研的解析与 HTML 库） |

### 2. 时间与 token 消耗

时长口径：墙钟时长减去外部等待（等待用户、用量上限、网络错误）。设备运行和后台任务的时间计入。

| 指标 | WeatherApp（工作流完整运行，含签名后续跑） | Feeder 阶段 A（工作流正常终态） | Feeder 阶段 B（突破返修上限的接续） | Feeder 合计 |
|---|---:|---:|---:|---:|
| 实际工作时长 | 6 时 28 分 | 6 时 16 分 | 3 时 51 分 | 10 时 08 分 |
| 墙钟时长 | 6 时 58 分 | 7 时 41 分 | 3 时 51 分 | 11 时 33 分 |
| 会话数（主会话 + 子会话） | 62 | 1 + 418 | 1 + 0 | 1 + 418 |
| 非缓存输入 token | 4,567,115 | 10,568 | 1,000 | 11,568 |
| 缓存写入 token | 0（接口不单独报告） | 23,457,755 | 568,193 | 24,025,948 |
| 缓存读取 token | 115,730,944 | 735,099,469 | 170,552,120 | 905,651,589 |
| 输出 token | 438,502 | 453,530 | 275,269 | 728,799 |
| **累计 token** | **120,736,561** | **759,021,322** | **171,396,582** | **930,417,904** |
| 新输入量（非缓存输入 + 缓存写入，可横向比较） | 约 457 万 | 约 2,347 万 | 约 57 万 | 约 2,404 万 |

**口径说明：**
- **为什么缓存读取占大头：** 每次模型调用都会重发整段上下文，所以两次测试的缓存读取都占 9 成以上。两家接口记录"新内容"的栏目不同：Anthropic 记在"缓存写入"，OpenAI 记在"非缓存输入"。横向比较时应看"新输入量"。
- **token 不等于费用：** 四类 token 单价差别很大，累计数不代表费用。
- **规模与耗时：** Feeder 的源码规模约为 WeatherApp 的 15 倍，阶段 A 的工作时长却与 WeatherApp 相当。主要原因是探索和切片实现可以并行，代价是会话数与上下文读取量大幅上升。

### 3. 转换结果摘要

| 项目 | WeatherApp 终态 | Feeder 阶段 A 终态 | Feeder 阶段 B 结束 |
|---|---|---|---|
| 签名构建与安装 | 通过 | 通过 | 通过 |
| 最终代码闭合 | 通过（硬违规 0） | 通过（硬违规 0） | 通过 |
| 台账完整性 | 通过 | 残留 1 条工具缺陷 | 通过 |
| 单元验收 | 5/6，首页切片未通过 | 31/31（全部为静态判定） | 31/31 |
| 运行时验证门 | 未通过 | 未通过 | 通过 |
| 断言：通过 / 失败 / 未验 | 105 / 4 / 4 | 961 / 4 / 49 | 999 / 0 / 15 |
| 有真机证据的通过 | 5 | 2 | 40 |
| 工作流判定 | 部分完成 | 部分完成 | 除待用户条件的 15 条外通过 |

**WeatherApp：** 产物能在实体设备运行，主要信息展示完整。未通过的集中在四类：
- **源行为与正确语义冲突：** 气压单位。
- **平台调用结果存疑：** 大致定位返回 201。
- **复杂手势与复合界面：** 首页头部恢复。
- **时间性动画与边界交接：** 未能观察到。

**Feeder：** 阶段 A 的产物在静态层面全部收敛，但上机后菜单全局失效，阻断了大量入口，按返修上限停止。阶段 B 在单一主会话中逐项真机归因，修复了 11 类运行时缺陷（菜单、网络重定向、播放、后台调度、通知频控、小组件生命周期等），冻结断言不再有失败项。剩余 15 条未验证都需要用户授权、外部账号或特殊硬件。

**需要说明的一点：** 阶段 B 的新增真机证据大多在模拟器上取得。按工作流对 B 级断言（通知、媒体、振动等）的要求，这部分仍需实体设备复核。

### 4. 两次测试共同显现的工作流特征

1. **台账纪律可靠，结果不虚报。** 两次测试都没有缩减冻结分母，也没有把失败改写为通过。门的历史保留了更正记录，最终判定都如实给出"部分完成"。这是工作流最可信的部分：结论可以从断言一路追溯到源码锚点、目标代码、走查报告步号和台账状态。
2. **前场与骨架效率高，规模扩展性好。** 资源、路由、骨架、台账、构建与闭合都由脚本完成，可编译、可冷启的工程很早就出现。依赖分波、分层并行，让 15 倍规模的工程在相近时间内完成首轮迁移。
3. **静态验收与运行时行为之间有明显断层。** 两次测试的失败都集中在运行时：
   - WeatherApp 是手势、定位、动画；
   - Feeder 是菜单全局失效，以及阶段 B 发现的 11 类问题，全部出自已经静态判定通过的断言。

   判断性读码验收能核对"代码写了什么"，但发现不了平台运行时语义差异，例如组件参数写法、系统 API 的状态机、进程生命周期、系统频控。这些问题只能上机才暴露。
4. **有界返修让工作流停在"部分完成"，且停止点是流程上限，而非能力上限。** 4b 的硬时间盒、"一次修复 + 一次复验"、30 分钟归因上限，使两次测试都在发现关键缺陷后收口。Feeder 阶段 B 表明：同一批问题在不设轮次上限、按"复现 → 反转条件 → 修复"逐项处理时，约 4 小时即可全部解决，额外 token 约为阶段 A 的 23%。这些上限控制了成本和失控风险，但也让首轮产物的可用度明显低于其潜力。
5. **真机验证的覆盖受执行器能力限制。**
   - 系统界面（通知栏、小组件、分享面板、系统文件选择器）不在应用控件树里，而规则又禁止自算坐标，相关契约在规则内常只能记为未验证。
   - 播放、语音、振动、后台调度等结果只能靠系统日志留证。
   - 是否有实体设备、是否签名，也直接决定能拿到哪一级证据。
6. **断言分层由 agent 决定，影响验证深度。** 无 PRD 时，真机清单就是 `on_device` 断言全集。Feeder 1014 条中只有 55 条被标为 `on_device`，许多依赖运行时的行为因此只得到读码结论。分层错位是"静态通过、上机失败"的主要来源。
7. **对环境与工具链的依赖较重。**
   - 模板依赖特定引擎的内置能力，换环境需要适配层。
   - 主机侧单元测试运行时存在空桩，会造成假失败；二进制原生库无法在桌面加载。
   - 签名、网络（TLS、限流、地区性连接重置）、会话用量上限都中断过流程。
   - 断点续跑（`resumeFromRunId`、`only/resumeFrom`）能有效恢复，但这些因素明显拉长了墙钟时间。

### 5. 整体评判

**定位：** `migrate-core` 是一套"可审计的迁移流水线"，而不是"自动转换器"。它最强的地方在于：
- 把迁移拆成可并行、可续跑的单元；
- 用确定性脚本承担骨架与检查；
- 用台账把每条结论绑定到证据。

在两次测试中，它都按设计如实给出了"部分完成"，没有虚报。

**效果：**
- **转译与开发块：** 表现良好。中小型工程与 5 万行级工程都能在约 6 小时内得到可编译、可运行、静态层面基本收敛的目标工程，规模扩展性好。
- **验证与返修块：** 是当前短板。静态验收对运行时问题基本无感；设备阶段被时间盒、单次返修和执行器能力共同限制。因此首轮产物"能跑但关键交互可能失效"的风险较高，必须依赖后续人工或接续修复才能达到可用。

**成本：** token 主要消耗在大量子会话对上下文的反复读取上，与并行度和会话数正相关；新输入量相对很小。规模越大，越需要关注子会话数量与上下文复用效率。

**结论：** 如果目标是"快速得到结构完整、可审计、缺陷位置清楚的迁移底稿"，这套工作流已经可用，价值明确。如果目标是"一次跑完即交付可用应用"，它目前还不够，主要差距在运行时验证与返修环节。

### 6. 改进建议

1. **前移运行时检查。** 在页面波冒烟中加入通用交互原语的上机自检，例如菜单弹出、长按、对话框、列表滑动、设置写入后重启。全局性写法错误（如菜单参数写法）可以在开发期就暴露，而不是到 4b 才发现。
2. **复核断言分层。** 冻结前单独审一遍"依赖运行时才成立"的断言，把它们归入 `on_device` 或配套运行时探针，减少分层错位。
3. **按问题类型放宽返修预算。** 保留归因三步和单次时间盒，但对"阻断大量入口的全局缺陷"允许额外的定向修复轮。或者把第一轮 4b 设计为"发现问题 → 归因修复 → 第二轮 4b"的固定两段。
4. **扩展走查执行器。**
   - 支持长按、系统界面的坐标操作（配截图留证）、输入前清空、日志断言。
   - 为相互影响数据的计划提供播种与顺序管理。
   - 明确直达启动对后续步骤的影响。
5. **降低环境耦合。**
   - 给模板所需的引擎能力定义标准接口，减少对特定引擎的依赖。
   - 把主机侧测试运行时的空桩、原生库加载限制写进体检，提前切换到真机测试路径。
6. **把运行时规律沉淀回规范。** 两次测试坐实的平台规律（如组件参数写法、播放器状态、后台任务取消、通知频控与角标语义、卡片进程寿命）应回流到 `references/` 与 `conventions.md` 模板，让后续迁移在实现期就避开。

---

## English version

### 1. Overview of the two runs

The two runs are not a controlled comparison: the source apps differ in size and stack, and so do the agents, models, and workflow engines. The table places them side by side; it should not be read as a direct ranking.

| Item | Run 1: WeatherApp | Run 2: Feeder |
|---|---|---|
| Source app | Weather forecast (Java + XML layouts + Protobuf storage) | RSS/Atom reader (Kotlin + Jetpack Compose) |
| Source production code | 30 files / 3,237 lines (plus 9 layouts, 14 protos) | 249 files / 50,526 lines |
| Feasibility | standard tier | standard tier, yellow; 81 dependencies, 19 to adjudicate |
| Agent and model | Codex, openai/gpt-6.1-sol | Claude Code, claude-opus-5-5 (plus claude-haiku-5-5 executors) |
| Workflow engine | Native DevEco engine | Claude Code Workflow tool with an adapter (built-ins of the original engine missing) |
| Frozen scope | 2 pages, 6 slices, 113 assertions | 16 pages, 31 units, 1,014 assertions |
| Target production code | 18 files / 3,338 lines (plus 3,390 lines of generated Protobuf code) | 222 files / 65,596 lines (incl. in-house parser and HTML libraries) |

### 2. Time and token consumption

Time = wall-clock minus external waits (waiting for the user, usage limits, network errors); device runs and background tasks are counted.

| Metric | WeatherApp (full workflow run, incl. post-signing resume) | Feeder Phase A (workflow's normal end state) | Feeder Phase B (continuation beyond the repair limit) | Feeder total |
|---|---:|---:|---:|---:|
| Work time | 6h 28m | 6h 16m | 3h 51m | 10h 08m |
| Wall-clock | 6h 58m | 7h 41m | 3h 51m | 11h 33m |
| Sessions (main + child) | 62 | 1 + 418 | 1 + 0 | 1 + 418 |
| Uncached input tokens | 4,567,115 | 10,568 | 1,000 | 11,568 |
| Cache-write tokens | 0 (not reported by the API) | 23,457,755 | 568,193 | 24,025,948 |
| Cache-read tokens | 115,730,944 | 735,099,469 | 170,552,120 | 905,651,589 |
| Output tokens | 438,502 | 453,530 | 275,269 | 728,799 |
| **Total tokens** | **120,736,561** | **759,021,322** | **171,396,582** | **930,417,904** |
| New input (uncached + cache write; comparable across APIs) | ~4.57M | ~23.47M | ~0.57M | ~24.04M |

**Accounting notes:**
- **Why cache reads dominate:** every model call resends the whole context, so cache reads exceed 90% in both runs. The two APIs record new content in different columns: Anthropic under cache writes, OpenAI under uncached input. Compare "new input" across them.
- **Tokens are not cost:** the four categories are priced very differently, so the total is not a cost.
- **Scale and time:** Feeder's source is about 15× larger than WeatherApp's, yet Phase A took about the same work time. The main reason is parallel exploration and slice implementation, which in turn drives up session count and context reads.

### 3. Conversion results

| Item | WeatherApp end state | Feeder Phase A end state | End of Feeder Phase B |
|---|---|---|---|
| Signed build and install | Passed | Passed | Passed |
| Final code closure | Passed (0 hard violations) | Passed (0 hard violations) | Passed |
| Ledger integrity | Passed | 1 residual tool defect | Passed |
| Unit acceptance | 5/6, home slice failed | 31/31 (all static) | 31/31 |
| Runtime validation gate | Failed | Failed | Passed |
| Assertions passed / failed / unverified | 105 / 4 / 4 | 961 / 4 / 49 | 999 / 0 / 15 |
| Passes with device evidence | 5 | 2 | 40 |
| Workflow verdict | Partially complete | Partially complete | Passed except 15 items awaiting user-side conditions |

**WeatherApp:** the app runs on a physical device and its main information is complete. The failures fall into four groups:
- **Source behavior vs correct semantics:** pressure units.
- **A questionable platform result:** coarse location returning 201.
- **Complex gestures and compound UI:** header restoration on the home screen.
- **Timing animations and boundary handoffs:** could not be observed.

**Feeder:** Phase A converged statically, but on device the menus were broken everywhere and blocked many entry points; the run stopped at the repair limit. Phase B attributed each problem on device within one main session and fixed 11 kinds of runtime defects (menus, network redirects, playback, background scheduling, notification rate limits, widget lifecycle, and others), leaving no frozen assertion failing. The remaining 15 unverified items need user consent, an external account, or special hardware.

**One caveat:** most of Phase B's new device evidence was collected on an emulator. Under the workflow's B-level rule (notifications, media, vibration, and similar), those items still need physical-device confirmation.

### 4. Workflow characteristics seen in both runs

1. **Reliable ledger discipline; no inflated results.** Neither run shrank the frozen denominator or rewrote a failure as a pass. Gate history keeps corrections, and both verdicts honestly reported "partially complete." This is the most trustworthy part of the workflow: every conclusion traces back through source anchors, target code, walkthrough steps, and ledger state.
2. **Efficient front-end and scaffolding, good scaling.** Scripts handle resources, routes, scaffolding, the ledger, builds, and closure, so a buildable, cold-startable project appears early. Wave- and layer-based parallelism let a project 15× larger finish its first pass in similar time.
3. **A clear gap between static acceptance and runtime behavior.** Both runs failed mainly at runtime:
   - WeatherApp: gestures, location, animation.
   - Feeder: menus broken everywhere, plus the 11 kinds of defects found in Phase B, all inside assertions that had already passed statically.

   Code-reading acceptance checks what the code says, but it cannot see platform runtime semantics: component-argument idioms, system API state machines, process lifecycles, system rate limits. These only surface on device.
4. **Bounded repair stops runs at "partially complete"; the stop reflects a process limit, not a capability limit.** The 4b hard time box, "one fix plus one recheck," and the 30-minute attribution cap made both runs stop soon after finding key defects. Feeder Phase B showed that the same problems, handled one by one with "reproduce → reverse the condition → fix" and no round limit, were all resolved in about 4 hours, adding about 23% to Phase A's tokens. The limits contain cost and runaway risk, but they leave first-pass output noticeably less usable than it could be.
5. **Device-verification coverage is limited by the executor.**
   - System UI (notification shade, widgets, share sheet, system file picker) isn't in the app's control tree, and the rules forbid self-computed coordinates, so these contracts often stay unverified within the rules.
   - Playback, speech, vibration, and background scheduling can only be evidenced through system logs.
   - Whether a physical device and signing are available directly decides which evidence level can be reached.
6. **Assertion layering is an agent decision and limits verification depth.** Without a PRD, the device checklist is exactly the `on_device` set. Only 55 of Feeder's 1,014 assertions were marked `on_device`, so many runtime-dependent behaviors received only code-reading verdicts. Layer misclassification is the main source of "passed statically, failed on device."
7. **Heavy dependence on environment and toolchain.**
   - The templates rely on a specific engine's built-ins; another environment needs an adapter.
   - The host-side unit-test runtime has stubs that cause false failures, and native binary libraries cannot load on the desktop.
   - Signing, the network (TLS, rate limits, regional connection resets), and session usage limits all interrupted runs.
   - Checkpoint resumption (`resumeFromRunId`, `only/resumeFrom`) recovers well, but these factors noticeably stretch wall-clock time.

### 5. Overall assessment

**What it is:** `migrate-core` is an **auditable migration pipeline**, not an automatic converter. Its strengths:
- It splits migration into parallel, resumable units.
- Deterministic scripts handle scaffolding and checks.
- The ledger ties every conclusion to evidence.

In both runs it honestly reported "partially complete," as designed.

**Effectiveness:**
- **Translation and development block:** works well. Both a small project and a 50k-line project produced buildable, runnable, statically converged targets in about six hours, and it scales well.
- **Verification and repair block:** the current weak point. Static acceptance is largely blind to runtime problems, and the device stage is limited at once by time boxes, single-attempt repair, and executor reach. First-pass output therefore carries a real risk of "runs, but key interactions may be broken," and reaching a usable app requires follow-up manual or continued repair.

**Cost:** tokens go mostly into many child sessions re-reading context; this grows with parallelism and session count, while new input stays relatively small. At larger scale, the number of child sessions and context reuse matter most.

**Conclusion:** if the goal is a structurally complete, auditable migration draft with clearly located defects, the workflow is already useful and its value is clear. If the goal is a usable app delivered in a single run, it is not there yet; the main gap is runtime verification and repair.

### 6. Recommendations

1. **Move runtime checks earlier.** Add on-device self-checks of common interaction primitives to page-wave smoke, such as opening menus, long-press, dialogs, list scrolling, and writing a setting then restarting. Global idiom errors (like the menu-argument idiom) would then surface during development rather than in 4b.
2. **Review assertion layering.** Before freezing, review assertions that only hold at runtime and move them to `on_device` or pair them with runtime probes, reducing layer misclassification.
3. **Scale the repair budget by problem type.** Keep three-step attribution and per-attribution time boxes, but allow extra targeted rounds for global defects that block many entry points. Alternatively, make 4b a fixed two-pass sequence: find, attribute and fix, then a second 4b pass.
4. **Extend the walkthrough executor.**
   - Support long-press, screenshot-backed coordinate operations for system UI, clearing a field before typing, and log assertions.
   - Provide seeding and ordering for plans that affect each other's data.
   - Make the effect of direct launches on later steps explicit.
5. **Reduce environment coupling.**
   - Define a standard interface for the engine capabilities the templates need, reducing dependence on a specific engine.
   - Add host test-runtime stubs and native-library loading limits to the feasibility check, so the run switches to on-device testing early.
6. **Feed runtime rules back into the specification.** Platform rules confirmed in both runs (component-argument idioms, player states, background-task cancellation, notification rate limits and badge semantics, widget-process lifetime) should flow back into `references/` and the `conventions.md` template, so later migrations avoid them during implementation.
