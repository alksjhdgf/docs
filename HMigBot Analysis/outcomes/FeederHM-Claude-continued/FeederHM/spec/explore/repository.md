# 探索文档：repository（仓储层 archmodel）

源根：`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/`（下文简写 `…/feeder/`）。
本区覆盖：`archmodel/Repository.kt`(986 行)、`FeedItemStore.kt`(393)、`FeedStore.kt`(167)、`SyncRemoteStore.kt`(134)、`SessionStore.kt`(45)、`AndroidSystemStore.kt`(24)、`Errors.kt`(9)、`FontStore.kt`(163)。
SettingsStore（998 行）属 settings-store 区，本区仅记录 Repository 对其的组合/副作用逻辑；DAO SQL 属 db 区，本区只引用决定行为语义的 SQL。

## 1. 架构与生命周期

- Kodein DI，全部为 **singleton**：`di/ArchModelModule.kt:47-53`（Repository、SessionStore、SettingsStore、FeedStore、FontStore、FeedItemStore、SyncRemoteStore），`di/AndroidModule.kt:10`（AndroidSystemStore）。
- Repository 是 UI/ViewModel/后台作业访问数据的唯一门面（"single source of truth"）。消费者（grep `Repository by instance`）：MainActivity / MainActivityViewModel / CommonActivityViewModel / NavigationDeepLinkViewModel / OpenLinkInDefaultActivityViewModel / FeedViewModel / ArticleViewModel / SearchFeedViewModel / CreateFeedScreenViewModel / EditFeedScreenViewModel / SettingsViewModel / TextSettingsViewModel / SyncScreenViewModel / FeedWidget / 后台 BlocklistUpdateJob、FullTextSyncJob、RssSyncJob、SyncChainGetUpdatesJob、SyncChainSendReadJob、NotificationsWorker / model RssLocalSync、RssNotifications、FullTextParser、TranslationManager / sync SyncRestClient / util ActivityLauncher。
- 数据流：几乎所有读取以 Kotlin `StateFlow`/`Flow` 暴露（Room Flow 自动失效刷新），列表用 AndroidX Paging3 `PagingData`。写操作为 `suspend fun`。
- 鸿蒙映射建议：Repository → 单例 TS 类（AppStorage/自建 Observable）；StateFlow → `@ObservedV2/@Trace` 或订阅回调；Room Flow → RDB + `on('dataChange')` 或写后手动通知；Paging3 → LazyForEach + IDataSource 分页加载。

### 1.1 Repository 构造副作用（init）
`archmodel/Repository.kt:72-94`：若 `settingsStore.addedFeederNews == false`，在 ApplicationCoroutineScope 中：
1. `feedStore.upsertFeed(Feed(title="Feeder News", url="https://news.nononsenseapps.com/index.atom"))`
2. `setAddedFeederNews(true)`（持久化 SharedPreferences `PREF_ADDED_FEEDER_NEWS`，SettingsStore.kt:39-45）
3. `runOnceRssSync(feedId, triggeredByUser=false)` 立即同步此源。
=> 首次安装后订阅列表含 "Feeder News" 一项并被拉取；以后即使用户删除也不会再加回。

## 2. 特殊 ID 常量
`db/room/AppDatabase.kt:30-32`：`ID_UNSET=0`、`ID_ALL_FEEDS=-10`、`ID_SAVED_ARTICLES=-20`。
“当前源+标签”是 `Pair<Long,String>`：
- feedId>0 → 单个源；feedId==ID_UNSET 且 tag 非空 → 标签；ID_ALL_FEEDS 或 (ID_UNSET 且 tag 空) → 全部；ID_SAVED_ARTICLES → 已收藏。
- FeedStore 还为标签生成 UI id：从 -1000 起递减（-1001,-1002…），同一进程内对同一 tag 稳定（`FeedStore.kt:25-35`；目前仅定义，grep 未见 Repository 使用）。

