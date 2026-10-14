/**
 * SyncStatus.ets —— 同步运行状态（源 SessionStore.syncWorkerRunning + Repository.currentlySyncing，FS-A01/FS-A10）。
 * 由 RssLocalSync 写入；UI/Repository 订阅（observeXxx 返回反订阅函数）或绑定 SyncStatus.ui（@ObservedV2 镜像）。
 */
import { EPOCH_MS } from '../model/Feed';
import { FeedDao } from '../db/FeedDao';

const LOG_TAG: string = 'FEEDER_RSS_LOCAL_SYNC';
const CURRENTLY_SYNCING_WINDOW_MS: number = 10 * 1000;

export type BooleanListener = (value: boolean) => void;

/** UI 绑定镜像 */
@ObservedV2
export class SyncUiState {
  @Trace syncWorkerRunning: boolean = false;
}

export class SyncStatus {
  static readonly ui: SyncUiState = new SyncUiState();
  private static running: boolean = false;
  private static listeners: BooleanListener[] = [];

  static isSyncWorkerRunning(): boolean {
    return SyncStatus.running;
  }

  static setSyncWorkerRunning(running: boolean): void {
    if (SyncStatus.running === running) {
      return;
    }
    SyncStatus.running = running;
    SyncStatus.ui.syncWorkerRunning = running;
    SyncStatus.listeners.slice().forEach((cb: BooleanListener) => {
      try {
        cb(running);
      } catch (e) {
        console.error(LOG_TAG, `syncWorkerRunning listener failed: ${(e as Error).message}`);
      }
    });
  }

  /** 订阅 syncWorkerRunning（立即回调当前值）；返回反订阅函数 */
  static observeSyncWorkerRunning(cb: BooleanListener): () => void {
    SyncStatus.listeners.push(cb);
    cb(SyncStatus.running);
    return () => {
      const i: number = SyncStatus.listeners.indexOf(cb);
      if (i >= 0) {
        SyncStatus.listeners.splice(i, 1);
      }
    };
  }

  /** FS-A10：MAX(feeds.last_sync) 在最近 10 秒内 */
  static isCurrentlySyncing(latestLastSync: number | null, nowMs: number = Date.now()): boolean {
    const ts: number = latestLastSync !== null ? latestLastSync : EPOCH_MS;
    return ts > nowMs - CURRENTLY_SYNCING_WINDOW_MS;
  }

  /** 源 Repository.currentlySyncing（distinctUntilChanged）；10 秒窗口过期时自动回落 false */
  static observeCurrentlySyncing(cb: BooleanListener): () => void {
    let last: boolean | null = null;
    let latestTs: number | null = null;
    let timer: number = -1;
    const evaluate = (): void => {
      const now: number = Date.now();
      const v: boolean = SyncStatus.isCurrentlySyncing(latestTs, now);
      if (timer !== -1) {
        clearTimeout(timer);
        timer = -1;
      }
      if (v && latestTs !== null) {
        const delay: number = Math.max(latestTs + CURRENTLY_SYNCING_WINDOW_MS - now, 0) + 50;
        timer = setTimeout(() => {
          timer = -1;
          evaluate();
        }, delay);
      }
      if (last !== v) {
        last = v;
        cb(v);
      }
    };
    const unsub: () => void = FeedDao.observeCurrentlySyncingLatestTimestamp((ts: number | null) => {
      latestTs = ts;
      evaluate();
    });
    return () => {
      unsub();
      if (timer !== -1) {
        clearTimeout(timer);
        timer = -1;
      }
    };
  }

  /** Feed 页刷新指示：currentlySyncing 且 syncWorkerRunning（FS-A10） */
  static observeFeedRefreshing(cb: BooleanListener): () => void {
    let syncing: boolean = false;
    let running: boolean = SyncStatus.running;
    let last: boolean | null = null;
    const emit = (): void => {
      const v: boolean = syncing && running;
      if (last !== v) {
        last = v;
        cb(v);
      }
    };
    const u1: () => void = SyncStatus.observeCurrentlySyncing((v: boolean) => {
      syncing = v;
      emit();
    });
    const u2: () => void = SyncStatus.observeSyncWorkerRunning((v: boolean) => {
      running = v;
      emit();
    });
    return () => {
      u1();
      u2();
    };
  }
}
