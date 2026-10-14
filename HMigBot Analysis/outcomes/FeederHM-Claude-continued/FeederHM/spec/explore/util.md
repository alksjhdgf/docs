# 探索文档：util（工具域）

范围：`util/`（17 文件）、`ui/compose/utils/`（14 文件）、`ui/text/VideoTagHunter.kt`。
排除：`ui/text/HtmlToPlainTextConverter.kt`、`ui/text/MarkdownToHtmlConverter.kt`（归 html-model）。
断言卡：`output/FeederHM/spec/cards/util.md`（UT-A01..UT-A48；backend 38 / ui 6 / on_device 4）。
路径前缀省略：下文 `F/` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/`，测试 `T/` = `input/Feeder/app/src/test/java/com/nononsenseapps/feeder/`。

总规模约 2150 行（不含排除的 2 个文件），其中 `Either.kt` 436 行（大部分是 Arrow 移植的注释）、`FeederTextToolbar.kt` 314 行。

---

## 1. 文件清单与职责

| 文件 | 行数 | 职责 | 平台依赖 | 主要调用方 |
|---|---|---|---|---|
| F/util/LinkUtils.kt | 122 | URL 规整、相对→绝对 | java.net.URL/URI | FeedParser, RssLocalSync, Converters, FeedItemWithFeed, CreateFeedScreenViewModel, SearchFeed*, PreviewItem, GoFeedExtensions |
| F/util/UrlCleaner.kt | 49 | 分享前去追踪参数 | java.net | FeedScreen.kt:1520/1764, ArticleScreen.kt:168 |
| F/util/HtmlUtils.kt | 160 | 首图提取、og:image 提取与抓取 | Jsoup, OkHttp | GoFeedExtensions(findFirstImageInHtml), RssLocalSync.kt:575(fetchOgImage) |
| F/ui/text/VideoTagHunter.kt | 33 | YouTube embed 识别 | 纯 Kotlin | HtmlLinearizer.kt:727 |
| F/util/ActivityLauncher.kt | 130 | 打开外链/启动 Activity | Intent, CustomTabs, Toast | FeedScreen, ArticleScreen, OpenLinkInDefaultActivity, Settings, SyncScreen, FeederTextToolbar；DI 在 F/base/DIAwareComponentActivity.kt:25 |
| F/util/SystemUtils.kt | 34 | 联网/计费/充电判断、urlEncode | ConnectivityManager, BatteryManager | MainActivityViewModel.kt:54, FeederApplication.kt:161, SyncScreenViewModel.kt:229, RssNotifications.kt:320 |
| F/util/ContextExtensions.kt | 110 | ToastMaker 接口、动态快捷方式、BiDi 包裹、Locale、深链常量 | ShortcutManager, BidiFormatter | Repository.kt:122/128, ArticleScreen.kt:689, NavigationDestinations, RssNotifications, FeedWidget, SyncScreen*, ImportOPMLFileActivity |
| F/util/LetterIconProvider.kt | 86 | 圆形字母图标位图 | android.graphics | 仅 ContextExtensions（快捷方式图标） |
| F/util/FilePathProvider.kt | 58 | 目录布局 | java.io.File | DI，多处（CleanupOrphanedFilesJob, FontStore, TranslationManager, FullTextParser…） |
| F/util/Either.kt | 436 | Arrow 风格 Either + catching | 纯 Kotlin | ArticleViewModel, FeedViewModel, Repository, FeedParser, Opml*, RssLocalSync, SavedArticles*, FullTextParser |
| F/util/BugReport.kt | 17 | GitHub issues / Ko-fi Intent | Intent | Settings.kt:256, SyncScreen.kt:613/846 |
| F/util/PrefUtils.kt | 13 | `PREF_MAX_ITEM_COUNT_PER_FEED`、getStringNonNull | SharedPreferences | SettingsStore.kt:338 |
| F/util/Time.kt | 6 | Instant.minusMinutes | java.time | 仅测试 |
| F/util/Logging.kt | 14 | logDebug（仅 DEBUG 构建输出） | Log, BuildConfig | 大量 |
| F/util/DoNotUseInProd.kt | 6 | OptIn 注解 | — | 测试/迁移 |
| F/util/CursorExtensions.kt / SQLiteDatabaseExtensions.kt / ContentValuesExtensions.kt | 13/13/27 | 旧 SQLite 辅助 | android.database | AppDatabase 迁移（AppDatabase.kt:957 另有 SupportSQLiteDatabase 版 inTransaction） |
| F/ui/compose/utils/ComposeProviders.kt | 70 | `withAllProviders`：DI→折叠铰链→窗口度量→窗口尺寸类→字体设置→主题→文本工具栏 | Compose | MainActivity.kt:99, AddFeedFromShareActivity, ManageSettingsActivity, ImportOPMLFileActivity, FeedWidgetSettingsActivity |
| F/ui/compose/utils/WindowSize.kt | 84 | WindowSizeClass、窗口 DpSize、isCompact*、ScreenType | material3-window-size, androidx.window | TextSettings, EditFeed, SearchFeed, OpmlImport, SyncScreen, Dimensions, FeedScreen, SwipeableFeedItemPreview |
| F/ui/compose/utils/Foldables.kt | 38 | 折叠铰链 bounds | androidx.window FoldingFeature, accompanist adaptive | NavigationDrawerTokens.kt:55 |
| F/ui/compose/utils/FeederTextToolbar.kt | 314 | 自定义浮动文本选择菜单 + PROCESS_TEXT | ActionMode, PackageManager, ClipboardManager | ComposeProviders |
| F/ui/compose/utils/Focusable.kt | 40 | Esc/Back 键处理、非触摸模式可聚焦 | Compose | ArticleScreen, Settings, FeedItemCard, FeedScreen, ReadAloudPlayer, NavDrawer, SyncScreen；ReaderView, LinearArticleContent |
| F/ui/compose/utils/MutableSavedState.kt | 46 | SavedStateHandle 委托 | SavedStateHandle | EditFeedScreenViewModel, CreateFeedScreenViewModel |
| F/ui/compose/utils/Permissions.kt | 34 | 按 API 级别的权限状态 | accompanist permissions | Settings.kt, EditFeedScreen.kt（通知权限） |
| F/ui/compose/utils/ProvideScaledText.kt | 26 | 文本样式按 fontScale 缩放 | Compose | ReaderView, TextSettings, LinearArticleContent, OpmlImportScreen |
| F/ui/compose/utils/WindowInsets.kt | 59 | insets 加边距（含 RTL 版） | Compose | addMarginLayout 未被引用 |
| F/ui/compose/utils/Wrapper.kt | 48 | StableHolder/ImmutableHolder（Compose 稳定性包装） | Compose | 广泛 |
| F/ui/compose/utils/DIUtils.kt | 16 | rememberApplicationCoroutineScope | Kodein | — |
| F/ui/compose/utils/LogCompositions.kt / PreviewThemes.kt | 27/16 | 调试/预览 | — | 无迁移价值 |

---

## 2. 行为契约细节

### 2.1 LinkUtils（F/util/LinkUtils.kt）
- `sloppyLinkToStrictURL(url)`（:11）：
  1. `url.isBlank()` → 抛 `MalformedURLException("String is blank")`。
  2. `URL(url)` 成功即返回（Java URL 只接受已知协议：http/https/file/jar/ftp/mailto 等，取决于 JVM/Android 的 handler）。
  3. 失败则 `URI(url)`：若可解析且 `isAbsolute`（有 scheme）→ `uri.toURL()`，未知协议在此抛 MalformedURLException（测试 `gemini://google.com` 期望失败，T/util/LinkUtilsKtTest.kt）；若不是绝对 URI 或 URI 语法错误 → `URL("http://$url")`。
  - 实测（JDK）：`localhost:8080/feed` 被 URI 视为 scheme=`localhost` 的绝对 URI → 抛异常（不会补 http）；`//example.com/x` → 非绝对 → `http:////example.com/x`；`feed://x.com/rss` → 抛异常。鸿蒙实现需复现这些边界或明确偏离。