## 3. 会话态（SessionStore，纯内存，不持久）
`archmodel/SessionStore.kt`
- `resumeTime: StateFlow<Instant>` 初值 EPOCH；Activity 回前台时设置，供 Compose 触发“恢复时动作”（如 syncOnResume）。
- `expandedTags: StateFlow<Set<String>>` 初值空；`toggleTagExpansion(tag)` 存在则移除否则加入（:27-35）。抽屉标签展开状态**冷启后丢失**。
- `syncWorkerRunning: StateFlow<Boolean>` 初值 false。

## 4. minReadTime 机制（核心语义，迁移必须复刻）
- `SettingsStore.minReadTime` 初值 `Instant.now()`，**按设计从不落盘**（SettingsStore.kt:47-56）。
- 列表“未读”过滤并非 `read_time is null` 那么简单：当 filter 包含 recentlyRead 时条件为 `read_time is null or read_time >= minReadTime`，于是**本次会话内刚读过的条目仍保留在列表中**，直到 minReadTime 前移。
- minReadTime 前移时机：
  - `setCurrentFeedAndTag` 实际变化时（SettingsStore 返回 true）→ `setMinReadTime(now)`（Repository.kt:132-134）。
  - `markAllAsReadInFeedOrTag` 结束 → `setMinReadTime(now)`（:607）。
  - 进程重启（初值=启动时刻）。
- 已收藏视图 (ID_SAVED_ARTICLES) 的 minReadTime 固定替换为 EPOCH（:424-428，:462-466）。
- `markAsReadAndNotified(itemId, readTimeBeforeMinReadTime=true)`（FeedViewModel.kt:157 的滑动标记已读使用）：若 minReadTime>EPOCH，用 `minReadTime-1s` **覆盖** read_time（`markAsReadAndNotifiedAndOverwriteReadTime`），使条目立刻从当前列表消失；否则普通标已读（coalesce，保留已有 read_time）（Repository.kt:509-525）。

## 5. 列表查询（FeedItemStore.rawQueryFilter，FeedItemStore.kt:130-180）
WHERE 组成：
1. 总是 `block_time is null`（被屏蔽词屏蔽的条目永不显示）。
2. 非收藏视图时追加 `AND ( … )`：
   - filter.unread && !recentlyRead && !read → `read_time is null`
   - 否则 `(read_time is null or read_time >= ?)`，参数为 filter.read ? EPOCH : minReadTime
   - filter.saved → 追加 `OR (bookmarked = 1)`
3. 范围（when 优先级）：
   - search 非空 → `plain_title LIKE %s% OR plain_snippet LIKE %s%`，对 `\` `%` `_` 做转义（注意：**search 非空时忽略 feedId/tag 范围，以及收藏视图的 bookmarked=1 约束**——收藏视图下搜索会跨全部条目，只是状态过滤段被跳过）。
   - ID_SAVED_ARTICLES → `AND bookmarked = 1`
   - feedId>0 → `AND feed_id IS ?`
   - tag 非空 → `AND tag IS ?`（tag 来自 LEFT JOIN feeds）
   - 其余 → 无范围（全部）
   - 注：SQL 中 LIKE 未写 `ESCAPE '\'` 子句（:172-173），SQLite 默认无转义字符，转义可能实际无效——迁移时按“字面匹配”意图实现。
- 排序：`primary_sort_time DESC, pub_date DESC, feed_items.id DESC`（newestFirst）或全 ASC（`db/room/FeedItemDao.kt:573-576`）。
- 分页：`PagingConfig(pageSize=10, initialLoadSize=100, prefetchDistance=100, jumpThreshold=100)`（FeedItemStore.kt:98-105）。
- 计数 `getFeedItemCountRaw`：同 WHERE 的 `count(*)`；`getUnreadCount(feedId, tag)` 用 `minReadTime=now`、空 filter（emptyFeedListFilter）、空 search（Repository.kt:104-113）。
- `getCurrentFeedListItems()` = combine(currentFeedAndTag, minReadTime, currentSorting, feedListFilter, search) → flatMapLatest 重新分页（:412-442）。
- `getCurrentFeedListVisibleItemCount()` 同上但不含排序（:451-479）。
- PreviewItem→FeedListItem（:362-377）：`unread = readTime==null`，`pubDate` 格式化：发布日（本地时区）>= 今天 → 系统时间格式（如 14:05），否则系统 medium 日期格式；null → ""（:379-393）。`wordCount=bestWordCount`。

