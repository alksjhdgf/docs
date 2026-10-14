/**
 * HtmlVectors.ets —— fnd-html-dom 单测向量（源 src/test/.../text/HtmlToPlainTextConverterTest.kt、
 * util/HtmlUtilsKtTest.kt、util/ExtractOgImageTest.kt、ui/text/MarkdownToHtmlConverterTest.kt
 * + 台账 HM-A48..A56 / UT-A14..A21 + Jsoup 行为边界）。纯数据。
 */

export interface HtmlStringVector {
  input: string;
  expected: string;
}

export interface FirstImageVector {
  name: string;
  html: string | null;
  baseUrl: string | null;
  /** null = 期望无结果 */
  expectedUrl: string | null;
  expectedWidth: number | null;
  expectedHeight: number | null;
}

export interface OgImageVector {
  name: string;
  html: string;
  baseUrl: string;
  /** null = 期望无结果 */
  expected: string | null;
}

export interface MarkdownContainsVector {
  name: string;
  markdown: string;
  contains: string[];
}

export interface SelectorVector {
  html: string;
  query: string;
  /** 匹配元素的 text()，按文档序 */
  texts: string[];
}

export interface DomTextVector {
  html: string;
  /** 取 body.text() */
  bodyText: string;
}

// HM-A48..A52（HtmlToPlainTextConverterTest 全部用例 + 台账补充）
export const PLAIN_TEXT_VECTORS: HtmlStringVector[] = [
  { input: '', expected: '' },
  { input: '<ul><li>one</li><li>two</li></ul>', expected: '* one\n* two' },
  { input: '<ol><li>one</li><li>two</li></ol>', expected: '1. one\n2. two' },
  { input: '<ol><li>sublist:<ul><li>A</li><li>B</li></ul></li><li>two</li></ol>', expected: '1. sublist:\n  * A\n  * B\n2. two' },
  { input: 'go to <a href="google.com">Google</a> and see.', expected: 'go to Google and see.' },
  { input: '<p>one<br>two<p>three', expected: 'one two three' },
  { input: 'foo <script>script</script> bar', expected: 'foo bar' },
  { input: 'foo <style>style</style> bar', expected: 'foo bar' },
  { input: 'foo <img src="meh" alt="meh"> bar', expected: 'foo bar' },
  { input: '<b>foo</b>', expected: 'foo' },
  { input: '<i>foo</i>', expected: 'foo' },
  { input: '<img src=\'bar\' alt=\'heh\'> foo', expected: 'foo' },
  // 补充：NBSP → 空格并 trim；块级/标题/引用只产生单个空格；仅图片时输出 [alt]
  { input: '&nbsp;foo&nbsp;', expected: 'foo' },
  { input: '<h1>Title</h1><blockquote>quote</blockquote><div>div</div>', expected: 'Title quote div' },
  { input: '<img src="x.png" alt="xkcd">', expected: '[xkcd]' },
  { input: '<img src="x.png"><img src="y.png" alt="  ">', expected: '[IMG]' },
  { input: '<p><strong>bold</strong> and <em>em</em></p>', expected: 'bold and em' },
  { input: 'a&amp;b &lt;tag&gt;', expected: 'a&b <tag>' }
];

const LONG_ALT: string = 'Every time we detect an asteroid from outside the Solar System, we should immediately ' +
  'launch a mission to fling one of our asteroids back in the direction it came from.';

const RED_DOT: string = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4' +
  '//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==';

