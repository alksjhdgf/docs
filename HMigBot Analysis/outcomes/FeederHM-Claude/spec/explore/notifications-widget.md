# 探索文档：notifications-widget（通知 + 桌面小组件 + FeedWidgetSettings 页）

断言前缀：NW。断言卡：`spec/cards/notifications-widget.md`。

## 1. 文件清单（$SRC = input/Feeder）

| 文件 | 行数 | 作用 |
|---|---|---|
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotifications.kt | 427 | 通知构造/发布/取消：`notify()`、`cancelNotification(s)`、渠道、单条通知、汇总通知、各种 Intent 构造 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/RssNotificationBroadcastReceiver.kt | 67 | 广播接收器：`mark_as_notified`（划掉通知）/`mark_as_read`（通知按钮"标为已读"） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/notifications/NotificationsWorker.kt | 83 | 前台期间监听"待通知条目"Flow：撤销已不在列表中的通知、刷新汇总通知 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidget.kt | 401 | Glance 桌面小组件（标题栏+同步+设置按钮+文章列表） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidgetReceiver.kt | 8 | GlanceAppWidgetReceiver |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidgetSettingsActivity.kt | 54 | 小组件"选择订阅源"页（路由名 FeedWidgetSettings） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/widget/FeedWidgetSettingsActivityViewModel.kt | 30 | 页 VM：导航抽屉分页数据 + 写入小组件源选择 |
| input/Feeder/app/src/main/res/xml/feed_app_widget_info.xml | 11 | appwidget-provider 元数据 |

协作方（别区，仅引用）：
- 调用 `notify(ctx)`：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:58（每次后台/手动同步 Job 的 finally 中）。
- `NotificationsWorker.runForever()/stopForever()`：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/MainActivity.kt:41 / :45（onStart/onStop），DI 单例绑定 FeederApplication.kt:214。
- 通知代理 Activity：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/OpenLinkInDefaultActivity.kt（路由 OpenLinkInDefault）。
- 深链：`DEEP_LINK_BASE_URI = "https://feederapp.nononsenseapps.com"`（util/ContextExtensions.kt:109-110）；导航里 `/feed?id={id}&tag={tag}` 与 `/article/{itemId}` 两个 uriPattern（ui/compose/navigation/ 下）。打开文章深链 → NavigationDeepLinkViewModel.setCurrentArticle → `repository.markAsReadAndNotified(itemId)`（NavigationDeepLinkViewModel.kt:26）。
- 通知权限 UI：Settings.kt:1278 `NotificationsSetting`、EditFeedScreen.kt:162（各自区负责，API≥33 才请求）。
- DAO：FeedDao.kt:130 `loadFeedIdsToNotify`；FeedItemDao.kt:328 `loadItemsToNotify`、:389/:395 `markAsNotified`、:420 `markAsReadAndNotified`、:538 `getFeedItemsNeedingNotifying`、:173/186/198/211 `widgetPreviews*`。
- 设置：SettingsStore.kt:82-103 `currentWidgetFeedAndTag`，键 `pref_widget_last_feed_id` / `pref_widget_last_feed_tag`（SettingsStore.kt:655-656）。
- 常量：`ID_UNSET=0`、`ID_ALL_FEEDS=-10`、`ID_SAVED_ARTICLES=-20`（db/room/AppDatabase.kt:30-32）。
- Manifest：AndroidManifest.xml:16 POST_NOTIFICATIONS；:158 receiver RssNotificationBroadcastReceiver（未 exported）；:161-165 OpenLinkInDefaultActivity（exported, singleInstance, 独立 taskAffinity）；:179-187 FeedWidgetReceiver（APPWIDGET_UPDATE + meta-data）；:190 FeedWidgetSettingsActivity（exported=false）。

## 2. 数据模型与"待通知"判定