### 5.1 过滤开关联动（Repository.kt:181-199）
- `setFeedListFilterRecentlyRead(false)` → 同时 `read=false`。
- `setFeedListFilterRead(true)` → 同时 `recentlyRead=true`。
- `setFeedListFilterSaved` 无联动。

### 5.2 小组件列表
`getWidgetFeedListItems`（FeedItemStore.kt:79-88）：收藏 / 单源 / 标签 / 全部，四条固定 SQL，均 `block_time IS NULL`、DESC、`LIMIT 50`（FeedItemDao.kt:162-211），**不按已读过滤、不受 filter/sorting 影响**。由 `currentWidgetFeedAndTag` 驱动（Repository.kt:445-448），消费者 widget/FeedWidget.kt:146。

## 6. 已读/收藏/通知写操作

| Repository API | 行为 | 后续副作用 | 锚点 |
|---|---|---|---|
| markAsReadAndNotified(id, beforeMin) | read_time=coalesce(read_time,now)，notified=1（或覆盖，见 §4） | runOnceSyncChainSendRead | Repository.kt:509-525 |
| markAsUnread(id) | read_time=null（**notified 不变**） | syncRemoteStore.setNotSynced(id)：删 read_status_synced 行 | :527-530, FeedItemDao.kt:355 |
| setBookmarked(id,b) | bookmarked=b | 无 | :495-498 |
| markAsNotified(ids) | notified=1 | 无 | :500 |
| markAllAsReadInFeedOrTag(feedId,tag) | feedId>0→该源；tag 非空→该标签；否则全部。read_time=coalesce(..,now)，notified=1。**不考虑 block/filter/search；收藏视图(-20)也走“全部”分支** | runOnceSyncChainSendRead；minReadTime=now | :597-608, FeedItemDao.kt:330-353 |
| markBeforeAsRead(cursor,feedId,tag) | 对与当前列表同样过滤(filter/search/minReadTime)的集合中，“列表中位于 cursor 之上”的条目标已读+notified | runOnceSyncChainSendRead | :610-625 |
| markAfterAsRead(cursor,…) | “位于 cursor 之下”的条目 | 同上 | :627-642 |
| remoteMarkAsRead(feedUrl,guid) | 总是插入 remote_read_mark；若本地有该条目→setSynced + 标已读 | 无 | :681-692 |

markBefore/After 细节（FeedItemStore.kt:182-248）：`descending = (NEWEST_FIRST != sorting)`（Before）/`(NEWEST_FIRST == sorting)`（After）；游标比较为三元组展开 `(primary_sort_time, pub_date, id)` 严格小于/大于（不含游标本身）；以原生 `execSQL` 执行（Room 不支持可写 RawQuery），之后 `invalidationTracker.refreshVersionsAsync()` 通知 Flow 刷新——鸿蒙 RDB 需写后手动通知。

## 7. 订阅源/标签操作

