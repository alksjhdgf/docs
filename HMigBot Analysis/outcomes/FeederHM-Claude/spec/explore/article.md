# 探索：Article 阅读页（区 article，断言前缀 AR）

前缀约定：`P` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder`，`R` = `input/Feeder/app/src/main/res`。

## 1. 范围与文件

| 文件 | 行数 | 角色 |
|---|---|---|
| P/ui/compose/feedarticle/ArticleScreen.kt | 832 | 有状态入口 `ArticleScreen(onNavigateUp,onNavigateToFeed,viewModel,mainActivityViewModel)`（:103）+ 无状态 `ArticleScreen(viewState,…)`（:234）+ 对话框 + `ArticleContent`（:641）+ `formatArticleDate`（:781）+ 摘要/翻译进度卡 |
| P/ui/compose/feedarticle/ArticleViewModel.kt | 1030 | `ArticleViewModel`、`ArticleScreenViewState`、`OpenAISummaryState`、`ArticleTranslationState`、`TSSError` |
| P/ui/compose/feedarticle/ReaderView.kt | 403 | 文章头部（标题/源名/作者日期/阅读时长/附件/头图）+ 正文槽 + 滚动条；`shouldShowHeaderImage`、`wordsToReadTimeSecs` |
| P/ui/compose/feedarticle/PodcastPlayerLinks.kt | 61 | `shouldOpenInPodcastPlayer`（音频扩展名表） |
| P/ui/compose/navigation/NavigationDestinations.kt:436-491 | — | `ArticleDestination`：路由 `reader/{itemId}`（LongType），深链 `$DEEP_LINK_BASE_URI/article/{itemId}`，`launchSingleTop` |
| P/ui/NavigationDeepLinkViewModel.kt:24-31 | — | 进入文章：`markAsReadAndNotified(itemId)` + `setCurrentArticle(itemId)` + `setIsArticleOpen(true)` |
| P/ui/MainActivityViewModel.kt:30-40 / P/ui/MainActivity.kt:55-71 | — | 音量键翻页 `scrollCommand`、`isPagingMode`/`isAnimatedPaging` |
| P/util/ActivityLauncher.kt | 130 | `openLink`/`openLinkInBrowser`/`openLinkInCustomTab`/`startActivity`（失败 toast `no_activity_for_link`） |
| P/util/UrlCleaner.kt:13 | — | `stripTrackingParameters`：分享前去掉 `utm_*`/`traffic_source*` 查询参数 |
| P/archmodel/Repository.kt:948-985 | — | `Article` 包装（id/link/feedDisplayTitle/title=plainTitle/snippet/enclosure/author/pubDate/feedId/feedUrl/bookmarked/fullTextByDefault/wordCount/wordCountFull/image）、`TextToDisplay` 枚举 |

**任务要求中的"上下篇"不存在**：全源 grep `nextArticle|previousArticle|next_article|previous_article` 0 命中；Article 页没有上一篇/下一篇导航。唯一相近的是"翻页模式"（同一篇内按屏滚动，见 §6）。不要在鸿蒙端发明上下篇。

测试：`input/Feeder/app/src/test/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ReaderViewKtTest.kt`（头图显示 4 用例）、`PodcastPlayerLinksTest.kt`。无 ArticleViewModel 单测。

## 2. 进入/离开与路由

- 路由 `reader/{itemId}`；FeedScreen 点条目（读者模式）调 `ArticleDestination.navigate(navController,itemId)`（P/ui/compose/feed/FeedScreen.kt:465,473）。
- `RegisterScreen` 中 `LaunchedEffect(itemId)` → `NavigationDeepLinkViewModel.setCurrentArticle`：
  - `repository.markAsReadAndNotified(itemId)`：SQL `UPDATE feed_items SET read_time = coalesce(read_time,:readTime), notified = 1`（P/db/room/FeedItemDao.kt:419）——已读时间仅首次写入；随后 `runOnceSyncChainSendRead`（Repository.kt:524）。
  - `setCurrentArticle(itemId)` 写 `pref_last_article_id`（SettingsStore.kt:657）；`setIsArticleOpen(true)` 写 `pref_is_article_open`。
- 返回：系统返回（`BackHandler`，ArticleScreen.kt:110）与顶栏返回箭头均调 `onNavigateUp`：`popBackStack()` 失败（深链冷启无后栈）则导航到 Feed（NavigationDestinations.kt:481-485）。
- 点源名（正文头部 feedTitle）→ `FeedDestination.navigate(navController, feedId=articleFeedId)`（:486-488）。
- ViewModel 由 SavedStateHandle 取 `itemId`（缺失抛 IllegalArgumentException，:95-97）；`scrollPosition` 与 `toolbarMenuVisible` 存 SavedStateHandle（进程重建恢复）。滚动位置 500ms 防抖保存（ArticleScreen.kt:122-126），重建时 `rememberScrollState(initial=viewModel.scrollPosition)`。

## 3. 页面结构（Compose 层级）

```
Scaffold(contentWindowInsets = statusBars; 水平 navigationBars 内边距; nestedScroll(enterAlwaysScrollBehavior))  ArticleScreen.kt:279
├─ topBar: SensibleTopAppBar(title = feedDisplayTitle, 随滚动收起/出现)          :286
│   ├─ navigationIcon: IconButton ArrowBack, cd `Go back`                          :297
│   └─ actions:
│       ├─ IconButton Article 图标, tooltip/cd `Fetch full article` → toggleFullText :305
│       ├─ IconButton OpenInBrowser, tooltip/cd `Open in Web view` → onOpenInCustomTab :316
│       └─ IconButton MoreVert, tooltip/cd `Open menu` → DropdownMenu（见 §4）      :327
├─ bottomBar: podcastPlayerState.isVisible ? HideablePodcastPlayer : HideableTTSPlayer :482（RA 区）
└─ content: Box(padding)
    ├─ ArticleContent → ReaderView(SelectionContainer > ColumnScrollbar > Column verticalScroll, spacedBy 16dp, testTag `readerColumn`)
    │   ├─ 头部块(宽 maxReaderWidth)：标题 headlineLarge(非空才显示) / 源名(链接样式, 可点) / 作者日期(medium alpha, 可空) / 阅读时长行(Timelapse 图标, readTimeSecs>0)
    │   ├─ 附件链接（enclosure.present && !isImage）`Open enclosed media` / `Open %1$s`
    │   ├─ 头图（条件见 §5）
    │   ├─ 翻译加载：TranslationModelDownloadProgress 卡 或 LinearProgressIndicator
    │   ├─ 摘要卡 SummarySection（openAiSummary != Empty）
    │   ├─ 正文：按 textToDisplay 分支（§5）
    │   └─ 底部 Spacer 92dp
    └─ 翻页模式：左 20% / 右 20% 透明点击区（§6）
