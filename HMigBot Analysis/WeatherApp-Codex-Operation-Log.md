# WeatherApp-Codex-Operation-Log — 迁移操作记录与证据时间线

记录日期：2026-10-13。对象：`input/WeatherApp` → `output/WeatherAppHM`。下文时间统一使用 UTC；2026-10-09 的伦敦当地时间为 UTC+1。本文记录迁移过程及其后的报告整理，**不是重新验收**。

## 0. 能读到什么、不能读到什么

我能读取本聊天目前可见的用户请求与历史摘要，也能读取目标工程保存的 `spec/` 台账、脚本 JSON、设备走查报告、9 次 workflow 的 36 份导出，以及合并报告。当前 Codex 线程本身可以检索到逐回合摘要和部分工具记录；但上下文会压缩，workflow 的子会话也不等于完整逐字思考日志。因此，下文能**审计主要动作和决策链**，不能保证还原“每一次点击、每条未落盘命令、每个代理的全部内部推理”。尤其不能把事后总结当作当时的原始日志。

证据标记：**T**＝产物自身含 UTC 时间戳；**O**＝文件、台账或 workflow 导出证明动作及先后，但没有可信的触发时刻；**C**＝仅能从本会话用户请求确定意图与先后，不能核准精确时间。`SKILL.md` 是“应当怎么做”的规范，不是“实际做了”的证据；`spec/*.json`、workflow run/journal、测试报告才用于证明执行。下文的“原因”会标出来源，避免把规范与实绩混淆。

## 先看机制：这套工作流到底如何迁移一个工程

### 不是单一“自动转换器”，而是四层协作

| 层 | 预设内容 | 依赖 agent 的部分 | 在本次运行中的可见例子 |
|---|---|---|---|
| **规范层** | 本目录 `SKILL.md` 定义五阶段、路径/冻结纪律、绿黄红分支、脚本调用顺序、切片边界、验收和停止规则；`references/` 提供平台知识与语义参考。 | 理解源项目语义；决定待裁决依赖、源码冲突和降级是否成立；规划可实施的切片。 | 无 PRD 时以源码定范围；将 113 条源码锚定断言冻结，未因验收失败缩分母。 |
| **确定性脚本层** | `scripts/*.mjs` 负责静态扫描、资源/路由/布局预处理、卡片解析、台账写入、接口抽取、构建/闭合、冒烟与设备走查驱动、报告投影。通过退出码/JSON 报告给出机器可核结果。 | 对脚本提出的 `case`/未映射项回源码裁决；编写非机械行为代码；选择修复还是保留缺口。 | `front.mjs` 生成可启动骨架；`parse-cards.mjs` 装账；`closure-suite.mjs` 报硬违规；`walk.mjs` 记录真实交互。 |
| **workflow 模板层** | `templates/explore.js` 按域并行探索；`implement.js` 按 wave 调度实现和波门；`mig_slices.js` 校验依赖/路由归属、运行检查点、安排页冒烟；`acceptance.js` 做末端 verify→定向修→限幅复验、保存 prior 判词与过账。 | 每个 `agent(...)` 回调内的源码阅读、编程、错误分析和判断。模板是编排器，不是业务代码生成器。 | 3 个探索域并行；地基 4 波按依赖顺序；首页先于设置；验收失败只 `only` 续跑。 |
| **宿主/外部环境层** | `devecocli` 建工程/签名/装机，本机 SDK 与 `hvigorw` 编译，模拟器/实体设备提供运行事实；官方或第三方库承载可复用能力。 | 确认 API 等价和具体适配；处理权限、网络、二进制格式、视觉/手势差异。 | 官方 protobuf 库与 14 个源 schema；签名后手机原生测试；大致定位仍返回 201。 |

因此“预设”不等于“自动完成迁移”。可重复的**骨架、路由、资源、检查与记账**较强；Android 业务状态机到 ArkTS 的映射、接口适配、页面组合和缺陷修复主要依赖 agent。模板使用 `agent` 调用实施者/核验者，用 `check` 执行确定性命令；不能把代理判断称为脚本的机械判定。

### 从输入到产物的实际处理链

```text
Android 源码
  │
  ├─[feasibility.mjs：静态规模/依赖/能力扫描]→ 形态与红黄绿建议
  │
  ├─[front.mjs：资源转换＋路由接线＋布局参考骨架]→ 可编译、可冷启的空业务骨架
  │
  └─[explore 模板：agent 逐域读源码]→ 带源码行号的短卡
                                      │
                          [parse-cards.mjs＋ledger.mjs]
                                      ↓
                         冻结断言、页面、切片、依赖图
                                      │
              [implement 模板：地基波、真实代码、接口 extract]
                                      ↓
           [mig_slices 模板：依赖分层实现＋构建/selfTest/闭合]
                                      ↓
              [acceptance 模板：末端判断、定向返修、过账]
                                      ↓
           [walk.mjs：模拟器/真机动作和证据]→最终 ledger/report
```

