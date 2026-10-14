# 探索：settings-store（设置存储 / 订阅源推荐 / SettingsViewModel）

断言 ID 前缀：`SS`；断言卡：`spec/cards/settings-store.md`。
路径前缀省写：`F = input/Feeder/app/src/main/java/com/nononsenseapps/feeder`。

## 1. 范围与文件

| 文件 | 行数 | 角色 |
|---|---|---|
| `F/archmodel/SettingsStore.kt` | 998 | 全部用户设置 + 会话态（上次 feed/tag/article）的持久化，`MutableStateFlow` 内存镜像 + `SharedPreferences` 落盘；含 key 常量、`UserSettings` 导出白名单、所有枚举与 `*FromString` 解析函数 |
| `F/util/PrefUtils.kt:8-13` | — | `PREF_MAX_ITEM_COUNT_PER_FEED = "pref_max_item_count_per_feed"`；`getStringNonNull(key, def)` |
| `F/archmodel/Repository.kt:72-398, 848-870` | — | 对 SettingsStore 的薄包装，**部分 setter 带副作用**（见 §4） |
| `F/ui/compose/settings/SettingsViewModel.kt` | 525 | 设置页 VM：42 路 `combine` → `SettingsViewState`；OpenAI/翻译 API 事件；Bergamot 本地翻译模型对管理；电池优化豁免检测 |
| `F/data/suggestions/SuggestedFeedRepository.kt` | 241 | 离线订阅源推荐：加载 `res/raw/feeds_mapped.json`（5.7MB，24916 条 Substack 源），按查询文本做包含匹配，按订阅人数降序取前 10 |
| `F/ui/compose/settings/TextSettingsViewModel.kt:139-243` | — | `FontSelection`（`RobotoFlex`/`SystemDefault`/`UserFont`）与 `getFontSelectionFromPath`，SettingsStore 的 `pref_font` 依赖它 |
| `F/model/opml/OPMLImporter.kt:43-162` / `OpmlActions.kt:52` / `OpmlWriter.kt:58-70` | — | 设置随 OPML 导入导出（`<feeder:settings>`），白名单 = `UserSettings` |
| `F/FeederApplication.kt:112-114` | — | `SharedPreferences` = `PreferenceManager.getDefaultSharedPreferences(...)`（默认 prefs 文件） |
| `F/db/room/AppDatabase.kt:447-490` | — | Migration 23→24 从旧 prefs `pref_block_list_values`（StringSet）迁移到 `blocklist` 表 |
| 单测 `input/Feeder/app/src/test/java/com/nononsenseapps/feeder/archmodel/SettingsStoreTest.kt`、`PagingSettingsTest.kt` | — | 覆盖了大部分 setter/默认/坏值回退，可作为鸿蒙侧单测蓝本 |

## 2. 存储模型

- 单一 `SharedPreferences`（默认文件）。每个设置：启动时 `sp.getX(key, default)` 读入 `MutableStateFlow`，setter 先改内存再 `sp.edit().putX().apply()`（异步落盘）。读侧一律 `StateFlow`（`blockListPreference` 例外：来自 Room `blocklist` 表的 `Flow`）。
- **枚举持久化格式不统一**（迁移时必须逐项照抄，否则 OPML 互导与旧备份不兼容）：
  - `pref_theme`/`pref_dark_theme`/`pref_sort`：写 `name.lowercase()`（如 `system`、`black`、`newest_first`），读时 `uppercase()` 后 `valueOf`。
  - `pref_feed_item_style`/`pref_swipe_as_read`：写 `name`（大写，如 `CARD`、`ONLY_FROM_END`），读时 `uppercase()`。
  - `pref_default_open_item_with`/`pref_open_links_with`：写数字字符串 `"0"|"1"|"2"|"3"`。
  - `pref_sync_freq`：写分钟数字符串（`"-1"`/`"15"`/…/`"1440"`）。
  - `pref_max_item_count_per_feed`：**以字符串**存 int（`"100"`）。
  - `pref_body_text_scale`：Float；`pref_openai_request_timeout_seconds` 等：Int；`pref_last_*_id`：Long。
- `minReadTime` **从不落盘**（`SettingsStore.kt:47-56`，每次进程启动为 `Instant.now()`）。

## 3. 设置项全量清单（逐条对源）

锚点 = `F/archmodel/SettingsStore.kt:<行>`（StateFlow 定义行 / key 常量行）。"导出"= 是否在 `UserSettings`（OPML 导出/导入白名单，775-833）。

