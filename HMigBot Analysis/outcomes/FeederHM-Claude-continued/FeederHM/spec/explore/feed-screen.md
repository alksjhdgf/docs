# 探索：feed-screen（页面 Feed）

断言卡：`/Users/ppp/Projects/migrate-core/output/FeederHM/spec/cards/feed-screen.md`（FD-A01…FD-A51；ui 35 / backend 15 / on_device 1）。

路径前缀 `P = input/Feeder/app/src/main/java/com/nononsenseapps/feeder`。

## 1. 文件与职责

| 文件 | 行数 | 职责 |
|---|---|---|
| `P/ui/compose/feed/FeedScreen.kt` | 1926 | 三层 `FeedScreen` 重载 + `FeedListContent` + `FeedGridContent` + `FeedOrTag`/`FeedScreenType`/`PlainTooltipBox` |
| `P/ui/compose/feedarticle/FeedViewModel.kt` | 813 | `FeedViewModel`（DIAwareViewModel + `FeedListFilterCallback`）、`FeedState`/`FeedScreenViewState`、`FeedListFilter`、卡片翻译 |
| 关联（别区负责，此处只引用页面可见结果） | | `navdrawer/NavDrawer.kt`（ui-components）、`SwipeableFeedItemPreview.kt`/`FeedItemCard.kt`/`EditFeedDialog.kt`（feed-items）、`deletefeed/DeleteFeedScreen.kt`（edit-search）、`dialog/RenameTagDialog.kt`、`empty/NothingToRead.kt`、`pullrefresh/`（ui-components）、`archmodel/Repository.kt`/`FeedItemStore.kt`（repository） |

### FeedScreen 三层结构
1. `FeedScreen(navController, viewModel, navDrawerListState)` `FeedScreen.kt:176` —— 有状态入口：collect `viewState`、`translatedFeedCards`、两个分页流（条目 `currentFeedListItems`、抽屉 `pagedNavDrawerItems`）；注册 4 个 SAF 启动器（`:188-231`）；`BackHandler`（抽屉开时关抽屉 `:254`）；用 `ScreenWithNavDrawer` 包裹；把所有回调接到 ViewModel/导航。
2. `FeedScreen(viewState, …回调…)` `:521` —— 构造 `toolbarActions`（搜索栏/搜索按钮、筛选菜单、更多菜单）并按 `isCompactDevice()` 选 `FeedListContent` 或 `FeedGridContent`（`:1040`）。
3. `FeedScreen(viewState, …, toolbarActions, content)` `:1112` —— Scaffold：topBar=`SensibleTopAppBar`（enterAlways 折叠）、bottomBar=播客条或 TTS 条、FAB、下拉刷新、翻译模型下载进度条、三个对话框（删除/编辑/重命名标签）。

### Compose 层级（列表模式）
```
DismissibleNavigationDrawer (ScreenWithNavDrawer)
 └ Scaffold [pullRefresh → nestedScroll(topBar) → 水平导航栏 inset; contentWindowInsets=statusBars]
    ├ topBar: SensibleTopAppBar(title, nav=Menu 图标, actions)
    │    actions: [SearchBar 输入框] 或 [Search 按钮][Filter 按钮+DropdownMenu(非收藏视图)][MoreVert+DropdownMenu]
    ├ bottomBar: HideablePodcastPlayer | HideableTTSPlayer(可嵌 FAB)
    ├ FAB: AnimatedVisibility(scaleIn/Out 256ms) DoneAll
    └ Box(padding)
        ├ FeedListContent: AnimatedVisibility(空态 NothingToRead) / AnimatedVisibility(LazyColumn testTag=feed_list)
        │    items: "SpacerScrollTrick" + 分页条目(SwipeableFeedItemPreview [+HorizontalDivider]) + "SpacerForFab"(72dp，showFab 且无底栏时)
        ├ PullRefreshIndicator(TopCenter)
        └ TranslationModelDownloadProgress(TopCenter, 可选)
    + DeleteFeedDialog / EditFeedDialog / RenameTagDialog（条件显示）
```
网格模式：`LazyVerticalStaggeredGrid`，`StaggeredGridCells.Fixed(forceSingleColumn ? 1 : LocalDimens.feedScreenColumns)`（`:1683`），无分割线，无 SpacerScrollTrick/SpacerForFab。

## 2. 数据模型

