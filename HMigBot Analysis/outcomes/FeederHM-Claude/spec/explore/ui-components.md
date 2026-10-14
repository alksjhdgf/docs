# 探索文档：ui-components（通用 UI 组件域）

断言前缀：`UC`；断言卡：`spec/cards/ui-components.md`。
锚点根：`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/`（下文简写 `ui/compose/`）。

## 0. 清点（10 个子目录，22 个 .kt，约 3.6k 行）

| 目录 | 文件（行数） | 角色 |
|---|---|---|
| components | AutoCompleteText(84) BottomAppBar(156) ConfirmDialog(54) OkCancel(113) TranslationProgressContent(70) Utils(19) | 复用小组件 |
| dialog | EditableListDialog(210) FeedNotificationsDialog(165) RenameTagDialog(57) | 通用对话框 |
| empty | NothingToRead(117) | Feed 空态 |
| layouts | Table(274) | HTML 表格自定义 Layout |
| modifiers | KeyEvents(40) TrackVisibility(107) | 按键拦截 / 可见性追踪 |
| pullrefresh | PullRefresh(98) PullToRefreshIndicator(227) PullToRefreshState(189) | fork 自 material PullRefresh（M3 化） |
| theme | Color(97) Dimensions(138) SensibleTopAppBar(53) Theme(311) Typography(337) | 主题/深色/动态色/字体/响应式尺寸 |
| icons | CustomFilled(10) TextToSpeech(86) | 自定义矢量图标（朗读） |
| coil | RestrainedFitScaling(95) TintedVectorPainter(24) | 图片缩放策略 / 着色占位 painter |
| navdrawer | NavDrawer(559) DrawerItemWithUnreadCount(131) | 抽屉内容：全部/收藏/标签树/订阅源 + 未读数 |

调用方速查（grep 结果）：
- `ScreenWithNavDrawer`、`NothingToRead`、`RenameTagDialog`、`PullRefreshIndicator`/`pullRefresh`、`trackVisibility`、`TranslationProgressContent` → `ui/compose/feed/FeedScreen.kt`（TranslationProgressContent 亦用于 `feedarticle/ArticleScreen.kt`）
- `EditableListDialog`、`FeedNotificationsDialog` → `settings/Settings.kt`（屏蔽词 `Filters`、`Notify for new items`）
- `ConfirmDialog` → `sync/LeaveSyncChainDialog.kt`（唯一调用者）
- `OkCancelWithContent/NonScrollable` → `editfeed/EditFeedScreen.kt`、`ompl/OpmlImportScreen.kt`
- `AutoCompleteResults` → `editfeed/EditFeedScreen.kt`（标签补全）
- `PaddedBottomAppBar` → `feedarticle/PodcastPlayerBar.kt`、`readaloud/ReadAloudPlayer.kt`
- `SensibleTopAppBar` → Article/Settings/TextSettings/EditFeed/SearchFeed/Feed/OpmlImport/Sync 共 8 屏
- `Table` → `html/LinearArticleContent.kt`（`TableData.fromCells` 在 `model/html/LinearStuff.kt`、`text/AnnotatedStringComposer.kt`）
- `Restrained*Scaling` / `rememberTintedVectorPainter` → ReaderView、LinearArticleContent、FeedItemCard/Compact/CompactCard/Indicator
- `interceptKey` → EditFeedScreen、SearchFeedScreen、EditableListDialog
- `safeSemantics` → 12 个文件（无障碍语义包装，吞异常）
- `CustomFilled.TextToSpeech` → `feedarticle/ArticleScreen.kt`

与其他区重叠：抽屉"容器"（Dismissible 推挤、手势、宽度、折痕、Esc/焦点）已在 `cards/ui-material.md` UM-A01..A09；Feed 页抽屉开关/返回/空态在 `cards/feed-screen.md` FD-A04..A07、FD-A35。本区只录**抽屉列表内容**与组件级契约，避免重复。

---

## 1. navdrawer —— 抽屉列表（订阅源/标签树、未读数）

