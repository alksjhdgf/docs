# 探索：edit-search（AddFeed / EditFeed / SearchFeed / Search / Import / 删除订阅源对话框）

断言卡：`output/FeederHM/spec/cards/edit-search.md`（EF-A01…EF-A58；ui 47 / backend 10 / on_device 1）。
相关已有卡（不重复）：app-shell（APP-A30~A46：ImportOPMLFile / AddFeedFromShare 的 Activity 路由）、feed-screen（FD-A20~A29 菜单入口）、feed-parser（FP-A46~A62 OPML 读写域）、feed-sync（FS-A44~A46 站点元数据）、settings-store（SS-A30~A34 推荐库）。

路径前缀 `P = input/Feeder/app/src/main/java/com/nononsenseapps/feeder/`。

## 1. 文件清单
| 文件 | 行数 | 内容 |
|---|---|---|
| P/ui/compose/editfeed/EditFeedScreen.kt | 763 | CreateFeedScreen / EditFeedScreen 包装、通用 EditFeedScreen（Scaffold+权限）、EditFeedView、LeftContent、RightContent、RulesField、ruleErrorText、`EditFeedScreenState` 接口 |
| P/ui/compose/editfeed/CreateFeedScreenViewModel.kt | 126 | 新建（AddFeed 路由） |
| P/ui/compose/editfeed/EditFeedScreenViewModel.kt | 194 | 编辑（EditFeed 路由）+ `isValidUrlOrUri` |
| P/ui/compose/searchfeed/SearchFeedScreen.kt | 809 | 搜索屏 UI、`SearchResult`（Parcelable: title,url,description,feedImage）、`isValidUrl` |
| P/ui/compose/searchfeed/SearchFeedViewModel.kt | 138 | 发现管线 `searchForFeeds`、推荐 `suggestionsFor` |
| P/ui/compose/deletefeed/DeleteFeedScreen.kt | 240 | `DeleteFeedDialog`（AlertDialog，非独立页面）、`DeletableFeed(id,title)` |
| P/ui/compose/ompl/OpmlImportScreen.kt | 323 | `OpmlImportScreen`（预览+确认）、`ViewState` |

共享组件：P/ui/compose/components/OkCancel.kt（`OkCancelWithContent` 可滚动 / `OkCancelWithNonScrollableContent`，按钮右对齐：TextButton `Cancel`(R.string.cancel) + TextButton `OK`(R.string.ok，app res 内未找到 `name="ok"`，应来自依赖库资源，英文 “OK”)）；P/ui/compose/components/AutoCompleteText.kt（`AutoCompleteResults`：内容下方 LazyColumn，最大高 3×TextField 最小高，宽 90%，2dp 圆角边框）；P/ui/compose/feed/ExplainPermissionDialog.kt；P/ui/compose/utils/Permissions.kt（`rememberApiPermissionState`，API<33 返回恒 Granted）；P/ui/compose/utils/MutableSavedState.kt（以属性名为 key 存 SavedStateHandle，首次读取触发 onChange）。

## 2. 路由与入口
- SearchFeed：`search/feed?feedUrl=`（可空）。入口：Feed 菜单 `Add feed`、空态 `Add more feeds?`。onClick(SearchResult) → `AddFeedDestination.navigate(url,title,feedImage)`（NavigationDestinations.kt:140-189）。
- AddFeed：`add/feed/{feedUrl}?feedTitle=&feedImage=`（feedUrl 以 Uri.encode 作路径段）。保存后 `FeedDestination.navigate(feedId)`（popUpTo graph inclusive，清空返回栈）（:218-273）。
- EditFeed：`edit/feed/{feedId}`（Long）。入口：Feed 菜单 `Edit feed`（可见源=1 直达，否则 EditFeedDialog 选择；EditFeedDialog 在 feed/EditFeedDialog.kt，属 feed-screen 区）。保存后同样跳 Feed（:275-312）。
- Search（分享）：AddFeedFromShareActivity 内 NavHost(start="search")；initialFeedUrl = intent.dataString ?: EXTRA_TEXT，trim。点结果 → 同 NavHost 内 AddFeed；保存 → `finish()`；向上 → 启动 MainActivity 并 finish（AddFeedFromShareActivity.kt:29-91）。
- Import：ImportOPMLFileActivity（Manifest :92，theme AppThemeDialog，excludeFromRecents，VIEW/SEND content:// MIME text/xml、application/xml、text/x-opml、application/octet-stream）。OK → 深链 `$DEEP_LINK_BASE_URI/feed?id=-10` 打开 MainActivity(NEW_TASK)+finish；Cancel → finish；向上 → MainActivity+finish。
- Feed 菜单内的 `Import feeds from OPML` **不走** Import 屏：直接 OpenDocument → `importOpml(di, uri)` 后台导入（FeedScreen.kt:210-219, 356）；导出 CreateDocument("text/x-opml")（FeedScreen.kt:199, 378）。Import 屏只出现在外部文件打开时。
- 删除对话框：Feed 页 `viewState.showDeleteDialog` 时渲染 `DeleteFeedDialog(feeds = visibleFeeds.map{DeletableFeed(id, displayTitle)})`（FeedScreen.kt:1319）；onDelete → `FeedViewModel.deleteFeeds` → applicationCoroutineScope 中 `repository.deleteFeeds`。

