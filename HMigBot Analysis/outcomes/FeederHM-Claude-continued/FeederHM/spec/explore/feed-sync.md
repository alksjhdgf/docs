# 探索：feed-sync（订阅源刷新域）

前缀 P = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/`。断言卡：`spec/cards/feed-sync.md`（FS-A01..A56，共 56 条：ui 0 / backend 53 / on_device 3）。

> 更正任务描述："WorkManager 定期同步、开机/网络约束"与源码不符。源码**不使用 WorkManager**，而是直接用 `android.app.job.JobScheduler` 加单个 `FeederJobService`（Manifest `.background.FeederJobService`，`BIND_JOB_SERVICE`）。开机后恢复调度靠 `setPersisted(true)`，配合 Manifest 中的 `RECEIVE_BOOT_COMPLETED` 权限（AndroidManifest.xml:18）；源码中**没有开机广播接收器**。

## 1. 文件清单与职责

| 文件 | 行数 | 职责 |
|---|---|---|
| P/model/RssLocalSync.kt | 601 | 同步主流程：互斥、选源、并发、HTTP 获取、解析、条目 upsert、过滤、去重、og:image、站点图标、保留裁剪 |
| P/model/FeedParser.kt | 585 | 站点元数据（alternate feed 链接、图标）、feed 抓取与解析（交给 gofeed 原生库）、`OkHttpClient.getResponse/curl/curlAndOnResponse` 扩展、`FeedParserError` 错误族 |
| P/model/RateLimiter.kt | 73 | 按 key（主机）限速，每秒最多 3 次 |
| P/model/RateLimitedInterceptor.kt | 19 | 网络拦截器，按 host 调用 `RateLimiter.blockingRateLimited` |
| P/model/TooManyRequestsInterceptor.kt | 56 | 429 处理：在 Retry-After 窗口内对该主机改为只用缓存 |
| P/model/ForceCacheOnSomeFailuresInterceptor.kt | 32 | 没有 cache-control 的 4xx 响应强制缓存 1h |
| P/model/UserAgentInterceptor.kt | 25 | 固定 UA |
| P/model/AlwaysUseCacheIfPossibleRequestsInterceptor.kt | 25 | 图片客户端请求：max-stale 30d / max-age 7d |
| P/model/OneImageRequestPerHostInterceptor.kt | 55 | Coil 拦截器：按主机散列为 8 个 Mutex 串行加载 |
| P/model/ArticleFilterRules.kt | 259 | 每源 block/allow 规则（仿 Miniflux） |
| P/model/ThumbnailImage.kt / ThumbnailImagePolicy.kt | 115 / 49 | 缩略图模型（kotlinx.serialization 多态）与优先级策略 |
| P/model/PreviewItem.kt | 81 | 列表预览投影（Room 查询列 `PREVIEW_COLUMNS`） |
| P/model/FeedUnreadCount.kt | 21 | 抽屉条目：id/display_title/tag/image_url/unread_count/expanded |
| P/model/Parsed{Feed,Article,Author,Enclosure}.kt | — | JSON-Feed 风格的中间模型（字段名带下划线） |
| P/model/SiteMetaData.kt | 17 | `SiteMetaData(url, alternateFeedLinks: List<AlternateLink(link,type)>, feedImage)` |
| P/model/OPMLParserHandler.kt | 14 | 接口：saveFeed / saveSetting / saveBlocklistPatterns（实现属 feed-parser/opml 区） |
| P/background/*.kt | 10 个文件 | JobScheduler 任务：RSS_SYNC(1)、RSS_SYNC_PERIODIC(2)、FULL_TEXT_SYNC(3)、SYNC_CHAIN_GET_UPDATES(4)、SYNC_CHAIN_SEND_READ(5)、BLOCKLIST_UPDATE(6)、CLEANUP_ORPHANED_FILES(7)（BackgroundJobId.kt:5） |

本区依赖、但归其他区的部分：gofeed 原生解析（feed-parser 区：`gofeedandroid.Gofeedandroid.parseBodyBytes`，GoFeedAdapter.kt:28）、FullTextParser（html-model）、`notify()`（notifications-widget：P/model/RssNotifications.kt:56）、SyncRestClient（sync）、DAO SQL（db）、设置项（settings-store）。

## 2. 同步主流程 RssLocalSync.syncFeeds

1. 取 `syncMutex`，在 `singleThreadedSync`（单线程 Executor）上运行；`setSyncWorkerRunning(true/false)` 包在 try/finally 中（RssLocalSync.kt:62-89）。源码注释明确要求流程内部不得切换派发器（:50）。
2. `downloadTime = Instant.now()`，本次所有新条目共用（:103）。
3. 计算 staleTime（:108-119）：
   - `debugReallyForceNetwork`（仅测试用）：now+1 天；
   - `forceNetwork`：now-1 分钟（注释：绝不在 1 分钟内重复请求服务器）；
   - 其余情况：now - max(minFeedAgeMinutes,1) 分钟。`RssSyncJob` 读取 extras `min_feed_age_minutes`，默认 5；`runOnceRssSync` 从不设置这个 extra，所以实际**总是 5 分钟**（RssSyncJob.kt:46）。
4. 同步链预处理：`getFeeds/getRead/getDevices/sendUpdatedFeeds/markAsRead`，异常被吞掉（:121-129）。
5. `feedsToSync`（:512-557）对应的 DAO（P/db/room/FeedDao.kt:51-115）：
   - 单源：`id IS :feedId AND last_sync < :staleTime AND retry_after < :now`；
   - 按 tag：`tag IS :tag AND ... ORDER BY last_sync`；
   - 全部：`... ORDER BY last_sync`。
   - staleTime<=0 时走不带 last_sync 条件的版本（内部使用）。
6. `needFullTextSync = feedsToFetch.any { fullTextByDefault }`。
7. 并发：`concurrentJobs = 2`，在同一线程上开 2 个协程，按 index%2 分片，只并发 IO 等待（:141-161）。
8. 全部完成后执行 `repository.applyRemoteReadMarks()`（:164）；finally 中如需全文则调用 `runOnceFullTextSync(triggeredByUser=false)`（:174）。
9. 返回值：outer try 走完为 true，否则 false（RssSyncJob 忽略该返回值）。

### 2.1 handleFeed（:186-236）
- 先 `setCurrentlySyncingOn(id, true, lastSync = now)`，即**开始时就写 last_sync**，失败也算已同步过（测试 `feedShouldNotBeUpdatedIfRequestFails` 断言 lastSync ≠ EPOCH）。
- Left 且为 `HttpError` 带 retryAfterSeconds 时：`setRetryAfterForFeedsWithBaseUrl(host, now+秒)`，SQL 为 `UPDATE feeds SET retry_after=:t WHERE url LIKE '%'||:host||'%' AND retry_after < :t`（FeedDao.kt:280-292），同主机的所有源一并延后（测试 `feedsGetRetryAfterSetAndWillNotSyncLater`）。
- Right 时：`setBlockStatusForNewInFeed(feedId, syncTime)` 用全局屏蔽词表标记新条目（FeedItemStore.kt:51，参数 applyBlocklistToSummaries/Links）。
- finally：`currently_syncing=false`。

### 2.2 syncFeed（:238-510）
- 重新执行 `syncLoadFeed(feedId, retryAfter=now)`，因为 retry_after 可能在同步中途被同主机的其他源改掉，为 null 就跳过（:246-252），之后再检查一次 retryAfter（:257）。
- `okHttpClient.getResponse(url, forceNetwork)` 的结果分三类：成功且有 body 时调用 `feedParser.parseFeedResponse(response.request.url.toUrl(), body)`，用的是**重定向后的 URL**；成功但无 body 返回 NoBody；非成功返回 HttpError(code, message, retryAfterSeconds)。
- `Response.retryAfterSeconds`：取所有 `retry-after` 头的最大值，非数字按 3600（:596-601）。注意：HTTP-date 格式的 Retry-After 会被当成 3600。
- 解析成功后：
  - `isNotUniqueIds`：本 feed 内 `items.map{id}.toSet().size != items.size`（:301-303）。
  - `alreadyReadGuids = getGuidsWhichAreSyncedAsReadInFeed(feed.url)`（远端已读标记）。
  - `ArticleFilterRules.compile(blockRules, allowRules)`，每源每次同步只编译一次。
  - guid：`isNotUniqueIds || feedSql.alternateId` 为真时用 alternateId，否则用 `id ?: alternateId`。**alternateId = `"$id|${content_text.hashCode()}|${title.hashCode()}"`**，其中 id 为 null 时字面就是字符串 "null"；hashCode 是 Java String.hashCode，对 null 调用 `.hashCode()` 返回 0（Kotlin `Any?.hashCode()`）（:593-594）。
  - 列表反转（feed 惯例是新的在前），从最旧的开始处理，`fallbackClock = downloadTime - (total-1-index) 秒`（:352）。
  - 过滤放在 mapIndexedNotNull 内部，**不改变** isNotUniqueIds 与 index/total（:335-346 注释）。
  - 查找已有条目：先 `loadFeedItem(alternateId, feedId)`，再 `loadFeedItem(id ?: alternateId, feedId)`，都没有则 `FeedItem(firstSyncedTime=downloadTime)`。
  - 去重：仅对新条目（id==ID_UNSET）且 `skipDuplicates` 开启时生效，SQL：`exists(select id from feed_items where id <> :id and (plain_title=:t or link=:l) and plain_title<>'' and link is not null and link<>'')`（FeedItemDao.kt:553-566）。**不限源，是全库范围**。
  - `updateFromParsedEntry`（P/db/room/FeedItem.kt:132-181）：wordCount 由 HtmlToPlainTextConverter 转换后估算；snippet = (summary ?: content_text ?: plainText).take(200)；plainTitle take 200（MAX_TITLE_LENGTH/MAX_SNIPPET_LENGTH=200，FeedItem.kt:44-45）；thumbnail 走 `ThumbnailImagePolicy.applyParsedEntryImage`；enclosure 取首个；author 用条目的，缺失用 feed 的；pubDate 用 `ZonedDateTime.parse(date_published)`，失败时保留旧值，没有旧值则为 `now(fallbackClock)`；`primarySortTime = min(firstSyncedTime, pubDate)`。注意 **date_modified 不参与**。
  - fetchOgImages：`resolveThumbnailImage`，调用 `OkHttpClient.fetchOgImage`（P/util/HtmlUtils.kt:130，`Accept: text/html`，非 2xx 抛异常，只流式读取 head，上限 MAX_HEAD_BYTES=65536）。
  - 远端已读：readTime ?: now，notified=true；upsert 后 `setSynced(id)`。
  - `upsertFeedItems`（FeedItemDao.kt:580-606）：先批量 update 已有条目，再批量 insert 新条目，然后逐条执行 block，写 blob（`blobOutputStream(id, articleDir)`）。
  - 站点图标：`imageUrl == null && siteFetched == EPOCH` 时，抓取 home_page_url 的根地址 `URL(protocol, host, port, "")`，用 getSiteMetaData 取 feedImage（:416-437）。
  - 源字段：`title = feed.title ?: title`；没有 auth 参数且没有 query 参数时，`url = feed.feed_url`（重定向后的 URL）；`imageUrl = feed.icon ?: imageUrl`；然后 `upsertFeed`。
  - 裁剪：`getItemsToBeCleanedFromFeed(feedId, keepCount=max(maxFeedItemCount, items.size))`，SQL：`SELECT id FROM feed_items WHERE feed_id IS :feedId AND bookmarked = 0 ORDER BY primary_sort_time DESC, pub_date DESC LIMIT -1 OFFSET :keepCount`（FeedItemDao.kt:62-71）。再排除 presentIds 与 `currentArticleId`；删除 blob 与 full blob 文件后 `deleteFeedItems`，并执行 `deleteStaleRemoteReadMarks(now)`。
  - 已知局限（源码注释 :466-471）：feed 缩小或用户调低上限后，仍在 feed 中但被规则过滤掉的条目可能被裁剪。

## 3. FeedParser（HTTP 与发现）

- `getSiteMetaData(url)` = `curl(url)` 后接 `getSiteMetaDataInHtml`：
  - 不含 `<head>`（忽略大小写）时返回 `NotHTML`。
  - alternate：`rel=alternate`，同时有 href 和 type，type 小写后含 `application/atom` 或 `application/rss`，或**恰好等于** `application/json`；能转成绝对 URL 才保留（:111-181）。
  - 没有 alternate 且 host 为 `www.youtube.com`/`youtube.com` 时，用 body 中第一个 `data-channel-external-id` 拼出 `https://www.youtube.com/feeds/videos.xml?channel_id=` 链接，type 为 "atom"。
  - 图标：依次查 `apple-touch-icon`、`icon`、`shortcut icon`（rel 精确匹配），取第一个有 href 的，转为绝对 URL（:81-106）。
  - 使用方：SearchFeedViewModel.kt:51,78,83；RssLocalSync.kt:428。