### 3.1 会话/导航状态（不导出）
| 属性 | key | 类型 | 默认 | 行 |
|---|---|---|---|---|
| addedFeederNews | `pref_added_feeder_news` | Boolean | false | 39, 648（**导出**，778） |
| minReadTime | —（不落盘） | Instant | now() | 47 |
| currentFeedAndTag | `pref_last_feed_id` / `pref_last_feed_tag` | Long / String | `ID_UNSET` / `""` | 58-80, 653-654 |
| currentWidgetFeedAndTag | `pref_widget_last_feed_id` / `pref_widget_last_feed_tag` | Long / String | `ID_UNSET` / `""` | 82-104, 655-656 |
| currentArticleId | `pref_last_article_id` | Long | `ID_UNSET` | 106-115, 657 |
| isArticleOpen | `pref_is_article_open` | Boolean | false | 117-126, 658 |

`setCurrentFeedAndTag`/`setCurrentWidgetFeedAndTag` 仅当值变化才写并返回 true（71-80）。

### 3.2 用户设置
| 属性 | key | 类型/取值 | 默认 | 行 |
|---|---|---|---|---|
| isMarkAsReadOnScroll | `pref_is_mark_as_read_on_scroll` | Boolean | false | 128, 724 |
| maxLines | `pref_max_lines` | Int，setter 忽略 ≤0 | 2 | 139-150, 726 |
| showOnlyTitle | `prefs_list_show_only_titles` | Boolean | false | 152, 732 |
| feedListFilter.saved | `prefs_filter_saved` | Boolean | false | 166, 728 |
| feedListFilter.recentlyRead | `prefs_filter_recently_read` | Boolean | **true** | 167, 729 |
| feedListFilter.read | `prefs_filter_read` | Boolean | **true** | 168, 730 |
| (feedListFilter.unread) | — | 恒 true | true | 995 |
| currentTheme | `pref_theme` | ThemeOptions{DAY,NIGHT,E_INK,SYSTEM} | SYSTEM | 188-200, 663, 840-847 |
| darkThemePreference | `pref_dark_theme` | DarkThemePreferences{BLACK,DARK} | BLACK | 202-214, 668, 849-854 |
| currentSorting | `pref_sort` | SortingOptions{NEWEST_FIRST,OLDEST_FIRST} | NEWEST_FIRST | 216-228, 674, 856-861 |
| showFab | `pref_show_fab` | Boolean | true | 230, 679 |
| syncOnResume | `pref_sync_on_resume` | Boolean | false | 238, 697 |
| syncOnlyOnWifi | `pref_sync_only_wifi` | Boolean；setter 重排周期同步 | false | 246-253, 695 |
| syncOnlyWhenCharging | `pref_sync_only_charging` | Boolean；setter 重排周期同步 | false | 255-263, 694 |
| loadImageOnlyOnWifi | `pref_img_only_wifi` | Boolean | false | 265, 702 |
| showThumbnails | `pref_img_show_thumbnails` | Boolean | true | 273, 703 |
| useDetectLanguage | `pref_readaloud_detect_lang` | Boolean | true | 281, 741 |
| useDynamicTheme | `pref_dynamic_theme` | Boolean；有效值 = 存值 && SDK≥31 | true(若 SDK≥31) | 290-303, 669 |
| textScale | `pref_body_text_scale` | Float | 1.0 | 305-317, 721 |
| font | `pref_font` | String 路径：`bundled/roboto_flex` / `system/default` / 用户字体相对路径 | RobotoFlex（`bundled/roboto_flex`）；解析失败/文件不存在回退 RobotoFlex | 319-335, 722, 998 |
| maximumCountPerFeed | `pref_max_item_count_per_feed` | String 存 Int | "100" | 337-344 |
| itemOpener | `pref_default_open_item_with` | ItemOpener{READER,CUSTOM_TAB,DEFAULT_BROWSER}；存 `"0"`/`"3"`/`"2"`；读 `"1"`(webview, 旧值)→CUSTOM_TAB；其它→READER | "0" READER | 346-369, 708, 716-719, 938-946 |
| linkOpener | `pref_open_links_with` | LinkOpener{CUSTOM_TAB,DEFAULT_BROWSER}；存 `"3"`/`"2"`；读 `"2"`→DEFAULT_BROWSER 其它→CUSTOM_TAB | "3" CUSTOM_TAB | 371-390, 709, 932-936 |
| openAdjacent | `pref_open_adjacent` | Boolean | true | 392, 710 |
| useInAppAudioPlayer | `pref_use_in_app_audio_player` | Boolean | true | 400, 711 |
| isPagingMode | `pref_paging_mode` | Boolean | false | 408, 713 |
| isAnimatedPaging | `pref_animated_paging` | Boolean | false | 416, 714 |
| showReadingTime | `pref_show_reading_time` | Boolean | false | 424, 734 |
| feedItemStyle | `pref_feed_item_style` | FeedItemStyle{CARD,COMPACT_CARD,COMPACT,SUPER_COMPACT} | CARD | 432-446, 681, 892-899 |
| swipeAsRead | `pref_swipe_as_read` | SwipeAsRead{DISABLED,ONLY_FROM_END,FROM_ANYWHERE} | ONLY_FROM_END | 448-464, 683, 901-907 |
| blockListPreference | Room 表 `blocklist.glob_pattern`（存 `*pat*`，读时去首尾一字符） | Flow<List<String>>，按 glob_pattern 排序 | 空 | 466-490 |
| applyBlocklistToSummaries | `pref_blocklist_apply_to_summaries` | Boolean | false | 492, 688 |
| applyBlocklistToLinks | `pref_blocklist_apply_to_links` | Boolean | false | 503, 689 |
| syncFrequency | `pref_sync_freq` | SyncFrequency 分钟：MANUAL(-1),15,30,60,180,360,720,1440；未知→MANUAL；setter 重排周期同步 | "60" EVERY_1_HOURS | 514-525, 696, 878-890, 983-988 |
| openAiSettings | `pref_openai_key`/`_model_id`/`_url`/`_azure_version`/`_azure_deployment_id`/`_request_timeout_seconds` | OpenAISettings(5×String,"" ; timeout Int) | ""×5, 30 | 527-551, 746-751, 909-916 |
| translationApiSettings | `pref_translation_api_key`/`_model_id`/`_url`/`_azure_version`/`_azure_deployment_id`/`_request_timeout_seconds` | 同上（typealias TranslationApiSettings） | ""×5, 30 | 553-577, 755-760 |
| preferredTranslationLanguage | `pref_openai_translation_language`（遗留名，注释要求保留） | String | "" | 579-588, 754 |
| translateArticlePreviewsByDefault | `pref_translate_feed_cards_by_default`（遗留名） | Boolean | false | 590, 763 |
| translateArticlesByDefault | `pref_translate_articles_by_default` | Boolean | false | 598, 764 |
| showTitleUnreadCount | `pref_show_title_unread_count` | Boolean | false | 606, 769 |
| openDrawerOnFab | `pref_open_drawer_on_fab` | Boolean | false | 614, 736 |
| forceSingleColumn | `pref_force_single_column` | Boolean | false | 622, 770 |

