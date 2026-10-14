# 探索文档：feed-parser（Feed 解析域 / OPML / 收藏导出）

> 区：feed-parser｜断言前缀：FP｜卡片：`output/FeederHM/spec/cards/feed-parser.md`
> 源根 `$SRC = input/Feeder`。所有锚点为工作区相对路径。
> 本区为**无页面域**：解析器、OPML 读写、收藏文章 JSON 导入导出。入口 UI（Feed 页溢出菜单的 Import/Export）属 Feed 页区，本区只记结果契约。

---

## 0. 文件清单（事实）

| 文件 | 行数 | 角色 |
|---|---|---|
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/gofeed/GoFeed.kt | 261 | Go gofeed 结构的 Kotlin 镜像（Moshi 反序列化目标），注释中逐字保留 Go struct 与 json tag |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/gofeed/GoFeedAdapter.kt | 33 | 调 native `gofeedandroid.Gofeedandroid.parseBodyString/parseBodyBytes` → JSON → Moshi → `GoFeed` |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/gofeed/GoFeedExtensions.kt | 379 | `FeederGoItem`：条目字段派生（标题纯文本化、content 选择、link/guid 回退、缩略图挑选） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/FeedParser.kt | 585 | （跨区引用）`parseFeedResponse` 内容类型闸门、`GoFeed.asFeed()` / `asParsedArticle()` 映射、错误类型族 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/Parsed{Feed,Article,Author,Enclosure}.kt | 15/18/7/9 | 解析产物（JSON Feed 风格字段名） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/ThumbnailImage.kt | 115 | 缩略图 sealed class（`ImageFromHTML`/`EnclosureImage`/`MediaImage`，kotlinx 序列化，判别名=类名） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OpmlPullParser.kt | 439 | OPML 拉式解析 + 失败回退正则重写 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OpmlWriter.kt | 335 | OPML 写出 DSL、escape/unescape/escapeAttribute、`OPML_FEEDER_NAMESPACE` |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OPMLImporter.kt | 179 | `OPMLParserHandler` 实现：feed upsert、设置键映射、屏蔽词合并 |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/opml/OpmlActions.kt | 107 | `exportOpml(di, uri)` / `importOpml(di, uri)`（SAF + Toast + 触发同步） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/OPMLParserHandler.kt | 14 | 接口：saveFeed / saveSetting / saveBlocklistPatterns |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/export/SavedArticlesExporter.kt | 137 | 收藏文章 JSON 导出（format `feeder-saved-articles` v1） |
| input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/export/SavedArticlesImporter.kt | 179 | 收藏导入：JSON v1 或旧版"每行一个链接" |
| 测试：androidTest/.../model/FeedParserTest.kt | 1416 | 解析向量（fixtures + 内嵌 XML 常量） |
| 测试：androidTest/.../model/opml/OPMLTest.kt | 956 | OPML 读写/第三方 OPML 向量 |
| 测试：test/.../model/gofeed/GoFeedExtensionsKtTest.kt | 138 | FeederGoItem 单测 |
| 测试：test/.../model/opml/OpmlWriterKtTest.kt / OpmlParserTest.kt | 305 / 199 | 写出逐字期望、设置键全量导入 |

依赖：`gradle/libs.versions.toml:18` `gofeed = "0.2.6"`，`:99` `com.nononsenseapps.gofeed:gofeed-android`（gomobile AAR，Go 原生 `github.com/mmcdole/gofeed`）。**本仓不含 Go 源码**，RSS/Atom/RDF/JSON Feed 语法层由该二进制完成。

---

## 1. 解析流水线（端到端）

```
HTTP Response
 └ FeedParser.parseFeedResponse(url, ResponseBody)          FeedParser.kt:235
     ├ 内容类型闸门：primaryType==null || "text" || subtype∋"json" || subtype∋"xml" → 解析
     │   否则 Left(UnsupportedContentType(mimeType=contentType.toString()))      :241-259
     ├ bytes = body.byteStream().readBytes()      （以字节交给 Go，编码由 XML 声明/BOM 决定）
     ├ GoFeedAdapter.parseBody(bytes)            GoFeedAdapter.kt:28
     │    Gofeedandroid.parseBodyBytes(bytes) → JSON ByteArray → Moshi(KotlinJsonAdapterFactory) → GoFeed
     ├ null → throw NPE("Parsed feed is null") → Left(RSSParseError)             :250
     ├ 任意异常 → Left(RSSParseError(url, throwable))                            :243-246
     └ GoFeed.asFeed(url) → ParsedFeed                                           :285
 parseFeedUrl(url) 成功后再 copy(feed_url = 原始请求 URL)  （保留 userinfo/query token）  :208-216
```
- `parseFeedResponse(response)` 取 `response.request.url` 作为 base URL（重定向后的最终 URL）；body 为 null → `Left(NoBody)`。FeedParser.kt:218-225
- 测试用 `parseFeedResponse(url, body: String)`：`body.toByteArray()`（UTF-8）后同路径。FeedParser.kt:267-278

### 1.1 GoFeed JSON 字段语义（Go struct → Kotlin 字段）

GoFeed（Feed 级），GoFeed.kt:28-52。Go json tag 见注释 GoFeed.kt:3-27：

| Kotlin 字段 | Go json key | 类型 | 语义（gofeed 上游） | Feeder 是否使用 |
|---|---|---|---|---|
| title | title | string | 频道/feed 标题 | ✅ → ParsedFeed.title（**不**做 HTML→纯文本） |
| description | description | string | RSS description / Atom subtitle / JSON description | ✅ → description |
| link | link | string | 站点主页（RSS `<link>`；Atom 第一个 rel=alternate 链接；JSON home_page_url） | ✅ → home_page_url（相对→绝对） |
| feedLink | feedLink | string | 自链接（atom:link rel=self / JSON feed_url） | ❌ 刻意忽略（FeedParser.kt:289-291） |
| links | links | []string | 全部链接 | ❌ |
| updated / updatedParsed | updated / updatedParsed | string / time | 原串 / 解析后时间 | ❌ |
| published / publishedParsed | 同名 | string / time | | ❌ |
| author | author | *Person | 已弃用的首作者（Feed 级） | ✅ → ParsedFeed.author.name；同时作为条目作者回退 |
| authors | authors | []*Person | | ❌ |
| language | language | string | | ❌ |
| image | image | *Image{url,title} | RSS `<image><url>` / Atom logo|icon / JSON icon | ✅ image.url → icon（相对→绝对） |
| copyright / generator | 同名 | string | | ❌ |
| categories | categories | []string | | ❌ |
| dublinCoreExt | **dcExt** | DC 扩展 | | ❌（见风险 R3：key 不一致） |
| iTunesExt | **itunesExt** | iTunes 扩展 | | ❌（同上） |
| extensions | extensions | map[ns]map[name][]Extension | 未知命名空间元素树 | ❌（Feed 级不用） |
| custom | custom | map | | ❌ |
| items | items | []*Item | 条目，文档顺序 | ✅ |
| feedType / feedVersion | 同名 | string | "rss"/"atom"/"json" | ❌ |