### 1.1 数据模型
- `model/FeedUnreadCount.kt:9-21`：`id, displayTitle(display_title), tag, imageUrl(image_url: URL?), unreadCount(unread_count), expanded`，实现 `FeedIdTag{tag,id}`。
- 特殊 id（`db/room/AppDatabase.kt:30-32`）：`ID_UNSET=0`（标签行）、`ID_ALL_FEEDS=-10`、`ID_SAVED_ARTICLES=-20`。
- `navdrawer/NavDrawer.kt:235-256` contentType 推导：id=0→Tag；-10→AllFeeds；-20→SavedArticles；其他：tag 非空→ChildFeed，否则 TopLevelFeed。
- `DrawerItemWithUnreadCount.kt`：sealed class（DrawerTop/DrawerSavedArticles/DrawerFeed/DrawerTag）+ compareTo 排序。**当前抽屉不使用它**（抽屉直接渲染 `FeedUnreadCount` 分页数据），仅保留了 `FeedIdTag` 接口被 FeedUnreadCount 实现。迁移可只保留接口语义。

### 1.2 数据源（SQL 即排序/计数契约）
`db/room/FeedDao.kt:133-163` `getPagedNavDrawerItems(expandedTags)`，基于视图 `feeds_with_items_for_nav_drawer`（最新定义 `AppDatabase.kt:275`）：
```
view: feeds LEFT JOIN (feed_items 中 未被 blocklist glob 匹配的条目: unread = read_time is null, bookmarked)
      display_title = custom_title 为空 ? title : custom_title
rows:
  All feeds   : id=-10, unread_count=sum(unread),       sort_section 0
  Saved       : id=-20, unread_count=sum(bookmarked) where bookmarked, sort_section 1
  Tag         : id=0, display_title=tag, sum(unread) group by tag (tag != ''), expanded = tag in expandedTags, sort_section 2, sort_tag_or_feed 0
  Feed        : id=feed_id, sum(unread) group by feed_id where tag='' or tag in expandedTags,
                sort_section = tag==''?3:2, sort_tag_or_feed 1
order by sort_section, tag, sort_tag_or_feed, display_title collate nocase
```
要点：
- `Saved articles` 的计数是**收藏条目数**而非未读数。
- 无 GROUP BY 的聚合行（All/Saved）在 SQL 语义下恒返回 1 行（空集 sum=NULL→Room 映射 0），所以两行始终存在。
- 被屏蔽词（blocklist）命中的条目不计入任何未读数。
- tag 排序未加 `collate nocase`（二进制序，大写在前）；display_title 不区分大小写。
- 有标签的订阅源仅在其标签展开时出现，且紧跟在标签行之后；无标签订阅源整体排在所有标签之后。
- 分页：`archmodel/FeedStore.kt:71-82` Pager(pageSize 10, initialLoadSize 50, prefetchDistance 50, jumpThreshold 50)；`Repository.kt:646-648` `expandedTags.flatMapLatest` → 展开集合变化重建 PagingSource；Room 的 PagingSource 对表变化自动失效 → 未读数实时更新。
- 展开状态：`archmodel/SessionStore.kt:24-35` 内存 `MutableStateFlow<Set<String>>`，**未持久化**，进程重启后全部折叠。
- FeedWidgetSettings 也复用同一数据（`widget/FeedWidgetSettingsActivityViewModel.kt:17`）。

### 1.3 UI 结构（`NavDrawer.kt`）
- `ScreenWithNavDrawer`（78-125）：`DismissibleNavigationDrawer`（项目自有 fork，见 ui-material 区）+ `DismissibleDrawerSheet { ListOfFeedsAndTags }`；点击项 → `onDrawerItemSelect(item.id, item.tag)` 后 `drawerState.close()`（111-116）；打开时 requestFocus（90-94）；Esc 类按键关闭（99-103）。
- `ListOfFeedsAndTags`（129-233）：LazyColumn，`contentPadding = WindowInsets.systemBars`（138），testTag `feedsAndTags`，collectionInfo(itemCount,1)；key：All/Saved 用常量 id，Tag 用 tag 字符串，Feed 用 id；分页占位 `Placeholder()` 48dp 空盒（424-432）。
- 分隔线：`itemIndex == 2 && contentType ∈ {Tag, ChildFeed, TopLevelFeed}` 时在该项上方画 `HorizontalDivider`（164-169），即"全部/收藏"与订阅源区之间。
- 行结构 `Feed(...)`（452-515）：Row 48dp 高、整行 clickable；[图标框 minimumInteractiveComponentSize][标题 1 行][未读数（>0 才显示）]。
  - AllFeeds：图标位空 24dp 盒；SavedArticles：`Icons.Default.Star` 24dp；Feed：有 imageUrl → coil `AsyncImage`（size=24dp px, Scale.FIT, Precision.INEXACT, ContentScale.Crop, contentDescription `Feed Icon`），失败只 logDebug（无错误图）；无 imageUrl → 空 24dp 盒。TopLevelFeed 与 ChildFeed 外观相同（无缩进）。
  - 未读数文本：`"%d".format(locale[0], n)`；语义 contentDescription = 复数 `n_unread_articles`（`%1$s unread articles` 等，`res/values/plural_strings.xml:3`）。
