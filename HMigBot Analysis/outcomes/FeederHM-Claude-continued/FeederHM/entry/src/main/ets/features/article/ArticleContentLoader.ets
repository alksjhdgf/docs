/**
 * ArticleContentLoader —— 源 ArticleViewModel.kt 的正文加载/全文抓取/HTML 读取（:330-447、:791-842）、
 * ArticleScreen.kt 的分享（:159-181）与 formatArticleDate（:781-792）。由 ArticleViewModel 拆出（单文件 ≤600 行）。
 *
 *  - parseArticleContent(article, fullText)：摘要模式读 `<articleDir>/<id>.txt.gz` 线性化；读失败 → FAILED_TO_LOAD_FULLTEXT；
 *    blob 不存在 → 触发该源强制网络同步并显示含 snippet 的兜底说明；全文模式无缓存 → FullTextParser 抓取，错误映射
 *    NoBody/NoUrl/NotHTML(UnsupportedContentType)/FullTextTooLarge/其它 → 对应 TextToDisplay（AR-A20/A22）。
 *  - loadArticleHtml / loadArticleHtmlForLanguageDetection：翻译与朗读用的原始 HTML（源同名私有函数）。
 *  - shareArticle：系统分享面板，text/plain，正文 = 去追踪参数链接（无链接则无正文），标题 = 当前显示标题（AR-A14/A15）。
 */
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { JavaTime, ZonedDateTimeValue } from '../../core/model/Feed';
import { FeedItemForFetching } from '../../core/model/FeedItem';
import { Article, RepositoryHooks, TextToDisplay } from '../../core/repo/RepoTypes';
import { Repository } from '../../core/repo/Repository';
import { FeedParserError, FeedParserErrorKind } from '../../core/html/FeedParserError';
import { FullTextParser, readGzipTextFile } from '../../core/html/FullTextParser';
import { HtmlLinearizer } from '../../core/html/HtmlLinearizer';
import { LinearArticle } from '../../core/html/LinearArticle';
import { FilePathProvider, blobFilePath, blobFullFilePath } from '../../core/util/Constants';
import { stripTrackingParameters } from '../../core/util/UrlCleaner';
import { Either } from '../../core/util/Either';
import { isFile } from '../translation/TranslationIo';

const LOG_TAG: string = 'FEEDER_ArticleVM';

/** 同步取资源串（源 application.getString）；无上下文/缺失 → fallback */
export function articleString(name: string, fallback: string): string {
  const ctx: common.UIAbilityContext | null = AppBootstrap.context();
  if (ctx !== null) {
    try {
      return ctx.resourceManager.getStringByNameSync(name);
    } catch (e) {
      console.warn(`${LOG_TAG}: missing string ${name}`);
    }
  }
  return fallback;
}

/** 源 HtmlLinearizer(tooLargeText, openInBrowserText, articleLink) */
export function newArticleLinearizer(articleLink: string | null): HtmlLinearizer {
  return new HtmlLinearizer(
    articleString('failed_to_fetch_full_article_too_large', 'Article is too large. Open in browser instead?'),
    articleString('open_in_web_view', 'Open in Web view'),
    articleLink !== null ? articleLink : ''
  );
}

function filePaths(): FilePathProvider {
  const paths: FilePathProvider | null = AppBootstrap.filePaths();
  if (paths === null) {
    throw new Error('File paths unavailable');
  }
  return paths;
}

/** 源 readArticleBlobIfPresent */
export async function readArticleBlobIfPresent(itemId: number): Promise<string | null> {
  return await readGzipTextFile(blobFilePath(itemId, filePaths().articleDir));
}

/** 源 readFullArticleBlobIfPresent */
export async function readFullArticleBlobIfPresent(itemId: number): Promise<string | null> {
  return await readGzipTextFile(blobFullFilePath(itemId, filePaths().fullArticleDir));
}

class FetchItem implements FeedItemForFetching {
  id: number = 0;
  link: string | null = null;
}

