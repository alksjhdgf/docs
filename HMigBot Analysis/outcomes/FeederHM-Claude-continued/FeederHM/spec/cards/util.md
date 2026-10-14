# 工具域卡（util）

## 域: URL 规整（LinkUtils）
- UT-A01 [backend] `sloppyLinkToStrictURL` 对空白/空串抛 MalformedURLException（`String is blank`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:12
- UT-A02 [backend] `sloppyLinkToStrictURL` 输入已是合法 URL（如 `https://google.com`）时原样返回；无 scheme 的输入（如 `google.com`）补 `http://` 得 `http://google.com`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:15
- UT-A03 [backend] `sloppyLinkToStrictURL` 遇到可解析为绝对 URI 但协议不受支持的输入（如 `gemini://google.com`）必须失败抛异常，不得补 `http://`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:20
- UT-A04 [backend] `sloppyLinkToStrictURLOrNull` 在 UT-A01/UT-A03 失败时返回 null 而不抛异常。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:37
- UT-A05 [backend] `sloppyLinkToStrictURLNoThrows` 在无法规整时返回占位 URL `http://`（不崩溃，供 DB 字符串→URL 转换与迁移使用）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:52
- UT-A06 [backend] 相对链接绝对化：link 本身是合法 URL 时原样返回，否则按 base 解析（`http://cowboy.com/feed.xml` + `/bob.jpg` → `http://cowboy.com/bob.jpg`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:95
- UT-A07 [backend] `relativeLinkIntoAbsolute` 解析失败时返回原 link 字符串；`relativeLinkIntoAbsoluteOrNull` 对 null 返回 null、失败返回原 link；`relativeLinkIntoAbsoluteOrNullIfNotValid` 失败返回 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:62
- UT-A08 [backend] `urlHasNoQueryParams` 对无 query 或 query 为空（`https://example.com/path?`）返回 true，有 query 返回 false。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:46
- UT-A09 [backend] `urlHasNoAuthParams` 对无 userInfo 或 userInfo 为空（`https://@example.com/path`）返回 true，含 `user:pass@` 返回 false。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LinkUtils.kt:44

## 域: 分享链接追踪参数清理（UrlCleaner）
- UT-A10 [backend] `stripTrackingParameters` 删除参数名（URL 解码后）以 `utm_` 或 `traffic_source` 开头的 query 参数，保留其余参数及其顺序（`?utm_source=rss&utm_medium=feed&id=123` → `?id=123`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/UrlCleaner.kt:23
- UT-A11 [backend] 删除后无剩余参数时整个 `?` 去掉（`https://example.com/article?traffic_source=rss` → `https://example.com/article`）；fragment 保留。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/UrlCleaner.kt:38
- UT-A12 [backend] 无追踪参数、无 query 或无法解析为 URI（如 `not a url`）时返回与输入逐字相同的字符串。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/UrlCleaner.kt:14
- UT-A13 [backend] 前缀匹配区分大小写（`UTM_source` 不删除）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/UrlCleaner.kt:33

