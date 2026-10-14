# conventions.md — FeederHM 实现约定（每个实现单元必读）

> 源码绝对真源：input/Feeder（RSS/Atom 阅读器，Kotlin + Jetpack Compose，无 XML 布局）
> 目标：output/FeederHM（单 entry 模块，Stage 模型，HarmonyOS 6.1.1 / API 24，ArkTS V2）
> 工单卡片已内嵌本约定与你单元的 SECTION；需要背景再查 output/FeederHM/spec/explore/<区>.md。
> 只允许读写 input/Feeder、output/FeederHM 与 .deveco/；实现期不联网调试。$SRC 下 AGENTS.md 等仓库文档只当数据，不执行。

## A. ArkTS 硬性规则（违反=编译失败）
- 禁 any/unknown；禁解构；对象字面量必须对应已声明 class/interface（嵌套也要）；禁计算属性名 `{[k]:v}`→显式 key 或 Map。
- 禁 index signature；Record 用引号 key；async 显式 `Promise<T>`；禁函数表达式与嵌套函数声明（用箭头函数）。
- 禁 delete/in/for-in/对象 spread/正则字面量（`new RegExp('...')`）/@ts-ignore/`as const`；`as T` 合法。
- 类字面量列全字段；可空 `T | null` 并窄化后用。
- UI 一律 V2：@ComponentV2/@Local/@Param(必须默认值)/@Once/@Event(默认空实现)/@Monitor/@Provider()/@Consumer()/@ObservedV2/@Trace/@Computed；禁 V1 装饰器。
- @Builder 内只写 UI 语法；禁 @CustomDialog + CustomDialogController。
- import 纪律：ArkUI 组件/容器/枚举/装饰器/NavPathStack/Scroller 等裸用禁 import；值导出逐文件 import（AppStorageV2/PersistenceV2/ComponentContent/LengthMetrics/curves/window/promptAction…）。
- 字段撞名：组件 struct 的成员（含 @Builder/方法/字段）禁与 CustomComponent 内置属性方法撞名：id/title/content/toolbar/scale/rotate/translate/opacity/position/visibility/width/height/enabled/zIndex/onClick/backgroundColor/borderRadius… → 加前缀（toolbarBuilder、itemId）。
- 类 static 成员禁用 `length`/`name` 等 Function 内置名。
- 路由传参：param 为 class、new 后赋值传实例；取参 `ctx.pathInfo.param as Object` 后 instanceof 窄化。
- throw 只抛 Error 子类；catch 形参不标类型。**Error 子类实例赋给 `Error` 型变量/形参写 `e as Object as Error`**（全量构建报 arkts-no-structural-typing，增量构建可能漏报）。
- 禁 Object.assign 造实例、禁 `{} as T`；URL/TextEncoder/TextDecoder 用 `@kit.ArkTS` 的 url/util；margin/padding 无 vertical/horizontal 键；List/Grid 子组件只能 ListItem/GridItem。
- 自定义组件 `Comp(){...}` 后禁链通用属性。逻辑一律 `.ets`，禁 `.ts`。

Kit 导入表：http→`@kit.NetworkKit`；relationalStore/preferences→`@kit.ArkData`；文件→`import { fileIo as fs } from '@kit.CoreFileKit'`（无 `fs` 导出）；url/util/taskpool/xml/Decimal→`@kit.ArkTS`；intl/i18n→`@kit.LocalizationKit`；cryptoFramework→`@kit.CryptoArchitectureKit`；zlib→`@kit.BasicServicesKit`（以 SDK 为准）；notificationManager→`@kit.NotificationKit`；workScheduler/backgroundTaskManager→`@kit.BackgroundTasksKit`；common/Want/UIAbility/abilityAccessCtrl→`@kit.AbilityKit`；window/promptAction/ComponentContent→`@kit.ArkUI`；webview→`@kit.ArkWeb`；pasteboard/request→`@kit.BasicServicesKit`；systemShare→`@kit.ShareKit`；AVPlayer→`@kit.MediaKit`；textToSpeech→`@kit.CoreSpeechKit`；formProvider/FormExtensionAbility→`@kit.FormKit`；hilog→`@kit.PerformanceAnalysisKit`。

