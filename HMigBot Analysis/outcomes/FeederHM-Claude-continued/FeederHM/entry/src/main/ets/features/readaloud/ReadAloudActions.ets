/**
 * ReadAloudActions.ets —— 源 ArticleViewModel.ttsPlay（:465）/ FeedViewModel.ttsPlay（:582）的朗读入口
 * 以及 ttsPause/ttsStop/ttsSkipNext/ttsOnSelectLanguage（两 VM 同名，直接委托应用级单例）。
 *
 *  - Article（RA-A02）：先停播客；同文章暂停中则恢复；否则取当前文章：
 *    正在显示翻译 → 读翻译后 HTML；否则 readFullText = 全文覆盖值 ?? 该条默认全文 → 全文 blob / 摘要 blob。
 *  - Feed（RA-A03）：先停播客；取当前文章（getCurrentArticle）；同文章暂停中则恢复；
 *    全文/摘要按该条默认全文设置（shouldDisplayFullTextForItemByDefault），不考虑翻译。
 *  - HTML → 段落文本列表（ui/common/HtmlSpeech，RA-A04）；文件缺失/解析失败静默不朗读（源 TODO，RA-A05）。
 */
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { FeedItemWithFeed } from '../../core/model/FeedItem';
import { ID_UNSET } from '../../core/model/Enums';
import { Repository } from '../../core/repo/Repository';
import { FilePathProvider, blobFilePath, blobFullFilePath } from '../../core/util/Constants';
import { readGzipTextFile } from '../../core/html/FullTextParser';
import { annotatedParagraphTexts, htmlToAnnotatedString } from '../../ui/common/HtmlSpeech';
import { PodcastPlayerStateHolder } from './PodcastPlayer';
import { LocaleOverride, TTSStateHolder } from './ReadAloudStateHolder';

const LOG_TAG: string = 'FEEDER_TTS';

/** 源 TSSError（TTSFileNotFound / TTSUnknownError）——仅记录，不提示用户（源 TODO） */
class TtsFileNotFound extends Error {
  constructor(path: string) {
    super(`TTS file not found: ${path}`);
    this.name = 'TTSFileNotFound';
  }
}

/** Article 页朗读请求（源 ArticleViewModel 内部状态的快照） */
export class ArticleTtsRequest {
  /** 源 itemId（导航参数中的文章 id） */
  itemId: number = ID_UNSET;
  /** 源 displayFullTextOverride（null = 未覆盖） */
  displayFullTextOverride: boolean | null = null;
  /** 源 showTranslatedContent */
  showTranslatedContent: boolean = false;
  /** 源 loadTranslatedArticle(article, readFullText).translatedHtml（由翻译单元/Article 页提供） */
  loadTranslatedHtml: ((item: FeedItemWithFeed, readFullText: boolean) => Promise<string>) | null = null;
}

/** HTML 文本 → 朗读段落（源 htmlToAnnotatedString(inputStream, baseUrl = feedUrl)） */
export function speechParagraphsFromHtml(html: string, baseUrl: string): string[] {
  return annotatedParagraphTexts(htmlToAnnotatedString(html, baseUrl));
}

/** 源 blobInputStream / blobFullInputStream + htmlToAnnotatedString；文件缺失抛 TTSFileNotFound */
export async function loadArticleSpeechText(item: FeedItemWithFeed, readFullText: boolean): Promise<string[]> {
  const paths: FilePathProvider | null = AppBootstrap.filePaths();
  if (paths === null) {
    throw new TtsFileNotFound('<no file paths>');
  }
  const path: string = readFullText ? blobFullFilePath(item.id, paths.fullArticleDir) :
    blobFilePath(item.id, paths.articleDir);
  const html: string | null = await readGzipTextFile(path);
  if (html === null) {
    throw new TtsFileNotFound(path);
  }
  return speechParagraphsFromHtml(html, item.feedUrl);
}

async function articleTtsPlayAsync(req: ArticleTtsRequest): Promise<void> {
  const feedItem: FeedItemWithFeed | null = await Repository.instance().getCurrentArticle();
  if (feedItem === null) {
    return;
  }
  const override: boolean | null = req.displayFullTextOverride;
  const readFullText: boolean = override !== null ? override : feedItem.fullTextByDefault;
  let textToRead: string[];
  try {
    const loader: ((item: FeedItemWithFeed, readFullText: boolean) => Promise<string>) | null = req.loadTranslatedHtml;
    if (req.showTranslatedContent && loader !== null) {
      const translatedHtml: string = await loader(feedItem, readFullText);
      textToRead = speechParagraphsFromHtml(translatedHtml, feedItem.feedUrl);
    } else {
      textToRead = await loadArticleSpeechText(feedItem, readFullText);
    }
  } catch (e) {
    // TODO show error some message（源同样静默）
    console.warn(LOG_TAG, `read aloud text unavailable: ${(e as Error)?.message}`);
    return;
  }
  TTSStateHolder.instance().tts(textToRead, Repository.instance().useDetectLanguage, req.itemId);
}

async function feedTtsPlayAsync(): Promise<void> {
  const article: FeedItemWithFeed | null = await Repository.instance().getCurrentArticle();
  if (article === null) {
    return;
  }
  if (TTSStateHolder.instance().resumeIfPausedOn(article.id)) {
    return;
  }
  const isFullText: boolean = await Repository.instance().shouldDisplayFullTextForItemByDefault(article.id);
  let textToRead: string[];
  try {
    textToRead = await loadArticleSpeechText(article, isFullText);
  } catch (e) {
    // TODO show error some message（源同样静默）
    console.warn(LOG_TAG, `read aloud text unavailable: ${(e as Error)?.message}`);
    return;
  }
  TTSStateHolder.instance().tts(textToRead, Repository.instance().useDetectLanguage, article.id);
}

export class ReadAloudActions {
  /** 源 ArticleViewModel.ttsPlay()（顶栏菜单 Read aloud / 朗读栏 Play，RA-A01/A02/A09/A10/A27） */
  static articleTtsPlay(req: ArticleTtsRequest): void {
    PodcastPlayerStateHolder.instance().stop();
    if (TTSStateHolder.instance().resumeIfPausedOn(req.itemId)) {
      return;
    }
    articleTtsPlayAsync(req).catch((e: Error) => {
      console.error(LOG_TAG, `articleTtsPlay failed: ${e?.message}`);
    });
  }

  /** 源 FeedViewModel.ttsPlay()（Feed 底栏 Play，RA-A03） */
  static feedTtsPlay(): void {
    PodcastPlayerStateHolder.instance().stop();
    feedTtsPlayAsync().catch((e: Error) => {
      console.error(LOG_TAG, `feedTtsPlay failed: ${e?.message}`);
    });
  }

  static ttsPause(): void {
    TTSStateHolder.instance().pause();
  }

  static ttsStop(): void {
    TTSStateHolder.instance().stop();
  }

  static ttsSkipNext(): void {
    TTSStateHolder.instance().skipNext();
  }

  static ttsOnSelectLanguage(lang: LocaleOverride): void {
    TTSStateHolder.instance().setLanguage(lang);
  }
}
