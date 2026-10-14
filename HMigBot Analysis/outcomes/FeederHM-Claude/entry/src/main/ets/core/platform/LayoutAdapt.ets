/**
 * LayoutAdapt.ets —— 源 ui/compose/utils（WindowSize.kt、Foldables.kt、Focusable.kt、ProvideScaledText.kt、
 * MutableSavedState.kt）与 util/ContextExtensions.unicodeWrap 的鸿蒙等价物。
 *
 * - 窗口尺寸类（Material3 阈值）：宽 Compact<600vp、Medium<840vp；高 Compact<480vp、Medium<900vp（UT-A42/A43）。
 * - WindowMetrics（@ObservedV2）放在 AppStorageV2 键 `WindowMetrics`；EntryAbility 在 onWindowStageCreate 中
 *   `LayoutAdapt.attach(mainWindow)`，订阅 windowSizeChange / keyboardHeightChange / foldStatusChange，aboutToDisappear 不需要
 *   （随窗口生命周期；detach() 供 onWindowStageDestroy 对称清理）。
 * - Escape/Back 键（UT-A44）、文字缩放（UT-A45）、作者名双向隔离（UT-A46）、保存状态（UT-A47）。
 */
import { AppStorageV2, display, KeyboardAvoidMode, UIContext, window } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';

const LOG_TAG: string = 'FEEDER_LAYOUT';

// ---------------------------------------------------------------- 尺寸类

export enum WindowWidthSizeClass {
  Compact = 'Compact',
  Medium = 'Medium',
  Expanded = 'Expanded',
}

export enum WindowHeightSizeClass {
  Compact = 'Compact',
  Medium = 'Medium',
  Expanded = 'Expanded',
}

/** 源 ScreenType */
export enum ScreenType {
  DUAL = 'DUAL',
  SINGLE = 'SINGLE',
}

export function widthSizeClassOf(widthVp: number): WindowWidthSizeClass {
  if (widthVp < 600) {
    return WindowWidthSizeClass.Compact;
  }
  if (widthVp < 840) {
    return WindowWidthSizeClass.Medium;
  }
  return WindowWidthSizeClass.Expanded;
}

export function heightSizeClassOf(heightVp: number): WindowHeightSizeClass {
  if (heightVp < 480) {
    return WindowHeightSizeClass.Compact;
  }
  if (heightVp < 900) {
    return WindowHeightSizeClass.Medium;
  }
  return WindowHeightSizeClass.Expanded;
}

/** 源 getScreenType：宽 Compact → SINGLE，否则 DUAL（UT-A42） */
export function getScreenType(widthClass: WindowWidthSizeClass): ScreenType {
  return widthClass === WindowWidthSizeClass.Compact ? ScreenType.SINGLE : ScreenType.DUAL;
}

/** 源 isCompactDevice：高 Compact 或 宽 Compact（UT-A43） */
export function isCompactDeviceFor(widthClass: WindowWidthSizeClass, heightClass: WindowHeightSizeClass): boolean {
  return heightClass === WindowHeightSizeClass.Compact || widthClass === WindowWidthSizeClass.Compact;
}

/** 源 isCompactLandscape：横屏 且 高 Compact（UT-A43） */
export function isCompactLandscapeFor(landscape: boolean, heightClass: WindowHeightSizeClass): boolean {
  return landscape && heightClass === WindowHeightSizeClass.Compact;
}

/** 源 FoldableHinge：bounds 为 vp */
export class FoldableHinge {
  left: number = 0;
  top: number = 0;
  right: number = 0;
  bottom: number = 0;

  /** 源 isTopToBottom = bounds.top == 0（竖直铰链） */
  get isTopToBottom(): boolean {
    return this.top === 0;
  }

  /** 源 isLeftToRight = bounds.left == 0（水平铰链） */
  get isLeftToRight(): boolean {
    return this.left === 0;
  }
}

