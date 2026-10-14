# 数据库域卡（db）

## 域: 数据库结构与生命周期
- DB-A01 [backend] 数据库文件名为 `rssDatabase`，schema 版本为 40，全应用单例访问。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/AppDatabase.kt:29
- DB-A02 [backend] 库含 8 张表 `feeds`、`feed_items`、`blocklist`、`sync_remote`、`read_status_synced`、`remote_read_mark`、`remote_feed`、`sync_device` 及视图 `feeds_with_items_for_nav_drawer`，表名列名与 v40 schema 一致。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/AppDatabase.kt:43
- DB-A03 [backend] `feeds.url` 唯一；同一 URL 不能存在两条订阅。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Feed.kt:38
- DB-A04 [backend] `feed_items` 以 (`guid`,`feed_id`) 唯一；同一订阅内同 guid 的文章只存一条，重复插入被忽略。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:52
- DB-A05 [backend] 删除订阅时级联删除其全部文章（`feed_items.feed_id` ON DELETE CASCADE），文章删除级联删除对应 `read_status_synced` 行。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:62
- DB-A06 [backend] 删除 `sync_remote` 行级联删除 `read_status_synced`、`remote_read_mark`、`remote_feed`、`sync_device` 中所属行。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/SyncDevice.kt:19
- DB-A07 [backend] 新建订阅默认值：`custom_title`/`tag`/`open_articles_with`/`block_rules`/`allow_rules` 为空串，`notify`/`fulltext_by_default`/`skip_duplicates`/`summarize_on_open`/`fetch_og_images` 为 false，`last_sync`/`retry_after` 为纪元 0。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Feed.kt:44
- DB-A08 [backend] 订阅显示名 = `custom_title` 非空白时取之，否则取 `title`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Feed.kt:73
- DB-A09 [backend] 文章未读判定为 `read_time IS NULL`；`unread`/`pinned`/`image_from_body`/`title` 为废弃列，不参与逻辑。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:129
- DB-A10 [on_device] 订阅、文章已读/收藏状态写入后冷重启应用仍保持。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/AppDatabase.kt:94

## 域: 类型存储格式
- DB-A11 [backend] 所有 Instant 字段以 epoch 毫秒整数存储；解析失败读为 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Converters.kt:35
- DB-A12 [backend] `pub_date` 以 ISO 日期时间字符串（TEXT）存储，无法解析的值读为 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Converters.kt:14
- DB-A13 [backend] `feed_items.image_url` 存缩略图 JSON（类型 `ImageFromHTML`/`EnclosureImage`/`MediaImage`）；旧值为纯 URL 时读为 `ImageFromHTML`(宽高未知)，否则 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Converters.kt:52
- DB-A14 [backend] URL 字段以字符串存储，读取时宽松解析为合法 URL 不抛错。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/Converters.kt:32

## 域: 文章写入与字段推导
- DB-A15 [backend] 解析条目写库时标题与摘要各截断至 200 字符；摘要取 summary → content_text → 正文纯文本。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:148
- DB-A16 [backend] 作者取条目作者，缺失时回退订阅作者；附件取第一个 attachment 的 url 与小写 MIME。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:166
- DB-A17 [backend] 发布时间无法解析时保留已有值，无已有值则取当前时间；`primary_sort_time` = min(`first_synced_time`, 发布时间)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:173
- DB-A18 [backend] 字数估算：按空白切分计数，平均词长 ≥15 字符（无空格语言）时字数记为 0。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:223
- DB-A19 [backend] 批量 upsert：已有 id 的条目更新、无 id 的插入并回填新 id，随后对每条执行正文写入回调。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:580
- DB-A20 [backend] 清理旧文章：每个订阅按排序保留最新 keepCount 条，其余非收藏文章可删；收藏文章永不被清理。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:60
- DB-A21 [backend] 重复判定：存在其他文章与之同标题或同链接（标题非空且链接非空）即视为重复。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:553

