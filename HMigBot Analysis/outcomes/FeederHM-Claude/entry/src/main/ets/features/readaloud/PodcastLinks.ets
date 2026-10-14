/**
 * PodcastLinks.ets —— 源 ui/compose/feedarticle/PodcastPlayerLinks.kt（链接判定、标题解码）
 * + ArticleViewModel.openPodcastPlayer（:546）+ ArticleScreen.kt 附件点击（:663）/ 正文链接（:731）的播客入口。
 *
 *  - shouldOpenInPodcastPlayer(link, enclosure)（RA-A25）：判定实现在 ui/common/ArticleLinks（唯一实现），此处按源签名包装；
 *  - openPodcastPlayer(link)：空白忽略；先停朗读再播放（TTS 与播客互斥，RA-A27）；
 *  - onEnclosureClick(enclosure, useInAppAudioPlayer)：开关开且判定为音频 → 内置播放器，否则浏览器打开（RA-A26）；
 *  - podcastLinkOptions(enclosure, useInAppAudioPlayer)：正文链接路由上下文（handleArticleLinkClick 用，RA-A26）。
 * 播客只能从 Article 页启动（RA-A28）：Feed 页只通过底栏控制已在播放的播客，不调用本文件入口。
 */
import { Enclosure } from '../../core/repo/RepoTypes';
import { ActivityLauncher } from '../../core/platform/LinkOpener';
import { javaUrlDecode } from '../../core/util/JavaCodec';
import { ArticleLinkOptions, shouldOpenInPodcastPlayer as shouldOpenLinkInPodcastPlayer } from '../../ui/common/ArticleLinks';
import { PodcastPlayerStateHolder } from './PodcastPlayer';
import { TTSStateHolder } from './ReadAloudStateHolder';

const LOG_TAG: string = 'FEEDER_PODCAST';

function substringBefore(s: string, delim: string): string {
  const i: number = s.indexOf(delim);
  return i < 0 ? s : s.substring(0, i);
}

function lastPathSegment(link: string): string {
  const path: string = substringBefore(substringBefore(link, '#'), '?');
  const i: number = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(i + 1);
}

/** 源 shouldOpenInPodcastPlayer(link, enclosure)（PodcastPlayerLinks.kt:21） */
export function shouldOpenInPodcastPlayer(link: string, enclosure: Enclosure): boolean {
  return shouldOpenLinkInPodcastPlayer(link, enclosure.link, enclosure.type);
}

/** 源 audioTitleFromLink(link, fallback = "")：URL 解码最后路径段并 trim；空则 fallback；再空则 link */
export function audioTitleFromLink(link: string, fallback: string = ''): string {
  const segment: string = lastPathSegment(link);
  let decoded: string;
  try {
    decoded = javaUrlDecode(segment);
  } catch (e) {
    decoded = segment;
  }
  decoded = decoded.trim();
  if (decoded.length > 0) {
    return decoded;
  }
  if (fallback.trim().length > 0) {
    return fallback;
  }
  return link;
}

/** 源 ArticleViewModel.openPodcastPlayer(link)：先停朗读，再 playLink（RA-A27/A29） */
export function openPodcastPlayer(link: string): void {
  if (link.trim().length === 0) {
    return;
  }
  TTSStateHolder.instance().stop();
  PodcastPlayerStateHolder.instance().playLink(link);
}

/** 源 ArticleScreen onEnclosureClick（:663） */
export function onEnclosureClick(enclosure: Enclosure, useInAppAudioPlayer: boolean): void {
  if (!enclosure.present) {
    return;
  }
  if (useInAppAudioPlayer && shouldOpenInPodcastPlayer(enclosure.link, enclosure)) {
    openPodcastPlayer(enclosure.link);
    return;
  }
  const launcher: ActivityLauncher | null = ActivityLauncher.instance();
  if (launcher === null) {
    console.warn(LOG_TAG, 'ActivityLauncher not bound');
    return;
  }
  launcher.openLinkInBrowser(enclosure.link).catch((e: Error) => {
    console.error(LOG_TAG, `openLinkInBrowser failed: ${e?.message}`);
  });
}

/**
 * 正文链接路由上下文（源 ColumnArticleContent onLinkClick :731）：
 * 交给 ui/common/ArticleLinks.handleArticleLinkClick —— 开关开且判定为音频 → openPodcastPlayer，否则按链接打开方式外部打开。
 */
export function podcastLinkOptions(enclosure: Enclosure, useInAppAudioPlayer: boolean): ArticleLinkOptions {
  const opts: ArticleLinkOptions = new ArticleLinkOptions();
  opts.useInAppAudioPlayer = useInAppAudioPlayer;
  opts.enclosureLink = enclosure.present ? enclosure.link : '';
  opts.enclosureType = enclosure.present ? enclosure.type : '';
  opts.onOpenAudioPlayer = (link: string) => {
    openPodcastPlayer(link);
  };
  return opts;
}

/** 源 podcastPlay / podcastPause / stopPodcastPlayback / podcastSeekBy / podcastSeekTo（Article/Feed VM 同名） */
export class PodcastControls {
  static play(): void {
    PodcastPlayerStateHolder.instance().play();
  }

  static pause(): void {
    PodcastPlayerStateHolder.instance().pause();
  }

  static stop(): void {
    PodcastPlayerStateHolder.instance().stop();
  }

  /** 快退 10 秒（源 podcastOnSeekBack = podcastSeekBy(-10_000)） */
  static seekBack(): void {
    PodcastPlayerStateHolder.instance().seekBy(-10000);
  }

  /** 快进 10 秒（源 podcastOnSeekForward = podcastSeekBy(10_000)） */
  static seekForward(): void {
    PodcastPlayerStateHolder.instance().seekBy(10000);
  }

  static seekTo(positionMillis: number): void {
    PodcastPlayerStateHolder.instance().seekTo(positionMillis);
  }
}