- `sloppyLinkToStrictURLOrNull`（:37）失败返回 null；`sloppyLinkToStrictURLNoThrows`（:52）失败返回 `URL("http://")`（Room 转换器与旧数据迁移用，保证不崩溃）。
- `relativeLinkIntoAbsoluteOrThrow(base, link)`（:95）：`URL(link)` 成功直接用，否则 `URL(base, link)`（RFC 3986 相对解析：`http://cowboy.com/dir/feed.xml`+`bob.jpg` → `http://cowboy.com/dir/bob.jpg`）。
- 三个包装：`relativeLinkIntoAbsolute`（失败→原 link）、`relativeLinkIntoAbsoluteOrNull`（null→null，失败→原 link）、`relativeLinkIntoAbsoluteOrNullIfNotValid`（失败→null，**无引用**）。
- `urlHasNoAuthParams` / `urlHasNoQueryParams`（:44/:46）被 RssLocalSync 用于判断能否安全做某些 URL 变换（详见 feed-sync 区）。

### 2.2 UrlCleaner（F/util/UrlCleaner.kt）
- 前缀列表固定：`utm_`、`traffic_source`（:23），`startsWith` 区分大小写；名字先 `URLDecoder.decode` 后匹配。
- 无 query / 无追踪参数 / URI 解析失败 → **原字符串原样返回**（不做任何规范化）。
- 有追踪参数时用 5 参 `URI(scheme, authority, path, query, fragment)` 重建（:48）。**已实测的怪癖**：Java 多参 URI 构造器总会把 `%` 引用为 `%25`，因此保留下来的参数值若含百分号转义会被**二次编码**（`?x=a%20b&utm_source=rss` → `?x=a%2520b`）；保留参数名经 `URLEncoder.encode` 重新编码（空格→`+`，`[]`→`%5B%5D`）。路径中的 `%20` 不受影响（用的是解码后的 path，再重新引用）。迁移时需决定：复刻（测试只覆盖简单值）还是修正；建议修正并记录差异，测试用例（T/util/UrlCleanerKtTest.kt 5 例）均不触及该怪癖。
- 调用点：仅"分享"动作（FeedScreen 两处、ArticleScreen 一处）；打开链接不清理。

