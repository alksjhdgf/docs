# 探索文档：html-ui（HTML 渲染 UI 域）

断言前缀：HU。断言卡：`spec/cards/html-ui.md`。
路径缩写（下文锚点均为工作区相对路径）：
- `LAC` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt`
- `TXT/` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/`
- `MH/` = `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/`

## 1. 范围与文件清单

| 文件 | 行数 | 作用 |
|---|---|---|
| ui/compose/html/LinearArticleContent.kt | 1536 | 线性化文章模型 `LinearArticle` → Compose 渲染（阅读器正文唯一渲染入口） |
| ui/compose/text/AnnotatedString.kt | 149 | `AnnotatedParagraphStringBuilder`：AnnotatedString.Builder 包装，追踪末两字符、可组合样式 |
| ui/compose/text/AnnotatedStringComposer.kt | 47 | `AnnotatedStringComposer : HtmlParser`，按段落产出 `List<AnnotatedString>` |
| ui/compose/text/HtmlComposer.kt | 107 | 抽象 `HtmlParser` + `withParagraph/withStyle/withAnnotation` + `Span` 密封类 |
| ui/compose/text/HtmlToAnnotatedString.kt | 400 | Jsoup HTML → `List<AnnotatedString>`（TTS 朗读与 AI 摘要显示用，**不是**阅读器正文渲染） |
| ui/compose/text/HtmlToComposable.kt | 166 | 杂项工具：`attrInHierarchy`、`asFontFamily`、`rememberMaxImageWidth`、空白规范化、`stripHtml`、`WithTooltipIfNotBlank` |
| ui/compose/text/Bidi.kt | 39 | `WithBidiDeterminedLayoutDirection`：java.text.Bidi 判定段落方向，切换 LocalLayoutDirection |
| ui/compose/text/Extensions.kt | 57 | `annotatedStringResource`：读 strings.xml 中 `<annotation style="link">` 转链接样式 |

依赖（不在本区，但渲染契约必需）：
- 数据模型 `MH/LinearStuff.kt`、`MH/LinearTextAnnotation.kt`（由 HtmlLinearizer 生成，属解析区）。
- 表格布局 `ui/compose/layouts/Table.kt`（`Table`、`TableData.fromCells`、`TableCell`）。
- 缩放 `ui/compose/coil/RestrainedFitScaling.kt`（`RestrainedFitScaling`/`RestrainedFillWidthScaling`）。
- 主题 `ui/compose/theme/Typography.kt:244-295`（`LinkTextStyle`=primary 色+下划线；`CodeInlineStyle`=surfaceVariant 背景+等宽；`CodeBlockBackground`=surfaceVariant；`OnCodeBlockBackground`=onSurfaceVariant）。
- `ui/compose/theme/Dimensions.kt:38,59,65,85,98`（`maxReaderWidth` 600dp/640dp；`hasImageAspectRatioInReader`）。
- `ui/compose/utils/ProvideScaledText.kt:10-25`（fontSize/lineHeight × `typographySettings.fontScale`）。
- `ui/compose/utils/Focusable.kt:30`（`focusableInNonTouchMode`：仅非触控输入模式可聚焦）。

## 2. 数据模型（渲染输入）

`LinearArticle(elements: List<LinearElement>)`（MH/LinearStuff.kt:7）
- `idToIndex: Map<String,Int>`：每个顶层元素的 `ids` → 元素序号（锚点跳转用）（:10-23）。仅顶层元素，嵌套元素的 id 不进入（只取 `element.ids()`）。
- `imageUrls`（lazy，递归收集图片 URL，含表格/引用/列表内）(:25-33)。