- 订阅源级开关 `feeds.notify`（1=开）。
- 条目字段 `feed_items.notified`（0/1）、`read_time`（null=未读）、`block_time`（非 null=被屏蔽）。
- 待通知条目（发布用，RssNotifications.kt:415 → FeedItemDao.kt:317-328）：`feed_id IN (notify=1 的源) AND notified=0 AND read_time IS NULL AND block_time IS NULL`，按列表倒序排序 `FEED_ITEM_LIST_SORT_ORDER_DESC`，**LIMIT 20**（注释：过多会崩溃）。无 notify=1 的源时直接空列表。
- 待通知 ID 流（NotificationsWorker 用，FeedItemDao.kt:529-538）：同条件但无 LIMIT、无排序，只返回 id，Room Flow 随表变化重发。
- 何时置 notified=1：
  - 划掉单条/汇总通知（delete intent → receiver `mark_as_notified`）。
  - 通知按钮"Mark as read"（receiver `mark_as_read` → `markAsReadAndNotified`）。
  - 点通知打开（OpenLinkInDefaultActivity → `markAsReadAndNotified`；汇总点击 → `markAsNotified(ids)`；READER 方式走深链 → NavigationDeepLinkViewModel → `markAsReadAndNotified`）。
  - 所有"标为已读"类 DAO 写法（markAsRead/markAllAsRead*）同时置 notified=1（FeedItemDao.kt:331-367）。
  - **发布通知本身不置 notified**：因此每次同步结束 `notify()` 都会把仍未处理的（最多 20 条）重新 post（同 id 覆盖，单条为 silent）。

## 3. 通知发布 `notify(appContext, updateSummaryOnly=false)`（RssNotifications.kt:56-94）

1. 无 POST_NOTIFICATIONS 授权 → 直接返回（不报错、不发布）。
2. `createNotificationChannel`：id `feederNotifications`，名称 `notification_channel_name`="Unread feeds"，描述 `notification_channel_description`="Notifications are only shown for unread items in configured feeds"，IMPORTANCE_LOW。每次调用都会 create（幂等更新）。
3. 取待通知条目（≤20）。为空则什么都不做（**不会**主动清除旧通知）。
4. 非 updateSummaryOnly：对每条 `nm.notify(item.id.toInt(), singleNotification)`。
5. 总是 post 汇总通知 id `SUMMARY_NOTIFICATION_ID = 2_147_483_646`。
6. 捕获 TransactionTooLargeException 仅记日志。

### 3.1 公共 builder（:403-413）
小图标 `R.drawable.ic_stat_f`、大图标 `R.mipmap.ic_launcher`、autoCancel=true、category SOCIAL、priority LOW。

### 3.2 单条通知（:138-220）
- 标题 `item.plainTitle`；正文 `item.feedDisplayTitle`；BigTextStyle（bigText=源名，bigContentTitle=标题）。
- group `com.nononsenseapps.feeder.ARTICLE`，GROUP_ALERT_SUMMARY，`setSilent(true)`，number=1。
- 删除（划掉）→ broadcast `mark_as_notified`，data=`URI_FEEDITEMS/<id>`，extra `extra_feeditem_id_array=[id]`，requestCode 0。
- 点击 contentIntent（:222-245，按 `repository.getArticleOpener(itemId)`：源级 `open_articles_with` 覆盖全局默认，Repository.kt:536-542）：
  - link==null 或 READER → `ACTION_VIEW https://feederapp.nononsenseapps.com/article/<id>` 到 MainActivity（NEW_TASK）。
  - CUSTOM_TAB → OpenLinkInDefaultActivity，data=`URI_FEEDITEMS/<id>?link=<link>`，action=`com.nononsenseapps.feeder.OPEN_IN_CUSTOM_TAB`。
  - DEFAULT_BROWSER → OpenLinkInDefaultActivity，同 data，ACTION_VIEW。
- 动作按钮（顺序固定，最多 3 个）：
  1. 有 `enclosureLink` → `open_enclosed_media`="Open enclosed media"（图标 notification_play_circle_outline），打开 OpenLinkInDefaultActivity(link=enclosure)。
  2. opener != DEFAULT_BROWSER 且 link!=null → `open_link_in_browser`="Open link in web browser"（图标 notification_open_in_browser），OpenLinkInDefaultActivity(link)。
  3. 总是 → `mark_as_read`="Mark as read"（图标 notification_check），broadcast `mark_as_read`，data=`URI_FEEDITEMS/<id>`。
- PendingIntent 区分靠不同 URI（注释"Important to keep the URI different"），requestCode=item.id.toInt()。