## 3. EditFeed/AddFeed 表单（逐项）
Scaffold：`enterAlwaysScrollBehavior` 顶栏 `SensibleTopAppBar(title = R.string.edit_feed)`（**AddFeed 也显示 "Edit feed"**）、返回图标 ArrowBack(`Go back`)；contentWindowInsets=statusBars；水平导航栏 inset。
内容：`OkCancelWithContent`（整体 verticalScroll，顶部 16dp，底部 24dp + 按钮 + 导航栏高度占位），okEnabled = `isOkToSave`。

LeftContent（EditFeedScreen.kt:331-480）：
1. `URL` — Material TextField(填充型)，singleLine，Uri 键盘、无自动更正、ImeAction.Next；onValueChange 存 `it.trim()`；isError=isNotValidUrl；下方 AnimatedVisibility 错误文本 `Not a valid URL`。
2. `Title` — OutlinedTextField，placeholder=defaultTitle，Words 大写，自动更正，Next。
3. `Tag` — OutlinedTextField 包在 AutoCompleteResults 内；focusGroup.hasFocus 控制候选显示；候选=allTags 过滤 `isNotBlank && startsWith(feedTag, ignoreCase)`；allTags 来自 `SELECT DISTINCT tag FROM feeds ORDER BY tag COLLATE NOCASE`（FeedDao.kt:49）；ImeAction.Done → 隐藏候选+键盘+焦点到右栏第一个开关。
硬件 Enter 被 `interceptKey` 拦截做焦点移动。

RightContent（:484-603）：SwitchSetting×6（顺序见 EF-A25），分隔线，GroupTitle `Open items by default with` + RadioButtonSetting×4，分隔线，GroupTitle `Article filtering rules` + bodySmall 描述（strings.xml:298）+ RulesField×2。
- 打开方式常量（SettingsStore.kt:716-719）：READER="0"，WEBVIEW="1"，BROWSER="2"，CUSTOM_TAB="3"；app default=""（其它任意值也算 app default，但 "1" 不算——四个单选均不选中）。
- RulesField：minLines 3 / maxLines 8，Monospace，ImeAction.Default（回车换行），placeholder `Title=(?i)sponsored`；错误显示 `ArticleRuleSet.parse(value).errors.firstOrNull()`；**规则错误不影响 OK**（VM 注释）。
- 规则解析：P/model/ArticleFilterRules.kt:149（MAX_RULES=100，字段 enum ArticleRuleField fromFieldName 忽略大小写）。

布局：ScreenType.DUAL（LocalWindowSizeMetrics → getScreenType）两栏 Row(width=maxContentWidth)，每栏 weight 1；SINGLE 一栏 + HorizontalDivider。

通知权限（:160-245）：`POST_NOTIFICATIONS`，minimumApiLevel=33。代理 state 的 notify setter：false 直接写；true 时 Granted→写 true；Denied+shouldShowRationale→显示 ExplainPermissionDialog（`permissionDismissed=false`）；Denied 无 rationale→launchPermissionRequest；结果回调写 notify=授予结果。ExplainPermissionDialog 只有 confirm `OK`（android.R.string.ok）按钮，onDismissRequest 关闭。