GoItem（条目级），GoFeed.kt:75-94，Go 注释 :55-74：

| Kotlin 字段 | Go key | 语义 | Feeder 使用 |
|---|---|---|---|
| title | title | 条目标题（可能含 HTML 实体/标签） | ✅ → HtmlToPlainText → ParsedArticle.title |
| description | description | RSS description / Atom summary / JSON summary | ✅ content 候选 #2 |
| content | content | RSS content:encoded / Atom content / JSON content_html(|content_text) | ✅ content 候选 #1 |
| link | link | 条目链接（Atom 第一个 rel=alternate） | ✅ url |
| links | links | | ❌ |
| updated/updatedParsed | | | ✅ updatedParsed → date_modified |
| published/publishedParsed | | Atom 无 published 时 gofeed 回退 updated | ✅ publishedParsed → date_published |
| author | author | 首作者（RSS `<author>`/dc:creator 等由 gofeed 归并） | ✅ → author（回退 feed author） |
| authors | | | ❌ |
| guid | guid | RSS guid / Atom id / JSON id | ✅ id 与 link 回退 |
| image | image{url,title} | 条目图片 | ✅ 缩略图候选 #1 |
| categories | categories | | ✅ → tags |
| enclosures | enclosures[{url,length,type}] | RSS enclosure / Atom rel=enclosure / JSON attachments | ✅ → attachments；image/* 为缩略图候选 |
| dublinCoreExt / iTunesExt | dcExt / itunesExt | | ❌（仅透传 getter，无消费者） |
| extensions | extensions | `map[nsPrefix]map[localName][]Extension`；Extension={name,value,attrs,children} | ✅ 媒体缩略图 + media:description |

其余结构：GoPerson{name,email}（只用 name）、GoImage{url,title}、GoEnclosure{url,length(string),type}、GoDublinCoreExtension（16 个 []string）、GoITunesFeedExtension/ItemExtension/Category/Owner、GoExtension{name,value,attrs,children}。GoFeed.kt:96-261。

**时间字段格式（结果契约）**：`publishedParsed/updatedParsed` 以字符串透传为 `date_published/date_modified`，下游用 `ZonedDateTime.parse()` 解析（db/room/FeedItem.kt:174-181，失败则保留旧值或 now）。测试向量要求 **RFC3339 UTC，Z 结尾**：`Thu, 14 Mar 2024 14:08:43 -0400` → `"2024-03-14T18:08:43Z"`（FeedParserTest.kt:1027-1040）。鸿蒙自研解析器必须输出 ISO-8601 且可被等价 `ZonedDateTime.parse` 接受。

### 1.2 asFeed 映射（FeedParser.kt:285-334，逐字段）

ParsedFeed：
| 字段 | 取值 |
|---|---|
| title | `GoFeed.title`（原样） |
| home_page_url | `link?.let { relativeLinkIntoAbsolute(url, it) }` |
| feed_url | **恒为请求 URL `url.toString()`**，绝不用 feedLink（注释：大量 feed selfLink 配错） |
| description | `description` |
| user_comment | `""` |
| next_url | `""` |
| icon | `image?.url?.let { relativeLinkIntoAbsolute(url, it) }` |
| favicon | `null` |
| author | `author?.let { ParsedAuthor(name=name, url=null, avatar=null) }` |
| expired | `null` |
| items | `items?.mapNotNull { it?.let { FeederGoItem(it, author, url).asParsedArticle() } }` （null 条目丢弃，顺序保持） |

ParsedArticle（FeedParser.kt:302-318，派生来自 FeederGoItem）：
| 字段 | 取值 |
|---|---|
| id | `guid`（见下） |
| url | `link`（见下） |
| external_url | null |
| title | `HtmlToPlainTextConverter().convert(goItem.title)`；title 为 null 则 null |
| content_html | `content`（可能含 HTML） |
| content_text | `plainContent` |
| summary | `snippet` = `plainContent.take(200)` |
| image | `thumbnail` |
| date_published | `goItem.publishedParsed` |
| date_modified | `goItem.updatedParsed` |
| author | `(goItem.author ?: feedAuthor)?.name` 包成 ParsedAuthor |
| tags | `goItem.categories` |
| attachments | `enclosures(filterNotNull).map { ParsedEnclosure(url, title=null, mime_type=type, size_in_bytes=length?.toLongOrNull(), duration=null) }` |
| hasFeedImage | `thumbnail?.fromBody == false`（即缩略图来自 feed 媒体/enclosure 而非正文） |

### 1.3 FeederGoItem 派生规则（GoFeedExtensions.kt）

- **content**（:28-46）：按序取第一个非空白：`goItem.content` → `goItem.description` → 递归遍历 `extensions` 中任意 `name` 等于 `description`（忽略大小写）的扩展的 `value`（即 media:description，含 media:group 子节点）→ `""`。
- **plainContent**（:48-56）：`HtmlToPlainTextConverter.convert(content)`；若结果空白且 content 含子串 `img` → `"<image>"`（实际上转换器在仅有图片时已产出 `[alt]`，见 1.5）。
- **snippet**（:58）：plainContent 前 200 字符（按 UTF-16 code unit）。
- **link**（:60-71）：`goItem.link`；为 null 时，若 guid 能被 `java.net.URI` 严格解析、为绝对 URI 且 scheme 为 http/https 则用 guid；否则 null。最终 `relativeLinkIntoAbsolute(feedBaseUrl, raw)`。
- **guid**（:82-84）：`(goItem.guid ?: goItem.link)` 经 `relativeLinkIntoAbsolute(feedBaseUrl, …)`（相对 id 会被拼成绝对 URL；非法 URL 原样返回）。
- **author**（:79-80）：`goItem.author ?: feedAuthor`。
- **feedThumbnail**（:101-138）候选序列：
  1. `goItem.image.url` → `MediaImage(url=abs)`
  2. 递归扩展：任意扩展 `attrs["url"]` 若 `pointsToImage` → `MediaImage(url, width=attrs["width"]?.toInt, height=attrs["height"]?.toInt)`；`name=="thumbnail"`(忽略大小写) 的 `value` 若 pointsToImage → MediaImage；递归 children。
  3. enclosures 中 `type` 以 `image/` 开头 → `EnclosureImage(url=abs, length=length.toLongOrDefault(0))`
  取 `maxByOrNull { width ?: -1 }`（宽度最大者；并列取第一个）。
- **pointsToImage**（:327-339）：URL 的 path（不含 query）以 `.jpg/.jpeg/.gif/.png/.webp/.avif`（忽略大小写）结尾；URL 构造失败为 false。
- **bodyThumbnail**（:140-144）：`findFirstImageInHtml(content, baseUrl = linkToHtml(feedBaseUrl, link) ?: feedBaseUrl)`——以**文章链接**为基准解析相对 src。
- **thumbnail**（:146-157）决策：
  - feedThumbnail 是 EnclosureImage 且（length==0 或 >50 000）→ 用它；
  - 否则 feedThumbnail 宽度 ≥640 → 用它；
  - 否则 `bodyThumbnail ?: feedThumbnail`。
- `findFirstImageInHtml`（util/HtmlUtils.kt:16-44）：先 `unescapeEntities(text, true)` 再 Jsoup 解析；取首个 `<img>`，排除 `width=="1"` 或 `height=="1"`，`url=abs:src`，排除空 url 及含 `twitter_icon`/`facebook_icon`（忽略大小写）的；width/height 为属性 toIntOrNull。

### 1.4 URL 辅助（util/LinkUtils.kt:62-121）
- `relativeLinkIntoAbsolute(base, link)`：`URL(link)` 成功则原样（规范化后 toString）；失败则 `URL(base, link)`；再失败返回原串，**不抛异常**。
- 注意：Feeder 以**请求 URL** 为基准，不使用 Atom `xml:base`（lineageos 向量通过请求 URL 解析出正确结果）。

### 1.5 HtmlToPlainTextConverter 要点（跨区，ui/text/HtmlToPlainTextConverter.kt）
TagSoup SAX：忽略 `style`/`script` 内文本；`br/p/div/blockquote/img` 处确保一个空格；`ul/ol/li` 产出 `* ` / `1. ` 列表前缀并换行；连续空白折叠；结束时若整体为空且出现过 `<img>` → 输出 `[alt]`（alt 空白则 `[IMG]`）；最终 NBSP(160)→空格并 trim。（:45-77,131-139,234-300）

---

## 2. gofeed 上游行为（非本仓源码；鸿蒙自研需复刻，均需以向量验证）

以下来自 gofeed 默认 translator 的公开行为，**本仓未包含**，列为实现参考，验收以第 3 节向量为准：
- 自动识别格式：XML 根 `rss`(0.9x/2.0) / `rdf:RDF`(RSS 1.0) / `feed`(Atom 0.3/1.0)；JSON 体 → JSON Feed。识别失败抛错（→ RSSParseError）。
- XML 解码需支持 XML 声明中的非 UTF-8 编码（fixtures 含 `ISO-8859-1`：golem-de、empty_slash_comment、rss_golem_2、rdf_slashdot），并容忍空的 `<slash:comments/>`。
- RSS：item.content=content:encoded；description=description；author 归并 `<author>`(解析 "email (name)") → dc:creator → itunes:author；guid=`<guid>` 文本；enclosures=`<enclosure>`；未知命名空间元素进入 `extensions[prefix][local]`（media:content/thumbnail/group/description 依赖于此）。
- Atom：link=第一个 rel=alternate（或无 rel）的 href；item.published 缺失时回退 updated；content 按 type：`text` 原文、`html` 实体解码一次、`xhtml` 保留内部 XML 串；feed image 取 logo，否则 icon；feed author 取第一个 `<author><name>`。
- 日期：容错解析多种 RFC822/RFC3339 变体并转为 UTC 输出（向量 1.1）。
- JSON Feed：home_page_url→link、icon→image、items[].id→guid、url→link、content_html|content_text→content、summary→description、date_published/modified、attachments→enclosures。

---

## 3. 测试向量清点（FeedParserTest.kt + fixtures）

Fixture 目录：`input/Feeder/app/src/androidTest/resources/com/nononsenseapps/feeder/model/`（另 `…/ui/cowboy_feed.json`、`…/util/*.ico`；JVM 测试 `app/src/test/resources/.../model/*.html` 属全文解析区）。
androidTest resources 共 48 份（model/ 40 + opml/ 5 + ui/ 1 + util/ 2）；test resources 4 份 HTML。

`bytesToResponse(name, url, contentType="application/xml")` 构造 HTTP 200 响应，URL 作为 base（FeedParserTest.kt:1192-1215）。`readResource` 用字符串路径（UTF-8 读入）。

### 3.1 Feed fixture 向量（期望值逐字摘自测试）

| Fixture（格式/编码/条目数*） | 请求 URL | 测试 | 断言 |
|---|---|---|---|
| rss_ukrnet.xml（RSS/UTF-8/20） | https://suspilne.media/rss/ukrnet.rss | canParseUkrnet :70 | 解析无异常；items=20 |
| rss_anime2you.xml（RSS/25） | https://www.anime2you.de/feed/ | anime2youHasThumbnails :94 | items[0].image == `ImageFromHTML(url="https://img.anime2you.de/2023/12/jujutsu-kaisen-6.jpg", width=700, height=350)` |
| openstreetmap.xml（RSS/20） | `http://https://www.openstreetmap.org/diary/rss` | dcCreatorEndsUpAsAuthor :122 | items[0].author == ParsedAuthor(name="0235")（来自 dc:creator） |
| atom_hnapp.xml（Atom/30） | http://hnapp.com/rss?q=… | htmlAtomContentGetsUnescaped :138 | items[0].title=`37 – Spectre Mitigations in Microsoft's C/C++ Compiler`；content_text=`37 points, 1 comment`；content_html=`<p>37 points, <a href="https://news.ycombinator.com/item?id=16381978">1 comment</a></p>` |
| rss_lemonde.xml（RSS/21） | http://www.lemonde.fr/rss/une.xml | enclosedImageIsUsedAsThumbnail :166 | items[0].image.url=`http://s1.lemde.fr/image/2018/02/11/644x322/5255112_3_a8dc_martin-fourcade_02be61d126b2da39d977b2e1902c819a.jpg` |
| atom_youtube.xml（Atom/14） | http://www.youtube.com/feeds/videos.xml | parsesYoutubeMediaInfo :183 | title=`Can You Observe a Typical Universe?`；image.url=`https://i2.ytimg.com/vi/q-6oU3jXAho/hqdefault.jpg`；content_text 以 `Sign Up on Patreon to get access to the Space Time Discord!` 开头（来自 media:group/media:description） |
| rss_peertube.xml（RSS/20） | https://framatube.org/feeds/videos.xml | parsesPeertubeMediaInfo :203 | title=`1.4. Et les réseaux sociaux ?`；image.url=`https://framatube.org/static/thumbnails/ed5c048d-01f3-4ceb-97db-6e278de512b0.jpg`；content_text 以 `MOOC CHATONS#1 - Internet` 开头 |
| rss_mediarss.xml（RSS/20） | https://rutube.ru/mrss/video/person/11234072/ | parsesYahooMediaRss :223 | title=`Камеди Клаб: «3 сентября»`；image.url=`https://pic.rutubelist.ru/video/93/24/93245691f0e18d063da5fa5cd60fa6de.jpg?size=l` |
| rss_myanimelist.xml（RSS/20） | https://myanimelist.net/rss/news.xml | parsesYahooMediaRss2 :243 | image.url=`https://cdn.myanimelist.net/s/common/uploaded_files/1664092688-dd34666e64d7ae624e6e2c70087c181f.jpeg` |
| rss_theguardian.xml（RSS） | https://www.theguardian.com/world/rss | parsesYahooMediaRssPicksLargestThumbnail :262 | image.url=`https://i.guim.co.uk/img/media/c4d7049b…/master/6000.jpg?width=460&quality=85&auto=format&fit=max&s=919d72fef6d4f3469aff69e94964126c`（多个 media:content 取 width 最大） |
| rss_lawnchair.xml（RSS/20） | https://nitter.weiler.rocks/lawnchairapp/rss | encodingTestWithSmileys :281 | items[0].content_html 含 `😍🤩`（U+1F60D U+1F929，代理对完好） |
| golem-de.xml（RSS/ISO-8859-1/40） | https://rss.golem.de/rss.php?feed=RSS2.0 | encodingIsHandledInAtomRss :375 | items[0].content_text 含 `größte` |
| empty_slash_comment.xml（RSS/ISO-8859-1/1） | 同上 | emptySlashComments… :393 | items=1；content_text 含 `größte` |
| atom_utdelningsseglaren.xml（Atom/25） | http://utdelningsseglaren.blogspot.com/feeds/posts/default | correctAlternateLinkInAtomIsUsedForUrl :416 | items[0].url=`http://utdelningsseglaren.blogspot.com/2017/12/tips-pa-6-podcasts.html`（条目有 replies×2/edit/self/alternate 五个 link，必须取 rel=alternate） |
| rss_lineageos.xml（**实为 Atom**/10，相对链接，id=`//`） | https://lineageos.org/feed.xml | relativeFeedLinkInRssIsMadeAbsolute :460 | home_page_url=`https://lineageos.org/`；feed_url=`https://lineageos.org/feed.xml`；items[0].id=`https://lineageos.org/Changelog-16`；url=`https://lineageos.org/Changelog-16/`；image.url=`https://lineageos.org/images/2018-02-25/lineageos-15.1-hero.png` |
| atom_research_rsc.xml（Atom/17，含 `<style>`） | http://research.swtch.com/feed.atom | noStyles :497 / feedAuthorIsUsedAsFallback :524 | feed_url 同请求；items=17；items[9].image.url=`http://research.swtch.com/qr-bbc.png`；title=`QArt Codes`；summary=`QR codes are 2-dimensional bar codes … building r`（200 字符，style 内容被忽略）；feed.author.name=`Russ Cox`，items[9].author.name 同（回退） |
| rss_nixos.xml（RSS/99） | http://nixos.org/news-rss.xml | nixos :540 | items=99；items[0].title=`NixOS 18.09 released`；image.url=`https://nixos.org/logo/nixos-logo-18.09-jellyfish-lores.png` |
| rss_nixers_newsletter.xml（RSS/111） | https://newsletter.nixers.net/feed.xml | nixers :557 | items=111；items[0].date_published 以 `2019-01-25` 开头 |
| 同上，content-type `video/mp4` | https://foo.bar/video.mp4 | doesNotFetchVideoContentType :575 | Left；description 含 `video/mp4` |
| 同上，content-type null | https://foo.bar/feed.xml | fetchesNullContentType :588 | Right |
| 同上，content-type `text/html` | https://foo.bar/feed.xml | fetchesTextContentType :597 | Right |
| rss_cyklistbloggen.xml（RSS/10） | http://www.cyklistbloggen.se/feed/ | cyklist :607 | items=10；items[0].image.url=`http://www.cyklistbloggen.se/wp-content/uploads/2014/01/Danviksklippan-skyltad.jpg`；title=`Ingen ombyggning av Danvikstull`；summary=`För mer än tre år sedan … I smalaste passagen är gångdel`（NBSP 被替换为空格、首尾 trim） |
| rss_cowboy.xml（RSS/15） | http://cowboyprogrammer.org/index.xml | cowboy :637 | items=15；items[1].image.url=`https://cowboyprogrammer.org/images/zopfli_boxplot.png`，title=`Compress all the images!`，summary=`Update 2016-11-22: Made the Makefile compatible with BSD sed (MacOS) One advantage … to be d`；items[4].title=`Fixing the up button in Python shell history`，summary 以 `In case your python/ipython shell doesn’t have a working history, e.g. pressing ↑ only prints some nonsensical ^[[A, …` 开头、到 `Ipython is more descri` |
| rss_cornucopia.xml（RSS/25） | https://cornucopia.cornubot.se/feeds/posts/default?alt=rss | rss :671 | home=`http://cornucopia.cornubot.se/`；feed_url=请求 URL；items=25；items[0].title=`Tredje månaden med överhettad svensk ekonomi - tydlig säljsignal för börsen`；summary 200 字符以 `För tredje månaden på raken ligger …` 开头；content_html 以 `För tredje månaden på raken` 开头；image.url=`https://1.bp.blogspot.com/-hD_mqKJx-XY/WLwTIKSEt6I/AAAAAAAAqfI/sztWEjwSYAoN22y_YfnZ-yotKjQsypZHACLcB/s640/konj.png`；attachments 空 |
| atom_cornucopia.xml（Atom/25） | https://cornucopia.cornubot.se/feeds/posts/default | atom :705 | 同上（feed_url 不得被改为 http） |
| atom_cowboy.xml（Atom/15） | http://cowboyprogrammer.org/atom.xml | atomCowboy :739 | items=15；items[1].id=`http://cowboyprogrammer.org/dummy-id-to-distinguis-from-alternate-link`（相对 id 拼绝对）；date_published 含 `2016`（无 published 回退 updated）；image.url=`http://localhost:1313/images/zopfli_boxplot.png`；feed.icon=`http://localhost:1313/css/images/logo.png`（来自 `<icon>`） |
| rss_morningpaper.xml（RSS/10） | https://blog.acolyer.org/feed/ | morningPaper :758 | home=`https://blog.acolyer.org`；items=10；items[0].title=`Thou shalt not depend on me: analysing the use of outdated JavaScript libraries on the web`；image.url=`https://adriancolyer.files.wordpress.com/2017/02/js-libs-fig-1.jpeg?w=640` |
| rdf_slashdot.xml（RDF/ISO-8859-1/15） | https://rss.slashdot.org/Slashdot/slashdotMain | testSlashdot :780 | home=`https://slashdot.org/`；items=15；feed.icon=`https://a.fsdn.com/sd/topics/topicslashdot.gif`；items[0].url=`https://yro.slashdot.org/story/24/03/02/071229/ransomware-attack-hampers-prescription-drug-sales-at-90-of-us-pharmacies?utm_source=rss1.0mainlinkanon&utm_medium=feed`；title=`Ransomware Attack Hampers Prescription Drug Sales at 90% of US Pharmacies`；summary 以 `"A ransomware gang once thought …` 开头（200 字符）；image == null |
| rss_londoner.xml（RSS/40，2.7MB） | http://londonist.com/feed | londoner :815 | home=`http://londonist.com/`；items=40；items[0].title=`Make The Most Of London's Offerings With Chip`；image.url=`http://assets.londonist.com/uploads/2017/06/chip_2.jpg` |
| rss_anon.xml（RSS/1） | http://ANON.com/rss | noLinkShouldBeNull :842 | home=`http://ANON.com/sub`；feed_url=`http://anon.com/rss`（host 小写化，OkHttp 规范化）；title=description=`ANON`；items=1；items[0].url==null（guid `http://ANON.com/sub/##` 非法 URI 不回退）；title/content_text/content_html/summary 均 `ANON` |
| rss_golem_2.xml（RSS/ISO-8859-1/40） | https://rss.golem.de/… | golem2… :866 | title=`Golem.de` |
| rss_diskuse.xml（RSS/1，双重转义） | https://diskuse.jakpsatweb.cz/rss2.php?topic=173233 | diskuse :884 | items[0].title=`Kajman, O této diskusi: test <pre> in <description> and <b>bold</b> in title` |
| rss_fz.xml（RSS/20） | https://www.fz.se/feeds/nyheter | fzImgUrl :899 **@Ignore** | （未生效）home `http://www.fz.se/nyheter/`、items=20、title `Nier: Automata bjuder på maffig lanseringstrailer` |
| rss_geekpark.xml（RSS/30） | http://main_test.geekpark.net/rss.rss | geekpark :920 | title=`极客公园（！）`；items=30 |
| atom_content_type_html.xml（Atom/1） | http://www.zoocoop.com/contentoob/o1.atom | contentTypeHtmlIsNotUnescapedTwice :930 | items 单条；content_html 含 ` <pre><code class="language-R">obs.lon &lt;- ncvar_get(nc.obs, 'lon')`，且**不**含 `obs.lon <- ncvar_get`（只解码一次） |

