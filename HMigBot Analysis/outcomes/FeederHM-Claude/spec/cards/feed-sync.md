# 订阅源刷新域卡（feed-sync）

## 域: 同步入口与并发

- FS-A01 [backend] 同一时刻只运行一次同步：`RssLocalSync.syncFeeds` 先取全局互斥锁 `syncMutex`，并在单线程派发器上执行；同步开始时将 `syncWorkerRunning` 置 true，结束时（finally）置 false。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:71
- FS-A02 [backend] 每次同步的 `maxFeedItemCount` 取设置 `maximumCountPerFeed`（默认 "100"）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:79
- FS-A03 [backend] 抓取订阅源前先执行同步链：依次调用 `getFeeds`、`getRead`、`getDevices`、`sendUpdatedFeeds`、`markAsRead`；其中任何一步抛出异常都只记日志，RSS 抓取照常继续。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:121
- FS-A04 [backend] 待同步源的选择：feedId>0 时只同步该源；否则 tag 非空时同步该 tag 下的所有源；两者都没有时同步全部源。所有分支都排除 `retry_after >= now` 的源，列表按 `last_sync` 升序。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:512
- FS-A05 [backend] 陈旧判定：非强制同步时只同步 `last_sync < now - max(minFeedAgeMinutes,1) 分钟` 的源（job 默认 5 分钟）；forceNetwork 时阈值为 now-1 分钟；在 1 分钟内同步过的源即使强制刷新也不会再请求。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:108
- FS-A06 [backend] 多个源由 2 个协程交错处理（按下标 mod 2 分配），互不阻塞；单个源失败（异常或 Left）不影响其他源。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:141
- FS-A07 [backend] 所有源处理完毕后执行 `applyRemoteReadMarks`：把已就绪的远端已读标记应用为本地已读，把这些条目标为已同步，再删除已应用的标记，并清理指向已读条目的标记。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:741
- FS-A08 [backend] 只要本次同步的源中有一个开启了 `fullTextByDefault`，同步结束后（finally）就调度一次非用户触发的全文抓取任务。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:174
- FS-A09 [backend] 每个源开始处理时把 `currently_syncing` 置 true，并把 `last_sync` 写为当前时间；无论成功或失败，结束后都把 `currently_syncing` 置回 false。因此请求失败（如 HTTP 500）后 `last_sync` 仍会更新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:195
- FS-A10 [backend] 对 UI 暴露的 `currentlySyncing` 规则：`MAX(feeds.last_sync)` 在最近 10 秒内则为真；Feed 页的刷新指示还要求 `syncWorkerRunning` 为真。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:403

## 域: HTTP 获取与限流

- FS-A11 [backend] forceNetwork 请求附带 `Cache-Control: max-age=60`，即发起条件请求，但 1 分钟内的缓存仍可命中；非强制请求遵循 HTTP 缓存。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:345
- FS-A12 [backend] 订阅 URL 含 userinfo（`user:pass@host`）时，先对用户名和密码分别做 URL 解码，再在收到 401 或 407 质询时以 HTTP Basic 认证重试一次；已经带过 Authorization 的请求不再重试。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:357
- FS-A13 [backend] 每个出站请求的 `User-Agent` 固定为 `SpaceCowboys Android RSS Reader / <versionName>(<versionCode>)`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/UserAgentInterceptor.kt:24
- FS-A14 [backend] 主 HTTP 客户端：磁盘缓存 200MB，连接和读取超时各 30s，跟随重定向。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:122
- FS-A15 [backend] 按主机限速：同一主机两次网络请求间隔不少于 333ms；不足时随机等待 [剩余时间, 2×剩余时间) 后再发。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RateLimiter.kt:13
- FS-A16 [backend] 服务端返回 4xx 且未带 `cache-control` 时，强制把该响应缓存 3600 秒（同时移除 pragma/expires/x-cache）；返回 5xx 或已带 cache-control 时保持原样。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ForceCacheOnSomeFailuresInterceptor.kt:11
- FS-A17 [backend] 收到 429 后，以 `Retry-After` 秒数为准（缺失或非整数按 60 秒）再加 1 秒，在此窗口内该主机的请求只走缓存（only-if-cached）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/TooManyRequestsInterceptor.kt:44
- FS-A18 [backend] 同步时 HTTP 失败若带 `retry-after` 头（多值取最大，非数字按 3600 秒），则把所有 URL 包含该主机名的源的 `retry_after` 设为 now+秒数（只延后、不提前）；窗口内这些源被跳过、不发请求。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:212
- FS-A19 [backend] 抓取 feed 时：只有 Content-Type 缺失、主类型为 text，或子类型含 json/xml 时才按原始字节解析；其他类型返回 `UnsupportedContentType`；非 2xx 返回 `HttpError(code,message,retryAfter)`；无响应体返回 `NoBody`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:235
- FS-A20 [backend] 解析 feed 时，以重定向后的最终请求 URL 作为基址，相对链接都按它转成绝对链接；不采用 feed 内自声明的 self link。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:285
- FS-A21 [backend] 图片专用客户端：独立网络缓存 300MB，请求一律附带 max-stale 30 天、max-age 7 天；开启"仅 Wi‑Fi 加载图片"且当前为计费网络时，只用缓存（无缓存则失败）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:157
- FS-A22 [backend] 图片加载按主机散列为若干把锁，同一锁内同一时刻只发一个 http(s) 图片请求；data: URL 不受此限。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/OneImageRequestPerHostInterceptor.kt:36