### FeedScreenViewState（`FeedViewModel.kt:700`），由 `combine` 32 个流组成（`:456-544`）
| 字段 | 来源 | 默认（FeedState） | 备注 |
|---|---|---|---|
| currentFeedOrTag | repository.currentFeedAndTag → `FeedOrTag(id, tag)` | (ID_UNSET,"") | `FeedOrTag.isFeed = id>0`，`isSavedArticles = id==-20` (`FeedScreen.kt:1858`) |
| showFab | `haveVisibleFeedItems && pref_show_fab` | true | |
| showThumbnails, feedItemStyle, swipeAsRead, maxLines, showOnlyTitle, showReadingTime, markAsReadOnScroll, showTitleUnreadCount, isOpenDrawerOnFab, forceSingleColumn | SettingsStore | CARD / ONLY_FROM_END / 2 / false… | 定义归 settings-store |
| currentlySyncing | `syncWorkerRunning && repository.currentlySyncing` | false | `currentlySyncing` = feeds 表最新同步时间戳在 10s 内（`Repository.kt:403`） |
| haveVisibleFeedItems | `getCurrentFeedListVisibleItemCount() > 0`，初值 1 | true | 防加载前闪空态（`:106`） |
| feedScreenTitle | `ScreenTitle(title?, FeedType, unreadCount)` | ("",FEED,0) | `Repository.kt:567` |
| visibleFeeds | `FeedStore.getFeedTitles(feedId, tag)`：id>0→该源；tag→该标签；否则全部源 | [] | 用于编辑/删除对话框（收藏/全部视图都列出全部源） |
| showToolbarMenu / showFilterMenu / searchBarVisible | ViewModel MutableStateFlow + SavedStateHandle 键 `toolbarMenuVisible`/`filterMenuVisible`/`searchBarVisible` | false | searchBarVisible 还 OR `search.isNotEmpty()` (`:531`) |
| showEditDialog / showDeleteDialog / showRenameTagDialog | ViewModel MutableStateFlow（**不**存 SavedState） | false | |
| filter | `repository.feedListFilter`（`PrefsFeedListFilter`，unread 恒 true） | emptyFeedListFilter（仅 unread） | |
| search | `repository.search`（内存 MutableStateFlow） | "" | |
| isTTSPlaying / ttsLanguages / podcastPlayerState / isBottomBarVisible | TTSStateHolder、PodcastPlayerStateHolder | | `isBottomBarVisible = tts != STOPPED || podcast.isVisible` |
| translationModelDownloadProgress | `BergamotModelManager.downloadProgress` | null | |

### 常量
- `ID_UNSET=0`、`ID_ALL_FEEDS=-10`、`ID_SAVED_ARTICLES=-20`（`P/db/room/AppDatabase.kt:30-32`）。
- 标题类型判定（`Repository.kt:575-581`）：tag 非空→TAG；id∈{0,-10}→ALL_FEEDS；-20→SAVED_ARTICLES；否则 FEED。
- `REQUIRED_VISIBLE_TIME_FOR_MARK_AS_READ = 500L`（`FeedScreen.kt:1889`）；可见阈值 0.9。
- 分页：pageSize 10，initialLoadSize 100，prefetchDistance 100，jumpThreshold 100（`FeedItemStore.kt:99`）。
- 排序：`FEED_ITEM_LIST_SORT_ORDER_DESC = "primary_sort_time DESC, pub_date DESC, feed_items.id DESC"`，ASC 对称（`P/db/room/FeedItemDao.kt:573`）。
- `FeedItemCursor`（primarySortTime, pubDate, id）用于“上方/下方标已读”。

### 筛选 SQL（`FeedItemStore.kt:130 rawQueryFilter`）
```
block_time is null
[非收藏视图] AND ( <read 条件> [OR bookmarked=1 若 saved] )
  <read 条件>: unread&&!recentlyRead&&!read → read_time is null
               否则 (read_time is null or read_time >= ?)  ? = read ? EPOCH : minReadTime
<范围>: search 非空 → (plain_title LIKE %q% OR plain_snippet LIKE %q%)   ← 注意：替代而非叠加 feed/tag 范围
        收藏视图 → AND bookmarked = 1
        id>0 → AND feed_id IS ?
        tag 非空 → AND tag IS ?
```
- 收藏视图 minReadTime 强制 EPOCH（`Repository.kt:424`）。
- 筛选默认（`SettingsStore.kt:163`）：saved=false、recentlyRead=**true**、read=**true** → 默认显示全部条目（含已读）。
- 联动（`Repository.kt:185-199`）：关 recentlyRead⇒关 read；开 read⇒开 recentlyRead。
- `onlyUnread = unread && !saved && !recentlyRead && !read`；`onlyUnreadAndSaved = unread && saved && !recentlyRead && !read`（`FeedViewModel.kt:809`）。

