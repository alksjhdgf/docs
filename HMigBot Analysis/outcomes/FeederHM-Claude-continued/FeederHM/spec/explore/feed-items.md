# 探索文档：feed-items（Feed 条目组件域，断言前缀 FI）

源目录：`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/`（下文简写 `feed/`）
断言卡：`output/FeederHM/spec/cards/feed-items.md`

## 1. 区域概览

| 文件 | 行数 | 作用 |
|---|---|---|
| feed/FeedItemCard.kt | 540 | `FeedItemCard`（CARD 样式）+ 共享的 `RowScope.FeedItemText`（标题/摘要/源名/日期/阅读时长 + 长按 DropdownMenu） |
| feed/SwipeableFeedItemPreview.kt | 469 | 列表项外壳：按 FeedItemStyle 分派、单击/长按、滑动标记已读（AnchoredDraggable）、无障碍自定义动作；`enum FeedItemSwipeState {CENTER, START, END}` |
| feed/FeedItemCompactCard.kt | 346 | `FeedItemCompactCard`（COMPACT_CARD 样式）+ `sealed FeedItemEvent` + `data class FeedItemState` |
| feed/FeedItemCompact.kt | 323 | `FeedItemCompact`（COMPACT 样式）+ **数据模型 `FeedListItem`**（含 `cursor`、`contentType()`） |
| feed/FeedItemSuperCompact.kt | 191 | `FeedItemSuperCompact`（SUPER_COMPACT 样式） |
| feed/FeedItemIndicator.kt | 223 | 指示器：`FeedItemEitherIndicator`、`FeedItemImageIndicator`、`FeedItemFeedIconIndicator`、`FeedItemNewIndicator`（未读圆点）、`FeedItemSavedIndicator`（星标） |
| feed/EditFeedDialog.kt | 119 | 多订阅源时选择要编辑的源 |
| feed/ExplainPermissionDialog.kt | 49 | 通知权限理由对话框（Settings / EditFeed 复用） |

调用方：仅 `feed/FeedScreen.kt`（列表 :1482、网格 :1726 两处 `SwipeableFeedItemPreview`；`EditFeedDialog` :1333）；`ExplainPermissionDialog` 由 `settings/Settings.kt:1356` 与 `editfeed/EditFeedScreen.kt:236` 调用。

## 2. 数据模型

### FeedListItem（feed/FeedItemCompact.kt:162）
```
id: Long, title: String, snippet: String, feedTitle: String, unread: Boolean,
pubDate: String（已格式化的显示串）, image: ThumbnailImage?, link: String?,
bookmarked: Boolean, feedImageUrl: java.net.URL?, primarySortTime: Instant,
rawPubDate: ZonedDateTime?, wordCount: Int
cursor: FeedItemCursor { primarySortTime, pubDate=rawPubDate, id }   // 用于“标记上方/下方已读”
contentType(style) = "$style/image" 若 image!=null 否则 "$style/other"   // LazyList 复用键
```
- `ThumbnailImage`（model/ThumbnailImage.kt:10）sealed：`url`, `width?`, `height?`, `fromBody`。
- FeedScreen 的分页占位 `PLACEHOLDER_ITEM`（FeedScreen.kt:1891）：全空、unread=true、id=ID_UNSET。

### FeedItemState / FeedItemEvent（feed/FeedItemCompactCard.kt:51-77）
仅 COMPACT_CARD 使用的 state+event 风格（其他三种是多回调参数）。Event：OpenInReader / OpenInCustomTab / OpenInBrowser / MarkAboveAsRead / MarkBelowAsRead / ShareItem / ToggleBookmarked / DismissDropdown。State 默认值：showThumbnail=true, bookmarkIndicator=true, dropDownMenuExpanded=false, showReadingTime=false, maxLines=2。

### 枚举（archmodel/SettingsStore.kt:892-906）
- `FeedItemStyle`：CARD(`Card`)、COMPACT_CARD(`Compact Card`)、COMPACT(`Compact`)、SUPER_COMPACT(`Super compact`)。
- `SwipeAsRead`：DISABLED(`Disabled`)、ONLY_FROM_END(`Only from end`)、FROM_ANYWHERE(`From anywhere`)。
- `FeedListFilter.onlyUnread = unread && !saved && !recentlyRead && !read`；`onlyUnreadAndSaved = unread && saved && !recentlyRead && !read`（feedarticle/FeedViewModel.kt:809-813）。