### 2.3 HtmlUtils（F/util/HtmlUtils.kt）
- `findFirstImageInHtml(text, baseUrl)`（:16）：`Parser.unescapeEntities(text, true)` 后 Jsoup 解析（字节流 UTF-8），遍历 `img`：
  - 过滤 `width=="1"` 或 `height=="1"`（字符串比较，`1px` 不算）。
  - url=`abs:src`（baseUrl 为 null 时用 ""，相对 src 绝对化失败 → 空串 → 被过滤）。注意：`data:` URL 经 `abs:` 依然保留（测试证实）。
  - 过滤 url 含 `twitter_icon` / `facebook_icon`（忽略大小写）。
  - 返回 `ImageFromHTML(url,width,height)`，其 `fromBody` 恒为 true（F/model/ThumbnailImage.kt:19）。
  - 测试：T/util/HtmlUtilsKtTest.kt（多行 base64、单行、src 在远处、无 src→null、null→null、社交图标→null、跟踪像素→null）。
- `extractOgImage(html, baseUrl)`（:55）：遍历 `og:image`、`twitter:image`；每个 key 先 `meta[property="…"]` 再 `meta[name="…"]`；Jsoup 属性值选择器大小写不敏感；`metaImageUrl` = trim 后非空才算，`absUrl("content")` 为空时退回原 rawUrl（:83-88）。返回 `MediaImage(url)`（fromBody=false）。测试 T/util/ExtractOgImageTest.kt 共 18 例，全部落入 UT-A17..A19。
- `streamHeadContent`（:97）：InputStreamReader 强制 UTF-8，2048 字符块读取，找到 `</head>`（忽略大小写）即截断返回；超过 `MAX_HEAD_BYTES=65536`（实为字符数）停止。非 UTF-8 页面（如 GBK）meta 中的非 ASCII 会乱码，但 URL 通常 ASCII，影响小。
- `OkHttpClient.fetchOgImage(url)`（:130）：IO 调度器；Header `Accept: text/html`；`!isSuccessful` 抛 IOException；contentType 非 null 且 subtype 不是 `html`/`xhtml+xml` → null；head 为空 → null；base = 最终 `response.request.url`（重定向后）。测试 T/util/FetchOgImageTest.kt（302 重定向）。
  - 调用点 F/model/RssLocalSync.kt:565-583（`resolveThumbnailImage`，仅当 feed.fetchOgImages 开启，且 `ThumbnailImagePolicy.shouldFetchOgImage` 为真；异常被吞 → 保留原值）。策略本身属 feed-sync 区（FS-A42）。
  - 使用的 OkHttpClient 是应用全局客户端（含 UA、缓存、可能的拦截器），鸿蒙需用同一 HTTP 栈并开启重定向跟随。