`sealed interface LinearElement` 7 种实现：
- `LinearText(ids, text, annotations: List<LinearTextAnnotation>, blockStyle: TEXT|PRE_FORMATTED|CODE_BLOCK)` (:342-360)
- `LinearListItem(ids, orderedIndex: Int?, content)`（orderedIndex 非空=有序列表可见序号）(:104)
- `LinearTable(ids,rowCount,colCount,cells: Map<Coordinate,LinearTableCellItem>)`；单元格 `type HEADER|DATA, colSpan,rowSpan,content`；`filler`=colSpan/rowSpan -1 的占位格 (:138-322)。RTL 表在 Builder.build 中镜像列坐标 (:236-250)。
- `LinearBlockQuote(ids, cite: String?, content)` (:324)
- `LinearImage(ids, sources: List<LinearImageSource>, caption: LinearText?, link: String?)`；`LinearImageSource(imgUri,widthPx?,heightPx?,pixelDensity?,screenWidth?)`，非正值构造即抛 IllegalArgumentException (:368-396)
- `LinearVideo(ids, sources)`（sources 非空 require）；`imageThumbnail`=首个有缩略图的源；`firstSource.link` 可能不同于 uri（YouTube embed）(:401-435)
- `LinearAudio(ids, sources)`（非空）；`firstSource.uri` (:440-456)
- `LinearList` 存在但**不是** LinearElement（渲染分支已注释掉，LAC:199-206,912）。

`LinearTextAnnotation(data, start 含, end 含)`；`endExclusive = end+1`（MH/LinearTextAnnotation.kt:3-16）。注解种类：H1..H6、Bold、Italic、Monospace、Underline、Strikethrough、Superscript、Subscript、Font(face)、Code、Link(href)。

## 3. 渲染入口

- `ColumnArticleContent(articleContent, onLinkClick, modifier, onElementPosition)`（LAC:153-188）——**实际使用**的入口：在 ReaderView 的 `Column + verticalScroll + SelectionContainer` 内逐元素渲染（ReaderView.kt:110,124；ArticleScreen.kt:720）。每元素：`ProvideTextStyle(bodyLarge + onBackground)` → `BoxWithConstraints(fillMaxWidth, 居中)` + `onGloballyPositioned` 回报 `positionInRoot().y` → `LinearElementContent(widthIn(max=min(maxWidth, maxReaderWidth)))`。
- `LazyListScope.linearArticleContent(...)`（LAC:121-151）——懒列表版本，`contentType=lazyListContentType`；**全仓无调用者**（grep 结果仅定义处）。迁移可不实现。
- `LinearElementContent(element, allowHorizontalScroll, idToIndex, onLinkClick)`（LAC:190-289）分派：ListItem→`LinearListItemContent`；Image→`LinearImageContent`；BlockQuote→`LinearBlockQuoteContent`；Text: TEXT→`LinearTextContent`，PRE_FORMATTED 与 CODE_BLOCK **都**→`CodeBlock`（PreFormattedBlock 已注释，LAC:244-253,719-761）；Table→`LinearTableContent`；Audio→`LinearAudioContent`；Video→`LinearVideoContent`。

`onLinkClick: (url: String, index: Int?) -> Unit` 是全区唯一的交互出口；index = 锚点在 `idToIndex` 中的元素序号（若有）。

## 4. 各块渲染行为（结果契约）

### 4.1 段落文本 `LinearTextContent`（LAC:616-639）
- `ProvideScaledText`（按用户字号缩放）→ `WithBidiDeterminedLayoutDirection(linearText.text)` → `Text(annotatedString, softWrap)`。
- 每个段落独立判 Bidi 方向：RTL 段落在 RTL 布局方向下显示（右对齐）。
- 可聚焦（仅键盘/非触控模式）并显示指示（indication）。

### 4.2 注解→样式 `LinearText.toAnnotatedString`（LAC:922-1048）
| 注解 | 样式 |
|---|---|
| Bold | FontWeight.Bold |
| Font(face) | `face.asFontFamily(typographySettings)`：monospace/serif/sans-serif（不区分大小写）映射到用户排版设置的字体；其他 → null（不改字体）(TXT/HtmlToComposable.kt:45-51) |
| H1–H6 | 全部统一 `typography.headlineSmall`（**不分级**） |
| Italic | FontStyle.Italic |
| Link(href) | `LinkAnnotation.Clickable`，样式 `LinkTextStyle`（primary 色 + 下划线）；点击：href 按 `#` split，若段数>1 取最后段查 idToIndex 得 index，否则 null；调用 `onLinkClick(href, index)` |
| Monospace | 用户设置的等宽字体 |
| Code | 若 blockStyle≠CODE_BLOCK：`CodeInlineStyle`（surfaceVariant 背景 + 等宽）；CODE_BLOCK 内忽略 |
| Subscript / Superscript | BaselineShift |
| Underline / Strikethrough | TextDecoration |
- 注意：PRE_FORMATTED 块内的 Code 注解**会**加内联代码背景（只排除 CODE_BLOCK）。
- 注意：锚点解析不区分同页/跨页：`http://other.com/x#foo` 中若当前文章恰有 id `foo`，也会被当作页内跳转（LAC:980-985）。