## 3. 共享文本块 FeedItemText（feed/FeedItemCard.kt:180-412）

结构（Column，spacing 4dp，weight(1f)）：
1. **合并文本**（:198-232）：`title` 非空 → title；且 `!showOnlyTitle && snippet 非空` → 追加 `'\n' + snippet`（snippet 用 `FeedListItemSnippetTextStyle` span）。title 空白 → 仅 snippet（注释：有源没有标题）。样式 `FeedListItemTitleTextStyle`，`fontWeight = titleFontWeight(unread)`（theme/Typography.kt:250：未读 Black，已读 Normal），`maxLines` + Ellipsis。外包 `WithBidiDeterminedLayoutDirection`（按段落内容决定 LTR/RTL）。
2. **源名 + 日期行**（:235-264）：ContentAlpha.medium；左 `feedTitle`（1 行、Ellipsis、weight 1）、右 `pubDate`（1 行、Clip）。各自 bidi。DropdownMenu 锚定在此行（Box 内）以便菜单居中于中间行。
3. **阅读时长行**（:367-410，仅 `showReadingTime`）：`readTimeSecs = wordsToReadTimeSecs(wordCount) = round(words*60/220.0)`（feedarticle/ReaderView.kt:401）；>0 才显示。左：`pluralStringResource(n_minutes, count=secs/60).format("${secs/60}:%02d")` → 例 588 词 → 160s → `2:40 minutes`；右：`n_words` → `588 words`。复数资源 res/values/plural_strings.xml:27-41，英文 `%1$s minute(s)` / `%1$s word(s)`（strings.xml:278-289）。

### 长按菜单（DropdownMenu，:265-365）——确定性清点
| 序 | 文案（strings.xml） | 动作 |
|---|---|---|
| 1 | `Open in reader` (open_article_in_reader:106) | onDismiss → onOpenFeedItemInReader |
| 2 | `Open in custom tab` (open_article_in_custom_tab:108) | onDismiss → onOpenFeedItemInCustomTab |
| 3 | `Open in default browser` (open_article_in_default_browser:107) | onDismiss → onOpenFeedItemInBrowser |
| 4 | `Save article` / `Stop saving article`（按 item.bookmarked；save_article:230 / unsave_article:231） | onDismiss → onToggleBookmark |
| 5 | `Mark the above as read` (:141) | onDismiss → onMarkAboveAsRead |
| 6 | `Mark the below as read` (:142) | onDismiss → onMarkBelowAsRead |
| 7 | `Share` (:62) | onDismiss → onShareItem |
| 8 | （隐藏，高 0dp）contentDescription `Close menu` (:290)，Role.Button | onDismiss（TalkBack 用） |
菜单 `onDismissRequest`（点外部/返回）与 `onKeyEventLikeEscape` 均关闭。

## 4. 四种样式布局

公共：已读整体 `alpha 0.75`、未读 1.0（Card:98、CompactCard:96、Compact:73、SuperCompact:44）；最小高度 `minimumTouchSize=48dp`（ui/compose/Constants.kt:5）。

### CARD — FeedItemCard（FeedItemCard.kt:71-178）
ElevatedCard → Column：
- 缩略图（:100-146）：`showThumbnail && item.image != null && (width ?: 1000) >= 10 && (height ?: 1000) >= 10`（过滤已知极小图）。全宽 16:9、clip shapes.medium、surfaceVariant 底、`RestrainedCropScaling(density)`（coil/RestrainedFitScaling.kt:37：按填充放大但不超过像素密度倍数）、Coil 请求尺寸=宽×宽*9/16、Scale.FIT、Precision.INEXACT；placeholder Terrain、error ErrorOutline（rememberTintedVectorPainter）；contentDescription `Article image`(strings.xml:224)；testTag `card_image`。
- Row（padding 8dp，spacing 8dp）：`FeedItemEitherIndicator(bookmarked = item.bookmarked && bookmarkIndicator, itemImage=null, feedImageUrl, size=16dp)` + FeedItemText。