### 2.4 VideoTagHunter（F/ui/text/VideoTagHunter.kt）
- 正则 `youtube.com/embed/([^?/]*)`（`.` 未转义，匹配任意字符；未锚定，`youtube-nocookie.com/embed/` 不匹配，因为前面是 `-nocookie`… 实际上 `youtube-nocookie.com` 中不含子串 `youtube.com`，故不识别）。
- 缩略图使用 `http://`（非 https）——鸿蒙若禁明文 HTTP 需改 https 或放行该域名。
- Video.width/height 固定 480/360；HtmlLinearizer 优先用 iframe 自身 width/height。与 HM-A32 重叠，本区只记函数契约（UT-A22）。

### 2.5 ActivityLauncher（F/util/ActivityLauncher.kt）
- 构造：`ActivityLauncher(activity, repository)`，由 DIAwareComponentActivity 绑定（F/base/DIAwareComponentActivity.kt:25）——每个 Activity 一个实例。
- `openLink(link, toolbarColor, openAdjacentIfSuitable=true)`（:55）：
  - 空白或 `#` 开头 → false；`mailto:` → `ACTION_SENDTO`；否则按 `repository.linkOpener`（SettingsStore.kt:871 枚举 `CUSTOM_TAB`/`DEFAULT_BROWSER`；字符串值 `"3"`/`"2"`，未知值 → CUSTOM_TAB，SettingsStore.kt:932）。
- `openLinkInBrowser`（:83）：ACTION_VIEW + `Browser.EXTRA_CREATE_NEW_TAB=true`。
- `openLinkInCustomTab`（:98）：CustomTabsIntent，`setToolbarColor`、`addDefaultShareMenuItem`；ActivityNotFound → Toast；其他异常（坏链接）→ 静默 false。
- `startActivity`（:37）：ActivityNotFoundException → Log + Toast `R.string.no_activity_for_link`（res/values/strings.xml:87 "Install something to open this link with first"），返回 false。
- 相邻打开（:22）：`openAdjacentIfSuitable && smallestScreenWidthDp>=600 && isOpenAdjacent`（`pref_open_adjacent`，默认 true，SettingsStore.kt:392）→ `FLAG_ACTIVITY_LAUNCH_ADJACENT|NEW_TASK`。分享 chooser 显式传 false（ArticleScreen.kt:176）。
- 注意：Feed/Article 的"文章打开方式"（READER/CUSTOM_TAB/DEFAULT_BROWSER，SettingsStore.kt:865）是另一个枚举，由调用方直接选 `openLinkInCustomTab`/`openLinkInBrowser`，不经 `openLink`；`openLink` 只用于正文内链接（ArticleScreen.kt:736 → html-ui 区 HU-A31/A32）。

