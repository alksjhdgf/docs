/**
 * LogUtils — hilog wrapper (source: core/util/log/LogUtils.kt, Timber + android.util.Log).
 * Tagged overloads v/d/i/w/e(tag, message) map to hilog with the given tag;
 * untagged ones (Timber style) use the default tag 'CoolMall'.
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0C01;
const DEFAULT_TAG: string = 'CoolMall';

export class LogUtils {
  private static debugMode: boolean = false;

  /**
   * Source: LogUtils.init(application, isDebug). When not debug, verbose/debug logs are dropped
   * (Timber plants no tree in release builds).
   */
  static init(isDebug: boolean = false): void {
    LogUtils.debugMode = isDebug;
  }

  static isDebug(): boolean {
    return LogUtils.debugMode;
  }

  // ===== tagged (android.util.Log equivalents: always logged) =====
  static vTag(tag: string, message: string): void {
    hilog.debug(DOMAIN, tag, '%{public}s', message);
  }

  static dTag(tag: string, message: string): void {
    hilog.debug(DOMAIN, tag, '%{public}s', message);
  }

  static iTag(tag: string, message: string): void {
    hilog.info(DOMAIN, tag, '%{public}s', message);
  }

  static wTag(tag: string, message: string): void {
    hilog.warn(DOMAIN, tag, '%{public}s', message);
  }

  static eTag(tag: string, message: string, err?: Error): void {
    if (err !== undefined) {
      hilog.error(DOMAIN, tag, '%{public}s: %{public}s\n%{public}s', message, err.message, err.stack ?? '');
    } else {
      hilog.error(DOMAIN, tag, '%{public}s', message);
    }
  }

  // ===== untagged (Timber equivalents: only when a tree is planted, i.e. debug) =====
  static v(message: string): void {
    if (LogUtils.debugMode) {
      hilog.debug(DOMAIN, DEFAULT_TAG, '%{public}s', message);
    }
  }

  static d(message: string): void {
    if (LogUtils.debugMode) {
      hilog.debug(DOMAIN, DEFAULT_TAG, '%{public}s', message);
    }
  }

  static i(message: string): void {
    if (LogUtils.debugMode) {
      hilog.info(DOMAIN, DEFAULT_TAG, '%{public}s', message);
    }
  }

  static w(message: string): void {
    if (LogUtils.debugMode) {
      hilog.warn(DOMAIN, DEFAULT_TAG, '%{public}s', message);
    }
  }

  static e(message: string, err?: Error): void {
    if (LogUtils.debugMode) {
      LogUtils.eTag(DEFAULT_TAG, message, err);
    }
  }

  static wtf(message: string): void {
    if (LogUtils.debugMode) {
      hilog.fatal(DOMAIN, DEFAULT_TAG, '%{public}s', message);
    }
  }
}