\* 条目数为 `<item`/`<entry` 正则粗计，未被测试断言者仅供参考。

### 3.2 内嵌 XML 常量向量（FeedParserTest.kt:1218-1416）
| 常量 | 测试 | 断言 |
|---|---|---|
| atomRelative / atomRelativeNoBase（self link `/feed.atom`，有/无 xml:base） | :432/:446 | Right；feed_url=`http://cowboyprogrammer.org/feed.atom`（=请求 URL） |
| atomWithInvalidSelfLink | selfLinkIsNotUpdated :1012 | feed_url=`http://cowboyprogrammer.org`（请求 URL，不取 self `https://example.com/notvalid`） |
| rssWithHtmlEscapedDescription | :949 | 单条；image.url=`http://cowboyprogrammer.org/hello.jpg&cached=true`；content_html=`<img src="hello.jpg&amp;cached=true">` |
| atomWithHtmlEscapedContents（text/html/xhtml 三条） | :973 | 三条 image.url 均 `http://cowboyprogrammer.org/hello.jpg&cached=true`；text/html 两条 content_html=`<img src="hello.jpg&amp;cached=true">`；xhtml 条 content_html 包含 `<img src="hello.jpg&amp;cached=true"/>` |
| rssBleepingComputer | timestampsAreParsedWithCorrectTimezone :1027 | date_published=`2024-03-14T18:08:43Z` |
| atomWithUnknownProtocol（gemini:// 链接，8 entry） | handlesUnknownProtocols :1043 | Right，items=8（未知协议不致失败） |
| atomWithAlternateLinks | — | 未被任何测试引用 |

