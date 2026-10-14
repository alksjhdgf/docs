# 设置存储域卡（settings-store）

## 域: 设置持久化与默认值

- SS-A01 [backend] 所有设置写入后内存值立即更新并持久化到同一偏好存储，key 名与源一致（如 `pref_theme`、`pref_sync_freq`、`pref_max_item_count_per_feed`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:197
- SS-A02 [on_device] 修改任一用户设置后冷重启应用，设置值保持为修改后的值。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:188
- SS-A03 [backend] 未设置时默认值：theme=`SYSTEM`、darkTheme=`BLACK`、sort=`NEWEST_FIRST`、feedItemStyle=`CARD`、swipeAsRead=`ONLY_FROM_END`、itemOpener=`READER`、linkOpener=`CUSTOM_TAB`、syncFrequency=60 分钟、maxCountPerFeed=100、maxLines=2、textScale=1.0、font=`bundled/roboto_flex`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:188
- SS-A04 [backend] 布尔设置默认 true 的仅有：showFab、showThumbnails、useDetectLanguage、useDynamicTheme、openAdjacent、useInAppAudioPlayer、filter.recentlyRead、filter.read；其余布尔设置默认 false。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:230
- SS-A05 [backend] 主题/暗色/排序以小写枚举名存储（如 `system`、`black`、`newest_first`），读取时不区分大小写。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:199
- SS-A06 [backend] feedItemStyle 与 swipeAsRead 以大写枚举名存储（如 `CARD`、`ONLY_FROM_END`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:444
- SS-A07 [backend] itemOpener 存 `"0"`(READER)/`"3"`(CUSTOM_TAB)/`"2"`(DEFAULT_BROWSER)；读到旧值 `"1"` 视为 CUSTOM_TAB，其它未知值视为 READER。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:938
- SS-A08 [backend] linkOpener 存 `"3"`(CUSTOM_TAB)/`"2"`(DEFAULT_BROWSER)；读到 `"2"` 以外任何值为 CUSTOM_TAB。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:932
- SS-A09 [backend] syncFrequency 以分钟数字符串存储，取值集合恰为 -1(Manually)/15/30/60/180/360/720/1440；无法识别的存储值解析为 MANUAL。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:878
- SS-A10 [backend] 枚举取值集合：ThemeOptions=`DAY`/`NIGHT`/`E_INK`/`SYSTEM`，DarkThemePreferences=`BLACK`/`DARK`，SortingOptions=`NEWEST_FIRST`/`OLDEST_FIRST`，FeedItemStyle=`CARD`/`COMPACT_CARD`/`COMPACT`/`SUPER_COMPACT`，SwipeAsRead=`DISABLED`/`ONLY_FROM_END`/`FROM_ANYWHERE`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:840
- SS-A11 [backend] 存储中出现非法枚举字符串时不崩溃，分别回退 theme→SYSTEM、darkTheme→BLACK、sort→NEWEST_FIRST、swipe→ONLY_FROM_END、itemStyle→CARD。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:948
- SS-A12 [backend] maxCountPerFeed 以十进制字符串存储（`"100"`），读写为整数。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:337
- SS-A13 [backend] setMaxLines 传入 ≤0 时 Store 不变；经 Repository 设置时值被钳到 ≥1。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:169
- SS-A14 [backend] 字体以路径字符串存储：`bundled/roboto_flex`、`system/default` 或用户字体相对路径；用户字体文件不存在或解析失败时回退 RobotoFlex。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:319
- SS-A15 [backend] OpenAI 设置与翻译 API 设置为两组独立键（`pref_openai_*` / `pref_translation_api_*`），各含 key/modelId/baseUrl/azureApiVersion/azureDeploymentId（默认空串）与 timeoutSeconds（默认 30）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:527
- SS-A16 [backend] 翻译首选语言与"默认翻译预览"使用遗留键名 `pref_openai_translation_language`、`pref_translate_feed_cards_by_default`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:754
- SS-A17 [backend] minReadTime 不持久化，每次进程启动初始化为当前时间；切换到不同 feed/tag 时重置为当前时间。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:132
- SS-A18 [backend] 上次 feed/tag、上次 widget feed/tag、上次文章 id、文章是否打开均持久化（`pref_last_feed_id` 等），默认 ID_UNSET/空串/false。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:653
- SS-A19 [backend] 列表过滤联动：关闭 recentlyRead 时同时关闭 read；开启 read 时同时开启 recentlyRead；unread 恒为 true。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:185
- SS-A20 [backend] 首次启动（`pref_added_feeder_news`=false）自动添加 `Feeder News` 订阅源 `https://news.nononsenseapps.com/index.atom` 并标记为已添加，之后不再添加。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:76

