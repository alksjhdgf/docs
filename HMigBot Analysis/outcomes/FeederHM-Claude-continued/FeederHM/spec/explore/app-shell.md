# 探索文档：app-shell（应用壳）

区前缀：APP。断言卡：`spec/cards/app-shell.md`。
锚点前缀约定：`P` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder`，下文写全路径。

## 0. 范围与文件清单

| 文件 | 行数 | 作用 |
|---|---|---|
| input/Feeder/app/src/main/AndroidManifest.xml | 194 | 6 个 Activity、1 个 Provider、1 个 JobService、2 个 Receiver、权限 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt | 238 | Application：Kodein DI 根容器、OkHttp、Coil ImageLoader、TTS/播客状态持有者 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ApplicationCoroutineScope.kt | 9 | `Dispatchers.Default + SupervisorJob()` 全局作用域 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt | 141 | NavHost 宿主（startDestination=Feed），生命周期钩子，音量键翻页，onNewIntent 深链 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivityViewModel.kt | 58 | 滚动命令流、resume 同步判定、周期同步配置 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/NavigationDeepLinkViewModel.kt | 32 | 深链进入 Feed/Article 时写当前 feed/tag/article |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/CommonActivityViewModel.kt | 31 | 主题/暗色/动态色/文字缩放/字体 StateFlow（所有 Activity 共用） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ManageSettingsActivity.kt | 57 | MANAGE_NETWORK_USAGE 入口，直接显示 SettingsScreen |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/ImportOPMLFileActivity.kt | 78 | 打开 OPML 文件 → OpmlImportScreen |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/AddFeedFromShareActivity.kt | 91 | 分享/打开 URL → SearchFeed → AddFeed；含 `onNavigateUpFromIntentActivities()` |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt | 91 | 无界面代理：通知点击标记已读/已通知、取消通知、开浏览器/CustomTab |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivityViewModel.kt | 24 | markAsNotified / markAsReadAndNotified |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/Constants.kt | 16 | 请求码、`EXTRA_FEEDITEMS_TO_MARK_AS_NOTIFIED="items_to_mark_as_notified"`、ARG_* 常量 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt | 581 | 8 个 sealed 目的地 + 路由拼接 + QueryParamsBuilder |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ComposeProviders.kt | 70 | `withAllProviders`：DI + 主题 + 折叠屏/窗口尺寸 + 排版 + 文本工具栏 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/di/{AndroidModule,ArchModelModule,NetworkModule}.kt | 11/85/28 | Kodein 模块 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/base/{DIAwareComponentActivity,DIAwareJobService,DIAwareViewModel}.kt | 31/18/119 | DI 感知基类与 ViewModel 工厂 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/contentprovider/{RSSContentProvider,RssContentProviderContract}.kt | 90/32 | 对外只读 Provider |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/blob/Blob.kt | 42 | 文章正文 gzip 文件命名与读写 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt | 110 | `DEEP_LINK_HOST`/`DEEP_LINK_BASE_URI`、动态快捷方式 |

## 1. Manifest 事实（input/Feeder/app/src/main/AndroidManifest.xml）

- 权限：READ_EXTERNAL_STORAGE(max28)、WRITE_EXTERNAL_STORAGE(max29)、INTERNET、ACCESS_NETWORK_STATE、POST_NOTIFICATIONS、RECEIVE_BOOT_COMPLETED、RUN_USER_INITIATED_JOBS（:6-19）。
- 自定义权限 `${applicationId}.permission.read`，label `permission_read_label`="Feeder read-only access"，desc "Allows the application to read feeds and articles"（:21-24；strings.xml:220-221）。
- `<queries>`：zxing 条码扫描包、TTS_SERVICE、PROCESS_TEXT text/plain（:26-36）。
- application：`android:name=.FeederApplication`，allowBackup=true，enableOnBackInvokedCallback=true（预测性返回），localeConfig=@xml/locales_config（应用内语言），supportsRtl，usesCleartextTraffic=true（允许 http 源），memtagMode=async（:38-49）。WebView MetricsOptOut（:51-53）。
- MainActivity（:55-80）：exported，`launchMode=singleTop`，LAUNCHER；`autoVerify` VIEW 过滤 http/https + host `feederapp.nononsenseapps.com`（App Links）；`android.app.shortcuts` → res/xml-v25/shortcuts.xml（**静态快捷方式为空**：只有 `<shortcuts/>`）。
- ManageSettingsActivity（:82-90）：exported，action `android.intent.action.MANAGE_NETWORK_USAGE`（系统“流量使用→应用设置”入口），parent=MainActivity。
- ImportOPMLFileActivity（:92-113）：exported，excludeFromRecents，label `import_feeds_from_opml`="Import feeds from OPML"，theme `AppThemeDialog`（对话框样式），VIEW/SEND，scheme content，mime text/xml、application/xml、text/x-opml、application/octet-stream。
- AddFeedFromShareActivity（:115-155）：三个 filter —— (1) VIEW http/https 且 mime 为 text/xml、application/rss+xml、application/atom+xml、application/xml、application/json；(2) SEND http/https host *；(3) SEND text/plain。
- RssNotificationBroadcastReceiver（:158，非本区）。
- OpenLinkInDefaultActivity（:160-165）：exported，label `open_link_in_browser`="Open link in web browser"，`launchMode=singleInstance`，独立 taskAffinity `${applicationId}.OpenLinkTask`，无 intent-filter（只被显式 PendingIntent 启动）。
- RSSContentProvider（:168-172）：authority `${applicationId}.rssprovider`，exported，readPermission=`${applicationId}.permission.read`（无 writePermission，但写操作全部抛异常）。
- FeederJobService（:175-177）、FeedWidgetReceiver（:179-187）、FeedWidgetSettingsActivity（:189-191，exported=false）—— 非本区，仅列出。

## 2. FeederApplication 初始化

input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt
- 字段初始化（构造期即创建，非懒）：`applicationCoroutineScope`（:71）、`TTSStateHolder(this, scope)`（:72）、`PodcastPlayerStateHolder(this, scope)`（:73）。
- `di by DI.lazy { ... }`（:75-215）绑定清单（全部 singleton，除注明）：
  - `FilePathProvider`（cacheDir/filesDir）→ util/FilePathProvider.kt：articleDir=`filesDir/articles`，fullArticleDir=`cacheDir/full_articles`，httpCacheDir=`cacheDir/http`，imageCacheDir=`cacheDir/image_cache`，httpImageCacheDir=`cacheDir/http_image_cache`，fontsDir=`filesDir/fonts`（FilePathProvider.kt:47-52）。**注意：全文 HTML 放在 cache 目录，可被系统清理；摘要正文在 files 目录。**
  - `Application`、`AppDatabase.getInstance` 及 9 个 DAO（Feed、FeedItem、SyncRemote、ReadStatusSynced、RemoteReadMark、RemoteFeed、SyncDevice、Blocklist）（:80-89）。
  - import androidModule（`AndroidSystemStore`）、archModelModule（见 §5）。
  - `ContentResolver`、`JobScheduler`（:95-96）。
  - `ToastMaker`：切到 Main 线程 `Toast.LENGTH_SHORT`（:97-110）。
  - `NotificationManagerCompat`、默认 `SharedPreferences`（:111-117）。**所有设置存在默认 SharedPreferences**。
  - `OkHttpClient`：`cachingHttpClient(httpCacheDir, 200MB)` + network 拦截器顺序 UserAgent → RateLimited → ForceCacheOnSomeFailures → TooManyRequests；DEBUG 下加日志拦截器（:119-147）。
  - `ImageLoader`（Coil3）：基于上面 OkHttp 新建 builder，单独 300MB http 图片缓存；`AlwaysUseCacheIfPossibleRequestsInterceptor`；**仅 Wi-Fi 加载图片**：当 `repository.loadImageOnlyOnWifi` 为真且当前为计费网络时，请求改为 `onlyIfCached` + maxStale/maxAge=Int.MAX（无缓存则 504）（:159-178）；crossfade、maxBitmapSize 2500x2500、后台内存缓存 5%、磁盘缓存 200MB(imageCacheDir)、内存缓存 100MB、组件：OneImageRequestPerHostInterceptor、IcoDecoder（支持 .ico favicon）、OkHttpNetworkFetcher（:181-208）。
  - `ApplicationCoroutineScope`、networkModule、`TTSStateHolder`、`PodcastPlayerStateHolder`、`NotificationsWorker(di)`（:210-214）。
- `onCreate`：仅 `staticFilesDir = filesDir`（已废弃，供旧 DB 迁移 AppDatabase.kt:767 写 blob）（:217-221）。**Application.onCreate 不调度任何任务**——周期同步与孤儿文件清理在 MainActivity.onCreate 调度。
- `onTerminate`：取消全局作用域、关 TTS、关播客（:223-228）（真机上基本不会被调用）。
- `newImageLoader` 返回 DI 中的 ImageLoader（:230）。

ApplicationCoroutineScope.kt:8：`Dispatchers.Default + SupervisorJob()`。

## 3. MainActivity（页面 Main）

input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt
- 注入：`NotificationsWorker`、`MainActivityViewModel`（activity 作用域）、`Repository`（:35-37）。
- `onCreate`（:88-103）：
  1. `mainActivityViewModel.ensurePeriodicSyncConfigured()` → Repository.kt:671 `schedulePeriodicRssSync(di, replace=false)`（已存在则不替换）。
  2. `schedulePeriodicOrphanedFilesCleanup(di)`（background/CleanupOrphanedFilesJob.kt:102：若无挂起作业则调度每日、需设备空闲+充电）。
  3. `enableEdgeToEdge()`（:96）。
  4. `setContent { withAllProviders { AppContent() } }`。
- `AppContent`（:105-135）：`NavHost(startDestination = FeedDestination.route)` 注册 8 目的地顺序：Feed、Article、EditFeed、SearchFeed、AddFeed、Settings、SyncScreen、TextSettings；共享一个 `navDrawerListState`（抽屉列表滚动状态跨页保持）。
- 冷启动 intent：Navigation-Compose 的 NavHost 在首次设置图时会自动 `handleDeepLink(activity.intent)`（框架行为，源码中无显式调用）→ 冷启深链（通知、快捷方式、小组件、App Link）直接落到 Feed/Article/Sync。
- 热启动（singleTop）：`addOnNewIntentListener` → `navController.handleDeepLink(intent)`；失败仅 `Log.e("NavController rejected intent")`（:125-134），无用户提示，停留当前页。
- `onStart`/`onStop`：`notificationsWorker.runForever()`/`stopForever()`（:39-47）。runForever（notifications/NotificationsWorker.kt:31-54）在前台期间监听“需通知条目”Flow：条目从列表消失则取消对应通知，列表空则取消汇总通知；非空则仅更新汇总通知。
- `onResume`（:49-53）：`setResumeTime(Instant.now())`（SessionStore）+ `maybeRequestSync()`：
  - `shouldSyncOnResume` 是 ViewModel 构造时快照 `repository.syncOnResume.value`（MainActivityViewModel.kt:46-47；默认 false，SettingsStore.kt:238 key `pref_sync_on_resume`）——**设置改了需重建 Activity 才生效**。
  - 条件 `isOkToSyncAutomatically()` = 已联网 && (!仅充电 || 正在充电) && (!仅 Wi-Fi || 非计费网络)（MainActivityViewModel.kt:54-57）。
  - 满足则 `runOnceSyncChainGetUpdates(di)` 然后 `runOnceRssSync(forceNetwork=false, triggeredByUser=false)`（:78-83）。
- `onKeyDown`（:55-72）：当 `isPagingMode` 且 `repository.isArticleOpen` 为真时，音量上/下键被消费并发出 `ScrollDirection.UP/DOWN` 滚动命令（`MutableSharedFlow`，无 replay）；否则交给系统。
- 未使用常量：`KEY_NOTIFICATION_PERMISSION_REQUESTED`（:139）——运行时通知权限请求不在 MainActivity，在 Settings.kt:1278 与 EditFeedScreen.kt:162（他区）。

## 4. 导航路由（NavigationDestinations.kt）

路由构造（:63-89）：`path` + `/{pathParam}`… + `?q1={q1}&q2={q2}`。所有 transition 均 fadeIn/fadeOut（:48-59）。

| 目的地 | path / route | 参数 | 深链 uriPattern（BASE=`https://feederapp.nononsenseapps.com`） | navigate 行为 |
|---|---|---|---|---|
| SearchFeedDestination (:141) | `search/feed?feedUrl={feedUrl}` | feedUrl String? 默认 null | 无 | singleTop；feedUrl 为空不拼 |
| TextSettingsDestination (:192) | `font/add` | 无 | **无（emptyList）** | singleTop |
| AddFeedDestination (:221) | `add/feed/{feedUrl}?feedTitle={feedTitle}&feedImage={feedImage}` | feedUrl 必填(path, `Uri.encode`)；feedTitle/feedImage 默认 "" | 无 | singleTop；保存后 → FeedDestination.navigate(feedId) |
| EditFeedDestination (:276) | `edit/feed/{feedId}` | feedId Long | 无 | singleTop；保存后 → Feed(feedId) |
| SettingsDestination (:314) | `settings` | 无 | 无 | 返回：popBackStack 失败则 → Feed |
| FeedDestination (:353) | `feed?id={id}&tag={tag}` | id Long 默认 `ID_UNSET`(0)；tag 默认 "" | `BASE/feed?id={id}&tag={tag}` | `popUpTo(graph.id){inclusive=true}` + singleTop（清空整个返回栈）；id==ID_UNSET 时不拼 id |
| ArticleDestination (:436) | `reader/{itemId}` | itemId Long 必填（缺失则 `error()` 崩溃 :470） | `BASE/article/{itemId}` | singleTop；返回：pop 失败则 → Feed；onNavigateToFeed → Feed(feedId) |
| SyncScreenDestination (:495) | `sync?syncCode={syncCode}&secretKey={secretKey}` | 两者默认 "" | `BASE/sync/join?sync_code={syncCode}&key={secretKey}` | singleTop；空串不拼；返回：pop 失败则 → Settings |

