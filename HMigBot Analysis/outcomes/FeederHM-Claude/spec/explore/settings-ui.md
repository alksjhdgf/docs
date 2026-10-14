# 探索文档：settings-ui（页面 Settings）

断言前缀：`ST`。卡片：`spec/cards/settings-ui.md`。
源文件（S = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/`）：
- `S/Settings.kt`（1787 行）：SettingsScreen / SettingsList / 通用设置行组件 / Option 包装类 / DownloadedModelsSection
- `S/SettingsViewModel.kt`（525 行）：SettingsViewModel、SettingsViewState、OpenAISettingsState/Event
- `S/SliderWithLabel.kt`（219 行）：SliderWithLabel / SliderWithEndLabels / SliderLabel
- `S/VisualTransformationApiKey.kt`（22 行）：API Key 掩码
- 相关：`input/Feeder/.../archmodel/SettingsStore.kt`（键、默认值、枚举）、`archmodel/Repository.kt`、`ui/compose/dialog/EditableListDialog.kt`、`ui/compose/dialog/FeedNotificationsDialog.kt`、`ui/compose/feed/ExplainPermissionDialog.kt`、`ui/compose/utils/Permissions.kt`、`util/ActivityLauncher.kt`、`util/BugReport.kt`、`ui/compose/navigation/NavigationDestinations.kt:314`

与其他区边界：OpenAISection/TranslationApiSection 对话框内部由 openai 区（AI-前缀）覆盖；存储键/默认值/枚举序列化由 settings-store 区（SS-前缀）覆盖；TextSettings 页由 TextSettings 区覆盖。本区只录 Settings 页本身可见结构、选项清单、依赖关系与点击结果。

## 1. 路由与外壳

- 路由 `settings`（`NavigationDestinations.kt:314`），`launchSingleTop`。ViewModel 由 `backStackEntry.diAwareViewModel()` 提供。
- 返回：`popBackStack()` 失败时导航到 `FeedDestination`（`NavigationDestinations.kt:333-336`）。
- `Device sync` → `SyncScreenDestination.navigate(syncCode="", secretKey="")`（:338-344）。
- `Text settings` → `TextSettingsDestination`（path `font/add`）（:345-347）。
- Scaffold（`Settings.kt:144`）：`contentWindowInsets = WindowInsets.statusBars`；水平方向避让导航栏；`SensibleTopAppBar` 标题 `Settings`（`title_activity_settings`），导航图标 ArrowBack，contentDescription `Go back`；`enterAlwaysScrollBehavior`（向下滚动时顶栏收起）。
- 内容 `SettingsList`：单列 `Column` + `verticalScroll`，水平 padding `dimens.margin`，每行宽 `dimens.maxContentWidth`（600/840dp，见 `theme/Dimensions.kt:64/84/97`），居中；末尾 `Spacer(navigationBarsPadding)` 避让底部导航栏。
- 组标题 `GroupTitle`（:974）：左侧 64dp 空位，高 64dp，labelMedium + primary 色，语义 heading。
- 组之间 `HorizontalDivider`。

## 2. 设置项逐条清点（按出现顺序）

缩写：Menu=MenuSetting（点行展开 DropdownMenu，副标题=当前值文本）；Switch=SwitchSetting（整行可点切换）；Ext=ExternalSetting（标题+副标题，点击执行动作）；List=ListDialogSetting；Action=ActionSetting。
默认值取自 `SettingsStore.kt`（真实持久化默认），非 `SettingsViewState` 的占位默认。

| # | 组 | 类型 | 标题（en） | 选项/副标题 | 默认值 | 依赖/条件 | 写入 | 锚点 Settings.kt |
|---|---|---|---|---|---|---|---|---|
| 1 | （无组） | Menu | `Theme` | `System`/`Day`/`Night`/`E Ink`（此顺序） | SYSTEM | — | repository.setCurrentTheme | 468 |
| 2 | （无组） | Switch | `Dynamic colors` | SDK<31：禁用+描述 `Only available on Android 12 and above` | true（SDK≥31 时；SDK<31 store 强制 false，SettingsStore.kt:290） | 仅 Android 12+ 可用 | setUseDynamicTheme | 484 |
| 3 | （无组） | Menu | `Preferred dark theme` | `Black`/`Dark` | BLACK | — | setPreferredDarkTheme | 504 |
| 4 | （无组） | 自定义 NotificationsSetting | `Notify for new items` | 副标题：权限被拒→`Permission must be granted before notifications can be enabled.`；否则已开启通知的订阅标题 `, ` 连接最多 3 个（第 4 个存在时追加 `...`） | 每订阅 notify 字段（DB） | API≥33 需 POST_NOTIFICATIONS 运行时权限 | toggleNotifications(feedId, value) | 518 / 1268 |
| 5 | `Block list` | List | `Filters` | 副标题：排序后的过滤词以空格连接，最多 5 个（超出追加 `...`） | 空 | — | addToBlockList / removeFromBlockList | 525-555 |
| 6 | `Block list` | Switch | `Apply to summaries` | — | false | — | setApplyBlocklistToSummaries | 557 |
| 7 | `Block list` | Switch | `Apply to links` | — | false | — | setApplyBlocklistToLinks | 563 |
| 8 | `Text` | Ext | `Text settings` | 副标题=当前字体名：RobotoFlex→`Roboto`，SystemDefault→`System default`，UserFont→路径第一个 `/` 之后部分（TextSettings.kt:645） | RobotoFlex（defaultFont） | — | 导航 TextSettings | 572-585 |
| 9 | `Syncing` | Menu | `Look for new articles…` | `Manually`/`Every 15 minutes`/`Every 30 minutes`/`Every hour`/`Every 3 hours`/`Every 6 hours`/`Every 12 hours`/`Every day`（SyncFrequency.entries 顺序） | EVERY_1_HOURS（"60"） | — | setSyncFrequency → 重排周期同步 replace=true（SettingsStore.kt:521） | 592 |
| 10 | `Syncing` | Switch | `Upon app start` | — | false | — | setSyncOnResume | 609 |
| 11 | `Syncing` | Switch | `Only on Wi-Fi` | — | false | — | setSyncOnlyOnWifi → 重排周期同步 | 615 |
| 12 | `Syncing` | Switch | `Only when charging` | — | false | — | setSyncOnlyWhenCharging → 重排周期同步 | 621 |
| 13 | `Syncing` | Menu | `Max items per feed` | `50`/`100`/`200`/`500`/`1000` | 100 | — | setMaxCountPerFeed | 627 |
| 14 | `Syncing` | Ext | `Battery optimization` | 副标题：已忽略电池优化→`Off`，否则→`On` | 系统状态 | 每次 resume 刷新（resumeTime 流） | 打开 `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` | 644 |
| 15 | `Syncing` | Ext | `Device sync` | 副标题空串 | — | — | 导航 SyncScreen | 656 |
| 16 | `Article list` | Menu | `Sort by` | `Newest first`/`Oldest first` | NEWEST_FIRST | — | setCurrentSorting | 670 |
| 17 | `Article list` | Switch | `Show floating action button` | — | true | — | setShowFab | 684 |
| 18 | `Article list` | Switch | `Show feeds after marking all as read` | — | false | 不依赖 FAB 开关（始终显示） | setOpenDrawerOnFab | 690 |
| 19 | `Article list` | Menu | `Article style` | `Card`/`Compact Card`/`Compact`/`Super compact` | CARD | — | setFeedItemStyle | 696 |
| 20 | `Article list` | Menu | `Max lines` | `1`…`10` | 2 | — | setMaxLines（Repository 钳 ≥1） | 708 |
| 21 | `Article list` | Switch | `Show only title` | — | false | — | setShowOnlyTitles | 718 |
| 22 | `Article list` | Menu | `Swipe to mark as read` | `Disabled`/`Only from end`/`From anywhere` | ONLY_FROM_END | — | setSwipeAsRead | 724 |
| 23 | `Article list` | Switch | `Mark as read on scroll` | — | false | — | setIsMarkAsReadOnScroll | 736 |
| 24 | `Article list` | Switch | `Show thumbnails` | — | true | — | setShowThumbnails | 742 |
| 25 | `Article list` | Switch | `Show estimated reading time` | — | false | — | setShowReadingTime | 748 |
| 26 | `Article list` | Switch | `Show unread article count in title` | — | false | — | setShowTitleUnreadCount | 754 |
| 27 | `Article list` | Switch | `Force single column` | — | false | — | setForceSingleColumn | 760 |
| 28 | `Reader` | Menu | `Open items by default with` | `Reader`/`Custom tab`/`Default browser` | READER | — | setItemOpener | 772 |
| 29 | `Reader` | Menu | `Open links with` | `Custom tab`/`Default browser` | CUSTOM_TAB | — | setLinkOpener | 789 |
| 30 | `Reader` | Switch | `Play audio links with built-in player` | 描述 `When disabled, audio links open with your default app instead` | true | — | setUseInAppAudioPlayer | 805 |
| 31 | `Reader` | Switch | `Open browser in split screen` | — | true | 仅 `smallestScreenWidthDp >= 600` 时显示 | setIsOpenAdjacent | 812-820 |
| 32 | `Reader` | Switch | `Paging Mode` | 描述 `Navigate articles by "turning pages" instead of continuous scrolling. Optimized for e-ink devices.` | false | — | setIsPagingMode | 822 |
| 33 | `Reader` | Switch | `Animated Paging` | 描述 `Briefly animate page turns. May cause ghosting on some e-ink devices.` | false | 仅 Paging Mode 开启时显示 | setIsAnimatedPaging | 829-836 |
| 34 | `Image loading` | Switch | `Only on Wi-Fi` | — | false | — | setLoadImageOnlyOnWifi | 841 |
| 35 | `Text to speech` | Switch | `Detect language` | 描述 `Automatically detects article language` | true | — | setUseDetectLanguage | 853 |
| 36 | `AI and translation` | OpenAISection | `Summary API` | info `Used for article summaries.` | — | 见 openai 区 | onSummaryOpenAISettingsEvent | 877 |
| 37 | `AI and translation` | TranslationApiSection | `Translation API` | info `Used for translating feed cards and articles.`；内嵌已下载模型区 | — | 见 openai 区 | onTranslationApiSettingsEvent | 885 |
| 38 | `AI and translation` | Switch | `Translate article previews` | — | false | 仅 canTranslate | setTranslateArticlePreviewsByDefault | 919-924 |
| 39 | `AI and translation` | Switch | `Translate articles by default` | — | false | 仅 canTranslate | setTranslateArticlesByDefault | 926-930 |
| 40 | （无组） | Action | `Send bug report` | BugReport 图标 | — | — | 打开 `https://github.com/spacecowboy/feeder/issues`（openAdjacentIfSuitable=true） | 936 |