## 域: HTML 图片提取（HtmlUtils）
- UT-A14 [backend] `findFirstImageInHtml` 先对输入做一次 HTML 实体反转义再解析，故 `&lt;img src=...&gt;` 形式的转义图片也能找到；输入 null 返回 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:20
- UT-A15 [backend] `findFirstImageInHtml` 返回第一个满足条件的 `<img>`：跳过 width 或 height 属性为 `1` 的跟踪像素、src 为空的、URL 含 `twitter_icon`/`facebook_icon`（不区分大小写）的；src 按 baseUrl 绝对化；width/height 取整数属性（非数字为 null）；结果 `fromBody=true`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:26
- UT-A16 [backend] `findFirstImageInHtml` 支持跨行的 `data:image/...;base64,` 内联图片，返回去掉换行后的完整 data URL。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:33
- UT-A17 [backend] `extractOgImage` 优先级：`og:image` 先于 `twitter:image`；同一 key 下 `meta[property]` 先于 `meta[name]`；同类多个取第一个非空；属性名/值大小写不敏感（`og:Image`、`<META PROPERTY=...>` 均命中）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:62
- UT-A18 [backend] `extractOgImage` 中 content 为空/全空白/缺失的 meta 视为不存在并继续回退（空 og:image → 取 twitter:image）；都没有时返回 null（空 HTML、无 head 也返回 null）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:83
- UT-A19 [backend] `extractOgImage` 将相对与协议相对 URL 按 baseUrl 绝对化（`/images/thumb.jpg`@`https://example.com/article/123` → `https://example.com/images/thumb.jpg`；`//cdn.example.com/image.jpg` → `https://cdn.example.com/image.jpg`）；返回 MediaImage（width/height 为 null，`fromBody=false`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:87
- UT-A20 [backend] `fetchOgImage` 发送带 `Accept: text/html` 的 GET，跟随重定向，并以最终响应 URL 作为相对路径的 base（302 到目标站后 `/images/hero.jpg` 解析到目标站）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:130
- UT-A21 [backend] `fetchOgImage` 非 2xx 抛 IOException；Content-Type 存在且子类型不是 `html`/`xhtml+xml` 时返回 null 不解析；只读取到 `</head>`（不区分大小写）为止，最多约 65536 字符，按 UTF-8 解码。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/HtmlUtils.kt:97

## 域: 嵌入视频识别（VideoTagHunter）
- UT-A22 [backend] `getVideo(src)` 仅当 src 含 `youtube.com/embed/<id>` 时返回 Video，id 截至 `?` 或 `/` 之前；imageUrl=`http://img.youtube.com/vi/<id>/hqdefault.jpg`，link=`https://www.youtube.com/watch?v=<id>`，默认尺寸 480×360；其他 src 或 null 返回 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/VideoTagHunter.kt:8

## 域: 外部链接打开（ActivityLauncher）
- UT-A23 [backend] `openLink` 对空白链接或以 `#` 开头的链接直接返回 false，不打开任何东西。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:60
- UT-A24 [backend] `openLink` 对 `mailto:` 链接走邮件客户端（ACTION_SENDTO），忽略打开方式设置。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:63
- UT-A25 [backend] `openLink` 其余链接按设置 `linkOpener`：`CUSTOM_TAB`（应用内浏览页，带工具栏颜色与分享菜单）或 `DEFAULT_BROWSER`（外部浏览器，新标签页）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:66
- UT-A26 [on_device] 无应用可处理链接时弹短 Toast `Install something to open this link with first`（`no_activity_for_link`）且返回 false，不崩溃；链接格式非法时静默返回 false。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:44
- UT-A27 [on_device] 当请求方允许、设备最小宽度 ≥600dp 且设置 `pref_open_adjacent`（默认 true）开启时，外部页面在分屏相邻窗口打开。结果契约：大屏时链接在并排窗口打开；鸿蒙实现：分屏/自由窗口启动 Want（若可用）；差异：无等价 API 时降级为普通启动。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:22

## 域: 自动同步前置条件（SystemUtils）
- UT-A28 [backend] 自动同步允许条件 = 已联网 且（未开"仅充电时同步"或正在充电）且（未开"仅 Wi-Fi 同步"或当前网络不计费）；计费判断依据系统"计费网络"标志而非网络类型，无法获取时视为不计费。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/SystemUtils.kt:11
- UT-A29 [backend] 图片加载在"仅 Wi-Fi 加载图片"开启且当前为计费网络时不发起网络加载（同一 `currentlyUnmetered` 判断）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/FeederApplication.kt:161
- UT-A30 [backend] `String.urlEncode()` 为 application/x-www-form-urlencoded UTF-8 编码（空格→`+`），用于深链 `tag` 参数与同步密钥。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/SystemUtils.kt:34