- Feed 屏进入（:408-433）：读取 id/tag；若 `id != ID_UNSET || tag 非空` 则 `NavigationDeepLinkViewModel.setCurrentFeedAndTag` → Repository.setCurrentFeedAndTag（Repository.kt:115-135）：feedId>0 时在全局作用域添加/更新**动态快捷方式**（最多 3 个，util/ContextExtensions.kt:32-90）并 reportShortcutUsed；若与当前值不同则写 SharedPreferences `pref_last_feed_id`/`pref_last_feed_tag` 并 `setMinReadTime(now)`；再 `setIsArticleOpen(false)`。id/tag 都空时不改当前 feed —— 即**冷启不带参数显示上次打开的 feed/tag**（SettingsStore.kt:58-60 初值来自 prefs）。
- Article 屏进入（:467-491）：`setCurrentArticle(itemId)`：后台 `markAsReadAndNotified(itemId)` + 设当前文章 + `setIsArticleOpen(true)`（NavigationDeepLinkViewModel.kt:24-31）。
- 特殊 ID：`ID_UNSET=0`、`ID_ALL_FEEDS=-10`、`ID_SAVED_ARTICLES=-20`（db/room/AppDatabase.kt:30-32）。
- QueryParamsBuilder（:555-581）：值为 null/空串则跳过；值 `Uri.encode`；首个用 `?` 其后 `&`。
- 深链来源（外区写入，需本区路由兼容）：
  - 通知单篇：`BASE/article/{id}` → MainActivity（model/RssNotifications.kt:229-236，READER 或 link==null 时）。
  - 通知汇总：`BASE/feed?id={id}&tag={urlEncoded}` → 经 OpenLinkInDefaultActivity 代理（RssNotifications.kt:320-333）。
  - 小组件条目：`BASE/article/{id}`（widget/FeedWidget.kt:286）。
  - 动态快捷方式：`BASE/feed?id={id}`（ContextExtensions.kt:43）。
  - OPML 导入完成：`BASE/feed?id=-10`（ImportOPMLFileActivity.kt:52-53）。
  - 同步“添加设备”二维码/链接：`BASE/sync/join?sync_code=…&key=…`（SyncScreenViewModel.kt:233）；外部扫码打开即经 App Link 进入 MainActivity → SyncScreen。