- `parseFeedUrl(url)`：curlAndOnResponse 后 parseFeedResponse，并把 `feed_url` 覆盖为原始输入 URL（保留认证信息和 token）。
- `parseFeedResponse(url, ResponseBody)`：按 Content-Type 决定是否解析（见 FS-A19），用**原始字节**交给 gofeed，字符集由 gofeed（Go）自行处理（XML 声明 / BOM）。`curl()` 用 `body.string()`，由 OkHttp 按 BOM 和 Content-Type charset 解码，默认 UTF-8。
- `GoFeed.asFeed(url)`：home_page_url 由 link 转绝对 URL；**feed_url 固定为请求 URL**，不采用 feedLink（:289 注释）；icon = image.url 转绝对 URL；items 经 FeederGoItem 转换（字段规则见 feed-parser 区）。`hasFeedImage = thumbnail?.fromBody == false`。
- `getResponse`（:336-404）：forceNetwork 时设 `CacheControl.maxAge(1 min)`；URL userInfo 按 `:` 切分并 URLDecoder 解码后生成 `Credentials.basic`，挂到 `authenticator`（401）和 `proxyAuthenticator`（407）上，已有对应头时返回 null（不重试）；请求在 IO 派发器上同步 execute。
- 错误族 `FeedParserError`（Parcelable sealed）：NotInitializedYet、FetchError、NotHTML、MetaDataParseError、RSSParseError、JsonFeedParseError、NoAlternateFeeds、HttpError(code,message,retryAfterSeconds; description="$code: $message")、UnsupportedContentType(mimeType)、NoBody、NoUrl、FullTextDecodingFailure、FullTextTooLarge(maxBytes; "Response body exceeded N bytes")（:479-585）。SearchFeed 与 EditFeed 页面会把这些错误展示给用户（归 edit-search 区）。

