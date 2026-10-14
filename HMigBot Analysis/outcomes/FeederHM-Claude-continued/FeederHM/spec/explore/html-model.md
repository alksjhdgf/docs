# 探索文档：html-model（HTML 模型域）

断言卡：`/Users/ppp/Projects/migrate-core/output/FeederHM/spec/cards/html-model.md`（HM-A01 ~ HM-A56，全部 backend，0 ui / 0 on_device）。
本区无页面；产物被 Article 页（阅读器渲染）、同步（全文预取）、Feed 列表（摘要/字数）消费。

## 1. 文件清单

| 文件 | 行数 | 作用 |
|---|---|---|
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/HtmlLinearizer.kt | 1148 | Jsoup DOM → `LinearArticle`（扁平块列表） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt | 454 | 数据模型：LinearArticle / LinearElement 各子类 / Table Builder |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearTextBuilder.kt | 178 | 带注解栈的文本构建器（push/pop、clearKeepingSpans） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearTextAnnotation.kt | 54 | 注解类型（闭区间 start..end） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FullTextParser.kt | 344 | 全文抓取 + readability4j 抽取 + 字符集探测 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/HtmlToPlainTextConverter.kt | 375 | TagSoup SAX → 纯文本（标题/摘要/字数） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/MarkdownToHtmlConverter.kt | 61 | JetBrains markdown（CommonMark）→ HTML，仅 AI 摘要 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/text/VideoTagHunter.kt | 33 | YouTube embed 识别（HtmlLinearizer 依赖） |
| 依赖（他区文件）ui/compose/text/HtmlToComposable.kt:19/33/128 | — | `attrInHierarchy`、`ancestors`、`stripHtml`（Linearizer 依赖） |

依赖库版本（gradle/libs.versions.toml）：jsoup 1.23.2、tagsoup 1.2.1、readability4j 1.0.8、jetbrains-markdown 0.7.14、icu4j 78.3。
lib-adjudications 已裁定：jsoup→自研 HTML 解析器；tagsoup→复用自研解析器；readability4j→自研移植；icu4j→`util.TextDecoder`（无统计探测）；markdown→自研 CommonMark 子集。
**注意**：lib-adjudications 中 markdown 条目 note 写"feed 内容 text/markdown"、evidence 为 `model/MarkdownToHtmlConverter.kt` —— 与源码不符：真实路径 `ui/text/MarkdownToHtmlConverter.kt`，唯一调用点是 AI 摘要（ArticleViewModel.kt:741），feed 内容不走 Markdown。

## 2. 数据模型（LinearStuff.kt / LinearTextAnnotation.kt）

```
LinearArticle(elements: List<LinearElement>)
  idToIndex: Map<String,Int>   // 每个 id → 顶层元素下标（LinearStuff.kt:10）
  imageUrls: Set<String> (lazy) // 递归收集全部图片候选 URL（:25）；containsImageUrl(url)
sealed LinearElement:
  LinearText(ids, text, annotations: List<LinearTextAnnotation>, blockStyle: TEXT|PRE_FORMATTED|CODE_BLOCK)  // LinearPrimitive
  LinearImage(ids, sources: List<LinearImageSource>, caption: LinearText?, link: String?)
    LinearImageSource(imgUri, widthPx?, heightPx?, pixelDensity: Float?, screenWidth?)  // init 校验 >0
  LinearVideo(ids, sources 非空) ; imageThumbnail = 首个非空缩略图 ; firstSource
    LinearVideoSource(uri, link, imageThumbnail?, widthPx?, heightPx?, mimeType?)
  LinearAudio(ids, sources 非空) ; LinearAudioSource(uri, mimeType?)
  LinearListItem(ids, orderedIndex: Int?, content: List<LinearElement>)
  LinearBlockQuote(ids, cite?, content: List<LinearElement>)   // 实际只放 LinearText
  LinearTable(ids, rowCount, colCount, cells: Map<Coordinate(row,col), LinearTableCellItem>)
    LinearTableCellItem(type HEADER|DATA, colSpan, rowSpan, content) ; filler = (DATA,-1,-1,[]) ; isFiller
LinearList(ordered, items) —— 不是 LinearElement；线性化器不产出它（列表项直接平铺为顶层 LinearListItem）
LinearTextAnnotation(data, start 含, end 含) ; endExclusive = end+1
LinearTextAnnotationData: H1..H6, Bold, Italic, Monospace, Underline, Strikethrough, Superscript, Subscript, Font(face), Code, Link(href)
```
- `LinearTextBlockStyle.shouldSoftWrap` 仅 TEXT 为 true（LinearStuff.kt:362）。
- 表格坐标：Builder 中 `add()` 寻找当前行第一个空位（被上行 rowspan filler 占用的跳过），写 filler；`build()` 若 RTL 则列镜像（LinearStuff.kt:190-251）。colSpan=0 不前进、不产 filler（Firefox "到行尾"语义由渲染侧 `ui/compose/html` 的 `toTableData` 处理，测试 `cowboy table` 断言 `table.cells.size - 3 == toTableData().cells.size`）。
- 鸿蒙实现：ArkTS 判别联合（`type` 字段 + interface）；`ArrayMap<Coordinate,...>` 换成 `Map<string,...>`（key=`${row},${col}`），因为 ArkTS Map 以引用比较对象键。

