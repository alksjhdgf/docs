/**
 * GoFeed.ets —— 源 model/gofeed/GoFeed.kt（Go gofeed 结构的 Kotlin 镜像）移植。
 *
 * 源应用中这些对象由 gomobile gofeed 产出 JSON、再经 Moshi 反序列化得到。Go 侧 json tag 大多带 omitempty，
 * 因此：空串 / 空数组 / nil 指针 → Kotlin 侧为 null（本移植由 XmlFeedParser/JsonFeedParser 在产出时遵守同一规则）。
 * GoExtension 的 json tag 无 omitempty：name/value 恒为字符串（可能为空串），attrs/children 恒为（可能为空的）Map。
 *
 * 风险 R3（explore/feed-parser.md）：Kotlin 字段名 dublinCoreExt/iTunesExt 与 Go json key dcExt/itunesExt 不一致，
 * Moshi 按属性名匹配，故源应用中这两个字段恒为 null。本移植保持该行为（解析器内部仍使用 DC/iTunes 数据做作者/标题回退，
 * 但不回填到 GoFeed/GoItem 的这两个字段），不"修复"成新行为。
 */

/** Go Person{name,email}（json omitempty） */
export class GoPerson {
  name: string | null = null;
  email: string | null = null;

  constructor(name: string | null = null, email: string | null = null) {
    this.name = name;
    this.email = email;
  }
}

/** Go Image{url,title} */
export class GoImage {
  url: string | null = null;
  title: string | null = null;

  constructor(url: string | null = null, title: string | null = null) {
    this.url = url;
    this.title = title;
  }
}

/** Go Enclosure{url,length,type}（length 为字符串） */
export class GoEnclosure {
  url: string | null = null;
  length: string | null = null;
  type: string | null = null;

  constructor(url: string | null = null, length: string | null = null, type: string | null = null) {
    this.url = url;
    this.length = length;
    this.type = type;
  }
}

/**
 * Go ext.Extension{name,value,attrs,children}。
 * attrs 以属性本地名为 key（命名空间信息被丢弃，同名后者覆盖）；children 以子元素本地名为 key。
 */
export class GoExtension {
  name: string | null = null;
  value: string | null = null;
  attrs: Map<string, string> | null = null;
  children: Map<string, GoExtension[]> | null = null;

  constructor(name: string | null = null, value: string | null = null, attrs: Map<string, string> | null = null,
    children: Map<string, GoExtension[]> | null = null) {
    this.name = name;
    this.value = value;
    this.attrs = attrs;
    this.children = children;
  }
}

/** typealias GoExtensions = Map<命名空间前缀, Map<元素本地名, List<GoExtension>>> */
export type GoExtensions = Map<string, Map<string, GoExtension[]>>;

/** Go ext.DublinCoreExtension（16 个 []string） */
export class GoDublinCoreExtension {
  title: string[] | null = null;
  creator: string[] | null = null;
  author: string[] | null = null;
  subject: string[] | null = null;
  description: string[] | null = null;
  publisher: string[] | null = null;
  contributor: string[] | null = null;
  date: string[] | null = null;
  type: string[] | null = null;
  format: string[] | null = null;
  identifier: string[] | null = null;
  source: string[] | null = null;
  language: string[] | null = null;
  relation: string[] | null = null;
  coverage: string[] | null = null;
  rights: string[] | null = null;
}

/** Go ext.ITunesCategory */
export class GoITunesCategory {
  text: string | null = null;
  subcategory: GoITunesCategory | null = null;
}

/** Go ext.ITunesOwner */
export class GoITunesOwner {
  email: string | null = null;
  name: string | null = null;
}

/** Go ext.ITunesFeedExtension */
export class GoITunesFeedExtension {
  author: string | null = null;
  block: string | null = null;
  categories: (GoITunesCategory | null)[] | null = null;
  explicit: string | null = null;
  keywords: string | null = null;
  owner: GoITunesOwner | null = null;
  subtitle: string | null = null;
  summary: string | null = null;
  image: string | null = null;
  complete: string | null = null;
  newFeedURL: string | null = null;
  type: string | null = null;
}