图中的两条“转换”要特别区分：`convert-resources.mjs` 能迁移可映射资源，`wire-routes.mjs` 能按 manifest/navigation/Compose 等真源建立统一路由，`transpile-layout.mjs` 只输出结构/尺寸/资源引用的**参考骨架**到 `spec/front/layouts/`，不直接进编译树，也不自动实现事件与数据流。实际页面仍由 agent 将可用布局语义并入注册页，编写 ArkUI 组件、状态和交互。本次首屏前场的 `Main` 只是骨架页，不能视作天气首页已经迁完。证据：`scripts/front.mjs` 顶部流程注释与 `spec/front/front-report.json`。

就“目标代码是谁写出来的”而言，还需区分三种来源：`devecocli create` 给出标准工程配置/目录；本套件的资源、路由和测试脚手架脚本写出可重复的基础文件与参考件；业务 `.ets`（本次的 Models、Units、OpenMeteo/GeoNames 客户端、WeatherService、Main/Settings 页面及组件）由实现 agent 按工单写入，并在构建报错后由修复 agent 或主会话定向修改。本次另有一个**特例**：14 个源 `.proto` 的目标序列化代码依赖官方 protobuf 库/生成流程，这属于专用协议代码生成，并非本套件能把任意 Java 类自动转换为 ETS。具体文件归属见 `spec/fnd-args.json` 与 `spec/slices-args.json`，二进制特例见 `spec/resume/protobuf-repair-evidence.md`。

### 哪些判定可机械裁决，哪些必须靠 agent

| 事项 | 裁决方式 | 评估含义 |
|---|---|---|
| 文件数/LOC/依赖广度、静态能力表命中 | `feasibility.mjs` 按固定规则产生 `green/yellow/red` 和 `sizeClass/shape`；模型可对边界改判，但须记理由。 | 是分流与风险提示，不保证某库的真实可替代性。WeatherApp 26 依赖跨过 small 的 ≤25 阈值，进入 `standard`；这里没有独立的“超大工程”档。 |
| 资源/路由/布局可映射部分 | 转换/接线/转译脚本产物及 warnings。 | 能快速形成工程骨架；未映射控件、行为和语义仍待 agent 补齐。 |
| 断言装账/冻结 | agent 从源码写卡；解析器检查格式、锚点、重复 ID；`ledger.mjs` 管状态和分母。 | 分母是语义抽取与机器纪律的组合，脚本不会凭源码自动理解全部业务契约。 |
| 构建、向量/行为探针、注册/资源/权限/API/安全区闭合 | `hvigorw`、`run-arkts-vectors.mjs`、`closure-suite.mjs` 的退出码和报告。 | 可重复的确定性门；通过说明静态/探针覆盖处无所报问题，不代表每条交互已运行成功。 |
| `case`、软立案、平台等价、源行为冲突、视觉近似 | agent 回源码、SDK 声明和实际运行证据裁决；合法差异按台账规则登记，不能自己把失败直接豁免。 | 结果强依赖分析质量，流程用证据/债务约束它，但不能完全机械化。 |
| 判断性行为验收 | `acceptance.js` 派 verify agent，失败派 fix agent 并限幅复验；`priorFile` 保留失败判词。 | 这是模型判断，不是纯静态规则；失败会明确保留。 |
| 真机交互 | agent 按冻结 on_device 清单规划流；`walk.mjs` 执行/记录动作、控件树、截图和错误分类；再逐断言判结果。 | “步骤 `ok:true`”不自动等于复合契约通过；需要检查操作后的可观察结果。 |

### 大工程怎样拆：自底向上＋有条件并行，而不是最后盲接线

`feasibility.mjs` 当前只有 `small` 与 `standard` 两档。超出 small 复合阈值的项目默认进入 `standard`，形态建议 `explore=workflow`、`foundation=wave`、`adversary=derived`；这不表示有一个会按项目大小自动无限扩展的“全自动大工程规划器”。超过单域约 25K token 的源码区，skill 要求再拆区；每个实施工单控制在约 6K、单片通常 ≤5 文件。分片边界仍由 agent 沿真正的业务内聚和松耦合关系制定，不能按文件数机械平均切。