/** 窗口度量（LocalWindowSize + LocalWindowSizeMetrics + LocalFoldableHinge + IME 高度的合体） */
@ObservedV2
export class WindowMetrics {
  @Trace widthVp: number = 360;
  @Trace heightVp: number = 780;
  @Trace imeHeightVp: number = 0;
  @Trace hinge: FoldableHinge | null = null;

  @Computed
  get widthClass(): WindowWidthSizeClass {
    return widthSizeClassOf(this.widthVp);
  }

  @Computed
  get heightClass(): WindowHeightSizeClass {
    return heightSizeClassOf(this.heightVp);
  }

  @Computed
  get screenType(): ScreenType {
    return getScreenType(this.widthClass);
  }

  @Computed
  get isLandscape(): boolean {
    return this.widthVp > this.heightVp;
  }

  @Computed
  get isCompactDevice(): boolean {
    return isCompactDeviceFor(this.widthClass, this.heightClass);
  }

  @Computed
  get isCompactLandscape(): boolean {
    return isCompactLandscapeFor(this.isLandscape, this.heightClass);
  }

  @Computed
  get imeVisible(): boolean {
    return this.imeHeightVp > 0;
  }
}

export const WINDOW_METRICS_KEY: string = 'WindowMetrics';

function densityOf(): number {
  try {
    const d = display.getDefaultDisplaySync().densityPixels;
    return d > 0 ? d : 1;
  } catch (e) {
    return 1;
  }
}

function currentHinge(density: number): FoldableHinge | null {
  try {
    if (!display.isFoldable()) {
      return null;
    }
    const st = display.getFoldStatus();
    if (st !== display.FoldStatus.FOLD_STATUS_EXPANDED && st !== display.FoldStatus.FOLD_STATUS_HALF_FOLDED) {
      return null;
    }
    const region = display.getCurrentFoldCreaseRegion();
    if (region.creaseRects.length === 0) {
      return null;
    }
    const r = region.creaseRects[0];
    const h = new FoldableHinge();
    h.left = r.left / density;
    h.top = r.top / density;
    h.right = (r.left + r.width) / density;
    h.bottom = (r.top + r.height) / density;
    return h;
  } catch (e) {
    return null;
  }
}

export class LayoutAdapt {
  private static win: window.Window | null = null;
  private static sizeCb: ((size: window.Size) => void) | null = null;
  private static imeCb: ((height: number) => void) | null = null;
  private static foldCb: ((st: display.FoldStatus) => void) | null = null;

  /** 页面读取：`@Local metrics: WindowMetrics = LayoutAdapt.metrics()` */
  static metrics(): WindowMetrics {
    return AppStorageV2.connect(WindowMetrics, WINDOW_METRICS_KEY, () => new WindowMetrics()) as WindowMetrics;
  }

  /** 由 EntryAbility.onWindowStageCreate 调用（fnd-app-init） */
  static attach(win: window.Window): void {
    LayoutAdapt.detach();
    LayoutAdapt.win = win;
    const m = LayoutAdapt.metrics();
    try {
      const rect = win.getWindowProperties().windowRect;
      const density = densityOf();
      m.widthVp = rect.width / density;
      m.heightVp = rect.height / density;
      m.hinge = currentHinge(density);
    } catch (e) {
      console.warn(`${LOG_TAG}: getWindowProperties failed: ${JSON.stringify(e)}`);
    }
    const sizeCb = (size: window.Size): void => {
      const density = densityOf();
      m.widthVp = size.width / density;
      m.heightVp = size.height / density;
      m.hinge = currentHinge(density);
    };
    const imeCb = (height: number): void => {
      m.imeHeightVp = height / densityOf();
    };
    const foldCb = (_st: display.FoldStatus): void => {
      m.hinge = currentHinge(densityOf());
    };
    try {
      win.on('windowSizeChange', sizeCb);
      LayoutAdapt.sizeCb = sizeCb;
      win.on('keyboardHeightChange', imeCb);
      LayoutAdapt.imeCb = imeCb;
    } catch (e) {
      console.warn(`${LOG_TAG}: window subscribe failed: ${JSON.stringify(e)}`);
    }
    try {
      if (display.isFoldable()) {
        display.on('foldStatusChange', foldCb);
        LayoutAdapt.foldCb = foldCb;
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: fold subscribe failed: ${JSON.stringify(e)}`);
    }
  }

  static detach(): void {
    const w = LayoutAdapt.win;
    try {
      const sizeCb = LayoutAdapt.sizeCb;
      const imeCb = LayoutAdapt.imeCb;
      const foldCb = LayoutAdapt.foldCb;
      if (w !== null) {
        if (sizeCb !== null) {
          w.off('windowSizeChange', sizeCb);
        }
        if (imeCb !== null) {
          w.off('keyboardHeightChange', imeCb);
        }
      }
      if (foldCb !== null) {
        display.off('foldStatusChange', foldCb);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: detach failed: ${JSON.stringify(e)}`);
    }
    LayoutAdapt.win = null;
    LayoutAdapt.sizeCb = null;
    LayoutAdapt.imeCb = null;
    LayoutAdapt.foldCb = null;
  }