对话框：SystemTranslationSettingsDialog、BergamotRuntimeDownloadDialog（§7）
```
Edge-to-edge：Scaffold `contentWindowInsets = WindowInsets.statusBars`（:284）→顶栏/内容避让状态栏。

## 4. 顶栏溢出菜单（DropdownMenu，ArticleScreen.kt:337-476）确定性清点

每项点击先 `onShowToolbarMenu(false)` 关菜单再执行动作。顺序：

| # | 条件 | 图标 | 文案 key → 英文 | 动作 |
|---|---|---|---|---|
| 1 | 总是 | Share | `share` → "Share" | onShare（§8） |
| 2 | `showSummarize` | AutoFixHigh | `summarize` → "Summarize" | viewModel.summarize() |
| 3 | `showTranslate` | Translate | 显示译文中：`show_original_language` "Show original (%1$s)"；否则 `translate_article` "Translate article"（参数=translationSourceLanguage，空时用 `original_article` "original"；注意 translate_article 无占位符） | viewModel.translate()（切换） |
| 4 | 总是 | VisibilityOff | `mark_as_unread` → "Mark as unread" | viewModel.markAsUnread() |
| 5 | 总是 | Star | 已收藏：`unsave_article` "Stop saving article"；否则 `save_article` "Save article" | setBookmarked(!isBookmarked) |
| 6 | 总是 | TextToSpeech | `read_article` → "Read aloud" | ttsPlay() |
| 7 | 总是（高度 0） | — | 无障碍 cd `close_menu` "Close menu" | 仅关菜单 |

菜单开闭状态 `toolbarMenuVisible` 存 SavedStateHandle（:131,:460-463）；Escape 键关闭（`onKeyEventLikeEscape`）。

条件：
- `showSummarize = openAISettings.canSummarize && !article.link.isNullOrEmpty()`（ArticleViewModel.kt:226）；`canSummarize = isValid && !isDeepL && !isLocalTranslation`（P/openai/OpenAIApi.kt:391）。
- `showTranslate = isShowingTranslated || (canRequestTranslation && alreadyInPreferredLanguage == null)`（:228）；`canRequestTranslation = translationSettings.canUseAsTranslationApi && preferredLanguage.isNotBlank() && link 非空`（:194-197）；`canUseAsTranslationApi = isValid && (isDeepL || isLocalTranslation)`（OpenAIApi.kt:397）。已检测为目标语言时菜单项隐藏。

## 5. ViewModel 状态与正文

### 5.1 viewState 组合（ArticleViewModel.kt:145-244）
18 个流 combine：articleFlow（`repository.getArticleFlow(itemId)` = DAO `getFeedItemFlow` 映射 `Article`）、textToDisplay、articleContentFlow、translatedArticleContent、toolbarVisible、linkOpener、useDetectLanguage、ttsState、ttsLanguages、openAISettings、translationApiSettings、preferredTranslationLanguage、openAiSummary、showTranslatedContent、articleTranslationState、bergamot downloadProgress、podcast playerState、useInAppAudioPlayer。关键派生：
- `articleTitle`：显示译文时为译文标题，否则 `plainTitle`。
- `isBottomBarVisible = ttsState != STOPPED || podcastPlayerState.isVisible`。
- `wordCount = isFullText ? wordCountFull : wordCount`（阅读时长随全文/摘要切换）。
- `articleContent`：显示译文时为译文线性化，否则原文。
- `isFullText = displayFullTextOverride ?: article.fullTextByDefault`（:142）。
- `articleId = itemId`（立即有值，非来自 DB）。
- 初始值 `ArticleState()`：`articleId = ID_UNSET(0)`，正文区要求 `articleId > ID_UNSET` 才渲染（ArticleScreen.kt:717）。

### 5.2 全文/摘要切换（toggleFullText，:321-328）
- 先把 textToDisplay 置 `LOADING_FULLTEXT`（"Fetching full article…"），翻转 override（`override?.not() ?: fullTextByDefault.not() ?: true`）；若正在显示译文则对新模式重新翻译。
- 内容解析 `parseArticleContent(article, fullText)`（:330-429，IO 线程）：
  - 摘要模式：读 `articleDir` 下 `<id>` 默认 blob（gzip）→ `HtmlLinearizer.linearize(stream, baseUrl=feedUrl)` → CONTENT；读失败 → `FAILED_TO_LOAD_FULLTEXT` + 空正文；blob 不存在 → 触发 `runOnceRssSync(feedId, forceNetwork=true, triggeredByUser=true)` 并显示硬编码英文道歉文案 + snippet（含 feeder#443 链接）。
  - 全文模式：全文 blob 不存在 → `fullTextParser.parseFullArticleIfMissing`；错误映射：NoBody→`FAILED_MISSING_BODY`，NoUrl→`FAILED_MISSING_LINK`，UnsupportedContentType/NotHTML→`FAILED_NOT_HTML`，FullTextTooLarge→`FAILED_FULLTEXT_TOO_LARGE`，其它→`FAILED_TO_LOAD_FULLTEXT`；存在则 linearize → CONTENT。
  - HtmlLinearizer 构造参数 tooLargeText=`failed_to_fetch_full_article_too_large`、openInBrowserText=`open_in_web_view`、articleLink（见 HM 区）。
- 正文分支文案（ArticleScreen.kt:718-776）：

| TextToDisplay | 显示 |
|---|---|
| CONTENT | ColumnArticleContent（HU 区渲染） |
| LOADING_FULLTEXT | `Fetching full article…` |
| FAILED_TO_LOAD_FULLTEXT | `Could not fetch full article` |
| FAILED_MISSING_BODY | `Found nothing to fetch` |
| FAILED_MISSING_LINK | `Feed is missing link to article` |
| FAILED_NOT_HTML | `Link is not an HTML document` |
| FAILED_FULLTEXT_TOO_LARGE | `Article is too large. Open in browser instead?` + 按钮 `Open in Web view`（→onOpenInCustomTab） |

注意：textToDisplay 是 VM 级状态，非 CONTENT 时整个正文被替换为文案（含翻译显示时）。

### 5.3 头部（ReaderView.kt）
- 标题：非空白才显示，headlineLarge，按段落 bidi 决定方向（:162-175）。
- 源名：titleMedium + 链接样式，点击 → onFeedTitleClick；头部块合并语义带自定义无障碍动作 `Go to %1$s`（`go_to_feed`）（:139-195）。
- 作者/日期（ArticleScreen.kt:676-694）：author==null&&pubDate!=null → `on_date` 即日期；两者都有 → `by_author_on_date` "%1$s, %2$s"（作者 unicodeWrap 以适配 RTL）；pubDate 为 null → 不显示（即使有作者）。日期格式 `formatArticleDate`：skeleton 24h 制 `yMMMMEEEEdHm`，否则 `yMMMMEEEEdhm`，用当前 locale 的 best pattern 与系统时区（:781-792）。
- 阅读时长：`readTimeSecs = round(words*60/220.0)`（:401）；>0 才显示；文本 = plurals `n_minutes`（count=分钟数）格式化 `"<min>:<ss>"`，英文 "%1$s minutes"/"%1$s minute"，如 9700 词 → `44:05 minutes`。
- 附件：`enclosure.present && !isImage`（type 以 `image/` 开头为 image）显示 `Open enclosed media`（name 空）或 `Open <name>`；点击：`useInAppAudioPlayer && shouldOpenInPodcastPlayer(link, enclosure)` → 内置播客播放，否则 `openLinkInBrowser`（总是外部浏览器，不看 linkOpener）。
- 头图：`shouldShowHeaderImage = showHeaderImage(textToDisplay==CONTENT) && image.fromBody==false && image.url ∉ articleContent.imageUrls`（:395-399）；再要求 `image.width` 为 null 或 ≥640，否则不显示（:304-315）；占位 Terrain、错误 ErrorOutline，tooltip `Article image`，cd=enclosure.name。
- 整个阅读列在 `SelectionContainer` 内：正文文本可长按选择复制。
- 滚动条：`ColumnScrollbar`（nanihadesuka 库），鸿蒙用 Scroll 自带 scrollBar。

### 5.4 链接点击（ArticleScreen.kt:722-742）
1. `index != null` 且已记录元素位置 → 页内平滑滚动到该元素（锚点）。
2. 否则 `useInAppAudioPlayer && shouldOpenInPodcastPlayer(link)` → 内置播客。
3. 否则 `activityLauncher.openLink(link, toolbarColor)`：空白或 `#` 开头忽略；`mailto:` → 邮件客户端（ACTION_SENDTO）；否则按设置 `pref_open_links_with`（默认 CUSTOM_TAB）→ CustomTab 或默认浏览器。无可处理应用 → toast `Install something to open this link with first`。
- `shouldOpenInPodcastPlayer`：链接空白/`#`开头→false；等于附件链接且附件 type `audio/*`→true；否则最后路径段（去 `#`/`?`）扩展名小写 ∈ {aac,flac,m4a,m4b,mp3,mp4,oga,ogg,opus,wav,weba}。
- `elementPositions` 下标偏移：ReaderView 从 offsetCounter=1 起，附件+1、头图+1，翻译加载+1、摘要卡+1，再加正文元素 index（:700-745）。实现上只需"锚点滚到目标元素"结果契约。