## 域: 条目入库（增量、去重、标识）

- FS-A23 [backend] 条目 guid 规则：若本 feed 内条目 id 有重复，或源的 `alternateId` 开关已开启，则 guid = `"<id>|<content_text.hashCode()>|<title.hashCode()>"`；否则 guid = id，id 为空时退回上述替代 id。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:318
- FS-A24 [backend] 增量更新：依次用替代 id、再用 `id ?: 替代id` 在同一源内查找已有条目；命中则就地更新（guid 改写为当前首选值），未命中则新建，`firstSyncedTime` 取本次下载时间。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:359
- FS-A25 [backend] 源开启 `skipDuplicates` 时，若新条目与库中任一已有条目（不限所在源）标题相同或链接相同（要求标题非空、链接非空），则丢弃该新条目。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:553
- FS-A26 [backend] 条目字段映射：标题截取前 200 字；摘要取 summary、content_text 或正文纯文本中第一个非空者，截取前 200 字；字数由正文纯文本估算；附件取第一个 enclosure 的 url，mime 转小写；作者取条目作者，缺失时用 feed 作者；link 取条目 url。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:132
- FS-A27 [backend] pubDate 能按 ISO ZonedDateTime 解析则覆盖；解析失败时保留已有值，没有已有值则用回退时钟。回退时钟为下载时间减去 (N-1-位置) 秒，因此 feed 中越靠前的无日期条目时间越新、且互不相同。`primarySortTime` = min(firstSyncedTime, pubDate)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:352
- FS-A28 [backend] 条目正文（content_html，缺失时用 content_text，再缺时为空串）写入 articleDir 下以条目 id 命名的 blob 文件；先更新已有条目，再插入新条目，并用新 id 写 blob。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:402
- FS-A29 [backend] 条目 guid 若在远端已读集合中：入库时 `readTime` 设为 now（已有值则保留）、`notified` 置 true，写入后立即标为已同步，不再回传给服务器。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:389
- FS-A30 [backend] 源同步成功后，对该源中本次新入库的条目按全局屏蔽词表计算屏蔽状态，计算口径受"应用到摘要/链接"两个设置影响。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:222
- FS-A31 [backend] 源元数据回写：title 取 feed 标题（为空则保留原值）；`imageUrl` 取 feed icon（为空则保留原值）；源 URL 不含认证参数且不含 query 时，改写为 feed_url（即重定向后的最终 URL）；源记录在所有条目处理完后才 upsert。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:441
- FS-A32 [backend] 源没有图标且 `siteFetched` 仍为 EPOCH 时，仅尝试一次：抓取 home_page_url 的站点根（协议+主机+端口），取 `rel=apple-touch-icon`、`icon`、`shortcut icon` 中第一个有 href 的链接作为源图标，并把 `siteFetched` 记为 now。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:416

## 域: 保留策略

- FS-A33 [backend] 每源保留条数 = max(maxFeedItemCount, 本次解析出的原始条目数)。超出部分按 `primary_sort_time DESC, pub_date DESC` 排序后删除，但不删收藏条目、本次 feed 中仍存在的条目和当前打开的文章。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:462
- FS-A34 [backend] 删除条目时同时删除其正文 blob 和全文 blob，然后清理过期的远端已读标记。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:478
- FS-A35 [backend] 每日孤儿文件清理：删除 articleDir 和 fullArticleDir 中不对应任何现存条目 id 的文件。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/CleanupOrphanedFilesJob.kt:37

## 域: 文章过滤规则

- FS-A36 [backend] 规则文本每行一条 `Field=regex`：只在第一个 `=` 处切分；字段名大小写不敏感，取值为 `Title`/`URL`/`Author`/`Tag`/`Content`；空行跳过，但仍计入行号。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ArticleFilterRules.kt:149
- FS-A37 [backend] 无效行不抛异常，而是记录错误后跳过：缺少 `=`→MissingSeparator，未知字段→UnknownField，空模式→EmptyPattern，正则非法→InvalidRegex；第 101 条起报 TooManyRules，该行及其后全部行忽略。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ArticleFilterRules.kt:166
- FS-A38 [backend] 过滤判定：先看屏蔽规则，任一命中即丢弃（屏蔽优先于允许）；没有允许规则时保留；有允许规则时只对适用的允许规则投票，任一命中即保留；Tag 规则对无标签条目不适用，若没有任何适用规则则保留。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ArticleFilterRules.kt:246
- FS-A39 [backend] 匹配语义为正则"包含匹配"：缺失字段按 "" 匹配；Content 优先匹配非空白的 content_text，否则匹配 content_html；文本超过 100000 字时只搜索前 100000 字，`$` 不会在截断处命中。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ArticleFilterRules.kt:43
- FS-A40 [backend] 过滤只在抓取时生效：被过滤的条目不入库、不写 blob、不发通知；规则新增前已入库的条目保留；全部规则无效时放行所有条目；规则过滤不改变 guid 方案和回退时钟的下标。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssLocalSync.kt:343