  /** IME 适配：键盘弹出时压缩布局（源 Activity windowSoftInputMode=adjustResize 等价） */
  static resizeOnKeyboard(uiContext: UIContext): void {
    try {
      uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (e) {
      console.warn(`${LOG_TAG}: setKeyboardAvoidMode failed: ${JSON.stringify(e)}`);
    }
  }
}

// ---------------------------------------------------------------- 键盘 Escape（源 Focusable.kt，UT-A44）

/** Escape / Back（源还有 NavigateOut，鸿蒙无对应键码） */
export function isEscapeLikeKeyCode(keyCode: number): boolean {
  return keyCode === KeyCode.KEYCODE_ESCAPE || keyCode === KeyCode.KEYCODE_BACK;
}

/**
 * 用法：`.onKeyEvent((e: KeyEvent) => onKeyEventLikeEscape(e, () => this.close()))`（onKeyEvent 回调返回 boolean 的重载）。
 * 是 Escape 类键 → 消费（返回 true）；只在按下（KeyType.Down）时触发动作一次（源 Down/Up 各触发一次，按意图去重）。
 */
export function onKeyEventLikeEscape(event: KeyEvent, action: () => void): boolean {
  if (!isEscapeLikeKeyCode(event.keyCode)) {
    return false;
  }
  if (event.type === KeyType.Down) {
    action();
  }
  return true;
}

// ---------------------------------------------------------------- 文字缩放（源 ProvideScaledText.kt，UT-A45）

/** fontSize × fontScale（fp） */
export function scaledFontSize(baseFp: number, fontScale: number): number {
  return baseFp * fontScale;
}

/** lineHeight × fontScale；未指定（null）保持未指定 */
export function scaledLineHeight(baseFp: number | null, fontScale: number): number | null {
  return baseFp === null ? null : baseFp * fontScale;
}

// ---------------------------------------------------------------- 双向隔离（源 unicodeWrap，UT-A46）

export const FSI: string = '⁨';
export const PDI: string = '⁩';

/**
 * 源 BidiFormatter.unicodeWrap(text)：按文本方向与语境方向插入 LRE/RLE..PDF 与 LRM/RLM。
 * 鸿蒙无 BidiFormatter → 用 Unicode 6.3 的 FSI…PDI 首强方向隔离，效果等价（作者名不打乱 by_author_on_date 语序）。
 */
export function unicodeWrap(text: string): string {
  return `${FSI}${text}${PDI}`;
}

// ---------------------------------------------------------------- 保存状态（源 MutableSavedState.kt，UT-A47）

/**
 * SavedStateHandle 等价：键值容器。进程重建恢复依赖 EntryAbility.onSaveState 写出 / onCreate(want.parameters) 读回
 * （SavedStateRegistry.saveAll / restoreAll，由 fnd-app-init 接线）。
 */
export class SavedStateHandle {
  private values: Map<string, Object> = new Map<string, Object>();

