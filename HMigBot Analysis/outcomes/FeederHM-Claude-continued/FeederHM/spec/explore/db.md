# 探索文档：db（数据库层）

范围：`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/`（Uri.kt、Constants.kt）与 `db/room/`（实体/DAO/视图/迁移/Converters），以及 Room 导出 schema `input/Feeder/app/schemas/com.nononsenseapps.feeder.db.room.AppDatabase/{7..40}.json`。
下文 `R` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room`，`D` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db`。

## 1. 总览

| 项 | 值 | 锚点 |
|---|---|---|
| 框架 | Android Room（SQLite），`@TypeConverters(Converters::class)` | R/AppDatabase.kt:43-60 |
| 库文件名 | `rssDatabase` | R/AppDatabase.kt:29 |
| 当前版本 | **40**；identityHash `e89ba6774f07eb4d7672ccbea86d880c`（40.json） | R/AppDatabase.kt:57 |
| 实体 | Feed, FeedItem, BlocklistEntry, SyncRemote, ReadStatusSynced, RemoteReadMark, RemoteFeed, SyncDevice（8 表） | R/AppDatabase.kt:44-53 |
| 视图 | `feeds_with_items_for_nav_drawer` | R/FeedsWithItemsForNavDrawer.kt:6-18 |
| DAO | FeedDao, FeedItemDao, BlocklistDao, SyncRemoteDao, ReadStatusSyncedDao, RemoteReadMarkDao, RemoteFeedDao, SyncDeviceDao | R/AppDatabase.kt:61-75 |
| 单例 | `getInstance(context)` 双检锁；DI 中 `bind<AppDatabase>() with singleton` | R/AppDatabase.kt:89-100；input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:81 |
| 迁移 | 5→7、6→7（遗留非 Room 库）+ 7→8 … 39→40 逐级；无 fallbackToDestructiveMigration | R/AppDatabase.kt:94-142 |
| 特殊 ID | `ID_UNSET=0`，`ID_ALL_FEEDS=-10`，`ID_SAVED_ARTICLES=-20` | R/AppDatabase.kt:30-32 |
| 远未来 | `FAR_FUTURE = Instant.ofEpochSecond(95635369646)`（约 5000 年） | D/Constants.kt:61-62 |
| ContentProvider URI | `content://com.nononsenseapps.feeder.provider/feeds`、`/feed_items`（Uri.kt 常量；manifest 实际 authority 是 `${applicationId}.rssprovider`，见 contentprovider 区） | D/Uri.kt:7-17；input/Feeder/app/src/main/AndroidManifest.xml:168-170 |

## 2. 表结构（v40，源自 40.json createSql）

### feeds（Feed.kt）
`id INTEGER PK AUTOINCREMENT, title TEXT NN, custom_title TEXT NN, url TEXT NN, tag TEXT NN, notify INTEGER NN, image_url TEXT, last_sync INTEGER NN, response_hash INTEGER NN, fulltext_by_default INTEGER NN, open_articles_with TEXT NN, alternate_id INTEGER NN, currently_syncing INTEGER NN, when_modified INTEGER NN, site_fetched INTEGER NN, skip_duplicates INTEGER NN, retry_after INTEGER NN, summarize_on_open INTEGER NN, fetch_og_images INTEGER NN, block_rules TEXT NN, allow_rules TEXT NN`
- 索引：`index_feeds_url` UNIQUE(url)；`index_feeds_id_url_title` UNIQUE(id,url,title)（R/Feed.kt:35-41）
- 默认值（Kotlin）：url=`URL("http://")`，lastSync/whenModified/siteFetched/retryAfter=EPOCH，openArticlesWith=`""`(=OPEN_ARTICLE_WITH_APPLICATION_DEFAULT)，block/allowRules=""（R/Feed.kt:33,44-70）
- `displayTitle = customTitle.ifBlank { title }`（R/Feed.kt:73-74）
- `whenModified` 仅在用户修改订阅时更新（注释 R/Feed.kt:60）；`retryAfter` 来自 Retry-After 响应头（R/Feed.kt:64）