### 4.3 代码块 / 预格式 `CodeBlock`（LAC:763-813）
- Surface（surfaceVariant 背景，medium 圆角），内边距 8dp；文字色 onSurfaceVariant；`softWrap=false`（不自动换行）。
- `allowHorizontalScroll=true` 时可横向滚动；在表格单元格内为 false（不可单独横滚，表格整体横滚）。

### 4.4 列表项 `LinearListItemContent`（LAC:441-476）
- Row：前缀 `"${orderedIndex}."`（有序）或 `"•"`（无序），间距 8dp；右侧 Column 递归渲染 content（可嵌套任意元素）。
- 每个 ListItem 是独立顶层元素（列表已被线性化拍平），嵌套列表通过 content 递归。

### 4.5 引用 `LinearBlockQuoteContent`（LAC:641-717）
- Surface(surface 色, tonalElevation 2dp, medium 圆角)，起始 padding 8dp，内 padding 8dp。
- **只渲染 content 中的 LinearText**（`filterIsInstance<LinearText>()`，LAC:661-663）：引用里的图片/列表/表格/代码以外的非文本元素会被丢弃（CODE_BLOCK 的 LinearText 仍按普通文本渲染，因为直接调 LinearTextContent 而非分派）。
- 文本字重 Light。
- 有 `cite` 时在底部右对齐（Alignment.End）显示 cite URL 原文，bodySmall + tertiary 色 + 斜体，可点击 → 同锚点规则调用 onLinkClick(cite, index)。

### 4.6 图片 `LinearImageContent`（LAC:478-614）
- `sources` 为空 → 不渲染（return）。
- 最佳源选择 `getBestImageForMaxSize`（LAC:599-614）：对每个候选算 size：有 pixelDensity → `pd / 设备density`；有 screenWidth → `screenWidth / maxWidthPx`；有 widthPx → `widthPx / maxWidthPx`；否则 `1/设备density`；取 `|size-1|` 最小者。maxWidthPx=`rememberMaxImageWidth()` = 容器宽 px，上限 2000（TXT/HtmlToComposable.kt:53-61）。
- 请求尺寸：width = (pd 源→maxImageWidth；screenWidth；widthPx；否则 maxImageWidth)，height = heightPx ?? width；Coil `Scale.FIT`、`Precision.INEXACT`（大图缩小，小图不放大）。
- contentScale：`hasImageAspectRatioInReader` → RestrainedFitScaling，否则 RestrainedFillWidthScaling；放大倍数不超过 max(1,density)。
- placeholder：Terrain 图标；error：ErrorOutline 图标（着色矢量）。
- contentDescription = caption 文本。
- caption 非空白时长按显示 tooltip（`WithTooltipIfNotBlank` → PlainTooltipBox，TXT/HtmlToComposable.kt:152-166；FeedScreen.kt:1910）。
- `link != null` 时图片可点击，同锚点规则调用 onLinkClick(link, index)；link 为 null 不可点。
- caption 存在时在图片下方以 labelMedium 渲染（可含链接）。
- 图片区域 `DisableSelection`（不参与文本选择）。

### 4.7 视频 `LinearVideoContent`（LAC:321-415）
- 有 `imageThumbnail`：显示缩略图（尺寸取 firstSource widthPx/heightPx，否则 maxImageWidth 正方形请求），placeholder PlayCircleOutline，error ErrorOutline，contentDescription = `touch_to_play_video`；点击 → `onLinkClick(firstSource.link, null)`。
- 始终显示链接样式文字 `Touch to play video`（R.string.touch_to_play_video，strings.xml:138），点击 → `onLinkClick(firstSource.link, null)`。
- 应用内无视频播放器：交给 ArticleScreen 打开外部链接。