## 4. HTTP 客户端拼装（P/FeederApplication.kt:119-205；P/../jsonfeed/JsonFeedParser.kt:14-42）

- 主客户端 `cachingHttpClient(httpCacheDir, 200MB)`：connect 和 read 超时各 30s，`followRedirects(true)`，**`trustAllCerts=true` 为默认值**：TrustManager 不做任何校验，`hostnameVerifier { true }`（P/../jsonfeed/OkHttpBuilderExtensions.kt:12-36）。也就是说所有 HTTPS 证书都被接受。
- 网络拦截器顺序：UserAgent → RateLimited → ForceCacheOnSomeFailures → TooManyRequests；DEBUG 下另加日志应用拦截器。
- 图片客户端 = 主客户端 `newBuilder()`（继承上述网络拦截器），另设独立 Cache(httpImageCacheDir, 300MB)，加应用拦截器 AlwaysUseCacheIfPossible 和"仅 Wi‑Fi 图片"拦截器（`!loadImageOnlyOnWifi || currentlyUnmetered` 时正常请求，否则 onlyIfCached，无缓存时返回 504）。
- Coil ImageLoader：crossfade、maxBitmapSize 2500x2500、磁盘缓存 imageCacheDir 200MB、内存缓存 100MB、后台时内存占比 5%、组件 OneImageRequestPerHostInterceptor + IcoDecoder + OkHttpNetworkFetcher。