## 5. DI 与 base（Kodein）

- archModelModule（di/ArchModelModule.kt:45-85）：singleton —— Repository、SessionStore、SettingsStore、FeedStore、FontStore、FeedItemStore、SyncRemoteStore、`OPMLParserHandler=OPMLImporter`、BergamotModelManager、BergamotWebTranslator、LocalTranslator、TranslationManager、`OpenAIApi(appLang=Locale.getDefault().getISO3Language())`、SuggestedFeedRepository（从 resources 读，Json ignoreUnknownKeys）；factory `OpenAISettings → OpenAIClientDefault`。Activity 作用域 VM：MainActivityViewModel、FeedWidgetSettingsActivityViewModel、OpenLinkInDefaultActivityViewModel、CommonActivityViewModel；Composable 作用域 VM：Settings、EditFeedScreen、CreateFeedScreen、SearchFeed、Article、Feed、NavigationDeepLink、TextSettings。
- networkModule（di/NetworkModule.kt:18-28）：provider（每次新建，因有状态）—— `JsonAdapter<Feed>`、`JsonFeedParser`、`FeedParser`；singleton —— SyncRestClient、RssLocalSync、FullTextParser。
- DIAwareComponentActivity（base/DIAwareComponentActivity.kt:15-31）：子 DI 扩展父 DI，绑定 MenuInflater、自身、`ActivityLauncher`（singleton per activity）。
- DIAwareViewModel/工厂（base/DIAwareViewModel.kt）：反射构造 `(DI, SavedStateHandle)` 优先，退回 `(DI)`；NavBackStackEntry 版本把路由 arguments 作为 defaultArgs 传入 SavedStateHandle（:110-119）——**目的地 VM 从 SavedStateHandle 读路由参数**（如 feedUrl、feedId、syncCode）。
- DIAwareJobService：同理扩展 DI（base/DIAwareJobService.kt）。
- withAllProviders（ui/compose/utils/ComposeProviders.kt:22-46）：withDI → CommonActivityViewModel（theme/darkTheme/dynamicColors/textScale/font）→ 折叠屏铰链 → 窗口度量 → 窗口尺寸类 → `ProvideTypographySettings(fontScale, font)` → `FeederTheme` → `WithFeederTextToolbar`。**所有 5 个带 UI 的 Activity 都套这一层**，故主题/字体设置对 ManageSettings/ImportOPMLFile/AddFeedFromShare 同样生效。