// UT-A14..A16（HtmlUtilsKtTest 全部用例 + 台账补充）
export const FIRST_IMAGE_VECTORS: FirstImageVector[] = [
  {
    name: 'findsBase64InlineImages',
    html: '<summary type="html">\n&lt;img src="data:image/png;base64,iVBORw0KGgoAAA\n' +
      'ANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4\n//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU\n' +
      '5ErkJggg==" alt="Red dot" /&gt;</summary>',
    baseUrl: null, expectedUrl: RED_DOT, expectedWidth: null, expectedHeight: null
  },
  {
    name: 'findsBase64InlineImagesSingleLine',
    html: '<summary type="html">&lt;img src="' + RED_DOT + '" alt="Red dot" /&gt;</summary>',
    baseUrl: null, expectedUrl: RED_DOT, expectedWidth: null, expectedHeight: null
  },
  {
    name: 'findsImageInSingleLine',
    html: '<summary type="html">&lt;img src="https://imgs.xkcd.com/comics/interstellar_asteroid.png" title="' +
      LONG_ALT + '" alt="' + LONG_ALT + '" /&gt;</summary>',
    baseUrl: null, expectedUrl: 'https://imgs.xkcd.com/comics/interstellar_asteroid.png',
    expectedWidth: null, expectedHeight: null
  },
  {
    name: 'findsImageInSingleLineSrcFarFromImg',
    html: '<summary type="html">&lt;img title="' + LONG_ALT + '" alt="' + LONG_ALT +
      '" src="https://imgs.xkcd.com/comics/interstellar_asteroid.png" /&gt;</summary>',
    baseUrl: null, expectedUrl: 'https://imgs.xkcd.com/comics/interstellar_asteroid.png',
    expectedWidth: null, expectedHeight: null
  },
  {
    name: 'returnsNullWhenNoImageLink',
    html: '<summary type="html">&lt;img title="' + LONG_ALT + '" alt="' + LONG_ALT + '" /&gt;</summary>',
    baseUrl: null, expectedUrl: null, expectedWidth: null, expectedHeight: null
  },
  {
    name: 'returnsNullForNull',
    html: null, baseUrl: null, expectedUrl: null, expectedWidth: null, expectedHeight: null
  },
  {
    name: 'returnsNullForTwitterAndFacebookIcons',
    html: '<description>Thanks to long-time Slashdot reader walterbyrd for sharing the link!<p>' +
      '<div class="share_submission" style="position:relative;"> <a class="slashpop" href="http://twitter.com/home">' +
      '<img src="https://a.fsdn.com/sd/twitter_icon_large.png"></a> <a class="slashpop" ' +
      'href="http://www.facebook.com/sharer.php?u=x"><img src="https://a.fsdn.com/sd/FACEBOOK_icon_large.png"></a> ' +
      '</div></p><p><a href="https://hardware.slashdot.org/story?utm_source=rss1.0moreanon&amp;utm_medium=feed">' +
      'Read more of this story</a> at Slashdot.</p><iframe src="https://slashdot.org/slashdot-it.pl?op=discuss&amp;' +
      'id=22035223&amp;smallembed=1" style="height: 300px; width: 100%; border: none;"></iframe></description>',
    baseUrl: null, expectedUrl: null, expectedWidth: null, expectedHeight: null
  },
  {
    name: 'returnsNullForTrackingPixels',
    html: '<description>asdfasd <img src="https://foo/track.png" width="1" height="1"> asdf asd</description>',
    baseUrl: null, expectedUrl: null, expectedWidth: null, expectedHeight: null
  },
  {
    name: 'skipsPixelAndEmptySrcThenResolvesRelative',
    html: '<p><img src="/px.gif" height="1"><img alt="no src"><img src="img/a.jpg" width="640" height="abc"></p>',
    baseUrl: 'https://example.com/blog/post.html', expectedUrl: 'https://example.com/blog/img/a.jpg',
    expectedWidth: 640, expectedHeight: null
  },
  {
    name: 'intDimensions',
    html: '<img src="https://x.com/a.png" width="300" height="+200">',
    baseUrl: null, expectedUrl: 'https://x.com/a.png', expectedWidth: 300, expectedHeight: 200
  }
];