## 3. HtmlLinearizer 行为（逐标签）

构造：`HtmlLinearizer(tooLargeText, openInBrowserText, articleLink)`，实例有可变状态（elementCount/charCount/truncated/当前 builder），**一次 linearize 一个实例**（调用方每次 new，ArticleViewModel.kt:338、:658）。
入口：`linearize(String|InputStream, baseUrl)` → `Jsoup.parse(stream, null /*自动侦测字符集*/, baseUrl).body()`。异常 → 空列表（:49）。

遍历规则（`linearizeChildren`，:97）：
- TextNode：`charCount += wholeText.length`；TEXT 块用 `appendCorrectlyNormalizedWhiteSpace`（码点级折叠：空格/\t/\n/\r/FF/NBSP→单空格，前一字符是空白则丢弃；不用 text() 以保留 ZWNJ）；非 TEXT 原样 append。
- 其它节点类型（注释、DataNode=script/style 内容）忽略。
- Element：先 `pushId(element.id())`（**在隐藏检查之前**，隐藏元素的 id 也会登记到当前文本块），再 `isHiddenByCSS`（style 含 `display:` 且含 `none`，子串判断，粗糙：`display:block;border:none` 也被隐藏；`display : none` 不被识别）。
- `p`：class `readability-styled` → 不切块 + 补一个空格；否则 `asElement`（前后 finalize 切块），子内容 blockStyle 强制 TEXT。
- `br` → `\n`。
- `h1..h6` → 切块 + 对应注解；文本用递归 `appendCorrectlyNormalizedWhiteSpaceRecursively`（标题内的 a/b 等**不产生**行内注解，链接在标题中丢失）。
- `strong/b`、`i/em/cite/dfn`、`span`(style)、`tt`、`u`、`s`、`sup`、`sub`、`font[face]`、`code` → 行内注解（见卡 HM-A13/14）。`q`、`del`、`strike`、`ins`、`mark`、`small`、`big` 等未处理 → 透明（只取子内容）。`hr` 无输出。
- `pre` → 切块，含 `code` 后代则 CODE_BLOCK 否则 PRE_FORMATTED，整段 Monospace。注意 Jsoup 会吞掉 `<pre>` 后紧跟的第一个换行，但 `<pre><code>\n` 中的换行保留（测试：`"\nCode\n  block"` vs `"Code\n  block"`）。
- `blockquote` → finalize；在子 scope 中线性化，把连续 LinearText 包成 `LinearBlockQuote(ids=allIds, cite)`，非文本元素直接顶层输出并切断引用。ids 在被切成多段时会重复（源码注释承认）。
- `a` → Link 注解（`abs:href` 空则 `href`）。图片/figure 通过 `findClosestLink()` 取栈中最近 Link 作为 `LinearImage.link`。
- `figcaption`：父是 `figure` 才展开，否则丢弃。
- `figure` → finalize；有 iframe → 只解析第一个 iframe 视频；否则候选 = 后代 `img` + class `image` 元素的 `getImageSource` 去重，空则祖先 `[data-src]/[data-responsive]`；caption = 子 scope 线性化后第一个非空 LinearText（图片本身在子 scope 被产出又被丢弃 —— 但 `addLimited` 已计数，元素计数会被多计）。
- `img` → finalize；`getImageSource`；caption = `stripHtml(alt)`（纯文本，ids 取当前 builder ids）；link = 最近链接。
- `ul/ol` → finalize；仅直接子 `li`；`orderedIndex` = 在 li 中的序号+1（**忽略 `start`/`value` 属性**）；空项丢弃。嵌套列表平铺进外层 LinearListItem.content。
- `td/th`（表格被优化掉时）→ 当 div 处理（切块）。
- `table` → finalize；dir 取 `attrInHierarchy("dir")`；行收集顺序 thead(0)→tbody(1)→tr(2)→tfoot(3)，**只看直接子级**（嵌套表格在单元格里递归）；`caption` 元素被忽略（不在行收集中）。colCount==1 或行数==1 → 展开子节点；否则 LinearTable（单元格内容 `asElement` 递归）。colspan/rowspan `toIntOrNull()?.coerceAtLeast(-1) ?: 1`（负数被夹到 -1，可能与 filler 判定冲突——colSpan=-1 且 rowSpan=-1 的真实单元格会被当 filler）。
- `rt/rp` 丢弃；`audio`/`video` 收集 `source[abs:src]` + type；`iframe` → finalize + YouTube 识别（VideoTagHunter.kt:8 正则 `youtube.com/embed/([^?/]*)`，缩略图 http（非 https）`img.youtube.com/vi/<id>/hqdefault.jpg`，默认 480×360）。
- 其它（div/section/article/span…）→ 透明递归。

