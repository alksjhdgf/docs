# text-settings TextSettings 页 + 字体域断言卡

## 页面: TextSettings
- TS-A01 [ui] 顶部内容避让状态栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:120
- TS-A02 [ui] 从 Settings 页 `Text` 分组的 `Text settings` 项（副标题显示当前字体名）进入本页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/Settings.kt:572
- TS-A03 [ui] 顶栏标题 `Text settings`；左侧返回按钮（无障碍 `Go back`）点击返回上一页。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:122
- TS-A04 [ui] `Font` 菜单项副标题显示当前字体名：RobotoFlex→`Roboto`、SystemDefault→`System default`、用户字体→其文件名（如 `Foo.ttf`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:645
- TS-A05 [ui] 点开 `Font` 下拉菜单，选项顺序固定：`Roboto`、`System default`、已导入用户字体（按文件名字典序）、最后 `Add font…`；当前字体项加粗高亮。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:275
- TS-A06 [ui] 选中非 `Add font…` 的字体项后，当前字体切换为该字体并持久化，副标题与下方预览文字字体随即更新；选中与当前相同的字体不触发写入。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettingsViewModel.kt:41
- TS-A07 [ui] 选中 `Add font…` 打开系统文件选择器，MIME 过滤为 `application/x-font-ttf`、`font/ttf`；用户取消选择则无任何变化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:304
- TS-A08 [ui] 导入成功后该字体自动成为当前字体，出现在下拉列表中，并在本页预览中生效。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:309
- TS-A09 [ui] 导入失败（无文件名、同名文件已存在、非 TrueType 0x00010000 头/解析失败、IO 异常）时弹 Toast `Could not add font`，当前字体不变。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:102
- TS-A10 [ui] 仅当当前字体为用户字体时，`Font` 行右侧显示删除按钮（无障碍 `Remove`）；内置字体时不显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:326
- TS-A11 [ui] 点删除按钮：当前字体回到 `Roboto`（RobotoFlex），该字体文件被删除并从下拉列表消失；失败时 Toast `Could not remove font`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:323
- TS-A12 [ui] 其它未知错误类型显示 Toast `Something went wrong`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:108
- TS-A13 [ui] `Text scale` 标题下有滑块，范围 1.0–2.0、步长 0.1（共 11 个刻度），两端分别为小号/大号字母 `A`；当前值超出范围时按边界显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:346
- TS-A14 [ui] 拖动滑块即时写入文字缩放并使下方预览文字字号随之按倍数变化（字号与行高同乘缩放值）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ProvideScaledText.kt:17
- TS-A15 [ui] 滑块无障碍描述为 `Text scale`，状态描述为一位小数加 x（如 `1.5x`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:447
- TS-A16 [ui] `Text preview` 标题下有 `Bold`/`Italic` 两个可独立多选的分段按钮，切换后预览文字分别变粗体/斜体；该状态仅本页临时，不持久化，重进页面恢复均未选中。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:386
- TS-A17 [ui] 预览区显示 10 行固定多语言样例（英、俄、希腊、阿拉伯、希伯来、印地、简中 `人人生而自由`、日、韩、泰），阿拉伯与希伯来两行右对齐，其余左对齐，均使用当前所选字体。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:523
- TS-A18 [ui] 窄屏（宽度 Compact）单栏：设置在上、预览在下，整体可纵向滚动；非 Compact 宽度双栏：左设置、右预览（右栏独立滚动）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettings.kt:161

## 域: 字体与文字缩放
- TS-A19 [backend] 字体选择持久化于 `pref_font`，值为路径：RobotoFlex=`bundled/roboto_flex`、SystemDefault=`system/default`、用户字体=文件名；未设置默认 RobotoFlex。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:319
- TS-A20 [backend] 启动读取 `pref_font` 时，若用户字体文件不存在或解析失败（或任何异常），回退为 RobotoFlex。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettingsViewModel.kt:212
- TS-A21 [backend] 文字缩放持久化于 `pref_body_text_scale`（Float，默认 1.0），每次滑块变化立即写入。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:305
- TS-A22 [backend] 用户字体存放于应用私有 `filesDir/fonts/`，以源文件显示名（DISPLAY_NAME）为文件名；导入流程先拷入 cacheDir 同名文件、解析校验通过后再复制到 fonts 目录；校验失败删除缓存文件并报错。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FontStore.kt:58
- TS-A23 [backend] 可选字体列表 = fonts 目录中以 `.ttf` 结尾且可解析的文件 + SystemDefault + RobotoFlex；导入/删除后列表实时刷新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FontStore.kt:35
- TS-A24 [backend] 同名字体文件已存在时导入失败（不覆盖）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FontStore.kt:65
- TS-A25 [backend] TrueType 解析：前 4 字节须为 `00 01 00 00` 否则判无效；在表目录中查找 `fvar` 表，读取轴 `wght`/`ital`/`slnt` 的 min/default/max（16.16 定点，有符号整数部分）；无 fvar 表时返回三者皆空（仍视为有效字体）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/truetype/TrueTypeParser.kt:24
- TS-A26 [backend] 16.16 定点转换：整数部分按有符号 16 位，小数部分=低 16 位/65536，按整数部分符号加减。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/truetype/TrueTypeParser.kt:271
- TS-A27 [backend] 可变字重判定 min>0 且 max>min；斜体轴判定 min>=0 且 max>min；倾斜轴判定 max>=0 且 max>min；SystemDefault 固定视为支持字重与斜体。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/settings/TextSettingsViewModel.kt:148
- TS-A28 [ui] 全局：所选字体作为全应用 sans 字体族（Material Typography 各级），所选缩放作为正文缩放倍数；等宽字体在 RobotoFlex 时用内置 Roboto Mono，其余用系统 Monospace。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:314
- TS-A29 [backend] 用户字体渲染：有字重轴时生成落在 [min,max] 内的标准字重；有倾斜轴时斜体用 slnt=min（负值前倾）、正体 slnt=0；否则有 ital 轴时斜体用 ital=max、正体 0。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:182
- TS-A30 [backend] OPML 导入设置：`pref_font` 经路径解析，失败回退 RobotoFlex；`pref_body_text_scale` 非数字回退 1.0。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OPMLImporter.kt:88