// UT-A17..A19（ExtractOgImageTest 全部用例）
export const OG_IMAGE_VECTORS: OgImageVector[] = [
  {
    name: 'extractsOgImageFromPropertyAttribute',
    html: '<html><head>\n<meta property="og:image" content="https://example.com/image.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/image.jpg'
  },
  {
    name: 'extractsOgImageFromNameAttribute',
    html: '<html><head>\n<meta name="og:image" content="https://example.com/image.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/image.jpg'
  },
  {
    name: 'prefersPropertyOverNameAttribute',
    html: '<html><head>\n<meta property="og:image" content="https://example.com/property.jpg">\n' +
      '<meta name="og:image" content="https://example.com/name.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/property.jpg'
  },
  {
    name: 'fallsBackToTwitterImageWhenNoOgImage',
    html: '<html><head>\n<meta property="twitter:image" content="https://example.com/twitter.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/twitter.jpg'
  },
  {
    name: 'fallsBackToTwitterImageFromNameAttribute',
    html: '<html><head>\n<meta name="twitter:image" content="https://example.com/twitter-name.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/twitter-name.jpg'
  },
  {
    name: 'prefersOgImageOverTwitterImage',
    html: '<html><head>\n<meta property="og:image" content="https://example.com/og.jpg">\n' +
      '<meta property="twitter:image" content="https://example.com/twitter.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/og.jpg'
  },
  {
    name: 'firstOgImageWinsWhenMultiplePresent',
    html: '<html><head>\n<meta property="og:image" content="https://example.com/first.jpg">\n' +
      '<meta property="og:image" content="https://example.com/second.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/first.jpg'
  },
  {
    name: 'resolvesRelativeUrlAgainstBaseUrl',
    html: '<html><head>\n<meta property="og:image" content="/images/thumb.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/article/123', expected: 'https://example.com/images/thumb.jpg'
  },
  {
    name: 'resolvesProtocolRelativeUrlAgainstBaseUrl',
    html: '<html><head>\n<meta property="og:image" content="//cdn.example.com/image.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/article', expected: 'https://cdn.example.com/image.jpg'
  },
  {
    name: 'returnsNullWhenNoMetaTagsPresent',
    html: '<html><head><title>No image here</title></head><body></body></html>',
    baseUrl: 'https://example.com/', expected: null
  },
  {
    name: 'ignoresBlankOgImageContent',
    html: '<html><head>\n<meta property="og:image" content="   ">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: null
  },
  {
    name: 'ignoresEmptyOgImageContent',
    html: '<html><head>\n<meta property="og:image" content="">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: null
  },
  {
    name: 'returnsNullWhenContentAttributeMissing',
    html: '<html><head>\n<meta property="og:image">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: null
  },
  {
    name: 'blankOgImageFallsBackToTwitterImage',
    html: '<html><head>\n<meta property="og:image" content="">\n' +
      '<meta property="twitter:image" content="https://example.com/twitter.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/twitter.jpg'
  },
  {
    name: 'handlesUpperCaseMetaTag',
    html: '<html><head>\n<META PROPERTY="og:image" CONTENT="https://example.com/image.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/image.jpg'
  },
  {
    name: 'matchesAttributeValueCaseInsensitively',
    html: '<html><head>\n<meta property="og:Image" content="https://example.com/image.jpg">\n</head><body></body></html>',
    baseUrl: 'https://example.com/', expected: 'https://example.com/image.jpg'
  },
  {
    name: 'returnsNullForEmptyHtml',
    html: '', baseUrl: 'https://example.com/', expected: null
  },
  {
    name: 'returnsNullForMinimalHtmlWithNoHead',
    html: '<html><body>Hello</body></html>', baseUrl: 'https://example.com/', expected: null
  },
  {
    name: 'extractsOgImageFromRealisticPage',
    html: '<!DOCTYPE html>\n<html lang="en">\n<head>\n    <meta charset="utf-8">\n    <title>Test Article</title>\n' +
      '    <meta property="og:title" content="Test Article">\n    <meta property="og:description" content="A description">\n' +
      '    <meta property="og:image" content="https://cdn.example.com/photos/2024/article-hero.jpg">\n' +
      '    <meta property="og:type" content="article">\n    <meta name="twitter:card" content="summary_large_image">\n' +
      '    <meta name="twitter:image" content="https://cdn.example.com/photos/2024/article-twitter.jpg">\n' +
      '    <link rel="stylesheet" href="/style.css">\n</head>\n<body><p>Article content</p></body>\n</html>',
    baseUrl: 'https://example.com/article', expected: 'https://cdn.example.com/photos/2024/article-hero.jpg'
  }
];

