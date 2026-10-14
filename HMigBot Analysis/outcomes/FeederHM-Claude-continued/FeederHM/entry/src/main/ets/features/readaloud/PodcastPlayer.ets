/**
 * PodcastPlayer.ets —— 源 model/PodcastPlayerStateHolder.kt（android.media.MediaPlayer 流式播放）的鸿蒙实现：
 * `@kit.MediaKit` AVPlayer。应用级单例（源 FeederApplication:72 applicationCoroutineScope 单例），
 * Article / Feed 两页订阅同一可观察状态（RA-A14）。
 *
 * 行为（照源）：
 *  - playLink(link)：空白忽略；释放旧播放器；状态 = {audioUrl, isVisible, isLoading}；创建并准备播放器（RA-A29）。
 *  - 准备完成：自动开始播放；isLoading/isBuffering=false、isPlaying=true、canSeek=duration>0、durationMillis、
 *    errorMessage=null；启动 500ms 进度轮询（RA-A30）。
 *  - 播放结束：停轮询、isPlaying=false、position=duration，栏保持可见（RA-A32）。
 *  - 缓冲开始/结束 → isBuffering（RA-A36）；错误/创建失败 → errorMessage=audio_playback_failed（RA-A38）。
 *  - seekBy/seekTo：仅 canSeek；目标钳到 [0, duration]（RA-A31）。
 *  - stop()：释放播放器、状态重置为默认（不可见，RA-A33）。
 * 源无播放速度、无标题/封面元数据、无后台服务/通知/音频焦点处理（同样不实现）。
 */
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FeedPageHooks } from '../feed/FeedHooks';
import { PlayerBarCollapseState } from './ReadAloudStateHolder';

const LOG_TAG: string = 'FEEDER_PODCAST';
const PROGRESS_INTERVAL_MS: number = 500;

/** 源 @Immutable data class PodcastPlayerState（@Trace 原地更新） */
@ObservedV2
export class PodcastPlayerState {
  @Trace audioUrl: string = '';
  @Trace isVisible: boolean = false;
  @Trace isLoading: boolean = false;
  @Trace isBuffering: boolean = false;
  @Trace isPlaying: boolean = false;
  @Trace canSeek: boolean = false;
  @Trace durationMillis: number = 0;
  @Trace positionMillis: number = 0;
  /** 源 errorMessage: String?（唯一取值 audio_playback_failed） */
  @Trace errorMessage: Resource | null = null;

  /** 源 `_playerState.value = PodcastPlayerState(...)`：整体重置 */
  resetTo(audioUrl: string, isVisible: boolean, isLoading: boolean): void {
    this.audioUrl = audioUrl;
    this.isVisible = isVisible;
    this.isLoading = isLoading;
    this.isBuffering = false;
    this.isPlaying = false;
    this.canSeek = false;
    this.durationMillis = 0;
    this.positionMillis = 0;
    this.errorMessage = null;
  }
}

function coerceAtLeastZero(v: number): number {
  return isNaN(v) || v < 0 ? 0 : v;
}

function coerceIn(v: number, min: number, max: number): number {
  return Math.min(Math.max(v, min), max);
}

/** 源 formatPodcastDuration（PodcastPlayerBar.kt:206）：`m:ss`，满 1 小时 `h:mm:ss`（RA-A37） */
export function formatPodcastDuration(totalMillis: number): string {
  const totalSeconds: number = Math.max(Math.trunc(totalMillis / 1000), 0);
  const hours: number = Math.trunc(totalSeconds / 3600);
  const minutes: number = Math.trunc((totalSeconds % 3600) / 60);
  const seconds: number = totalSeconds % 60;
  const ss: string = seconds < 10 ? '0' + seconds : String(seconds);
  if (hours > 0) {
    const mm: string = minutes < 10 ? '0' + minutes : String(minutes);
    return `${hours}:${mm}:${ss}`;
  }
  return `${minutes}:${ss}`;
}

export class PodcastPlayerStateHolder {
  private static inst: PodcastPlayerStateHolder | null = null;

  static instance(): PodcastPlayerStateHolder {
    if (PodcastPlayerStateHolder.inst === null) {
      PodcastPlayerStateHolder.inst = new PodcastPlayerStateHolder();
    }
    return PodcastPlayerStateHolder.inst as PodcastPlayerStateHolder;
  }