## 6. 各外部入口 Activity

### 6.1 ManageSettings（ui/ManageSettingsActivity.kt）
- 入口：系统 MANAGE_NETWORK_USAGE。enableEdgeToEdge（:22）。
- 直接渲染 `SettingsScreen`（与主内 Settings 同组件，VM 为 activity 级 `diAwareViewModel()`）（:26-53）。
- 返回(Up)：`onNavigateUpFromIntentActivities()` = 启动 MainActivity 并 finish（AddFeedFromShareActivity.kt:83-91）。
- 进入同步：以 `SyncScreenDestination.deepLinks.first().uriPattern` 原样（**含字面量 `{syncCode}`/`{secretKey}` 占位符**）作为 VIEW URI 启动 MainActivity 后 finish（:30-40）。Navigation 解析后 syncCode/secretKey 参数值可能为字面 "{syncCode}"（待真机确认）。
- 进入文字设置：`TextSettingsDestination.deepLinks.first()`（:41-51）——**TextSettings 的 deepLinks 是 emptyList（NavigationDestinations.kt:195），`.first()` 必抛 NoSuchElementException → 源码中从系统入口点“文字设置”会崩溃**。迁移时应改为可达实现（打开 Main 并跳 TextSettings），属源缺陷，不复刻崩溃。

