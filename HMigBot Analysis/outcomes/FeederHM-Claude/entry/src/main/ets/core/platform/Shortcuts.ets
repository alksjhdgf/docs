/**
 * Shortcuts.ets —— 源 util/ContextExtensions.kt（addDynamicShortcutToFeed / reportShortcutToFeedUsed）
 * 与 util/LetterIconProvider.kt 的鸿蒙等价物。
 *
 * 平台差异（台账未登记，见降级候选 deg-acc-dynamic-shortcuts）：鸿蒙公开 API（@kit.AbilityKit shortcutManager，API 20+）只有
 * getAllShortcutInfoForSelf / setShortcutVisibleForSelf，快捷方式须在 module.json5 静态声明，
 * 运行期不能新增"标签=源标题、图标=字母图标"的动态快捷方式。因此：
 * - 快捷方式规则（id/标签/深链/rank/上限 3/已存在只更新/满则移除 rank 最大）完整实现为纯逻辑 + MRU 模型
 *   （DynamicShortcutModel），并持久化到 Preferences（等价源 ShortcutManager 的跨进程保留）。
 * - 桌面落地（UT-A34 降级方案）：静态声明 3 个槽位快捷方式 `feed_slot_0..2`（profile 中 visible=false，
 *   want.parameters 带 `feederShortcutSlot`=槽号），每次变更后按 MRU 列表长度用 setShortcutVisibleForSelf
 *   显隐槽位；点击槽位 → 入口 Want 经 resolveShortcutWantUri（DeepLinkRouter.resolveWant 调用）换算为该槽当前源的深链
 *   （rank 0 = 最近用）。槽位声明：resources/base/profile/shortcuts_config.json + module.json5 EntryAbility metadata。
 *   差异：槽位标签/图标为静态资源，不能是源标题/字母图标。未声明槽位时自动退化为仅模型。
 * - 额外平台适配仍可经 setShortcutPlatformHook 注入。
 * - 所有异常被吞掉只打调试日志（UT-A32）。
 */