  /** 源 playerState: StateFlow<PodcastPlayerState> */
  readonly playerState: PodcastPlayerState = new PodcastPlayerState();

  private mediaPlayer: media.AVPlayer | null = null;
  private progressTimer: number = -1;
  /** 每次 playLink/stop 递增；异步创建返回时据此丢弃过期播放器 */
  private generation: number = 0;
  private preparedOnce: boolean = false;

  private constructor() {
  }

  /** 源 playLink（:30） */
  playLink(link: string): void {
    if (link.trim().length === 0) {
      return;
    }
    this.releaseCurrentPlayer();
    this.playerState.resetTo(link, true, true);
    this.publish();
    this.initializePlayer(link);
  }

  /** 源 play()：start + 轮询 + isPlaying=true */
  play(): void {
    const player: media.AVPlayer | null = this.mediaPlayer;
    if (player === null) {
      return;
    }
    player.play().catch((e: BusinessError) => {
      console.warn(LOG_TAG, `play failed: ${e?.code} ${e?.message}`);
    });
    this.startProgressUpdates();
    this.playerState.isPlaying = true;
  }

  /** 源 pause() */
  pause(): void {
    const player: media.AVPlayer | null = this.mediaPlayer;
    if (player !== null && player.state === 'playing') {
      player.pause().catch((e: BusinessError) => {
        console.warn(LOG_TAG, `pause failed: ${e?.code} ${e?.message}`);
      });
    }
    this.stopProgressUpdates();
    this.playerState.isPlaying = false;
  }

  /** 源 stop()：释放并重置为默认状态（isVisible=false） */
  stop(): void {
    this.releaseCurrentPlayer();
    this.playerState.resetTo('', false, false);
    this.publish();
  }

  /** 源 seekBy(deltaMillis)：快退/快进 ±10s（RA-A31） */
  seekBy(deltaMillis: number): void {
    const player: media.AVPlayer | null = this.mediaPlayer;
    if (player === null || !this.playerState.canSeek) {
      return;
    }
    const target: number = coerceIn(player.currentTime + deltaMillis, 0, coerceAtLeastZero(player.duration));
    this.seekPlayer(player, target);
  }

  /** 源 seekTo(positionMillis)：拖动松手跳转（RA-A31/A37） */
  seekTo(positionMillis: number): void {
    const player: media.AVPlayer | null = this.mediaPlayer;
    if (player === null || !this.playerState.canSeek) {
      return;
    }
    const target: number = coerceIn(Math.trunc(positionMillis), 0, coerceAtLeastZero(player.duration));
    this.seekPlayer(player, target);
  }

  /** 源 shutdown() */
  shutdown(): void {
    this.releaseCurrentPlayer();
  }

  private seekPlayer(player: media.AVPlayer, target: number): void {
    try {
      player.seek(target);
    } catch (e) {
      console.warn(LOG_TAG, `seek failed: ${JSON.stringify(e)}`);
    }
    this.playerState.positionMillis = target;
  }

  /** 同步 Feed 页底栏可见性（FeedPageHooks.state.podcastPlayerVisible，RA-A14/A35） */
  private publish(): void {
    FeedPageHooks.state.podcastPlayerVisible = this.playerState.isVisible;
    PlayerBarCollapseState.instance().sync();
  }

  private markFailed(): void {
    this.stopProgressUpdates();
    this.playerState.isLoading = false;
    this.playerState.isBuffering = false;
    this.playerState.isPlaying = false;
    this.playerState.errorMessage = $r('app.string.audio_playback_failed');
  }

  /** 源 initializePlayer：MediaPlayer(CONTENT_TYPE_MUSIC, USAGE_MEDIA) + setDataSource + prepareAsync */
  private initializePlayer(link: string): void {
    const gen: number = this.generation;
    this.preparedOnce = false;
    media.createAVPlayer().then((player: media.AVPlayer) => {
      if (gen !== this.generation) {
        // 期间已 stop / 换链接：丢弃
        player.release().catch((e: BusinessError) => {
          console.warn(LOG_TAG, `release stale failed: ${e?.code}`);
        });
        return;
      }
      this.mediaPlayer = player;
      this.attachListeners(player, gen);
      try {
        // audioRendererInfo 只能在 initialized 态设置（idle 态设置报 5400102 并触发 error 回调），见 stateChange
        player.url = link;
      } catch (e) {
        console.warn(LOG_TAG, `Failed to initialize podcast player: ${JSON.stringify(e)}`);
        this.markFailed();
      }
    }).catch((e: BusinessError) => {
      console.warn(LOG_TAG, `Failed to create podcast player: ${e?.code} ${e?.message}`);
      if (gen === this.generation) {
        this.markFailed();
      }
    });
  }