### 2.6 SystemUtils（F/util/SystemUtils.kt）
- `currentlyMetered`：`ConnectivityManager.isActiveNetworkMetered`，取不到服务 → false（即视为不计费）。注释强调"计费≠蜂窝"，热点可能也算计费。
- `currentlyCharging`：`BatteryManager.isCharging`。
- `currentlyConnected`：已废弃的 `getNetworkInfo(activeNetwork).isConnected`。
- 组合逻辑在 F/ui/MainActivityViewModel.kt:54-57 `isOkToSyncAutomatically()`（用于 onResume 同步，`syncOnResume`）；后台定时同步约束在 WorkManager（feed-sync 区）。
- `String.urlEncode()` = `URLEncoder.encode(this,"UTF-8")`（表单编码，空格→`+`）；用于 RssNotifications.kt:320 深链 `tag=` 与 SyncScreenViewModel.kt:229 同步密钥拼 URL。鸿蒙 `encodeURIComponent` 会把空格编码为 `%20`，深链解析端若配套解码则无影响，但跨端/二维码互通（同步加入链接）需保持兼容解码（`+` 与 `%20` 都当空格）。

### 2.7 ContextExtensions / LetterIconProvider
- `ToastMaker` 接口（:16）：`suspend makeToast(String)` / `makeToast(@StringRes)`；实现在 FeederApplication（DI）。被 ArticleViewModel、TextSettings、FeedScreen、OpmlActions、SavedArticlesImporter/Exporter 使用。
- `addDynamicShortcutToFeed(label, id, icon=null)`（:32）：见 UT-A31；`setDisabledMessage("Feed deleted")`（硬编码英文）；图标默认 `getLetterIcon(label, id, radius=iconMaxHeight)`。调用于 Repository.setCurrentFeedAndTag（feedId>ID_UNSET 时，在应用协程中）。
- `reportShortcutToFeedUsed(id)`（:96）：启动器预测用。
- 快捷方式删除逻辑（源被删时禁用/移除）不在本区（repository 区 RP-A08 已录）。
- `unicodeWrap`（:105）：`BidiFormatter.getInstance(locale).unicodeWrap(text)`——按上下文方向在文本两侧插入 LRE/RLE..PDF 或 LRM/RLM 标记；调用 ArticleScreen.kt:689（作者名）。
- `getLocale()` = `configuration.locales[0]`。
- `DEEP_LINK_HOST`/`DEEP_LINK_BASE_URI`（:109-110）；Manifest 声明 host（AndroidManifest.xml:74）。
- 字母图标颜色表 17 色但 `NUM_OF_TILE_COLORS=8`，只用前 8 色：`#e57373 #f06292 #ba68c8 #9575cd #7986cb #64b5f6 #4fc3f7 #4dd0e1`；字体 `sans-serif-light` BOLD，字号 0.8×边长。key 为 Long feedId 时 `hashCode` = `(int)(v ^ (v>>>32))`——鸿蒙复刻同色需用同一哈希。

### 2.8 FilePathProvider / PrefUtils / Time / Logging
- 目录（F/util/FilePathProvider.kt:47-52）见 UT-A37；CleanupOrphanedFilesJob 依此清理孤立文章文件。
- `PREF_MAX_ITEM_COUNT_PER_FEED="pref_max_item_count_per_feed"`，以字符串存储，SettingsStore 默认 `"100"`（SettingsStore.kt:338）。
- `Instant.minusMinutes` 仅测试使用。
- `logDebug` 仅 `BuildConfig.DEBUG` 时输出；`Either.catching` 内部也走 logDebug。