### ViewModel 差异
| 项 | CreateFeedScreenViewModel | EditFeedScreenViewModel |
|---|---|---|
| 初值 | SavedStateHandle 以属性名取：feedUrl（导航路径参数）、feedTitle（查询参数→Title 框也被预填）、defaultTitle=state["feedTitle"]、feedImage=state["feedImage"] | 必须 state["feedId"]，否则抛 IllegalArgumentException；init 协程 getFeed(feedId)（不存在则抛异常 → 崩溃），state 中不存在的 key 才从 DB 填 |
| Title 预填 | 搜索结果标题 | `feed.displayTitle`（customTitle.ifBlank{title}） |
| defaultTitle(占位) | 搜索结果标题 | `feed.title` |
| 保存 | `repository.saveFeed(Feed(... whenModified=now, imageUrl=sloppyLinkToStrictURLOrNull(feedImage)))` → `runOnceRssSync(feedId, triggeredByUser=false)` → action(feedId) | getFeed ?: Feed()；copy 覆盖 13 字段；`feed != updatedFeed` 才 whenModified=max(now, old+1ms)、saveFeed、runOnceRssSync；action(feed.id) |
| URL 校验 | `isValidUrlOrUri` = `java.net.URL(value)` 不抛即合法（只校验协议已知/格式）| 同 |

保存时 `URL(feedUrl)` 直接构造；OK 仅在合法时可用，故不抛。
`FeedStore.saveFeed`：id>0 → `updateFeed`（@Update，默认 ABORT）；否则 `insertFeed`（@Insert REPLACE）（FeedStore.kt:41, FeedDao.kt:24）。Feed.url 有唯一索引（Feed.kt:38）；FeedItem→Feed 外键 CASCADE（FeedItem.kt:66）。

## 4. SearchFeed / Search
UI 状态（SearchFeedScreen.kt:155-249）：feedUrl / currentlySearching / results / errors 均 rememberSaveable；suggestions 普通 remember；`currentSearchJob` 在 rememberCoroutineScope 中执行。
- onUrlChange：取消 job、清空结果/错误、currentlySearching=false。
- onSearch：清空，currentlySearching=true，取消旧 job，collect flow：Left→errors+=，Right→results+=；job 完成且仍为当前 job 时 currentlySearching=false。
- 传给视图的 errors：搜索中为空列表。
- 自动搜索：`LaunchedEffect(initialFeedUrl)`，条件 initialFeedUrl 非空白 && feedUrl==initialFeedUrl && 无结果无错误 && isValidUrl。
- 推荐：LaunchedEffect 内 `snapshotFlow{feedUrl}.debounce(150).collectLatest`，length<2 → 空，否则 `suggestionsFor(query)`（IO 预加载 `feeds_mapped.json`，24916 条，5.7MB，res/raw；search 最少 2 字符、词元 ≥2、包含匹配、按订阅数降序取 10）。显示描述=作者（作者非空且标题不含作者名）。
- 输入合法 `isValidUrl`（:782）：非空白且 `URL(s)` 或 `URL("http://"+s)` 不抛。注意 java.net.URL 不校验空格/主机名，故几乎任何非空白文字（如关键词 `hacker news`）都“合法”，Search 按钮可用，搜索会以 `http://hacker news` 抓取失败→显示错误卡+`Add anyway`。关键词发现只能靠本地推荐。
- 发起搜索参数 `sloppyLinkToStrictURLNoThrows`（LinkUtils.kt:52）：URL() → URI 绝对则 toURL → 否则 `http://`+s；全部失败 `URL("http://")`。
- 右栏顺序：推荐区（`Suggestions` labelLarge 左对齐 + SearchResultView 卡片）→ 错误卡（仅 results 为空时）→ 结果卡 → 进度指示（AnimatedVisibility）。
- Search 按钮文案 `android.R.string.search_go`（系统字符串，英文 “Search”）；鸿蒙需自建字符串。
- testTag：`urlField`、`searchResult`、`errorResult`、`searchingIndicator`（androidTest 机器人 P/../androidTest/.../ui/robots/SearchFeedScreenRobot.kt 使用）。EndToEndTest（@Ignore）：输入 `cowboyprogrammer.org` → Search 可用 → 点首个结果 → OK → 顶栏标题 `Cowboy Programmer`。