### 3.3 站点元数据向量（FeedParser 非 gofeed 部分，HTML fixtures；归 AddFeed/SearchFeed 区，此处只列以便交叉）
fz.html → alternateFeedLinks=[`https://www.fz.se/feeds/nyheter`, `https://www.fz.se/feeds/forum`]（type `application/rss+xml`）、feedImage=`https://www.fz.se/apple-touch-icon.png`；slashdot.html → icon `https://slashdot.org/favicon.ico`；nixos.html → [`https://nixos.org/news-rss.xml`]。cowboyprogrammer.html 仅有加载器（getCowboyHtml），无测试使用。

### 3.4 其它 fixture
- cowboyprogrammer_feed.json（JSON Feed，10 items）、cowboyprogrammer_atom.xml（15 entries）、cowboyprogrammer_deleted_middle_atom.xml（2 entries）：Feeds.kt 提供，RssLocalSyncKtTest 断言同步后 JSON=10 条、Atom=15 条（RssLocalSyncKtTest.kt:195-230）。**JSON Feed 解析的唯一向量**。
- ui/cowboy_feed.json、rss_fz_2022.xml、muhasebetr.html：仓内无引用。
- util/gitlab.ico、png.ico：IcoDecoderTest（非本区）。test/resources 四份 HTML：FullTextParserKtTest（非本区）。