- 标签行 `ExpandableTag`（274-355）：[ExpandArrow IconButton(ExpandLess 图标，展开 0°/折叠 180° 旋转动画)][标签名（点击=选中标签导航）][未读数]；箭头点击 = `onToggleExpansion(tag)`（不导航、不关抽屉）。语义：mergeDescendants、stateDescription `Open tag`/`Closed tag`、customAction `Toggle tag expansion`；箭头按钮自身 clearAndSetSemantics。
- 文案 key：`all_feeds`=`All feeds`，`saved_articles`=`Saved articles`，`toggle_tag_expansion`、`expanded_tag`=`Open tag`、`contracted_tag`=`Closed tag`、`feed_icon`=`Feed Icon`。
- FeedScreen 侧的 workaround（`feed/FeedScreen.kt:265-277`）：itemCount==0 时临时换用另一个 LazyListState，防止重建后滚动位置被重置。

---

## 2. theme —— 主题 / 深色 / 动态色 / 字体 / 尺寸

### 2.1 入口链（`ui/compose/utils/ComposeProviders.kt:22-46`）
`withAllProviders` → 从 `CommonActivityViewModel` 收集 `currentTheme, darkThemePreference, dynamicColors, textScale, font` → `withFoldableHinge → withWindowMetrics → withWindowSize → ProvideTypographySettings(fontScale, font) → FeederTheme(...) → WithFeederTextToolbar(content)`。所有 Activity（Main、ManageSettings、AddFeedFromShare、ImportOPMLFile、FeedWidgetSettings）都走它，设置变更即时重组生效。

### 2.2 设置枚举与持久化（`archmodel/SettingsStore.kt`）
- `ThemeOptions`（840-847）：DAY `Day` / NIGHT `Night` / E_INK `E Ink` / SYSTEM `System`；默认 SYSTEM（188-195）；存小写名，解析失败回退 SYSTEM（950-955）。
- `DarkThemePreferences`（849-854）：BLACK `Black`（默认）/ DARK `Dark`（202-213，解析失败回退 BLACK 962-967）。
- `useDynamicTheme`（290-302）：默认 true，但仅 SDK≥31 生效；UI 文案 `Dynamic colors`（strings.xml:129）。
- `textScale` 默认 1f（305-316）；`font` 默认 `FontSelection.RobotoFlex`（`defaultFont` 998），读取失败/文件不存在回退默认（318-328）。

### 2.3 配色（`theme/Theme.kt:256-299`，`theme/Color.kt`）
- dark 判定：DAY/E_INK=false，NIGHT=true，SYSTEM=isSystemInDarkTheme()。
- 选色优先级：SDK≥S 且 dynamicColors → `dynamicDark/LightColorScheme`；否则 dark→darkColors；E_INK→eInkColors；其余 lightColors。（注意：E_INK + 动态色开时会走动态浅色，而非黑白——源码行为。）
- 最后：`dark && BLACK` → `background = Color.Black`（对动态色同样生效）。DARK 时背景为 `md_theme_dark_background #191C19`。
- 固定色板：种子 Green700 `#0b8043`；light primary `#006D37`、background `#FBFDF7`；dark primary `#77DB93`；E Ink：primary 黑、background/surface 白、onBackground 黑（Color.kt:35-61）。
- 其他颜色常量：`SwipingItemToReadColor #ff5252`、`SwipingItemToUnreadColor #1C9255`（Feed 滑动），`NavBarScrimLight/Dark`。
- 系统栏（Theme.kt:165-225）：`enableEdgeToEdge`，状态栏全透明；DAY/E_INK `light`（深色图标）、NIGHT `dark`、SYSTEM `auto`；导航栏 scrim lightScrim `argb(e6,FF,FF,FF)` / darkScrim `argb(80,1b,1b,1b)`。
- `PreviewTheme` 仅供预览。