### COMPACT_CARD — FeedItemCompactCard（FeedItemCompactCard.kt:82-232）
ElevatedCard(shapes.medium) → BoxWithConstraints(fillMaxWidth)：
- `showThumbnail` 时：若 `image?.url` 非空画 16:9 缩略图（Scale.FILL、ContentScale.Crop、alpha 0.74、**不过滤极小图**）；无论是否有图都叠加 `matchParentSize` 的竖向渐变（黑 0.8 → 0.38 → 0.8）。
- 右上角 Row(24dp 高)：`bookmarked && bookmarkIndicator` → 星标；`unread` → 未读圆点（Icons.Outlined.Circle，primary，cd `Unread`）；`feedImageUrl?.toHttpUrlOrNull()` 成功 → 源图标。
- 底部标题区（padding top 48dp，BottomCenter）：FeedItemText，**showOnlyTitle 恒为 true**；文字色 `showThumbnail ? Color.White : LocalContentColor`。
- 注：COMPACT_CARD 的左侧不放 EitherIndicator。

### COMPACT — FeedItemCompact（FeedItemCompact.kt:49-160）
Surface(height IntrinsicSize.Min) → Row(start padding = dimens.margin, spacing 4dp)：
- FeedItemText（minHeight 48dp, vertical padding 8dp）。
- 右列条件：`(bookmarked && bookmarkIndicator) || showThumbnail && (image != null || feedImageUrl != null)`：
  - 收藏优先：64dp 宽列显示 24dp 星标（**不显示图片**）；
  - 否则 `image?.url ?: feedImageUrl`：宽 `imageWidth`（SwipeableFeedItemPreview 传 64dp，紧凑横屏 196dp）、fillMaxHeight；item 图用 RestrainedCropScaling，源图标用 RestrainedFitScaling；请求尺寸 宽×1.5宽；contentDescription null。
  - 不满足 → Spacer(margin-4dp)。
- 注意：COMPACT 的 showThumbnail **不受**紧凑横屏关闭（只改宽度）；且 `showThumbnail=false` 时仍会显示收藏星标列。

### SUPER_COMPACT — FeedItemSuperCompact（FeedItemSuperCompact.kt:19-74）
Surface(minHeight 48dp) → Row(CenterVertically, spacing 8dp, padding vertical 8dp / horizontal margin)：`FeedItemEitherIndicator(size=24dp)` + FeedItemText。无缩略图参数。

### 指示器 FeedItemEitherIndicator（FeedItemIndicator.kt:37-67）
优先级：bookmarked → `FeedItemSavedIndicator`（Icons.Default.Star、primary、cd `Saved article` strings.xml:229）；itemImage → ImageIndicator（实际所有调用方都传 null）；feedImageUrl → FeedIconIndicator（Fit，cd=null）；否则等尺寸空白 Spacer。注释掉的 unread 分支说明未读圆点在 EitherIndicator 中**不**出现（只在 COMPACT_CARD 出现）。

## 5. SwipeableFeedItemPreview（外壳 + 滑动）

参数：onSwipe(Boolean)、filter、item、showThumbnail、feedItemStyle、swipeAsRead、bookmarkIndicator、maxLines、showOnlyTitle、showReadingTime、7 个动作回调、onItemClick、`swipeEnabled=true`（FeedScreen 传 `!listState.isScrollInProgress` / `!gridState.isScrollInProgress`，:1586/:1827）。

外层 BoxWithConstraints（:165-225）：
- `width(dimens.maxContentWidth)`；clip：COMPACT/SUPER_COMPACT → RectangleShape，否则 shapes.medium。
- `combinedClickable(onLongClick = 展开菜单, onClick = onItemClick)`；菜单展开态 `rememberSaveable`。
- 无障碍：`stateDescription = Unread/Read`（unread_adjective:165 / read_adjective:257）；customActions 8 个：`Toggle read status`(:36，调用 onSwipe(item.unread))、Open in reader、Open in custom tab、Open in default browser、Save article/Stop saving article、Mark the above as read、Mark the below as read、Share。

