# HTML 模型域卡（html-model）

## 域: HtmlLinearizer 线性化（入口与限额）
- HM-A01 [backend] `HtmlLinearizer.linearize(html, baseUrl)` 只遍历 `<body>` 子树，输出扁平 `LinearArticle.elements`（顶层元素序列，不再嵌套 `ul/ol` 容器）；`<html><body></body></html>` 输出空列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:37
- HM-A02 [backend] 解析过程抛任何异常时不向上抛出，返回空元素列表（文章区显示为空而非崩溃）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:49
- HM-A03 [backend] 元素数超过 `MAX_ELEMENTS`=2000 或累计文本字符数超过 `MAX_CHARS`=100000 后停止添加任何元素（截断），之后的内容全部丢弃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:770
- HM-A04 [backend] 发生截断时在末尾追加两段 TEXT：`tooLargeText`（调用方传 `Article is too large. Open in browser instead?`）与 `openInBrowserText`（调用方传 `Open in Web view`），后者整段带指向 `articleLink` 的链接注解。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:54
- HM-A05 [backend] 纯文本 `<body>Hello, world!</body>` 输出单个 `LinearText(text="Hello, world!", blockStyle=TEXT, 无注解)`；多层 `div` 嵌套不拆分为多个块。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:709
- HM-A06 [backend] `style` 属性同时包含子串 `display:` 与 `none` 的元素及其子树整体跳过不输出。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:815

## 域: HtmlLinearizer 文本与空白
- HM-A07 [backend] TEXT 块中连续可折叠空白（空格/制表/LF/CR/FF/NBSP 160）折叠为单个普通空格；ZWNJ 等不可见字符必须保留（不得用会剥离它们的 text() 实现）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:1026
- HM-A08 [backend] 每个文本块生成时去掉尾部空白（trimEnd），注解起止下标随之截断到新长度内，起止非法的注解被丢弃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearTextBuilder.kt:117
- HM-A09 [backend] `<br>` 在当前文本中插入 `\n`，不切分块。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:153
- HM-A10 [backend] 普通 `<p>` 前后切块成独立 LinearText；带 class `readability-styled` 的 `<p>` 不切块，仅在其后补一个空格（保证 `...was</p><a>orphaned` 输出 `was orphaned`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:131
- HM-A11 [backend] `h1`~`h6` 各自成独立块，整段带 `H1`~`H6` 注解；标题内文本递归收集且保留子元素间空格（`<h2><a>Link</a> <small>small</small></h2>` → `Link small`，H2 注解 0..9）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:155
- HM-A12 [backend] 注解起止下标为闭区间（end 含），`endExclusive=end+1`；嵌套/交错的行内标签各自产生独立注解（`<b><i><u>Hell</u>o</i>, wor</b>ld!` → Bold 0..9、Italic 0..4、Underline 0..3）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearTextAnnotation.kt:3
- HM-A13 [backend] 行内标签映射：`strong/b`→Bold，`i/em/cite/dfn`→Italic，`u`→Underline，`s`→Strikethrough，`sup`→Superscript，`sub`→Subscript，`tt`→Monospace，`code`→Code，`font[face]`→Font(face)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:215
- HM-A14 [backend] `span` 仅在 style `font-weight: bold` 时加 Bold、`font-style` 为 `italic`/`oblique` 时加 Italic，其他 span 透明。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:235
- HM-A15 [backend] 跨块的行内注解在切块后延续：`<b>Before it<ul><li>Item 1</li>...</ul>After</b>` 输出 4 块，每块均带从 0 起的 Bold 注解。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearTextBuilder.kt:148
- HM-A16 [backend] `<a>` 产生 Link 注解，href 取绝对化 `abs:href`，为空（如 `mailto:`）时退回原始 `href`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:428
- HM-A17 [backend] `<pre>` 成独立块并整段加 Monospace；内含 `<code>` 时 blockStyle=CODE_BLOCK（另加 Code 注解），否则 PRE_FORMATTED；非 TEXT 块原样保留空白与换行不折叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:341
- HM-A18 [backend] 仅 TEXT 块允许软换行（`shouldSoftWrap`），PRE_FORMATTED/CODE_BLOCK 不软换行。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:362
- HM-A19 [backend] `rt`/`rp`（ruby 注音）内容被丢弃；`figcaption` 不在 `figure` 直接子级时被丢弃。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:654