### 3.5 GoFeedExtensionsKtTest（test/.../gofeed，baseUrl `http://test.com`）
- 内容仅 `<img src='http://google.com/image.png' alt='An image'/>`：thumbnail=`ImageFromHTML("http://google.com/image.png")`，snippet=`[An image]`。:14-37
- link=null、guid=`https://example.com/article/123` → link=guid。:40-53
- guid=`urn:uuid:some-non-url-id` → link=null。:56-69
- guid=`http://example.com/sub/##` → link=null。:72-86
- link 与 guid 同在 → 用 link。:89-102
- media content 无宽度（`MediaImage(url)`）+ 正文同图：feedThumbnail=MediaImage，thumbnail=ImageFromHTML（宽度不足 640 → 正文优先）。:105-137

---

## 4. OPML

### 4.1 写出（OpmlWriter.kt）
- 文件头 `<?xml version="1.0" encoding="UTF-8"?>\n`，随后 DSL 渲染：两空格缩进；无子节点自闭合 `/>`；属性按插入顺序。:38,166-188
- 根 `<opml version="1.1" xmlns:feeder="https://nononsenseapps.com/feeder">`；`<head><title>` 文本 `Feeder`（文本节点独占一行，缩进）。:205-209,40-43
- body：遍历 `tags`（来自 `FeedDao.loadTags()` = `SELECT DISTINCT tag … ORDER BY tag COLLATE NOCASE`，空 tag 排最前）；空 tag 的 feed 直接写在 body 下，非空 tag 包在 `<outline title=tag text=tag>` 中（tag 经 escape）。每个 tag 内 feed 来自 `getFeedsByTitle(tag)`（`ORDER BY title`）。:45-57
- feed outline 属性**顺序**：`feeder:notify`、`feeder:imageUrl`（仅非空）、`feeder:fullTextByDefault`、`feeder:openArticlesWith`、`feeder:alternateId`、`feeder:fetchOgImages`、`feeder:blockRules`（仅非空白）、`feeder:allowRules`（仅非空白）、`title`、`text`、`type="rss"`、`xmlUrl`。title/text= escape(`displayTitle` = customTitle 非空白则 customTitle 否则 title)；xmlUrl= escape(url)；布尔写 `true/false`；openArticlesWith 原样（默认 `""` 也写出）。:247-262
- `escape`：`& " ' < >` → `&amp; &quot; &apos; &lt; &gt;`（顺序 & 优先）。:88-94
- `escapeAttribute`（仅 block/allowRules）：escape 后 `\r\n`/`\r`→`\n`，`\n`→`&#10;`，`\t`→`&#9;`。:104-109
- 当 settings 或 blockedPatterns 非空：body 末尾 `<feeder:settings>`，内含逐项 `<feeder:setting key=K value=escape(V)/>`（key 不转义），再逐个 `<feeder:blocked pattern=escape(P)/>`。:58-72
- settings 来源 `SettingsStore.getAllSettings()`：SharedPreferences 中 key ∈ UserSettings 枚举的全部项，值 toString。**包含 OpenAI/翻译 API key 明文**（`pref_openai_key`、`pref_translation_api_key`）。archmodel/SettingsStore.kt:630-638
- 写出 IOException 被吞（只 Log.e）。:77-79