### feed_items（FeedItem.kt）
`id PK AUTOINCREMENT, guid TEXT NN, title TEXT NN, plain_title TEXT NN, plain_snippet TEXT NN, image_url TEXT, image_from_body INTEGER NN, enclosure_link TEXT, enclosure_type TEXT, author TEXT, pub_date TEXT, link TEXT, unread INTEGER NN, notified INTEGER NN, feed_id INTEGER, first_synced_time INTEGER NN, primary_sort_time INTEGER NN, pinned INTEGER NN, bookmarked INTEGER NN, fulltext_downloaded INTEGER NN, read_time INTEGER, word_count INTEGER NN, word_count_full INTEGER NN, block_time INTEGER, FK(feed_id)→feeds(id) ON DELETE CASCADE`
- 索引：UNIQUE(guid,feed_id)；(feed_id)；(block_time)；`idx_feed_items_cursor` UNIQUE(primary_sort_time,pub_date,id)（R/FeedItem.kt:49-69）
- 废弃但保留的列（SQLite 不能 drop）：`title`（恒等于 plain_title）、`image_from_body`、`unread`（被 read_time 取代）、`pinned`（被 bookmarked 取代）（R/FeedItem.kt:77-115）
- `unread` 计算属性 = `readTime == null`（R/FeedItem.kt:129-130）
- `pub_date` 以 TEXT 存 ZonedDateTime ISO 字符串（typeAffinity TEXT，R/FeedItem.kt:92-95）
- `image_url` 存 ThumbnailImage JSON（见 §4）
- MAX_TITLE_LENGTH=200、MAX_SNIPPET_LENGTH=200（R/FeedItem.kt:44-45）

`updateFromParsedEntry`（R/FeedItem.kt:132-182）：
- 正文 = HtmlToPlainTextConverter(content_html ?: content_text ?: "")；wordCount=estimateWordCount(正文)
- snippet = (summary ?: content_text ?: 正文).take(200)
- plainTitle = entry.title?.take(200)（title 为 null 时不改）；title = plainTitle
- thumbnail = ThumbnailImagePolicy.applyParsedEntryImage(current, incoming)
- enclosure = 首个 attachment 的 url 与 mime_type.lowercase()
- author = entry.author?.name ?: feed.author?.name；link = entry.url
- pubDate = parse(date_published)，失败则保留旧值，否则 now(clock)
- primarySortTime = min(firstSyncedTime, pubDate ?: firstSyncedTime)

`estimateWordCount`（R/FeedItem.kt:223-239）：取前 HtmlLinearizer.MAX_CHARS 字符，按 `\s+` 切分计数；若 字符数/词数 ≥ 15（无空格语言如日文）返回 0。
`enclosureFilename`：URI(enclosureLink).path 最后一段，空则 null；`domain`：(enclosureLink ?: link).host()（R/FeedItem.kt:184-204）。

### blocklist（BlocklistEntry.kt）
`id PK AUTOINCREMENT, glob_pattern TEXT NN`，UNIQUE(glob_pattern)（R/BlocklistEntry.kt:11-26）

### sync_remote（SyncRemote.kt）
`id PK, url TEXT NN, sync_chain_id TEXT NN, latest_message_timestamp INTEGER NN, device_id INTEGER NN, device_name TEXT NN, secret_key TEXT NN, last_feeds_remote_hash INTEGER NN`
- 只使用 id=1 一行（所有查询 `WHERE id IS 1`，R/SyncRemoteDao.kt:26-58）
- 默认 url `https://feeder-sync.nononsenseapps.com:443`；弃用主机 `feederapp.nononsenseapps.com`、`feeder-sync.nononsenseapps.workers.dev`（R/SyncRemote.kt:49-57）
- `hasSyncChain()` ⇔ syncChainId.length == 64（R/SyncRemote.kt:44）
- `generateDeviceName()`：Build.MANUFACTURER+MODEL（MODEL 已以厂商开头则只用 MODEL），首字母大写，空则随机数 0..99999（R/SyncRemote.kt:59-76）

### read_status_synced / remote_read_mark / remote_feed / sync_device
- read_status_synced：`sync_remote`→sync_remote CASCADE，`feed_item`→feed_items CASCADE；UNIQUE(feed_item,sync_remote)（R/ReadStatusSynced.kt:12-44）
- remote_read_mark：`sync_remote, feed_url TEXT, guid TEXT, timestamp INTEGER`；UNIQUE(sync_remote,feed_url,guid)；索引 (feed_url,guid)、(sync_remote)、(timestamp)（R/RemoteReadMark.kt:15-48）
- remote_feed：`sync_remote, url`；UNIQUE(sync_remote,url)（R/RemoteFeed.kt:13-39）
- sync_device：`sync_remote, device_id, device_name`；UNIQUE(sync_remote,device_id)（R/SyncDevice.kt:12-38）

