# 探索：text-settings（TextSettings 页 + 字体/缩放域 + truetype 解析）

断言卡：spec/cards/text-settings.md（TS-A01..A30；ui 19 / backend 11 / on_device 0）

## 1. 文件清单
| 文件 | 行数 | 作用 |
|---|---|---|
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt | 704 | 页面 Composable：TextSettingsScreen / View / SinglePane / DualPane / TextSettingsContent / Header / ScaleSetting / PreviewFontContent / UiFontOption |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettingsViewModel.kt | 243 | VM、FontSettingsState、FontSettingsEvent、FontSelection（sealed）、getFontSelectionFromPath |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/truetype/TrueTypeParser.kt | 288 | 手写 TTF 头 + fvar 轴解析 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/truetype/TrueTypeMetadata.kt | 7 | 数据类 weight/italic/slant FloatVariations? |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FontStore.kt | 163 | 字体文件 IO：列举/导入/删除，getFontMetadata |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:301-339 | | textScale/font/addFont/removeFont/fontOptions 门面（Either） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:305-335, 721-722, 998 | | pref_body_text_scale / pref_font 持久化；defaultFont = RobotoFlex |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Errors.kt | 9 | AddFontError(cause) / RemoveFontError(cause) |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:123-340 | | 字体族构造（variableFont、userFontFamily、ProvideTypographySettings） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ProvideScaledText.kt | 26 | fontSize/lineHeight × fontScale |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ComposeProviders.kt:28-33 | | 全局提供 TypographySettings（来自 CommonActivityViewModel.textScale/font） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/SliderWithLabel.kt:79 | | SliderWithEndLabels |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:1100 | | 通用 MenuSetting（DropdownMenu） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navigation/NavigationDestinations.kt:192 | | TextSettingsDestination path=`font/add`，launchSingleTop，deepLinks=empty |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/di/ArchModelModule.kt:84 | | VM 绑定 |
| res/font/roboto_flex.ttf, roboto_mono_variable_wght.ttf | | 内置可变字体（需随包迁移） |
| app/src/test/java/com/nononsenseapps/feeder/truetype/TrueTypeParserKtTest.kt | | 仅测 uBytesToUInt / 定点转换 5 例 |

## 2. 数据模型
- FontSelection（sealed）：path + min/max Weight/Italic/Slant；派生 hasWeightVariation(min>0&&max>min)、hasItalicVariation(min>=0&&max>min)、hasSlantVariation(max>=0&&max>min)；serialize()=path。
  - RobotoFlex：path `bundled/roboto_flex`，wght 100–1000，ital 0–0，slnt -10–0（→hasSlant=true）。
  - SystemDefault：path `system/default`，hasWeight/hasItalic 覆写为 true，wght 100–900，ital 0–1。
  - UserFont(path=文件名, 各轴默认 0)。getFile = fontsDir.resolve(path)。
- FontSettingsState：fontOptions(默认[SystemDefault])、sansSerifFont(默认 SystemDefault)、fontScale 1f、previewBold/Italic false、previewMonospace false（UI 中切换已注释掉，恒 false）、errorToDisplay Any?。
- FontSettingsEvent：SetSansSerifFont / SetFontScale / AddFont(uri) / RemoveFont / SetPreviewBold / SetPreviewItalic。
- UiFontOption(name, realOption?)：toString=name；realOption==null 代表 `Add font…`。用户字体 name = path.substringAfter("/")——path 不含 "/" 时返回整个文件名（含 .ttf）。
- 持久化：SharedPreferences `pref_font`(String path)、`pref_body_text_scale`(Float)。UserSettings 枚举 SETTING_FONT / SETTING_TEXT_SCALE（参与 OPML 设置导出/导入）。

## 3. 行为
### VM（TextSettingsViewModel）
- viewModelScope combine(repository.font, textScale, fontOptions, previewBold, previewItalic, errorToDisplay) → _viewState。
- SetSansSerifFont：与当前不同才 applicationCoroutineScope.launch { repository.setFont }。
- SetFontScale：直接同步 repository.setTextScale（每次滑动都写 SP，apply 异步）。
- AddFont / RemoveFont：applicationCoroutineScope 中执行，Left → errorToDisplay = error。errorToDisplay **从不清除**；页面 LaunchedEffect(key=errorToDisplay) 非空时 Toast。新的错误对象（cause 不同）即重新 Toast；离开再进页面会新建 VM（错误清空）。
- Preview Bold/Italic 只在 VM 内存。