### 拦截器的细节事实（实现时需要知道）
- RateLimiter：`DELAY_MS = 1000/3 = 333`；超限时 sleep 时长为 `Random.nextLong(remain, remain*2)`；`cleanOldEntries()` 删除 `value < now - 60` 的条目，**单位是毫秒**（看起来本意是 60 秒）。结果是：只要两次同主机请求之间有任何请求完成（会触发清理），超过 60ms 的记录就被删掉，实际限速比"每秒 3 次"宽松得多。鸿蒙实现建议按本意（同主机间隔不少于 333ms）实现；对用户可见的结果不变。
- RateLimitedInterceptor 用 `Thread.sleep` 阻塞 OkHttp 调用线程。
- TooManyRequestsInterceptor 是**网络拦截器**，所以它设置的 `onlyIfCached` 只作为请求头发往服务器，不会触发 OkHttp 的缓存短路（缓存层在网络拦截器上游）。实际效果存疑（PLAUSIBLE），卡片 FS-A17 按代码意图写成契约。注释说是"for Coil"，但它挂在主客户端上，对 feed 请求同样生效。
- ForceCacheOnSomeFailures：没有 cache-control 的 4xx（包括 429、404 favicon）缓存 3600s。这会让 1 小时内对同一 URL 的请求直接命中 4xx 缓存（forceNetwork 的 max-age=60 会绕过）。
- OneImageRequestPerHost：锁 key 为 `host.hashCode() % 8`，可能为负，实际最多 15 个分桶；只处理 data 为 String 且以 "http" 开头的请求。