### 2.4 字体排版（`theme/Typography.kt`）
- `FeederTypography`（29-81）：M3 默认 Typography 的全部 15 个样式 merge `sansFontFamily`；headline*/body* 加 `LineBreak.Paragraph`，body* 加 `Hyphens.Auto`。
- `ProvideTypographySettings`（313-337）：RobotoFlex→内置可变字体 `res/font/roboto_flex.ttf`；SystemDefault→`FontFamily.SansSerif`；UserFont→`filePathProvider.fontsDir/<path>` 文件 + 可变轴（weight/italic/slant）展开为多个 Font。mono：RobotoFlex→`roboto_mono_variable_wght.ttf`，否则系统 Monospace（297-301）。serif 固定 `FontFamily.Serif`。
- `TypographySettings(fontScale, sans, mono, serif)` 经 `LocalTypographySettings` 下发；fontScale 由 `utils/ProvideScaledText.kt:19-20` 作用于正文字号/行高（TextSettings 区）。
- 语义样式：`titleFontWeight(unread)` 未读=Black、已读=Normal（250-255）；`LinkTextStyle` primary+下划线；`CodeInlineStyle` surfaceVariant 背景+mono；Feed 列表 title=titleMedium、snippet=titleSmall、日期/源名=labelMedium；TTS 播放器 titleMedium。
- FontSelection（`settings/TextSettingsViewModel.kt:139-240`）：RobotoFlex（wght 100-1000，slnt -10..0），SystemDefault（声明 wght 100-900、ital 0-1），UserFont（元数据从字体文件解析）。

### 2.5 响应式尺寸（`theme/Dimensions.kt`）
- phone：maxContent 600、maxReader 600、margin/gutter/navIconMargin 16、feedScreenColumns 1。
- tablet(w)：列数 w>1360→4，>1028→3，否则 2；maxContent min(840,w)，maxReader min(640,w)，margin 32。
- TV：仅当 `screenWidthDp==960 && screenHeightDp==540`；3 列、reader 图片 16:9。
- 选择（112-137）：宽度类 Compact→phone；否则高度类 Compact→phone；否则 tablet。`remember{}` 无 key——配置变化依赖 Activity 重建。

### 2.6 SensibleTopAppBar（`theme/SensibleTopAppBar.kt`）
注释说"小而高屏用 LargeTopAppBar"，**实现恒为普通 `TopAppBar`**。标题单行省略，`WithBidiDeterminedLayoutDirection` 按标题文字方向排版；容器色 background，滚动后 `surfaceColorAtElevation(3.dp)`。

---

## 3. dialog / components

### 3.1 ConfirmDialog（`components/ConfirmDialog.kt:17-53`）
AlertDialog：标题（titleLarge 居中）、正文、`confirmButton=Button(OK)→onOk`、`dismissButton=Button(Cancel)→onDismiss`、点外部/返回→onDismiss。OK/Cancel 来自 **`android.R.string.ok/cancel`**（系统串，非 app strings.xml）。唯一使用：`LeaveSyncChainDialog`（title `Leave sync chain`，body `Are you sure you want to leave the sync chain?`）。注意 ConfirmDialog 的 onOk 不自动关闭，由调用方决定。

### 3.2 RenameTagDialog（`dialog/RenameTagDialog.kt`）
标题 `Rename tag`；单行 OutlinedTextField 预填当前标签名（rememberSaveable）；OK enabled = `tagName.isNotBlank() && tagName != currentTagName`；OK → onRename(tagName) 再 onDismiss；Cancel→onDismiss。按钮串用 android.R。调用：FeedScreen.kt:1347-1355（currentTagName = 当前 feedScreenTitle.title）。