### 3.3 汇总通知（:282-359）
- 标题 `updated_feeds`="Updated feeds"；正文 = 去重后的源名以 ", " 连接；InboxStyle 每条一行 `"<源名> — <标题>"`（U+2014）。
- groupSummary=true，number=条目数；未设 silent（但渠道 LOW + GROUP_ALERT_SUMMARY）。
- 点击：深链 `https://feederapp.nononsenseapps.com/feed?id=<id>&tag=<urlEncode(tag)>` 先到 OpenLinkInDefaultActivity（extra `items_to_mark_as_notified`=全部 id）→ 标记 notified → 转发 MainActivity 打开该 Feed。
  - tag：所有条目 tag 相同则取之（可能是 ""），否则 ""。
  - id：所有条目同一源 → 该 feedId；否则 tag 非空 → `ID_ALL_FEEDS(-10)`（tag 优先）；否则 `ID_UNSET(0)`（"默认最后打开的"）。
- 删除：broadcast `mark_as_notified` + 全部 id 数组（无 data，requestCode 0）。

### 3.4 取消
`cancelNotifications(ctx, ids)`：无权限直接返回；对每个 id `nm.cancel(id.toInt())`（:101-118）。

## 4. 广播接收器（RssNotificationBroadcastReceiver.kt）
- `mark_as_notified`：ids 非空 → `dao.markAsNotified(ids)` + 取消这些通知。
- `mark_as_read`：id 取 `intent.data.lastPathSegment`（失败→0）→ `dao.markAsReadAndNotified(id)`（read_time=coalesce(read_time,now), notified=1）+ 取消该通知。
- **注意**：直接用 DAO，不经过 `Repository.markAsReadAndNotified`，因此**不会**触发 `runOnceSyncChainSendRead`（同步链已读上报）；而 App 内/OpenLinkInDefault 的路径会（Repository.kt:509-525）。
- 用 GlobalScope + Dispatchers.Default 异步执行（无 goAsync）。

## 5. NotificationsWorker（前台期间）
- MainActivity.onStart 启动、onStop 取消（仅应用可见时运行）。
- 收 `getFeedItemsNeedingNotifying()`；`runningReduce(prev,current)`：current 为空 → 取消汇总通知；prev 中不在 current 的 id → 逐个取消通知（即：用户在 App 内读掉/标记后，对应系统通知自动消失）。
- `collectLatest`：延迟 100ms，current 非空 → `notify(updateSummaryOnly=true)` 仅重发汇总通知。
- 单测：input/Feeder/app/src/test/java/com/nononsenseapps/feeder/notifications/NotificationsWorkerTest.kt（`cancelsNotificationsForItemsNoLongerPresent`）。

## 6. OpenLinkInDefaultActivity（通知代理，路由 OpenLinkInDefault；细节属 app-shell 区）
- data host == `feederapp.nononsenseapps.com` 且 lastPathSegment=="feed"：后台 `markAsNotified(ids)` → 以同 URI 启动 MainActivity。
- 否则：id=lastPathSegment，link=query `link`；协程 `markAsReadAndNotified(id)` + 取消通知；link 非空时按 action 用 Custom Tab 或浏览器打开（openAdjacentIfSuitable=false）；失败 Toast `no_activity_for_link`="Install something to open this link with first"。
- 无 UI，立即 finish。

## 7. 桌面小组件 FeedWidget（Glance）

### 7.1 元数据（res/xml/feed_app_widget_info.xml）
minWidth 110dp、minHeight 40dp、targetCell 3×2、可横纵缩放（max 1000dp）、initialLayout glance 默认 loading。**没有 `android:configure`**：放置小组件时不弹配置页；配置只能点小组件上的齿轮。`updatePeriodMillis` 未设置（无系统定时刷新）。

### 7.2 数据
- `Repository.getCurrentWidgetFeedListItems()`（Repository.kt:445）= `currentWidgetFeedAndTag.flatMapLatest` → `FeedItemStore.getWidgetFeedListItems`（FeedItemStore.kt:79-88）：
  - feedId == -20 → 收藏（bookmarked=1）
  - feedId > 0 → 指定源
  - tag 非空 → 指定 tag
  - 否则（含 ID_ALL_FEEDS=-10、ID_UNSET=0）→ 全部
  - 均排除 block_time 非空，倒序，**LIMIT 50**；**不过滤已读**（已读条目也显示，仅颜色变淡）。