## 域: HtmlLinearizer 列表/引用/表格
- HM-A20 [backend] `ol/ul` 的每个直接子 `li` 输出一个顶层 `LinearListItem`；`ol` 项 `orderedIndex` 从 1 递增，`ul` 项为 null；内容为空的项不输出。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:527
- HM-A21 [backend] `blockquote` 内连续的 LinearText 合并为一个 `LinearBlockQuote(cite=属性cite或null)`；内部非文本元素（图片/视频等）打断引用并作为独立顶层元素输出（tumblr 用例 → 文本、图片、引用 3 块）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:376
- HM-A22 [backend] 表格行按 `thead`→`tbody`→裸`tr`→`tfoot` 顺序收集；单列或单行表格不生成 LinearTable，单元格内容按普通块展开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:578
- HM-A23 [backend] 单元格 `th`→HEADER、`td`→DATA；`colspan/rowspan` 缺省为 1；被跨越的位置填 filler（colSpan=rowSpan=-1）；`colCount` 为各行最大累计列数（colspan/rowspan 用例 → 4 列 3 行）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:190
- HM-A24 [backend] `colspan="0"` 原样记为 colSpan=0 且不占列、不产生 filler（3 列表 + 一行 colspan=0 → colCount=3、rowCount=2）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:629
- HM-A25 [backend] 祖先链 `dir` 属性为 `rtl` 的表格，列坐标镜像（col = colCount-1-col）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:575

## 域: HtmlLinearizer 图片/音视频
- HM-A26 [backend] `img` 切块并输出 `LinearImage`；候选源顺序：`srcset`（或 `data-responsive`）各项 → `data-img-url`（或 `data-src`）→ `abs:src` → style `background-image`；无任何候选时不输出。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:820
- HM-A27 [backend] srcset 项描述符 `Nx`→pixelDensity=N，`Nw`→screenWidth=N，无描述符→全空；相对 URL 以 baseUrl 解析为绝对（`/image.jpg`+`https://example.com` → `https://example.com/image.jpg`）；`data:` 内联图原样保留。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:852
- HM-A28 [backend] `img` 同时有 width、height 属性时写入 widthPx/heightPx；≤0 的尺寸置 null（不得因负值抛错）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:947
- HM-A29 [backend] `img` 的 caption 取 `alt` 去标签后的纯文本（`<b>Bold</b> text` → `Bold text`，无注解），alt 为空则 caption=null；`link` 取包裹它的最近 `<a>` 的 href。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:496
- HM-A30 [backend] `figure` 汇总后代 `img` 与 class=`image` 元素的全部候选源并按 URL 去重，生成单个 LinearImage；无后代候选时退回祖先上 `data-src`/`data-responsive`（arstechnica）；caption 取 figure 内第一个非空 LinearText（保留注解，如 figcaption 内 Bold 4..4）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:450
- HM-A31 [backend] `figure` 内含 `iframe` 时只解析第一个 iframe 为视频，不再产出图片。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:454
- HM-A32 [backend] `iframe` 的 src 匹配 `youtube.com/embed/<id>` 时输出 LinearVideo：uri=原 src，link=`https://www.youtube.com/watch?v=<id>`，缩略图=`http://img.youtube.com/vi/<id>/hqdefault.jpg`，尺寸取 iframe width/height 否则 480×360；非 YouTube iframe 不输出。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/VideoTagHunter.kt:10
- HM-A33 [backend] `video`/`audio` 收集子 `source` 的绝对化 src 与 `type`（mimeType）；无有效 source 时整体忽略；video 的 width/height ≤0 置 null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:658

## 域: LinearArticle 模型与页内锚点
- HM-A34 [backend] 每个块收集自身及（≤100 个）后代元素的非空 `id`；`LinearArticle.idToIndex` 把每个 id 映射到其所在顶层元素下标，供 `#fragment` 页内链接跳转。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:10
- HM-A35 [backend] 文本块 ids 累积包裹它的所有容器 id（`div#div1>div#div2>p` → `{div1,div2}`）；表格 ids 含表格及所有单元格 id；blockquote 含自身与内部 p 的 id。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt:1141
- HM-A36 [backend] `LinearArticle.imageUrls` 递归收集图片、引用、列表项、表格（跳过 filler）中所有图片的全部候选源 URL；`containsImageUrl(url)` 据此判断。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:25
- HM-A37 [backend] `LinearImageSource` 宽/高/屏宽 <1 或像素密度 ≤0、`LinearVideo`/`LinearAudio` 无 source 视为非法构造（实现须在线性化阶段先过滤，保证不触发）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:382