## 6. 翻页模式（e-ink）
- 设置 `pref_paging_mode`（默认 false）"Paging Mode"、`pref_animated_paging`（默认 false）"Animated Paging"（SettingsStore.kt:408-421, Settings.kt:822-836）。
- 开启时正文上叠一行：左 20% 点击 → 向上滚 0.9×视口高（≥0）；中间 60% 不拦截；右 20% 点击 → 向下滚 0.9×视口（≤max）；无点击涟漪；animated 时动画滚动否则瞬时（ArticleScreen.kt:531-575）。注意：左右区覆盖内容，会拦截该区域内的链接点击/选择。
- 音量键：`isPagingMode && isArticleOpen` 时 VOLUME_UP/DOWN 被消费并发出 UP/DOWN 滚动命令，同样 0.9 视口（MainActivity.kt:55-71，ArticleScreen.kt:128-151）。鸿蒙：音量键拦截能力有限，列为降级候选。

## 7. 翻译 / 摘要入口（详见 explore/translation.md、cards/openai.md）
- 菜单 Translate：`translate()`（:607-614）若已显示译文 → 仅切回原文；否则 showTranslated=true 并 `translateCurrentArticle()`。
- `translateCurrentArticle`（:616-688）：首选语言空 → toast `Set a preferred translation language in AI settings` 并清空；API 不可用 → 清空；检测已是目标语言 → AlreadyInPreferredLanguage（菜单项隐藏）；否则 Loading（正文顶部进度条/模型下载进度卡）→ 成功：译文 HTML 线性化显示、标题替换为译文标题、菜单变 `Show original (<源语言>)`；`SystemTranslationSettingsRequiredException` → 对话框（正文=异常消息；`Open settings` 打开系统设置并关闭；`Cancel`）；`BergamotRuntimeDownloadRequiredException` → 对话框标题 `Download offline translation engine?`、正文 4.9 MB 警告、`Download`/`Cancel`；其它异常 → toast 异常消息（缺省 "Translation failed"）并回到原文。
- `downloadBergamotRuntimeAndTranslate`（:882-893）：Loading → 下载成功则重新翻译，失败 toast `Could not download the offline translation engine.`。
- 翻译结果仅在 `isFullText` 与当前模式一致时生效（:187-192），切换全文/摘要后若在显示译文会重新翻译。
- 后台语言检测（:271-318）：设置可用时对当前模式 HTML 检测是否已是目标语言，命中则隐藏翻译菜单项。
- 打开时自动行为（:246-269，只执行一次）：订阅源 `summarizeOnOpen && canSummarize` → 自动摘要；`translateArticlesByDefault && canTranslate && canStartAutomaticArticleTranslation`（Local 模式需已有缓存或无需下载 Bergamot）→ 自动翻译。
- 摘要 `summarize()`（:583-605）：Loading 卡（线性进度）→ 输入为全文纯文本（Jsoup body.text()，无全文缓存则先抓取全文）→ 成功：Markdown→HTML→富文本段落；异常：错误文本直接显示（缺省 "Unknown error"）。

