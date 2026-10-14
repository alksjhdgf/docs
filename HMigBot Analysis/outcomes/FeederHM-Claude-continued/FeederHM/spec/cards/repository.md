# 仓储层（Repository / Stores）域卡

## 域: 首次启动与会话态
- RP-A01 [backend] 首次启动（`addedFeederNews`=false）时自动订阅标题 `Feeder News`、URL `https://news.nononsenseapps.com/index.atom` 的源，置 `addedFeederNews`=true 并立即触发一次该源同步；之后启动不再重复添加（即使用户已删除）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:76
- RP-A02 [backend] minReadTime 初值为进程启动时刻且从不持久化；切换到不同的源/标签、或执行全部标为已读后，minReadTime 更新为当前时间。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:132
- RP-A03 [backend] 抽屉标签展开集合 expandedTags 仅存于内存，toggleTagExpansion(tag) 已展开则收起、否则展开；冷启后全部收起。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SessionStore.kt:27
- RP-A04 [backend] 搜索词 search 仅存于内存（初值空串），不持久化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:201

## 域: 当前源选择
- RP-A05 [backend] setCurrentFeedAndTag 持久化当前 (feedId, tag)，冷启后恢复为上次选择。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:67
- RP-A06 [backend] deleteFeeds 删除源后，若当前选中源在被删集合中，当前选择切换为全部（`ID_ALL_FEEDS`=-10, ""）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:589
- RP-A07 [backend] renameTag(old,new) 将所有 tag=old 的源改为 new；若当前选中正是标签 old，则当前选择改为标签 new。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:144
- RP-A08 [on_device] 选中某个具体源（feedId>0）后，系统桌面长按应用出现以该源标题命名的动态快捷方式（最多 3 个），点击打开该源；删除源后对应快捷方式移除。结果契约：快捷方式可直达源；鸿蒙实现：无动态 shortcut API；差异：见降级候选。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt:32