## 5. 文章过滤规则（ArticleFilterRules.kt）
- 字段：Title、URL、Author、Tag、Content（大小写不敏感）。Miniflux 的 EntryDate/EntryCommentsURL 不支持。
- 解析：逐行 trim（同时去掉 CRLF 的 \r），只按第一个 `=` 切分，字段和模式各自 trim；错误类型 MissingSeparator / UnknownField(fieldName) / EmptyPattern / InvalidRegex(reason) / TooManyRules(lineNumber, 100)；行号从 1 开始。
- EditFeed/AddFeed 页面只显示第一条错误（`ArticleRuleSet.parse(value).errors.firstOrNull()`，EditFeedScreenViewModel.kt:59/62，CreateFeedScreenViewModel.kt:53-54）。错误文案归 edit-search 区。
- 匹配：`Regex.containsMatchIn`；超过 100_000 字时使用 region + transparentBounds + 非 anchoringBounds。**这是 Java regex 语义**，ArkTS 的 RegExp（JS 语义）在 lookbehind、`(?i)` 内联标志、possessive 量词、`\p{}` 等写法上与 Java 不同，需要做方言兼容或文档化（风险）。
- 单测：`app/src/test/.../model/ArticleFilterRulesTest.kt`；集成测试：androidTest RssLocalSyncKtTest.kt:922-1075（block 优先、allow 仅保留匹配项、被屏蔽条目不写 blob、规则新增前的条目不删、无效规则不影响 feed）。