### 4.8 音频 `LinearAudioContent`（LAC:291-319）
- 仅一行链接样式文字 `Touch to play audio`（R.string.touch_to_play_audio，strings.xml:329），点击 → `onLinkClick(firstSource.uri, null)`。

### 4.9 表格 `LinearTableContent` + `Table`（LAC:815-907, 1512-1536；layouts/Table.kt）
- `toTableData`：跳过 filler；colSpan/rowSpan==0 表示“跨到末尾”(colCount-col / rowCount-row)。
- `TableData.fromCells` 排序：非跨格按行列在前，单向跨格其次，双向跨格最后（Table.kt:232-265）；init 校验跨格后不得出现非跨格（:214-223）。
- 布局：自定义 Layout 两遍测量，列宽=该列所有单元格最大宽，行高=最大高；跨格宽度平分到各列；整体可横向滚动（allowHorizontalScroll）。单元格最小宽高约束来自已记录列宽/行高（mutableStateMap，跨重组记忆）。
- 斑马纹：偶数行 background，奇数行 surfaceVariant；**表格任一单元格含图片则全部不着色**（LAC:836）。
- 列分隔线：非最后一列右侧画 1dp outlineVariant 竖线；无横线（已注释）。
- 单元格 padding 4dp，内容间距 4dp；HEADER 单元格加粗。
- 单元格内容递归 `LinearElementContent(allowHorizontalScroll=false)`（嵌套表格、代码块、列表、图片均可）。
- RTL 表格：列坐标在模型层已镜像，布局层始终从左往右摆放。

## 5. 文本工具（ui/compose/text）

### 5.1 Bidi（TXT/Bidi.kt:10-25）
`Bidi(paragraph, DIRECTION_DEFAULT_LEFT_TO_RIGHT).baseIsLeftToRight()` → Ltr/Rtl。无强方向字符时默认 LTR。调用方：LinearTextContent、ReaderView 标题/订阅源名/作者日期/阅读时长（ReaderView.kt:163,182,199,233）、FeedItemCard（:222,243,254,389,398）、SensibleTopAppBar 标题（:36）、OpmlImportScreen（:230,264）。

### 5.2 HTML → List<AnnotatedString>（TXT/HtmlToAnnotatedString.kt）
用途：**TTS 朗读文本**（ArticleViewModel.kt:484,501,518；FeedViewModel.kt:604,624）与 **AI 摘要显示**（ArticleViewModel.kt:743：Markdown→HTML→此函数；ArticleScreen.kt:806-831 SummarySection 逐段 Text 显示）。
- `htmlToAnnotatedString(InputStream, baseUrl)`：`Jsoup.parse(stream, null, baseUrl)`（自动探测编码）；`htmlStringToAnnotatedString(html, baseUrl="")`。
- 遍历 body 子节点，每次 `emitParagraph` 产出一个 AnnotatedString（空 builder 或以 NBSP 结尾时不产出，AnnotatedStringComposer.kt:11-22）；emit 后用 spanStack 重新 push 仍开着的样式（跨段续接）。
- 标签映射（:84-393）：p（`readability-styled` 类的 p 不分段）、br→'\n'、h1-h6 分段（**无**标题样式，仅规范化空白）、strong/b 粗体、i/em/cite/dfn 斜体、tt 等宽、u **无样式**、sup/sub 基线偏移、font 透传、pre 分段+等宽+保留原始空白、code 分段+等宽（继承 preFormatted）、blockquote 分段、a → string annotation tag `"URL"` 值 `abs:href`（空则原 href，mailto）、figure/img 仅分段（不朗读 alt）、ul → 每个 li 一段前缀 `"• "`、ol → `"${i+1}. "`、table → caption 一段、thead→tbody→tfoot 每行 tr 一段，末尾追加 "\n\n"、rt/rp/iframe/video 忽略、其他递归。
- 注意：代码注释说列表前缀用“no break space”，实际字节为普通空格 0x20（已 xxd 核实 :293,:309），所以 `endsWithNonBreakingSpace` 抑制分段逻辑对列表前缀不生效（空 li 也会产出仅含前缀的段）。
- 链接 "URL" 是 StringAnnotation 不是 LinkAnnotation：AI 摘要中的链接**不可点击、无链接样式**。
- `a` 的 withAnnotation 在 `appendTextChildren` 之外未加样式。
- 空白规范化 `appendCorrectlyNormalizedWhiteSpace`（TXT/HtmlToComposable.kt:63-92）：按 codePoint 遍历 wholeText（不用 Jsoup text() 以保留 ZWNJ 等不可见字符）；builder 空且 stripLeading 时丢弃前导可折叠空白；可折叠空白（`isCollapsableWhiteSpaceCode`，在 MH 包）折叠为单个空格（已以空白/NBSP 结尾则不加）。
- 测试：`input/Feeder/app/src/test/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToAnnotatedStringTest.kt`（3 例：Markdown 流程、简单 HTML、ul 列表，仅断言文本包含）。