注意：
- 两个 `Only on Wi-Fi` 同名开关：#11 是同步（`pref_sync_only_wifi`），#34 是图片加载（`pref_img_only_wifi`），由所属组标题区分。
- `canTranslate = translationApiSettings.canUseAsTranslationApi && preferredTranslationLanguage.trim().isNotBlank()`（SettingsViewModel.kt:363）；`canUseAsTranslationApi = canTranslate && (isDeepL || isLocalTranslation)`（openai/OpenAIApi.kt:397）。
- 选项文本来自 enum.stringId（SettingsStore.kt:840-906）；Option 包装类 `toString()` 返回本地化名，MenuSetting 用 `toString()` 显示（Settings.kt:1140/1188）。Int 型菜单（Max items、Max lines）直接显示数字。
- Max items 菜单当前值若不在 5 个候选中，副标题仍显示该数字，下拉中无高亮项。

## 3. 通用行组件行为

- **MenuSetting**（:1100）：整行点击切换 `expanded`（rememberSaveable）；DropdownMenu 首项为 0 高度的"关闭菜单"隐藏项（无障碍 contentDescription `Close menu`）；其后每个值一项，点击→关闭并 `onSelection(value)`；当前值项粗体 + secondary 色；Escape 键关闭；外部点击关闭。
- **SwitchSetting**（:1438）：整行点击→`onCheckedChange(!checked)`；`enabled=false` 时行与 Switch 都不可点；无障碍 role=Switch，stateDescription `On`/`Off`；可选 description 作为副标题。
- **ExternalSetting**（:1053）：标题+副标题（各单行省略），role=Button。
- **ActionSetting**（:1014）：图标+单行标题，role=Button。
- **RadioButtonSetting**（:1383）：本页未使用（被 TextSettings 等使用），role=RadioButton，stateDescription selected/not selected。
- **ListDialogSetting**（:1201）：点击打开 `EditableListDialog`；Settings 页只用于 Block list（showToggle=false）。
- **TitleAndSubtitle**（:1502）：titleMedium / bodyMedium，中间 2dp 间距。