### 4.2 读取（OpmlPullParser.kt）
- 先把整个流读成 bytes；`parseInputStream`（XmlPullParser，自动探测编码，**需命名空间感知**）；失败（Left）则把 bytes 按 UTF-8 解码，正则 `<outline.*?xmlUrl="([^"]+)".*?/>` 每处替换为 `<outline xmlUrl="$1" type="rss" />` 后再解析一次（丢失 title/tag/feeder 属性）。:66-93
- 结构：根必须 `opml`（否则异常）；只处理 `body`，其它子元素整体跳过。:124-137
- body 下：`outline` → readOutline；`settings` 且 ns==feeder 命名空间 → readSettings；其余跳过。:140-154
- outline 有 `xmlUrl`（无命名空间、大小写敏感）→ feed；否则视为 tag 文件夹：tag=unescape(title ?: text ?: "")，递归其子 outline（**多层文件夹被扁平化为最内层文件夹名**）。:211-245
- feed outline：feedTitle=unescape(title ?: text ?: "")；`URL(xmlUrl)` 失败 → 该条丢弃（仅 Log）；`Feed(title = feedTitle.ifBlank{url}, customTitle = feedTitle, tag = 父文件夹名或 "", url)`；可选覆盖（缺省用 Feed 默认值）：`feeder:notify`(toBoolean)、`feeder:fullTextByDefault` → 回退无命名空间 `retrieveFullText`（Flym）、`feeder:alternateId`、`feeder:openArticlesWith`(字符串)、`feeder:fetchOgImages`、`feeder:blockRules`/`feeder:allowRules`（**不** unescape）、`feeder:imageUrl`（URL 非法则 null）。feed outline 的子节点全部跳过。:248-340
- `feeder:settings` 内：`feeder:setting`（属性 key/value，value 经 unescape）存入 map（同 key 后者覆盖）；`feeder:blocked`（属性 pattern，unescape）加入 set。:157-208
- 全部解析完毕后才落库：先逐个 `saveFeed`，再逐个 `saveSetting`，最后一次 `saveBlocklistPatterns`。任一异常 → `OpmlParsingError`(XmlPullParserException) 或 `OpmlUnknownError`。:105-121
- 注意：XmlPullParser 已解码实体，代码再 `unescape` 一次（title/tag/value/pattern），属双重解码；例如属性原文 `&amp;lt;` 最终得 `<`。保持兼容需复刻。
- `toBoolean()` 语义：仅忽略大小写的 `"true"` 为 true，其余（含非法值）为 false。

### 4.3 落库（OPMLImporter.kt）
- `saveFeed`：按 url 查已有 → 有则 `updateFeed(feed.copy(id=existing.id))`（**整行覆盖**为 OPML 值，未在 OPML 中的字段回到 Feed 默认值，如 lastSync/responseHash）；无则 insert。:32-40
- `saveSetting`：`UserSettings.fromKey(key)`（忽略大小写匹配）；未知 key 仅 Log.w。逐 key 转换（:46-162）：布尔类 `toBoolean()`；`pref_body_text_scale` toFloatOrNull ?: 1.0；`pref_max_lines` toIntOrNull ?: 1 且 ≥1；`pref_max_item_count_per_feed` toIntOrNull ?: 100；枚举类经 `*FromString`；`pref_font` 经 `getFontSelectionFromPath`（失败 defaultFont）；OpenAI 6 项与 Translation API 6 项合并进现有设置对象（timeout toIntOrNull ?: 30）；`pref_openai_translation_language` 原样。
- `saveBlocklistPatterns`：过滤空白、过滤已存在、去重后逐个 add。:165-176