- 小组件选择是**全局单一**设置（SharedPreferences `pref_widget_last_feed_id`/`pref_widget_last_feed_tag`，默认 0/""=全部），所有小组件实例共用，不区分 appWidgetId。
- `FeedWidgetItem`（FeedWidget.kt:71-85）：id,title,snippet,feedTitle,unread,pubDate,image(Bitmap?),link,bookmarked,feedImageUrl,primarySortTime,rawPubDate,wordCount。
- 图片：用**源图标** `feedImageUrl`（非文章图）经 Coil 加载 200×200 FIT、RGB_565、单张超时 1s，失败为 null（不显示图）。
- `WidgetState`：`Syncing` | `Ready(items)`。`combine(syncWorkerRunning, items)`：syncWorkerRunning=true → Syncing；起始先 emit Syncing。

### 7.3 布局（FeedWidget.kt:192-325）
Column(fillMaxHeight, background=background, padding 4dp)：
- 标题栏 Row：[ic_stat_f 图标 + 文本 `widget_title`="Feeder"]（整体可点 → 启动 MainActivity）— Spacer — [ic_stat_sync 图标，点 → 直接 `rssLocalSync.syncFeeds()`（默认参数：非强制，最小源年龄 5 分钟）] — [ic_settings 图标，点 → FeedWidgetSettingsActivity]。
- Syncing：居中文本 `widget_refreshing`="Refreshing"（替代列表）。
- Ready：LazyColumn（start 12dp），每项一个卡片 Row（背景 surfaceVariant，padding 8dp）：可选源图标 + Column[标题 maxLines=2 粗体16sp；snippet maxLines=2 12sp]。未读 → onSurface；已读 → onSurfaceVariant 且图标被着色（视觉变灰）。不显示源名/日期。
- 点卡片 → `ACTION_VIEW https://feederapp.nononsenseapps.com/article/<id>`（隐式 Intent，由 MainActivity 深链接管 → 打开文章并标为已读+已通知）。
- 空列表时无"空态"文案（只有标题栏）。
- 主题：Material3 light/dark 默认色（非 App 动态色）。
- 注意：小组件触发的同步**不经过 RssSyncJob**，因此同步后**不会调用 notify()**（不会弹通知）。
- 刷新机制：Glance 会话存活时通过 Flow 实时更新；除 FeedWidgetSettings 页外**没有任何地方调用 updateAll**（全仓 grep 仅 FeedWidgetSettingsActivity.kt:44）。

## 8. 页面 FeedWidgetSettings（FeedWidgetSettingsActivity）
- enableEdgeToEdge（:26）；Surface 内直接复用导航抽屉列表 `ListOfFeedsAndTags`（NavDrawer.kt:129），`contentPadding = WindowInsets.systemBars`（避让状态栏/导航栏），testTag `feedsAndTags`。无顶栏、无标题、无返回按钮（系统返回关闭）。
- 列表内容 = `repository.getPagedNavDrawerItems()`：All feeds（`all_feeds`）、Saved articles（`saved_articles`）、可展开 tag（点箭头 `toggleTagExpansion`，与主界面抽屉共享展开状态）、子源/顶层源（含未读数与图标）；第 3 项若为源项上方有分隔线。
- 点任意项 → `setCurrentWidgetFeedAndTag(item.id, item.tag)`（值相同则不写）→ 在 viewModelScope 启动 updateAll（对每个 glanceId 调一次 updateAll，冗余）→ 立即 `finish()`。
  - 风险：finish 后 viewModelScope 被取消，updateAll 可能未执行；实际刷新主要依赖 Glance 会话中对 `currentWidgetFeedAndTag` StateFlow 的收集。

## 9. 鸿蒙映射建议（结果契约 / 实现 / 差异）