### 6.2 ImportOPMLFile（ui/ImportOPMLFileActivity.kt）
- 读 `intent.data`（:29），单页 NavHost "import"（:35）→ `OpmlImportScreen(onNavigateUp, uri, onDismiss, onOk)`（ui/compose/ompl/OpmlImportScreen.kt:67-73）。
- Up → 打开 Main 并 finish；Dismiss → finish；OK → 以 `BASE/feed?id=-10`（全部订阅）VIEW + NEW_TASK 启动 MainActivity 再 finish（:51-66）。
- 注意：SEND 动作的 OPML 只取 `intent.data`，未读 `EXTRA_STREAM`；SEND 时 uri 可能为 null（源行为）。
- 对话框主题 + excludeFromRecents。

### 6.3 AddFeedFromShare（ui/AddFeedFromShareActivity.kt）
- `initialFeedUrl = (intent.dataString ?: EXTRA_TEXT)?.trim()`（:29-30）。
- NavHost start="search"：SearchFeedScreen(initialFeedUrl)，点结果 → AddFeedDestination.navigate(url,title,feedImage)（:35-58）；Up → 打开 Main + finish。
- "add/feed/…" 页：CreateFeedScreen，Up → popBackStack 回搜索，保存(onOk) → `finish()`（不跳 Main）（:59-76）。