UserSettings 全集（导出/导入键，SettingsStore.kt:775-833 + 常量 :648-770）：`pref_added_feeder_news, pref_theme, pref_dark_theme, pref_dynamic_theme, pref_sort, pref_show_fab, pref_feed_item_style, pref_swipe_as_read, pref_sync_only_charging, pref_sync_only_wifi, pref_sync_freq, pref_sync_on_resume, pref_img_only_wifi, pref_img_show_thumbnails, pref_default_open_item_with, pref_open_links_with, pref_open_adjacent, pref_use_in_app_audio_player, pref_paging_mode, pref_animated_paging, pref_body_text_scale, pref_is_mark_as_read_on_scroll, pref_readaloud_detect_lang, pref_max_lines, prefs_filter_saved, prefs_filter_recently_read, prefs_filter_read, prefs_list_show_only_titles, pref_font, pref_show_reading_time, pref_open_drawer_on_fab, pref_show_title_unread_count, pref_max_item_count_per_feed, pref_openai_key, pref_openai_model_id, pref_openai_url, pref_openai_azure_version, pref_openai_azure_deployment_id, pref_openai_request_timeout_seconds, pref_blocklist_apply_to_summaries, pref_blocklist_apply_to_links, pref_openai_translation_language, pref_translation_api_key, pref_translation_api_model_id, pref_translation_api_url, pref_translation_api_azure_version, pref_translation_api_azure_deployment_id, pref_translation_api_request_timeout_seconds, pref_translate_feed_cards_by_default, pref_translate_articles_by_default, pref_force_single_column`（51 项）。

### 4.4 动作（OpmlActions.kt）与入口
- `exportOpml(di, uri)`：SAF `openOutputStream(uri)` → writeOutputStream；异常 → Toast `Failed to export OPML`（R.string.failed_to_export_OPML）+ 第二个 Toast 显示异常消息，返回 Left。:27-62
- `importOpml(di, uri)`：解析 → **无论成败都** `runOnceRssSync(triggeredByUser=true)` → 若结果 Left 则 Toast `Failed to import OPML`；外层异常同样 Toast + 消息。:67-99
- 入口（Feed 页，FeedScreen.kt:199-230,356-415）：导出 `CreateDocument("text/x-opml")`，默认文件名 `feeder-export-<LocalDate>-<secondOfDay>.opml`；导入 `OpenDocument` MIME 列表 `text/xml,text/x-opml,application/xml,application/json,application/octet-stream,*/*`；启动失败（无文件选择器）Toast 对应失败文案。均在 ApplicationCoroutineScope 中执行（离开页面不取消）。
- OpmlImportScreen.kt:142 的 importOpml 调用被注释（该屏另有逻辑，归 Import 区）。

### 4.5 OPML 测试向量
| 测试 | 断言 |
|---|---|
| OpmlWriterKtTest.shouldEscapeStrings :26 | 逐字期望 :157-172（tag `quoted "tag"`、feed 属性顺序、`&amp;type=rss`） |
| …writesRulesWithNewlinesEncodedAsCharacterReferences :54 | `feeder:blockRules="Title=(?i)sponsored&#10;URL=ads &amp; &quot;tracking&quot;"`，`feeder:allowRules="Tag=(?i)linux"` |
| …writesRulesWithTabs… :82 | `feeder:blockRules="Content=Price:&#9;free"` |
| …doesNotWriteRuleAttributesWhenRulesAreEmpty :105 | 不出现 `feeder:blockRules`/`feeder:allowRules` |
| …exportsSettings :125 | 逐字期望 :174-244（51 个 setting + 2 个 blocked，含转义） |
| …escapeAndUnescape :14 | escape/unescape 互逆 |
| OpmlParserTest.handlesAllSettings :113 | 每个 UserSettings 键调用对应 setter，例：`pref_dark_theme="DaRk"`→DARK、`pref_sync_freq="720"`→EVERY_12_HOURS、`pref_feed_item_style="super_compact"`→SUPER_COMPACT、`pref_font="bundled/roboto_flex"`→RobotoFlex、`pref_text_scale 1.6` |
| OpmlParserTest.handlesBlockedPatterns :170 | 输入 `foo, existing, foo, injection break';, "", " "`，已有 `existing` → 仅 add `foo` 与 `injection break';` 各一次 |
| OPMLTest.testWrite :108 | 10 个样例 feed 的逐字文件（OPMLTest.kt:851-935；空 tag feed 0/3/6/9 在 body 顶层，tag1/tag2 分组） |
| OPMLTest.testRead :156 | 读回：url 对应、tag 对应、i=0 时 title=customTitle=`"0"`，其余 title=customTitle=`custom "i"` |
| OPMLTest.testReadExisting :218 | 已有同 url feed 保持 id；OPML 外 feed（20）不变；i=0 notify/alternateId/fullTextByDefault=true、openArticlesWith=`reader`、imageUrl=`https://example.com/feedImage.png` |
| OPMLTest.testReadSettings :128 | 设置全量往返；blockList=[`foo`] |
| OPMLTest.testReadBadFile :336 | 非 XML 文本 → 无 feed、无异常 |
| OPMLTest.testReadMissingFile :352 | 结果 Left |
| OPMLTest.multiLineRulesRoundTripThroughOpml :365 | `Title=(?i)sponsored\nURL=ads & "tracking"` 与 `Tag=(?i)linux\nAuthor=Bob` 往返一致 |
| antennapod-feeds.opml :457 | 8 feeds、tags 仅 `""`；标题 `Alice Isn't Dead`、`Invisible City`、`PodCastle`、`The Art of Storytelling with Brother Wolf`、`The Cleansed: A Post-Apocalyptic Saga`、`The Tolkien Professor`、`Welcome to Night Vale`、`Within the Wires` |
| Flym_auto_backup.opml :514 | 11 feeds、4 tags（含空）；`black humor`/`comics`/`Tech`/`Political humour`；`retrieveFullText` 映射 fullTextByDefault（如 Deathbulge=true、SMBC=false） |
| rssguard_1.opml / rssguard_2.opml :604/:728 | 各 30 feeds、6 tags（含空）；例：`Les trois sagesses`@`Religion`、`Chart Porn`@`Graphs`、`Actualités`@`""` |
| Programming.opml :708 | 50 feeds |
| testExportThenImport :661 | 标题含 `>`/`<` 的 3 个 feed 经 exportOpml→parse 得 3 个 |

---

## 5. 收藏文章导出/导入（model/export）

### 5.1 导出（SavedArticlesExporter.kt）
- JSON（kotlinx，`prettyPrint=true`，encodeDefaults=false 默认）：`{"format":"feeder-saved-articles","version":1,"articles":[…]}`。:24-30,54-63
- 数据源 `FeedItemDao.getBookmarkedItemsForExport()`：`bookmarked = 1`，`ORDER BY link`。link 为 null 的条目跳过。:104-105
- article 字段：`link, guid, title(plainTitle), snippet(plainSnippet), pubDate(ZonedDateTime.toString 或 null), primarySortTime(Instant.toString), readTime(Instant 或 null), author, thumbnailImage(多态对象，判别字段 "type" ∈ ImageFromHTML/EnclosureImage/MediaImage), enclosureLink, enclosureType, wordCount, wordCountFull, feed{url,title,customTitle,tag,fullTextByDefault}`。:77-129
- 入口：`CreateDocument("application/json")`，文件名 `feeder-saved-articles-<LocalDate>-<secondOfDay>.json`；失败 Toast `Failed to export saved articles` + 异常消息。
- 注：kotlinx 默认 `explicitNulls=true`，可空字段为 null 时写 `null`；缩略图 width/height 有默认值 null 时省略（encodeDefaults=false）。（推断自 kotlinx 默认配置，需实现时验证）