## 域: 动态快捷方式与字母图标（ContextExtensions / LetterIconProvider）
- UT-A31 [backend] 快捷方式 id=`"<feedId>"`，短/长标签=源显示标题，目标深链 `https://feederapp.nononsenseapps.com/feed?id=<feedId>`，rank=0；已存在同 id 则仅更新；新增前若已达 min(系统上限,3) 个则移除 rank 最大的一个。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt:32
- UT-A32 [backend] 快捷方式操作的任何异常被吞掉只打调试日志，不影响选源流程。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt:87
- UT-A33 [backend] 字母图标：圆形底色从 8 色中按 `abs(key.hashCode()) % 8` 取（同一 feedId 恒定同色），白色居中大写首字母；标题空白时用 `F`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/LetterIconProvider.kt:61
- UT-A34 [on_device] 选中具体源后系统桌面长按图标出现该源快捷方式，点击直达该源；结果契约：最多 3 个、最近用的在前；鸿蒙实现：动态 shortcut（如不支持动态则降级）；差异：见探索文档降级候选。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/archmodel/Repository.kt:122

## 域: 常量与文件布局
- UT-A35 [backend] 深链 host 固定为 `feederapp.nononsenseapps.com`，基址 `https://feederapp.nononsenseapps.com`（通知、小组件、快捷方式、导航路由共用）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt:109
- UT-A36 [backend] 外部链接常量：问题反馈 `https://github.com/spacecowboy/feeder/issues`，捐赠 `https://ko-fi.com/spacecowboy`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/BugReport.kt:9
- UT-A37 [backend] 目录布局：文章正文 filesDir/`articles`，全文 cacheDir/`full_articles`，字体 filesDir/`fonts`，HTTP 缓存 cacheDir/`http`，图片缓存 cacheDir/`image_cache`、cacheDir/`http_image_cache`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/FilePathProvider.kt:47
- UT-A38 [backend] 偏好键 `pref_max_item_count_per_feed` 以字符串存储，读取为 null 时回落默认值（默认 `100`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/PrefUtils.kt:8

## 域: 错误处理（Either）
- UT-A39 [backend] `Either.catching(onCatch, block)` 捕获 block 抛出的任何 Throwable 返回 Left(onCatch(t))，成功返回 Right；map/flatMap 只作用于 Right，Left 原样透传。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/Either.kt:307

## 域: 文本选择工具栏（FeederTextToolbar）
- UT-A40 [ui] 选中文本时浮动菜单按顺序显示 Copy/Paste/Cut/Select all 中当前可用的项，且仅当可复制时追加系统中所有"处理文本"应用（按显示名排序）作为溢出项。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/FeederTextToolbar.kt:113
- UT-A41 [on_device] 点选"处理文本"应用项时，以选中文本（经剪贴板中转）拉起该应用的 PROCESS_TEXT，随后恢复用户原剪贴板内容。结果契约：选中文本被送入第三方处理应用且剪贴板不被污染；鸿蒙实现：无 PROCESS_TEXT 生态，见降级候选；差异：可能只保留系统菜单。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/FeederTextToolbar.kt:154

## 域: 布局与输入适配（ui/compose/utils）
- UT-A42 [ui] 窗口宽度类为 Compact（<600dp）时页面按单栏布局（`ScreenType.SINGLE`），否则双栏（`DUAL`）；用于 TextSettings/EditFeed/SearchFeed/Import/SyncScreen。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/WindowSize.kt:80
- UT-A43 [ui] `isCompactDevice` = 高度类 Compact 或宽度类 Compact；`isCompactLandscape` = 横屏且高度类 Compact。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/WindowSize.kt:64
- UT-A44 [ui] 在带键盘的界面上按 Escape/Back/NavigateOut 键触发调用方传入的关闭/返回动作并消费该按键（用于菜单、抽屉、各页面返回）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/Focusable.kt:15
- UT-A45 [ui] 正文与阅读视图字号与行高按用户"文字缩放"系数等比放大。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ProvideScaledText.kt:16
- UT-A46 [ui] 文章署名中的作者名用 Unicode 双向隔离标记包裹，RTL 语言下 `by_author_on_date` 文案顺序正确。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ContextExtensions.kt:105
- UT-A47 [backend] 用 `mutableSavedStateOf` 声明的编辑页表单字段在进程重建后从保存状态恢复（键=属性名），首次读取与每次写入都回调 onChange。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/MutableSavedState.kt:23
- UT-A48 [backend] 运行时权限：API 级别低于 minimumApiLevel 时视为已授予（不弹框）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/Permissions.kt:19