## 8. 分享 / 浏览器打开 / 已读 / 收藏 / 朗读
- 分享（ArticleScreen.kt:159-181）：仅 `articleId > 0`；系统分享选择器，`text/plain`，EXTRA_TEXT = `stripTrackingParameters(articleLink)`（link 为 null 则无文本），EXTRA_TITLE = articleTitle（注意：显示译文时为译文标题）。`stripTrackingParameters`：去除名字以 `utm_` 或 `traffic_source` 开头的查询参数，其它参数保留原值，全部去掉则去掉 `?`；无追踪参数则原样返回；URI 解析失败原样返回（UrlCleaner.kt:13-49）。
- 顶栏 `Open in Web view`（:182-186）：articleLink 非空 → **总是**以 CustomTab 打开（不看 linkOpener 设置），toolbarColor=surface；link 为空则无反应。
- 标为未读：`repository.markAsUnread(itemId)` → `UPDATE feed_items SET read_time = null` + `syncRemoteStore.setNotSynced(itemId)`（Repository.kt:527-531）；在 applicationScope 执行；**不离开页面**，且再次进入该文章才会重新标记已读（同一页面停留期间保持未读）。
- 收藏：`setBookmarked(itemId, !isBookmarked)` → `UPDATE feed_items SET bookmarked = :b`（FeedItemDao.kt:364）；articleFlow 反应式刷新 → 菜单文案在 Save/Stop saving 间切换。
- 打开即已读：见 §2（markAsReadAndNotified，coalesce 保留首次已读时间）。
- 朗读 `ttsPlay`（:465-536）：先停止播客；若暂停在同一 itemId 则恢复；否则读 **repository.getCurrentArticle()**（pref_last_article_id，而非 VM 的 itemId）→ 译文/全文/摘要 HTML → `htmlToAnnotatedString` → `ttsStateHolder.tts(textArray, useDetectLanguage, articleId=itemId)`；文件缺失静默不播（TODO 未提示）。详见 RA 区。
- 播客：`openPodcastPlayer(link)` 空白忽略，先停 TTS 再 `playLink(link)`；底栏 seek ±10 s。