### 6.4 OpenLinkInDefault（ui/OpenLinkInDefaultActivity.kt，无 UI）
- 无 setContent、不 enableEdgeToEdge；onCreate 末尾必 `finish()`（:58）。
- 分支 A（:35-51）：`uri.host == feederapp.nononsenseapps.com && lastPathSegment == "feed"`（汇总通知）：取 `items_to_mark_as_notified` long 数组 → 后台 `markAsNotified(ids)`（只标“已通知”，不标已读）；然后以同 uri VIEW 启动 MainActivity（openAdjacentIfSuitable=false）。
- 分支 B（:61-90）：uri 形如 `content://<authority>/feed_items/{id}?link=…`（db/Uri.kt:17 `URI_FEEDITEMS`）：id=lastPathSegment（解析失败 → 抛异常；null → ID_UNSET）；`lifecycleScope.launch { markAsReadAndNotified(id); cancelNotification(id) }`；link 非空时：action==`com.nononsenseapps.feeder.OPEN_IN_CUSTOM_TAB` → CustomTab（toolbar 颜色 R.color.primary），否则默认浏览器；异常 → Toast `no_activity_for_link`="Install something to open this link with first"。
- 风险：markAsReadAndNotified 跑在 lifecycleScope，紧接 finish() 后作用域被取消，写库可能未完成（源竞态）；分支 A 的 viewModelScope 同理。迁移应保证写库完成（用应用级作用域）。
- singleInstance + 独立 taskAffinity：不污染主任务栈。

## 7. RSSContentProvider（对外接口）

contentprovider/RSSContentProvider.kt + RssContentProviderContract.kt
- authority `${applicationId}.rssprovider`（BuildConfig.APPLICATION_ID），读权限 `${applicationId}.permission.read`。
- URI：
  - `content://<auth>/feeds` → `FeedDao.loadFeedsForContentProvider()`：`SELECT id, title FROM feeds ORDER BY title`（db/room/FeedDao.kt:117-124）；type `vnd.android.cursor.dir/vnd.rssprovider.feeds`。
  - `content://<auth>/articles` → `SELECT id, title, plain_snippet AS text FROM feed_items WHERE block_time IS NULL ORDER BY primary_sort_time DESC, pub_date DESC`（FeedItemDao.kt:115-123）；type `vnd.android.cursor.dir/vnd.rssprovider.items`。
  - `content://<auth>/articles/#` → 同上加 `feed_id = #`（**# 是 feed id 不是 article id**）（FeedItemDao.kt:125-134）；type `vnd.android.cursor.item/vnd.rssprovider.item`（命名误导，实为某 feed 的文章列表）。
  - 其它 → query 返回 null，getType 返回 null。