`getImageSource`（:820）：srcset 以 `", "`（逗号+空格）切分（**无空格的 `a.jpg 1x,b.jpg 2x` 会被当成一项**），每项按空白取前两段；`w`/`x` 描述符；数字解析失败抛出 → 整个函数 catch 后返回已收集部分。之后 `data-img-url|data-src`、`abs:src`（`data:` 原样）、`background-image:url('...')`。width/height 仅在两者都有时写入。`resolve()`（:1093）带 Jsoup 同款 workaround（`?query`、`./` 前缀）；无法解析返回 ""（空串 imgUri 仍会被加入！）。

限额（:770，:1015）：`MAX_ELEMENTS=2000`、`MAX_CHARS=100_000`（注释：grapheneos releases 页面 OOM 的经验值，约 60 分钟阅读）。超限后 `truncated=true`，后续 linearizeChildren 直接 break，末尾追加 tooLarge + openInBrowser 两段（:54）。`estimateWordCount`（db/room/FeedItem.kt:223）同样引用 MAX_CHARS。

`LinearTextBuilder`：`push` 记录 start；`pop` 设 end=text.lastIndex；`toLinearText` trimEnd 并夹注解；`clearKeepingSpans` 清空文本与已完成注解，仍打开的注解 start 重置为 0 —— 这就是跨块延续行内样式的机制（HM-A15）。`endsWithWhitespace` 在空 builder 时视为 true（行首空白被吃掉）。

`idToIndex`：仅登记顶层元素自己的 ids（嵌套在 ListItem/BlockQuote 里的子 LinearText 的 ids 不单独登记，但 allIds 已把后代 id 合并到容器 ids）。消费方：ui/compose/html/LinearArticleContent.kt:508/699/983（`#` 分割取最后一段查表滚动）。