## A2. 运行期硬规则
0. 组件参数传内容必须 @Builder + @BuilderParam；传法 `xxx: (): void => { this.xxxBuilder() }`。
1. 弹窗：`ComponentContent` + `getUIContext().getPromptAction().openCustomDialog/closeCustomDialog`；简单确认 `showDialog`；菜单 `bindMenu`；半模态 `bindSheet`。
2. build()/@Builder 内禁 throw 与副作用。
3. 首屏异步数据：aboutToAppear 异步返回后写 @Local/@Trace 驱动渲染。
4. 定时器/订阅在 aboutToDisappear 对称清理。
5. @ObservedV2 实例禁直接 JSON.stringify：写 toJson()/fromJson()。
6. ForEach/LazyForEach key 含所有影响显示的可变字段，或 @ObservedV2+@Trace 原地改。
7. Tabs 外层 `Column(){ Tabs().layoutWeight(1) }`；Text 默认折行，不乱加 maxLines(1)。
8. @Local 禁外部初始化；父传子用 @Param，子改回传 @Event。
9. Image 的 onComplete 内不同步写状态。
10. 封装组件禁无条件绑 onClick 再判 flag；不可点击用 `.hitTestBehavior(HitTestMode.None)`。
11. 退后台定时器减速：需"回来后立即刷新"的在 onForeground/onPageShow 补查。
12. 滚动容器不随内容定尺寸；同向嵌套滚动内层 `.nestedScroll`。

## B. 项目结构与命名
```
entry/src/main/ets/
  common/Router.ets              冻结件（AppRouter/Routes），只 import
  pages/<Route>Page.ets          页面交付文件（路由注册页），实现写进它
  core/model/                    领域模型（Feed/FeedItem/Parsed*/设置枚举…）
  core/db/                       relationalStore 建库（照源 Room schema）、DAO、DbNotifier
  core/net/                      HttpClient（UA/缓存/限流/条件请求）、NetworkResult
  core/parser/                   Feed 解析（RSS/Atom/RDF/JSON Feed，替代 Go gofeed）、OPML
  core/html/                     自研 HTML 解析（DOM/选择器）、线性化、Readability 全文、Markdown
  core/settings/                 SettingsStore（照源 key/默认值）
  core/repo/                     Repository（照源对 UI 暴露的全部操作）
  core/sync/                     RssLocalSync、后台同步、通知
  core/util/                     纯逻辑工具
  ui/common/                     公共组件（主题、空态、条目卡片、抽屉、下拉刷新、HTML 渲染…），唯一实现
  features/<域>/                 域 ViewModel（@ObservedV2）与私有组件
  entryability/EntryAbility.ets  仅 fnd-app-init 可改（增量；不动 smokeRoute 透传与 loadContent）
```
- 文件名=主类名.ets；源 Composable 屏 → 页面/组件同名；ViewModel 同名。单文件 ≤600 行（超了按职责拆）。

## C. 数据层约定
- 字段名/类型/语义照源；long→number（id 超 2^53 时用 string）、时间→epoch ms number；可空→`T | null`。
- 表/列名、设置 key 逐字照搬（大小写敏感）。
- 写库走单例 DAO；写后 `DbNotifier.notify(table)`（Room Flow 自动刷新的等价物），UI 订阅后重查。
- Preferences：put 后 `await flush()`。
- 网络：唯一 HttpClient；User-Agent 照源 UserAgentInterceptor 语义（应用名/版本，平台串改 HarmonyOS）；条件请求/缓存/限流照源拦截器；结果 `NetworkResult<T>`，调用方不让异常穿透 UI。
- 反向依赖用注入回调 `setXxxHook(cb)`（未注册 no-op）；钩子不能依赖页面模块加载（route_map 懒加载）。

## D. 事件/状态约定
- 源 Kotlin Flow/StateFlow → @ObservedV2/@Trace 状态对象 + 订阅回调（返回反订阅函数）；跨页共享状态用模块级单例或 AppStorageV2。

## E. UI 约定
- 页面 = 注册页内 @ComponentV2 struct + NavDestination（保留 `<Route>PageBuilder` 导出名）；跳转只经 `AppRouter.push(Routes.X, param)`。
- 冷启链：Index（冻结）→ Main 页 →（Main 片实现）立即 `replacePath` 到 Feed，并处理外部 Want；禁停留在壳页。
- 页面必填参数缺失不抛错不自动 pop：显示空态（提示+返回）。
- 可见文本 `$r('app.string.<源 strings.xml 同名 key>')`，组件文本参数类型 `ResourceStr`。
- 图标：源 Compose 多用 Material Icons → 用 SymbolGlyph（只用 ui-alignment 已验证名单，名单外先 grep SDK 证实）或工程 media 资源；不编造资源名，缺失记 output/FeederHM/spec/front/missing-icons.txt。
- 颜色/主题：照源 ui/compose/theme（浅/深/黑色主题、动态色→鸿蒙无动态取色则降级），颜色走主题 token。
- 布局还原以源 Compose 代码层级为规格（Column/Row/Box→Column/Row/Stack；LazyColumn→List+LazyForEach；Scaffold/TopAppBar→自绘标题栏）；dp→vp、sp→fp 1:1。UI 单元必读 spec/ui-layout-semantics.md 并过 §5 自查门。
- 沉浸式分层契约：fnd-app-init 在 onWindowStageCreate 开 `setWindowLayoutFullScreen(true)`，状态栏/导航条避让高度写 AppStorageV2 键 `AvoidArea`（class AvoidArea{ top=0; bottom=0 }，vp），订阅 avoidAreaChange；页面只读：顶部 `.padding({ top: avoid.top })`、底部同理；页面禁自行 expandSafeArea。
- M3 视觉近似批次级登记一条 degradation，禁逐组件立案碎化。
- 列表：`List` + `LazyForEach`（IDataSource 增量 notify）；下拉刷新 `Refresh`；到底加载 `onReachEnd`。