枚举显示文案（`input/Feeder/app/src/main/res/values/strings.xml`）：Theme `Day`/`Night`/`E Ink`/`System`（125-127,123）；Dark `Black`/`Dark`（131-132）；Sort `Newest first`/`Oldest first`（133-134）；Opener `Reader`/`Custom tab`/`Default browser`（102,105,104）；Sync `Manually`/`Every 15 minutes`/`Every 30 minutes`/`Every hour`/`Every 3 hours`/`Every 6 hours`/`Every 12 hours`/`Every day`（68-75）；ItemStyle `Card`/`Compact Card`/`Compact`/`Super compact`（179-182）；Swipe `Disabled`/`Only from end`/`From anywhere`（212-214）。

### 3.3 UserSettings 白名单（导出/导入）
49 项（775-833）：除 3.1 中的会话状态（last feed/tag/article/widget、isArticleOpen）外的全部 3.2 键 + `pref_added_feeder_news`。**OpenAI/翻译 API Key 也在白名单内 → 明文进入 OPML 导出文件**。`fromKey` 不区分大小写（836）。`getAllSettings()`（630-638）= `sp.all` 过滤到白名单、值 `toString()`；**未写过的键（仍为默认）不会出现在导出中**。

### 3.4 解析回退（坏值不崩溃）
`sortingOptionsFromString`→NEWEST_FIRST，`themeOptionsFromString`→SYSTEM，`darkThemePreferenceFromString`→BLACK，`swipeAsReadFromString`→ONLY_FROM_END，`feedItemStyleFromString`→CARD，`syncFrequencyFromString`→MANUAL（注意：不是默认 60！），`itemOpenerFromString`→READER，`linkOpenerFromString`→CUSTOM_TAB（948-988）。OPML 导入额外：maxLines 坏值→1 并 coerceAtLeast(1)；textScale 坏值→1.0；maxCount 坏值→100；timeout 坏值→30；font 不存在→defaultFont（OPMLImporter.kt:88-108,139,157）。