| Android | 鸿蒙 | 差异 |
|---|---|---|
| NotificationChannel(LOW) | `notificationManager.addSlot(SlotType.CONTENT_INFORMATION 或 OTHER_TYPES)` | 渠道名/描述文本无法自定义（slot 类型固定）→ 降级 |
| POST_NOTIFICATIONS 检查 | `notificationManager.isNotificationEnabled()` / `requestEnableNotification()` | 无权限时静默跳过，契约一致 |
| NotificationCompat 单条 BigText | `NotificationRequest` + `NOTIFICATION_CONTENT_LONG_TEXT`，id=itemId | id 需 int32，同 Android toInt 截断 |
| group + groupSummary | `groupName` 相同；鸿蒙无"摘要通知"概念 | 汇总通知可作为普通 MULTILINE 通知（id 2147483646）发布；降级候选 |
| InboxStyle | `NOTIFICATION_CONTENT_MULTILINE`（lines） | 行数上限需实测 |
| setNumber | `badgeNumber` / `setBadgeNumber` | |
| contentIntent PendingIntent.getActivity | `wantAgent`（START_ABILITY，带 want 参数 itemId/link/action） | 代理 Activity 改为 UIAbility 内路由/无界面处理 |
| 动作按钮 PendingIntent.getBroadcast | `actionButtons[].wantAgent`（SEND_COMMON_EVENT 或 START_ABILITY） | 鸿蒙最多 3 个按钮，正好满足；后台广播处理需静态订阅者(StaticSubscriberExtensionAbility，受限)或拉起 Ability |
| deleteIntent | `removalWantAgent` | 需实测划掉是否可靠触发 |
| BroadcastReceiver + GlobalScope | 公共事件订阅 / Ability 内 TaskPool | 进程可能未存活，静态订阅受系统白名单限制 → 降级候选 |
| NotificationsWorker（前台监听） | UIAbility onForeground/onBackground 中订阅 RDB 变化 | 等价 |
| Glance AppWidget | FormExtensionAbility + ArkTS 卡片(form_config.json) | 卡片内 List、点击 `postCardAction`（router/message/call） |
| 卡片 Flow 实时更新 | `formProvider.updateForm` 由主进程在同步结束/读状态变化/选择变化时推送 | 必须显式推送，否则不刷新 |
| 卡片内同步按钮 | `postCardAction message` → FormExtensionAbility.onFormEvent → 触发同步 | FormExtension 生命周期短（约 10s）→ 可能需转交后台任务；降级候选 |
| Coil Bitmap 图标 | 卡片图片需 `formImages` 传 fd / memory:// | 复杂度高；降级候选：不显示图标或用占位 |
| 设置页 Activity | UIAbility 页 FeedWidgetSettings（卡片 router 跳转）；或 form 配置页 | 全局单选择，与 formId 无关（保持） |

## 10. 降级候选
1. 通知渠道名/描述（`Unread feeds` / 描述文案）：鸿蒙 slot 不可命名。
2. 分组摘要通知 + GROUP_ALERT_SUMMARY 语义：改为独立多行通知或依赖系统按应用聚合。
3. 通知"划掉→标记已通知"（removalWantAgent）可靠性需真机验证；不可靠时只在打开/已读时标记。
4. 通知按钮"Mark as read"在应用未运行时的后台处理（公共事件静态订阅受限）→ 改为拉起无界面 Ability 或拉起 App。
5. Custom Tab 打开方式：鸿蒙无 Custom Tab，CUSTOM_TAB 退化为应用内 Web 组件或系统浏览器。
6. 小组件源图标图片（formImages）。
7. 小组件内同步按钮（FormExtension 时限）。
8. 小组件实时刷新（Glance Flow）→ 显式 updateForm 推送；"Refreshing"状态需主进程在同步开始/结束各推一次。
9. 小组件缩放（1000dp）→ 鸿蒙固定规格 2*2/2*4/4*4 等，选 2*4/4*4。

## 11. 风险 / 注意点
- 每次同步都重 post 所有未处理通知（silent），鸿蒙实现需保持"同 id 覆盖、不重复响铃"。
- Receiver 的已读不触发同步链上报（与 App 内已读不同）— 若要严格复刻需保留此差异（或视为 bug 可统一）。
- 小组件同步不弹通知；后台 Job 同步才弹。
- 小组件列表包含已读条目，最多 50 条；通知最多 20 条。
- 汇总点击 deepLinkId/tag 推导规则（§3.3）容易写错。
- FeedWidgetSettings 页 finish 与 updateAll 的竞态；鸿蒙需确保选择后卡片立即刷新。
- int 截断：通知 id = itemId.toInt()，汇总 id 固定 2147483646，条目 id 极大时可冲突（理论）。