## 4. 对话框清点

### 4.1 Block list —— EditableListDialog（ui/compose/dialog/EditableListDialog.kt:50）
- 标题区三段：`Filters`（titleLarge）、`Hides articles with titles containing any of these filters. Example filters:`、等宽字体示例 `feeder feed?r fe*er`（Settings.kt:530-546）。
- 列表：每条过滤词 + 删除图标按钮（contentDescription `Remove`），点击立即调用 removeFromBlockList。
- 底部（confirmButton 槽）为输入框，label `Add item`；IME Next 或 硬键盘 Enter → `onAddItem(newValue)` 并清空；Escape → 关闭。**无 OK/Cancel 按钮**，点外部关闭。
- 后端：add 时空白忽略，存 `lowercase().trim()`，唯一约束冲突忽略；add/remove 后触发 `runOnceBlocklistUpdate`（Repository.kt:226-234）。展示时去掉存储的首尾 `*`（SettingsStore.kt:467-476）。Settings 页列表按字母排序（Settings.kt:182 `.sorted()`）。

### 4.2 Notify for new items（Settings.kt:1268）
- 权限：`rememberApiPermissionState("android.permission.POST_NOTIFICATIONS", minimumApiLevel=33)`；API<33 视为已授予（Permissions.kt:19-23）。
- 点击行：
  - 已授予 → 打开 FeedNotificationsDialog；
  - 被拒且 shouldShowRationale → 显示 ExplainPermissionDialog（文本 `Permission must be granted before notifications can be enabled.`，按钮 `OK` → 再次发起权限请求；外部点击关闭）；
  - 被拒且无需解释 → 直接发起系统权限请求；授权结果回调 `expanded = granted`（授予后自动打开订阅通知对话框）。