- `getFeed(id)` / `getFeed(url)`（`SELECT * FROM feeds WHERE url IS :url`）/ `saveFeed(feed)`：id>0 → update 返回原 id；否则 insert 返回新 id（FeedStore.kt:41-47）。
- `upsertFeed(feed)`：@Upsert；捕获 SQLiteConstraintException（url 唯一约束）时若 id==ID_UNSET，按 url 查已有 id 再 upsert；否则重抛（FeedStore.kt:108-124）。
- `deleteFeeds(ids)`：删除行（条目级联由 db 区确认）→ 移除这些 id 的动态快捷方式 → 若当前选中源在其中，切换到 (ID_ALL_FEEDS, "")（Repository.kt:589-595）。
- `deleteFeed(url)`：仅删行（同步链用），**不清快捷方式、不改当前选中**（:768-770）。
- `renameTag(old,new)`：`UPDATE feeds SET tag=new WHERE tag IS old`；若当前选中的是该标签 (ID_UNSET, old) → 切到 (ID_UNSET, new)（:144-153）。
- `toggleNotifications(feedId, v)`：`UPDATE feeds SET notify`（FeedDao.kt:165）。
- `allTags`：`SELECT DISTINCT tag FROM feeds ORDER BY tag COLLATE NOCASE`（含空串 tag）（FeedDao.kt:49-50）。
- `feedNotificationSettings` = feedDao.loadFlowOfFeedsForSettings。
- `getCurrentlyVisibleFeedTitles()`：按当前选中返回单源/标签/全部的 FeedTitle 列表，按 title NOCASE 排序（FeedStore.kt:84-92）。
- `setRetryAfterForFeedsWithBaseUrl(host, t)`：`url LIKE %host%` 且现值更早时才更新（只延后不提前）（FeedDao.kt:276-284）。
- syncLoadFeed*：按 `retry_after < :retryAfter`（以及 IfStale 版 `last_sync < :staleTime`）挑选待同步源，`ORDER BY last_sync`（FeedDao.kt:52-112）。
- `setCurrentlySyncingOn(feedId, syncing, lastSync?)`：lastSync 非空时同时写 last_sync。

### 7.1 抽屉（导航）分页
`getPagedNavDrawerItems()` = expandedTags.flatMapLatest → `feedDao.getPagedNavDrawerItems(expandedTags)`，PagingConfig(10/50/50/50)（FeedStore.kt:71-82）。SQL（FeedDao.kt:132-163）union 四段并 `order by sort_section, tag, sort_tag_or_feed, display_title collate nocase`：
- section0：全部（id=-10，unread=sum(unread)）
- section1：已收藏（id=-20，计数=sum(bookmarked)，仅当存在收藏行 `where bookmarked`）
- section2：每个非空 tag 一行（id=0，display_title=tag，unread 求和，expanded=tag∈expandedTags）；以及属于**已展开** tag 的源行（sort_tag_or_feed=1 排在其标签行后）
- section3：无标签的源
- `getUnreadBookmarksCount`：收藏视图、EPOCH、空 filter 的计数。因 rawQueryFilter 在收藏视图跳过已读条件，结果实为**未被屏蔽的收藏总数**（不论已读与否），名称有误导（Repository.kt:651-659；FeedItemStore.kt:138-143,176）。

## 8. 标题栏 ScreenTitle
两个实现，**类型判定不同**（迁移须保留差异或明确取哪种）：
- `getScreenTitleForCurrentFeedOrTag()`（Repository.kt:567-587，主界面用）：title = feedId>0 ? 源 displayTitle : tag 非空 ? tag : null；type：tag 非空→TAG；feedId∈{0,-10}→ALL_FEEDS；-20→SAVED_ARTICLES；否则 FEED。unreadCount = getUnreadCount(feedId, tag)。
- `getScreenTitleForFeedOrTag(feedId, tag)`（:544-564）：type 按 feedId：0→TAG、-10→ALL_FEEDS、-20→SAVED_ARTICLES、else FEED（feedId=0 且 tag 空会被判为 TAG）。grep 未见 Repository 以外调用。
- unreadCount 计算使用 minReadTime=now，filter 空 → 不在 saved 视图时条件 `(read_time is null or read_time >= now)`，近似纯未读数。