## 4. 调用方（他区）
- ArticleViewModel.parseArticleContent（ui/compose/feedarticle/ArticleViewModel.kt:330）：默认文本读 `articleDir/<id>` blob（gzip），全文读 `<id>.full.html.gz`；**baseUrl 传 `article.feedUrl`，不是文章 link**。全文缺失时调用 `fullTextParser.parseFullArticleIfMissing`，错误映射到 `TextToDisplay`：NoBody→FAILED_MISSING_BODY、NoUrl→FAILED_MISSING_LINK、UnsupportedContentType/NotHTML→FAILED_NOT_HTML、FullTextTooLarge→FAILED_FULLTEXT_TOO_LARGE、其它→FAILED_TO_LOAD_FULLTEXT（:384-396）。
- 翻译结果 HTML 也走 HtmlLinearizer（:658）。
- AI 摘要：MarkdownToHtmlConverter → `htmlToAnnotatedString`（:741）。
- ArticleScreen.kt:658 用 `articleContent.imageUrls`（与头图去重相关）。
- FullTextSyncJob（background/FullTextSyncJob.kt:31）→ `parseFullArticlesForMissing`；DI 单例 di/NetworkModule.kt:27。
- SearchFeedScreen.kt:498-500 把 UnsupportedContentType/FullTextDecodingFailure/FullTextTooLarge 映射到字符串 `unsupported_content_type` / `failed_to_parse_full_article` / `failed_to_fetch_full_article_too_large`。
- HtmlToPlainTextConverter：FeedItem.updateFromParsedEntry（db/room/FeedItem.kt:138，snippet+字数）、GoFeedExtensions.kt:21（标题）/:48（plainContent，空但含 img → `<image>`）、FullTextParser.kt:155（全文字数）。
- CleanupOrphanedFilesJob.kt:51 清理孤儿 `*.full.html.gz`；blob/Blob.kt:27 定义文件名 `"$itemId.full.html.gz"`，GZIP 流读写。

相关字符串（res/values/strings.xml）：`open_in_web_view`=`Open in Web view`(:119)、`failed_to_fetch_full_article_too_large`=`Article is too large. Open in browser instead?`(:250)、`unsupported_content_type`(:268)、`failed_to_parse_full_article`(:269)、`fetching_full_article`(:160)。

## 5. FullTextParser（model/FullTextParser.kt）
- `parseFullArticlesForMissing()`（:35）：`getFeedsItemsWithDefaultFullTextNeedingDownload().firstOrNull()`（FeedItemDao.kt:460：`f.fulltext_by_default=1 AND fi.fulltext_downloaded<>1 AND block_time is null`），**串行**逐条处理，全部 Right 才 true。
- `parseFullArticleIfMissing(item)`（:53）：文件已存在 → Right；否则 parseFullArticle；Throwable → `FullTextDecodingFailure`；**finally 一律 `markAsFullTextDownloaded`**（失败也不会自动重试，除非用户在阅读页手动触发，因为 ArticleViewModel 用文件存在性判断）。
- `parseFullArticle`（:72，Dispatchers.Default）：`curlAndOnResponse`（FeedParser.kt:451，非 2xx → HttpError；异常 → FetchError）→ contentLength>3MiB → TooLarge；8 KiB 分块读到 buffer，超过 3MiB → TooLarge；contentType null 或非 text/html → UnsupportedContentType；charset 链：header → `findMetaCharset` → `detectCharset`（ICU CharsetDetector，confidence>50）→ UTF-8；`toJavaCharset` 映射 GB2312→GBK、BIG5-HKSCS→Big5_HKSCS（`"Shift-JIS"` 分支因与 uppercase 比较永不命中，死代码）；`parseFullArticle(url, html)` → Readability4JExtended → `contentWithUtf8Encoding`，有 dir 则 `replaceFirst("<html", "<html dir=\"$dir\"")`；写 gzip 文件 + `updateWordCountFull`。抽取结果 null 时什么也不写但返回 Right（之后阅读页因无文件显示"Error text should already be set above"分支——实际 retrieveFullText 返回 Right → errorText null → 显示空内容）。
- `findMetaCharset(bytes)`（:199）：手写状态机，逐字节 `b.toInt().toChar()`；仅支持双引号属性值（单引号/无引号属性会把状态打回 TAG_START）；`content` 值须含小写 `charset=`；遇到第一个匹配即返回（不限于 `<head>`）。
- `detectCharset`（:328）：ICU，测试期望 gb2312 样例 → `GB18030`。