## 6. 缩略图（ThumbnailImage.kt / Policy）
- 存储在 `feed_items.image_url` 列（COL_IMAGEURL），值是 kotlinx.serialization 多态 JSON，鉴别字段名为 `type`（默认 classDiscriminator），值为 `ImageFromHTML`/`EnclosureImage`/`MediaImage`。数据库序列化格式归 db 区 Converters，迁移时需保持兼容。
- equals 只比较 url、width、height（EnclosureImage 不比较 length）。
- FeederGoItem.thumbnail 的选择（GoFeedExtensions.kt）：feedThumbnail 在 media/扩展/image enclosure 中取宽度最大者；若是 EnclosureImage 且 length 为 0 或大于 50000，或宽度 ≥ 640，直接采用；否则优先 bodyThumbnail（正文首图），没有再用 feedThumbnail。

## 7. PreviewItem / FeedUnreadCount
- `PREVIEW_COLUMNS`（PreviewItem.kt:19-26）是列表、小组件分页查询的列集合；`feedDisplayTitle = customTitle.ifBlank{title}`；`domain = (enclosureLink ?: link).host`；`bestWordCount` 在 fullTextByDefault 时取 wordCountFull。
- 使用方：FeedItemDao.pagingPreviews / widgetPreviewsByFeed；FeedItemStore.toFeedListItem（FeedItemStore.kt:362）。
- FeedUnreadCount 由 NavDrawer 分页使用（FeedViewModel.kt:94）。

## 8. 后台任务（background/）

| 任务 | 调度函数 | 约束 | 备注 |
|---|---|---|---|
| RSS_SYNC(1) | `runOnceRssSync(di, feedId, feedTag, forceNetwork, triggeredByUser)` RssSyncJob.kt:67 | 非 force 且仅 Wi‑Fi 时为 UNMETERED，否则 ANY；Android 14+ 且用户触发时 `setUserInitiated(true)` | 固定 job id，重复 schedule 会替换（JobScheduler 语义：同 id 的任务若正在运行会被停止，属平台语义，未在源码中验证） |
| RSS_SYNC_PERIODIC(2) | `schedulePeriodicRssSync(di, replace)` :108 | 充电（设置）、UNMETERED/ANY、setPeriodic(freq)、persisted | freq<1（MANUAL=-1）时 cancel；replace=false 时只在不存在时 schedule |
| FULL_TEXT_SYNC(3) | `runOnceFullTextSync(di, triggeredByUser)` FullTextSyncJob.kt:40 | 非用户触发时：充电 + UNMETERED/ANY；用户触发时无约束 + userInitiated | 执行 `FullTextParser.parseFullArticlesForMissing()` |
| SYNC_CHAIN_GET_UPDATES(4) | `runOnceSyncChainGetUpdates` | 充电/网络 | 只在同步链已配置时调度；执行 getRead → applyRemoteReadMarks → getDevices |
| SYNC_CHAIN_SEND_READ(5) | `runOnceSyncChainSendRead` | 充电/网络 + minLatency 10s | 已有待执行任务时不再调度 |
| BLOCKLIST_UPDATE(6) | `runOnceBlocklistUpdate` | NETWORK_TYPE_NONE + minLatency 1ms | extras：only_new / feed_id |
| CLEANUP_ORPHANED_FILES(7) | `schedulePeriodicOrphanedFilesCleanup` | deviceIdle + charging + 1 天周期 + persisted | MainActivity.onCreate 调用 |

- `FeederJobService`（FeederJobService.kt）：按 jobId 分派；在 `BackgroundCoroutineScope`（Dispatchers.Default + SupervisorJob）中 launch，完成后 `jobFinished(params,false)`；onStopJob 时 cancel 协程并返回 false（不重排）；Android 14+ 的用户触发任务调用 `setNotification(SYNC_NOTIFICATION_ID=42623, ..., JOB_END_NOTIFICATION_POLICY_REMOVE)`。
- 同步通知（background/Notifications.kt）：渠道 `feederSyncNotifications`，名称和描述为 `R.string.sync_status`="Sync status"，IMPORTANCE_LOW；内容标题为 `R.string.syncing`="Syncing"；group 为 `com.nononsenseapps.feeder.SYNC`；ongoing；图标 `ic_stat_sync`。
- RssSyncJob.doWork：读取 extras（feed_id、feed_tag、force_network、min_feed_age_minutes=5），finally 中调用 `notify(appContext)`（新条目通知，需要 POST_NOTIFICATIONS 权限）。