背景层（:249-273）：matchParentSize，`drawRect(color)`；color 动画：`item.unread || filter.onlyUnread` → `SwipingItemToReadColor 0xffff5252`（红），否则 `SwipingItemToUnreadColor 0xff1C9255`（绿）（theme/Color.kt:96-97）。alpha：currentValue≠CENTER → 1.0，否则 0.2（tween）。图标：未读 VisibilityOff，已读 Visibility，cd=null；对齐 `offset>0 → CenterStart，否则 CenterEnd`；水平 padding 24dp。

前景：按 style 分派（:277-401），每个子组件 `Modifier.offset { requireOffset() }`（未初始化异常→0）。`isCompactLandscape()`（utils/WindowSize.kt:64：横屏 && 高度 Compact）→ CARD/COMPACT_CARD showThumbnail=false；COMPACT imageWidth 196dp。

滑动层（:406-461，仅 swipeAsRead≠DISABLED）：
- ONLY_FROM_END：拖拽区 = fillMaxHeight × (maxWidth/4)，align CenterEnd；anchors START=-(w/2), CENTER=0（只能向起始侧滑）。
- FROM_ANYWHERE：拖拽区 = matchParentSize 但 `padding(start=48dp)`（给导航抽屉边缘手势让位）；anchors START=-(w/2), CENTER=0, END=+(w/2)。
- `anchoredDraggable(orientation=Horizontal, reverseDirection=isRtl, enabled=swipeEnabled)`。注释：锚点取 w/2，默认 50% 位置阈值 → 约滑 1/4 宽度即触发（另有速度阈值 fling）。
- 拖拽层是覆盖层，点击/长按由父层处理（注释强调）。

状态机：
- `LaunchedEffect(filter, item.unread)`：非 CENTER 时 animateTo(CENTER)（关键状态变化复位）。
- `LaunchedEffect(settledValue)`（:116-126）：settled≠CENTER → 若 `!filter.onlyUnread`：skipHaptic=true 并 animateTo(CENTER)（回弹）；然后 `onSwipe(item.unread)`。仅未读过滤下保持滑出，待条目从分页数据消失。
- 触觉（:231-247）：currentValue 变化且 offset≠0 → `HapticFeedbackType.GestureThresholdActivate`；回弹那次跳过。

FeedScreen 侧接线（FeedScreen.kt:1482-1520、:428-447）：
```
onSwipe = { cur -> markAsReadOnSwipe(id, unread = !cur, saved = bookmarked) }
markAsReadOnSwipe(itemId, unread, saved) = when {
  filter.onlyUnread -> vm.markAsReadOnSwipe(itemId)            // readTime 覆盖为 minReadTime-1s 以便立即从列表移除
  filter.onlyUnreadAndSaved && !saved -> vm.markAsReadOnSwipe(itemId)
  unread -> vm.markAsUnread(itemId)                            // 原为已读 → 改未读
  else -> vm.markAsRead(itemId)                                // 原为未读 → 已读
}
```
- `Repository.markAsReadAndNotified(itemId, readTimeBeforeMinReadTime=true)`（archmodel/Repository.kt:509）：minReadTime > EPOCH 时 readTime=minReadTime-1s。
- onMarkAboveAsRead → `markBeforeAsRead(cursor)`，且 `filter.onlyUnread` 时 `listState.scrollToItem(0)`；onMarkBelowAsRead → `markAfterAsRead(cursor)`（Repository.kt:610/627：markAsReadRaw(feedId, tag, filter, search, minReadTime, descending, cursor)，above 用 `descending = sorting != NEWEST_FIRST`，below 用 `==`；之后 runOnceSyncChainSendRead）。
- onToggleBookmark → `onSetBookmark(id, !bookmarked)`。
- onShareItem → `Intent.createChooser(ACTION_SEND, text/plain, EXTRA_TEXT = stripTrackingParameters(link)（link 非空时）, EXTRA_TITLE = title)`；`stripTrackingParameters`（util/UrlCleaner.kt:13）去掉 `utm_*`、`traffic_source*` 等查询参数。
- bookmarkIndicator = `!currentFeedOrTag.isSavedArticles`（:1494）。
- COMPACT/SUPER_COMPACT 时列表项间加 1dp HorizontalDivider（最后一项除外）（:1588-1600）。
- 另外 FeedScreen 有滚动可见标记已读（trackVisibility 0.9）与 DisposableEffect 标记——属 Feed 页区，不在本区卡。

