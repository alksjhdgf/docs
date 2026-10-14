# feed-items

## 域: 条目公共文本（FeedItemText）
- FI-A01 [ui] 条目主文本：title 非空白时显示 title，且 showOnlyTitle=false 且 snippet 非空白时换行接显示 snippet（摘要样式）；title 空白时只显示 snippet。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:198
- FI-A02 [ui] 主文本最多显示 maxLines 行（用户设置），超出以省略号截断。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:227
- FI-A03 [ui] 未读条目主文本字重为 Black（900），已读为 Normal。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:250
- FI-A04 [ui] 四种样式下已读条目整体以 75% 不透明度显示，未读为 100%。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:98
- FI-A05 [ui] 主文本下一行左侧显示 feedTitle（单行、超长省略），右侧显示 pubDate（单行）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:243
- FI-A06 [ui] 主文本、feedTitle、pubDate、阅读时长各自按内容判定书写方向，RTL 文字（阿拉伯语/希伯来语）右起排列。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:222
- FI-A07 [backend] 阅读时长秒数 = round(wordCount × 60 / 220)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ReaderView.kt:401
- FI-A08 [ui] showReadingTime=true 且阅读秒数 >0 时显示第三行：左侧 `M:SS minutes`（n_minutes 复数按分钟数取，如 588 词显示 `2:40 minutes`），右侧 `<wordCount> words`（n_words）；秒数为 0 时不显示该行。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:367

## 域: 条目点击与长按菜单
- FI-A09 [ui] 单击条目触发打开文章（onItemClick(itemId)，具体打开方式由 Feed 页决定）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:179
- FI-A10 [ui] 长按条目弹出菜单，按序 7 项：`Open in reader`、`Open in custom tab`、`Open in default browser`、`Save article`（已收藏时为 `Stop saving article`）、`Mark the above as read`、`Mark the below as read`、`Share`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:265
- FI-A11 [ui] 点任一菜单项先关闭菜单再执行该项动作；点菜单外部或按返回键仅关闭菜单。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:267
- FI-A12 [backend] `Open in reader` / `Open in custom tab` / `Open in default browser` 分别以该条目 id 调用对应打开回调。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1536
- FI-A13 [backend] `Save article`/`Stop saving article` 将条目收藏状态置为 !bookmarked。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1508
- FI-A14 [backend] `Mark the above as read`：在当前 feed/tag、过滤器、搜索词、minReadTime 范围内，把列表中位于该条目之前（按当前排序）的条目标记已读并触发一次已读同步；当前过滤器为仅未读时列表滚回顶部。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:610
- FI-A15 [backend] `Mark the below as read`：同范围内把位于该条目之后（按当前排序）的条目标记已读并触发一次已读同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:627
- FI-A16 [on_device] `Share` 调起系统分享面板，分享纯文本为去除 `utm_*`/`traffic_source*` 追踪参数后的条目链接（链接为空则无正文），标题为条目 title。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1511

## 域: 样式分派与外观
- FI-A17 [ui] 条目按 feedItemStyle 渲染：CARD→卡片、COMPACT_CARD→紧凑卡片、COMPACT→紧凑行、SUPER_COMPACT→超紧凑行；COMPACT/SUPER_COMPACT 为直角无卡片外框，CARD/COMPACT_CARD 为圆角卡片。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:277
- FI-A18 [ui] COMPACT/SUPER_COMPACT 样式下相邻条目之间显示分隔线（最后一项后无）；CARD/COMPACT_CARD 无分隔线。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1588
- FI-A19 [ui] 在“已保存文章”视图中所有样式均不显示收藏星标指示器（bookmarkIndicator=false），其他视图中收藏条目显示星标（无障碍描述 `Saved article`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1494
- FI-A20 [ui] 紧凑横屏（横屏且窗口高度为 Compact）时 CARD 与 COMPACT_CARD 不显示缩略图，COMPACT 右侧图片列变宽（196dp，否则 64dp）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:275
- FI-A21 [ui] CARD：showThumbnail 且条目有图且图片已知宽、高都不小于 10px（未知视为满足）时，卡片顶部显示全宽 16:9 缩略图，加载中显示占位图标、失败显示错误图标，无障碍描述 `Article image`；其下一行左侧为指示器（收藏星标，否则订阅源图标，否则空白）+ 文本。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCard.kt:100
- FI-A22 [ui] COMPACT_CARD：始终只显示标题不显示摘要；showThumbnail 时缩略图铺满卡片背景并叠加黑色竖向渐变、文字为白色（无图时也叠渐变、白字）；showThumbnail=false 时为普通卡片配色。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCompactCard.kt:99
- FI-A23 [ui] COMPACT_CARD 右上角依次显示：收藏星标（收藏且 bookmarkIndicator）、未读圆点（未读时，无障碍描述 `Unread`）、订阅源图标（feedImageUrl 为合法 http(s) URL 时）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCompactCard.kt:126
- FI-A24 [ui] COMPACT：文本在左；右侧列中收藏且 bookmarkIndicator 时显示星标（不显示图片，即使 showThumbnail=false 也显示），否则 showThumbnail 时显示条目图片（裁切填充），无条目图片则显示订阅源图标（完整适配）；都没有则无右列。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemCompact.kt:99
- FI-A25 [ui] SUPER_COMPACT：左侧指示器（收藏星标，否则订阅源图标，否则空白）+ 右侧文本，从不显示缩略图。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedItemSuperCompact.kt:51
- FI-A26 [ui] 无障碍：条目状态描述为 `Unread`/`Read`，并提供自定义动作 `Toggle read status`（等同一次滑动切换已读）及与长按菜单 7 项同名同效的动作。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:180