## 4. 带副作用的 setter（Repository / Store 层）

- `setSyncOnlyOnWifi`/`setSyncOnlyWhenCharging`/`setSyncFrequency` → `schedulePeriodicRssSync(di, replace=true)`（SettingsStore.kt:252,262,524）。`F/background/RssSyncJob.kt:108-147`：minutes<1(MANUAL) 取消 `RSS_SYNC_PERIODIC` 任务；否则 JobScheduler 周期任务，`setRequiresCharging(onlyCharging)`、网络 UNMETERED/ANY、`setPersisted(true)`。
- Repository `setFeedListFilterRecentlyRead(false)` 连带 `read=false`；`setFeedListFilterRead(true)` 连带 `recentlyRead=true`（Repository.kt:185-199）。
- Repository `setMaxLines(v)` → `coerceAtLeast(1)`（Repository.kt:169-171）。
- `addBlocklistPattern`：空白忽略；`lowercase().trim()` 后插入 `*pat*`，唯一约束冲突静默忽略（SettingsStore.kt:481-490；BlocklistDao.kt insertSafely）。Repository 增删模式及切换 applyToSummaries/Links 后 `runOnceBlocklistUpdate(di)`（Repository.kt:226-247），按 `lower(title|snippet|link) GLOB '*pat*'` 重算 `feed_items.block_time`。
- Repository `setCurrentFeedAndTag`：feedId>ID_UNSET 时加动态快捷方式；值变化时 `setMinReadTime(now)`（Repository.kt:115-135）。
- Repository init：若 `addedFeederNews==false` 则 upsert `Feeder News`（`https://news.nononsenseapps.com/index.atom`），置 true 并单次同步该源（Repository.kt:72-94）。
- `removeFont(UserFont)` 先 `setFont(defaultFont)` 再删文件；`addFont(uri)` 后自动选中（Repository.kt:309-337）。
- `setUseDynamicTheme` 落盘原值，但内存值在 SDK<31 恒 false（300-303）。

## 5. SettingsViewModel

- 42 路 `combine`（`SettingsViewModel.kt:279-377`）→ `SettingsViewState`（427-470）。**注意索引错位**：`translationApiState.modelsResult = params[31]`、`preferredTranslationLanguage = params[30]`（与组合顺序一致，非 bug）。`canTranslate = translationApiSettings.canUseAsTranslationApi && preferredTranslationLanguage.trim().isNotBlank()`（363）。
- `SettingsViewState` 默认值与 Store 默认**不一致**（首帧闪烁风险，非持久语义）：`showThumbnails=false`(store true)，`forceSingleColumn=true`(store false)，`font=SystemDefault`(store RobotoFlex)。
- 用 `applicationCoroutineScope`（脱离 VM 生命周期）执行：syncOnlyOnWifi、syncOnlyWhenCharging、syncFrequency、block list 增删、applyBlocklistTo*、toggleNotifications（68-144）。其余同步直调。
- `batteryOptimizationIgnoredFlow`：每次 `resumeTime` 变化查询 `PowerManager.isIgnoringBatteryOptimizations`（265-270）→ Android 特有。
- `feedsSettings`：`repository.feedNotificationSettings` → `UIFeedSettings(feedId,title,notify)`（253-263）；`toggleNotifications(feedId, value)`。
- OpenAI/翻译：`OpenAISettingsEvent` {UpdateSettings→保存, LoadModels→IO 线程调用 `openAIApi.listModelIds`, SwitchEditMode, ShowModelsError}（400-419）；`OpenAIModelsState` {None, Loading, Success(ids), Error(message)}；MissingToken/AzureApiVersionRequired/AzureDeploymentIdRequired → None（390-395）。
- Bergamot 本地翻译模型：init 时 `loadDownloadedLanguagePairs()`；`deleteLanguagePair(src,tgt)`；`deleteAllLanguagePairs()`（222-245）。

## 6. 订阅源推荐（SuggestedFeedRepository）