  private attachListeners(player: media.AVPlayer, gen: number): void {
    player.on('stateChange', (state: media.AVPlayerState, reason: media.StateChangeReason) => {
      if (gen !== this.generation) {
        return;
      }
      if (state === 'initialized') {
        // 源 MediaPlayer(CONTENT_TYPE_MUSIC, USAGE_MEDIA)
        const rendererInfo: audio.AudioRendererInfo = {
          usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
          rendererFlags: 0
        };
        player.audioRendererInfo = rendererInfo;
        player.prepare().catch((e: BusinessError) => {
          console.warn(LOG_TAG, `prepare failed: ${e?.code} ${e?.message}`);
          if (gen === this.generation) {
            this.markFailed();
          }
        });
      } else if (state === 'prepared') {
        if (this.preparedOnce) {
          return;
        }
        this.preparedOnce = true;
        // 源 setOnPreparedListener：自动开始播放
        player.play().catch((e: BusinessError) => {
          console.warn(LOG_TAG, `autoplay failed: ${e?.code} ${e?.message}`);
        });
        const duration: number = player.duration;
        this.playerState.isLoading = false;
        this.playerState.isBuffering = false;
        this.playerState.isPlaying = true;
        this.playerState.canSeek = duration > 0;
        this.playerState.durationMillis = coerceAtLeastZero(duration);
        this.playerState.errorMessage = null;
        this.startProgressUpdates();
      } else if (state === 'completed') {
        // 源 setOnCompletionListener
        this.stopProgressUpdates();
        this.playerState.isPlaying = false;
        this.playerState.isBuffering = false;
        this.playerState.positionMillis = coerceAtLeastZero(player.duration);
      }
    });
    player.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (gen !== this.generation) {
        return;
      }
      if (infoType === media.BufferingInfoType.BUFFERING_START) {
        this.playerState.isBuffering = true;
      } else if (infoType === media.BufferingInfoType.BUFFERING_END) {
        this.playerState.isBuffering = false;
      }
    });
    player.on('durationUpdate', (duration: number) => {
      if (gen !== this.generation || !this.preparedOnce) {
        return;
      }
      this.playerState.durationMillis = coerceAtLeastZero(duration);
    });
    player.on('error', (err: BusinessError) => {
      console.warn(LOG_TAG, `Podcast playback failed: ${err?.code} / ${err?.message}`);
      if (gen !== this.generation) {
        return;
      }
      this.markFailed();
    });
  }

  /** 源 startProgressUpdates：每 500ms 更新 position/duration（RA-A30） */
  private startProgressUpdates(): void {
    this.stopProgressUpdates();
    this.progressTimer = setInterval(() => {
      const player: media.AVPlayer | null = this.mediaPlayer;
      if (player === null) {
        this.stopProgressUpdates();
        return;
      }
      this.playerState.positionMillis = coerceAtLeastZero(player.currentTime);
      this.playerState.durationMillis = coerceAtLeastZero(player.duration);
    }, PROGRESS_INTERVAL_MS);
  }

  private stopProgressUpdates(): void {
    if (this.progressTimer >= 0) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
  }

  /** 源 releaseCurrentPlayer：停轮询、stop、release */
  private releaseCurrentPlayer(): void {
    this.generation++;
    this.stopProgressUpdates();
    const player: media.AVPlayer | null = this.mediaPlayer;
    this.mediaPlayer = null;
    if (player === null) {
      return;
    }
    try {
      player.off('stateChange');
      player.off('bufferingUpdate');
      player.off('durationUpdate');
      player.off('error');
    } catch (e) {
      console.warn(LOG_TAG, `off failed: ${JSON.stringify(e)}`);
    }
    // release() 在任意状态可调用，内部先停止播放
    player.release().catch((e: BusinessError) => {
      console.warn(LOG_TAG, `release failed: ${e?.code} ${e?.message}`);
    });
  }
}