import { application, common, shortcutManager, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { image } from '@kit.ImageKit';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { DEEP_LINK_BASE_URI } from '../util/Constants';
import { javaLongHashCode, javaStringHashCode } from '../util/JavaHash';

const LOG_TAG: string = 'FeederDynamicShortcut';

/** 源 setDisabledMessage("Feed deleted")（硬编码英文） */
export const SHORTCUT_DISABLED_MESSAGE: string = 'Feed deleted';

/** 源 maxShortcutCountPerActivity.coerceAtMost(3) 的上限 */
export const MAX_FEED_SHORTCUTS: number = 3;

export class FeedShortcut {
  id: string = '';
  shortLabel: string = '';
  longLabel: string = '';
  /** 目标深链 */
  uri: string = '';
  rank: number = 0;
  disabledMessage: string = SHORTCUT_DISABLED_MESSAGE;
}

/** 源快捷方式目标深链：`https://feederapp.nononsenseapps.com/feed?id=<feedId>` */
export function feedShortcutUri(feedId: number): string {
  return `${DEEP_LINK_BASE_URI}/feed?id=${feedId}`;
}

export function buildFeedShortcut(label: string, feedId: number): FeedShortcut {
  const s = new FeedShortcut();
  s.id = `${feedId}`;
  s.shortLabel = label;
  s.longLabel = label;
  s.uri = feedShortcutUri(feedId);
  s.rank = 0;
  return s;
}

export enum ShortcutOpKind {
  UPDATE = 'UPDATE',
  ADD = 'ADD',
}

/** addDynamicShortcutToFeed 的决策结果（纯逻辑，UT-A31） */
export class ShortcutPlan {
  kind: ShortcutOpKind = ShortcutOpKind.ADD;
  shortcut: FeedShortcut = new FeedShortcut();
  /** 新增前需移除的快捷方式 id（已达上限时 rank 最大的一个），无则 null */
  removeId: string | null = null;
}

/**
 * 源逻辑：已存在同 id → 仅更新；否则若 current.size >= min(systemMax, 3) → 按 rank 升序排序取最后一个移除；然后新增。
 * Kotlin sortBy 为稳定排序：同 rank 时保留原顺序中的最后一个。
 */
export function planAddFeedShortcut(current: FeedShortcut[], label: string, feedId: number,
  systemMax: number = MAX_FEED_SHORTCUTS): ShortcutPlan {
  const plan = new ShortcutPlan();
  plan.shortcut = buildFeedShortcut(label, feedId);
  const exists = current.some((s: FeedShortcut): boolean => s.id === plan.shortcut.id);
  if (exists) {
    plan.kind = ShortcutOpKind.UPDATE;
    return plan;
  }
  plan.kind = ShortcutOpKind.ADD;
  if (current.length >= Math.min(systemMax, MAX_FEED_SHORTCUTS)) {
    const sorted = current.slice();
    sorted.sort((a: FeedShortcut, b: FeedShortcut): number => a.rank - b.rank); // Array.sort 稳定（ES2019）
    if (sorted.length > 0) {
      plan.removeId = sorted[sorted.length - 1].id;
    }
  }
  return plan;
}

/** 平台适配钩子：拿到决策后的完整列表（rank 0 在前）。未注册 = no-op。 */
export type ShortcutPlatformHook = (shortcuts: FeedShortcut[]) => void;

let platformHook: ShortcutPlatformHook | null = null;

export function setShortcutPlatformHook(cb: ShortcutPlatformHook | null): void {
  platformHook = cb;
}

/**
 * 内存 MRU 模型：模拟 ShortcutManager 动态快捷方式列表的 rank 语义——
 * 新增/更新的快捷方式 rank=0（置顶），其余依次后移。
 */
export class DynamicShortcutModel {
  private static list: FeedShortcut[] = [];

  static dynamicShortcuts(): FeedShortcut[] {
    return DynamicShortcutModel.list.slice();
  }

  static apply(plan: ShortcutPlan): void {
    let next: FeedShortcut[] = DynamicShortcutModel.list.filter((s: FeedShortcut): boolean =>
      s.id !== plan.shortcut.id && (plan.removeId === null || s.id !== plan.removeId));
    next = [plan.shortcut].concat(next);
    for (let i = 0; i < next.length; i++) {
      next[i].rank = i;
    }
    DynamicShortcutModel.list = next;
  }

  static remove(ids: string[]): void {
    DynamicShortcutModel.list = DynamicShortcutModel.list.filter((s: FeedShortcut): boolean => ids.indexOf(s.id) < 0);
    for (let i = 0; i < DynamicShortcutModel.list.length; i++) {
      DynamicShortcutModel.list[i].rank = i;
    }
  }

  static clear(): void {
    DynamicShortcutModel.list = [];
  }

  /** 从持久化读回（按 rank 排好序） */
  static restore(list: FeedShortcut[]): void {
    DynamicShortcutModel.list = list.slice();
    for (let i = 0; i < DynamicShortcutModel.list.length; i++) {
      DynamicShortcutModel.list[i].rank = i;
    }
  }
}

// ---------------------------------------------------------------- 持久化 + 桌面槽位

/** 静态槽位快捷方式 id 前缀（module.json5 → profile shortcuts：feed_slot_0 / feed_slot_1 / feed_slot_2） */
export const SHORTCUT_SLOT_ID_PREFIX: string = 'feed_slot_';
/** 槽位快捷方式 want.parameters 中的槽号键（值为 "0".."2"） */
export const SHORTCUT_SLOT_PARAM: string = 'feederShortcutSlot';

const PREFS_NAME: string = 'feeder_shortcuts';
const PREFS_KEY: string = 'dynamic_shortcuts';

class StoredShortcut {
  id: string = '';
  shortLabel: string = '';
  longLabel: string = '';
  uri: string = '';
  rank: number = 0;
}

let loaded: boolean = false;
let opChain: Promise<void> = Promise.resolve();

function appContext(): common.Context | null {
  try {
    return application.getApplicationContext();
  } catch (e) {
    return null;
  }
}

async function openPrefs(): Promise<preferences.Preferences | null> {
  const ctx = appContext();
  if (ctx === null) {
    return null;
  }
  try {
    return await preferences.getPreferences(ctx, PREFS_NAME);
  } catch (e) {
    console.debug(`${LOG_TAG}: open prefs failed: ${JSON.stringify(e)}`);
    return null;
  }
}

export function serializeShortcuts(list: FeedShortcut[]): string {
  const out: StoredShortcut[] = list.map((s: FeedShortcut): StoredShortcut => {
    const st = new StoredShortcut();
    st.id = s.id;
    st.shortLabel = s.shortLabel;
    st.longLabel = s.longLabel;
    st.uri = s.uri;
    st.rank = s.rank;
    return st;
  });
  return JSON.stringify(out);
}

export function deserializeShortcuts(raw: string): FeedShortcut[] {
  if (raw.length === 0) {
    return [];
  }
  const arr = JSON.parse(raw) as StoredShortcut[];
  if (!Array.isArray(arr)) {
    return [];
  }
  const list: FeedShortcut[] = [];
  for (const st of arr) {
    if (st === null || st === undefined || typeof st.id !== 'string' || st.id.length === 0) {
      continue;
    }
    const s = new FeedShortcut();
    s.id = st.id;
    s.shortLabel = typeof st.shortLabel === 'string' ? st.shortLabel : '';
    s.longLabel = typeof st.longLabel === 'string' ? st.longLabel : s.shortLabel;
    s.uri = typeof st.uri === 'string' ? st.uri : '';
    s.rank = typeof st.rank === 'number' ? st.rank : list.length;
    list.push(s);
  }
  list.sort((a: FeedShortcut, b: FeedShortcut): number => a.rank - b.rank);
  return list.slice(0, MAX_FEED_SHORTCUTS);
}

/** 首次操作前从 Preferences 读回上次进程的快捷方式列表 */
async function ensureLoaded(): Promise<void> {
  if (loaded) {
    return;
  }
  loaded = true;
  const prefs = await openPrefs();
  if (prefs === null) {
    return;
  }
  const raw = await prefs.get(PREFS_KEY, '');
  DynamicShortcutModel.restore(deserializeShortcuts(typeof raw === 'string' ? raw as string : ''));
}

async function persist(): Promise<void> {
  const prefs = await openPrefs();
  if (prefs === null) {
    return;
  }
  await prefs.put(PREFS_KEY, serializeShortcuts(DynamicShortcutModel.dynamicShortcuts()));
  await prefs.flush();
}

/** 槽位快捷方式 id → 槽号；非槽位返回 -1 */
export function slotIndexOf(shortcutId: string): number {
  if (!shortcutId.startsWith(SHORTCUT_SLOT_ID_PREFIX)) {
    return -1;
  }
  const n = Number(shortcutId.substring(SHORTCUT_SLOT_ID_PREFIX.length));
  return Number.isInteger(n) && n >= 0 ? n : -1;
}

/** 按当前列表长度显隐静态槽位：槽 i 可见 ⇔ i < 快捷方式数 */
async function syncLauncherSlots(count: number): Promise<void> {
  let infos: shortcutManager.ShortcutInfo[] = [];
  try {
    infos = await shortcutManager.getAllShortcutInfoForSelf();
  } catch (e) {
    console.debug(`${LOG_TAG}: getAllShortcutInfoForSelf failed: ${JSON.stringify(e)}`);
    return;
  }
  for (const info of infos) {
    const slot = slotIndexOf(info.id);
    if (slot < 0) {
      continue;
    }
    try {
      await shortcutManager.setShortcutVisibleForSelf(info.id, slot < count);
    } catch (e) {
      console.debug(`${LOG_TAG}: setShortcutVisibleForSelf(${info.id}) failed: ${JSON.stringify(e)}`);
    }
  }
}

async function notifyPlatform(): Promise<void> {
  const list = DynamicShortcutModel.dynamicShortcuts();
  try {
    await persist();
  } catch (e) {
    console.debug(`${LOG_TAG}: persist failed: ${JSON.stringify(e)}`);
  }
  await syncLauncherSlots(list.length);
  const hook = platformHook;
  if (hook !== null) {
    hook(list);
  }
}

/** 串行化所有快捷方式操作（先读回持久化列表），异常吞掉只打调试日志（UT-A32） */
function enqueue(what: string, op: () => void): Promise<void> {
  opChain = opChain.then(async (): Promise<void> => {
    try {
      await ensureLoaded();
      op();
      await notifyPlatform();
    } catch (error) {
      console.debug(`${LOG_TAG}: Error during ${what} of shortcut: ${JSON.stringify(error)}`);
    }
  });
  return opChain;
}

/** 等待已排队的快捷方式操作完成（测试/入口解析用） */
export function shortcutOpsIdle(): Promise<void> {
  return opChain;
}

/**
 * 源 Context.addDynamicShortcutToFeed（UT-A31/A32）：选中具体源（feedId > ID_UNSET）时由 Repository 调用。
 * 任何异常吞掉只打调试日志。
 */
export function addDynamicShortcutToFeed(label: string, feedId: number): void {
  try {
    enqueue('add', (): void => {
      const plan = planAddFeedShortcut(DynamicShortcutModel.dynamicShortcuts(), label, feedId);
      DynamicShortcutModel.apply(plan);
    });
  } catch (error) {
    console.debug(`${LOG_TAG}: Error during add of shortcut: ${JSON.stringify(error)}`);
  }
}

/** 源 reportShortcutToFeedUsed：鸿蒙无启动器预测上报 API → 仅记录（no_equiv）。 */
export function reportShortcutToFeedUsed(id: number | string): void {
  try {
    console.debug(`${LOG_TAG}: report use of shortcut ${id} (no launcher prediction API on HarmonyOS)`);
  } catch (error) {
    console.debug(`${LOG_TAG}: Error during report use of shortcut: ${JSON.stringify(error)}`);
  }
}

/** 源被删除时移除对应快捷方式（Repository 调用）；异常吞掉。 */
export function removeFeedShortcuts(feedIds: number[]): void {
  try {
    enqueue('remove', (): void => {
      DynamicShortcutModel.remove(feedIds.map((id: number): string => `${id}`));
    });
  } catch (error) {
    console.debug(`${LOG_TAG}: Error during remove of shortcut: ${JSON.stringify(error)}`);
  }
}

/**
 * 入口 Want 若来自槽位快捷方式（parameters[feederShortcutSlot]），返回该槽当前源的深链
 * `https://feederapp.nononsenseapps.com/feed?id=<feedId>`；否则/槽位已空返回 null。
 * 由 DeepLinkRouter 在解析 want.uri 之前调用。
 */
export async function resolveShortcutWantUri(want: Want): Promise<string | null> {
  try {
    const v: Object | undefined = want.parameters?.[SHORTCUT_SLOT_PARAM];
    if (v === undefined || v === null) {
      return null;
    }
    const slot = Number(`${v}`);
    if (!Number.isInteger(slot) || slot < 0) {
      return null;
    }
    await opChain;
    await ensureLoaded();
    const list = DynamicShortcutModel.dynamicShortcuts();
    if (slot >= list.length) {
      return null;
    }
    const s = list[slot];
    reportShortcutToFeedUsed(s.id);
    return s.uri.length > 0 ? s.uri : feedShortcutUri(Number(s.id));
  } catch (error) {
    console.debug(`${LOG_TAG}: Error during resolve of shortcut: ${JSON.stringify(error)}`);
    return null;
  }
}

// ---------------------------------------------------------------- 字母图标（LetterIconProvider，UT-A33）

/** 源 colors 前 8 色（NUM_OF_TILE_COLORS = 8） */
export const LETTER_TILE_COLORS: string[] = [
  '#e57373', '#f06292', '#ba68c8', '#9575cd',
  '#7986cb', '#64b5f6', '#4fc3f7', '#4dd0e1',
];

export const NUM_OF_TILE_COLORS: number = 8;

/**
 * 源 pickColor：abs(key.hashCode()) % 8。key 为 Long feedId（number）时用 Long.hashCode，字符串用 String.hashCode。
 * abs(Int.MIN_VALUE) 在 Kotlin 为负，但其 %8 == 0，与此处结果一致。
 */
export function letterIconColorIndex(key: number | string): number {
  const h: number = typeof key === 'string' ? javaStringHashCode(key as string) : javaLongHashCode(key as number);
  return Math.abs(h) % NUM_OF_TILE_COLORS;
}

export function letterIconColor(key: number | string): string {
  return LETTER_TILE_COLORS[letterIconColorIndex(key)];
}

/** 源：标题空白 → 'F'；否则首个 UTF-16 码元的 uppercaseChar（单字符映射，无法单字符大写时保持原样） */
export function letterIconChar(text: string): string {
  if (text.trim().length === 0) {
    return 'F';
  }
  const c = text.charAt(0);
  const up = c.toUpperCase();
  return up.length === 1 ? up : c;
}

/**
 * 源 getLetterIcon：radius×radius 像素位图；圆形底色 + 白色居中粗体首字母（字号 0.8×边长）。
 * 失败 → null（调用方不依赖它）。
 */
export function getLetterIcon(text: string, key: number | string, radius: number = 128): image.PixelMap | null {
  try {
    const canvas = new OffscreenCanvas(radius, radius, LengthMetricsUnit.PX);
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = letterIconColor(key);
    ctx.beginPath();
    ctx.arc(radius / 2, radius / 2, radius / 2, 0, Math.PI * 2);
    ctx.fill();

    const ch = letterIconChar(text);
    const fontSize = radius * 0.8;
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'alphabetic';
    const m: TextMetrics = ctx.measureText(ch);
    const glyphHeight = m.actualBoundingBoxAscent + m.actualBoundingBoxDescent;
    ctx.fillText(ch, radius / 2, radius / 2 + glyphHeight / 2);
    return ctx.getPixelMap(0, 0, radius, radius);
  } catch (e) {
    console.debug(`${LOG_TAG}: letter icon failed: ${JSON.stringify(e)}`);
    return null;
  }
}
