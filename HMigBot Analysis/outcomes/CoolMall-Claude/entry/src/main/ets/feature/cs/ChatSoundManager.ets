/**
 * ChatSoundManager (source: feature/cs/util/ChatSoundManager.kt) — CS-A15 / CS-A16.
 *
 * Android SoundPool(maxStreams 2, USAGE_NOTIFICATION / CONTENT_TYPE_SONIFICATION) → @kit.MediaKit SoundPool
 * (createSoundPool(2, STREAM_USAGE_NOTIFICATION)); R.raw.send / R.raw.receive → rawfile send.mp3 / receive.mp3.
 * Playback is enabled once a load completes (source OnLoadCompleteListener status == 0 → isInitialized).
 * play(): volume 1.0/1.0, priority 1, no loop, normal rate. release() frees the pool and both raw fds.
 */
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { resourceManager } from '@kit.LocalizationKit';
import { LogUtils } from '../../core/util/LogUtils';

const TAG: string = 'ChatSoundManager';
const SEND_RAW: string = 'send.mp3';
const RECEIVE_RAW: string = 'receive.mp3';

export class ChatSoundManager {
  private soundPool: media.SoundPool | null = null;
  private sendSoundId: number = 0;
  private receiveSoundId: number = 0;
  private isInitialized: boolean = false;
  private released: boolean = false;
  private resMgr: resourceManager.ResourceManager | null = null;
  private openedFds: string[] = [];

  constructor(context: common.Context | undefined) {
    this.initSoundPool(context);
  }

  private async initSoundPool(context: common.Context | undefined): Promise<void> {
    if (context === undefined) {
      LogUtils.eTag(TAG, 'no context, sounds disabled');
      return;
    }
    try {
      const rendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_NOTIFICATION,
        rendererFlags: 0
      };
      const pool: media.SoundPool = await media.createSoundPool(2, rendererInfo);
      if (this.released) {
        pool.release();
        return;
      }
      this.soundPool = pool;
      pool.on('loadComplete', (soundId: number) => {
        LogUtils.dTag(TAG, `sound loaded: ${soundId}`);
        this.isInitialized = true;
      });
      this.resMgr = context.resourceManager;
      this.sendSoundId = await this.loadRaw(pool, SEND_RAW);
      this.receiveSoundId = await this.loadRaw(pool, RECEIVE_RAW);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      LogUtils.eTag(TAG, `init sound pool failed: ${err.code} ${err.message}`);
    }
  }

  private async loadRaw(pool: media.SoundPool, name: string): Promise<number> {
    if (this.resMgr === null || this.released) {
      return 0;
    }
    const fd: resourceManager.RawFileDescriptor = await this.resMgr.getRawFd(name);
    this.openedFds.push(name);
    return await pool.load(fd.fd, fd.offset, fd.length);
  }

  private play(soundId: number): void {
    const pool: media.SoundPool | null = this.soundPool;
    if (!this.isInitialized || soundId === 0 || pool === null) {
      return;
    }
    const params: media.PlayParameters = {
      loop: 0,
      rate: audio.AudioRendererRate.RENDER_RATE_NORMAL,
      leftVolume: 1.0,
      rightVolume: 1.0,
      priority: 1
    };
    pool.play(soundId, params).catch((e: BusinessError) => {
      LogUtils.eTag(TAG, `play failed: ${e.code} ${e.message}`);
    });
  }

  /** Message sent sound */
  playMessageSentSound(): void {
    this.play(this.sendSoundId);
  }

  /** Agent reply received sound */
  playMessageReceivedSound(): void {
    this.play(this.receiveSoundId);
  }

  /** Release the pool and the raw file descriptors */
  release(): void {
    this.released = true;
    const pool: media.SoundPool | null = this.soundPool;
    this.soundPool = null;
    this.isInitialized = false;
    this.sendSoundId = 0;
    this.receiveSoundId = 0;
    if (pool !== null) {
      try {
        pool.off('loadComplete');
      } catch (e) {
        LogUtils.dTag(TAG, 'off loadComplete failed');
      }
      pool.release().catch((e: BusinessError) => {
        LogUtils.eTag(TAG, `release failed: ${e.message}`);
      });
    }
    const mgr: resourceManager.ResourceManager | null = this.resMgr;
    if (mgr !== null) {
      for (const name of this.openedFds) {
        mgr.closeRawFd(name).catch((e: BusinessError) => {
          LogUtils.dTag(TAG, `closeRawFd ${name}: ${e.message}`);
        });
      }
    }
    this.openedFds = [];
  }
}