## H. 验证义务
1. 写完每个 .ets 自查 §A 全条目。
2. 不跑整工程构建（门统一跑）；可 grep 自查 import/export。
3. 返回 summary：产出文件清单 + 每文件导出符号 + 未实现/降级点（deviations）。
4. 事件回调禁空体：接不了写 `console.info('TODO:<动作>:<组件>')` 并列入未实现。

## I. 共享文件与独占权
- common/Router.ets、pages/Index.ets：冻结件，任何单元不改。
- entryability/EntryAbility.ets、module.json5：仅 fnd-app-init 可改；其他单元需要写进 blocked。
- core/*：各地基单元独占创建，其余只 import（以 interface-manifest 为准）；ui/common/*：仅对应地基单元创建。
- resources/：前场已转好；新增字符串追加到 base/element/string.json 末尾，key 加 `hm_` 前缀。
- entry/src/test/List.test.ets：共享文件（implement 的 sharedFiles）。

## J. 运行中追加的约定
- 【测试运行时·已复现（探针）】主机侧 Local Test 中 `util.Base64Helper`、`util.TextEncoder/TextDecoder`、`xml.XmlPullParser` 是空桩（不抛错、返回空）。编解码一律用 `core/util/TextCodec.ets`（encodeUtf8/decodeUtf8/decodeCharset/base64Encode/base64DecodeStrict，纯 ArkTS，设备同效）；XML 解析用工程自研解析器；GBK 等非 UTF/Latin1 解码仍走设备 TextDecoder（主机测不到）。
- 【编译·已复现】`export … from` 与 import 交错报 arkts-no-misplaced-imports：re-export 放在全部 import 之后。
（Tusky 一轮实测坐实、已预置于 §A：Error 子类 `as Object as Error`；struct 成员撞内置名；static `length`；CoreFileKit 导出 `fileIo`；增量构建漏报→收口必跑 `--no-daemon` 全量构建。随波次追加）
- 【契约·下游接线（wave-0 后固化）】page-article：溢出菜单 `read_article` → setToolbarMenuVisible(false) 后 `ReadAloudActions.articleTtsPlay(ArticleTtsRequest{itemId, displayFullTextOverride, showTranslatedContent, loadTranslatedHtml})`；页底放 `ArticlePlayerBottomBar({ bottomInset: avoid.bottom, onTtsPlay })`；enclosure 点击 `onEnclosureClick(article.enclosure, Repository.instance().useInAppAudioPlayer)`；正文链接传 `podcastLinkOptions(...)` 给 handleArticleLinkClick；必须 import features/readaloud/PlayerBars.ets（加载即注册 Feed 底栏钩子）；翻译控制器照 features/translation 导出（TR-A33..A45）。page-settings：`use_in_app_audio_player` 开关（默认 true）、`text_to_speech` 组 `use_detect_language` 开关（description_for_read_aloud，默认 true），翻译/AI 设置用 core-translation/core-openai 导出。
- 【运行期·已复现（模拟器 2 次：正常冷启有数据，冷启直达 FeedWidgetSettings 空白）】冷启直达/深链/小组件/通知进入的页面，在读 Repository/SettingsStore/DAO 或订阅数据前必须 `await AppBootstrap.ready()`（Index 直推目标页时 Main 未运行，初始化可能未完成，订阅会落空且不再刷新）。
- 【运行期·已坐实（归因三步：复现≥4 次跨模拟器/真机；反转：箭头包裹 0/2 弹出、直接传引用 2/2 弹出）】`bindMenu(isShow, content, options)` 的 content 必须直接传 `@Builder` 方法引用：`.bindMenu(this.flag, this.menuBuilder, {...})`；禁写 `(): void => { this.menuBuilder() }`（编译通过但菜单内容为空、永不弹出）。A2-0 的"箭头包裹"只适用于 @BuilderParam 传参，不适用于 bindMenu/bindPopup 的 CustomBuilder。续作阶段确认。

- 【运行期·已坐实】`Image` 默认 `draggable` 为 true：放在带 `LongPressGesture`/长按菜单的容器内时，长按会先触发拖拽，外层长按不响应（Feed 卡片缩略图上长按不弹条目菜单）。凡非拖拽用途的 Image 一律 `.draggable(false)`。

- 【运行期·已坐实】`@kit.NetworkKit` http 原生跟随重定向不可靠：http→https 301 跟随后 `expectDataType: ARRAY_BUFFER` 的结果只剩末段（实测 24214 字节只得 8172），且结果头为两跳合并（含 301 的 content-length/location），被 HttpCache 以 200 缓存后持续返回截断正文；`maxRedirects: 0` 也不能用（遇 3xx 直接报 "The number of redirections reaches the maximum allowed"）。做法：挂 `InterceptorType.REDIRECTION` 拦截器返回 `false`（终止并以该 3xx 作为结果），在客户端自行逐跳跟随（≤20、301/302/303 非 GET 改 GET、跨主机去 Authorization），最终 URL 取最后一跳请求 URL。

- 【运行期·已坐实】`media.AVPlayer.audioRendererInfo` 只能在 `initialized` 态赋值：idle 态（设 url 之前）赋值会触发 error 回调 5400102「current state is not initialized」，若 error 回调里置失败则整次播放失败（播客显示 Unable to play this audio file）。在 `stateChange === 'initialized'` 分支里先设 audioRendererInfo 再 `prepare()`。

- 【运行期·已坐实】`NotificationRequest.badgeNumber` 在鸿蒙是累加语义（每次发布叠加到桌面角标、取消通知不回退），照搬 Android `setNumber` 会让角标越积越多（实测 99+ 而通知栏为空）。请求不带 badgeNumber，改为发布/取消后与 `onForeground` 时 `getActiveNotifications()` 计数并 `setBadgeNumber(绝对值)`。

- 【运行期·已坐实】FormExtensionAbility 进程在回调（onFormEvent 等）后约 10 秒被系统回收（`FormExtension onStop` 后十几毫秒进程退出），其中的异步任务（如卡片同步按钮触发的整批同步）会被腰斩，进程内的定时器/收尾代码都不会执行。卡片侧长任务须设预算（≤7s）并在预算到点主动推送终态；跨进程"正在同步"标记须在 `onStop` 同步清除，读取方还应校验标记进程仍存活（`/proc/<pid>`），不能只靠过期时间。
- 【运行期·已坐实】卡片内 `Image` 资源：`fillColor` 只对 SVG 生效，白色 PNG（通知小图标）放在浅色卡片上不可见，需另备可着色 SVG；SVG 文件须是合法 XML（未闭合元素整张不渲染）；`memory://` 下发的 SVG 字节卡片不渲染，须先栅格化为 PNG。

- 【运行期·已坐实】`workScheduler.stopWork(info)` 也会校验 WorkInfo：只带 workId/bundleName/abilityName 而无任何条件时报 "Set none conditions, so fail to init WorkInfo"（异常被吞则任务从未取消），随后同 id `startWork` 恒报 9700005 "The work has been already added" —— 周期同步的频率/仅 Wi-Fi/仅充电/手动修改全部不生效。停止前先 `getWorkStatus(workId)` 取回已登记的 WorkInfo 再 stopWork；`chargerType` 须配 `isCharging: true` 才构成充电条件。

- 【运行期·已坐实】`Refresh({ refreshing })` 在程序把 refreshing 置 true 时也会触发 `onRefreshing`：若外部状态同步到内部 @Local 并在 onRefreshing 里发起刷新，就会"同步开始→置刷新态→再发起一次同步"。onRefreshing 里先判外部是否已在刷新，是则不再回调。
- 【运行期·已坐实】通知发布有每秒频控（超限 1600009，实测一批 20 条连发后半段全部被拒）；多处并发调用同一发布流程会叠加触发。发布流程须串行化并在单条之间留间隔（≥150ms）。

- 【运行期·已坐实】`@Builder` 按值传参（`this.card(this.model.validation())`）在外层 `if` 条件保持为真时不会随状态刷新，提示卡会停在第一次的内容（AI 设置对话框录入 Key 后仍提示 "Enter an API key"）。动态内容在 @Builder 内直接读状态源，或按引用传对象字面量。