/** 源 retrieveFullText(itemId)：全文缓存已在 → 成功；否则按 getLink 抓取。返回错误或 null（成功） */
export async function retrieveFullText(itemId: number): Promise<FeedParserError | null> {
  const paths: FilePathProvider = filePaths();
  if (isFile(blobFullFilePath(itemId, paths.fullArticleDir))) {
    return null;
  }
  const item: FetchItem = new FetchItem();
  item.id = itemId;
  item.link = await Repository.instance().getLink(itemId);
  const r: Either<FeedParserError, boolean> = await FullTextParser.instance(paths).parseFullArticleIfMissing(item);
  return r.leftOrNull();
}

/** 源 parseArticleContent 全文分支的错误映射（AR-A20） */
export function textToDisplayForError(error: FeedParserError): TextToDisplay {
  switch (error.kind) {
    case FeedParserErrorKind.NO_BODY:
      return TextToDisplay.FAILED_MISSING_BODY;
    case FeedParserErrorKind.NO_URL:
      return TextToDisplay.FAILED_MISSING_LINK;
    case FeedParserErrorKind.UNSUPPORTED_CONTENT_TYPE:
      return TextToDisplay.FAILED_NOT_HTML;
    case FeedParserErrorKind.NOT_HTML:
      return TextToDisplay.FAILED_NOT_HTML;
    case FeedParserErrorKind.FULL_TEXT_TOO_LARGE:
      return TextToDisplay.FAILED_FULLTEXT_TOO_LARGE;
    default:
      return TextToDisplay.FAILED_TO_LOAD_FULLTEXT;
  }
}

/** parseArticleContent 结果：textToDisplay 为 null 表示保持当前值（源未调用 textToDisplay.update 的分支） */
export class ParsedArticleContent {
  content: LinearArticle = new LinearArticle([]);
  textToDisplay: TextToDisplay | null = null;

  static of(content: LinearArticle, textToDisplay: TextToDisplay | null): ParsedArticleContent {
    const r: ParsedArticleContent = new ParsedArticleContent();
    r.content = content;
    r.textToDisplay = textToDisplay;
    return r;
  }
}

/** 源硬编码兜底文案（ArticleViewModel.kt:372-378），后接 snippet */
const MISSING_BLOB_TEXT: string = 'Sorry, due to a coding oversight, ' +
  'the full offline version of this article has been permanently deleted, ' +
  'see <a href="https://github.com/spacecowboy/Feeder/issues/443">feeder#443</a> ' +
  'for updates on this issue<br/><br/>';

/** 源 parseArticleContent(article, fullText)（AR-A20/A22） */
export async function parseArticleContent(article: Article, fullText: boolean): Promise<ParsedArticleContent> {
  const empty: LinearArticle = new LinearArticle([]);
  try {
    const paths: FilePathProvider = filePaths();
    const linearizer: HtmlLinearizer = newArticleLinearizer(article.link);
    const baseUrl: string = article.feedUrl !== null ? article.feedUrl : '';
    if (!fullText) {
      const blob: string = blobFilePath(article.id, paths.articleDir);
      if (isFile(blob)) {
        try {
          const html: string | null = await readGzipTextFile(blob);
          if (html === null) {
            throw new Error(`Could not open blob ${blob}`);
          }
          return ParsedArticleContent.of(linearizer.linearize(html, baseUrl), TextToDisplay.CONTENT);
        } catch (e) {
          console.error(`${LOG_TAG}: Could not open blob: ${(e as Error)?.message}`);
          return ParsedArticleContent.of(empty, TextToDisplay.FAILED_TO_LOAD_FULLTEXT);
        }
      }
      console.error(`${LOG_TAG}: No default file to parse. Attempting to fetch feed again`);
      // Should not happen but keeping this as a fallback
      RepositoryHooks.runOnceRssSync(article.feedId, '', true, true);
      return ParsedArticleContent.of(linearizer.linearize(MISSING_BLOB_TEXT + article.snippet, baseUrl),
        TextToDisplay.CONTENT);
    }
    const fullBlob: string = blobFullFilePath(article.id, paths.fullArticleDir);
    let errorText: TextToDisplay | null = null;
    if (!isFile(fullBlob)) {
      // If the fulltext file is missing, try to fetch it
      const error: FeedParserError | null = await retrieveFullText(article.id);
      if (error !== null) {
        errorText = textToDisplayForError(error);
      }
    }
    if (isFile(fullBlob)) {
      try {
        const html: string | null = await readGzipTextFile(fullBlob);
        if (html === null) {
          throw new Error(`Could not open blob ${fullBlob}`);
        }
        return ParsedArticleContent.of(linearizer.linearize(html, baseUrl), TextToDisplay.CONTENT);
      } catch (e) {
        console.error(`${LOG_TAG}: Could not open blob: ${(e as Error)?.message}`);
        return ParsedArticleContent.of(empty, TextToDisplay.FAILED_TO_LOAD_FULLTEXT);
      }
    }
    // Error text should already be set above
    return ParsedArticleContent.of(empty, errorText);
  } catch (t) {
    console.error(`${LOG_TAG}: Error parsing article: ${(t as Error)?.message}`);
    return ParsedArticleContent.of(empty, null);
  }
}