1. **先找底座和边界。** 源码探索并行可以提高盘点速度，但产卡后必须对照共享状态、数据模型、路由与初始化链。应用级初始化、数据模型、服务/协议、共享组件属于地基或 core/backend 片；页面是消费者，backend 不应反向依赖页面。页面必须拥有它在路由表中的注册页文件。
2. **地基按依赖波推进。** `implement.js` 的不同 `wave` 顺序执行，同波单元才并行；实现者不能随意修改共享文件，跨片共享修改交给集成步骤统一处理，波后可设构建门。地基代码过门后由 `interface.mjs extract` 抽出真实接口清单；下游依接口实现，漂移由检查点拦截。本次 `fnd-app-init→fnd-models→fnd-clients→fnd-service` 是四个先后波，虽然共调用四个代理，并非四个代理从空白状态同时写完再合并。证据：`spec/fnd-args.json`、`templates/implement.js`。
3. **再沿依赖图做纵切片。** `mig_slices.js` 在启动前查依赖闭包、禁止 backend/platform 依赖 page、核每个注册路由的文件归属；按依赖层调度，每层独立片可并行。每片写代码后立刻构建、自测、slice closure，全部通过才记 `checked`。首个 wave 必须先让首页真实数据流和直接依赖跑起来；其他片之后铺开。本次首页 `page-main` 先完成，`page-settings` 在后续 wave 完成；两片都依赖 `fnd-service`。证据：`spec/slices-args.json`、`spec/slices-rest-args.json`、`templates/mig_slices.js`。
4. **最后集中判断并定向返修。** 实现期的 `checked` 不是验收通过。末端 acceptance 只放确定性层无法充分证明的单元，verify 可跨单元并行；失败单元保存判词，用 `only/resumeFrom` 定向返修，不重跑已 accepted 项。真机阶段再验证核心路径与 on_device-only 行为。最终由台账投影报告，不因部分测试通过而将整体标成成功。证据：`templates/acceptance.js`、`SKILL.md` 阶段四/五、本次 `accept-prior.json`。

这套结构解决的是多人/多代理开发最常见的三类碰撞：**谁拥有文件、谁提供接口、谁有权判通过**。它并不消除语义风险：如果探索卡片漏行为、接口设计错误，或者设备行为需要视觉/时间性观察，脚本的绿灯不会自动发现全部问题。WeatherApp 的 protobuf、头部手势和大致定位正是这些边界的实证。因此评估这套工作流时，应分别看“预设自动化的覆盖”“agent 语义/编码质量”和“最终运行时证据”，不能把三者混为一个成功率。

## 1. 总览与终点

| 时间 / 触发 | 决策、动作及依据 | 结果和证据级别 |
|---|---|---|
| 2026-10-09 09:40:35 | 本 Codex 线程创建。用户先后询问环境、要求补齐局部环境、登录，再要求迁移并累计消耗，随后追问验证、完成签名。此处仅说明会话顺序，**不是各条消息的发送时间**。 | 线程元数据 T；消息顺序 C。 |
| 10:44:05 | 迁移计时开始，固定源 `input/WeatherApp`、目标 `output/WeatherAppHM`；无 PRD。 | `spec/MIGRATION-METRICS.md` T，`spec/session-progress.md` O。 |
| 10:45:56–11:11:43 | 建台账、完成前场、从源码装入断言、规划并冻结 2 路由/6 切片/113 条断言。 | 台账逐项时间 T；前场报告 O；冻结文件 O。 |
| 11:11:43–12:11:51 | 地基波、首页优先切片和设置片实现，构建/向量/闭合检查。 | workflow、slice history T/O。 |
| 12:24–13:15:38 | 判断性验收、定向返修、模拟器/设备验证、第一轮报告；签名不足阻止实体装机，验收未全绿。 | 台账、walk 报告 T；第一轮结束时间 T。 |
| 13:44:41–17:41:52 | 用户签名后仅续阶段四、五：真实二进制存储、签名真机、定位/界面补证、闭合返修和最终封账。 | `spec/MIGRATION-METRICS.md`、门历史、真机报告 T。 |
| 2026-10-12，时刻未核实 | 用户要求合并中英报告、对照截图、体验记录、目录整理和去签名源码副本。 | 本聊天 C，成品文件 O。 |

最终是**部分完成，不是全量迁移验收通过**：113 条冻结断言中 105 通过、4 失败、4 未验证、0 豁免；6 片中 5 accepted、`page-main` failed。签名构建、实体安装、最终闭合硬违规 0、台账纪律核验都通过；acceptance 和 runtime-4b 门仍红。`ledger verify` 通过只证明台账与门记录完整，**不改写门的 ok 值**。依据：`spec/REPORT.md`、`spec/ledger/ledger.json`。

## 2. 逐段操作与分支原因