## 域: 文章列表查询
- RP-A09 [backend] 所有列表/计数/小组件查询都排除被屏蔽条目（block_time 非空）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:141
- RP-A10 [backend] 仅勾选未读过滤时只返回 read_time 为空的条目；勾选“最近已读”时额外返回 read_time>=minReadTime 的条目；勾选“已读”时返回全部已读条目。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:145
- RP-A11 [backend] 勾选“已收藏”过滤时，收藏条目无论已读状态都包含在列表中。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:157
- RP-A12 [backend] 范围：feedId>0 只含该源条目；tag 非空（feedId=0）只含该标签下源的条目；`ID_SAVED_ARTICLES`(-20) 只含 bookmarked=1 条目且不施加已读过滤；其余为全部条目。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:163
- RP-A13 [backend] 搜索词非空时按 plain_title 或 plain_snippet 包含（字面子串，`%`/`_`/`\` 不作通配）匹配，且此时不再限制当前源/标签范围。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:164
- RP-A14 [backend] 排序 NEWEST_FIRST 时按 primary_sort_time、pub_date、id 全降序，否则全升序。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:573
- RP-A15 [backend] 当前源/标签、minReadTime、排序、过滤、搜索任一变化时文章列表重新查询并刷新；收藏视图的 minReadTime 视为 EPOCH。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:412
- RP-A16 [backend] 列表项 unread=read_time 为空；发布日期为今天（本地时区）显示系统时间格式，否则显示系统中等日期格式，无日期显示空串。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:379
- RP-A17 [backend] 过滤联动：关闭“最近已读”时同时关闭“已读”；开启“已读”时同时开启“最近已读”。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:185
- RP-A18 [backend] 小组件列表按小组件自己的 (feedId, tag)（收藏/单源/标签/全部）返回最多 50 条未屏蔽条目，按最新优先，不受已读过滤与排序设置影响。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:79

## 域: 标题与计数
- RP-A19 [backend] 当前屏幕标题：feedId>0 为源显示标题，否则 tag 非空为标签名，否则为空（UI 显示通用名）；类型：tag 非空→TAG，feedId 为 0 或 -10→ALL_FEEDS，-20→SAVED_ARTICLES，否则 FEED。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:567
- RP-A20 [backend] 标题中的未读数 = 当前范围内未屏蔽且未读（read_time 为空或晚于当前时刻）的条目数，随数据变化实时更新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:104
- RP-A21 [backend] 抽屉导航项顺序：全部(-10, 未读和) → 已收藏(-20, 收藏数，仅存在收藏时) → 各非空标签（未读和；展开时其下源紧随其后）→ 无标签源；同段内按标题不区分大小写排序。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:132
- RP-A22 [backend] currentlySyncing 在所有源最大 last_sync 处于最近 10 秒内时为 true。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:403

## 域: 已读/收藏写操作
- RP-A23 [backend] markAsReadAndNotified 将条目置为已读（保留已有 read_time）并 notified=1，之后若同步链已配置则排队发送已读状态。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:509
- RP-A24 [backend] 滑动标为已读（readTimeBeforeMinReadTime=true 且 minReadTime>EPOCH）时 read_time 被覆盖为 minReadTime-1 秒，使该条目立即从“最近已读”列表中消失。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:514
- RP-A25 [backend] markAsUnread 将 read_time 置空并删除该条目的已同步标记（下次同步不再视为已读已同步）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:527
- RP-A26 [backend] setBookmarked(id, b) 设置收藏状态，收藏列表与抽屉收藏计数随之更新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:495
- RP-A27 [backend] 全部标为已读：feedId>0 作用于该源，tag 非空作用于该标签，否则作用于所有条目；未读条目 read_time=now、全部 notified=1，之后 minReadTime=now 并排队发送已读同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:597
- RP-A28 [backend] “标记上方为已读/标记下方为已读”只作用于与当前列表相同过滤（过滤/搜索/minReadTime/范围）下、按当前排序位于游标条目之前/之后的条目（不含游标本身），并在写入后刷新列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:182

## 域: 订阅源存取
- RP-A29 [backend] saveFeed：id>0 更新并返回原 id，否则插入并返回新 id。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedStore.kt:41
- RP-A30 [backend] upsertFeed 对 id 未设置但 URL 已存在的源，更新已有记录而非报错或重复插入。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedStore.kt:108
- RP-A31 [backend] allTags 返回所有源的去重标签，按不区分大小写排序。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:49
- RP-A32 [backend] 单篇打开方式：源设置值 `2`→默认浏览器、`3`→自定义标签页、`0`→阅读器，其他值（含空）回落全局 itemOpener 设置。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:536
- RP-A33 [backend] 条目清理保留每源最新 keepCount 条，收藏条目永不被清理。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:60
- RP-A34 [backend] setRetryAfterForFeedsWithBaseUrl 只把 URL 含该 host 的源的 retry_after 往后推，不会提前。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:276

## 域: 屏蔽词
- RP-A35 [backend] 添加/删除屏蔽词、切换“应用于摘要”“应用于链接”后，会重新计算全部条目的屏蔽状态，列表随之隐藏/恢复相应条目。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:226

## 域: 设置透传
- RP-A36 [backend] setMaxLines 写入值下限为 1（小于 1 时存 1）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:169
- RP-A37 [on_device] 应用启动时确保周期 RSS 同步已按 syncFrequency 调度（不替换已存在的调度）；频率为手动(<1 分钟)时取消周期同步。结果契约：后台定时拉取；鸿蒙实现：WorkScheduler；差异：最小间隔受限。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:108

## 域: 字体
- RP-A38 [backend] 字体选项列表 = 字体目录中可解析的 `.ttf` 用户字体 + 系统默认 + Roboto Flex。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FontStore.kt:35
- RP-A39 [backend] 添加字体成功后复制进应用字体目录、列表刷新并自动设为当前字体。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:309
- RP-A40 [backend] 添加同名已存在字体、无文件名或非有效 TrueType 文件时返回 AddFontError，不改变当前字体与列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FontStore.kt:58
- RP-A41 [backend] 删除用户字体时先将当前字体重置为 Roboto Flex，再删除文件并刷新列表；对内置字体调用无效果。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:323

## 域: 同步链（Feeder Sync）
- RP-A42 [backend] getSyncRemote 无记录时创建 id=1 的默认远端（设备名取自设备制造商/型号，新随机密钥）并持久化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SyncRemoteStore.kt:33
- RP-A43 [backend] 收到远端已读（feedUrl+guid）时总是记录远端已读标记；本地存在该条目则立即标为已读并记为已同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:681
- RP-A44 [backend] applyRemoteReadMarks 将匹配本地未读条目的远端标记应用为已读并记为已同步，删除已应用标记，再删除对应本地已读条目的残留标记（保证用户后续“标为未读”不被覆盖）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:741
- RP-A45 [backend] 远端已读标记超过 7 天即被清除。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SyncRemoteStore.kt:91
- RP-A46 [backend] 新建同步链成功后刷新设备列表并返回 (syncCode, 本地 secretKey)；加入同步链成功后刷新设备列表；失败返回 ErrorResponse。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:778
- RP-A47 [backend] 未配置同步链时，已读操作不触发任何发送已读作业。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/SyncChainSendReadJob.kt:56