## 6. EditFeedDialog（feed/EditFeedDialog.kt）
- AlertDialog：title `Edit feed`(strings.xml:26，titleLarge 居中)；confirmButton 为空（OK 被注释掉）；dismissButton `Cancel`（android.R.string.cancel）。
- text：LazyColumn，key=feed.id，每行 [未选中 RadioButton（语义清空）| 32dp | feed.title(titleMedium)]，行最小高 48dp，merge 语义；点行或单选 → `onEdit(id)` 后 `onDismiss()`。
- 数据：`viewState.visibleFeeds.map { DeletableFeed(it.id, it.displayTitle) }`（FeedScreen.kt:1333）。
- 触发：工具栏菜单“编辑”项（FeedScreen.kt:892）：`visibleFeeds.size == 1` → 直接 `EditFeedDestination.navigate(feedId)`，否则 `setShowEditDialog(true)`；可见性 `editDialogVisible` StateFlow（FeedViewModel.kt:373）。
- onEdit → `EditFeedDestination.navigate(navController, feedId)`（FeedScreen.kt:326）。

## 7. ExplainPermissionDialog（feed/ExplainPermissionDialog.kt）
- AlertDialog：无标题；text = `stringResource(explanation)`（bodyLarge），当前唯一用法 `explanation_permission_notifications` = `Permission must be granted before notifications can be enabled.`(strings.xml:223)；confirmButton `OK`（android.R.string.ok）→ onOk；无 dismissButton；onDismissRequest → onDismiss。
- 两个调用方逻辑相同（accompanist permissions）：
  - Settings.kt:1284-1315/1355：点通知设置行 → Denied 且 shouldShowRationale → `permissionDismissed=false` 显示对话框；Denied 无 rationale → 直接 launchPermissionRequest；Granted → 展开通知选择对话框。对话框 OK → launchPermissionRequest；dismiss → permissionDismissed=true。
  - EditFeedScreen.kt:160-243：打开“通知”开关时同上；关闭开关直接 notify=false。

## 8. 鸿蒙映射与平台风险