- FeedNotificationsDialog（dialog/FeedNotificationsDialog.kt:40）：标题 `Notify for new items`；每个订阅一行（标题最多 2 行 + Switch），行/开关点击 → toggleNotifications(feedId, !notify)；唯一按钮 `OK` 关闭。订阅顺序：`COALESCE(NULLIF(custom_title,''), title) COLLATE NOCASE`（FeedDao.kt:66-74）。

### 4.3 已下载翻译模型（DownloadedModelsSection，Settings.kt:1644；嵌入 Translation API 编辑对话框）
- 显示条件：`canTranslate && visibleDownloadedLanguagePairs.isNotEmpty()`（:902）。
- 标题 `Downloaded translation models` + 描述 `Offline translation languages downloaded by Feeder. Remove languages you no longer need to free up space.`。
- 每对一行：`<源语言显示名> → <目标语言显示名>`（Locale 显示名，首字母大写，失败回退代码）+ 大小；删除图标（`Delete model`）→ 确认框：标题 `Delete model`，正文 `Delete the %1$s to %2$s translation model (%3$s)?`，按钮 `Delete model` / `Cancel`。
- 多于 1 对时追加 `Delete all downloaded models` 行 + 总大小 → 确认框正文 `Delete all %1$d downloaded translation model(s) (%2$s)?`，按钮 `Delete model` / `Cancel`。
- 确认删除仅加入 `pendingDeletedLanguagePairs`（立即从可见列表消失）；Translation API 对话框 Save 时才调用 `deleteLanguagePair` 实删；Dismiss 时清空待删集合（恢复显示）（Settings.kt:869-916）。
- formatFileSize（:111）：≥1MB → `%.1f MB`；≥1KB → `%.0f KB`；否则 `<n> B`（1024 进制）。

## 5. ViewModel（SettingsViewModel.kt）

- 42 路 `combine` 把 Repository 流合成 `SettingsViewState`（:276-378）。包含 Room 流（blockList、feedNotificationSettings）与 batteryOptimizationIgnoredFlow（resumeTime 映射 `PowerManager.isIgnoringBatteryOptimizations`）。
- 在所有流首发前，UI 显示 `SettingsViewState()` 占位默认值，其中若干与 store 默认不同：`showThumbnails=false`(store true)、`forceSingleColumn=true`(store false)、`useDynamicTheme=true`。迁移时应直接以 store 值初始化，避免闪烁。
- 写入线程：syncOnlyOnWifi / syncOnlyWhenCharging / syncFrequency / blocklist add/remove / applyBlocklist* / toggleNotifications 走 `applicationCoroutineScope`（离开页面仍完成）；其余同步调用 Repository。
- AI 事件：LoadModels（IO 线程拉取模型列表）、UpdateSettings（直接持久化）、SwitchEditMode、ShowModelsError；细节在 openai 区。
- 语言对：init 时 `loadDownloadedLanguagePairs()`；`deleteLanguagePair` 删除后重读列表。`deleteAllLanguagePairs` 存在但 UI 未使用（UI 的 Delete all 走逐对待删）。

## 6. SliderWithLabel.kt

