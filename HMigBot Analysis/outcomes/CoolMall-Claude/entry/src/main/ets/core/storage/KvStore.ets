/**
 * KvStore — MMKV equivalent (source: core/util/storage/MMKVUtils.kt + core/datastore/**).
 * Backed by @kit.ArkData preferences, single file `coolmall`, synchronous API; every write is
 * followed by flush() so data survives process death (MMKV writes are persisted immediately).
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LogUtils } from '../util/LogUtils';

const TAG: string = 'KvStore';
const PREFERENCES_NAME: string = 'coolmall';

/** Persistence keys, copied verbatim from the source (DATA-A18). */
export class KvKeys {
  /** AuthStoreDataSourceImpl.KEY_AUTH */
  static readonly AUTH_INFO: string = 'auth_info';
  /** UserInfoStoreDataSourceImpl.KEY_USER_INFO */
  static readonly USER_INFO: string = 'user_info';
  /** Cart items selected for checkout (OrderConfirm) */
  static readonly CARTS: string = 'carts';
  /** Selected goods for checkout (OrderConfirm) */
  static readonly SELECTED_GOODS_LIST: string = 'selectedGoodsList';
  /** Remembered login account */
  static readonly SAVED_PHONE: string = 'saved_phone';
  static readonly SAVED_PASSWORD: string = 'saved_password';
  /** Onboarding guide flag */
  static readonly GUIDE_SHOWN: string = 'guide_shown';
  /** Theme settings */
  static readonly SETTINGS_THEME_MODE: string = 'settings_theme_mode';
  static readonly SETTINGS_THEME_COLOR: string = 'settings_theme_color';
}

export class KvStore {
  private static prefs: preferences.Preferences | null = null;

  /** MMKVUtils.init — call once from EntryAbility.onCreate before any other storage access. */
  static init(ctx: common.Context): void {
    if (KvStore.prefs !== null) {
      return;
    }
    const options: preferences.Options = { name: PREFERENCES_NAME };
    KvStore.prefs = preferences.getPreferencesSync(ctx, options);
  }

  static isInitialized(): boolean {
    return KvStore.prefs !== null;
  }

  private static store(): preferences.Preferences | null {
    if (KvStore.prefs === null) {
      LogUtils.eTag(TAG, 'KvStore not initialized, call KvStore.init(ctx) in EntryAbility.onCreate first');
    }
    return KvStore.prefs;
  }

  private static flush(p: preferences.Preferences): void {
    try {
      p.flushSync();
    } catch (e) {
      LogUtils.eTag(TAG, 'flush failed: ' + JSON.stringify(e));
    }
  }

  // ====================== String ======================
  static getString(key: string, defaultValue: string = ''): string {
    const p = KvStore.store();
    if (p === null) {
      return defaultValue;
    }
    const v = p.getSync(key, defaultValue);
    return typeof v === 'string' ? (v as string) : defaultValue;
  }

  /** MMKV encode(key, null) removes the value; same here. */
  static putString(key: string, value: string | null): void {
    const p = KvStore.store();
    if (p === null) {
      return;
    }
    if (value === null) {
      p.deleteSync(key);
    } else {
      p.putSync(key, value);
    }
    KvStore.flush(p);
  }

  // ====================== Boolean ======================
  static getBoolean(key: string, defaultValue: boolean = false): boolean {
    const p = KvStore.store();
    if (p === null) {
      return defaultValue;
    }
    const v = p.getSync(key, defaultValue);
    return typeof v === 'boolean' ? (v as boolean) : defaultValue;
  }

  static putBoolean(key: string, value: boolean): void {
    const p = KvStore.store();
    if (p === null) {
      return;
    }
    p.putSync(key, value);
    KvStore.flush(p);
  }

  // ====================== Number (MMKV Int/Long/Float/Double) ======================
  static getNumber(key: string, defaultValue: number = 0): number {
    const p = KvStore.store();
    if (p === null) {
      return defaultValue;
    }
    const v = p.getSync(key, defaultValue);
    return typeof v === 'number' ? (v as number) : defaultValue;
  }

  static putNumber(key: string, value: number): void {
    const p = KvStore.store();
    if (p === null) {
      return;
    }
    p.putSync(key, value);
    KvStore.flush(p);
  }

  // ====================== Object (kotlinx.serialization JSON) ======================
  /**
   * MMKVUtils.putObject: stores JSON.stringify(value) as a string.
   * Do NOT pass @ObservedV2 instances directly (conventions A2.8) — pass a plain toJson() object.
   */
  static putObject(key: string, value: Object): void {
    KvStore.putString(key, JSON.stringify(value));
  }

  /**
   * MMKVUtils.getObject: empty or unparsable → null.
   * Returns the parsed plain object cast to T (not a class instance: methods are absent;
   * callers needing instances must rebuild them, e.g. via a fromJson()).
   */
  static getObject<T>(key: string): T | null {
    const json = KvStore.getString(key, '');
    if (json.length === 0) {
      return null;
    }
    try {
      const parsed: Object | null = JSON.parse(json) as Object | null;
      if (parsed === null) {
        return null;
      }
      return parsed as T;
    } catch (e) {
      LogUtils.wTag(TAG, 'getObject parse failed for key ' + key);
      return null;
    }
  }

  // ====================== Misc ======================
  static containsKey(key: string): boolean {
    const p = KvStore.store();
    if (p === null) {
      return false;
    }
    return p.hasSync(key);
  }

  static remove(key: string): void {
    const p = KvStore.store();
    if (p === null) {
      return;
    }
    p.deleteSync(key);
    KvStore.flush(p);
  }

  static clearAll(): void {
    const p = KvStore.store();
    if (p === null) {
      return;
    }
    p.clearSync();
    KvStore.flush(p);
  }
}