发现管线 `searchForFeeds`（SearchFeedViewModel.kt:49-100）：flow{} 中 `feedParser.getSiteMetaData(initialUrl)`；map 中对每个 URL `feedParser.parseFeedUrl(url)`；flowOn(Default)。YouTube 正则 `^https?://www\.youtube\.com/feeds/videos\.xml\?channel_id=UC([-_a-zA-Z0-9]{22})`，追加 playlist UULF/UUSH/UULV（常规视频/Shorts/直播）。siteMetaData 是 VM 级 mutableState，map 阶段可回填（用 feed.home_page_url）。HttpError.retryAfterSeconds → `repository.setRetryAfterForFeedsWithBaseUrl(host, now+s)`。
错误类型（FeedParserError 子类）及文案映射见 EF-A10；`NotInitializedYet` 显示硬编码 "Not initialized yet"（不应出现）。

## 5. Import（OPML 导入屏）
- `LaunchedEffect(uri)`：uri null → error；否则用一个**只收集 feeds 的** OPMLParserHandler（saveSetting/saveBlocklistPatterns 空实现）跑 `OpmlPullParser.parseInputStreamWithFallback`（OpmlPullParser.kt:66：先正常解析，失败则正则重写 outline 再解析）。抛异常 → error=true。返回 Left 不抛 → 仍按 feeds 判断（多为 `No feeds`）。
- ViewState：feeds: Map<URL,Feed>（按 URL 去重，后者覆盖）、error、initial；okEnabled=feeds 非空；feedCount=size；**tagCount=有非空白 tag 的 feed 个数（不是去重 tag 数）**——文案 “Import 3 feeds with 3 tags?” 在 3 个同 tag 订阅时出现，属源码行为。
- 文本：`import_x_feeds_with_y_tags` = `Import %1$s with %2$s?`，plurals n_feeds/n_tags（one=`%1$s feed`/`%1$s tag`，其它 `%1$s feeds`/`%1$s tags`；zero/two/few/many 英文都为复数）。ProvideScaledText（用户文字缩放）+ WithBidiDeterminedLayoutDirection。
- 列表：feeds.values sortedBy title，FlowRow：标题 titleSmall + url bodySmall。
- OK：`ApplicationCoroutineScope.launch { importOpml(di, uri) }`（OpmlActions.kt:67：OPMLImporter 真正写库，已存在 url 用 update 保留 id；导入设置/屏蔽词；`runOnceRssSync(triggeredByUser=true)`；失败 Toast `Failed to import OPML` + 异常消息），随后 onOk。注意文件被**解析两次**（预览一次、导入一次），需要 URI 读权限在 Activity 关闭后仍有效。
- 尺寸：Scaffold fillMaxHeight(DUAL 0.5 / SINGLE 1.0)；pinnedScrollBehavior；Activity 以 Dialog 主题呈现。有大段注释掉的 DUAL Dialog 方案。

## 6. 删除订阅源对话框
- 外层有状态版：`feedsToDelete: Map<Long,Boolean>` rememberSaveable；selectAllSelected = feeds 全部为 true（**feeds 为空时 all{} 为 true，Select all 显示为选中**）。
- OK：`onDelete(勾选 keys)` 后 `onDismiss()`；按钮为填充 Button（android.R.string.ok / cancel）。
- 标题行：`Delete feed`(titleMedium) + MoreVert IconButton(`Open menu`) → DropdownMenu：`Select all` 项（Checkbox + android.R.string.selectAll “Select all”）+ 一个高度 0 的隐藏项（无障碍 `Close menu`，供 TalkBack 关闭菜单）。
- 列表 LazyColumn，key=feed.id，行 requiredHeightIn(min=minimumTouchSize)，clickable 切换，stateDescription `Selected`/`Not selected`（androidx.compose.ui 资源）。
- 数据源：`repository.getCurrentlyVisibleFeedTitles()` → FeedStore.getFeedTitles：feedId>0 → 该源；tag 非空 → 该 tag 下（ORDER BY title NOCASE）；否则全部（ORDER BY title NOCASE）。注意按 title 排序但显示 displayTitle。
- 删除：Repository.deleteFeeds（Repository.kt:589）：`DELETE FROM feeds WHERE id IN (...)`（文章级联删除）、`ShortcutManager.removeDynamicShortcuts(ids)`、当前 feed 被删则 setCurrentFeedAndTag(ID_ALL_FEEDS=-10,"")。不触发远端同步链删除（无相关调用）。