### 调用方清单（谁触发同步）
- 下拉刷新当前源/标签：FeedViewModel.requestImmediateSyncOfCurrentFeedOrTag（FeedViewModel.kt:179）→ force=true，user=true。
- 刷新全部：requestImmediateSyncOfAll（:190）→ force=true，user=true。
- 新建源：CreateFeedScreenViewModel.kt:118 → 只同步该 feedId，user=false；编辑源：EditFeedScreenViewModel.kt:177 同样。
- OPML 导入：OpmlActions.kt:83 → 全量，user=true。
- 加入同步链成功：SyncScreenViewModel.kt:111 → 全量，user=false。
- 文章正文 blob 缺失时的兜底：ArticleViewModel.kt:365 → 该源，force，user。
- 首次启动添加 "Feeder News"（`https://news.nononsenseapps.com/index.atom`）后同步：Repository.kt:77-92。
- 前台恢复：MainActivity.onResume → maybeRequestSync（MainActivity.kt:49-85）：`syncOnResume`（默认 false），且 `currentlyConnected && (!onlyCharging || charging) && (!onlyWifi || unmetered)` 时调用 runOnceSyncChainGetUpdates + runOnceRssSync(force=false, user=false)。
- 周期：MainActivity.onCreate → ensurePeriodicSyncConfigured（replace=false）；SettingsStore 中 setSyncOnlyOnWifi/setSyncOnlyWhenCharging/setSyncFrequency 调用 replace=true（SettingsStore.kt:252/262/524）。
- SyncFrequency 枚举（SettingsStore.kt:878）：MANUAL(-1)、15、30、60、180、360、720、1440；默认 "60"（PREF_SYNC_FREQ）。

## 9. 测试向量（可迁移为鸿蒙单测/集成测）
- androidTest/model/RssLocalSyncKtTest.kt：cowboy JSON/Atom 同步、NixOS 重复 guid（99 条，guid 以 `https://nixos.org/news.html|` 开头）、无日期条目生成互不相同且递减的时间、按 15 分钟阈值跳过、force 绕过、429 + Retry-After:30 对同主机两个源都生效、500 后 lastSync 仍更新、裁剪不少于 feed 实际条数、在 feed 中的条目不删、当前选中文章不删、远端已读应用并 setSynced、过滤规则 7 例。
- androidTest/model/FeedsToSyncTest.kt：陈旧/新鲜 × 单源/全部/标签。
- test/model/RssLocalSyncThumbnailPolicyTest.kt、ArticleFilterRulesTest.kt。

## 10. 鸿蒙映射与平台差异