## 9. 数据模型（鸿蒙需复刻）
- `ArticleScreenViewState` 32 字段（ArticleViewModel.kt:941-975）；`ArticleItemKeyHolder/RotatingArticleItemKeyHolder` 为 Compose key 计数器，鸿蒙可忽略。
- `OpenAISummaryState { Empty | Loading | Result(value, annotatedStrings) }`。
- `ArticleTranslationState { Empty | Loading | AlreadyInPreferredLanguage(sourceLanguage,isFullText) | SystemSettingsRequired(message) | RuntimeDownloadRequired | Result(translatedTitle, sourceLanguage, isFullText) }`。
- `TextToDisplay` 7 值（Repository.kt:977-985）。
- `Enclosure(present, link, name, type)`；`isImage = type.startsWith("image/")`。

## 10. 平台差异与鸿蒙映射

| 源 | 结果契约 | 鸿蒙实现 | 差异 |
|---|---|---|---|
| Intent.createChooser(ACTION_SEND text/plain) | 弹系统分享面板，文本=去追踪链接，标题=文章标题 | `@kit.ShareKit` systemShare `SharedData`(utd TEXT/HYPERLINK) + `ShareController.show` | 无 EXTRA_TITLE 等价，可放 title 字段 |
| CustomTabsIntent | 应用内浏览器标签打开文章链接 | ArkWeb 内嵌页（Web 组件页面）或 `startAbility` 系统浏览器 | 无 CustomTab；"Open in Web view" 可用 ArkWeb 页 |
| ACTION_VIEW + EXTRA_CREATE_NEW_TAB | 外部浏览器打开 | `context.openLink(url)` / startAbility(action=ohos.want.action.viewData) | — |
| mailto: ACTION_SENDTO | 打开邮件客户端 | `openLink('mailto:..')` | 视设备有无邮件应用 |
| ActivityNotFoundException toast | 无处理应用时提示 `Install something to open this link with first` | catch startAbility 错误 → promptAction.showToast | — |
| FLAG_ACTIVITY_LAUNCH_ADJACENT | 平板分屏打开 | 无等价 | 降级忽略 |
| Settings.ACTION_SETTINGS | 打开系统设置 | startAbility `com.huawei.hmos.settings` | 系统设置 bundle 名需实测 |
| SelectionContainer | 正文文本可选择复制 | Text `.copyOption(CopyOptions.LocalDevice)` / textSelectable | 跨多 Text 连续选择不可得 |
| SavedStateHandle（scrollPosition, toolbarMenuVisible） | 进程重建恢复阅读位置 | 页面内 @Local + 可选 AppStorageV2 | 鸿蒙无进程重建恢复语义，弱化 |
| 音量键 onKeyDown | 翻页模式音量键翻屏 | `onKeyEvent` 对音量键通常不可拦截 | 降级候选 |
| enterAlwaysScrollBehavior 顶栏 | 滚动隐藏顶栏 | Scroll onScroll 手动偏移/或固定顶栏 | 视觉，不入账 |
| viewModelScope / applicationScope | markAsUnread/bookmark 离开页面也完成 | 写库 Promise 不随页面取消（不绑组件生命周期） | — |

