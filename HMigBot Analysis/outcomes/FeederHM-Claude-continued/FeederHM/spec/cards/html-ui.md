# html-ui

## 域: 文章正文块渲染
- HU-A01 [ui] 文章正文按 LinearArticle.elements 顺序逐块渲染，每块宽度不超过阅读最大宽度（手机 600dp / 平板 640dp）并水平居中。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:153
- HU-A02 [ui] 每个文本段落按自身内容独立判定书写方向：基础方向为 RTL 的段落（如阿拉伯语/希伯来语）以从右到左布局显示，无强方向字符时为 LTR。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/Bidi.kt:10
- HU-A03 [ui] 正文文本字号与行高随用户阅读字号缩放设置（fontScale）等比变化。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:624
- HU-A04 [ui] 文本注解渲染：Bold 加粗、Italic 斜体、Underline 下划线、Strikethrough 删除线、Superscript/Subscript 上/下标基线偏移。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:931
- HU-A05 [ui] H1–H6 注解区间统一以 headlineSmall 标题样式显示（不分级）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:947
- HU-A06 [ui] Monospace 注解与 Font face=monospace 使用用户设置的等宽字体；Font face=serif/sans-serif 分别用用户设置的衬线/无衬线字体，其他 face 不改变字体。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToComposable.kt:45
- HU-A07 [ui] 非代码块（TEXT/PRE_FORMATTED）中的 Code 注解以内联代码样式显示（surfaceVariant 背景 + 等宽字体）；CODE_BLOCK 内不再叠加内联样式。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:1003
- HU-A08 [ui] Link 注解区间以链接样式显示（主题 primary 色 + 下划线）且可点击。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:969
- HU-A09 [backend] 链接点击回调 onLinkClick(href, index)：href 含 '#' 时取最后一个 '#' 后片段查 idToIndex 得元素序号，查不到或无 '#' 则 index=null。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:978
- HU-A10 [backend] idToIndex 由每个顶层元素的 ids 映射到该元素序号构成，仅包含顶层元素。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:10
- HU-A11 [ui] PRE_FORMATTED 与 CODE_BLOCK 文本块都渲染为代码块：surfaceVariant 背景圆角容器、onSurfaceVariant 文字色、不自动换行，超宽内容可横向滚动查看。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:763
- HU-A12 [ui] 有序列表项前缀显示 `<orderedIndex>.`，无序列表项前缀显示 `•`，项内容在前缀右侧且可嵌套任意块（段落/图片/表格/子列表）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:455
- HU-A13 [ui] 引用块以带色调提升的 surface 圆角容器显示，内部文本为 Light 字重；仅渲染引用内的文本块，非文本子元素（图片/列表/表格等）不显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:661
- HU-A14 [ui] 引用块有 cite 时在容器底部右对齐显示 cite URL 原文（bodySmall、tertiary 色、斜体），点击按 HU-A09 规则触发 onLinkClick(cite, index)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:679
- HU-A15 [ui] 图片 sources 为空时整块不显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:485
- HU-A16 [backend] 多源图片选择：对每个源按 pixelDensity/设备密度、screenWidth/容器宽、widthPx/容器宽（均缺失则 1/设备密度）计算比值，选 |比值-1| 最小者；容器宽 px 上限 2000。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:599
- HU-A17 [ui] 图片加载中显示占位图标（Terrain），加载失败显示错误图标（ErrorOutline）；图片不被放大超过设备像素密度倍数，宽度不超过容器宽。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:552
- HU-A18 [ui] 图片有 link 时点击图片按 HU-A09 规则触发 onLinkClick(link, index)；link 为空时图片不可点击。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:501
- HU-A19 [ui] 图片有 caption 时在图片下方以 labelMedium 显示 caption 文本（可含可点击链接），caption 同时作为图片无障碍描述；caption 非空白时长按图片显示 caption 提示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:581
- HU-A20 [ui] 视频块有缩略图时显示缩略图（加载中 PlayCircleOutline、失败 ErrorOutline），点击缩略图触发 onLinkClick(firstSource.link, null)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:333
- HU-A21 [ui] 视频块始终显示链接样式文字 `Touch to play video`，点击触发 onLinkClick(firstSource.link, null)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:405
- HU-A22 [ui] 音频块显示链接样式文字 `Touch to play audio`，点击触发 onLinkClick(firstSource.uri, null)。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:309
- HU-A23 [ui] 表格按行列网格显示：列宽取该列最大单元格宽、行高取该行最大单元格高，colSpan/rowSpan 跨格正确合并，spans 为 0 表示跨至表尾；filler 占位格不渲染。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:1512
- HU-A24 [ui] 表格超出阅读宽度时整体可横向滚动；单元格内的代码块/嵌套表格不单独横滚。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:896
- HU-A25 [ui] 表格 HEADER 单元格文字加粗；奇数行（0 起）背景为 surfaceVariant 形成斑马纹，但表格任一单元格含图片时所有行不着色。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:836
- HU-A26 [ui] 多列表格在非最后一列右侧绘制 1dp outlineVariant 竖分隔线，无横分隔线。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/html/LinearArticleContent.kt:854
- HU-A27 [ui] RTL 表格（dir=rtl）列顺序镜像，首列显示在最右侧。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/model/html/LinearStuff.kt:236
- HU-A28 [ui] 正文文本可被长按选择复制，图片与视频区域不参与文本选择。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ReaderView.kt:110