### 5.3 AnnotatedParagraphStringBuilder（TXT/AnnotatedString.kt）
- 维护 `lastTwoChars`（最新在前），`endsWithWhitespace`：空→true；末字符为空白或 NBSP(160)→true。`isEmpty()` = lastTwoChars 为空（**不是** builder.length==0）。
- `pushComposableStyle/popComposableStyle` + `rememberComposableAnnotatedString`（可组合样式延迟应用）——当前 Composer 只在 resetAfterEmit 中重放；未见其他产出调用（`SpanWithComposableStyle`、`SpanWithVerbatim` 无生产者，grep 仅定义/重放处）。

### 5.4 其他工具（TXT/HtmlToComposable.kt）
- `Element.attrInHierarchy(attr)`：沿祖先查找首个非空属性；HtmlLinearizer 用来判 `dir="rtl"` 表格方向（MH/HtmlLinearizer.kt:575）。
- `stripHtml(html)`：去掉 `<...>` 之间字符的极简剥离，用于 img alt 文本（MH/HtmlLinearizer.kt:504）。不处理实体。
- `isCollapsableWhiteSpace(String)`（internal）：SPACE/TAB/LF/CR/FF/NBSP。
- `Element.ancestors(predicate)`：本区未见调用。

### 5.5 annotatedStringResource（TXT/Extensions.kt:24-57）
读 `Resources.getText(id)`，`Spanned` 中 `android.text.Annotation` key=`style` value=`link` → `LinkTextStyle`。用于空态页 `empty_feed_open` = `<annotation style="link">Open</annotation> another feed?`、`empty_feed_add` = `<annotation style="link">Add</annotation> more feeds?`（strings.xml:19-20；NothingToRead.kt:70,90）。整行 Box 点击，非仅链接词。