### 视图 feeds_with_items_for_nav_drawer（R/FeedsWithItemsForNavDrawer.kt:6-18）
feeds LEFT JOIN（feed_items 中 `block_time is null` 的条目）；列：feed_id, item_id, display_title（custom_title 为 '' 用 title）, tag, image_url, unread（read_time is null）, bookmarked。注意：Room 校验视图 SQL 时对空白敏感（迁移 34→35 中用 `\n    ` 精确复刻，R/AppDatabase.kt:259-262）。

## 3. 投影/POJO
- `FEED_ITEM_COLUMNS_WITH_FEED` / `FeedItemWithFeed`：条目列 + feeds.tag/id/title/custom_title/url/fulltext_by_default；`feedDisplayTitle` = feedCustomTitle.ifBlank{feedTitle}（R/FeedItemWithFeed.kt:39-83）
- `PREVIEW_COLUMNS` / `PreviewItem`（定义在 model/PreviewItem.kt:19-26）：额外含 feed_open_articles_with、feed_image_url
- `FeedForSettings`(id,title,notify)、`FeedTitle`(id,title,custom_title)、`FeedItemIdWithLink`、`FeedItemForReadMark`(id,feed_id,guid,feed_url)、`RemoteReadMarkReadyToBeApplied`(id,feed_item_id)、`FeedUnreadCount`(model/FeedUnreadCount.kt)

## 4. Converters（R/Converters.kt）
| 类型 | 存储 | 读取容错 |
|---|---|---|
| ZonedDateTime | `toString()` ISO TEXT | parse 失败 → null（:14-27） |
| URL | `toString()` | `sloppyLinkToStrictURLNoThrows`（:29-33） |
| Instant | epoch **毫秒** INTEGER | 异常 → null（:35-44） |
| ThumbnailImage | kotlinx Json（sealed，判别字段默认 `type`：`ImageFromHTML`/`EnclosureImage`/`MediaImage`） | JSON 失败则把原串当 URL → `ImageFromHTML(url,null,null)`；再失败 null（:46-67） |
ThumbnailImage 子类：ImageFromHTML(url,width?,height?) fromBody=true；EnclosureImage(url,length) fromBody=false；MediaImage(url,width?,height?) fromBody=false（input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ThumbnailImage.kt:9-93）。

## 5. DAO 关键行为

### FeedDao（R/FeedDao.kt）
- insertFeed REPLACE（:24-25；注意 REPLACE 在 url 冲突时会删旧行→级联删条目）；updateFeed、deleteFeed、deleteFeedWithId、deleteFeeds(ids)、deleteFeedWithUrl、upsert
- loadTags/loadAllTags：`DISTINCT tag ORDER BY tag COLLATE NOCASE`（:46-50）
- 同步选择：syncLoadFeed(s)/IfStale：`retry_after < :retryAfter`，过期判断 `last_sync < :staleTime`，按 last_sync 升序（:52-115）
- loadFlowOfFeedsForSettings：title=COALESCE(NULLIF(custom_title,''),title)，按其 NOCASE 排序（:64-74）
- getPagedNavDrawerItems(expandedTags)（:133-163）：union 四段 → 「全部」(id=-10, sum unread, section0)；「已保存」(id=-20, sum bookmarked, section1)；每个非空 tag 一行(id=0, expanded=tag∈expandedTags, section2)；feed 行仅当 tag 为空(section3) 或 tag 已展开(section2, 排在 tag 行后)；排序 `sort_section, tag, sort_tag_or_feed, display_title collate nocase`
- setNotify(id|tag)、setAllNotify、renameTag(old,new)
- getCurrentlySyncingLatestTimestamp：`MAX(last_sync)` Flow（故意不按 currently_syncing 过滤，:208-216）
- setCurrentlySyncingOn(feedId,syncing[,lastSync])
- setRetryAfterForFeedsWithBaseUrl(host,retryAfter)：`url LIKE '%host%' AND retry_after < :retryAfter`（只延后，不提前，:276-287）
- loadFeedsForContentProvider：Cursor(id,title) 按 title