### A. 环境准备与可行性（10:44–10:47 UTC；部分动作时刻不可核）

1. **触发与范围。** 用户要求检查工作流环境、补齐局部配置，确认登录后让 `input` 工程迁至 `output`，并从开始累计 token/用时。工作流 `SKILL.md` 规定五相：可行性→规格基线→开发→测试→发布回流；源只读，目标和 `.deveco` 可写，失败不得重置台账或改冻结分母。实际固定路径见 `spec/session-progress.md`。来源：用户 C、skill 规范、进度记录 O。
2. **源体检。** `front.mjs --feasibility` 扫到 31 个源文件、3,289 行、XML UI、9 个布局、26 个依赖；`feasibility.json` 后续收敛为红/黄/未裁决各 0。复合信号定档 `standard`，形态为 `explore=workflow`、`foundation=wave`、`adversary=derived`。原因不是“想多跑代理”，而是 `SKILL.md` 要先按体检 `shape` 定后续执行形态。依据：`spec/feasibility.json`、`spec/front/front-report.json`。前场记录首个 feasibility exit 0，但其 tail 保留“12 个待裁决依赖”的早期状态；后续 `spec/lib-adjudications.json` 与定向复检清零，不能把两个时点混成一次扫描结果。O。
3. **工程和前场。** 建鸿蒙骨架后，脚本依次安装 ArkTS test 脚手架、转换资源、接线、转译布局、对齐 SDK、尝试签名、构建、切片闭合及首屏冒烟。这是 `SKILL.md` 阶段 1/2a 的规定顺序，执行摘要逐步保存在 `spec/front/front-report.json`：资源为 base 103 条字符串、1 个附加 locale、57 矢量+3 位图；9 个布局转译节点 84/89、属性 358/655；SDK 设备 API 24 与工程兼容版本对齐；build/closure/smoke 均 exit 0。转译骨架只是实现参考件，不等同最终页面。O。
4. **签名分支。** 前场 `ensure-sign` exit 4，原因是自动签名要求登录；工作流明确允许 unsigned＋模拟器/hdc 调试链继续，但必须把真机/发布能力标成未证。随后 unsigned HAP 在模拟器冷启落到 `Main` 骨架页，安装、前台、着陆与页面子树检查全绿；报告中 HAP 时间 10:47:20.736。此时“首屏冒烟通过”只代表骨架可启动，不代表业务迁好。依据：`front-report.json` 的签名与 smoke 两步，`spec/smoke/smoke-2a.json`。T/O。
5. **顺序异常如实记录。** 台账 `createdAt=10:45:56.150`，早于前场冒烟 10:47:20.736；而 skill 文本把 `ledger init` 放在前场之后。现有产物只能说明实际台账创建时间和冒烟时间，**不能断言所有前场步骤都在 init 之后**。这是流程文字顺序与实测锚点不完全一致，本文不替它补造解释。T。

### B. 规格提取、装账与冻结（约 10:47–11:11 UTC）

6. **为何做三域探索。** 体检将形态定为 workflow，因而调用 `explore` 并行读 weather-ui、search-settings、data-platform 三域，再汇总跨域风险。`explore.run.md` 记录 4 个代理、总历时 356.9 秒，三域卡分别写入 `spec/cards/`。天气卡定位 `Main` 应承载天气头、指标、小时/日图、降水和出入口；搜索/设置卡辨明嵌入 Fragment 与模态弹层不是额外独立路由；数据卡识别服务、单位、缓存、真实定位和二进制设置。原因来自 skill 的“源码锚点、按域短卡、不发明源不存在功能”的规则；具体事实来自源锚点卡及 workflow 导出。O。
7. **跨域风险进入设计，而非直接判失败。** 探索指出温度转换遗漏 `dayTemp`、气压数值/标签错配、UV 主读数引用差值、定位失败与刷新竞态、空数组越界、明文 GeoNames 等。它们是源行为/风险，不自动意味着目标修复或断言通过。无 PRD，遇到“忠实复现源”与“安全/正确语义”冲突时不能私自选择。依据：`spec/cards/*.md`、`explore.run.md`。O。
8. **机器解析与分母。** 规则要求用 `parse-cards.mjs` 解析短卡与接线信息，再由 `ledger.mjs` 入账；进度文件记录三条卡片格式告警经定向修正后无告警。初步 110 条（含机械初始化断言），补入 edge-to-edge/窗口等 3 条后为 113 条：backend 64、ui 43、on_device 6。功能条目 `10:55:26.54` 左右入账，补充条目约 `11:04`；这两个时间来自 ledger history。关键理由是为后续验收固定分母，而不是事后按通过情况选测。`spec/features-batch.json`、`spec/window-features-batch.json`、`spec/ledger/ledger.json`。T/O。
9. **路由/切片分配。** 两个注册页为 `Main`、`Settings`；搜索按源底部弹层实现，`TodayWeatherFragment`/内嵌设置不凭 Fragment 数量加独立页。规划六片：`fnd-app-init`、`fnd-models`、`fnd-clients`、`fnd-service`、`page-main`、`page-settings`。地基拥有初始化、模型、网络/存储和服务，页面是消费者；这来自 `SKILL.md` 的依赖方向和注册页归属约束。六片的计划历史均在 11:11:43.679；`spec/freeze.json` 明示 frozen、113 断言、2 页、6 片，并规定失败只 `only` 复跑。T/O。
10. **源库映射和规范。** 对 Java/Android 原语与第三方依赖查用法、SDK 声明，再把判定写 `spec/lib-adjudications.json`；约定、UI 语义与各片工单在 `spec/conventions.md`、`ui-layout-semantics.md`、`instructions.md`。这是 skill 要求“平台有等价先映射、不凭感觉重造”“接口从地基真代码派生”。在现存文件中可证产物和最终依赖清账，不能逐条证明当时所有搜索查询的命令/时刻。O。

