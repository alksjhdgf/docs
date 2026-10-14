/**
 * FullTextParser.ets —— 源 model/FullTextParser.kt：全文下载 → 字符集 → Readability 抽取 → `<id>.full.html.gz`。
 *
 * - parseFullArticleIfMissing：文件已存在 → Right；否则抓取；Throwable → FullTextDecodingFailure；
 *   finally 一律 markAsFullTextDownloaded（失败也不自动重试）（HM-A38）
 * - 抓取（源 curlAndOnResponse）：网络异常 → FetchError；非 2xx → HttpError（HM-A39）
 * - Content-Length 或实际字节 > 3 MiB → FullTextTooLarge（HM-A40）；Content-Type 缺失/非 text/html → UnsupportedContentType（HM-A41）
 * - 字符集：Content-Type charset → meta（findMetaCharset）→ 统计探测（CharsetDetector，ICU 置信度 > 50）→ UTF-8（HM-A42/A43）
 * - Readability 抽取；有 dir 注入首个 `<html`；结果为 null 不写文件仍 Right（HM-A44）
 * - gzip 写 fullArticleDir/<id>.full.html.gz + 纯文本字数 → word_count_full（HM-A45/A47）
 * - 批量：fulltext_by_default=1 且未下载、未屏蔽的条目串行处理，全部成功才 true（HM-A46）
 * 结果契约：Kotlin Either<FeedParserError, Unit> → Either<FeedParserError, boolean>（Right 恒为 true）。
 */
import { encodeUtf8 } from '../util/TextCodec';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Either, Left, Right } from '../util/Either';
import { FilePathProvider, blobFullFilePath } from '../util/Constants';
import { JavaUrl } from '../util/JavaCompat';
import { HttpClient, HttpClientConfig } from '../net/HttpClient';
import { NetworkIOException } from '../net/NetworkResult';
import { HttpResponse, MediaType } from '../net/HttpMessages';
import { FeedItemDao } from '../db/FeedItemDao';
import { FeedItemForFetching, FeedItemIdWithLink, estimateWordCount } from '../model/FeedItem';
import { HtmlToPlainTextConverter } from './HtmlToPlainText';
import {
  decodeWithCharset, detectCharset, findMetaCharset, isSupportedCharset, parseFullArticle, toJavaCharset
} from './FullTextExtract';
import {
  FeedParserError,
  FetchError,
  FullTextDecodingFailure,
  FullTextTooLarge,
  HttpError,
  NoUrl,
  UnsupportedContentType
} from './FeedParserError';

export {
  decodeWithCharset, detectCharset, findMetaCharset, isSupportedCharset, parseFullArticle, toJavaCharset
} from './FullTextExtract';

const LOG_TAG: string = 'FEEDER_FULLTEXT';

// giving a bit of leeway to allow for inline images and junk like inline CSS and javscript
// but this is way higher than is possible to render if actual HTML. It will be truncated by HtmlLinearizer.
export const MAX_FULL_TEXT_BYTES: number = 3 * 1024 * 1024;
/**
 * HM-A40：源 FullTextParser.kt:93-101 按 8 KiB 块读，缓冲超过 MAX 即停（最多读 MAX + 8 KiB）。
 * 此处以传输层 maxLimit（@ohos.net.http HttpRequestOptions.maxLimit）封顶同一字节数，内存不再随响应无界增长：
 * 超限若报错（2300023 写回调中止 / 2300063 超最大文件）→ FullTextTooLarge；若静默截断，截断长度 > MAX 仍判 FullTextTooLarge。
 */
export const FULL_TEXT_READ_CAP_BYTES: number = MAX_FULL_TEXT_BYTES + 8 * 1024;
const BODY_LIMIT_ERROR_CODES: number[] = [2300023, 2300063];

export class FullTextParser {
  static readonly MAX_FULL_TEXT_BYTES: number = MAX_FULL_TEXT_BYTES;

  private readonly filePathProvider: FilePathProvider;
  private readonly clientOverride: HttpClient | null;
  private static shared: FullTextParser | null = null;

  /**
   * 进程唯一实例（APP-A70）：源 di/NetworkModule.kt:27 `bind<FullTextParser>() with singleton { FullTextParser(di) }`。
   * 首次调用时以 filePathProvider 建实例（应用内 FilePathProvider 恒为同一组目录），其后复用。
   */
  static instance(filePathProvider: FilePathProvider): FullTextParser {
    if (FullTextParser.shared === null) {
      FullTextParser.shared = new FullTextParser(filePathProvider);
    }
    return FullTextParser.shared as FullTextParser;
  }