### Repository
- addFont：fontStore.addFont(uri) 后 setFont(userFont)，异常包成 AddFontError。
- removeFont：仅 UserFont 有效：先 setFont(defaultFont=RobotoFlex) 再删文件；非 UserFont 时无操作返回 Right。

### FontStore
- getAllFonts（初始化时同步执行，构造时 IO）：fontsDir 中 isFile && name.endsWith(".ttf") 且 getFontMetadata 非空 → UserFont（**只填 weight/italic，未填 slant**），然后追加 SystemDefault、RobotoFlex。
- addFont：ContentResolver query DISPLAY_NAME 得文件名（null→RuntimeException）；fontsDir 中已存在→异常；IO 线程：cacheDir/<filename> 先删后建，openInputStream 拷贝；getFontMetadata 失败→删缓存+异常；mkdirs fonts，copyTo；返回 UserFont（同样未填 slant）；最后刷新 _fontOptions。注意：缓存文件成功后未删除（遗留在 cacheDir）。不检查扩展名：非 .ttf 名的有效文件会被选中但不会出现在列表中。
- removeFont：删文件、刷新列表。

### TrueType 解析（parseTrueTypeFont）
1. 读 4 字节须 == 00 01 00 00（不接受 'true'、'OTTO'/OTF、TTC 'ttcf'）。
2. 读 numTables(uint16)，跳到偏移 12。
3. 逐表目录项(16B)：tag==`fvar` 时读 offset、length 后 break；否则跳 12。
4. 若找到：skip 到 fvarOffset（stream.skip 需一次到位，否则失败）；跳 8 字节到 axisCount；读 axisCount、axisSize；跳 4；每轴读 tag、min、default、max（Fixed 16.16），识别 wght/ital/slnt；跳到 axisStart+axisSize。
5. 任意读不足 → IllegalArgumentException；getFontMetadata 捕获返回 null（=无效字体）。
- fixedType32ToSignedFloat：integer=高 16 位 toShort；结果 = integer + sign*(低16位/65536)。注：对负的非整数值（如 -10.5 编码为 0xFFF58000）此算法得 -11.5 而非 -10.5——"Sign logic for decimal is unclear" 源码注释承认，迁移时照搬以保持一致或明确修正（建议照搬，单测有基准）。

### 字体渲染（Typography.kt）
- ProvideTypographySettings：RobotoFlex→robotoSansFontFamily（资源可变字体，wght 100..1000 中的标准字重 × Normal/Italic，variation wght+ital）；SystemDefault→FontFamily.SansSerif；UserFont→userFontFamily(file)。mono：RobotoFlex→Roboto Mono 可变字体，其它→FontFamily.Monospace。
- userFontFamily：hasWeight→fontWeights 过滤 [min,max]，否则仅 Normal；hasItalic||hasSlant→Normal+Italic，否则仅 Normal；variableFont(file) 按 slnt 优先(Italic→slnt=min，Normal→0)、其次 ital(Italic→ital=max，Normal→0)。
- 全局：ComposeProviders 从 CommonActivityViewModel 收集 textScale/font；Typography 所有级别 merge sansFontFamily；ProvideScaledText 在 11 处使用（文章正文/列表等，非本区）。

## 4. 页面布局结构（Compose）
- Scaffold(nestedScroll enterAlways TopAppBar；windowInsets 水平 navigationBars；contentWindowInsets=statusBars) → SensibleTopAppBar(title `text_settings`, nav ArrowBack `go_back`)。
- 内容 Box(TopCenter, padding+navigationBarsPadding)：
  - SINGLE（WindowWidthSizeClass.Compact）：Column(spacedBy 8, width=dimens.maxContentWidth, padding margin/8, verticalScroll){ TextSettingsContent; PreviewFontContent }
  - DUAL：Row(width maxContentWidth){ Column(weight1){Content}（**不可滚动**）; Column(weight1, verticalScroll){Preview} }
- TextSettingsContent：
  1. Row{ MenuSetting(title `font`, subtitle 当前项名, icon=null, weight1) ; [UserFont 时] IconButton(Delete, `remove`) }
  2. Header `text_scale`（labelMedium, primary 色, heading 语义）
  3. ScaleSetting：SliderWithEndLabels(range 1..2, steps 9, 两端 "A" 字号 bodyLarge×1 / ×2)，semantics contentDescription=`Text scale`、stateDescription "%.1fx"，minHeight 64
  4. Header `text_preview`
  5. MultiChoiceSegmentedButtonRow{ `bold` ; `italic` }