### 5.2 导入（SavedArticlesImporter.kt）
- 读全文；`trimStart()` 以 `{` 开头 → JSON（`ignoreUnknownKeys=true`）；否则旧格式：按行 trim、去空、去重，每 500 条 `UPDATE feed_items SET bookmarked=1 WHERE link IN (…)`（只标记已存在条目，不新建）。:59-67,103-118
- JSON 校验：format 必须 `feeder-saved-articles`、version 必须 1，否则 `IllegalArgumentException("Unsupported saved articles export format/version: …")` → Toast `Failed to import saved articles` + 消息。:78-83
- 每篇：解析 feed.url（非法 → feedId=null）；按 url 找 feed，找不到则**新建 Feed**（title/customTitle/url/tag/fullTextByDefault）。已有条目查找：feedId 非空时按 `(guid.ifBlank{link}, feedId)`，再回退按 link（`ORDER BY id LIMIT 1`）。存在 → setBookmarked(true)；不存在 → 插入新 FeedItem：guid=guid.ifBlank{link}、plainTitle、plainSnippet、thumbnailImage、enclosure、author、pubDate(ZonedDateTime.parse 或 null)、link、`notified=true`、firstSyncedTime=primarySortTime=`Instant.parse(primarySortTime) ?: pubDate ?: now`、`bookmarked=true`、readTime、wordCount(Full)。:85-161
- 入口 OpenDocument MIME：`text/plain, application/octet-stream, */*`。

---

## 6. 鸿蒙实现要点 / 平台差异

| 源机制 | 结果契约 | 鸿蒙实现建议 | 差异 |
|---|---|---|---|
| gomobile gofeed（Go 原生 .so + JSON 桥） | XML/JSON → GoFeed 语义结构 | ArkTS 自研解析器：XML 走 `@ohos.xml` XmlPullParser（或 SAX）+ 自研 RSS/Atom/RDF/JSON translator，直接产出与 1.2 同构的 ParsedFeed（无需 JSON 中转） | 无 Go 运行时；编码（ISO-8859-1 等）需用 `util.TextDecoder` 按 XML 声明转码后再解析；日期多格式容错需自写 |
| Moshi 反序列化 | — | 省略 | — |
| Jsoup（findFirstImageInHtml、unescapeEntities） | 首图提取 + 绝对化 | 复用 html-model 区的 HTML 解析库/自研 tokenizer | 实体表与 Jsoup 保持一致 |
| TagSoup HtmlToPlainTextConverter | 标题/摘要纯文本 | 同上，需复刻空白/列表/`[alt]` 规则 | 归 html/text 区，接口共享 |
| java.net.URL / URI | 相对→绝对、guid 合法性 | 自研 RFC3986 resolve（`@ohos.url` URL 可用）；URI 严格校验需复刻（`##` 判非法） | `URL(base, link)` 与 WHATWG URL 行为差异（如 `http://https://…` 主机解析） |
| android.util.Xml XmlPullParser（OPML） | 命名空间感知拉式解析 | `@ohos.xml.XmlPullParser`（API 支持 ns 属性） | 需验证命名空间属性读取与 `&#10;` 字符引用解码 |
| SAF CreateDocument/OpenDocument | 用户选文件读写 | `picker.DocumentViewPicker.save/select` + `fs` | on_device 验证 |
| Toast（ToastMaker） | 失败提示文案 | `promptAction.showToast` | — |
| ApplicationCoroutineScope + Dispatchers.IO | 后台执行、页面离开不取消 | TaskPool / 全局 async | — |
| runOnceRssSync | 导入后触发一次用户同步 | 调用同步域入口 | 依赖 sync 区 |

### 降级候选
- gofeed 的完整扩展支持（iTunes/DublinCore 结构化字段、全部日期格式）——Feeder 仅消费 1.2 列出的字段；可只实现被消费字段 + media:* 扩展树 + dc:creator 作者归并。
- `GoFeed.links/feedLink/authors/categories(feed)/custom/feedType` 无消费者，可不实现。
- OPML 回退正则修复（极少数坏 OPML）可保留实现（成本低），不建议降级。

---

## 7. 风险

- **R1 解析器重写面最大**：gofeed 行为不在仓内，只能靠 3.x 向量（约 40 个）逆推。高风险点：Atom `content type=html|text|xhtml` 的解码次数（contentTypeHtmlIsNotUnescapedTwice、escaped* 三向量）、RSS description 双重转义（diskuse）、`<style>` 忽略、media:group 嵌套、theguardian 取最大宽度、Atom 多 link 取 alternate、RDF、ISO-8859-1、空 `<slash:comments/>`、unknown protocol、2.7MB 大文件（londoner）性能。
- **R2 日期**：输出必须为可被 `ZonedDateTime.parse` 接受的 ISO 串且为 UTC（`…Z`）；gofeed 容错格式（如 `2018-12-13 00:00:00`、`EDT` 时区缩写）需覆盖，否则 pubDate 退化为同步时间，影响排序。
- **R3 GoFeed Kotlin 字段名与 Go json tag 不一致**：`dublinCoreExt`↔`dcExt`、`iTunesExt`↔`itunesExt`、`newFeedURL`↔`newFeedUrl`；Moshi 按属性名匹配，故源应用中这些字段很可能恒为 null（未经运行验证）。无消费者，不影响行为——迁移时不要"修复"成新行为。
- **R4 feed_url 规范化**：anon 向量期望 `http://anon.com/rss`（host 小写），来源于 OkHttp `request.url`，鸿蒙需对 base URL 做同样规范化。
- **R5 OPML 双重 unescape**、`toBoolean` 宽松语义、导入整行覆盖已有 feed（丢 lastSync 等）——均为既有行为，需保持。
- **R6 安全**：OPML 导出包含 OpenAI/翻译 API key 明文；导入会覆盖它们。迁移须保持（契约）但应在设计层提示。
- **R7 `findFirstImageInHtml` 预先 `unescapeEntities`** 导致 `&amp;` 被解码进 URL（`hello.jpg&cached=true`），向量依赖此行为。
- **R8 缩略图决策**：`EnclosureImage` 长度 0 或 >50000 时直接采用；宽度≥640 的媒体图优先；否则正文首图优先——三分支都需向量覆盖（lemonde/theguardian/anime2you/GoFeedExtensionsKtTest）。
