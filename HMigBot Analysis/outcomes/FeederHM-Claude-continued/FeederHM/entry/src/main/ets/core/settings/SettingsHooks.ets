/*
 * SettingsHooks — SettingsStore setter 副作用的反向依赖注入点（conventions §C：setXxxHook(cb)，未注册 no-op）。
 *
 * - 同步调度钩子：源 SettingsStore.setSyncOnlyOnWifi / setSyncOnlyWhenCharging / setSyncFrequency 末尾调用
 *   schedulePeriodicRssSync(di, replace = true)（SettingsStore.kt:252,262,524）。由 fnd-sync-engine 注册，
 *   回调内读 SettingsStore 当前 syncFrequency/syncOnlyOnWifi/syncOnlyWhenCharging 重排 WorkScheduler；
 *   minutes < 1（MANUAL）时取消周期同步（RssSyncJob.kt:121-125）。
 * - 屏蔽词变化钩子：源 Repository 在屏蔽词增删及切换 applyBlocklistToSummaries/Links 后 runOnceBlocklistUpdate(di)
 *   （Repository.kt:226-247）。SettingsStore 在 applyBlocklistTo* setter 后触发；Repository 增删 pattern 后调用
 *   fireBlocklistChanged()。由 repo/sync 单元注册。
 */

/** replace：源 schedulePeriodicRssSync 的 replace 参数（setter 触发时恒为 true） */
export type SyncScheduleHook = (replace: boolean) => Promise<void>;
export type BlocklistChangedHook = () => Promise<void>;

let syncScheduleHook: SyncScheduleHook | null = null;
let blocklistChangedHook: BlocklistChangedHook | null = null;

/** 注册（或传 null 注销）周期同步重排钩子 */
export function setSyncScheduleHook(cb: SyncScheduleHook | null): void {
  syncScheduleHook = cb;
}

/** 注册（或传 null 注销）屏蔽词/屏蔽范围变化钩子 */
export function setBlocklistChangedHook(cb: BlocklistChangedHook | null): void {
  blocklistChangedHook = cb;
}

/** 触发周期同步重排；未注册时 no-op；异常只记日志不外抛 */
export function fireSyncScheduleHook(replace: boolean): void {
  const cb = syncScheduleHook;
  if (cb === null) {
    return;
  }
  try {
    cb(replace).catch((e: Error) => {
      console.error(`SettingsHooks: sync schedule hook failed: ${e?.message}`);
    });
  } catch (e) {
    console.error(`SettingsHooks: sync schedule hook threw: ${(e as Error)?.message}`);
  }
}

/** 触发屏蔽词重算；未注册时 no-op；异常只记日志不外抛 */
export function fireBlocklistChanged(): void {
  const cb = blocklistChangedHook;
  if (cb === null) {
    return;
  }
  try {
    cb().catch((e: Error) => {
      console.error(`SettingsHooks: blocklist hook failed: ${e?.message}`);
    });
  } catch (e) {
    console.error(`SettingsHooks: blocklist hook threw: ${(e as Error)?.message}`);
  }
}