### minReadTime 语义
- 切换 feed/tag（值变化时）与 Mark all as read 后设为 now（`Repository.kt:132,606`）。作用：“最近已读”筛选只显示本次浏览会话中读过的。
- 滑动标已读在仅未读筛选下写 `read_time = minReadTime - 1s`，使条目立即掉出 “recently read” 范围（`Repository.kt:509`）。

## 3. 行为逐项

### 顶栏
- 标题拼接：`title + " (N)"`（`R.string.title_unread_count = "(%1$d)"` 不可翻译），条件见 FD-A03。title 为 null 时显示 ""。
- 导航图标：`Icons.Default.Menu`，cd `Open navigation drawer`，切换抽屉。
- 搜索：`SearchBar(expanded=false)` 内 `SearchBarDefaults.InputField`，onQueryChange/onSearch 都调用 `repository.searchFor`；trailing `Close`（cd `Cancel search`）+ Esc 键：隐藏并清空。
- 筛选菜单（`:684-821`）：Unread（enabled=false，恒勾选）、Saved、Recently read、Read；每项 Role.Checkbox + stateDescription selected/not selected；末尾 0 高度隐藏项 `Close menu`（TalkBack 用）。点击后立即关闭菜单。
- 更多菜单（`:836-1033`）——**确定性清点**：
  1. `Mark all as read`（DoneAll）
  2. ── 分隔
  3. `Sync feeds`（Refresh）
  4. ── 分隔
  5. `Add feed`（Add）→ SearchFeed
  6. `Edit feed`（Edit）→ visibleFeeds.size==1 ? EditFeed(id) : EditFeedDialog
  7. `Delete feed`（Delete）→ DeleteFeedDialog
  8. 条件：`feedScreenTitle.type == TAG && !currentFeedOrTag.isFeed` → ── 分隔 + `Rename tag`
  9. ── 分隔
  10. `Import feeds from OPML`
  11. `Export feeds to OPML`
  12. `Import saved articles`
  13. `Export saved articles`
  14. ── 分隔
  15. `Settings`
  16. 隐藏 0 高 `Close menu`
  注意：Edit/Delete 在 All feeds / Saved articles 视图下也显示（列出全部源）；若无订阅源，visibleFeeds 为空 → Edit 弹空对话框。

### 下拉刷新（`:1139-1202`）
- `manuallyTriggeredRefresh`（rememberSaveable）|| currentlySyncing ⇒ 指示器显示。
- 当 currentlySyncing 变 true 时清除手动标志；手动标志设置后 5s 无论如何清除。
- onRefresh → `requestImmediateSyncOfCurrentFeedOrTag()` → `runOnceRssSync(feedId, feedTag, forceNetwork=true, triggeredByUser=true)`（JobScheduler 一次性任务，`P/background/RssSyncJob.kt:67`）。
- 修饰顺序注释：pullRefresh 必须在 nestedScroll 之前（`:1285`）。

### FAB 与底栏
- FAB 仅在 `showFab && bottomBarVisibleState.isIdle && !targetState` 时单独显示；底栏可见时 FAB 传入 `HideableTTSPlayer(floatingActionButton=…)`（播客条不嵌 FAB）。
- 列表在底栏不可见时内容 padding = 底部导航栏 inset（CARD/COMPACT_CARD 再加水平 margin 16dp/32dp）；底栏可见时 padding 0。

### 列表条目交互（页面层面）
- 每项：`translatedFeedCards.merge(item)`；`LaunchedEffect` 触发 `translateFeedCardIfNeeded`。
- 点击 → `openArticle`（`FeedViewModel.kt:394`）：`getArticleOpener`（源级 `PREF_VAL_OPEN_WITH_*` 否则全局 itemOpener）；CUSTOM_TAB/DEFAULT_BROWSER 需链接非空，否则落到阅读器；阅读器路径先 `setCurrentArticle`+`setIsArticleOpen(true)` 再导航 `ArticleDestination`；最后 `markAsRead`。
- 长按菜单（FeedItemCard.kt:270-354，归 feed-items）：Open in reader / Open in custom tab / Open in default browser / Save article|Stop saving article / Mark the above as read / Mark the below as read / Share。
- 滑动（`swipeEnabled = !isScrollInProgress`）→ `markAsReadOnSwipe` 分支见 FD-A42。
- 滚动标已读：`trackVisibility(0.9f)` + itemCoroutineScope 延时 500ms；`filter.unread` 恒真（PrefsFeedListFilter），故实际路径总是“置 itemWasVisible，DisposableEffect onDispose 时标已读”——即条目离开组合（滚出视口）时才标记。`else` 分支（立即标记）在当前设置模型下不可达（仅 emptyFeedListFilter/测试）。
- 分享：`Intent.ACTION_SEND` text/plain，`EXTRA_TEXT=stripTrackingParameters(link)`（link 非空时），`EXTRA_TITLE=title`，chooser，`openAdjacentIfSuitable=false`。
- 动画：同步进行中禁用 `animateItem`（防止滚动跳动）。
- SpacerScrollTrick：首项为空 Spacer，使列表停在顶部时新条目插入后仍停在顶部（LazyColumn 行为；鸿蒙 List 需等价策略）。
- `LazyPagingItems.rememberLazyListState()` workaround：itemCount==0 时返回临时状态，避免重建后滚动位置丢失（`:1875`）。

