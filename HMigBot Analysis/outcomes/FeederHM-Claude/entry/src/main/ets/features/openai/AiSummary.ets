/*
 * AiSummary — 文章页 AI 摘要：状态、请求组装入口与摘要卡。
 * 源：ui/compose/feedarticle/ArticleViewModel.kt（showSummarize :226、自动摘要 :256、summarize() :583-604、
 *     convertSummaryToAnnotatedStrings :737、loadArticleContent :753）、ArticleScreen.kt（菜单 :362、SummarySection :807）。
 *
 * page-article 接线：
 *   - 菜单 `Summarize`：仅 `showSummarize(Repository.instance().openAISettings, article.link)` 为真时出现（AI-A44），
 *     点击 → `controller.summarize(articleId, articleLink, feedUrl)`。
 *   - 打开文章（每篇仅一次）：`controller.summarizeOnOpenIfEnabled(feedId, articleId, articleLink, feedUrl)`（AI-A47）。
 *   - 正文前：`if (controller.state.phase !== SummaryPhase.Empty) { SummarySection({ summary: controller.state }) }`（AI-A45）。
 */
import { OpenAISettings } from '../../core/settings/SettingsModels';
import { Repository } from '../../core/repo/Repository';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { Feed } from '../../core/model/Feed';
import { FeedItemForFetching } from '../../core/model/FeedItem';
import { FilePathProvider, blobFullFilePath } from '../../core/util/Constants';
import { FullTextParser, readGzipTextFile } from '../../core/html/FullTextParser';
import { parseHtml } from '../../core/html/HtmlParser';
import { HtmlNode } from '../../core/html/HtmlNode';
import { MarkdownToHtmlConverter } from '../../core/html/MarkdownToHtml';
import { AnnotatedParagraph, htmlToAnnotatedString } from '../../ui/common/HtmlSpeech';
import { AnnotatedParagraphList } from '../../ui/common/RichText';
import { FeederTheme } from '../../ui/common/Theme';
import { isFile } from '../translation/TranslationIo';
import { canSummarize, OpenAIApi, SummaryResult } from './OpenAIApi';

const LOG_TAG: string = 'FEEDER_AI_SUMMARY';

/** 源 sealed OpenAISummaryState */
export enum SummaryPhase {
  Empty = 'Empty',
  Loading = 'Loading',
  Result = 'Result'
}

@ObservedV2
export class OpenAISummaryState {
  @Trace phase: SummaryPhase = SummaryPhase.Empty;
  /** Result.value */
  @Trace result: SummaryResult | null = null;
  /** Result.annotatedStrings */
  @Trace paragraphs: AnnotatedParagraph[] = [];
}

/** AI-A44：showSummarize = summarySettings.canSummarize && !article.link.isNullOrEmpty() */
export function showSummarize(summarySettings: OpenAISettings, articleLink: string | null): boolean {
  return canSummarize(summarySettings) && articleLink !== null && articleLink.length > 0;
}

/** 源 convertSummaryToAnnotatedStrings：成功 → Markdown→HTML→段落；错误 → 原文单段 */
export function convertSummaryToParagraphs(result: SummaryResult): AnnotatedParagraph[] {
  if (result.isSuccess) {
    const html = new MarkdownToHtmlConverter().convertToHtml(result.content);
    return htmlToAnnotatedString(html, '');
  }
  return [new AnnotatedParagraph(result.content, [], [])];
}

class FetchItem implements FeedItemForFetching {
  id: number = 0;
  link: string | null = null;
}

/** AI-A46：源 loadArticleContent —— 全文缓存存在读缓存，否则抓全文；取 body 纯文本（不截断） */
export async function loadArticleContentForSummary(articleId: number, articleLink: string | null,
  feedUrl: string | null): Promise<string> {
  const paths: FilePathProvider | null = AppBootstrap.filePaths();
  if (paths === null) {
    throw new Error('Cannot load article: file paths unavailable');
  }
  const blobFile = blobFullFilePath(articleId, paths.fullArticleDir);
  if (!isFile(blobFile)) {
    const item = new FetchItem();
    item.id = articleId;
    item.link = articleLink;
    const r = await FullTextParser.instance(paths).parseFullArticleIfMissing(item);
    const error = r.leftOrNull();
    if (error !== null) {
      throw new Error(`Cannot load article: ${error.description}`);
    }
  }
  const html: string | null = await readGzipTextFile(blobFile);
  if (html === null) {
    throw new Error(`Cannot load article: ${blobFile}`);
  }
  const body: HtmlNode | null = parseHtml(html, feedUrl !== null ? feedUrl : '').body();
  return body !== null ? body.text() : '';
}