/** Go ext.ITunesItemExtension */
export class GoITunesItemExtension {
  author: string | null = null;
  block: string | null = null;
  duration: string | null = null;
  explicit: string | null = null;
  keywords: string | null = null;
  subtitle: string | null = null;
  summary: string | null = null;
  image: string | null = null;
  isClosedCaptioned: string | null = null;
  episode: string | null = null;
  season: string | null = null;
  order: string | null = null;
  episodeType: string | null = null;
}

/**
 * Go Item（条目）。updatedParsed/publishedParsed 为 Go time.Time 的 JSON 形式（RFC3339Nano 串）。
 */
export class GoItem {
  title: string | null = null;
  description: string | null = null;
  content: string | null = null;
  link: string | null = null;
  links: string[] | null = null;
  updated: string | null = null;
  updatedParsed: string | null = null;
  published: string | null = null;
  publishedParsed: string | null = null;
  author: GoPerson | null = null;
  authors: (GoPerson | null)[] | null = null;
  guid: string | null = null;
  image: GoImage | null = null;
  categories: string[] | null = null;
  enclosures: (GoEnclosure | null)[] | null = null;
  /** 恒为 null（风险 R3，见文件头） */
  dublinCoreExt: GoDublinCoreExtension | null = null;
  /** 恒为 null（风险 R3，见文件头） */
  iTunesExt: GoITunesItemExtension | null = null;
  extensions: GoExtensions | null = null;
}

/** Go Feed（Feed 级） */
export class GoFeed {
  title: string | null = null;
  description: string | null = null;
  link: string | null = null;
  feedLink: string | null = null;
  links: string[] | null = null;
  updated: string | null = null;
  updatedParsed: string | null = null;
  published: string | null = null;
  publishedParsed: string | null = null;
  author: GoPerson | null = null;
  authors: (GoPerson | null)[] | null = null;
  language: string | null = null;
  image: GoImage | null = null;
  copyright: string | null = null;
  generator: string | null = null;
  categories: string[] | null = null;
  /** 恒为 null（风险 R3） */
  dublinCoreExt: GoDublinCoreExtension | null = null;
  /** 恒为 null（风险 R3） */
  iTunesExt: GoITunesFeedExtension | null = null;
  extensions: GoExtensions | null = null;
  custom: Map<string, string> | null = null;
  items: (GoItem | null)[] | null = null;
  /** "rss" / "atom" / "json" */
  feedType: string | null = null;
  feedVersion: string | null = null;
}

/** Go omitempty：空串 → null */
export function emptyToNull(s: string | null | undefined): string | null {
  if (s === null || s === undefined || s.length === 0) {
    return null;
  }
  return s;
}

/** Go omitempty：空数组 → null */
export function emptyListToNull<T>(list: T[] | null | undefined): T[] | null {
  if (list === null || list === undefined || list.length === 0) {
    return null;
  }
  return list;
}

/** Go json.Marshal 对 map 键按字节序排序输出 → Moshi/Kotlin LinkedHashMap 迭代顺序即排序后顺序 */
export function sortedKeys<V>(m: Map<string, V>): string[] {
  const keys: string[] = [];
  m.forEach((_v: V, k: string) => {
    keys.push(k);
  });
  keys.sort((a: string, b: string): number => a < b ? -1 : (a > b ? 1 : 0));
  return keys;
}

/** 源 makeGoItem（测试辅助）：全部字段默认 null */
export function makeGoItem(guid: string | null = null, title: string | null = null, content: string | null = null,
  description: string | null = null, link: string | null = null, extensions: GoExtensions | null = null): GoItem {
  const item: GoItem = new GoItem();
  item.guid = guid;
  item.title = title;
  item.content = content;
  item.description = description;
  item.link = link;
  item.extensions = extensions;
  return item;
}