### C. 开发、构建与静态门（11:11–12:11 UTC）

11. **地基波。** 因 `shape.foundation=wave`，`fnd_w0` workflow 实施四个地基单元；导出记录 4 代理、1617.9 秒。构建 exit 0、ArkTS LocalTest 26/26 exit 0 后，四片在 11:45:53.532–.533 被记为 accepted（地基波门的阶段性状态），并从实际代码提取 `spec/interface-manifest.json`。这不是后续判断性验收的终局，尤其 `fnd-app-init` 后来被验出缺口。依据：`fnd_w0.run.md`、slice history、`spec/client-fix-evidence.md`。T/O。
12. **首页优先。** skill 要求 wave-0 先实现首页垂直路径和直接依赖，不能先把其余页面铺开。`slices_w0.run.md` 记录 2 代理、1264.6 秒；`page-main` 在 12:04:28.423 以 build+selfTest+slice closure exit 0 进入 `checked`。`checked` 的含义是确定性门通过，未过账行为断言。T/O。
13. **其余页面。** `slices_rest.run.md` 记录 1 代理、220.4 秒；`page-settings` 在 12:11:51.621 进入 `checked`。切片流水的规则是只挂构建、selfTest、代码闭合，判断性 verify/对抗统一移到阶段四。此处分隔验证类型，避免把构建绿误写成用户行为通过。T/O。
14. **实现中的裁决与近似。** 源 MotionLayout/MPAndroidChart/BlurView 等没有 1:1 直接照搬；页面以滚动帧驱动头部、Canvas 日图、平台 Sheet blur 等近似实现，并将四条 `approx` 记录为降级项。它们不豁免冻结功能断言，仍要观察最终行为。GeoNames 明文域的网络配置由主会话处理并留债/关闭记录；跨片接口变化需记债、重派生 manifest、只复验受影响片。依据：`spec/ledger/ledger.json`、`spec/feedback.md`、`spec/interface-manifest.json`。O。

### D. 第一轮末端验收与模拟器验证（12:24–13:15 UTC）

15. **为什么末端才验。** `SKILL.md` 规定确定性层可证的直接通过，行为判断只在阶段四统一做一次，失败以 `priorFile` 和 `only` 定向修/复验。`accept.run.md` 显示首轮未收敛 `fnd-app-init`、`fnd-clients`、`page-main`；`accept_retry.run.md` 仅余前者与首页。`accept-prior.json` 保存判词，不是凭记忆重验全盘。地基模型/服务与设置页的末端过账集中在 12:24 左右，客户端有关结果在 12:45 左右；`page-settings` 12:24:20.628 accepted。依据：workflow 导出和台账 history。T/O。
16. **定向返修未掩盖红灯。** 初验发现仓储接口/缓存恢复/初始化顺序及首页视觉手势证据不闭合；相关共享契约修复、manifest 重提取和消费者复验有 `spec/init-fix-evidence.md`、`client-accept-fix-evidence.md`。但 `fnd-app-init` 与 `page-main` 在 12:46:59 被记 failed，未因先前地基波门绿而保留 accepted。`fnd-clients` 在 12:45:41.943 accepted。T/O。
17. **集成闭合。** `closure-suite.mjs --stage final` 检查注册、资源、死代码、权限/API/字面锚点等，12:47:57.742 首次记 closure-final 绿；后续删未消费 backgroundTick、对间接 store 读写用精确豁免票裁决，13:07:50.497 再记绿。脚本红案应由模型回源判断或修，不可批量自我豁免，这是 skill 的裁决机制。依据：`spec/closure/closure-final.json`、`spec/closure-waivers.json`、门历史。T/O。
18. **模拟器逐页与核心流。** 12:49 `Main`、`Settings` 机械计划均 `ok:true`；随后 `core-city` 12:54:26、`core-preferences` 12:58:32、`core-details` 13:02:01 报告均可执行，形成模拟器核心路径 3/3。运行报告中的 `ok:true` 仅表示步骤/探针/截图执行成功，复合行为仍须逐断言判断。`on-device-grant` 13:02、`system-location` 13:06 也有模拟器执行记录，但不等于实体硬件真值。依据：`spec/4b/*.report.json`。T。
19. **实体装机阻塞。** 第一轮未签名物理 HAP 安装返回 code 9568320 / `no signature file`；因此真机/B 级项不能声称通过。模拟器 3/3 不覆盖这一缺口。13:07:50.548 acceptance 门记 false；13:07:50.599 runtime-4b 也记 false，虽有模拟器核心 3/3。第一轮约 13:15:38.440 结束。依据：门历史、`spec/MIGRATION-METRICS.md`、首次 smoke/报告。T。