单测 FullTextParserKtTest（test/java/com/nononsenseapps/feeder/model/FullTextParserKtTest.kt）6 例：phoronix 全文（Readability 输出含 `he SystemV file-system was</p>\n  <a`）、meta content gb2312、meta charset gbk、content 带分号、ICU 猜 GB18030、土耳其畸形页 windows-1254。资源：test/resources/com/nononsenseapps/feeder/model/{gb2312.html, muhasebetre_article.html, phoronix.html, muhasebetr.html}。

## 6. HtmlToPlainTextConverter（TagSoup SAX）
- 输出规则见卡 HM-A48~A53。注意：`startLi` 缩进 = `"  " * (listings.size-1)`；`Listing.number` 从 1；strong/em/a 处理函数为空（只保留文字）；`ensureSpace` 跳过已有空白或 NBSP；`characters()` 只折叠 ' ' 与 '\n'（不含 \t、\r、NBSP）；`script/style` 通过 ignoreCount 屏蔽；img 仅记录 lastImageAlt，`endDocument` 若全文为空才输出 `[alt]`（alt 空 → `IMG`，"See test mentioning XKCD"）。实例非线程安全（共享 builder），各调用点每次 new。
- 单测 HtmlToPlainTextConverterTest（test/java/com/nononsenseapps/text/HtmlToPlainTextConverterTest.kt）13 例：repeated、empty、unorderedList、orderedList、nestedList、link、noNewLines、noScripts、noStyles、imgSkipped、noBold、noItalic、noLeadingImages（`<img alt='heh'> foo` → `foo`）。

## 7. MarkdownToHtmlConverter
- CommonMarkFlavourDescriptor + HtmlGenerator；空白 → ""；异常 → HTML 转义原文；`convertToPlainText` = 去标签正则（异常时正则去 `**`/`*`/反引号）。注意 `convertToPlainText` 不解 HTML 实体（`&amp;` 会残留）。
- 单测 MarkdownToHtmlConverterTest 6 例：basic(strong/em)、list(ul/li)、heading(h1/h2)、plain text（无 `*`）、empty、complex(h1/strong/ul/blockquote/h2/code)。

## 8. HtmlLinearizerTest 用例清点（test/java/com/nononsenseapps/feeder/model/html/HtmlLinearizerTest.kt，56 个 @Test（另有 1 个被注释掉的 `audio in iframe`））
基础：empty→[]；simple text；spaces inside headers kept（H2 0..9）；bold/italic/underline 同范围 0..12；交错（B0..9/I0..4/U0..3）；header 独立块（H1 0..7 + 文本）；nested divs 单块。
列表：ol（orderedIndex 1,2，2 个顶层项）；ul（null）；surrounding span + list（4 块均 Bold）。
图片：alt→caption；bold alt→纯文本 `Bold text`；img in link（link=href）；defined size 100×200；srcset（1x、2x、700w、fallback 四源顺序）；data-img-url；相对 URL；inline data:；figure+figcaption（Bold 4..4）；figure inside link（caption 带 Link 0..7，link 设置）；figure 两 img 去重（2 源）/全不同（3 源）；image negative height→null。
引用：p in blockquote（cite null，单 LinearText）；content inside blockquote（tumblr，3 块，[1] 为图片）。
pre：with code（`"\nCode\n  block"`, CODE_BLOCK, Mono+Code 0..12）；pre（`"Code\n  block"`, PRE_FORMATTED, Mono 0..11）；without code（PRE_FORMATTED）。
音视频：audio 无源忽略；audio 两源（相对 `audio.mp3` → `https://example.com/audio.mp3`）；video 无源忽略；video 两源；video 负宽→null；iframe youtube（480×360 默认）；figure 内 iframe youtube（1170×658，src 保留 `?feature=oembed`）。
表格：2x2；2x2 rtl（html dir=rtl，列镜像）；colspan/rowspan/双跨（4 列 3 行）；colspan=0（3 列 2 行）；cowboy table（filler 数 = 3）；thead/tbody/tfoot（无闭合标签）；single column optimized out（2 个 LinearText）；insane nested table（kill-the-newsletter，4 个 LinearText）；cowboyprogrammer exhaustive（1 个表 8 行）。
真实页面：arstechnica ×2（6 个 LinearListItem，每项 1 个 jpeg LinearImage，取自 li 的 data-src/data-responsive）；feeder news changelog（20 块）；cowboyprogrammer transmission（12 块）。
ids：div1+div2 合并；img id；ul 项 ids（item1/item2，ul 自身 id 不入项）；blockquote {quote1, para1}；audio id；table {table1, cell1..4}；video id。
空格：readability-styled p + 链接 → `...was orphaned back in 2023` 单块。