/** 源 loadArticleHtml(article, fullText)：摘要 → blob ?: snippet；全文 → 缓存或抓取，失败抛错 */
export async function loadArticleHtml(itemId: number, snippet: string, fullText: boolean): Promise<string> {
  if (!fullText) {
    const html: string | null = await readArticleBlobIfPresent(itemId);
    return html !== null ? html : snippet;
  }
  const cached: string | null = await readFullArticleBlobIfPresent(itemId);
  if (cached !== null) {
    return cached;
  }
  const error: FeedParserError | null = await retrieveFullText(itemId);
  if (error !== null) {
    throw new Error(`Cannot load article: ${error.description}`);
  }
  const html: string | null = await readFullArticleBlobIfPresent(itemId);
  if (html === null) {
    throw new Error('Cannot load article');
  }
  return html;
}

/** 源 loadArticleHtmlForLanguageDetection：不触发下载；无则 null */
export async function loadArticleHtmlForLanguageDetection(itemId: number, snippet: string,
  fullText: boolean): Promise<string | null> {
  if (!fullText) {
    const html: string | null = await readArticleBlobIfPresent(itemId);
    if (html !== null) {
      return html;
    }
    return snippet.trim().length > 0 ? snippet : null;
  }
  return await readFullArticleBlobIfPresent(itemId);
}

// ============================================================ 日期（源 formatArticleDate，AR-A27）

function systemLocale(): string {
  try {
    return i18n.System.getSystemLocale();
  } catch (e) {
    return 'en-US';
  }
}

function systemIs24Hour(): boolean {
  try {
    return i18n.System.is24HourClock();
  } catch (e) {
    return true;
  }
}

/**
 * 源 formatArticleDate：skeleton 24h `yMMMMEEEEdHm` / 12h `yMMMMEEEEdhm`，当前语言区域 best pattern，系统时区。
 * pubDate 为 null 或不可解析 → null（源 ZonedDateTime? 为 null，整行不显示）。
 */
export function formatArticleDate(pubDate: string | null): string | null {
  const z: ZonedDateTimeValue | null = JavaTime.parseZoned(pubDate);
  if (z === null) {
    return null;
  }
  const is24: boolean = systemIs24Hour();
  let opts: Intl.DateTimeFormatOptions;
  if (is24) {
    opts = {
      weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
      hourCycle: 'h23'
    };
  } else {
    opts = {
      weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit',
      hourCycle: 'h12'
    };
  }
  const d: Date = new Date(z.epochMs);
  try {
    return new Intl.DateTimeFormat(systemLocale(), opts).format(d);
  } catch (e) {
    try {
      return new Intl.DateTimeFormat('en-US', opts).format(d);
    } catch (e2) {
      return d.toLocaleString();
    }
  }
}

// ============================================================ 分享（AR-A14/A16）

/** 源 Intent.createChooser(ACTION_SEND text/plain, EXTRA_TEXT = stripTrackingParameters(link), EXTRA_TITLE = title) */
export async function shareArticle(ui: UIContext, link: string | null, title: string): Promise<void> {
  try {
    const record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
      title: title
    };
    if (link !== null) {
      record.content = stripTrackingParameters(link);
    }
    const data: systemShare.SharedData = new systemShare.SharedData(record);
    const controller: systemShare.ShareController = new systemShare.ShareController(data);
    const ctx: common.UIAbilityContext = ui.getHostContext() as common.UIAbilityContext;
    const options: systemShare.ShareControllerOptions = {};
    await controller.show(ctx, options);
  } catch (e) {
    console.error(`${LOG_TAG}: share failed: ${JSON.stringify(e)}`);
  }
}