- 数据：`input/Feeder/app/src/main/res/raw/feeds_mapped.json`（5,713,743 B，24916 条；字段 `headline`,`author_name`,`language`,`feed_url`,`category`,`total_subscribers`(字符串数字)；仅用前四+subscribers，`ignoreUnknownKeys=true`，见 `F/di/ArchModelModule.kt:61-68`）。来源说明 `res/raw/feed_source.txt`（sidestack_scraper）。
- 懒加载、单例；加载失败 → 空列表（131-138）。`preload()` 由 SearchFeedViewModel 在 IO 线程调用（SearchFeedViewModel.kt:38-41）。
- `search(query, limit=10)`（102-129）：query 长度<2 → 空；分词 `[\p{L}\p{N}']+` 小写（Locale.ROOT），过滤长度≥2 的 token，无 token → 空；`normalizedQuery` = token 用单空格连接。**命中条件仅为** headline / author / url 的规范化文本包含 normalizedQuery；Substack 源 URL `https://X.substack.com/feed` 只用 `X` 参与匹配（14, 24-27）。结果按 `totalSubscribers`（非数字→0）**降序**，取前 limit。其它打分字段（exact match、token 计数）计算了但**未参与排序/过滤**。
- 调用端：SearchFeedScreen 对输入 `snapshotFlow` debounce 150ms，长度<2 清空，否则 `suggestionsFor`（SearchFeedScreen.kt:186-201）；映射为 `SearchResult(title=headline,url=feedUrl,description=author 若非空且 headline 不含 author(忽略大小写) 否则 "")`（SearchFeedViewModel.kt:116-139）；列表标题 `Suggestions`（strings.xml:22）。

## 7. 鸿蒙映射与平台差异

- SharedPreferences → `@ohos.data.preferences`（同一 key 名、同一字符串编码格式；`flush` 异步对应 `apply`）。StateFlow → AppStorage/@ObservedV2 或自建 observable store；需保证"内存先变、落盘异步"语义。
- 枚举字符串格式必须原样保留（§2），以兼容 OPML `<feeder:settings>` 互导。
- `useDynamicTheme`：鸿蒙无 Material You 动态取色，降级候选。
- `schedulePeriodicRssSync`（JobScheduler，persisted、充电/不计费网络约束、最短 15 分钟）→ 鸿蒙 WorkScheduler（`workScheduler.startWork`，`isRepeat`/`repeatCycleTime` 最小 2h(普通应用实际限制需实测)、`networkType`、`chargerType`）。15/30/60 分钟档位可能无法等价。
- `isIgnoringBatteryOptimizations` 无直接等价 → 降级。
- `itemOpener=CUSTOM_TAB` / `linkOpener=CUSTOM_TAB` 无 Chrome Custom Tabs；鸿蒙可用应用内 Web 组件或 `openLink`；需保留枚举值语义。
- 5.7MB JSON 放 `rawfile`，`resourceManager.getRawFileContent` + JSON.parse 一次性加载；需在 taskpool/worker 中解析避免 UI 卡顿。
- 正则 `\p{L}\p{N}` 在 ArkTS 需 `u` 标志（`/[\p{L}\p{N}']+/gu`）。
- Bergamot 本地翻译模型管理、OpenAI 列模型由其它区负责，本区只记录 VM 接口。

### 降级候选
1. `pref_dynamic_theme`（动态取色）——鸿蒙无等价，可保留键但恒失效。
2. 电池优化豁免状态检测（batteryOptimizationIgnored）。
3. 同步频率 15/30/60 分钟档（WorkScheduler 周期下限）。
4. Custom Tab 打开方式（映射为应用内浏览）。

## 8. 风险

1. 枚举存储格式不统一（lowercase / UPPERCASE / 数字码 / 分钟数 / 字符串化 int），实现时易"统一化"导致 OPML 互导失配。
2. `syncFrequencyFromString` 坏值回退 MANUAL（≠默认 60），易被误写。
3. API Key 明文存 prefs 且进入 OPML 导出（安全/隐私关注，但行为需保持）。
4. `getAllSettings` 只导出写过的键；若鸿蒙实现在首启时写入默认值，导出内容会变多（行为偏差但无害，需决策）。
5. VM 默认态与 Store 默认不一致（首帧）。
6. 推荐数据 5.7MB 解析性能；排序只按订阅数。
7. filter 联动（recentlyRead/read）在 Repository 而非 Store 层。