| 源能力 | 鸿蒙实现建议 | 差异/注意 |
|---|---|---|
| Mutex + 单线程派发器 | ArkTS 主线程 async + 自写异步互斥（Promise 链）；或把同步放到 TaskPool/Worker 中单例运行 | ArkTS 单线程事件循环，2 路"并发"天然只是交错 IO，与源语义一致；DB 与文件 IO 需用异步 API |
| OkHttp + 磁盘 HTTP 缓存 + 条件请求 | `@kit.RemoteCommunicationKit`(rcp) 支持拦截器和缓存配置；或 `@kit.NetworkKit` http（usingCache） | FS-A11/A16/A17/A21 依赖 HTTP 缓存语义（max-age、max-stale、only-if-cached）；NetworkKit http 的缓存可控性很弱，rcp 更合适，否则需要自研 ETag/Last-Modified 缓存层 |
| Basic 认证（userinfo） | rcp `authentication` 或在请求时直接设置 `Authorization` 头 | 源是"收到质询后才发"，直接预发更简单，但会改变线上行为（凭据随首个请求发出） |
| trustAllCerts | rcp `security.remoteValidation: 'skip'` 可实现；NetworkKit http 有 `remoteValidation` / caPath | 安全风险，见 §11 |
| JobScheduler 周期任务 | WorkSchedulerExtensionAbility（`workScheduler.startWork`，repeatCycleTime，networkType WIFI/ANY，chargerType，isPersisted，isDeepIdle） | 鸿蒙周期最小 20 分钟（以 SDK .d.ts 为准，需核实），15 分钟档可能无法满足；扩展进程执行时长受限，长同步可能被杀 |
| 用户触发的一次性同步 + 前台通知 | 应用在前台时直接在进程内执行；退到后台继续用短时任务 `backgroundTaskManager.requestSuspendDelay` 或长时任务 DATA_TRANSFER + 通知 | Android 14 以下源也不显示通知，FS-A51 为 on_device |
| 开机恢复 | WorkScheduler `isPersisted: true` | 无需开机广播；feasibility.json 已把"开机自启"列为降级 |
| Coil 图片管线 | ArkUI Image 自带缓存 + 自研下载器/拦截（ImageKnife 三方库可选） | 单主机串行、仅 Wi‑Fi 只用缓存需要自定义加载器 |
| Jsoup 查 link/meta | 自研 HTML tokenizer（feasibility 已裁定自研） | 只需 `<link rel>`、`data-channel-external-id`、og:image 的 head 扫描 |
| Java regex（过滤规则） | ArkTS RegExp | 方言差异（见 §5） |
| String.hashCode（alternateId） | 必须手写 Java 32 位 hashCode（UTF-16 码元，`h=31*h+c`，int 溢出） | 见风险 |

### 降级候选
1. 15 分钟同步档：鸿蒙 WorkScheduler 最小周期如高于 15 分钟（需按 SDK 核实），则按最小值执行，或隐藏该选项。
2. Android 14 的 user-initiated job 通知：鸿蒙前台同步无需通知；后台只在申请长时任务时显示。
3. TooManyRequests 的"仅缓存"语义：若 rcp 无 only-if-cached，则在窗口期内直接返回失败（不发请求）。
4. 图片按主机串行：可降级为全局并发上限。
5. trustAllCerts：建议默认改为正常校验，对自签名证书源给出错误提示（属行为变化，需裁定）。

## 11. Top 风险
1. **alternateId 跨端一致性**：guid 依赖 Java `String.hashCode()` 和 HtmlToPlainTextConverter 输出的 content_text。Feeder Sync 用 (feed_url, guid) 交换已读标记（getGuidsWhichAreSyncedAsReadInFeed），鸿蒙版若与 Android 设备组成同步链，哈希和纯文本转换必须逐位一致，否则已读不同步、条目重复。
2. **解析器替换**：gofeed（Go）由自研 ArkTS 解析器替代，id/link/guid 的绝对化与 published 格式（`publishedParsed` 字符串需能被 ZonedDateTime.parse 解析）决定增量和去重是否正确（归 feed-parser 区，但本区直接受影响）。
3. **HTTP 缓存语义**：forceNetwork 用 max-age=60、4xx 强制缓存 1h、图片 max-stale 30d 都依赖标准 HTTP 缓存；鸿蒙 http 模块缓存能力有限，需要 rcp 或自研。
4. **trustAllCerts + 关闭主机名校验**：源对所有 HTTPS 不做校验。照搬会有 MITM 风险且可能过不了审核；不照搬则自签名源会失败。需要裁定。
5. **后台执行限制**：WorkScheduler 扩展的时长和频率限制可能让大订阅量同步被中断；源用 last_sync 先写的方式，中断后的源要等 5 分钟后才会重试。
6. **Java regex 方言**（过滤规则可由 OPML/同步导入，跨端规则文本相同但语义不同）。
7. retry_after 用 `url LIKE %host%` 子串匹配，会误伤 URL 中包含该主机名的其他源，鸿蒙需照搬才能保持行为一致。
8. RateLimiter 毫秒单位的 bug 与 TooManyRequests 网络拦截器层级问题：照搬"意图"还是"实际行为"需要统一口径（卡片按意图写）。