// HM-A54（MarkdownToHtmlConverterTest 全部用例：包含断言）
export const MARKDOWN_CONTAINS_VECTORS: MarkdownContainsVector[] = [
  {
    name: 'basic', markdown: 'This is **bold** and this is *italic*',
    contains: ['<strong>', '</strong>', '<em>', '</em>']
  },
  { name: 'list', markdown: '- Item 1\n- Item 2\n- Item 3', contains: ['<ul>', '</ul>', '<li>', '</li>'] },
  { name: 'heading', markdown: '# Heading 1\n## Heading 2', contains: ['<h1>', '</h1>', '<h2>', '</h2>'] },
  {
    name: 'complex',
    markdown: '# Summary\n\nThis is a **summary** of the article:\n\n- **Key point 1**: Important information\n' +
      '- *Key point 2*: More details\n\n> Quote from the article\n\n## Conclusion\n\nThe article discusses `code` and more.',
    contains: ['<h1>', '<strong>', '<ul>', '<blockquote>', '<h2>', '<code>']
  }
];

// 自研 CommonMark 子集的精确输出（jetbrains HtmlGenerator 形态：外层 <body>）
export const MARKDOWN_EXACT_VECTORS: HtmlStringVector[] = [
  { input: 'This is **bold** and this is *italic*', expected: '<body><p>This is <strong>bold</strong> and this is <em>italic</em></p></body>' },
  { input: '- a\n- b', expected: '<body><ul><li>a</li><li>b</li></ul></body>' },
  { input: '# H1\n## H2', expected: '<body><h1>H1</h1><h2>H2</h2></body>' },
  { input: '> quote', expected: '<body><blockquote><p>quote</p></blockquote></body>' },
  { input: 'use `a<b` here', expected: '<body><p>use <code>a&lt;b</code> here</p></body>' },
  { input: '1. one\n2. two', expected: '<body><ol><li>one</li><li>two</li></ol></body>' },
  { input: '***both***', expected: '<body><p><em><strong>both</strong></em></p></body>' },
  { input: '[link](https://x.com "t")', expected: '<body><p><a href="https://x.com" title="t">link</a></p></body>' }
];

// Jsoup 选择器子集（标签/类/id/属性/后代/子代）
const SEL_DOC: string = '<div id="main" class="Box big"><p class="a">one</p><span><p>two</p></span>' +
  '<a href="/x" data-k="V">link</a></div><p id="tail">three</p>';

export const SELECTOR_VECTORS: SelectorVector[] = [
  { html: SEL_DOC, query: 'p', texts: ['one', 'two', 'three'] },
  { html: SEL_DOC, query: '#main > p', texts: ['one'] },
  { html: SEL_DOC, query: '#main p', texts: ['one', 'two'] },
  // Jsoup text()：块元素仅在其后紧跟文本/行内兄弟时补空格；span 内的 p 无兄弟 → 'two' 与 'link' 相连
  { html: SEL_DOC, query: '.box', texts: ['one twolink'] },
  { html: '<div class="x"><p>in</p><b>tail</b></div>', query: '.X', texts: ['in tail'] },
  { html: SEL_DOC, query: 'div.big.box span', texts: ['two'] },
  { html: SEL_DOC, query: 'a[href]', texts: ['link'] },
  { html: SEL_DOC, query: '[data-k=v]', texts: ['link'] },
  { html: SEL_DOC, query: 'a[href^=/], p#tail', texts: ['link', 'three'] },
  { html: SEL_DOC, query: '[^data-]', texts: ['link'] },
  { html: SEL_DOC, query: 'p:not(.a)', texts: ['two', 'three'] },
  { html: SEL_DOC, query: 'div:has(span) > a', texts: ['link'] }
];

// 宽容解析：未闭合、实体、script 原文、自闭合、块级空白（Jsoup Element.text 语义）
export const DOM_TEXT_VECTORS: DomTextVector[] = [
  { html: '<p>one<p>two', bodyText: 'one two' },
  { html: '<div>a<br>b</div>c', bodyText: 'a b c' },
  { html: 'x &amp; y &copy &notit; &#65;&#x42;', bodyText: 'x & y © ¬it; AB' },
  { html: '<b>bo<i>th</b> it</i>', bodyText: 'both it' },
  { html: '<script>if (a < b) { x = "</p>"; }</script>ok', bodyText: 'ok' },
  { html: '<ul><li>1<li>2</ul>', bodyText: '1 2' },
  { html: '<table><tr><td>a<td>b</table>', bodyText: 'a b' },
  { html: '<p>  lots   of\n\tspace </p>', bodyText: 'lots of space' },
  { html: '<pre>  keep\n  this</pre>', bodyText: 'keep\n  this' }
];