## 域: 缩略图

- FS-A41 [backend] 解析期缩略图优先级：feed 提供的非正文图（media/enclosure）优先；已有的非正文图保留；正文首图只作兜底。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ThumbnailImagePolicy.kt:15
- FS-A42 [backend] 源开启 `fetchOgImages`、条目有 url、feed 没给图，且当前缩略图为空或来自正文时，抓取文章页 `<head>` 中的 og:image；抓取失败则保留原值；已有非正文图永不被覆盖。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ThumbnailImagePolicy.kt:30
- FS-A43 [backend] 缩略图以带类型标签的 JSON 存储，有三种类型：`ImageFromHTML`（fromBody=true，含宽高）、`EnclosureImage`（含 length）、`MediaImage`（含宽高）；url 一律为绝对地址。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ThumbnailImage.kt:9

## 域: 站点发现（SearchFeed 依赖）

- FS-A44 [backend] 站点元数据：HTML 不含 `<head>` 时返回 NotHTML。否则提取 `rel=alternate` 中带 href 和 type、且 type 含 application/atom、application/rss 或等于 application/json 的链接，并转为绝对 URL。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:56
- FS-A45 [backend] youtube.com 或 www.youtube.com 页面若没有 alternate 链接，从 `data-channel-external-id` 属性生成 `https://www.youtube.com/feeds/videos.xml?channel_id=<id>`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:174
- FS-A46 [backend] 抓取站点页面（curl）只接受 text/plain 和 text/html，其余类型返回 UnsupportedContentType；`parseFeedUrl` 返回的 feed_url 保留用户输入的原 URL（含认证信息和 token）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:406

## 域: 后台任务调度

- FS-A47 [on_device] 结果契约：同步频率不为"手动"时，按设置周期（15/30/60/180/360/720/1440 分钟，默认 60）在后台定期同步，受"仅充电""仅 Wi‑Fi"约束，重启设备后仍有效；鸿蒙实现：WorkSchedulerExtensionAbility 周期任务（repeatCycleTime + chargerType/networkType + isPersisted）；差异：鸿蒙最小周期和执行时机由系统管控，15 分钟档未必准时。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:108
- FS-A48 [backend] 选择 `MANUAL` 时取消周期同步任务；修改频率、仅 Wi‑Fi 或仅充电设置后，按新约束重新调度（replace）；启动主界面时若该任务不存在则补建。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:121
- FS-A49 [backend] 一次性同步 `runOnceRssSync`：非强制同步且开启"仅 Wi‑Fi"时要求非计费网络，否则任意网络即可；参数 feedId、tag、forceNetwork 透传给 RssLocalSync。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:84
- FS-A50 [backend] 同步任务结束后（无论成败，finally）为开启通知的源发送新条目通知。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:56
- FS-A51 [on_device] 结果契约：用户手动触发同步（下拉刷新或菜单）时，同步期间显示标题为 `Syncing` 的常驻低优先级通知（渠道名 `Sync status`），任务结束即移除；鸿蒙实现：短时任务或长时任务（dataTransfer）配合通知；差异：Android 仅 14 及以上（user-initiated job）才显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/FeederJobService.kt:98
- FS-A52 [backend] 回到前台时：若开启"恢复时同步"（默认关闭），且当前有网、满足充电/非计费约束，则先拉取同步链更新，再做一次非强制同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:74
- FS-A53 [backend] 回传已读标记的任务：至少延迟 10 秒后执行以合并批次；已有待执行任务时不重复调度；未配置同步链时不调度。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/SyncChainSendReadJob.kt:52
- FS-A54 [backend] 屏蔽词更新任务按参数分三种范围：指定 feedId 时只处理该源的新条目；onlyNew 时只处理屏蔽状态为空的条目；否则全量重算。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/BlocklistUpdateJob.kt:44
- FS-A55 [on_device] 结果契约：孤儿文件清理每天执行一次，仅在设备空闲且充电时运行，重启后仍保留调度；鸿蒙实现：WorkScheduler 周期任务（isDeepIdle + chargerType + isPersisted）；差异：执行时机由系统决定。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/CleanupOrphanedFilesJob.kt:102
- FS-A56 [backend] 全文抓取任务：对开启 fullTextByDefault 且尚未下载全文的条目逐条抓取全文；全文 blob 已存在的条目跳过；无论成败都标记为已尝试下载。非用户触发时受充电和 Wi‑Fi 设置约束。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/FullTextSyncJob.kt:40