## 域: 滑动标记已读（SwipeableFeedItemPreview）
- FI-A27 [ui] 设置 swipeAsRead=`Disabled` 时条目不能横向滑动。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:406
- FI-A28 [ui] swipeAsRead=`Only from end`：只有从条目末端（LTR 为右侧）1/4 宽度区域起手才可滑动，且只能向起始方向（LTR 向左）滑。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:424
- FI-A29 [ui] swipeAsRead=`From anywhere`：除条目起始侧 48dp（留给抽屉边缘手势）外任意位置起手可滑，向左向右均可。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:431
- FI-A30 [ui] 滑动距离约达条目宽度 1/4（或快速甩动）松手即触发切换；未达阈值松手回弹、不改变状态。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:445
- FI-A31 [ui] RTL 布局下滑动方向与拖拽区域镜像。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:440
- FI-A32 [ui] 列表/网格滚动进行中条目滑动被禁用，竖向滚动不误触发标记。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:1586
- FI-A33 [ui] 滑动时条目后方露出背景色块与图标：条目未读或过滤器为仅未读时为红色（0xFFFF5252）+ `VisibilityOff` 图标，否则绿色（0xFF1C9255）+ `Visibility` 图标；图标位于被让出的一侧；越过阈值时背景完全不透明，否则半透明淡显。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:99
- FI-A34 [backend] 滑动触发后的结果：过滤器为仅未读 → 标记已读且已读时间写为 minReadTime−1s（使其立即从当前列表消失）；过滤器为仅未读+已保存且条目未收藏 → 同上；否则原未读 → 标记已读，原已读 → 标记未读。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:428
- FI-A35 [ui] 非“仅未读”过滤器下触发后条目自动回弹归位并留在列表中（已读状态翻转）；“仅未读”过滤器下条目保持滑出直至从列表移除。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:119
- FI-A36 [ui] 过滤器或条目已读状态变化时，处于滑出状态的条目复位居中（复用的列表项不残留偏移）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:108
- FI-A37 [on_device] 滑动越过阈值时触发一次触觉反馈；触发后的自动回弹不再震动。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/SwipeableFeedItemPreview.kt:232

## 域: 编辑订阅源选择对话框（EditFeedDialog）
- FI-A38 [ui] Feed 页工具栏菜单编辑项：当前可见订阅源恰为 1 个时直接进入该源的 EditFeed 页，否则弹出选择对话框。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:892
- FI-A39 [ui] 选择对话框标题 `Edit feed`，正文为可滚动的可见订阅源列表（显示各源 displayTitle），每行前有未选中的单选按钮；仅有 `Cancel` 按钮，无确认按钮。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/EditFeedDialog.kt:41
- FI-A40 [ui] 点任一行（或其单选按钮）进入该订阅源的 EditFeed 页并关闭对话框；点 `Cancel` 或对话框外部仅关闭对话框。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/EditFeedDialog.kt:81

## 域: 通知权限说明对话框（ExplainPermissionDialog）
- FI-A41 [ui] 说明对话框无标题，正文 `Permission must be granted before notifications can be enabled.`，唯一按钮 `OK`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/ExplainPermissionDialog.kt:23
- FI-A42 [on_device] 点 `OK` 发起系统通知权限请求；点对话框外部/返回仅关闭说明对话框、不请求。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:1356
- FI-A43 [on_device] 结果契约：在 Settings 通知项或 EditFeed 页打开通知开关时，若未授权且系统需要先说明理由则先显示说明对话框，若未授权且无需说明则直接发起系统授权，已授权则直接生效（EditFeed 开关置开 / Settings 展开通知选择）；鸿蒙实现：notificationManager.isNotificationEnabled() 判定，未开启时先弹说明对话框，OK 后 requestEnableNotification()；差异：鸿蒙无 shouldShowRationale，改为“未授权即先说明”。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/editfeed/EditFeedScreen.kt:187
