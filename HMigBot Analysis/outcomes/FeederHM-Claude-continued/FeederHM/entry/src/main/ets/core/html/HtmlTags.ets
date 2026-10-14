/**
 * HtmlTags.ets —— 树构建用标签分类（HTML5 规范 §13.2 的 special / formatting / scope 集合等）。
 */
export const HEAD_TAGS: Set<string> = new Set<string>([
  'base', 'basefont', 'bgsound', 'link', 'meta', 'title', 'style', 'script', 'noscript', 'template', 'noframes'
]);
/** 内容按原文（DATA 节点）存放的标签 */
export const RAW_DATA_TAGS: Set<string> = new Set<string>(['script', 'style']);
export const CLOSES_P: Set<string> = new Set<string>([
  'address', 'article', 'aside', 'blockquote', 'center', 'details', 'dialog', 'dir', 'div', 'dl', 'fieldset',
  'figcaption', 'figure', 'footer', 'header', 'hgroup', 'main', 'menu', 'nav', 'ol', 'p', 'search', 'section',
  'summary', 'ul', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre', 'listing', 'form', 'table', 'hr', 'xmp', 'plaintext',
  'dd', 'dt', 'li'
]);
export const HEADINGS: Set<string> = new Set<string>(['h1', 'h2', 'h3', 'h4', 'h5', 'h6']);
export const SPECIAL: Set<string> = new Set<string>([
  'address', 'applet', 'area', 'article', 'aside', 'base', 'basefont', 'bgsound', 'blockquote', 'body', 'br',
  'button', 'caption', 'center', 'col', 'colgroup', 'dd', 'details', 'dir', 'div', 'dl', 'dt', 'embed', 'fieldset',
  'figcaption', 'figure', 'footer', 'form', 'frame', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head',
  'header', 'hgroup', 'hr', 'html', 'iframe', 'img', 'input', 'keygen', 'li', 'link', 'listing', 'main', 'marquee',
  'menu', 'meta', 'nav', 'noembed', 'noframes', 'noscript', 'object', 'ol', 'p', 'param', 'plaintext', 'pre',
  'script', 'search', 'section', 'select', 'source', 'style', 'summary', 'table', 'tbody', 'td', 'template',
  'textarea', 'tfoot', 'th', 'thead', 'title', 'tr', 'track', 'ul', 'wbr', 'xmp'
]);
export const FORMATTING: Set<string> = new Set<string>([
  'a', 'b', 'big', 'code', 'em', 'font', 'i', 'nobr', 's', 'small', 'strike', 'strong', 'tt', 'u'
]);
export const SCOPE_DEFAULT: Set<string> = new Set<string>([
  'applet', 'caption', 'html', 'table', 'td', 'th', 'marquee', 'object', 'template'
]);
export const SCOPE_TABLE: Set<string> = new Set<string>(['html', 'table', 'template']);
export const TABLE_CONTEXT: Set<string> = new Set<string>(['table', 'tbody', 'thead', 'tfoot', 'tr']);
export const TABLE_SECTIONS: Set<string> = new Set<string>(['tbody', 'thead', 'tfoot']);
export const TABLE_ALLOWED: Set<string> = new Set<string>([
  'caption', 'colgroup', 'col', 'tbody', 'thead', 'tfoot', 'tr', 'td', 'th', 'table', 'script', 'style', 'template',
  'input', 'form'
]);
/** 推入活动格式列表 marker 的元素 */
export const MARKER_TAGS: Set<string> = new Set<string>(['td', 'th', 'caption', 'applet', 'marquee', 'object', 'template']);
/** 插入前不重建活动格式元素的起始标签（除 CLOSES_P 外） */
export const NO_RECONSTRUCT: Set<string> = new Set<string>([
  'base', 'basefont', 'bgsound', 'link', 'meta', 'title', 'style', 'script', 'noscript', 'template', 'noframes',
  'textarea', 'iframe', 'noembed', 'xmp', 'html', 'body', 'head', 'frameset', 'frame'
]);