### E. 用户签名后的定向续跑（13:44–17:22 UTC）

20. **触发和恢复边界。** 用户完成签名并要求严格跑完全部流程、累计消耗、写明不能做的阻塞；13:44:41 是计量文件记录的续跑起点。根据 skill 的“中断恢复：读 ledger 和 workflow run；不重做已完成阶段”，本轮仅恢复四、五阶段及相关定向修复，不重建 `ledger init`、不重跑前场/探索、不改 `freeze.json` 的 113 分母。依据：用户 C、`spec/MIGRATION-METRICS.md` T、`spec/session-progress.md` O。
21. **先清未验/失败库存。** `spec/resume/inventory.json/.md`、`original33-disposition.md` 将早期未验 33 条逐项分配到 owner 和证据层；最终 29 条补证、4 条仍缺。`current-outcomes.json` 记录原 6 个 failed 中 DP-A29、DP-A33、WUI-A18 关闭；DP-A25、WUI-A13、WUI-A35 未关闭，新增 DP-A08 真机失败。此处记录的是前后差集，而不是改变断言。O。
22. **真实二进制设置存储分支。** 初始 `fnd-app-init` 失败的关键是 `settings.pb` 必须是源 14 份 proto schema 对应的真实 protobuf 二进制，不能用近似 JSON 冒充。按 skill 的“先查平台/库、不重造已有原语”选用官方 `@hadss/turbo-trans-protobuf` rc.5，补齐读写/仓储，接口由真代码重派生（10 文件、101 导出）。Darwin 主机 LocalTest 无法装载该库的 ELF 原生模块，所以没有报告 host 测试通过，改用签名测试 HAP 在手机跑。依据：`spec/resume/protobuf-repair-evidence.md`、`spec/REPORT.md`、原生日志。O。
23. **实体签名与原生回归。** 主 HAP 和 ohosTest HAP 在真实设备签名安装成功；原生 Hypium 43/43。第一次手机逐页计划 14:44:07/14:44:13；城市、偏好、详情核心流分别 14:56:26、14:57:09、14:59:05，最终实体核心路径 3/3。偏好验证使用非默认华氏度/俄语并冷启，城市选择/二进制恢复也经过真实设备，不以默认值证明持久化。依据：`spec/4b-phone/*.report.json`、`spec/resume/native-vectors-77UYD26331000973.json`。T/O。
24. **定位分叉。** 真机精确定位原生例 15:10 左右 1/1；大致权限首次计划/UI 前置条件不对，随后在正确“仅大致授予、精确拒绝”的状态下两次原生 `getCurrentLocation` 返回 201，最后一次还显式保持前台。三次总尝试的记录时间分别约 15:15、15:26、15:35。SDK 文档允许 approximate-only，因此不能把 201 自行归咎为平台无等价，也不能偷换成 fine-only 或拿精确定位成功抵扣。按 skill 的有界“一次定向修＋一次复验/时间盒”原则和本轮停止文件，DP-A08 failed。依据：`spec/resume/location-NativeLocationCoarse-01/02/03.*`、`coarse-diagnosis.md`、`stop-and-limits.md`、台账。T/O。
25. **首页风险补证。** `page-risk-targeted` 16:00、`page-risk-geometry` 16:02、`page-risk-locale` 16:03 记录手机手势/几何与英俄界面。WUI-A18 有真实 MOVE、父位移/headerDelta 为 0、横向内容移动，因而从失败转通过；但头部下滑恢复三次未到展开终点，不能用“swipe/shot 成功”证明 WUI-A13 或复合 WUI-A35。设置入场中间帧、刷新进度因果、图表点选/动画、降水末端交接仍缺证。依据：`spec/resume/page-risk-device-evidence.md`、`page-main-results.json`、`stop-and-limits.md`、`spec/4b-phone`。T/O。
26. **图标与系统定位设置的独立修复。** 目标 SVG 出现资源显示问题后，workflow `svg_reported_fix` 只修 XML 检查报告命中的 13 个目标 SVG 尾部未闭合空 `<g>`，不改源应用或转换器；`xmllint`、签名构建及手机 `icon-only` 16:22:31 照片确认。系统位置服务关闭→提示→唯一 Settings→系统页→返回应用于 `system-provider` 16:47:32 完成，之后恢复设备开关并留最终截图。两者不是对定位 201 或头部恢复的偷偷重试。依据：`svg_reported_fix.run.md`、`spec/resume/icon-repair.md`、对应 4b 报告和 `screenshots-phone/location-restoration-final.png`。T/O。
27. **余下六项的针对性走查。** 模拟器 `remaining-six-entry` 17:09:49 首次计划失败，修正目标匹配后 `remaining-six-entry-r1` 17:10:28 执行成功；`remaining-six-behavior` 17:11:37 仍不满足全部行为证据。依 skill 的 `walk.mjs` 报错分类，先区分计划目标缺失/歧义与真实应用缺陷；计划执行成功也不覆盖行为断言。依据：`spec/4b-sim-resume/*.report.json`、`spec/resume/remaining-six-evidence.md`。T/O。
28. **原生 IO 返修和验收复跑。** 二进制库集成后 final closure 初检报 Runtime.ets 同步 IO 2 个硬违规、async 2 个软案，17:22:51.717 如实记红；加错误出口并在手机仅定向跑 IO 3/3 后，17:22:51.775 closure-final 记绿、硬违规 0。`accept_signed_resume` 与 `accept_page_proof` 只用 `prior/only` 复验失败片；`fnd-app-init` 在 15:53:43.225 转 accepted，`page-main` 仍 failed。17:22:51.827 acceptance false；17:22:51.881 runtime false。依据：门历史、workflow 导出、`spec/resume/io-guard-native.json`、`spec/accept-prior.json`。T/O。