## 9. 当前文章 / 打开方式
- `currentArticleId` 持久化（SettingsStore.kt:112-115）；`currentArticle: Flow<Article>`、`getArticleFlow(id)`、`getCurrentArticle()`。
- `Article` 包装（Repository.kt:947-976）：item 为 null 时 id=ID_UNSET，title/snippet/feedDisplayTitle=""，enclosure.present=false 等默认值；enclosure 由 enclosureLink 非空决定；`Enclosure.isImage = type.startsWith("image/")`。
- `getArticleOpener(itemId)`（:536-542）：读该条目所属源 `feeds.open_articles_with`：`"2"`→DEFAULT_BROWSER，`"3"`→CUSTOM_TAB，`"0"`→READER，其他（含 `""`、null、`"1"` WebView 旧值）→全局 `itemOpener`。注意与 SettingsStore.itemOpenerFromString（`"1"`→CUSTOM_TAB）不同。
- `shouldDisplayFullTextForItemByDefault(id)` = feeds.fulltext_by_default ?: false。
- `getLink(id)`。
- `TextToDisplay` 枚举：CONTENT, LOADING_FULLTEXT, FAILED_TO_LOAD_FULLTEXT, FAILED_MISSING_BODY, FAILED_MISSING_LINK, FAILED_NOT_HTML, FAILED_FULLTEXT_TOO_LARGE（:978-986）。
- `FeedType` 枚举 FEED/TAG/SAVED_ARTICLES/ALL_FEEDS；`ScreenTitle(title?, type, unreadCount)`。

## 10. 选中源 setCurrentFeedAndTag（Repository.kt:115-135）
- feedId>0 时异步：添加/更新动态快捷方式（label=源 displayTitle 或 ""，id 字符串，intent=`https://feederapp.nononsenseapps.com/feed?id=<id>` 指向 MainActivity），并 reportShortcutUsed（`util/ContextExtensions.kt:32-103`）。已有 → update；新建且当前数 ≥ min(maxShortcutCountPerActivity,3) → 先按 rank 排序移除最后一个。异常吞掉。
- 持久化到 SharedPreferences（PREF_LAST_FEED_ID / tag），冷启恢复。
- 变化时 minReadTime=now。
- `setCurrentWidgetFeedAndTag` 只持久化，不动快捷方式/minReadTime。

## 11. 屏蔽词（blocklist）
- `addBlocklistPattern` / `removeBlocklistPattern` / `setApplyBlocklistToSummaries` / `setApplyBlocklistToLinks` 均在写设置后 `runOnceBlocklistUpdate(di)`（JobScheduler，无网络要求、minLatency 1ms，`background/BlocklistUpdateJob.kt:58-78`）重算全部条目 block_time。
- `setBlockStatusForNewInFeed(feedId, blockTime)`：同步时对新条目按当前 applyToSummaries/applyToLinks 设置屏蔽（RssLocalSync.kt:222 调用）。

## 12. 同步（RSS 本地同步辅助）
- `currentlySyncing: Flow<Boolean>` = `MAX(feeds.last_sync)` 在 10 秒内（Repository.kt:403-409；FeedDao.kt:208-216 注释：不按 currently_syncing 过滤以避免指示器闪烁）。注意 mapLatest 只在 DB 变化时重算，10 秒后不会自动变 false，需另有数据变化触发。
- `ensurePeriodicSyncConfigured()` → `schedulePeriodicRssSync(replace=false)`；syncFrequency.minutes<1 时取消周期任务（RssSyncJob.kt:108-125）。MainActivity.kt:91 冷启调用。
- 其余（upsertFeedItems / loadFeedItem / getItemsToBeCleanedFromFeed / deleteFeedItems / updateWordCountFull / duplicateStoryExists / getFeedsItemsWithDefaultFullTextNeedingDownload / markAsFullTextDownloaded / getFeedItemsNeedingNotifying）是后台同步/全文/通知区的透传：
  - cleanup：`feed_id IS :feedId AND bookmarked = 0 ORDER BY primary_sort_time DESC, pub_date DESC LIMIT -1 OFFSET keepCount` → **收藏条目永不被清理**（FeedItemDao.kt:60-68）。
  - duplicationExists：存在 id≠自身 且 (plain_title 相同 或 link 相同)，且 plain_title 非空、link 非空（FeedItemDao.kt:553-562）。
  - 需通知：`feeds.notify=1 AND notified=0 AND read_time null AND block_time null`（FeedItemDao.kt:529-538）。
  - 默认全文待下载：`fulltext_by_default=1 AND fulltext_downloaded<>1 AND block_time null`（:460-470）。