## 6. 链接点击路由（调用方 ArticleScreen，不在本区但契约相关）
ArticleScreen.kt:719-745：
- `index != null && elementPositions.containsKey(index)` → 动画滚动 `articleScrollState.animateScrollTo(y)`（页内锚点）。
- 否则若启用应用内音频播放器且 `shouldOpenInPodcastPlayer(link, enclosure)`（PodcastPlayerLinks.kt:21：等于 enclosure 链接且 audio/*，或末段扩展名为音频）→ 打开应用内播放器。
- 否则 `activityLauncher.openLink(link, toolbarColor)`（ActivityLauncher.kt:55-71：空白或 `#` 开头 → 不做任何事；`mailto:` → 邮件客户端；否则按设置 CUSTOM_TAB / DEFAULT_BROWSER；无可处理应用 → Toast `no_activity_for_link`）。
- 已知问题（事实，留给设计决定是否修复）：`onElementPosition` 以 `offsetCounter + index` 为 key 存（:744），而查询用原始 `idToIndex` 的 index（:723）；当显示翻译进度或 AI 摘要（offsetCounter>0）时锚点跳转会错位/失效。且存的是 `positionInRoot().y`（随滚动变化的屏幕坐标），非内容内偏移，滚动后再点锚点位置可能不准。

## 7. Compose 布局结构摘要
```
ReaderView: SelectionContainer > Column(verticalScroll)
  ColumnArticleContent
    for element: ProvideTextStyle(bodyLarge,onBackground)
      BoxWithConstraints(fillMaxWidth, center, onGloballyPositioned)
        LinearElementContent(widthIn max=min(maxWidth, maxReaderWidth 600/640dp))
          Text | CodeBlock(Surface,hscroll) | ListItem(Row[marker, Column]) |
          BlockQuote(Surface[Column[texts, cite End]]) |
          Image(Column[DisableSelection Box(clickable)[Tooltip? AsyncImage], caption]) |
          Video(Column[thumb?, "Touch to play video"]) | Audio("Touch to play audio") |
          Table(Box[Layout hscroll][cells: Column(bg, divider)])
```
文案 key：`touch_to_play_video`、`touch_to_play_audio`、`article_image`（ReaderView 头图 tooltip，非本区）、`empty_feed_open`、`empty_feed_add`。

## 8. 平台风险（HarmonyOS 映射）
1. **AnnotatedString → ArkUI Span/StyledString**：需要 Text+Span（或 StyledString/MutableStyledString）支持：粗/斜/下划线/删除线/字体族/背景色（内联代码）/上下标（BaselineShift——ArkUI Span 无直接 baselineShift，需 `baselineOffset`+缩小字号 或 StyledString 的 BaselineOffsetStyle）/可点击区间（Span onClick 或 StyledString GestureStyle）。
2. **文本选择**：Android 用 SelectionContainer 跨段落选择，图片/视频区 DisableSelection。ArkUI Text `copyOption` 仅单个 Text 内选择，跨块选择无等价 → 降级。
3. **Bidi**：`java.text.Bidi` 无直接等价；需自写首个强方向字符判定（Unicode BidiClass L/R/AL）或用 `@ohos.i18n`（若有）——需按段落切 `direction(Direction.Rtl)`。
4. **图片**：Coil 的尺寸请求/INEXACT/自定义 ContentScale(Restrained*)、placeholder/error 图标。ArkUI Image 有 `alt`（占位）但无 error 占位，需 onError 切换；“不放大超过 density 倍”需自算尺寸。srcset 最佳源选择算法纯逻辑可直接移植。
5. **表格**：自定义两遍测量 Layout（列宽取最大、跨格平分）→ ArkUI 需 `onMeasureSize/onPlaceChildren` 自定义布局或 Grid（Grid 不支持按内容自适应列宽）；嵌套横向滚动（表格横滚 ⊂ 垂直滚动）。
6. **代码块不换行 + 横滚**：Text `maxLines`/`wordBreak` + Scroll(Horizontal)。
7. **Tooltip**（长按图片显示 caption）：ArkUI 用 `bindPopup`/`bindContextMenu` 替代。
8. **锚点滚动**：依赖每块 y 坐标；ArkUI 可用 `Scroller.scrollTo` + `onAreaChange` 获取块位置；建议修复原 offset 错位（或照原样保留行为，需设计定夺）。
9. **字体缩放**：fontScale × 用户 TypographySettings（mono/serif/sans 字体族）——ArkUI 需自定义字体注册（font.registerFont）。
10. **focusableInNonTouchMode**：键盘/遥控导航场景，低优先。
11. **TTS 用 HTML→纯文本段落**：Jsoup 依赖；鸿蒙需替代 HTML 解析器（与解析区共用决策）。

## 9. 降级候选
- 跨段落文本选择（SelectionContainer）→ 单段落 Text copyOption 选择。
- 图片 caption 长按 tooltip → popup 或直接省略（caption 已在图下方可见）。
- 非触控模式聚焦指示（focusableInNonTouchMode）。
- `linearArticleContent`（LazyList 版本）无调用者，可不迁移。
- `rememberComposableAnnotatedString` / `SpanWithComposableStyle` / `SpanWithVerbatim`（TTS 注解）无生产者，可不迁移。

## 10. 未决/需他区确认
- `isCollapsableWhiteSpaceCode` 在 model/html（解析区）。
- HtmlLinearizer 如何产出 PRE_FORMATTED vs CODE_BLOCK、注解范围（解析区）。
- `TypographySettings`、`Dimensions.imageAspectRatioInReader` 的取值来源（主题/设置区）。