## 域: 链接点击路由（阅读器调用方）
- HU-A29 [ui] 点击带 index 且该序号块位置已知的链接时，正文动画滚动到目标块位置，不打开外部应用。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:723
- HU-A30 [backend] 非页内跳转链接：启用应用内音频播放器且链接为本文 audio/* 附件或音频扩展名时进入应用内播放器，否则按设置用自定义标签页或默认浏览器打开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:730
- HU-A31 [backend] 外部打开时空白链接或以 '#' 开头的链接不做任何事；mailto: 链接交给邮件客户端。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:59
- HU-A32 [on_device] 点击正文外链后真实拉起浏览器/自定义标签页（或邮件客户端）并加载该 URL；无可处理应用时提示 `no_activity_for_link` 文案。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/util/ActivityLauncher.kt:40

## 域: HTML 转朗读/摘要段落
- HU-A33 [backend] htmlToAnnotatedString 将 HTML body 拆为段落列表：p、h1–h6、pre、code、blockquote、figure、img、表格行等为段落边界，空段不产出；class=readability-styled 的 p 不分段。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToAnnotatedString.kt:84
- HU-A34 [backend] 段落文本空白规范化：连续可折叠空白（空格/Tab/LF/CR/FF/NBSP）折叠为一个空格、段首可折叠空白去除，ZWNJ 等不可见字符保留；pre 内保留原始空白，br 产生换行。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToComposable.kt:67
- HU-A35 [backend] 列表转段落：ul 每个 li 一段并以 `• ` 开头，ol 每个 li 一段并以 `<序号>. ` 开头（序号从 1 起）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToAnnotatedString.kt:286
- HU-A36 [backend] 表格转段落：先 caption，再按 thead→tbody→tfoot 顺序每个 tr 一段；rt/rp/iframe/video 内容忽略，img 不朗读 alt。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToAnnotatedString.kt:318
- HU-A37 [backend] 段落样式：strong/b 粗体、i/em/cite/dfn 斜体、tt/pre/code 等宽、sup/sub 上下标、u 无样式；a 标签以 tag "URL" 记录绝对 href（为空回退原 href）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/HtmlToAnnotatedString.kt:172
- HU-A38 [ui] AI 摘要（Markdown→HTML）按上述段落逐段显示于摘要卡片，段间距 8dp；摘要中的链接不可点击。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleScreen.kt:817
- HU-A39 [on_device] 朗读文章时 TTS 按 htmlToAnnotatedString 产出的段落顺序依次朗读正文（原文/全文/译文按当前显示选择）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feedarticle/ArticleViewModel.kt:475

## 域: 资源富文本
- HU-A40 [ui] 空态页文案 `Open another feed?` 与 `Add more feeds?` 中被 annotation style=link 标记的词（`Open`/`Add`）以链接样式（primary 色+下划线）显示。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/text/Extensions.kt:24
