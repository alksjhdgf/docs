/**
 * ThumbnailSelector.ets —— 源 model/gofeed/GoFeedExtensions.kt 中 FeederGoItem 的缩略图部分：
 * feedThumbnail / bodyThumbnail / thumbnail、recursiveExtensionThumbnailCandidates、pointsToImage、linkToHtml。
 *
 * 选择优先级（照源）：
 *  1. feed 侧候选按序收集：条目 image.url → 扩展树（Go JSON map 键排序后的顺序）中 attrs["url"] 指向图片的元素
 *     （带 width/height）及名为 thumbnail（忽略大小写）的元素值 → type 以 "image/" 开头的 enclosure；
 *     取 width 最大者（无宽度视为 -1，并列取先出现者）。
 *  2. 最终：feed 候选为 EnclosureImage 且 length 为 0 或 > 50000 → 采用；feed 候选 width ≥ 640 → 采用；
 *     否则正文首图（findFirstImageInHtml，以条目链接为基准，无链接用 feed URL）优先，无则 feed 候选。
 */
import { EnclosureImage, ImageFromHTML, MediaImage, ThumbnailImage } from '../model/Thumbnail';
import { JavaUrl } from '../util/JavaCompat';
import { relativeLinkIntoAbsolute, relativeLinkIntoAbsoluteOrNull } from '../util/LinkUtils';
import { findFirstImageInHtml, kotlinToIntOrNull } from '../html/HtmlUtils';
import { GoEnclosure, GoExtension, GoExtensions, GoItem, sortedKeys } from './GoFeed';

const IMAGE_SUFFIXES: string[] = ['.jpg', '.jpeg', '.gif', '.png', '.webp', '.avif'];