### ViewModel 写操作（均在 `ApplicationCoroutineScope`，离开页面仍完成）
deleteFeeds、renameTag、markAllAsRead、markAsUnread、markAsRead、markAsReadOnSwipe、markBeforeAsRead、markAfterAsRead、setBookmarked（`FeedViewModel.kt:127-177`）。openArticle* 用 viewModelScope。

### 卡片翻译（`FeedViewModel.kt:201-345, 740-782`）
- 配置 = (translateArticlePreviewsByDefault, translationApiSettings, preferredTranslationLanguage.trim())；`isActive = enabled && settings.canUseAsTranslationApi && targetLanguage 非空`。
- 配置变化：清 inFlight、清条目、generation+1（触发每项 LaunchedEffect 重跑）。
- 单项：ID_UNSET 跳过；已完成跳过；去重 key=(itemId,title,snippet,settings,lang)；先读缓存显示；本地翻译且 `!canTranslateWithoutBergamotDownload` 跳过；调用 `translateFeedListItem`；结果仅在配置未变时写入；每 itemId 只保留最新一条。
- merge：译文空白回退原文。

### TTS/播客回调（归 readaloud-podcast）
`ttsPlay` 先停播客，读取当前文章（blob 或全文 blob）→ `htmlToAnnotatedString` → `ttsStateHolder.tts`；`onCleared` 时 `ttsStateHolder.shutdown()`。播客 seek ±10_000ms。

### 导入/导出（结果见 FD-A28..31；实现归 feed-parser/opml、export）
- OPML 导入：`importOpml` 解析后**总是** `runOnceRssSync(triggeredByUser=true)`；结果 Left 或异常 → toast `Failed to import OPML`（异常还 toast 异常消息）（`P/model/opml/OpmlActions.kt:67`）。
- 导出异常 → toast 失败文案 + 异常消息。
- 文件名用 `LocalDate.now()`（ISO yyyy-MM-dd）与 `LocalTime.now().toSecondOfDay()`。

### 文案 key（res/values/strings.xml）
`navigation_drawer_open`=Open navigation drawer；`search_verb`=Search；`cancel_search`=Cancel search；`filter_noun`=Filter；`unread_adjective`=Unread；`saved_adjective`=Saved；`recently_read_adjective`=Recently read；`read_adjective`=Read；`open_menu`=Open menu；`close_menu`=Close menu；`mark_all_as_read`=Mark all as read；`synchronize_feeds`=Sync feeds；`add_feed`=Add feed；`edit_feed`=Edit feed；`delete_feed`=Delete feed；`rename_tag`=Rename tag；`import_feeds_from_opml`/`export_feeds_to_opml`/`import_saved_articles`/`export_saved_articles`；`action_settings`=Settings；`all_feeds`=All feeds；`saved_articles`=Saved articles；`title_unread_count`=(%1$d)；`empty_feed_top`=Nothing to read here. Would you like to…；`empty_feed_open`=<annotation style="link">Open</annotation> another feed?；`empty_feed_add`=<annotation style="link">Add</annotation> more feeds?；`failed_to_import_OPML`、`failed_to_export_OPML`、`failed_to_import_saved_articles`、`failed_to_export_saved_articles`；`no_article_link_custom_tab`=Unable to open article in custom tab；`no_article_link_browser`=Unable to open article in browser。

### 布局/尺寸（不入卡，供实现）
- `isCompactDevice()` = height==Compact || width==Compact（`P/ui/compose/utils/WindowSize.kt:69`）。
- phone：margin/gutter 16dp，1 列；tablet：margin/gutter 32dp，列数 >1360dp→4，>1028dp→3，否则 2；tv：3 列（`P/ui/compose/theme/Dimensions.kt:62-105`）。
- 列表间距：CARD/COMPACT_CARD spacedBy(margin)，COMPACT/SUPER_COMPACT 0 + 1dp 分割线（最后一项无）。
- FAB 占位 72dp。