## 13. 跨设备同步链（Feeder Sync，实验性）
SyncRemoteStore（`archmodel/SyncRemoteStore.kt`）
- `getSyncRemote()`：读 id=1 行；不存在则创建默认（deviceName=generateDeviceName() 由 Build.MANUFACTURER/MODEL 组成，secretKey=AesCbcWithIntegrity.generateKey().toString()）并插入（:33-39,108-117）。
- `replaceWithDefaultSyncRemote()`：删除后插入新默认（deviceName=Build.PRODUCT/MODEL/BRAND，新密钥）（SyncRemoteDao.kt:61-70）——用于离开同步链。
- read_status_synced：`setSynced(itemId)` 插入（IGNORE 冲突）；`setNotSynced` 删除；`getFeedItemsWithoutSyncedReadMark` = 已读且未同步，id DESC。
- remote_read_mark：`addRemoteReadMark` 插入（IGNORE）timestamp=now；`deleteStaleRemoteReadMarks(now)` 删 7 天前；`getRemoteReadMarksReadyToBeApplied` 匹配 guid+feed url 且本地未读；`deleteRemoteReadMarksForReadItems` 删除本地已读对应标记（防止覆盖用户“标为未读”）。
- Repository.applyRemoteReadMarks（:741-752）：取待应用 → 标已读 → 逐个 setSynced → 删已应用 → 删已读条目对应的残留标记。
- 设备/远端订阅：`getDevices` Flow、`replaceDevices`、`getRemotelySeenFeeds`、`replaceRemoteFeedsWith`。
- 网络（SyncRestClient，属 sync 区）：`joinSyncChain(code,key)` 成功后拉设备列表；`startNewSyncChain()` 成功后 updateDeviceList 并返回 (syncCode, secretKey)；`leaveSyncChain` / `removeDevice` 失败仅 Log.e，不向 UI 报错；`isSyncChainConfigured` = feederSync!=null && secretKey!=null（SyncRestClient.kt:44-48）。
- `runOnceSyncChainSendRead`：同步链未配置时直接 return（SyncChainSendReadJob.kt:52-59）；配置时按 syncOnlyWhenCharging / syncOnlyOnWifi 约束调度 JobScheduler。

## 14. 字体（FontStore + Errors）
- 字体目录 `filesDir/fonts`；拷贝中转 `cacheDir`（util/FilePathProvider.kt:25,52）。
- `fontOptions: StateFlow<List<FontSelection>>` = 字体目录下所有 `.ttf` 中 **可解析** 的 UserFont（path=文件名，min/max weight/italic 来自 TrueType 变体轴，缺省 0f）+ SystemDefault + RobotoFlex（顺序：用户字体在前）（FontStore.kt:35-56）。
- `addFont(uri)`：取 OpenableColumns.DISPLAY_NAME 作文件名（无则异常 "No filename"）；目标已存在 → 异常 "File already exists"；复制到 cache → parseTrueTypeFont 校验失败则删 cache 并异常 "Error parsing font file"；成功则复制到 fonts 目录、刷新 fontOptions（FontStore.kt:58-114）。注：只校验内容可解析，不校验扩展名；但列表只收 `.ttf` 结尾 → 非 .ttf 文件名的字体添加成功后不会出现在列表中（但会被设为当前字体）。
- Repository.addFont（Repository.kt:309-321）：`Either.catching` → 成功则 `setFont(userFont)` 设为当前；失败返回 `AddFontError(cause)`。
- Repository.removeFont（:323-337）：仅对 UserFont 生效：先 `setFont(defaultFont)`（defaultFont=RobotoFlex，SettingsStore.kt:998），再删文件、刷新列表；对内置字体是 no-op 返回 Right。失败 → `RemoveFontError`。
- FontSelection 路径：RobotoFlex `bundled/roboto_flex`、SystemDefault `system/default`（ui/compose/settings/TextSettingsViewModel.kt:169-187）。