  /** client 缺省用 HttpClient.main()（源 DI 单例 OkHttpClient） */
  constructor(filePathProvider: FilePathProvider, client: HttpClient | null = null) {
    this.filePathProvider = filePathProvider;
    this.clientOverride = client;
  }

  /** 主客户端（源 DI OkHttpClient）+ 读取上限 FULL_TEXT_READ_CAP_BYTES（HM-A40） */
  private client(): HttpClient {
    if (this.clientOverride !== null) {
      return this.clientOverride;
    }
    const c: HttpClientConfig = HttpClient.main().config.copy();
    c.maxResponseBytes = FULL_TEXT_READ_CAP_BYTES;
    return new HttpClient(c);
  }

  async parseFullArticlesForMissing(): Promise<boolean> {
    console.debug(LOG_TAG, 'Parsing full texts for missing');
    const itemsToSync: FeedItemIdWithLink[] = await FeedItemDao.getFeedsItemsWithDefaultFullTextNeedingDownload();
    let all: boolean = true;
    for (let i = 0; i < itemsToSync.length; i++) {
      const r: Either<FeedParserError, boolean> = await this.parseFullArticleIfMissing(itemsToSync[i]);
      all = all && r.isRight();
    }
    return all;
  }

  async parseFullArticleIfMissing(feedItem: FeedItemForFetching): Promise<Either<FeedParserError, boolean>> {
    const fullArticleFile: string = blobFullFilePath(feedItem.id, this.filePathProvider.fullArticleDir);
    let result: Either<FeedParserError, boolean>;
    try {
      if (isFile(fullArticleFile)) {
        result = new Right<FeedParserError, boolean>(true);
      } else {
        result = await this.parseFullArticle(feedItem);
      }
    } catch (t) {
      result = new Left<FeedParserError, boolean>(
        new FullTextDecodingFailure(feedItem.link !== null ? feedItem.link : '', t as Error) as FeedParserError);
    } finally {
      await FeedItemDao.markAsFullTextDownloaded(feedItem.id);
    }
    result.onLeft((e: FeedParserError) => {
      console.warn(LOG_TAG, 'Failed to parse missing full article: ' + e.toString());
    });
    return result;
  }

  private async parseFullArticle(feedItem: FeedItemForFetching): Promise<Either<FeedParserError, boolean>> {
    console.debug(LOG_TAG, `Fetching full page ${feedItem.link}, ${feedItem.id}`);
    const url: string | null = feedItem.link;
    if (url === null) {
      return new Left<FeedParserError, boolean>(new NoUrl() as FeedParserError);
    }
    // 源 URL(url)：非法抛 MalformedURLException → 上层归为 FullTextDecodingFailure
    JavaUrl.parse(url);

    let response: HttpResponse;
    try {
      response = await this.client().getResponse(url);
    } catch (t) {
      if (t instanceof NetworkIOException && BODY_LIMIT_ERROR_CODES.indexOf((t as NetworkIOException).errorCode) >= 0) {
        console.info(LOG_TAG, `buffer exceeds MAX LIMIT (${MAX_FULL_TEXT_BYTES}) bytes`);
        return new Left<FeedParserError, boolean>(new FullTextTooLarge(url, MAX_FULL_TEXT_BYTES) as FeedParserError);
      }
      return new Left<FeedParserError, boolean>(new FetchError(url, t as Error) as FeedParserError);
    }
    if (!response.isSuccessful()) {
      return new Left<FeedParserError, boolean>(
        new HttpError(url, response.code, response.message, response.retryAfterSeconds()) as FeedParserError);
    }
    try {
      return await this.onResponse(feedItem, url, response);
    } catch (t) {
      return new Left<FeedParserError, boolean>(new FullTextDecodingFailure(url, t as Error) as FeedParserError);
    }
  }