## 4. 平台模型差异（结果契约 / 鸿蒙实现 / 差异）
| 项 | 结果契约 | 鸿蒙实现建议 | 差异 |
|---|---|---|---|
| Paging3 + Room 原生 SQL | 按筛选/排序/搜索分页，数据变更自动刷新 | relationalStore + 自建分页 DataSource（LazyForEach + IDataSource），监听写操作后 notifyDataReload | 无 Room invalidation tracker；`markAsReadRaw` 是原生 UPDATE 后手动 `refreshVersionsAsync`，鸿蒙需写后显式通知列表 |
| SAF CreateDocument/OpenDocument | 让用户选择位置导入/导出 | `picker.DocumentViewPicker` save/select | MIME 过滤语义不同（鸿蒙按后缀 fileSuffixFilters） |
| ApplicationCoroutineScope | 写操作离开页面仍完成 | 应用级 Promise/TaskPool，不绑定页面生命周期 | — |
| JobScheduler runOnceRssSync | 用户触发立即同步（强制网络） | 前台直接执行同步任务（taskpool）+ 进度标志 | 无一次性 Job 约束；需自行判断网络 |
| SavedStateHandle | 菜单/搜索栏状态跨重建恢复 | AppStorage/LocalStorage 或 @StorageProp | 鸿蒙无同等进程重建机制，影响小 |
| Custom Tabs | 应用内浏览器打开文章 | Web 组件页或 `openLink`（appLinkingOnly=false） | 无 Custom Tabs，见降级候选 |
| Intent.ACTION_SEND chooser | 系统分享 | `@kit.ShareKit` systemShare | — |
| trackVisibility / DisposableEffect | 可见 90% 500ms 后滚出时标已读 | List `onVisibleAreaChange([0.9])` + 定时器 + `onDisappear`/滚动索引判断 | 需复刻“离开时才标”与“快速划过取消” |
| WindowSizeClass | 紧凑→列表，否则瀑布流 | `@ohos.mediaquery`/断点 + WaterFlow(columnsTemplate) | — |
| BackHandler | 抽屉开时返回关抽屉 | Navigation `onBackPressed`/NavDestination onBackPressed 拦截 | — |
| Toast | 失败提示 | `promptAction.showToast` | — |

## 5. 降级候选
- `Open in custom tab`：鸿蒙无 Chrome Custom Tabs，降级为应用内 Web 页或系统浏览器。
- 动态快捷方式（删除时 removeDynamicShortcuts，进入 feed 时 addDynamicShortcut）：鸿蒙 shortcut 仅静态配置，动态快捷方式能力有限 → 可降级为 no-op。
- TalkBack 隐藏“Close menu”项：鸿蒙无障碍差异，可省略。
- `openAdjacentIfSuitable` 分屏打开：无对应。
- Bergamot 本地翻译模型下载进度（WebView WASM，归 translation 区）。

## 6. 风险 / 坑点
1. **搜索是全局的**：search 非空时 `rawQueryFilter` 的 `when` 走 search 分支，完全忽略 feed/tag/收藏范围（`FeedItemStore.kt:159`）。看似 bug 但为现有行为，实现必须照搬（标题仍显示当前 feed）。
2. **筛选默认显示已读**：read/recentlyRead 默认 true，且 Unread 项不可取消；新实现易误设默认“仅未读”。
3. **minReadTime 机制**贯穿：切换 feed、全部已读都会重置；滑动写 minReadTime−1s；收藏视图强制 EPOCH。漏掉会导致“recently read”行为错乱或滑动后条目不消失。
4. **上下方标已读的方向**：markBefore 用 `descending = sort != NEWEST_FIRST`，markAfter 用 `descending = sort == NEWEST_FIRST`（`Repository.kt:621,638`）；三元组游标比较需手写（SQLite 不支持 tuple 比较）。
5. **刷新指示器 5s 超时与 currentlySyncing=worker 运行 && 10s 内时间戳** 的双条件，否则会无限转圈或闪烁。
6. viewState 由 32 个流 combine 而成，鸿蒙需拆分为多个 @State/@StorageLink 避免全量重渲染。
7. 列表保持顶部（SpacerScrollTrick）与重建后滚动位置 workaround：鸿蒙 List 插入头部时默认行为不同，需验证。
8. Edit/Delete 菜单在 All/Saved 视图作用于全部订阅源，且无订阅源时 Edit 会弹出空对话框——保持一致即可。
9. FAB 在底栏可见时嵌入 TTS 条但不嵌入播客条（播客条可见时 FAB 不显示）。