## 域: FullTextParser 全文抽取
- HM-A38 [backend] 单篇全文：若 `<itemId>.full.html.gz` 已存在直接成功；否则抓取 `link`；无论成败最终都把该条目标记 `fulltext_downloaded=1`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:53
- HM-A39 [backend] link 为空返回 `NoUrl`；HTTP 非 2xx 返回 `HttpError(code)`；网络异常返回 `FetchError`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt:451
- HM-A40 [backend] 响应 Content-Length 或实际读取字节超过 3 MiB（`MAX_FULL_TEXT_BYTES`=3*1024*1024）返回 `FullTextTooLarge`，不写文件。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:88
- HM-A41 [backend] Content-Type 缺失或不是 `text/html` 时返回 `UnsupportedContentType(mimeType)`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:112
- HM-A42 [backend] 字符集决定顺序：Content-Type charset → HTML `<meta charset=…>`/`<meta content="…charset=X;…">` → 统计探测（置信度>50）→ UTF-8 兜底。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:126
- HM-A43 [backend] meta 字符集扫描：`<meta charset="gbk">`→`gbk`；`content="charset=gbk; text/html"`→`gbk`（截到 `;`）；gb2312 样例页→`gb2312`；畸形土耳其样例→`windows-1254`；名 `GB2312` 解码时按 GBK 处理。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:199
- HM-A44 [backend] 正文用 Readability 算法抽取；文章有方向 `dir` 时把 `dir="<dir>"` 注入首个 `<html` 标签；抽取结果为 null 时不写文件但仍返回成功。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:178
- HM-A45 [backend] 抽取成功后把 HTML 以 gzip 写入 `fullArticleDir/<itemId>.full.html.gz`，并用纯文本转换结果估算字数写入 `wordCountFull`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt:145
- HM-A46 [backend] 批量：对订阅源 `fulltext_by_default=1`、条目 `fulltext_downloaded<>1` 且未屏蔽（`block_time is null`）的条目逐个抓全文；全部成功才返回 true。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItemDao.kt:460
- HM-A47 [backend] 字数估算只看前 100000 字符，按空白切词；平均词长 ≥15（如中日文无空格）时字数记 0。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/db/room/FeedItem.kt:223

## 域: HtmlToPlainTextConverter 纯文本
- HM-A48 [backend] 空串→空串；结果把 NBSP 替换为空格并去首尾空白。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/HtmlToPlainTextConverter.kt:45
- HM-A49 [backend] 块级与换行标签（`p/div/br/blockquote/h1-6`）只产生单个空格，不产生换行：`<p>one<br>two<p>three` → `one two three`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/HtmlToPlainTextConverter.kt:206
- HM-A50 [backend] 列表：`ul` 项前缀 `* `、`ol` 项前缀 `N. `（从 1 起），每项后换行，嵌套每层缩进两空格（`1. sublist:\n  * A\n  * B\n2. two`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/HtmlToPlainTextConverter.kt:152
- HM-A51 [backend] `script`/`style` 内容丢弃；粗斜体与链接只保留文字（`go to <a>Google</a> and see.` → `go to Google and see.`）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/HtmlToPlainTextConverter.kt:252
- HM-A52 [backend] 图片不输出文字（`foo <img alt="meh"> bar` → `foo bar`）；仅当全文无任何文字时输出 `[<最后一张图的alt，空则 IMG>]`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/HtmlToPlainTextConverter.kt:70
- HM-A53 [backend] 该转换用于条目标题、摘要片段（snippet）与字数估算；RSS 条目内容转纯文本为空但含 `img` 时摘要为 `<image>`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/gofeed/GoFeedExtensions.kt:48

## 域: MarkdownToHtmlConverter
- HM-A54 [backend] 空白输入返回空串；CommonMark 渲染至少覆盖 `**`→`<strong>`、`*`→`<em>`、`-`列表→`<ul><li>`、`#`/`##`→`<h1>`/`<h2>`、`>`→`<blockquote>`、反引号→`<code>`。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/MarkdownToHtmlConverter.kt:18
- HM-A55 [backend] 渲染失败时返回 HTML 转义后的原文（`& < > " '`）；`convertToPlainText` 输出不含 `*`/`**` 标记。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/MarkdownToHtmlConverter.kt:27
- HM-A56 [backend] 该转换只用于 AI 摘要成功结果（Markdown→HTML→富文本）；摘要错误信息直接作为纯文本显示，不经 Markdown。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:741