### FeedItemDao（R/FeedItemDao.kt）
- insert IGNORE（:26-30）；`upsertFeedItems` 扩展：id>0 走 update，否则 insert，回填 id 后对每条调用 block(item,text)（:580-607；text 在调用方写 blob 文件）
- getItemsToBeCleanedFromFeed(feedId,keepCount)：非书签条目按 primary_sort_time DESC,pub_date DESC 跳过前 keepCount 条返回其余 id（:60-71）
- 排序常量：DESC=`primary_sort_time DESC, pub_date DESC, feed_items.id DESC`，ASC 反之（:573-576，由 idx_feed_items_cursor 支撑）
- 列表分页：pagingUnreadPreviewsDesc/Asc（feed/tag/全部），过滤 `(read_time is null or read_time >= :minReadTime) AND bookmarked in (1,:bookmarked) AND block_time is null`（:213-315）。实际 UI 走 FeedItemStore 的 RawQuery（见 §6）
- widgetPreviewsByFeed/ByTag/AllFeeds/Saved：block_time null，DESC，LIMIT 50（:162-211）
- loadItemsToNotify(feedIds)：notified=0、未读、未屏蔽，DESC LIMIT 20（:317-328）
- markAllAsRead（全部/feed/tag）、markAsRead(ids)、markAsReadAndNotified：`read_time = coalesce(read_time,:now), notified=1`（保留首次已读时间，:330-362,419-423）
- markAsReadAndNotifiedAndOverwriteReadTime：覆盖 read_time（:425-429）
- markAsUnread：read_time=null（:355-356）
- setBookmarked、setBookmarkedByLinks(links)（导入书签用）、getBookmarkedItemsForExport（bookmarked 且 link 非空，按 link）、getLinksOfBookmarks（:364-386）
- markAsNotified(ids|id)、markTagAsNotified、markAllAsNotified（:388-417）
- getOpenArticleWith / getFullTextByDefault / getLink（:431-458）
- getFeedsItemsWithDefaultFullTextNeedingDownload：feed.fulltext_by_default=1 且 fulltext_downloaded<>1 且未屏蔽（Flow，:460-470）；markAsFullTextDownloaded
- getFeedItemCount（全部/tag/feed）Flow（:481-527）
- getFeedItemsNeedingNotifying：feed.notify=1、notified=0、未读、未屏蔽（Flow，:529-538）
- getItemWith(feedUrl,guid)（:540-551）
- duplicationExists(id,plainTitle,link)：存在其他 id 且（同标题或同链接）且 plain_title<>'' 且 link 非空（:553-566）
- updateWordCountFull、loadFeedItemByLink（按 id 取首条）

### BlocklistDao（R/BlocklistDao.kt）
- insertSafely(pattern)：存 `'*' || pattern || '*'`；deletePattern 同样包裹（:10-24）——**调用方传入的 pattern 已 lowercase？** 匹配侧使用 `lower(plain_title) glob pattern`，glob 区分大小写，故模式需小写（调用方负责，见 blocklist/settings 区）
- getGlobPatterns Flow 按 glob_pattern 排序
- setItemBlockStatus(blockTime, applyToSummaries, applyToLinks)：全表重算；命中 → `coalesce(block_time,:blockTime)`，未命中 → null（:35-54）
- setItemBlockStatusWhereNull：仅 block_time 为 null 的行（:56-76）
- setItemBlockStatusForNewInFeed(feedId,…)：限定 feed 且 block_time null（:78-99）
- 匹配对象：lower(plain_title)，可选 lower(plain_snippet)、lower(link)

### SyncRemoteDao（R/SyncRemoteDao.kt）
- 单行 id=1；updateLastMessageTimestamp 仅当新值更大（:44-51）
- replaceWithDefaultSyncRemote（@Transaction）：删 id=1，插入 id=1、deviceName=Build.PRODUCT ?: MODEL ?: BRAND、secretKey=AesCbcWithIntegrity.generateKey()（:60-70）；删 sync_remote 会级联删 read_status_synced/remote_read_mark/remote_feed/sync_device

### ReadStatusSyncedDao
- insert IGNORE；getFeedItemsWithoutSyncedReadMark：已读且不在 read_status_synced 中的条目，id DESC（:32-50）；deleteReadStatusSyncForItem；deleteAll

### RemoteReadMarkDao
- insert IGNORE；deleteStaleRemoteReadMarks(oldest)（调用方传 now-7 天：archmodel/SyncRemoteStore.kt:91-93）；deleteByIds；deleteRemoteReadMarksForReadItems（防止用户标未读后被旧远端标记重新标已读，:42-58）；getRemoteReadMarksReadyToBeApplied（guid+feed_url 匹配且本地未读，:60-69）；getGuidsWhichAreSyncedAsReadInFeed

