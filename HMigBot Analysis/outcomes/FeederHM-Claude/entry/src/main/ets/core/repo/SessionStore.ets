/**
 * SessionStore（源 archmodel/SessionStore.kt）：纯内存会话态，从不持久化（冷启后恢复初值）。
 * - resumeTime：初值 EPOCH(0)，回前台时设置（供"恢复时动作"如 syncOnResume）。
 * - expandedTags：抽屉已展开标签集合，初值空（RP-A03）。
 * - syncWorkerRunning：初值 false。
 * StateFlow → @ObservedV2/@Trace 镜像（state，UI 可直接绑定）+ observeXxx(cb)（立即回调当前值，返回反订阅函数）。
 * 注：minReadTime 照源由 SettingsStore 持有（同样不落盘，进程启动=now），见 SettingsStore.setMinReadTime。
 */
import { Listeners } from './RepoTypes';

@ObservedV2
export class SessionState {
  /** epoch ms */
  @Trace resumeTime: number = 0;
  /** 已展开标签（插入顺序；语义为集合） */
  @Trace expandedTags: string[] = [];
  @Trace syncWorkerRunning: boolean = false;
}

export class SessionStore {
  private static inst: SessionStore | null = null;

  readonly state: SessionState = new SessionState();
  private readonly resumeTimeListeners: Listeners<number> = new Listeners<number>();
  private readonly expandedTagsListeners: Listeners<Set<string>> = new Listeners<Set<string>>();
  private readonly syncWorkerRunningListeners: Listeners<boolean> = new Listeners<boolean>();

  static instance(): SessionStore {
    if (SessionStore.inst === null) {
      SessionStore.inst = new SessionStore();
    }
    return SessionStore.inst as SessionStore;
  }

  // ---------------------------------------------------------------- resumeTime

  get resumeTime(): number {
    return this.state.resumeTime;
  }

  setResumeTime(epochMs: number): void {
    // MutableStateFlow.update：相同值不重复发射
    if (this.state.resumeTime === epochMs) {
      return;
    }
    this.state.resumeTime = epochMs;
    this.resumeTimeListeners.emit(epochMs);
  }

  observeResumeTime(cb: (epochMs: number) => void): () => void {
    const off: () => void = this.resumeTimeListeners.add(cb);
    cb(this.state.resumeTime);
    return off;
  }

  // ---------------------------------------------------------------- expandedTags

  /** 当前展开集合的副本 */
  get expandedTags(): Set<string> {
    return new Set<string>(this.state.expandedTags);
  }

  isTagExpanded(tag: string): boolean {
    return this.state.expandedTags.indexOf(tag) >= 0;
  }

  /** 源 toggleTagExpansion：已展开则移除，否则加入 */
  toggleTagExpansion(tag: string): void {
    const cur: string[] = this.state.expandedTags;
    const i: number = cur.indexOf(tag);
    const next: string[] = cur.slice();
    if (i >= 0) {
      next.splice(i, 1);
    } else {
      next.push(tag);
    }
    this.state.expandedTags = next;
    this.expandedTagsListeners.emit(new Set<string>(next));
  }

  observeExpandedTags(cb: (tags: Set<string>) => void): () => void {
    const off: () => void = this.expandedTagsListeners.add(cb);
    cb(this.expandedTags);
    return off;
  }

  // ---------------------------------------------------------------- syncWorkerRunning

  get syncWorkerRunning(): boolean {
    return this.state.syncWorkerRunning;
  }

  setSyncWorkerRunning(running: boolean): void {
    if (this.state.syncWorkerRunning === running) {
      return;
    }
    this.state.syncWorkerRunning = running;
    this.syncWorkerRunningListeners.emit(running);
  }

  observeSyncWorkerRunning(cb: (running: boolean) => void): () => void {
    const off: () => void = this.syncWorkerRunningListeners.add(cb);
    cb(this.state.syncWorkerRunning);
    return off;
  }
}