## 7. 平台差异与鸿蒙映射
| Android | 结果契约 | 鸿蒙建议 |
|---|---|---|
| SavedStateHandle + mutableSavedStateOf（表单进程重建恢复） | 编辑中字段旋转/重建不丢 | ViewModel 级 @State + AppStorage/持久化 PersistentStorage 或页面 onSaveState；旋转在鸿蒙不重建页面，进程回收恢复可降级 |
| accompanist PermissionState POST_NOTIFICATIONS + rationale | 开通知需授权 | `notificationManager.isNotificationEnabled()` / `requestEnableNotification()`；无 “shouldShowRationale” 概念 → ExplainPermissionDialog 可简化 |
| `java.net.URL` 校验 | 合法判定规则（EF-A04/EF-A26） | 用 `@ohos.url` `url.URL.parseURL` 会更严格（拒绝空格、校验 host），行为不同；需自写宽松校验以保持“关键词也能点 Search” 或明确定义差异 |
| `LaunchedEffect`+`snapshotFlow.debounce(150).collectLatest` | 150ms 防抖推荐 | setTimeout 防抖 + 请求序号丢弃过期结果 |
| Flow 逐条 emit + Job.cancel | 结果逐条追加、输入变化即取消 | async 迭代 + 取消令牌（generation 计数） |
| ApplicationCoroutineScope（导入/删除脱离页面生命周期） | 导入页关闭后导入仍完成 | 模块级单例 Promise / taskpool；必要时短时任务 |
| ContentResolver.openInputStream(uri) 两次 | 预览+导入 | fileIo 打开 Picker/Want 传入 URI；外部 Want 打开的 URI 需持久化或复制到沙箱后再导入 |
| ShortcutManager.removeDynamicShortcuts | 删除源移除快捷方式 | 鸿蒙动态快捷方式能力有限 → 降级候选 |
| Activity 入口（分享、文件打开） | 见 app-shell | UIAbility + skills（uris/actions） |
| android.R.string.search_go / ok / cancel / selectAll、androidx selected/not_selected | 英文 “Search/OK/Cancel/Select all/Selected/Not selected” | 自建 string 资源 |

## 8. 降级候选
- 删除订阅源后移除对应动态快捷方式（EF-A58 的一部分）：鸿蒙若无动态快捷方式则省略。
- 通知权限 rationale 对话框（EF-A33 分支）：鸿蒙无 shouldShowRationale，可只保留请求授权。
- 表单进程死亡恢复（EF-A42）：鸿蒙无配置变更重建，进程回收恢复可降级。
- ScreenType.DUAL 两栏布局（EF-A14/EF-A37）：可按断点实现，必要时降级单栏。

## 9. 风险 / 实现须知
1. **AddFeed 重复 URL 会替换旧源**：insertFeed 为 REPLACE，url 唯一索引冲突时 SQLite 删除旧行（旧文章级联删除）并插入新行（新 id）。迁移是否复刻需决策（未入卡，若入则为破坏性行为）。
2. **EditFeed 改成已存在的 URL**：@Update 默认 ABORT → SQLiteConstraintException 在 viewModelScope 未捕获 → 崩溃。鸿蒙应至少不崩溃（建议 Toast/错误提示）。
3. EditFeed 指定 feedId 不存在时 init 抛异常崩溃；保存时源已被删则 `Feed()` 新建（id=0 → insert）。
4. AddFeed 顶栏标题为 `Edit feed`（非 `Add feed`），需照搬。
5. 两套 URL 校验不一致：SearchFeed 宽松（补 http://），Add/Edit 严格（必须带协议）；Search 结果 url 总带协议，故正常流转无碍。鸿蒙 URL API 更严格，需保留语义。
6. OPML 预览的 tagCount 语义是“带 tag 的订阅数”，非去重 tag 数；摘要文案依赖复数规则。
7. OPML 预览解析失败（Left）显示 `No feeds` 而非 `Failed to import OPML`；仅抛异常/uri 为空才显示失败。
8. `Select all` 在空列表时显示选中（all on empty）。
9. 推荐数据 5.7MB JSON 首次加载在 IO 线程，鸿蒙需放 taskpool/worker 并懒加载；rawfile 读取。
10. 搜索管线依赖 FeedParser.getSiteMetaData / parseFeedUrl（feed-sync / feed-parser 区）以及 Retry-After 处理。
11. 保存后 FeedDestination 清空返回栈，返回键将退出到桌面/上级而非回到 SearchFeed。
12. 预览时 OPML 设置与屏蔽词不会显示也不会写入；真正写入发生在 OK 之后（包括明文 API key 设置，见 FP-A50/A57）。