### RemoteFeedDao / SyncDeviceDao
- replaceRemoteFeedsWith / replaceDevices（@Transaction 全删再插）；getRemotelySeenFeeds（sync_remote IS 1）；getDevices 按 device_name Flow
- 注意 SyncDeviceDao.deleteAll 是非 suspend（R/SyncDeviceDao.kt:28-33）

## 6. 区外直接 SQL（与 DB 契约强相关）
`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt`：
- getFeedItemCountRaw / getPagedFeedItemsRaw：`@RawQuery(observedEntities=[FeedItem])`；Pager pageSize=10, initialLoad=100, prefetch=100, jumpThreshold=100（:58-128）
- rawQueryFilter（:130-180）：恒 `block_time is null`；非「已保存」视图：仅未读筛选时 `read_time is null`，否则 `(read_time is null or read_time >= ?)`（filter.read → EPOCH，否则 minReadTime）；filter.saved → `OR bookmarked=1`；搜索：转义 `\ % _` 后 `plain_title LIKE ? OR plain_snippet LIKE ?`（**搜索时忽略 feed/tag 限定**）；否则 已保存→bookmarked=1、feedId>0→feed_id、tag→tag
- markAsReadRaw（:182-248）：按游标（primary_sort_time, pub_date, id）把「当前位置之后/之前」的条目标已读，直接 execSQL 后 `invalidationTracker.refreshVersionsAsync()`（Room 不支持写 RawQuery）