### 降级候选
1. 音量键翻页（MainActivity.onKeyDown）——鸿蒙普通应用难拦截音量键；保留左右点击区翻页。
2. CustomTab（toolbarColor、默认分享菜单项）——改用 ArkWeb 页或系统浏览器。
3. 平板 launch-adjacent 分屏打开链接——忽略。
4. 进程死亡后恢复滚动位置/菜单开闭——可弱化为页面内存态。
5. TalkBack 隐藏"Close menu"项、自定义无障碍动作 `Go to <feed>`——鸿蒙可用 accessibilityText 近似，非必须。

## 11. 关键风险
1. **全文抓取/HTML 线性化/Readability** 依赖自研 HTML 解析（jsoup 替代），错误枚举到 7 种 TextToDisplay 的映射必须照搬，否则失败文案错。
2. **blob 文件**：摘要 blob（`articleDir/<id>`）、全文 blob（`<id>.full.html.gz`）gzip 存取需 zlib；默认 blob 缺失走"重新同步 + 硬编码英文道歉文案"兜底分支。
3. 翻译状态机复杂（6 态 + isFullText 匹配 + 自动翻译 + 语言检测 + Bergamot 运行时下载对话框）；Bergamot/本地翻译在鸿蒙大概率无等价（见 translation 区），对话框路径可能无法触发。
4. 朗读用 `getCurrentArticle()`（全局当前文章）而非本页 itemId——迁移时保持"进入页即 setCurrentArticle"，否则读错文章。
5. "Open in Web view" 恒走 CustomTab，与正文链接按设置分流不同；附件恒走外部浏览器。三条路径要分开实现。
6. 分享标题在显示译文时是译文标题。
7. 阅读时长复数文案格式怪异（`44:05 minutes`），按 count=分钟整数选复数。
8. 不存在上下篇导航；不要添加。