- projection/selection/sortOrder 参数全部被忽略（:70-82）。
- insert/update/delete 均 `throw UnsupportedOperationException("Not implemented")`。
- DI 取自 `applicationContext as FeederApplication`。
- 鸿蒙：对应 DataShareExtensionAbility（需 system/签名级权限才能被三方访问，三方普通应用通常无法跨应用读）——降级候选。

## 8. Blob（blob/Blob.kt）

- 摘要正文：`<dir>/<itemId>.txt.gz`，gzip（:10-25）；dir=articleDir(`filesDir/articles`)。
- 全文：`<dir>/<itemId>.full.html.gz`，gzip（:27-42）；dir=fullArticleDir(`cacheDir/full_articles`)。
- 写方：RssLocalSync.kt:404（同步时写摘要正文）、FullTextParser.kt:148（全文）、AppDatabase.kt:767（旧迁移，写到 filesDir 根）；读方：ArticleViewModel、FeedViewModel；清理：CleanupOrphanedFilesJob.kt:48-51（删除无对应 feed_item 的文件）。
- 迁移约束：文件名格式与 gzip 编码是同步/阅读/清理三方的共同契约；鸿蒙可用 zlib（@ohos.zlib gzip）或自定义，需三方一致。

## 9. 平台模型差异与鸿蒙映射

| 源机制 | 结果契约 | 鸿蒙实现建议 | 差异 |
|---|---|---|---|
| Application + Kodein DI | 进程级单例容器（DB、HTTP、ImageLoader、Store） | AbilityStage.onCreate / 模块级单例 + 手写 ServiceLocator | 无 Kodein；构造期创建 TTS/播客需改为懒加载 |
| MainActivity singleTop + NavHost | 单任务内单实例，新深链复用并导航 | EntryAbility launchType=singleton；onNewWant → Navigation(NavPathStack) | 需自写 URI→路由解析（无 navDeepLink） |
| App Links autoVerify `feederapp.nononsenseapps.com` | 点击该域名链接直接进应用 | module.json5 skills uris + `domainVerify`（App Linking） | 需域名服务器配置 applinking.json，否则只能作为可选打开方式 |
| 外部 Activity（ManageSettings/ImportOPML/AddFeedFromShare） | 各自独立入口 | 同一 UIAbility 多 skill（按 action/uri/type 分派）或多 UIAbility | MANAGE_NETWORK_USAGE 无鸿蒙等价 → 降级 |
| SEND text/plain / http URL | 从别的应用分享进来 | skills `ohos.want.action.sendData` + uris type `text/plain`；或系统分享面板 Share Kit 目标 | 字段 key 不同（EXTRA_TEXT → want.parameters） |
| OPML VIEW content:// | 文件管理器打开 .opml | skills `ohos.want.action.viewData` + type `text/xml` 等；fileUri 读 | content URI → file URI 授权 |
| OpenLinkInDefault（无 UI 代理） | 点通知→标记→开浏览器 | 通知 WantAgent 直接指向 EntryAbility 带参，在 onNewWant 内处理后 `startAbility` 浏览器；或 WantAgent→CommonEvent 订阅者 | 无透明 Activity；需不闪现主界面的实现 |
| CustomTab | 应用内浏览器标签 | 系统浏览器或 ArkWeb 内嵌页 | 无 CustomTab 等价 |
| ContentProvider exported + 自定义读权限 | 三方应用可只读查询 feeds/articles | DataShareExtensionAbility | 三方应用 DataShare 受限 → 降级候选 |
| 动态快捷方式（最多 3） | 桌面长按图标出现最近 feed | 无运行时动态快捷方式 API（仅 module.json5 静态 shortcuts） → 降级 | |
| 音量键翻页 | 阅读页音量键滚动 | KeyEvent（onKeyEvent，KEYCODE_VOLUME_UP/DOWN）在页面根节点拦截 | 音量键是否可被应用拦截需真机验证 |
| onStart/onStop runForever | 前台期间同步通知状态 | UIAbility onForeground/onBackground | 一致 |
| JobScheduler 周期同步/清理 | 后台定时 | WorkScheduler（WorkSchedulerExtensionAbility，最短 2h 间隔、需充电/空闲条件） | 间隔与保活差异 |
| enableEdgeToEdge | 内容不被状态栏遮挡 | `setWindowLayoutFullScreen(true)` + avoidArea 顶部 padding | 一致 |
| enableOnBackInvokedCallback | 预测性返回 | Navigation 返回 / onBackPress | 无动画契约 |
| localeConfig 应用内语言 | 每应用语言 | `i18n.System`/`I18NUtil` 应用偏好语言 `setAppPreferredLanguage` | 可行 |