- `SliderWithLabel(value, valueToLabel, valueRange, onValueChange, steps=0, labelMinWidth=28dp)`：滑块上方一个随值水平移动的气泡标签（primary 背景、圆角 10dp、onPrimary 文字、labelMedium）；偏移 = `(boxWidth - (labelMinWidth+8dp)) * fraction`，fraction = (coerce(value)-start)/(end-start) 钳 0..1，区间宽 0 时为 0（:137-154）。**主代码无调用**（仅 Preview）。
- `SliderWithEndLabels(value, startLabel, endLabel, valueRange, onValueChange, steps)`：滑块上方左右两端各一个 Composable 标签，SpaceBetween、底部对齐（:79）。被 `TextSettings.kt:450` 用于字号缩放（两个 "A"，字号分别 × valueRange.start / end）。
- 归属 TextSettings 页的视觉组件；本区仅记录 API。HarmonyOS 可用 `Slider` + `Row` 两端 `Text` 组合；气泡标签可用 `Slider` 的 `showTips` 或自绘。

## 7. VisualTransformationApiKey.kt

- 文本为空白或长度 < 10 → 原样显示。
- 否则显示 = `text[0..3]`（**前 4 字符**，因 `subSequence(0..PREFIX_LENGTH)` 是闭区间）+ `"*" × (len - 7)` + `text[len-3, len)`（**后 3 字符**）。总长度不变，`OffsetMapping.Identity`。常量名 `PREFIX_LENGTH=3`、`SUFFIX_LENGTH=4` 与实际显示（4/3）不一致——迁移按实际行为实现。
- 仅作显示变换，底层值与复制/编辑不受影响。用于 OpenAISection.kt:387 的 key 输入框（openai 区 AI-A11 已录同一断言，本区不重复）。
- HarmonyOS：TextInput 无 VisualTransformation 等价物；可用"显示文本=掩码，编辑时取真实值"的自定义组件，或 `InputType.Password` + 显隐切换（行为差异：Password 全掩码）。

## 8. 平台差异 / 降级候选

- **Dynamic colors（Material You）**：HarmonyOS 无系统动态取色等价 API。降级：保留开关但禁用并给出说明，或隐藏；需与主题区统一决策。
- **Battery optimization**：`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` + `PowerManager.isIgnoringBatteryOptimizations` 无直接等价。鸿蒙可跳转系统设置应用详情页（`startAbility` 到设置）或改为说明文字；副标题 On/Off 状态可能无法获取 → 降级候选。
- **POST_NOTIFICATIONS 权限**：鸿蒙用 `notificationManager.requestEnableNotification()`/`isNotificationEnabled()`；"shouldShowRationale"概念无等价，可简化为：未开启→请求→成功后打开对话框，拒绝后显示解释文本。
- **Open browser in split screen**（FLAG_ACTIVITY_LAUNCH_ADJACENT，sw≥600dp 才显示）：鸿蒙分屏由系统控制，无应用侧"相邻启动"等价 → 降级候选（可隐藏）。
- **Custom tab** 选项：鸿蒙无 Chrome Custom Tabs；需映射为应用内 Web 组件或系统浏览器（与 html-ui/app-shell 区统一）。
- **周期同步**（WorkManager，wifi/charging 约束）：鸿蒙 WorkScheduler 最小间隔约 2 小时（`repeatCycleTime` 下限），`Every 15 minutes`/`Every 30 minutes`/`Every hour` 可能无法精确实现 → 结果契约：选择后按所选频率调度；差异：系统可能放宽间隔。归 feed-sync 区落实。
- **Send bug report**：外部浏览器打开 GitHub issues URL；无可处理应用时 Android 弹 Toast `Install something to open this link with first`（ActivityLauncher.kt:44-47）。
- **TalkBack 隐藏关闭项**：无障碍细节，鸿蒙可用 accessibility 属性实现，非必须。
- **Escape 键关闭菜单/对话框**：硬键盘细节，非核心。

## 9. 迁移风险

1. 设置项多（40 行）且条件显示（Dynamic/SDK、split screen/sw600、Animated Paging/Paging Mode、翻译两开关/canTranslate、模型区），容易漏条件或漏项；需按本清单逐项核对。
2. 两个同名 `Only on Wi-Fi` 映射到不同键，易接错。
3. 改同步频率/Wi-Fi/充电必须触发周期任务重排；改 blocklist 必须触发 blocklist 重算（runOnceBlocklistUpdate）。
4. 占位默认值与真实默认值不一致导致首帧闪烁。
5. Translation 模型删除是"待删 + Save 才提交"的两阶段语义，易被实现成立即删除。
6. API key 掩码前 4 后 3（常量名误导）。
7. Block list 对话框无确认按钮，靠 IME Next/Enter 添加，且添加时转小写去空格。
