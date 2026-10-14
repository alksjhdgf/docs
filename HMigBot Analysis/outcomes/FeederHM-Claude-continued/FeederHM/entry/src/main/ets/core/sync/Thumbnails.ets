/**
 * Thumbnails.ets —— 同步期缩略图下载策略（源 RssLocalSync.resolveThumbnailImage + model/ThumbnailImagePolicy.kt）。
 *
 * 优先级（FS-A41/A42）：
 *  1) feed 提供的非正文图（media/enclosure）优先，已有非正文图保留（解析期：ThumbnailImagePolicy.applyParsedEntryImage，
 *     由 FeedItem.updateFromParsedEntry 调用）；
 *  2) 源开启 fetchOgImages、条目有 url、feed 没给图、当前缩略图为空或来自正文时，抓取文章页 <head> 的 og:image；
 *  3) 抓取失败或无 og:image 则保留当前值（正文首图兜底或 null）。
 * 缩略图存储格式（FS-A43：带 `type` 判别的 JSON，ImageFromHTML/EnclosureImage/MediaImage）见 core/model/Thumbnail.ets。
 */
import { ThumbnailImage, ThumbnailImagePolicy, MediaImage } from '../model/Thumbnail';
import { fetchOgImage, OgHttpGet, OgHttpResponse } from '../html/HtmlUtils';
import { HttpClient } from '../net/HttpClient';
import { HttpResponse } from '../net/HttpMessages';

export { ThumbnailImagePolicy };

const LOG_TAG: string = 'FEEDER_RSS_LOCAL_SYNC';

/** og:image 抓取函数（可注入，便于测试） */
export type OgImageFetcher = (url: string) => Promise<ThumbnailImage | null>;

/** 用指定 HttpClient（缺省主客户端）构造 fetchOgImage 所需的 GET（跟随重定向、带请求头） */
export function ogHttpGetFor(client: HttpClient | null = null): OgHttpGet {
  return async (url: string, headers: Map<string, string>): Promise<OgHttpResponse> => {
    const c: HttpClient = client !== null ? client : HttpClient.main();
    const r: HttpResponse = await c.get(url, headers);
    const resp: OgHttpResponse = {
      code: r.code,
      contentType: r.header('content-type'),
      finalUrl: r.finalUrl.length > 0 ? r.finalUrl : url,
      body: r.body !== null ? r.body : new ArrayBuffer(0)
    };
    return resp;
  };
}

/** 源 OkHttpClient.fetchOgImage：非 2xx / IO 失败抛异常，非 HTML → null */
export function defaultOgImageFetcher(client: HttpClient | null = null): OgImageFetcher {
  const get: OgHttpGet = ogHttpGetFor(client);
  return async (url: string): Promise<ThumbnailImage | null> => {
    const img: MediaImage | null = await fetchOgImage(get, url);
    return img;
  };
}

/**
 * 源 RssLocalSync.resolveThumbnailImage：
 * 1) Keep feed-provided thumbnail (media/enclosure/etc) when it's not body-derived.
 * 2) Otherwise try og:image from article <head>.
 * 3) If no og:image found, keep current value (body fallback or null).
 */
export async function resolveThumbnailImage(current: ThumbnailImage | null, articleUrl: string | null,
  hasFeedImage: boolean, fetcher: OgImageFetcher): Promise<ThumbnailImage | null> {
  const trimmed: string | null = articleUrl !== null ? articleUrl.trim() : null;
  if (trimmed === null || trimmed.length === 0) {
    return current;
  }
  if (!ThumbnailImagePolicy.shouldFetchOgImage(current, trimmed, hasFeedImage)) {
    return current;
  }
  let ogImage: ThumbnailImage | null = null;
  try {
    ogImage = await fetcher(trimmed);
  } catch (e) {
    console.debug(LOG_TAG, `Failed to fetch og:image for ${trimmed}: ${(e as Error).message}`);
    ogImage = null;
  }
  return ThumbnailImagePolicy.applyOgImage(current, ogImage);
}