## 10. 降级候选

1. ManageSettings 入口（Android 系统 MANAGE_NETWORK_USAGE 意图）：鸿蒙无系统“应用流量设置”跳入点 → 页面保留但入口不可从系统触达（可留作内部路由）。
2. RSSContentProvider 对外只读接口：鸿蒙 DataShare 对三方非系统应用基本不可用 → 可实现 DataShareExtension 但无法真机验证跨应用读；建议降级为不提供。
3. 动态桌面快捷方式（ContextExtensions.addDynamicShortcutToFeed）：无运行时 API → 降级（静态 shortcuts 源本身为空）。
4. App Links autoVerify：需服务端 applinking 配置，无法自证 → 降级为 deep link 路由解析 + skills uris 声明。
5. CustomTab（ACTION_OPEN_IN_CUSTOM_TAB）：降级为系统浏览器或 ArkWeb 页。
6. OpenLinkInDefault 的 singleInstance/独立 taskAffinity 透明代理：降级为在 EntryAbility.onNewWant 里处理（可能短暂前台化）。
7. zxing 条码扫描 queries（外部包）：鸿蒙用 ScanKit 替代（他区）。

## 11. 源缺陷/易错点（迁移时须知，不要复刻崩溃）

- ManageSettingsActivity.kt:45：`TextSettingsDestination.deepLinks.first()` 对空列表 → NoSuchElementException 崩溃。
- ManageSettingsActivity.kt:34：把含 `{…}` 占位符的 uriPattern 当实际 URI 发出。
- MainActivityViewModel.kt:46：`shouldSyncOnResume` 是构造时快照。
- OpenLinkInDefaultActivity.kt:62：lastPathSegment `toLong()` 非数字会抛异常（只来自内部 PendingIntent，实际安全）。
- OpenLinkInDefaultActivity.kt:65 / OpenLinkInDefaultActivityViewModel.kt:16：后台写库在 finish 后的作用域里，可能被取消。
- ArticleDestination 缺 itemId → `error()`（NavigationDestinations.kt:470）。
- RSS Provider `articles/#` 的 # 是 feedId；item MIME 命名误导。
- 全文 blob 在 cacheDir，被系统清理后需重新抓取（ArticleViewModel 有 isFile 检查兜底）。

## 12. Compose 布局结构（本区页面）

- Main：无自有布局，仅 NavHost 容器；首帧 = FeedScreen（他区）。
- ManageSettings：= SettingsScreen 整页（他区 settings 定义布局/文案）。
- ImportOPMLFile：= OpmlImportScreen（他区 ompl）；外壳为对话框主题 Activity。
- AddFeedFromShare：= SearchFeedScreen → CreateFeedScreen（他区 searchfeed/editfeed）。
- OpenLinkInDefault：无 UI；唯一可见输出是失败 Toast `no_activity_for_link`。
- 所有带 UI 的页面经 withAllProviders 套 FeederTheme（主题/暗色/动态色/字号/字体）。