  private async onResponse(feedItem: FeedItemForFetching, url: string,
    response: HttpResponse): Promise<Either<FeedParserError, boolean>> {
    const contentLength: number = contentLengthOf(response);
    if (contentLength > MAX_FULL_TEXT_BYTES) {
      console.info(LOG_TAG, `contentLength exceeds MAX LIMIT (${MAX_FULL_TEXT_BYTES}) bytes`);
      return new Left<FeedParserError, boolean>(new FullTextTooLarge(url, MAX_FULL_TEXT_BYTES) as FeedParserError);
    }
    const bytes: Uint8Array = response.bytes();
    if (bytes.length > MAX_FULL_TEXT_BYTES) {
      console.info(LOG_TAG, `buffer exceeds MAX LIMIT (${MAX_FULL_TEXT_BYTES}) bytes`);
      return new Left<FeedParserError, boolean>(new FullTextTooLarge(url, MAX_FULL_TEXT_BYTES) as FeedParserError);
    }

    const contentType: MediaType | null = response.contentType();
    if (contentType === null) {
      return new Left<FeedParserError, boolean>(new UnsupportedContentType(url, 'null') as FeedParserError);
    }
    if (contentType.type !== 'text' || contentType.subtype !== 'html') {
      return new Left<FeedParserError, boolean>(
        new UnsupportedContentType(url, contentType.toString()) as FeedParserError);
    }

    // OkHttp MediaType.charset()：不支持的字符集名视为 null
    let charset: string | null = contentType.charset !== null && isSupportedCharset(contentType.charset) ?
    contentType.charset : null;
    if (charset === null) {
      const meta: string | null = findMetaCharset(bytes);
      // 源 Charset.forName：不支持/非法名抛错 → FullTextDecodingFailure
      charset = meta !== null ? toJavaCharset(meta) : null;
      console.debug(LOG_TAG, `No charset in content type, meta charset: ${charset}`);
    }
    if (charset === null) {
      const guessed: string | null = detectCharset(bytes);
      charset = guessed !== null ? toJavaCharset(guessed) : null;
      console.debug(LOG_TAG, `No charset in content type, guessing charset: ${charset}`);
    }

    const html: string = decodeWithCharset(bytes, charset !== null ? charset : 'utf-8');
    const article: string | null = parseFullArticle(url, html);

    if (article !== null) {
      const dir: string = this.filePathProvider.fullArticleDir;
      try {
        if (!fs.accessSync(dir)) {
          fs.mkdirSync(dir, true);
        }
        await writeGzipTextFile(blobFullFilePath(feedItem.id, dir), article);
      } catch (t) {
        // 同步 fs 在无权限/只读/空间不足时抛 BusinessError：转成明确的 FullTextDecodingFailure（上层 onLeft 记录并标记）
        const err = t as Error;
        console.error(LOG_TAG, `Failed to write full article for ${feedItem.id} into ${dir}: ${err?.message}`);
        return new Left<FeedParserError, boolean>(
          new FullTextDecodingFailure(url, new Error(`Cannot write full article file: ${err?.message}`)) as FeedParserError);
      }
      // Update word count on item
      const plainText: string = new HtmlToPlainTextConverter().convert(article);
      await FeedItemDao.updateWordCountFull(feedItem.id, estimateWordCount(plainText));
    }
    return new Right<FeedParserError, boolean>(true);
  }
}

// =============================================================================================
// 文件
// =============================================================================================

function isFile(path: string): boolean {
  try {
    return fs.accessSync(path) && fs.statSync(path).isFile();
  } catch (e) {
    return false;
  }
}

function contentLengthOf(response: HttpResponse): number {
  const v: string | null = response.header('content-length');
  if (v === null || !new RegExp('^\\s*\\d+\\s*$').test(v)) {
    return -1;
  }
  return Number(v.trim());
}

/** gzip 写文本（UTF-8）；先写临时文件再改名，避免半截文件被当作"已存在" */
export async function writeGzipTextFile(path: string, text: string): Promise<void> {
  const bytes: Uint8Array = encodeUtf8(text);
  const buf: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  const tmp: string = path + '.tmp';
  const gz: zlib.GZip = zlib.createGZipSync();
  await gz.gzopen(tmp, 'wb');
  try {
    if (buf.byteLength > 0) {
      await gz.gzwrite(buf, buf.byteLength);
    }
  } finally {
    await gz.gzclose();
  }
  await fs.rename(tmp, path);
}

/** 读 gzip 文本文件（UTF-8）；不存在返回 null。供阅读页读取 `<id>.full.html.gz` */
export async function readGzipTextFile(path: string): Promise<string | null> {
  if (!isFile(path)) {
    return null;
  }
  const gz: zlib.GZip = zlib.createGZipSync();
  await gz.gzopen(path, 'rb');
  const chunks: Uint8Array[] = [];
  let total: number = 0;
  try {
    while (true) {
      const buf: ArrayBuffer = new ArrayBuffer(64 * 1024);
      const n: number = await gz.gzread(buf);
      if (n <= 0) {
        break;
      }
      chunks.push(new Uint8Array(buf, 0, n));
      total += n;
    }
  } finally {
    await gz.gzclose();
  }
  const all: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  for (let i = 0; i < chunks.length; i++) {
    all.set(chunks[i], offset);
    offset += chunks[i].length;
  }
  return decodeWithCharset(all, 'utf-8');
}

/** 便捷：全文文件路径（blobFullFile） */
export function fullArticleFilePath(itemId: number, paths: FilePathProvider): string {
  return blobFullFilePath(itemId, paths.fullArticleDir);
}
