/**
 * ArticleLinks.ets —— 源 ArticleScreen.kt 正文链接路由（:719-745）+ PodcastPlayerLinks.kt（shouldOpenInPodcastPlayer）
 * 的鸿蒙实现（由 RichText.ets 按单文件 ≤600 行拆出）。
 *
 * - index 非空且该块位置已知 → 动画滚动到块位置（不打开外部应用，HU-A29）；
 * - 否则启用应用内音频播放器且链接为本文 audio/* 附件或音频扩展名 → 应用内播放器（HU-A30）；
 * - 否则 ActivityLauncher.openLink：空白或 '#' 开头不做事、mailto → 邮件客户端、按设置自定义标签页/默认浏览器、
 *   无可处理应用 → Toast no_activity_for_link（HU-A31/A32，由 core/platform/LinkOpener 实现）。
 * - 修正源已知问题：位置按"文章容器在滚动内容中的偏移 + 块在文章容器内的偏移"登记（内容坐标），
 *   不受上方翻译进度/AI 摘要块与当前滚动位置影响（源以 offsetCounter+index 存 positionInRoot().y，会错位）。
 */
import { openLink } from '../../core/platform/LinkOpener';
import { FeederTheme } from './Theme';

// =============================================================================================
// 正文链接路由（源 ArticleScreen.kt:719-745 + PodcastPlayerLinks.kt）
// =============================================================================================

const AUDIO_FILE_EXTENSIONS: Set<string> = new Set<string>([
  'aac', 'flac', 'm4a', 'm4b', 'mp3', 'mp4', 'oga', 'ogg', 'opus', 'wav', 'weba'
]);

function substringBefore(s: string, delim: string): string {
  const i: number = s.indexOf(delim);
  return i < 0 ? s : s.substring(0, i);
}

function substringAfterLast(s: string, delim: string, missing: string): string {
  const i: number = s.lastIndexOf(delim);
  return i < 0 ? missing : s.substring(i + 1);
}

function lastPathSegment(link: string): string {
  return substringAfterLast(substringBefore(substringBefore(link, '#'), '?'), '/', '');
}

/**
 * 源 shouldOpenInPodcastPlayer(link, enclosure)：空白或 '#' 开头 → false；等于附件链接且附件 audio/* → true；
 * 否则末段扩展名为音频扩展名 → true。
 */
export function shouldOpenInPodcastPlayer(link: string, enclosureLink: string, enclosureType: string): boolean {
  if (link.trim().length === 0 || link.startsWith('#')) {
    return false;
  }
  if (link === enclosureLink && enclosureType.startsWith('audio/')) {
    return true;
  }
  const path: string = lastPathSegment(link).toLowerCase();
  const extension: string = substringAfterLast(path, '.', '');
  return AUDIO_FILE_EXTENSIONS.has(extension);
}

/**
 * 页内锚点位置表 + 滚动（源 elementPositions + articleScrollState.animateScrollTo）。
 * 位置 = 文章容器在滚动内容中的偏移（setArticleTop）+ 元素在文章容器内的偏移（setElementPosition）。
 */
export class ArticleAnchors {
  readonly scroller: Scroller;
  private positions: Map<number, number> = new Map<number, number>();
  private articleTop: number = 0;

  constructor(scroller: Scroller) {
    this.scroller = scroller;
  }

  setArticleTop(y: number): void {
    this.articleTop = y;
  }

  setElementPosition(index: number, y: number): void {
    this.positions.set(index, y);
  }

  reset(): void {
    this.positions.clear();
  }

  has(index: number): boolean {
    return this.positions.has(index);
  }

  /** 内容坐标（vp）；未知 → null */
  positionOf(index: number): number | null {
    const y: number | undefined = this.positions.get(index);
    return y === undefined ? null : this.articleTop + y;
  }

  /** 动画滚动到目标块；位置未知返回 false */
  scrollToElement(index: number): boolean {
    const y: number | null = this.positionOf(index);
    if (y === null) {
      return false;
    }
    this.scroller.scrollTo({ xOffset: 0, yOffset: y, animation: true });
    return true;
  }
}

/** 正文链接路由所需上下文（由 Article 页 ViewModel 填） */
export class ArticleLinkOptions {
  useInAppAudioPlayer: boolean = false;
  enclosureLink: string = '';
  enclosureType: string = '';
  /** 打开应用内播放器（源 onOpenAudioPlayer）；null → 视为未启用 */
  onOpenAudioPlayer: ((link: string) => void) | null = null;
}

/** 当前主题 surface 色（ARGB number，源 toolbarColor） */
export function toolbarColorOfTheme(): number {
  let hex: string = FeederTheme.colors.surface;
  hex = hex.startsWith('#') ? hex.substring(1) : hex;
  if (hex.length === 6) {
    hex = 'FF' + hex;
  }
  const n: number = parseInt(hex, 16);
  return isNaN(n) ? 0 : n;
}

export enum ArticleLinkAction {
  SCROLLED = 'SCROLLED',
  AUDIO_PLAYER = 'AUDIO_PLAYER',
  EXTERNAL = 'EXTERNAL'
}

/**
 * 源 ColumnArticleContent onLinkClick（ArticleScreen.kt:720-741）：
 *  index 非空且位置已知 → 动画滚动（不打开外部应用）；
 *  否则启用应用内播放器且 shouldOpenInPodcastPlayer → 播放器；
 *  否则 ActivityLauncher.openLink（空白/'#' 开头不做事；mailto → 邮件；按设置自定义标签页/默认浏览器；无应用 → Toast）。
 */
export function handleArticleLinkClick(link: string, index: number | null, anchors: ArticleAnchors | null,
  opts: ArticleLinkOptions): ArticleLinkAction {
  if (index !== null && anchors !== null && anchors.has(index)) {
    anchors.scrollToElement(index);
    return ArticleLinkAction.SCROLLED;
  }
  const player: ((link: string) => void) | null = opts.onOpenAudioPlayer;
  if (opts.useInAppAudioPlayer && player !== null &&
    shouldOpenInPodcastPlayer(link, opts.enclosureLink, opts.enclosureType)) {
    player(link);
    return ArticleLinkAction.AUDIO_PLAYER;
  }
  openLink(link, toolbarColorOfTheme()).catch((e: Error) => {
    console.error('FEEDER_RICHTEXT: openLink failed: ' + e?.message);
  });
  return ArticleLinkAction.EXTERNAL;
}