### 2.9 Either（F/util/Either.kt）
- 密封类 `Left(value)` / `Right(value)`；方法：isLeft/isRight(+predicate)、fold、swap、map、mapLeft、onRight、onLeft、getOrNull、leftOrNull；扩展：flatMap、flatten、getOrElse、merge、left()/right()、compareTo（Left<Right）、combine、widen、leftWiden、identity。
- `Either.catching(onCatch, block)`（:307）捕获 **Throwable**（含 CancellationException —— 在协程中可能吞掉取消，迁移到 ArkTS 时 try/catch 无此问题，但注意语义）。
- 鸿蒙：ArkTS 可用 discriminated union `{ kind:'left', value } | { kind:'right', value }` 等价实现；无需 contracts。

### 2.10 ui/compose/utils
- **withAllProviders**（ComposeProviders.kt:22）：提供链顺序 DI → `CommonActivityViewModel`（主题、深色偏好、动态取色、textScale、font）→ `withFoldableHinge` → `withWindowMetrics` → `withWindowSize` → `ProvideTypographySettings(fontScale, font)` → `FeederTheme` → `WithFeederTextToolbar`。5 个 Activity 共用（MainActivity、AddFeedFromShare、ManageSettings、ImportOPMLFile、FeedWidgetSettings）。鸿蒙等价：EntryAbility 级 AppStorage/@Provide 注入主题、字体、断点。
- **WindowSize.kt**：`LocalWindowSizeMetrics`（WindowSizeClass；Material3 阈值：宽 Compact<600dp、Medium<840dp；高 Compact<480dp、Medium<900dp）、`LocalWindowSize`（窗口 DpSize，`LocalConfiguration.current` 读取以在配置变化时重算）。`getScreenType`：宽 Compact→SINGLE，否则 DUAL。鸿蒙：`mediaquery`/`BreakpointSystem`（xs/sm/md/lg 阈值 320/600/840vp 与 Material 宽阈值一致，可直接映射；高度类需自行用窗口 height 计算）。
- **Foldables.kt**：取 `FoldingFeature.bounds`；`isTopToBottom = bounds.top==0`（竖直铰链）、`isLeftToRight = bounds.left==0`。仅 NavigationDrawerTokens 用于在竖铰链时调整抽屉宽度（ui-material 区）。鸿蒙：`display.getFoldDisplayMode`/`getCurrentFoldCreaseRegion` 可替代。
- **FeederTextToolbar.kt**：替换 Compose `LocalTextToolbar`；`ActionMode.TYPE_FLOATING`；固定项 id 0..3（Copy/Paste/Cut/SelectAll，标题用 android 系统字符串，`SHOW_AS_ACTION_IF_ROOM`）；文本处理器项 id 100+index（group 1，`SHOW_AS_ACTION_NEVER`，按 `ResolveInfo.DisplayNameComparator` 排序），仅当 onCopyRequested 非空时添加；点击时：保存原剪贴板 → 调 onCopy → 读剪贴板第一项文本 → `ACTION_PROCESS_TEXT`（type `text/plain`，`EXTRA_PROCESS_TEXT`，经 activityLauncher 可相邻打开）→ 恢复原剪贴板（异常仅记录，FileUriExposed）。存在的原因：Compose 默认工具栏不显示 PROCESS_TEXT 项（例如翻译 App）。
- **Focusable.kt**：`onKeyEventLikeEscape(action)`——Key.Escape/Back/NavigateOut 都触发并返回 true（注意：onKeyEvent 对 KeyDown 和 KeyUp 都会触发，原实现未区分 → action 可能被调用两次；调用方动作多为幂等的关闭）。`focusableInNonTouchMode`：触摸模式下不可聚焦，键盘/方向键模式下可聚焦（ReaderView、LinearArticleContent 正文块）。
- **MutableSavedState.kt**：`by mutableSavedStateOf(state, default, onChange)`；键=Kotlin 属性名（如 `fetchOgImages`，EditFeedScreenViewModel.kt:129 用 `state.contains("fetchOgImages")` 判断是否已有用户编辑值，避免被 DB 值覆盖）。首次 get 时从 handle 读并回调 onChange。鸿蒙：Navigation 页面参数 / `PersistentStorage` 或 Ability `onSaveState` 可替代；进程被杀恢复属于 on_device，但本卡只录 backend 结果契约（UT-A47）。
- **Permissions.kt**：`rememberApiPermissionState(permission, minimumApiLevel)`——预览模式或 SDK<min 时返回恒 Granted 的假状态。用于 POST_NOTIFICATIONS（API 33+）在 Settings/EditFeed 开通知时请求。鸿蒙：`abilityAccessCtrl.requestPermissionsFromUser`；通知授权是 `notificationManager.requestEnableNotification`，非普通权限（notifications-widget 区）。
- **ProvideScaledText.kt**：`fontSize*fontScale`、`lineHeight*fontScale`（TextUnit 为 Unspecified 时乘法结果仍 Unspecified）。
- **WindowInsets.kt**：`addMargin`/`addMarginLayout`（RTL 时 start/end 互换）；`addMarginLayout` 无引用。
- **Wrapper.kt**：StableHolder/ImmutableHolder 是 Compose 重组性能包装，无业务语义，鸿蒙不需要（ArkUI 用 @Observed/@ObjectLink 或不可变数组替换）。
- **DIUtils / LogCompositions / PreviewThemes**：无迁移价值。

