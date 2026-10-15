/**
 * ToastUtils (source: core/util/toast/ToastUtils.kt, Toaster library) — UIContext.getPromptAction().
 * Must be initialised with ToastUtils.init(uiContext) after windowStage.loadContent (fnd-app-init).
 * Success / error / warning styles: Toaster custom layouts (colored rounded background, white 15sp text,
 * leading 24dp icon) are approximated with the system toast backgroundColor/textColor
 * (#09BE4F / #FF2B2B / #FFB703, white text); the leading icon cannot be shown in a system toast.
 * Black/white default styles: BlackToastStyle (light system) / WhiteToastStyle (dark system) via styleBg/styleFg.
 */
import { promptAction, UIContext } from '@kit.ArkUI';
import { LogUtils } from './LogUtils';

const TAG: string = 'ToastUtils';
// Toaster defaults: short 2000ms, long 3500ms; show() picks long when text length > 20.
const SHORT_DURATION: number = 2000;
const LONG_DURATION: number = 3500;
const AUTO_LONG_TEXT_LENGTH: number = 20;
const COLOR_SUCCESS: string = '#09BE4F';
const COLOR_ERROR: string = '#FF2B2B';
const COLOR_WARNING: string = '#FFB703';
const COLOR_WHITE: string = '#FFFFFF';
/** Toaster BlackToastStyle / WhiteToastStyle approximations */
const STYLE_BLACK_BG: string = '#CC000000';
const STYLE_BLACK_FG: string = '#FFFFFF';
const STYLE_WHITE_BG: string = '#EAFFFFFF';
const STYLE_WHITE_FG: string = '#BB000000';

export class ToastUtils {
  private static uiContext: UIContext | null = null;
  private static lastToastId: number = -1;
  private static pendingTimers: number[] = [];
  private static darkMode: boolean = false;

  /** Bind the UIContext used for toasts (call after loadContent). isDarkTheme mirrors the source init flag. */
  static init(uiContext: UIContext, isDarkTheme: boolean = false): void {
    ToastUtils.uiContext = uiContext;
    ToastUtils.darkMode = isDarkTheme;
  }

  static isReady(): boolean {
    return ToastUtils.uiContext !== null;
  }

  /**
   * Source setBlackStyle()/setWhiteStyle() switch the default toast style with the app theme.
   * The system toast already renders with the current (app-applied) color mode, so only the mode is recorded.
   */
  static setBlackStyle(): void {
    ToastUtils.darkMode = false;
    LogUtils.dTag(TAG, 'default toast style: light (system toast follows color mode)');
  }

  static setWhiteStyle(): void {
    ToastUtils.darkMode = true;
    LogUtils.dTag(TAG, 'default toast style: dark (system toast follows color mode)');
  }

  static isDarkMode(): boolean {
    return ToastUtils.darkMode;
  }

  /** Default style (source Application.kt: WhiteToastStyle when the system is dark, BlackToastStyle when light) — LAUNCH-A32 */
  private static styleBg(): string {
    return ToastUtils.darkMode ? STYLE_WHITE_BG : STYLE_BLACK_BG;
  }

  private static styleFg(): string {
    return ToastUtils.darkMode ? STYLE_WHITE_FG : STYLE_BLACK_FG;
  }

  /** Normal toast; duration auto-selected like Toaster.show. */
  static show(text: ResourceStr): void {
    ToastUtils.showInternal(text, ToastUtils.autoDuration(text), ToastUtils.styleBg(), ToastUtils.styleFg());
  }

  static showShort(text: ResourceStr): void {
    ToastUtils.showInternal(text, SHORT_DURATION, ToastUtils.styleBg(), ToastUtils.styleFg());
  }

  static showLong(text: ResourceStr): void {
    ToastUtils.showInternal(text, LONG_DURATION, ToastUtils.styleBg(), ToastUtils.styleFg());
  }

  static showSuccess(text: ResourceStr): void {
    ToastUtils.showInternal(text, ToastUtils.autoDuration(text), COLOR_SUCCESS, COLOR_WHITE);
  }

  static showError(text: ResourceStr): void {
    ToastUtils.showInternal(text, ToastUtils.autoDuration(text), COLOR_ERROR, COLOR_WHITE);
  }

  static showWarning(text: ResourceStr): void {
    ToastUtils.showInternal(text, ToastUtils.autoDuration(text), COLOR_WARNING, COLOR_WHITE);
  }

  /** Show a normal toast after delayMillis. */
  static delayedShow(text: ResourceStr, delayMillis: number): void {
    const timerId: number = setTimeout(() => {
      ToastUtils.pendingTimers = ToastUtils.pendingTimers.filter((t: number) => t !== timerId);
      ToastUtils.show(text);
    }, delayMillis);
    ToastUtils.pendingTimers.push(timerId);
  }

  /** Cancel the current toast and any pending delayed toast. */
  static cancel(): void {
    ToastUtils.pendingTimers.forEach((t: number) => clearTimeout(t));
    ToastUtils.pendingTimers = [];
    const ctx: UIContext | null = ToastUtils.uiContext;
    if (ctx !== null && ToastUtils.lastToastId >= 0) {
      try {
        ctx.getPromptAction().closeToast(ToastUtils.lastToastId);
      } catch (e) {
        LogUtils.wTag(TAG, `closeToast failed: ${JSON.stringify(e)}`);
      }
      ToastUtils.lastToastId = -1;
    }
  }

  private static autoDuration(text: ResourceStr): number {
    if (typeof text === 'string') {
      return (text as string).length > AUTO_LONG_TEXT_LENGTH ? LONG_DURATION : SHORT_DURATION;
    }
    return SHORT_DURATION;
  }

  private static showInternal(text: ResourceStr, duration: number, bg: string | undefined,
    fg: string | undefined): void {
    const ctx: UIContext | null = ToastUtils.uiContext;
    if (ctx === null) {
      LogUtils.wTag(TAG, `toast before init: ${typeof text === 'string' ? text : 'resource'}`);
      return;
    }
    const options: promptAction.ShowToastOptions = {
      message: text,
      duration: duration
    };
    if (bg !== undefined) {
      options.backgroundColor = bg;
      // Opaque colored background: disable the default blur material so the color is not tinted.
      options.backgroundBlurStyle = BlurStyle.NONE;
    }
    if (fg !== undefined) {
      options.textColor = fg;
    }
    try {
      ctx.getPromptAction().openToast(options).then((id: number) => {
        ToastUtils.lastToastId = id;
      }).catch((e: Error) => {
        LogUtils.wTag(TAG, `openToast failed: ${e.message}`);
      });
    } catch (e) {
      LogUtils.wTag(TAG, `openToast threw: ${JSON.stringify(e)}`);
    }
  }
}