### F. 发布回流、计量和后续交付（17:22 UTC 以后）

29. **最终台账封账。** `ledger verify --sdk auto --require-gates closure-final,runtime-4b` exit 0；脚本随后将 ledger 投影为 `spec/REPORT.md`，其更新时间 17:29:57.589。该 verify 只要求必需门有记录、证据/降级/债务纪律合格，不要求门值都 true；所以总判断仍不能全过。`spec/feedback.md` 留源行为冲突、未收敛风险和潜在回流建议；skill 明确只产候选，不直接修改套件。DevEco 主会话结束 17:40:31.912，最终设备状态/封账核对 17:41:52。T/O。
30. **总消耗口径。** 开始 10:44:05 至最终核对 17:41:52，跨轮墙钟 6:57:47，其中 13:15:38.440–13:44:41 为约 29 分钟暂停；实际两段工作合计 6:28:44.440。DevEco 主会话及递归子会话共 62 个；非缓存输入 4,567,115、输出 438,502、缓存读取 115,730,944、缓存写入 0，总 120,736,561 token。reasoning 222,842 是输出内含子项，不能再加。计量取 DevEco 本地会话数据库递归 `tokens_*` 字段，**不含本 Codex 桌面聊天**，也不是费用。依据：`spec/MIGRATION-METRICS.md`。T/O。
31. **报告与截图整理。** 之后用户要求仅以最终状态制作一份中英合并评估报告，补源应用简介、代码行数、主要分支和未通过原因；又要求 Android 模拟器与 Harmony 真机的关键截图各三组放在报告尾部。2026-10-12 的最终报告 `WeatherApp-Codex-Report.md` 已包含主页、设置、日图/降水三组对照；图片统一位于 `screenshots/WeatherApp-Codex/`。截图只能比较可见结构，不能证明动画或设备行为。用户追加的实测体验记录了“基本功能/主要信息完整，少量媒体未对齐；换城后下拉刷新切回原城市；不同语言文本掺杂”，这些是追加观察，**没有重新给冻结 113 条断言过账**。依据：本聊天 C、报告及截图文件 O；逐条截图采集时刻未从当前可见证据核准。
32. **源码交付副本。** 按用户要求把当时目标工程源码放入 `outcomes/WeatherApp-Codex/` 并去除签名材料，保留 Markdown 报告和同目录树内图片引用。该副本服务于过程评判，不应当反推为后续又完成了一次迁移或验收。依据：本聊天 C、`outcomes/WeatherApp-Codex/` O。该副本与带 `spec/`、workflow 原始证据的工作工程不同；详审应回查工作工程。未核实归档复制的精确 UTC 时刻。