---

## 3. 平台模型差异与鸿蒙映射

| 能力 | Android | 鸿蒙候选 | 差异/注意 |
|---|---|---|---|
| URL 解析 | java.net.URL/URI（协议白名单、RFC2396） | `@ohos.url` `url.URL.parseURL(input, base)`（WHATWG） | WHATWG 接受任意 scheme（`gemini://` 不报错）、对 `google.com` 无 base 时报错；需在包装层复刻 UT-A01..A07 的判定（自己做 scheme 白名单：http/https 至少） |
| query 处理 | URLDecoder/URLEncoder（表单编码） | `url.URLParams` / 手写 | `+`/`%20` 差异；UrlCleaner 二次编码怪癖 |
| HTML 解析 | Jsoup（`abs:` 属性、CSS 选择器、实体反转义） | 无内置 DOM 解析器；需三方 ArkTS HTML 解析库或自写 | html-model 区同样依赖，需统一选型；大小写不敏感属性选择、`absUrl` 需自实现 |
| HTTP | OkHttp（全局客户端、重定向、流式读取） | `@ohos.net.http`（`requestInStream` 支持流式）或 RCP | 需要拿到最终 URL（重定向后）作 base；流式提前终止读取 |
| 打开链接 | Intent ACTION_VIEW / CustomTabs / SENDTO | `startAbility` with Want（`ohos.want.action.viewData`）、`openLink`；应用内浏览用 Web 组件页 | 无 Custom Tabs；"CUSTOM_TAB" 需映射为应用内 Web 页或系统浏览器 |
| 相邻窗口 | FLAG_ACTIVITY_LAUNCH_ADJACENT | `StartOptions.windowMode`（分屏，受限）| 多数设备不可用，降级 |
| 计费网络 | isActiveNetworkMetered | `connection.getNetCapabilitiesSync` → `NET_CAPABILITY_NOT_METERED` | 语义接近 |
| 充电 | BatteryManager.isCharging | `batteryInfo.chargingStatus` | 等价 |
| 动态快捷方式 | ShortcutManager | 鸿蒙 shortcuts 主要为静态（module.json5 `shortcuts`）；动态快捷方式 API 受限 | 降级候选 |
| BiDi 包裹 | BidiFormatter | 无直接等价；手动插入 FSI(U+2068)…PDI(U+2069) | 需自实现 |
| PROCESS_TEXT | 系统 Intent 生态 | 无 | 降级候选 |
| 文本选择菜单 | ActionMode | ArkUI `Text`/`TextInput` 的 `editMenuOptions`/`bindSelectionMenu` | 可自定义菜单项，但无第三方处理器 |
| 窗口尺寸类 | WindowSizeClass | 断点系统 + `window.getWindowProperties` | 高度类需自算 |
| 折叠铰链 | FoldingFeature | `display.getCurrentFoldCreaseRegion` | 可映射 |
| 保存状态 | SavedStateHandle | `onSaveState`/`PersistentStorage`/Navigation 参数 | 进程重建语义不同 |
| 字母图标 | Bitmap+Canvas | `OffscreenCanvas` → `PixelMap` | 同色需同哈希 |