/** 源 pointsToImage：java.net.URL(url).path 以图片后缀结尾（忽略大小写，不看 query）；URL 非法为 false */
export function pointsToImage(url: string): boolean {
  try {
    const path: string = JavaUrl.parse(url).path.toLowerCase();
    for (let i = 0; i < IMAGE_SUFFIXES.length; i++) {
      if (path.endsWith(IMAGE_SUFFIXES[i])) {
        return true;
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

/** okhttp3 String.toLongOrDefault：可选符号 + 十进制数字且在 Long 范围内，否则默认值 */
export function toLongOrDefault(s: string, defaultValue: number): number {
  const v: number | null = kotlinToLongOrNull(s);
  return v !== null ? v : defaultValue;
}

/** Kotlin String.toLongOrNull（超出 2^53 精度按 number 近似） */
export function kotlinToLongOrNull(s: string): number | null {
  if (!new RegExp('^[+-]?[0-9]+$').test(s)) {
    return null;
  }
  const big: number = Number(s);
  if (big > 9223372036854775807 || big < -9223372036854775808) {
    return null;
  }
  return big;
}

/** 源 recursiveExtensionThumbnailCandidates */
function recursiveExtensionThumbnailCandidates(extension: GoExtension, baseUrl: JavaUrl, out: ThumbnailImage[]): void {
  if (extension.attrs !== null) {
    const url: string | undefined = extension.attrs.get('url');
    if (url !== undefined && pointsToImage(url)) {
      const h: string | undefined = extension.attrs.get('height');
      const w: string | undefined = extension.attrs.get('width');
      out.push(new MediaImage(relativeLinkIntoAbsolute(baseUrl, url), w !== undefined ? kotlinToIntOrNull(w) : null,
        h !== undefined ? kotlinToIntOrNull(h) : null));
    }
  }
  if (extension.name !== null && extension.name.toLowerCase() === 'thumbnail') {
    const value: string | null = extension.value;
    if (value !== null && pointsToImage(value)) {
      out.push(new MediaImage(relativeLinkIntoAbsolute(baseUrl, value)));
    }
  }
  const children: Map<string, GoExtension[]> | null = extension.children;
  if (children !== null) {
    const keys: string[] = sortedKeys<GoExtension[]>(children);
    for (let i = 0; i < keys.length; i++) {
      const list: GoExtension[] = children.get(keys[i]) as GoExtension[];
      for (let j = 0; j < list.length; j++) {
        recursiveExtensionThumbnailCandidates(list[j], baseUrl, out);
      }
    }
  }
}

/** 遍历 GoExtensions（前缀、元素名均按排序键） */
export function forEachExtension(extensions: GoExtensions | null, action: (e: GoExtension) => void): void {
  if (extensions === null) {
    return;
  }
  const prefixes: string[] = sortedKeys<Map<string, GoExtension[]>>(extensions);
  for (let i = 0; i < prefixes.length; i++) {
    const byName: Map<string, GoExtension[]> = extensions.get(prefixes[i]) as Map<string, GoExtension[]>;
    const names: string[] = sortedKeys<GoExtension[]>(byName);
    for (let j = 0; j < names.length; j++) {
      const list: GoExtension[] = byName.get(names[j]) as GoExtension[];
      for (let k = 0; k < list.length; k++) {
        action(list[k]);
      }
    }
  }
}

/** 源 FeederGoItem.enclosures：filterNotNull */
export function nonNullEnclosures(goItem: GoItem): GoEnclosure[] | null {
  if (goItem.enclosures === null) {
    return null;
  }
  const out: GoEnclosure[] = [];
  for (let i = 0; i < goItem.enclosures.length; i++) {
    const e: GoEnclosure | null = goItem.enclosures[i];
    if (e !== null) {
      out.push(e);
    }
  }
  return out;
}

/** 源 FeederGoItem.feedThumbnail */
export function feedThumbnailOf(goItem: GoItem, feedBaseUrl: JavaUrl): ThumbnailImage | null {
  const candidates: ThumbnailImage[] = [];
  if (goItem.image !== null && goItem.image.url !== null) {
    candidates.push(new MediaImage(relativeLinkIntoAbsolute(feedBaseUrl, goItem.image.url)));
  }
  forEachExtension(goItem.extensions, (e: GoExtension): void => {
    recursiveExtensionThumbnailCandidates(e, feedBaseUrl, candidates);
  });
  const encs: GoEnclosure[] | null = nonNullEnclosures(goItem);
  if (encs !== null) {
    for (let i = 0; i < encs.length; i++) {
      const enc: GoEnclosure = encs[i];
      if (enc.type !== null && enc.type.startsWith('image/') && enc.url !== null) {
        candidates.push(new EnclosureImage(relativeLinkIntoAbsolute(feedBaseUrl, enc.url),
          enc.length !== null ? toLongOrDefault(enc.length, 0) : 0));
      }
    }
  }
  // maxByOrNull { width ?: -1 }：并列取第一个
  let best: ThumbnailImage | null = null;
  let bestWidth: number = 0;
  for (let i = 0; i < candidates.length; i++) {
    const w: number = candidates[i].width !== null ? candidates[i].width as number : -1;
    if (best === null || w > bestWidth) {
      best = candidates[i];
      bestWidth = w;
    }
  }
  return best;
}

/** 源 linkToHtml：link 非 null → relativeLinkIntoAbsoluteOrNull(feedBaseUrl, link) */
export function linkToHtml(feedBaseUrl: JavaUrl, link: string | null): string | null {
  if (link !== null) {
    return relativeLinkIntoAbsoluteOrNull(feedBaseUrl, link);
  }
  return null;
}

/** 源 FeederGoItem.bodyThumbnail：以条目链接（否则 feed URL）为基准取正文首图 */
export function bodyThumbnailOf(content: string, feedBaseUrl: JavaUrl, link: string | null): ImageFromHTML | null {
  const l: string | null = linkToHtml(feedBaseUrl, link);
  const baseUrl: string = l !== null ? l : feedBaseUrl.toString();
  return findFirstImageInHtml(content, baseUrl);
}

/** 源 FeederGoItem.thumbnail 决策 */
export function selectThumbnail(feedThumbnail: ThumbnailImage | null,
  bodyThumbnail: () => ThumbnailImage | null): ThumbnailImage | null {
  if (feedThumbnail instanceof EnclosureImage && (feedThumbnail.length === 0 || feedThumbnail.length > 50000)) {
    // Enclosures don't have width/height, so guessing from length
    return feedThumbnail;
  } else if (feedThumbnail !== null && (feedThumbnail.width !== null ? feedThumbnail.width : 0) >= 640) {
    return feedThumbnail;
  }
  const body: ThumbnailImage | null = bodyThumbnail();
  return body !== null ? body : feedThumbnail;
}
