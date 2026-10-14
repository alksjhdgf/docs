# 通知与桌面小组件卡（notifications-widget）

## 域: 通知发布

- NW-A01 [backend] 同步任务结束（无论成功或异常，finally）都调用一次通知发布 `notify`。结果契约：后台/手动同步完成后才发通知；鸿蒙实现：同步任务 finally 中调用发布函数；差异：无。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:58
- NW-A02 [backend] 未获通知权限时 `notify` 与取消通知均直接返回，不报错也不发布。鸿蒙实现：`isNotificationEnabled()` 为 false 时跳过。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:60
- NW-A03 [backend] 待通知条目 = 所属源 `notify=1` 且 `notified=0` 且未读（`read_time` 为空）且未屏蔽（`block_time` 为空），按列表倒序取最多 20 条；没有任何 `notify=1` 的源时为空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:322
- NW-A04 [backend] 待通知条目为空时不发布任何通知；非空时对每条发布一条单独通知（通知 id = 条目 id 转 int），并发布一条汇总通知（固定 id `2147483646`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:77
- NW-A05 [backend] 发布通知不会把条目标记为 notified；条目只有在被划掉、点"Mark as read"、点通知打开或被标为已读时才置 `notified=1`，因此后续每次同步会以同一 id 覆盖重发仍未处理的通知。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:80
- NW-A06 [on_device] 通知使用低重要性渠道 `feederNotifications`（名称 `Unread feeds`，描述 `Notifications are only shown for unread items in configured feeds`），单条通知静默（不响铃不振动）。鸿蒙实现：低打扰 slot；差异：鸿蒙 slot 不可自定义名称/描述（降级）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:125
- NW-A07 [on_device] 单条通知标题为文章纯文本标题，正文为订阅源显示名，点按后通知自动消失。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:147
- NW-A08 [on_device] 汇总通知标题 `Updated feeds`，正文为去重后的源名以 `, ` 连接，展开后每条一行 `<源名> — <文章标题>`，角标数字为条目数。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:286
- NW-A09 [on_device] 单条通知的动作按钮按顺序：有附件链接时 `Open enclosed media`；文章打开方式不是默认浏览器且有链接时 `Open link in web browser`；始终有 `Mark as read`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:177

## 域: 通知点击与动作

- NW-A10 [backend] 单条通知点击目标按条目的打开方式（源级 `open_articles_with` 覆盖全局默认）：链接为空或阅读器 → 应用内打开文章深链 `https://feederapp.nononsenseapps.com/article/<id>`；Custom Tab → 代理以 Custom Tab 打开链接；默认浏览器 → 代理以浏览器打开链接。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:222
- NW-A11 [backend] 经代理打开链接（点通知、`Open link in web browser`、`Open enclosed media`）时：该条目被标为已读且已通知，其通知被取消；无可用应用打开链接时提示 `Install something to open this link with first`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt:61
- NW-A12 [backend] 点 `Mark as read`：条目 `read_time` 置为当前时间（已有则保留）且 `notified=1`，并取消该条通知；此路径直接写库，不触发同步链的已读上报。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotificationBroadcastReceiver.kt:43
- NW-A13 [backend] 划掉单条通知：该条目置 `notified=1`（仍未读）并取消该通知；划掉汇总通知：汇总内全部条目置 `notified=1` 并取消其通知。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotificationBroadcastReceiver.kt:55
- NW-A14 [backend] 点汇总通知：汇总内全部条目置 `notified=1`（不标已读），然后打开 Feed 页 `feed?id=<id>&tag=<tag>`：所有条目 tag 相同则取该 tag 否则空；所有条目同源则 id=该源，否则 tag 非空用 `ID_ALL_FEEDS(-10)`，再否则 `ID_UNSET(0)`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt:297
- NW-A15 [backend] 应用在前台期间监听待通知 id 集合：某条目不再待通知（被读/标记）时自动取消其通知；集合为空时取消汇总通知；集合非空时（延迟约 100ms）只重发汇总通知。应用进入后台即停止监听。鸿蒙实现：UIAbility onForeground/onBackground 订阅 RDB 变化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/notifications/NotificationsWorker.kt:31

## 域: 桌面小组件

- NW-A16 [backend] 小组件显示的源由全局单一设置决定（键 `pref_widget_last_feed_id` 默认 0、`pref_widget_last_feed_tag` 默认 ""，所有小组件实例共用）：id=-20 → 收藏文章；id>0 → 该源；tag 非空 → 该 tag；其余（含全部订阅 -10）→ 全部。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedItemStore.kt:79
- NW-A17 [backend] 小组件列表排除被屏蔽条目，按列表倒序最多 50 条，已读条目也包含在内。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:173
- NW-A18 [ui] 小组件标题栏左侧为应用图标与文字 `Feeder`（点按打开应用主界面），右侧依次为同步图标与设置图标。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:213
- NW-A19 [ui] 小组件每项显示标题（最多 2 行）与摘要（最多 2 行），有源图标时显示在左侧；已读条目文字以次要颜色显示，与未读可区分。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:278
- NW-A20 [backend] 点小组件条目打开应用内对应文章（深链 `https://feederapp.nononsenseapps.com/article/<id>`），该条目随之被标为已读且已通知。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:286
- NW-A21 [ui] 同步进行中（`syncWorkerRunning` 为真）及初次加载时，小组件列表区域显示 `Refreshing` 代替条目列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:155
- NW-A22 [on_device] 点小组件同步图标会以默认参数（非强制）触发一次订阅源同步，完成后小组件列表刷新；此路径不发布新条目通知。鸿蒙实现：卡片 message 事件 → FormExtensionAbility 转发同步任务，结束后 updateForm；差异：FormExtension 存活时长受限（降级候选）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:178
- NW-A23 [on_device] 点小组件设置图标打开 FeedWidgetSettings 页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:250
- NW-A24 [on_device] 数据库条目变化（同步新增、已读状态变化）或小组件源选择变化后，桌面小组件内容随之更新。鸿蒙实现：主进程在同步结束/读状态变化/选择变化时调用 `formProvider.updateForm`；差异：Glance 依赖 Flow 自动刷新，鸿蒙必须显式推送。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:445
- NW-A25 [backend] 小组件条目图标为订阅源图标，单张加载超时 1 秒，失败则不显示图标（不阻塞列表）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt:125

## 页面: FeedWidgetSettings

- NW-A26 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:138
- NW-A27 [ui] 页面列出与导航抽屉相同的条目：`All feeds`、`Saved articles`、各标签（可展开/收起显示其下源）、各订阅源（含未读数）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidgetSettingsActivity.kt:31
- NW-A28 [ui] 点标签的展开控件切换该标签展开状态，与主界面导航抽屉共享展开状态，不关闭页面。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidgetSettingsActivityViewModel.kt:22
- NW-A29 [backend] 点任一条目即保存为小组件源（id 与 tag，与当前相同时不重写），请求刷新所有小组件并立即关闭页面。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidgetSettingsActivity.kt:37
- NW-A30 [on_device] 冷重启后小组件仍显示上次选择的源（设置持久化）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:82