### 降级候选
1. **动态快捷方式（UT-A31/A34）**：若鸿蒙不支持运行时动态 shortcut，降级为不提供"最近源"快捷方式（或仅静态快捷方式）；字母图标随之无用途。
2. **PROCESS_TEXT 文本处理器（UT-A41）**：无等价生态，降级为系统默认选择菜单（复制/全选等）。
3. **相邻窗口打开（UT-A27）**：降级为普通启动。
4. **Custom Tabs（UT-A25 的 CUSTOM_TAB 分支）**：降级为应用内 Web 组件页（保留工具栏颜色与分享按钮）或直接系统浏览器。
5. **`Browser.EXTRA_CREATE_NEW_TAB`**：无等价，忽略。

---

## 4. 未引用/死代码（迁移可省）
- `relativeLinkIntoAbsoluteOrNullIfNotValid`（LinkUtils.kt:109）、`WindowInsets.addMarginLayout`（WindowInsets.kt:24）、`getLetterIcon` 除快捷方式外无用、`Instant.minusMinutes` 仅测试、`LogCompositions`、`PreviewThemes`、`WithAllPreviewProviders`、`DoNotUseInProd`。
- Cursor/SQLiteDatabase/ContentValues 扩展：旧 SQLite 迁移辅助，鸿蒙新库不需要（除非做 Android DB 导入）。

## 5. 风险（按严重度）
1. **URL 语义迁移**：LinkUtils 依赖 java.net 的协议白名单与 RFC2396 解析；鸿蒙 WHATWG 解析在未知 scheme、无 scheme、`host:port` 无协议等边界行为不同。FeedParser/RssLocalSync/DB 转换器大量依赖，偏差会导致订阅 URL 规整/去重/相对链接结果不同。需按 UT-A01..A09 + 测试用例做黄金测试。
2. **HTML 解析器选型**：HtmlUtils 依赖 Jsoup 的 `unescapeEntities`、`abs:src`、大小写不敏感属性选择器；鸿蒙无内置等价物，与 html-model 区共用决策。
3. **og:image 抓取**：需流式读到 `</head>` 即中断连接、拿重定向后最终 URL；`@ohos.net.http` 默认行为需验证。
4. **UrlCleaner 二次编码怪癖**：复刻或修正需明确定稿（建议修正，因为属 bug：分享出去的链接会变）。
5. **urlEncode 表单编码**：深链 `tag` 与同步密钥 URL 中空格→`+`，鸿蒙端解码需兼容 `+`，否则跨设备同步加入链接/含空格标签的通知深链会错。
6. **快捷方式/PROCESS_TEXT/相邻窗口/Custom Tabs**：平台无等价，见降级候选。
7. **字母图标颜色一致性**：依赖 Kotlin Long.hashCode，鸿蒙需复刻 `(v ^ (v >>> 32))` 截断为 int 再 abs%8（abs(Int.MIN_VALUE) 为负的极端情况可忽略）。
8. **onKeyEventLikeEscape 双触发**：未区分 KeyDown/KeyUp，鸿蒙实现建议只在 KeyUp（或 Down）触发一次，属可接受偏差。

## 6. 断言统计
- backend 38：UT-A01..A25、A28..A33、A35..A39、A47、A48
- ui 6：A40、A42、A43、A44、A45、A46
- on_device 4：A26、A27、A34、A41
- 合计 48 条。