## 3. 为什么最后停在这些状态

| 项目 | 最终状态 | 停止/未判通过的直接原因 | 性质与依据 |
|---|---|---|---|
| `DP-A25` 气压单位 | failed | 源实现把 OpenMeteo hPa 值标为选定单位，冻结安全句又要求不得按错标签二次换算；两者冲突。无 PRD 覆盖或用户授权变更行为，不改冻结断言，也不假装通过。 | 源锚点卡＋`resume/stop-and-limits.md`；需要产品决策。 |
| `DP-A08` 大致定位 | failed | 正确授权状态后真实调用两次返回 201；精确定位成功不覆盖此项，三次总尝试触及停止线；未证明平台缺陷。 | 原生手机日志＋skill 有界复验。 |
| `WUI-A13` 头部恢复 | failed | 上滑收缩可见，但限定三次下滑未回展开端点。 | 手机手势/几何报告＋停止文件。 |
| `WUI-A35` 复合界面 | failed | MOVE 等局部项有证据，但头部恢复、内滚边界、刷新协同、长文本等整套复合契约未闭合。 | `page-main` 验收判词＋走查。 |
| `SS-A01` | untested | 设置可打开/返回，未捕获右侧滑入中间帧。 | 原始 33 差集与页面结果。 |
| `WUI-A12` | untested | 下拉和终态已见，刷新进度出现/结束的独立因果序列未见。 | 同上。 |
| `WUI-A20` | untested | 静态曲线可证，点选 marker 与 1 秒动画行为未见。 | 同上。 |
| `WUI-A21` | untested | 内滚可见，末项可达及双边界交接未见。 | 同上。 |

这四项未验**不是统一的真机阻塞**。工作流确有返修机制：acceptance 保存 `priorFile`，使用 `only`/`resumeFrom` 定向复验；4b 对真实缺陷允许限额的针对性修复和涉事流复测；不收敛则失败/未验入账并进入最终报告。它不是“只要失败就无限循环直到变绿”。依据：`SKILL.md` 阶段 4a/4b 与实际 `accept_retry`、`accept_signed_resume`、`accept_page_proof`、`stop-and-limits.md`。

## 4. 证据入口与复现边界

| 来源 | 能证明什么 | 不能证明什么 |
|---|---|---|
| 本目录 `SKILL.md` | 五阶段规则、分支、返修与停止纪律 | 某一条规则实际上已执行。 |
| `output/WeatherAppHM/spec/feasibility.json`、`front/front-report.json` | 源规模、形态、前场各脚本退出码和摘要 | 后续用户行为、全部真机功能。 |
| `spec/cards/`、`features-batch.json`、`slices-batch.json`、`freeze.json` | 断言来源、切片归属、冻结范围 | 断言最终通过。 |
| `spec/ledger/ledger.json` | 逐项状态历史、UTC 时间、门记录 | 代理未落盘的全部推理或所有设备操作。 |
| `.deveco/workflows/WeatherAppHM/*.run.md`、`*.journal.jsonl` | 9 次 workflow 的输入、阶段、结果与返修轨迹 | 每个子会话的完整内部思考；journal 本身大多无时间戳。 |
| `spec/4b/`、`4b-phone/`、`4b-sim-resume/`、`resume/*native*` | 逐步走查、原生测试、失败类型与截图 | 报告未覆盖的时间性/复合行为。 |
| `spec/closure/closure-final.json`、`accept-prior.json`、`REPORT.md` | 静态闭合、判断性判词、最终四态和门 | “verify exit 0”并不证明所有门通过。 |
| `spec/MIGRATION-METRICS.md` | 迁移会话累计用量和两个工作时段 | 本 Codex 聊天 token 或货币费用。 |

要**重走工作流**可以按 skill 的五相步骤和上述参数/产物重新执行，但不能保证得到同一耗时、token、网络天气、定位服务结果或签名环境；源/目标当前文件也可能与 2026-10-09 当时状态不同。尤其不能从这份操作记录声称“可无差别、逐命令复刻”；更准确的说法是：主要决策、脚本门、失败返修、设备证据和最终判定**可以据现存材料复核**。敏感签名配置/凭据不在本记录中展开。