| 点 | Android | 鸿蒙建议 | 风险 |
|---|---|---|---|
| 滑动标记 | AnchoredDraggable + 自定义拖拽区（末端 1/4 / 起始 48dp 让位） | ListItem `swipeAction`（start/end + `edgeEffect`/`onEnterActionArea`/`onAction`）或 PanGesture + translate 自实现 | swipeAction 不支持“只在末端 1/4 区域起滑”与“起始 48dp 让位”；FROM_ANYWHERE 双向与 SideBar/抽屉手势冲突；滚动中禁用需自管（List 滚动与横向 Pan 方向判定）。**建议 PanGesture({direction: Horizontal}) 自实现**，以便精确复刻拖拽区与阈值 |
| 阈值/回弹 | 锚点 ±w/2、50% 位置阈值 + 速度 | 手动：|dx|≥w/4 或 fling 速度阈值 → 触发；animateTo 0 | 速度阈值数值不同，触发手感差异（可接受） |
| 仅未读下保持滑出 | 不回弹，等分页数据刷新移除 | 同：触发后保持 translate，数据源删除该项 | 若 LazyForEach 复用组件，translate 状态需按 item.id 复位（源用 LaunchedEffect(filter, unread) 复位） |
| 触觉 | HapticFeedbackType.GestureThresholdActivate | `@kit.SensorServiceKit` vibrator.startVibration（preset effect 如 `haptic.clock.timer` 或 time 短震），需 `ohos.permission.VIBRATE` | 需权限声明；on_device 才能验 |
| 长按菜单 | DropdownMenu 锚定中间行 | `.bindContextMenu(builder, ResponseType.LongPress)` 或 `bindPopup`/Menu | 单击与长按共存，需避免与 PanGesture 冲突（GestureGroup Exclusive/Parallel 次序） |
| 无障碍自定义动作 | semantics customActions + stateDescription | ArkUI `accessibilityText`/`accessibilityDescription`；**无等价“自定义动作列表”** | 降级候选 |
| 隐藏 Close menu 项 | TalkBack 专用 0 高菜单项 | 屏幕朗读可通过返回关闭 | 降级候选 |
| 图片 | Coil AsyncImage，placeholder/error，RestrainedCrop/Fit（不超过像素密度放大） | `Image(url).alt(占位)` + onError 切 error 图；objectFit Cover/Contain | 无“限制最大放大倍数”的 ContentScale；小图会被放大到糊。可接受降级或 onComplete 读尺寸后自算 |
| 极小图过滤 | width/height <10 不渲染（仅 CARD） | 同逻辑 | — |
| Bidi | WithBidiDeterminedLayoutDirection 每段判方向 | Text `.direction(Direction.Auto)` / `textDirection` | 需核验 Text 对段落 Auto 方向支持 |
| 复数串 | pluralStringResource n_minutes/n_words | `getPluralStringValueSync` + plural 资源 | 注意 format 参数是 "M:SS" 字符串而 count 是分钟数 |
| 标题字重 | FontWeight.Black/Normal | FontWeight.Bolder(900)/Normal | — |
| 分享 | Intent.createChooser ACTION_SEND text/plain | `@kit.ShareKit` systemShare（UTD PLAIN_TEXT / HYPERLINK） | on_device |
| 自定义 Tab | Custom Tabs | 无等价；可用应用内 Web 组件页或 openLink | 菜单项“Open in custom tab”行为需 OpenLink 区决策 |
| 通知权限理由 | accompanist shouldShowRationale | `notificationManager.requestEnableNotification()`（系统弹窗）；`isNotificationEnabled()` 检查 | 鸿蒙无 rationale 概念；首次拒绝后再次请求可能不弹。见断言 FI-A43 |
| 紧凑横屏 | WindowHeightSizeClass.Compact + 横屏 | `display`/`window` 尺寸断点（heightBreakpoint SM + 横屏） | 断点定义需与 app-shell 一致 |

### 降级候选
1. 无障碍自定义动作（8 个 customActions，FI-A26）：ArkUI 无 per-node 自定义动作列表；降级为长按菜单可达 + accessibilityText 描述读状态。
2. TalkBack 隐藏 `Close menu` 菜单项（源码 FeedItemCard.kt:354，未单独入卡）：降级为系统返回关闭。
3. 触觉反馈（FI-A37）：若未申请 VIBRATE 权限或设备无马达则省略。
4. RestrainedCrop/FitScaling 的“放大不超过像素密度”：ArkUI 无对应 ContentScale，降级为 Cover/Contain。
5. `Open in custom tab`：鸿蒙无 Custom Tabs，交由 OpenLink 区定义（通常应用内 Web 页）。

## 9. 易错点（实现必读）
- 滑动回调传的是**滑前**的 `item.unread`，FeedScreen 取反后作为“目标未读状态”。
- 背景色判定同时看 `filter.onlyUnread`：背景色判定为 `item.unread || filter.onlyUnread` → 红，否则绿。
- COMPACT_CARD 在 showThumbnail=true 但无图时仍画黑渐变 + 白字（不是 bug 迁移要保留）。
- COMPACT 收藏星标优先于缩略图，且即便 showThumbnail=false 也显示星标列。
- SUPER_COMPACT / CARD 左侧指示器只有星标或源图标，**未读圆点仅 COMPACT_CARD 有**。
- 已读 0.75 透明是整个条目（含缩略图）。
- bookmarkIndicator 在“已保存文章”视图为 false（所有样式都不显示星标）。
- 菜单项顺序与文案固定 7 项；Save/Stop saving 文案随状态切换。
- EditFeedDialog 无确认按钮；只有 1 个可见源时不弹框直接跳页。