/** 源 ArticleViewModel 摘要部分（每个文章页一个实例） */
export class AiSummaryController {
  readonly state: OpenAISummaryState = new OpenAISummaryState();
  private handledInitialOpen: boolean = false;
  private generation: number = 0;

  /** 源 summarize()：Loading → Result（任何异常转 Error 结果） */
  async summarize(articleId: number, articleLink: string | null, feedUrl: string | null): Promise<void> {
    const gen = ++this.generation;
    this.state.phase = SummaryPhase.Loading;
    this.state.result = null;
    this.state.paragraphs = [];
    let result: SummaryResult;
    try {
      const content = await loadArticleContentForSummary(articleId, articleLink, feedUrl);
      result = await OpenAIApi.instance().summarize(content, Repository.instance().openAISettings);
    } catch (e) {
      const msg = e instanceof Error ? (e as Error).message : '';
      result = SummaryResult.error(msg !== undefined && msg !== null && msg.length > 0 ? msg : 'Unknown error');
    }
    let paragraphs: AnnotatedParagraph[];
    try {
      paragraphs = convertSummaryToParagraphs(result);
    } catch (e) {
      console.warn(LOG_TAG, `summary conversion failed: ${(e as Error)?.message}`);
      paragraphs = [new AnnotatedParagraph(result.content, [], [])];
    }
    if (gen !== this.generation) {
      return;
    }
    this.state.result = result;
    this.state.paragraphs = paragraphs;
    this.state.phase = SummaryPhase.Result;
  }

  /** AI-A47：feed.summarizeOnOpen && canSummarize → 打开文章自动摘要（仅首次） */
  async summarizeOnOpenIfEnabled(feedId: number, articleId: number, articleLink: string | null,
    feedUrl: string | null): Promise<void> {
    if (this.handledInitialOpen) {
      return;
    }
    this.handledInitialOpen = true;
    const feed: Feed | null = await Repository.instance().getFeed(feedId);
    if (feed !== null && feed.summarizeOnOpen && canSummarize(Repository.instance().openAISettings)) {
      await this.summarize(articleId, articleLink, feedUrl);
    }
  }

  /** 切换文章时复位（源 VM 随文章重建） */
  reset(): void {
    this.generation++;
    this.handledInitialOpen = false;
    this.state.phase = SummaryPhase.Empty;
    this.state.result = null;
    this.state.paragraphs = [];
  }
}

/** 源 M3 LinearProgressIndicator()（不定进度）：4vp 轨道 + 往复滑动的指示条 */
@ComponentV2
struct IndeterminateLinearProgress {
  @Local barX: string = '-100%';

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('40%')
        .height(4)
        .borderRadius(2)
        .backgroundColor(FeederTheme.colors.primary)
        .translate({ x: this.barX })
    }
    .width('100%')
    .height(4)
    .borderRadius(2)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .clip(true)
    .onAppear(() => {
      this.getUIContext().animateTo({ duration: 1500, iterations: -1, curve: Curve.EaseInOut }, () => {
        this.barX = '250%';
      });
    })
  }
}

/** AI-A45：源 SummarySection —— OutlinedCard；Loading 线性进度条（padding 16）；Result 段落富文本 */
@ComponentV2
export struct SummarySection {
  @Param summary: OpenAISummaryState = new OpenAISummaryState();

  build() {
    Column() {
      if (this.summary.phase === SummaryPhase.Loading) {
        Column() {
          IndeterminateLinearProgress()
        }
        .width('100%')
        .padding(16)
      } else if (this.summary.phase === SummaryPhase.Result) {
        AnnotatedParagraphList({ paragraphs: this.summary.paragraphs })
      }
    }
    .width('100%')
    .backgroundColor(FeederTheme.colors.surface)
    .border({ width: 1, color: FeederTheme.colors.outlineVariant, radius: 12 })
    .clip(true)
  }
}