## 7. 迁移链（全部 R/AppDatabase.kt）
| 迁移 | 内容 | 行 |
|---|---|---|
| 5→7, 6→7 | legacyMigration：建 feeds/feed_items（含 description 列），从旧 `Feed`/`FeedItem` 表逐行复制（v6 含 imageUrl），删旧 trigger/view/表 | 831-955 |
| 7→8 | feeds.last_sync | 821-829 |
| 8→9 | feeds.response_hash | 810-818 |
| 9→10 | 重建 feed_items 去掉 description；description（截 1MB）写入 blob 文件 `blobOutputStream(id, filesDir)`；重建索引；所有 feeds.response_hash=0 | 739-807 |
| 10→11 | first_synced_time | 728-736 |
| 11→12 | primary_sort_time | 717-725 |
| 12→13 | feeds.fulltext_by_default | 706-714 |
| 13→14 | feeds.open_articles_with TEXT '' | 695-703 |
| 14→15 | feeds.alternate_id | 684-692 |
| 15→16 | feeds.currently_syncing | 673-681 |
| 16→17 | 建 sync_remote | 662-670 |
| 17→18 | 建 read_status_synced + 索引 | 636-659 |
| 18→19 | 建 remote_read_mark + 索引 | 605-633 |
| 19→20 | sync_remote.device_id/device_name；建 sync_device | 572-602 |
| 20→21 | sync_remote.secret_key/last_feeds_remote_hash；feeds.when_modified；建 remote_feed；为 id=1 生成 AES 密钥 | 519-569 |
| 21→22 | feed_items.pinned | 508-516 |
| 22→23 | feed_items.bookmarked | 497-505 |
| 23→24 | 建 blocklist；从 SharedPreferences `pref_block_list_values` 迁入为 `*x*`，然后删该偏好 | 447-494 |
| 24→25 | fulltext_downloaded；删 filesDir 下 `*.full.html.gz`；`*.txt.gz` 移到 cacheDir/articles | 401-445 |
| 25→26 | idx_feed_items_cursor；pinned=1 → bookmarked=1 | 379-399 |
| 26→27 | read_time；unread=0 的行 read_time=1690317917000 | 358-377 |
| 27→28 | feeds.site_fetched | 345-356 |
| 28→29 | enclosure_type | 332-343 |
| 29→30 | word_count | 319-330 |
| 30→31 | word_count_full | 306-317 |
| 31→32 | image_from_body | 293-304 |
| 32→33 | feeds.skip_duplicates | 280-291 |
| 33→34 | 创建 nav drawer 视图（基于 blocklist glob 过滤） | 268-278 |
| 34→35 | 删视图；feed_items.block_time + 索引；重建视图（block_time is null）；`runOnceBlocklistUpdate(di)` 触发后台计算 | 249-266 |
| 35→36 | feeds.retry_after | 235-247 |
| 36→37 | cacheDir/articles/*.txt.gz 移回 filesDir/articles | 153-193 |
| 37→38 | feeds.summarize_on_open | 195-206 |
| 38→39 | feeds.fetch_og_images | 208-217 |
| 39→40 | feeds.block_rules / allow_rules TEXT '' | 219-233 |
注释：17-20 从未发布（R/AppDatabase.kt:104）。迁移中含文件系统副作用（9→10、24→25、36→37）和 SharedPreferences 副作用（23→24）以及 WorkManager 调度（34→35）。

## 8. 鸿蒙映射建议（结果契约 / 实现 / 差异）
- Room → `@ohos.data.relationalStore`（RdbStore）。结果契约：同表名列名、同约束/索引/外键级联；鸿蒙实现：首次 `executeSql` 建表 + `store.version` 管理；差异：无编译期 DAO/schema 校验，需手写 SQL 与映射。
- 外键级联：SQLite 需 `PRAGMA foreign_keys=ON`（Room 默认开启）。RdbStore 需显式验证，否则删订阅不会级联删条目——高风险。
- Flow/PagingSource 响应式：Room 依靠 InvalidationTracker；鸿蒙需自建（`store.on('dataChange')` 仅分布式表适用），建议仓储层写后发事件 + 重新查询；分页用 LIMIT/OFFSET 或键集游标（排序键 primary_sort_time,pub_date,id）。
- Instant=毫秒 INTEGER，ZonedDateTime=ISO 字符串 TEXT（含偏移/区域，如 `2024-01-01T10:00+01:00[Europe/Paris]` 形式的 java toString）；ArkTS 无 ZonedDateTime，pub_date 的字典序比较在 markAsReadRaw 游标中被直接用作 TEXT 比较——需保持同一序列化格式以保证排序一致。
- ThumbnailImage JSON 判别字段与类名必须保持 `type`+`ImageFromHTML/EnclosureImage/MediaImage`，以兼容可能的数据导入。
- 迁移链：鸿蒙是新安装，不存在 Android 旧库；可直接以 v40 schema 建库，迁移链降级（见下）。
- GLOB/LIKE/COALESCE/NULLIF/COLLATE NOCASE/`LIMIT -1 OFFSET`/视图：均为 SQLite 原生，RdbStore（SQLite 内核）应支持，需验证 `LIMIT -1`。
- ContentProvider 游标查询 → 鸿蒙 DataShareExtensionAbility（另区）。

## 9. 降级候选
- 迁移 5→7…39→40 全链（含文件迁移、SharedPreferences 黑名单迁移）：鸿蒙全新安装无旧库，建议仅以 v40 建库，版本号记 40，保留 onUpgrade 框架用于后续版本。
- 废弃列 `title`、`unread`、`pinned`、`image_from_body`：可保留以保持 schema 同形（推荐，便于数据导入/对照），亦可省略；若省略需确认无查询引用（`title` 仍被 loadFeedItemsForContentProvider 使用，R/FeedItemDao.kt:117）。
- `generateDeviceName` 用 Build.MANUFACTURER/MODEL → 鸿蒙 `deviceInfo.manufacture/productModel`。
- Uri.kt 的 `content://com.nononsenseapps.feeder.provider` 常量：与 manifest authority 不一致，不对应真实 Provider；但 `URI_FEEDITEMS` 被通知用作 Intent data/唯一标识（input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:255,274,385），鸿蒙可替换为 Want 参数，属通知区。

## 10. 风险
1. 外键级联 + REPLACE 冲突策略：insertFeed REPLACE 在 url 唯一冲突时删除旧行并级联删除其全部条目（含书签）——行为须一致或明确改进。
2. 响应式查询失效通知（Flow/Paging + 原始 SQL 写入后 refreshVersionsAsync）在鸿蒙需手工实现，否则列表/抽屉计数不刷新。
3. pub_date TEXT 格式与排序/游标比较、primary_sort_time 计算必须逐字一致，否则排序与「标记以上为已读」错乱。
4. Blocklist glob 大小写：匹配 lower(字段) glob 模式，模式写入时包 `*…*`；glob 特殊字符 `[ ] ? *` 未转义。
5. nav drawer union 查询及 ID_ALL_FEEDS/ID_SAVED_ARTICLES 负数哨兵贯穿 UI 路由，必须保持。
6. sync_remote 单行 id=1 假设遍布 DAO。