## 15. 设置透传
Repository 对 SettingsStore 的绝大部分 StateFlow + setter 为一对一透传（theme、darkTheme、sorting、showFab、feedItemStyle、swipeAsRead、syncOnResume、syncOnlyOnWifi、syncOnlyWhenCharging、loadImageOnlyOnWifi、showThumbnails、useDetectLanguage、useDynamicTheme、textScale、font、maximumCountPerFeed、itemOpener、linkOpener、useInAppAudioPlayer、syncFrequency、openAI、translationApi、preferredTranslationLanguage、translateArticlePreviewsByDefault、translateArticlesByDefault、showTitleUnreadCount、openDrawerOnFab、forceSingleColumn、openAdjacent、isPagingMode、isAnimatedPaging、showReadingTime、isArticleOpen、isMarkAsReadOnScroll、showOnlyTitle）。
仅有的逻辑：`setMaxLines(v)` → `coerceAtLeast(1)`（Repository.kt:169-171）；过滤联动（§5.1）；blocklist 触发作业（§11）。键/默认值归 settings-store 区。
`search: MutableStateFlow<String>` 在 Repository 内存中（:201-203），不持久。

## 16. AndroidSystemStore
仅 `removeDynamicShortcuts(feedIds)`：ShortcutManager 移除 id 字符串（AndroidSystemStore.kt:20-23）。

## 17. 平台差异与鸿蒙实现要点
- 协程/Flow：结果契约是“数据变化后订阅者看到新值”。鸿蒙：RDB 写后发事件 / @Trace 状态；差异：Room 自动失效追踪，鸿蒙需在每个写 API 后手动刷新相关查询（包括 markAsReadRaw 这类原生 SQL）。
- Paging3：鸿蒙 LazyForEach + IDataSource，按 10/100 分页；结果契约只要求列表完整、顺序正确、过滤正确。
- JobScheduler（runOnceRssSync/BlocklistUpdate/SyncChainSendRead/schedulePeriodicRssSync）：鸿蒙一次性任务可直接在 TaskPool 执行；周期同步用 WorkScheduler（最小间隔 2h 限制，Android 15 分钟起）。
- 动态快捷方式（ShortcutManager）：鸿蒙无运行时动态 shortcuts 等价 API（仅 module.json5 静态 shortcuts）。
- ContentResolver + OpenableColumns 取字体文件名：鸿蒙用 DocumentViewPicker 返回 uri + fileIo 读取，文件名从 uri 末段解析。
- TrueType 解析（truetype/ 包）需移植以获取变体轴；鸿蒙 `font.registerFont` 注册自定义字体。
- Build.MANUFACTURER/MODEL → `deviceInfo.manufacture/productModel`。
- AesCbcWithIntegrity 密钥 → cryptoFramework。
- `DateFormat.getTimeFormat/getMediumDateFormat`（跟随系统 12/24h 与区域）→ `Intl.DateTimeFormat` / i18n。

## 18. 降级候选
- 动态快捷方式（选中源时加入、删源时移除、reportShortcutUsed）：鸿蒙无动态 shortcut API → 降级为不实现或静态快捷方式。
- 周期 RSS 同步频率 <2h 的选项：WorkScheduler 最小间隔限制。
- JobScheduler 的“仅充电/仅 WiFi”约束对一次性 SyncChainSendRead：鸿蒙一次性 TaskPool 无约束，需自行检测网络/充电状态或用 WorkScheduler。
- 用户字体中可变字体轴（weight/italic 范围）在 ArkUI 中的可用性待验证。

## 19. 已发现的可疑行为（照搬或明确决策）
- search 非空时忽略当前源/标签/收藏范围（全局搜索）。
- LIKE 转义无 ESCAPE 子句。
- markAllAsReadInFeedOrTag 在收藏视图下会将**全部**条目标已读。
- currentlySyncing 10 秒窗口不会自行超时。
- getArticleOpener 对 `"1"` 回落全局，与 itemOpenerFromString 不一致。
- 测试参考：`input/Feeder/app/src/test/java/com/nononsenseapps/feeder/archmodel/{RepositoryTest,FeedItemStoreTest,FeedStoreTest,SessionStoreTest,SyncRemoteStoreTest}.kt`。
