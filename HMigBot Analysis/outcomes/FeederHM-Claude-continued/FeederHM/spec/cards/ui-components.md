# ui-components 通用 UI 组件域断言卡

## 域: 导航抽屉列表（订阅源/标签树、未读数）
- UC-A01 [ui] 抽屉列表第 1 项恒为 `All feeds`、第 2 项恒为 `Saved articles`（星形图标），即使没有任何订阅源或收藏也存在；其后为标签与订阅源。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:139
- UC-A02 [backend] `All feeds` 计数 = 全部订阅源中未读（read_time 为空）且未被屏蔽词命中的条目数；`Saved articles` 计数 = 已收藏条目数（非未读数）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:139
- UC-A03 [backend] 标签行计数 = 该标签下全部订阅源未读条目之和；订阅源行计数 = 该源未读条目数；被屏蔽词匹配的条目不计入任何计数。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/AppDatabase.kt:275
- UC-A04 [backend] 排序：`All feeds` → `Saved articles` → 各标签（按标签名）及其展开的子订阅源（紧随标签行，按显示标题不区分大小写）→ 无标签订阅源（按显示标题不区分大小写）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:160
- UC-A05 [backend] 有标签的订阅源仅在其标签处于展开状态时出现在抽屉中；无标签订阅源始终出现。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedDao.kt:156
- UC-A06 [backend] 标签展开状态为会话级内存状态，不持久化：应用进程重启后所有标签恢复折叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SessionStore.kt:24
- UC-A07 [backend] 订阅源在抽屉中的显示标题：自定义标题非空时用自定义标题，否则用订阅源原标题。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/AppDatabase.kt:275
- UC-A08 [ui] 标签行左侧箭头按钮点击仅切换该标签展开/折叠（不导航、不关闭抽屉），箭头朝向随展开状态翻转；点击标签名则导航到该标签的 Feed 并关闭抽屉。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:315
- UC-A09 [ui] 行尾未读数仅在计数 > 0 时显示（按当前语言区域格式化的整数），计数为 0 时不显示数字。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:498
- UC-A10 [ui] 订阅源行在有图标 URL 时显示异步加载的订阅源小图标，无图标 URL 或加载失败时保留空白占位、标题保持对齐；有标签与无标签订阅源行外观一致（无缩进）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:528
- UC-A11 [ui] 列表第 3 项若为标签或订阅源，则在其上方显示一条分隔线，将 `All feeds`/`Saved articles` 与订阅源区隔开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:164
- UC-A12 [ui] 标题单行显示，超长截断不换行。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:489
- UC-A13 [ui] 抽屉中的未读数随标记已读/未读、同步新条目、收藏变化自动刷新，无需重开抽屉。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/FeedStore.kt:71
- UC-A14 [ui] 无障碍：标签行状态描述为 `Open tag`/`Closed tag` 并提供 `Toggle tag expansion` 自定义动作；未读数朗读为复数串（如 `5 unread articles`）；订阅源图标描述 `Feed Icon`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:299

## 域: 主题与配色
- UC-A15 [ui] 主题选项为 `Day`/`Night`/`E Ink`/`System` 四项，默认 `System`（跟随系统深浅色）；`Day`/`E Ink` 恒浅色，`Night` 恒深色。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Theme.kt:261
- UC-A16 [ui] 深色模式下深色偏好为 `Black`（默认）时页面背景为纯黑 #000000；为 `Dark` 时背景为深灰 #191C19。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Theme.kt:292
- UC-A17 [ui] 未启用动态取色时使用 Feeder 固定绿色配色（浅色 primary #006D37、深色 primary #77DB93）；`E Ink` 主题为黑白高对比配色（primary 黑、背景白、文字黑）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Theme.kt:283
- UC-A18 [ui] `Dynamic colors` 开启（默认开）且系统支持时使用系统取色板生成配色；结果契约：配色随系统主题色；鸿蒙实现：无壁纸取色 API 时回退固定配色；差异：见探索文档降级候选。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Theme.kt:275
- UC-A19 [ui] 应用 edge-to-edge：状态栏透明，状态栏/导航栏图标深浅随主题（`Day`/`E Ink` 深色图标、`Night` 浅色图标、`System` 随系统）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Theme.kt:165
- UC-A20 [ui] 修改主题、深色偏好、动态取色、字体后所有已打开页面立即应用，无需重启。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ComposeProviders.kt:25
- UC-A21 [backend] 主题/深色偏好存储值无法解析时分别回退为 `System` / `Black`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:950
- UC-A22 [on_device] 主题、深色偏好、动态取色、字体设置在冷重启应用后仍保持。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:197

## 域: 字体与排版
- UC-A23 [ui] 全局界面字体可选内置 Roboto Flex（默认）、系统默认、用户导入字体，所选字体应用于全部界面文字样式。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:319
- UC-A24 [backend] 等宽字体（代码块/屏蔽词示例）：选 Roboto Flex 时用内置 Roboto Mono，其它选择用系统等宽字体。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:297
- UC-A25 [backend] 已保存的用户字体文件不存在或无法解析时回退为默认 Roboto Flex，不崩溃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:318
- UC-A26 [ui] 列表中未读条目标题为最粗字重（Black），已读为常规字重。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Typography.kt:250
- UC-A27 [ui] 顶栏标题单行省略，并按标题文字方向（RTL/LTR）对齐。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/SensibleTopAppBar.kt:36

## 域: 响应式尺寸
- UC-A28 [ui] 窄屏（宽度类 Compact，或高度类 Compact）使用手机布局：Feed 单列、内容最大宽 600vp；否则平板布局：窗口宽 >1360vp 为 4 列、>1028vp 为 3 列、否则 2 列，内容最大宽 min(840vp, 窗口宽)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Dimensions.kt:118