LinearStuffKtTest（2 例）：imageUrls 包含嵌套（blockquote/listitem/table）图片及全部候选源；containsImageUrl 对嵌套 URL 为真、未知为假。

## 9. 平台模型差异
- 全文批量抓取：结果契约：订阅源开启"默认全文"的未抓取条目在同步后获得全文文件且标记已抓取；Android：FullTextSyncJob（WorkManager 链）在 Dispatchers.Default/IO 协程串行执行；鸿蒙实现：同步任务中 `taskpool` 或 async 串行执行，文件写 `context.filesDir/fullArticles/<id>.full.html.gz`（`@ohos.zlib` gzip）；差异：后台时机由同步区决定。
- 线性化在 IO 线程执行；鸿蒙应放 TaskPool（纯函数，需可序列化输出 —— LinearArticle 结构须为 Sendable/纯数据，lazy 属性需改为显式计算）。
- 网络：OkHttp `curlAndOnResponse` → `@ohos.net.http` / rcp；需能拿到原始字节与 Content-Type（含 charset 参数）、Content-Length，并支持流式读取 3 MiB 上限（`requestInStream` 或 rcp 流）。

## 10. 降级候选
- ICU CharsetDetector 统计探测（HM-A42 第三步）：lib-adjudications 已裁定无等价 → 降级为 header/meta 声明 + UTF-8 兜底（可加 BOM 嗅探、UTF-8 有效性校验后回退 GBK 等启发式）。`guesses gb from html` 用例（期望 `GB18030`）无法原样复现。
- readability4j：须自研移植（Mozilla Readability 算法），输出 HTML 与 Android 不会逐字节一致；phoronix 用例的空白格式断言（`</p>\n  <a`）只能弱化为"段落与链接之间存在空白"。
- Jsoup 的宽容 HTML5 解析（隐式 tbody、未闭合 td/th/p、`<pre>` 首换行吞掉、`abs:` 属性解析）须在自研解析器中复刻，否则表格/pre 用例失败。
- TagSoup 对 `<br>` 自动配对 `</br>` 的行为：自研时直接把 br 视作空元素即可（结果一致）。
- Markdown：自研 CommonMark 子集，至少覆盖 HM-A54 列出的语法。

## 11. Top 风险
1. 自研 HTML 解析器是整个阅读器的地基；HtmlLinearizerTest 56 例几乎全依赖 Jsoup 的树修正行为（未闭合标签、tbody 插入、figure/p 嵌套修正、`abs:` 解析、`html dir` 属性）。
2. 字符集：无 ICU 探测 → 未声明编码的非 UTF-8 页面（中文 GB 系、土耳其 1254）乱码；`util.TextDecoder` 支持的编码名需与 meta 中的别名（gb2312/gbk/windows-1254/shift_jis/big5-hkscs）做映射表。
3. Readability 移植的抽取质量与 `readability-styled` 类名约定：Linearizer 依赖 readability4j 插入的 `<p class="readability-styled">` 做空格处理，自研抽取器若不产生该类则需同步调整 HM-A10。
4. 限额与内存：MAX_ELEMENTS/MAX_CHARS 是为 Compose 内存设定的；ArkUI LazyColumn/List 渲染成本不同，但仍应保留同数值以维持截断契约与字数估算一致。
5. 源码怪癖需决定"保真还是修正"：`isHiddenByCSS` 子串误判、srcset 只按 `", "` 切分、`ol start` 被忽略、标题内链接丢失、`resolve` 失败得到空 imgUri、`toJavaCharset` Shift-JIS 死分支、全文失败也标记已下载（不重试）、baseUrl 用 feedUrl 而非文章 link。建议保真（卡片按现行为写）。
6. lib-adjudications 的 markdown 条目用途/路径描述错误（见 §1），设计阶段需更正。
