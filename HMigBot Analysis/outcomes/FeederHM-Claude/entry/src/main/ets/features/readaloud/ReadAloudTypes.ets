/**
 * ReadAloudTypes.ets —— 源 model/ReadAloudStateHolder.kt 的数据类型（PlaybackStatus :431、LocaleOverride :437）
 * 与 TTSStateHolder 的纯逻辑辅助（由 ReadAloudStateHolder.ets 按单文件 ≤600 行拆出）。
 */
import { normalizeTag } from './TextLanguageDetector';

/** speak 单次文本上限（引擎限制 < 10000 字符），超长段落按此拆分 */
const MAX_UTTERANCE_LENGTH: number = 9000;

/** 源 enum class PlaybackStatus */
export enum PlaybackStatus {
  STOPPED = 'STOPPED',
  PAUSED = 'PAUSED',
  PLAYING = 'PLAYING'
}

export enum LocaleOverrideKind {
  APP_SETTING = 'AppSetting',
  FORCED_AUTO = 'ForcedAuto',
  FORCED_LOCALE = 'ForcedLocale'
}

/** 源 sealed class LocaleOverride { AppSetting, ForcedAuto, ForcedLocale(locale) } */
export class LocaleOverride {
  readonly kind: LocaleOverrideKind;
  /** 仅 ForcedLocale 有意义（BCP-47 标签） */
  readonly locale: string;

  constructor(kind: LocaleOverrideKind, locale: string) {
    this.kind = kind;
    this.locale = locale;
  }

  static appSetting(): LocaleOverride {
    return new LocaleOverride(LocaleOverrideKind.APP_SETTING, '');
  }

  static forcedAuto(): LocaleOverride {
    return new LocaleOverride(LocaleOverrideKind.FORCED_AUTO, '');
  }

  static forcedLocale(locale: string): LocaleOverride {
    return new LocaleOverride(LocaleOverrideKind.FORCED_LOCALE, locale);
  }
}

/** 源 ttsState / language / availableLanguages 三个 StateFlow */
@ObservedV2
export class TtsState {
  @Trace ttsState: PlaybackStatus = PlaybackStatus.STOPPED;
  @Trace language: LocaleOverride = LocaleOverride.appSetting();
  @Trace availableLanguages: string[] = [];
}

export function isBlank(s: string): boolean {
  return s.trim().length === 0;
}

/** 超长段落按空白拆成 ≤ MAX_UTTERANCE_LENGTH 的片段（引擎限制） */
export function splitForEngine(text: string): string[] {
  if (text.length <= MAX_UTTERANCE_LENGTH) {
    return [text];
  }
  const out: string[] = [];
  let rest: string = text;
  while (rest.length > MAX_UTTERANCE_LENGTH) {
    let cut: number = rest.lastIndexOf(' ', MAX_UTTERANCE_LENGTH);
    if (cut <= 0) {
      cut = MAX_UTTERANCE_LENGTH;
    }
    out.push(rest.substring(0, cut));
    rest = rest.substring(cut);
  }
  if (!isBlank(rest)) {
    out.push(rest);
  }
  return out;
}

/** Kotlin sortedBy（稳定） */
export function stableSortByKey(items: string[], key: (s: string) => string): string[] {
  const keys: string[] = [];
  const sorted: string[] = [];
  for (let i = 0; i < items.length; i++) {
    const k: string = key(items[i]);
    let pos: number = sorted.length;
    while (pos > 0 && keys[pos - 1] > k) {
      pos--;
    }
    sorted.splice(pos, 0, items[i]);
    keys.splice(pos, 0, k);
  }
  return sorted;
}

export function sameTag(a: string, b: string): boolean {
  return normalizeTag(a).toLowerCase() === normalizeTag(b).toLowerCase();
}