## 域: 通用对话框
- UC-A29 [ui] 确认对话框显示标题与正文，按钮 `OK` 执行确认操作、`Cancel` 关闭；点击对话框外或返回等同取消（如 `Leave sync chain` / `Are you sure you want to leave the sync chain?`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/components/ConfirmDialog.kt:24
- UC-A30 [ui] 重命名标签对话框标题 `Rename tag`，单行输入框预填当前标签名；`OK` 仅在输入非空白且不同于原名时可用，点击后执行重命名并关闭；`Cancel` 关闭不改名。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/dialog/RenameTagDialog.kt:35
- UC-A31 [ui] 可编辑列表对话框（屏蔽词 `Filters`）：输入框标签 `Add item`，按键盘"下一项"或硬件 Enter 添加当前文本并清空输入框；硬件 Esc 关闭对话框；无确认按钮，点击外部关闭。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/dialog/EditableListDialog.kt:91
- UC-A32 [ui] 可编辑列表每项右侧有删除按钮（无障碍描述 `Remove`），点击立即移除该项。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/dialog/EditableListDialog.kt:163
- UC-A33 [backend] 屏蔽词添加：空白输入被忽略；保存为去首尾空白的小写形式；重复项不重复添加且不报错。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/SettingsStore.kt:481
- UC-A34 [ui] 订阅源通知对话框标题 `Notify for new items`，每个订阅源一行（标题最多两行省略）带开关，点击整行或开关切换该源通知；唯一按钮 `OK` 关闭对话框；行无障碍状态 `On`/`Off`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/dialog/FeedNotificationsDialog.kt:100
- UC-A35 [ui] 表单底部 `Cancel`/`OK` 按钮组：右对齐，`Cancel` 在前、`OK` 在后，`OK` 可按表单合法性禁用；按钮组底部避让导航栏。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/components/OkCancel.kt:94
- UC-A36 [ui] 自动补全建议列表在输入框下方按需展开（限高可滚动），点击建议项回填/回调。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/components/AutoCompleteText.kt:43

## 域: 空态
- UC-A37 [ui] 空态显示三行居中文案 `Nothing to read here. Would you like to…`、`Open another feed?`、`Add more feeds?`，其中 `Open` 与 `Add` 以链接样式突出。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/empty/NothingToRead.kt:50
- UC-A38 [ui] 点击 `Open another feed?` 打开导航抽屉；点击 `Add more feeds?` 进入添加订阅源搜索页（SearchFeed）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/empty/NothingToRead.kt:65

## 域: 下拉刷新
- UC-A39 [ui] 仅在列表已处于顶部时继续下拉才拉出刷新指示器；下拉超过阈值松手触发刷新，未超阈值松手指示器回弹且不刷新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/pullrefresh/PullToRefreshState.kt:122
- UC-A40 [ui] 刷新进行中指示器停留并显示转圈，刷新结束后收回；刷新进行中再次下拉不重复触发刷新。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/pullrefresh/PullToRefreshState.kt:112

## 域: 翻译模型下载进度
- UC-A41 [ui] 进度文案三态：下载翻译引擎 `Downloading offline translation engine: N%`；准备中 `Preparing offline translation model X to Y…`（不确定进度条）；下载模型 `Downloading offline translation model X to Y: N%`（确定进度条）；下方恒显示 `First download can be 20–50 MB and may take a few minutes. Translation works offline afterward.`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/components/TranslationProgressContent.kt:24

## 域: 底部播放栏容器
- UC-A42 [ui] 底部操作栏（播客/朗读播放条）内容避让系统导航栏，操作按钮左排、悬浮按钮（如有）右侧。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/components/BottomAppBar.kt:139

## 域: 可见性追踪与按键拦截
- UC-A43 [backend] 可见性追踪：可见比例 = 组件与父容器可见区交集面积 / 组件面积；比例变化 ≥1% 才回调，`isAboveThreshold` = 比例 ≥ 阈值（Feed 滚动标记已读用 0.9）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/modifiers/TrackVisibility.kt:41
- UC-A44 [backend] 按键拦截：指定键在抬起时触发一次回调（按下不触发，避免重复），且该键不传递给子组件；其它键正常传递。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/modifiers/KeyEvents.kt:33

## 域: 表格布局（文章 HTML 表格）
- UC-A45 [ui] 文章表格列宽取该列最宽单元格、行高取该行最高单元格，跨行/跨列单元格尺寸均摊到所跨行列；表格超宽时可横向滚动；0×0 空表不崩溃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/layouts/Table.kt:79
- UC-A46 [backend] 表格单元格排序：非跨越单元格在前、单向跨越其次、双向跨越最后，同类按行再按列；跨越单元格出现在非跨越单元格之前视为非法。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/layouts/Table.kt:232

## 域: 图片加载与缩放
- UC-A47 [backend] 文章/卡片图片按 Fit/Crop/填满宽度缩放，但放大倍数不超过 max(屏幕像素密度, 1)，小图不会被过度放大。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/coil/RestrainedFitScaling.kt:24
- UC-A48 [ui] 图片加载中显示随当前内容色着色的占位图标，加载失败显示错误图标。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/coil/TintedVectorPainter.kt:11
- UC-A49 [backend] "仅 Wi-Fi 加载图片"开启且当前为计费网络时，图片只从缓存读取，无缓存则加载失败（不发起网络请求）；图片使用独立磁盘缓存，不挤占订阅源响应缓存；支持 .ico 图标解码。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:160