- PreviewFontContent：ProvideScaledText(bodyMedium + weight/style + sansFontFamily) 内 10 个 Text（硬编码样例，非资源，contentDescription 均为 `Text preview`）。
- MenuSetting：整行可点切换 DropdownMenu；首项是高度 0 的隐藏 "close menu" 项（TalkBack 用，`close_menu`）；当前值项 bold + secondary 色；Esc 关闭。
- 字符串（res/values/strings.xml）：text_settings "Text settings"(363)、go_back "Go back"(162)、font "Font"(356)、system_default "System default"(358)、add_font "Add font…"(361)、remove "Remove"(196)、text_scale "Text scale"(226)、text_preview "Text preview"(357)、bold "Bold"(362)、italic "Italic"(360)、could_not_add_font(364)、could_not_remove_font(365)、something_went_wrong(366)、text "Text"(355)。

## 5. 入口/导航
- Settings 页 SettingsGroup `text` → ExternalSetting(副标题=当前字体 UiFontOption.name, 标题 `text_settings`) → TextSettingsDestination.navigate（Settings.kt:572-584，NavigationDestinations.kt:345）。
- ManageSettingsActivity.kt:41-50 用 `TextSettingsDestination.deepLinks.first()`，而 deepLinks=emptyList() → 源码中此路径会抛 NoSuchElementException（潜在 bug，属 ManageSettings 区；迁移时应改为直接路由到 TextSettings）。

## 6. 平台差异与鸿蒙实现要点
- 文件选择：ActivityResultContracts.OpenDocument(MIME ttf) → 鸿蒙 picker.DocumentViewPicker(select, fileSuffixFilters ['.ttf'])；返回 URI 后 fs.copyFile/openSync 读取。文件名：Android DISPLAY_NAME → 鸿蒙从 URI 末段解码或 fs.stat；结果契约：以原文件名保存到 filesDir/fonts。
- 自定义字体加载：Compose Font(file, variationSettings) → ArkUI `font.registerFont({familyName, familySrc:'file://...'})`（@ohos.font）或 Text.fontFamily；**ArkUI 不支持 per-Font variationSettings（wght/slnt 可变轴）**——只能用 fontWeight 让引擎合成/选择命名实例；RobotoFlex 的 slnt/italic 可变效果可能退化。
- 全局字体替换：Compose Typography 全局 → ArkUI 无全局 Typography，需在应用状态（AppStorage）中保存 fontFamily/scale，在所有 Text 显式绑定，或用自定义组件封装。
- 文字缩放：ProvideScaledText 乘 fontSize/lineHeight → 鸿蒙以 fp × scale 计算；注意系统字体缩放已在 fp 中叠加。
- StateFlow/combine → @ObservedV2/@Trace 或 AppStorage + PersistentStorage / preferences。applicationCoroutineScope → 异步函数不随页面销毁取消即可。
- Toast → promptAction.showToast。
- SegmentedButton 多选 → 两个 Toggle(ToggleType.Button)。
- WindowSizeClass Compact(<600vp) 判断 → 断点 / display 宽度。
- TTF 解析是纯字节逻辑，可在 ArkTS 用 ArrayBuffer/DataView 1:1 移植（大端），注意 uint32 偏移用 >>>0。

## 7. 降级候选
- 可变字体轴（wght 连续值、slnt/ital variation）：ArkUI Text 无 fontVariationSettings → 降级为注册整份字体 + fontWeight/fontStyle（引擎合成粗斜体）。
- RobotoFlex / Roboto Mono 的可变轴同上。
- MIME 过滤 `application/x-font-ttf`/`font/ttf` → 改为后缀过滤 .ttf。

## 8. 风险 / 注意
1. 源码不一致：FontStore 构造 UserFont 时不带 slant 值，而 SettingsStore 冷启动经 getFontSelectionFromPath 带 slant → 对带 slnt 轴的字体，冷启后当前选择与列表项 data class 不等，下拉高亮丢失、渲染斜体方式不同（Italic 走 slant vs ital）。迁移时建议统一（以 path 判等）。
2. errorToDisplay 永不清空；同类错误 cause 相同的 data class 相等时可能不再弹 Toast（实际每次异常对象不同，会弹）。
3. 导入不校验扩展名，非 .ttf 名文件导入成功后被选中但不出现在列表；cacheDir 拷贝残留。
4. 解析仅支持 0x00010000 头；OTF/TTC 一律 `Could not add font`。
5. 定点数负小数的符号处理与规范不一致（照搬以保持行为）。
6. ManageSettingsActivity 入口 deepLinks.first() 必崩（源码 bug）。
7. Bold/Italic 预览状态非持久化；previewMonospace 恒 false（死代码）。
8. Dual 模式左栏不可滚动。