### 3.3 EditableListDialog（`dialog/EditableListDialog.kt`）
- 无 OK/Cancel 按钮；`confirmButton` 位置放一个 OutlinedTextField（label `Add item`，IME Next）。
- 添加：IME Next 或硬件 Enter（`interceptKey(Key.Enter)` KeyUp 触发）→ `onAddItem(newValue)` 并清空；Esc → onDismiss。**不在组件内过滤空串**，过滤在 `SettingsStore.addBlocklistPattern`（481-490：blank 忽略、`lowercase().trim()`、重复约束异常吞掉）。
- 列表：LazyColumn key=item 字符串（重复项会冲突，存储侧唯一约束保证），每行文本 + Delete IconButton（contentDescription `Remove`）→ onRemoveItem。
- 可选 toggle 行（showToggle，Role.Switch，整行可点）——当前唯一调用（Settings.kt:528-555 屏蔽词 `Filters`）传 showToggle=false。
- 调用方 `ListDialogSetting`（Settings.kt:1201-1263）：行点击展开对话框，副标题显示前 5 项空格拼接。

### 3.4 FeedNotificationsDialog（`dialog/FeedNotificationsDialog.kt`）
- 标题由调用方给（Settings.kt:1365-1372：`Notify for new items`）；唯一按钮 `OK`（android.R）→ onDismiss。
- 列表 key=feedId；每行：标题（titleMedium，最多 2 行省略）+ Switch；点击整行或 Switch → `onToggleItem(feedId, !notify)`；行语义 Role.Switch + stateDescription `On`/`Off`。

### 3.5 OkCancelWithContent / NonScrollable（`components/OkCancel.kt`）
Column 居中；可滚动版本上 16dp、内容、24dp、按钮；按钮行宽 = `maxContentWidth`，右对齐：`Cancel`（TextButton）、8dp、`OK`（TextButton，enabled=okEnabled）；底部 `windowInsetsBottomHeight(navigationBars)` 避让导航栏。按钮串来自 android.R。

### 3.6 AutoCompleteResults（`components/AutoCompleteText.kt`）
content（输入框）下方 4dp，`AnimatedVisibility(displaySuggestions)` 的 LazyColumn（最大高 3×TextField 最小高、宽 90%、2dp onBackground 边框圆角 8），项 key=字符串、点击回调 onSuggestionClick。

### 3.7 PaddedBottomAppBar（`components/BottomAppBar.kt`）
fork 的 M3 BottomAppBar：Surface 内 Box `windowInsetsPadding(navigationBars.only(Bottom))`，Row 高 `bottomBarHeight=80.dp`（`ui/compose/Constants.kt:7`），actions 左排，FAB（可选）右侧 weight 占位后放置；focusGroup。

### 3.8 TranslationProgressContent（`components/TranslationProgressContent.kt`）
三态文案：`isRuntimeDownload` → `Downloading offline translation engine: %1$d%%`；`isIndeterminate` → `Preparing offline translation model %1$s to %2$s…` + 不确定进度条；否则 `Downloading offline translation model %1$s to %2$s: %3$d%%` + 确定进度条（fraction）。底部提示 `First download can be 20–50 MB and may take a few minutes. Translation works offline afterward.`（outline 色）。注意：runtime 下载且 isIndeterminate 时文案为 runtime 百分比但进度条为不确定。

### 3.9 safeSemantics（`components/Utils.kt`）
semantics 包装，try/catch 吞异常并 Log——鸿蒙无需等价，直接设置 accessibility 属性。

---

## 4. empty —— NothingToRead（`empty/NothingToRead.kt`）
居中三段（headlineMedium + Light 字重，居中）：`empty_feed_top`=`Nothing to read here. Would you like to…`；可点击块 `empty_feed_open`=`<annotation style="link">Open</annotation> another feed?` → onOpenOtherFeed；可点击块 `empty_feed_add`=`<annotation style="link">Add</annotation> more feeds?` → onAddFeed。`annotatedStringResource`（`text/Extensions.kt`）把 annotation style=link 渲染为链接样式。调用（FeedScreen.kt:1383-1400 / 1661-1665）：`!haveVisibleFeedItems` 时淡入淡出；Open→打开抽屉；Add→`SearchFeedDestination`。

---