  contains(key: string): boolean {
    return this.values.has(key);
  }

  get(key: string): Object | undefined {
    return this.values.get(key);
  }

  set(key: string, value: Object): void {
    this.values.set(key, value);
  }

  remove(key: string): void {
    this.values.delete(key);
  }

  keys(): string[] {
    return Array.from(this.values.keys());
  }
}

/** 全部页面的 SavedStateHandle 注册表（按页面/ViewModel 作用域名区分） */
export class SavedStateRegistry {
  private static handles: Map<string, SavedStateHandle> = new Map<string, SavedStateHandle>();
  private static restored: Map<string, Object> = new Map<string, Object>();
  static readonly PARAM_PREFIX: string = 'feeder.savedstate.';

  /** 取（或建）作用域句柄；若有进程重建恢复的值则预灌入 */
  static handle(scope: string): SavedStateHandle {
    const existing = SavedStateRegistry.handles.get(scope);
    if (existing !== undefined) {
      return existing;
    }
    const h = new SavedStateHandle();
    const prefix = `${SavedStateRegistry.PARAM_PREFIX}${scope}.`;
    SavedStateRegistry.restored.forEach((v: Object, k: string) => {
      if (k.startsWith(prefix)) {
        h.set(k.substring(prefix.length), v);
      }
    });
    SavedStateRegistry.handles.set(scope, h);
    return h;
  }

  static clear(scope: string): void {
    SavedStateRegistry.handles.delete(scope);
  }

  /** EntryAbility.onSaveState(reason, wantParam) 中调用：写入 wantParam */
  static saveAll(wantParam: Record<string, Object>): void {
    SavedStateRegistry.handles.forEach((h: SavedStateHandle, scope: string) => {
      for (const k of h.keys()) {
        const v = h.get(k);
        if (v !== undefined) {
          wantParam[`${SavedStateRegistry.PARAM_PREFIX}${scope}.${k}`] = v;
        }
      }
    });
  }

  /** EntryAbility.onCreate(want) 且 launchReason 为恢复时调用：读回 want.parameters */
  static restoreAll(params: Record<string, Object> | undefined): void {
    if (params === undefined) {
      return;
    }
    const keys: string[] = Object.keys(params);
    for (const k of keys) {
      if (k.startsWith(SavedStateRegistry.PARAM_PREFIX)) {
        SavedStateRegistry.restored.set(k, params[k]);
      }
    }
  }
}

/**
 * 源 DelegatedMutableSavedState：键=属性名；首次读取从 handle 取值（无则默认值）并回调 onChange；
 * 每次写入同时写 handle、更新值并回调 onChange。ViewModel 用 getter/setter 包一层即可等价 `by` 委托。
 */
export class MutableSavedState<T> {
  private readonly handle: SavedStateHandle;
  private readonly key: string;
  private readonly onChange: ((value: T) => void) | null;
  private initialized: boolean = false;
  private current: T;

  constructor(handle: SavedStateHandle, key: string, defaultValue: T, onChange?: (value: T) => void) {
    this.handle = handle;
    this.key = key;
    this.current = defaultValue;
    this.onChange = onChange !== undefined ? onChange : null;
  }

  get value(): T {
    if (!this.initialized) {
      const saved = this.handle.get(this.key);
      if (saved !== undefined && saved !== null) {
        this.current = saved as T;
      }
      this.initialized = true;
      if (this.onChange !== null) {
        this.onChange(this.current);
      }
    }
    return this.current;
  }

  set value(v: T) {
    this.handle.set(this.key, v as Object);
    this.current = v;
    if (this.onChange !== null) {
      this.onChange(v);
    }
  }
}

export function mutableSavedStateOf<T>(handle: SavedStateHandle, key: string, defaultValue: T,
  onChange?: (value: T) => void): MutableSavedState<T> {
  return new MutableSavedState<T>(handle, key, defaultValue, onChange);
}