## 域: 屏蔽词（blocklist）

- SS-A21 [backend] 添加屏蔽词：空白输入被忽略；其余转小写并去首尾空白后保存，重复添加不报错且不产生重复项。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:481
- SS-A22 [backend] 屏蔽词列表按字母序返回原始词（不含内部 `*` 通配包裹）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:466
- SS-A23 [backend] 增删屏蔽词或切换"应用到摘要/链接"后，按标题（及开启时的摘要/链接）小写子串匹配重算文章屏蔽状态。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:226

## 域: 同步调度联动

- SS-A24 [on_device] 修改同步频率/仅 Wi-Fi/仅充电后，后台周期同步按新参数重新调度；频率为 `Manually` 时取消周期同步。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/background/RssSyncJob.kt:121

## 域: 设置导入导出（OPML）

- SS-A25 [backend] 导出 OPML 时 `<feeder:settings>` 仅包含 UserSettings 白名单内且已被写入过的键，值为字符串；会话状态键（last feed/article/widget、article open）不导出。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:630
- SS-A26 [backend] 导入 OPML 设置时 key 不区分大小写匹配白名单，未知 key 忽略；坏值回退（maxLines→≥1、textScale→1.0、maxCount→100、timeout→30）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OPMLImporter.kt:46

## 域: SettingsViewModel

- SS-A27 [backend] canTranslate 为真当且仅当翻译 API 设置可用且首选翻译语言去空白后非空。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/SettingsViewModel.kt:363
- SS-A28 [backend] 加载模型列表：先置 Loading，成功→Success(ids)，错误→Error(message)，缺 token/缺 Azure 版本/缺 Azure 部署 id→None；摘要与翻译两组状态互不影响。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/SettingsViewModel.kt:381
- SS-A29 [backend] 删除全部本地翻译语言对后，已下载语言对列表为空；删除单个后列表刷新为剩余项。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/SettingsViewModel.kt:228

## 域: 订阅源推荐

- SS-A30 [backend] 推荐数据来自内置 `feeds_mapped.json`（headline/author_name/feed_url/total_subscribers），加载失败时推荐为空而不崩溃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/data/suggestions/SuggestedFeedRepository.kt:131
- SS-A31 [backend] 查询长度 <2 或无长度 ≥2 的词元时返回空；否则返回标题/作者/URL 规范化文本（小写词元以单空格连接）包含查询规范化文本的源。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/data/suggestions/SuggestedFeedRepository.kt:102
- SS-A32 [backend] Substack 源 URL `https://<name>.substack.com/feed` 仅以 `<name>` 参与 URL 匹配。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/data/suggestions/SuggestedFeedRepository.kt:24
- SS-A33 [backend] 推荐结果按订阅人数降序（非数字视为 0），最多 10 条。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/data/suggestions/SuggestedFeedRepository.kt:125
- SS-A34 [ui] 推荐项标题为 headline；仅当作者非空且标题不含作者名（忽略大小写）时以作者作为描述，推荐区标题为 `Suggestions`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/searchfeed/SearchFeedViewModel.kt:125