## 5. pullrefresh（fork 自 androidx.compose.material PullRefresh）
- `PullToRefreshState.kt`：阈值 `RefreshThreshold=80.dp`，刷新时指示器停在 `RefreshingOffset=56.dp`；`DRAG_MULTIPLIER=0.5`（手指拖动 160dp 才达阈值）；超阈值后非线性阻尼（overshoot 上限 200%）。
  - `onPull`：refreshing 时返回 0 不消费；距离 coerceAtLeast(0)。
  - `onRelease`：未刷新且 adjusted>threshold → 调 onRefresh；否则动画回 0；距离清零。
  - `setRefreshing`（SideEffect 同步外部 refreshing）：变化时动画到 refreshingOffset 或 0。
- `PullRefresh.kt`：NestedScrollConnection——上滑（available.y<0, Drag）在 preScroll 先回推指示器；下拉仅在 postScroll（子列表未消费，即已在顶部）时累计；preFling 调 onRelease 并返回 Zero（不消费 fling）。
- `PullToRefreshIndicator.kt`：40dp 圆形 Surface，`translationY = position - height`；refreshing 时 CircularProgressIndicator，否则按 progress 绘制箭头弧（SwipeRefreshLayout 规格）；Crossfade 100ms；箭头 Canvas contentDescription 硬编码 `"Refreshing"`（未本地化）。
- FeedScreen 用法（1195-1203, 1286, 1300-1306）：`pullRefresh` 必须放在 nestedScroll(topAppBar) 之前；onRefresh → `manuallyTriggeredRefresh=true; onRefreshVisible()`（同步当前 feed/tag）；指示器 TopCenter。
- 鸿蒙：ArkUI `Refresh` 组件可替代，阈值/阻尼参数不入断言；需保证"仅在列表顶部下拉触发"与"刷新中不重复触发"。

---

## 6. modifiers
- `interceptKey(key, onKeyEvent)`（KeyEvents.kt:29-40）：onPreviewKeyEvent；目标键 KeyUp 时触发回调并消费；目标键 KeyDown 也消费（不传给子组件）；其他键放行。用于 Enter 提交 / Esc 关闭（EditFeed、SearchFeed、EditableListDialog）。
- `trackVisibility(threshold, cb)`（TrackVisibility.kt）：Modifier.Node + GlobalPositionAware；可见面积 = 自身 boundsInWindow 与**父**布局 boundsInWindow 的交集 / 自身面积；变化 ≥0.01 才回调；`VisibilityInfo(isVisible>0, visiblePercentage, bounds, isAboveThreshold = pct>=threshold)`；父为空或未 attach → 置 0 不回调。FeedScreen 用 0.9 阈值 + 500ms（`REQUIRED_VISIBLE_TIME_FOR_MARK_AS_READ`，FeedScreen.kt:1889）实现"滚动标记已读"（在 Feed 区断言）。
- 鸿蒙：`onVisibleAreaChange(ratios, cb)` 可直接实现，但参照系是窗口/父容器裁剪，需对齐"相对父容器"的语义。

---

## 7. layouts —— Table（`layouts/Table.kt`）
- 自定义 Layout：子项按 `tableData.cells` 顺序发射（rowSpan/colSpan>0）；测量约束 min = 已知列宽/行高之和（mutableStateMap 跨测量记忆），max 无穷；列宽 = 各列最大（跨列单元格宽度均分到各列）；行高同理；总尺寸 = 和；放置于累计偏移。
- `allowHorizontalScroll=true` 时外层 horizontalScroll；Box 居中。
- `TableData`：私有主构造 + `(row, column)` 便捷构造；init 校验"跨越单元格须在非跨越之后"，否则 `check` 抛异常；`fromCells` 排序：非跨越 < 单向跨越 < 双向跨越，再按 row、column。`TableData(0,0)` 不崩溃（预览 185-197）。
- 依赖"非跨越单元格先测量"保证列宽正确。鸿蒙无等价 Layout API 时需用自定义布局（`onMeasureSize/onPlaceChildren`）或 Grid 近似——见降级候选。

---