## 域: 列表查询与已读状态
- DB-A22 [backend] 文章列表排序为 `primary_sort_time`,`pub_date`,`id` 三键同向（默认降序，可升序）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:573
- DB-A23 [backend] 所有列表、计数、通知、小组件查询均排除 `block_time` 非空（被屏蔽）的文章。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:140
- DB-A24 [backend] 列表过滤：仅未读时 `read_time is null`；含「最近已读」时额外包含 read_time ≥ minReadTime；含「已读」时包含全部；含「已保存」时并入收藏文章；「已保存」视图(-20)只列收藏。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:142
- DB-A25 [backend] 搜索对 `plain_title`/`plain_snippet` 做子串 LIKE 匹配，`\` `%` `_` 按字面处理，且搜索时不限定当前订阅/标签。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:162
- DB-A26 [backend] 标记已读（单条/批量/订阅/标签/全部）保留已存在的首次已读时间并同时置 `notified=1`；标未读将 `read_time` 置空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:330
- DB-A27 [backend] 「标记上方/下方为已读」按当前条目的排序游标(primary_sort_time,pub_date,id)只标记排序在其之前/之后且符合当前过滤的文章，写入后列表数据刷新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:182
- DB-A28 [backend] 列表、计数、抽屉、文章详情查询为可观察数据源，任意文章/订阅写入后自动推送新结果。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:156
- DB-A29 [backend] 待通知文章 = 订阅 `notify=1`、`notified=0`、未读且未屏蔽；单次通知最多取 20 条。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:317
- DB-A30 [backend] 桌面小组件数据：按订阅/标签/全部/已保存取未屏蔽文章，降序最多 50 条。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:162
- DB-A31 [backend] 需自动下载全文的文章 = 所属订阅 `fulltext_by_default=1` 且 `fulltext_downloaded<>1` 且未屏蔽。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:460
- DB-A32 [backend] 收藏导出仅含链接非空的收藏文章并按链接排序；导入按链接批量置收藏。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:370

## 域: 订阅查询与抽屉
- DB-A33 [backend] 抽屉条目顺序：「全部」(id -10, 未读总数) → 「已保存」(id -20, 收藏数) → 各非空标签（未读合计，展开后紧随其下列出该标签订阅）→ 无标签订阅；同组按显示名不区分大小写排序；计数排除屏蔽文章。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:133
- DB-A34 [backend] 标签列表为去重后不区分大小写排序；重命名标签批量修改所有该标签订阅。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:46
- DB-A35 [backend] 同步选取订阅仅包含 `retry_after` 早于当前的订阅，按 `last_sync` 升序；非强制同步时仅选 `last_sync` 早于过期阈值者。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:95
- DB-A36 [backend] 收到 Retry-After 时，URL 含该主机的所有订阅 `retry_after` 只会被推迟、不会被提前。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:276
- DB-A37 [backend] 「最近同步时间」取所有订阅 `last_sync` 最大值并可观察。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:210
- DB-A38 [backend] 通知设置列表按显示名不区分大小写排序；可按订阅、按标签或全部切换 `notify`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:64

## 域: 屏蔽列表
- DB-A39 [backend] 添加/删除屏蔽词以 `*词*` glob 形式存储，模式唯一，列表按模式排序可观察。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/BlocklistDao.kt:10
- DB-A40 [backend] 屏蔽重算：小写标题（可选摘要、链接）匹配任一模式的文章被设 `block_time`（已有则保留），不再匹配的清空；新同步文章仅对本订阅未判定条目计算。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/BlocklistDao.kt:35

## 域: 同步元数据
- DB-A41 [backend] 同步配置仅一行（id=1）；重置为默认时生成新 AES 密钥、默认服务器 `https://feeder-sync.nononsenseapps.com:443` 并清空关联设备/远端记录。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/SyncRemoteDao.kt:60
- DB-A42 [backend] 已加入同步链判定为 `sync_chain_id` 长度恰为 64；`latest_message_timestamp` 只增不减。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/SyncRemote.kt:44
- DB-A43 [backend] 待上传已读标记 = 已读且尚无 `read_status_synced` 记录的文章；远端已读标记仅应用到本地未读的同 feed_url+guid 文章，本地已读者的远端标记被删除，超过 7 天的远端标记被清理。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/RemoteReadMarkDao.kt:42
- DB-A44 [backend] 设备列表与远端订阅列表以事务方式整表替换；设备按名称排序可观察。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/SyncDeviceDao.kt:35