## 8. coil 目录 + 图片加载
- `RestrainedFitScaling / RestrainedCropScaling / RestrainedFillWidthScaling(pixelDensity)`：标准 Fit/Crop/FillWidth 比例，但**上限 = max(pixelDensity, 1)**，防止小图被过度放大（例：1x 图在 3x 屏最多放大 3 倍以显示为原 dp 尺寸）。用于 ReaderView 头图（Crop）、LinearArticleContent 正文图（Fit / FillWidth）、FeedItemCard（Crop）。
- `rememberTintedVectorPainter(image, tint=LocalContentColor)`：ImageVector→按当前内容色着色的 painter，用作 coil placeholder（`Icons.Outlined.Terrain`）与 error（`Icons.Outlined.ErrorOutline`）。
- 全局 ImageLoader（`FeederApplication.kt:148-205`，非本目录但属"coil"）：独立 OkHttp 图片缓存 300MB（`httpImageCacheDir`）+ `AlwaysUseCacheIfPossibleRequestsInterceptor`；`loadImageOnlyOnWifi` 开且当前为计费网络 → 强制 `onlyIfCached`（无缓存则 504 失败）；coil 磁盘缓存 200MB（`imageCacheDir`）、内存 100MB、后台 5%；crossfade；maxBitmapSize 2500×2500；组件 `OneImageRequestPerHostInterceptor`、`IcoDecoder`（.ico favicon）、OkHttp fetcher。

## 9. icons
`Icons.CustomFilled.TextToSpeech`：Material Symbols 风格自定义矢量（24×24 path，懒初始化缓存）；用于 Article 页朗读按钮。鸿蒙需转 SVG 资源（可从 path 数据导出）。

---

## 10. 平台风险
1. **动态取色**：Android 12+ `dynamicLight/DarkColorScheme`（壁纸取色）默认开启。HarmonyOS 无公开等价的壁纸 Monet 色板 API → 降级为固定绿色配色，`Dynamic colors` 开关需隐藏或说明无效。
2. **E Ink + 动态色**组合源码会走动态色（非黑白），迁移时应决定是否沿用（建议照搬：无动态色即自然黑白）。
3. **可变字体**：RobotoFlex/用户字体按 wght/ital/slnt 轴生成多个 Font 变体。ArkUI `font.registerFont` 支持注册字体文件，但对可变字体轴（FontVariation）支持有限 → 用户字体粗细/斜体可能退化为合成。
4. **Edge-to-edge 系统栏**：状态栏图标深浅需用 `window.setWindowSystemBarProperties`（statusBarContentColor）按主题切换；SYSTEM 需监听系统深浅色变化。
5. **Pull refresh 阈值/嵌套滚动顺序**：Compose 依赖 `pullRefresh` 先于 TopAppBar nestedScroll；ArkUI Refresh + 可折叠标题需验证手势冲突。
6. **Paging + Room 自动失效**：抽屉未读数依赖 Room PagingSource 表失效自动刷新；鸿蒙 RDB 无自动观察 → 需在写库后主动通知抽屉刷新（否则未读数陈旧）。
7. **SQL 排序细节**：tag 二进制排序 vs 标题 nocase；鸿蒙 RDB(SQLite) 可原样保留 SQL。
8. **Table 自定义测量**：依赖跨 pass 记忆列宽，ArkUI 自定义布局需重新实现。
9. **android.R.string.ok/cancel**：系统串在鸿蒙需自备资源（`OK`/`Cancel`）。
10. **复数资源**：`n_unread_articles` 用 plurals（zero/one/two/few/many/other），ArkTS `getPluralStringValue` 可对应。
11. **TV 尺寸判定**（960×540 精确匹配）与折叠屏 hinge——鸿蒙设备形态需重新映射（断点 sm/md/lg）。
12. 指示器 contentDescription `"Refreshing"` 硬编码英文。

## 11. 降级候选
- 动态取色（壁纸色板）→ 固定配色；开关隐藏/禁用。
- 可变字体轴（weight/italic/slant 变体）→ 仅注册字体文件，粗斜体由系统合成。
- TV 专用尺寸集（tvDimensions）→ 鸿蒙无 TV 目标时省略。
- `SwitchSetting` 式 toggle 行在 EditableListDialog（showToggle）当前无调用者 → 可不实现。
- `DrawerItemWithUnreadCount` sealed 类与 compareTo（未被抽屉使用）→ 不迁移。
