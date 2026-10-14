/**
 * TextSettingsViewModel（源 ui/compose/settings/TextSettingsViewModel.kt + TextSettings.kt 的 UiFontOption）。
 *
 * 源 combine(repository.font, textScale, fontOptions, previewBold, previewItalic, errorToDisplay) → FontSettingsState
 *  ⇒ @ObservedV2 状态对象：订阅 SettingsStore（pref_font / pref_body_text_scale）与 FontStore.fontOptions，变化即重算。
 * 源 applicationCoroutineScope.launch ⇒ AppScope.launch（离页后写入仍完成）。
 * 源 errorToDisplay（LaunchedEffect 弹 Toast）⇒ errorSeq 自增 + 错误监听回调（页面持 UIContext 弹 Toast）。
 */
import { uniformTypeDescriptor } from '@kit.ArkData';
import { text } from '@kit.ArkGraphics2D';
import { AppScope } from '../../core/app/AppBootstrap';
import { AddFontError, RemoveFontError } from '../../core/repo/RepoTypes';
import { Repository } from '../../core/repo/Repository';
import { DEFAULT_FONT, FontSelection, FontSelectionKind, filenameFromUri } from '../../core/repo/FontStore';
import { SettingsStore } from '../../core/settings/SettingsStore';
import { PREF_FONT, PREF_TEXT_SCALE } from '../../core/settings/SettingsKeys';
import { Either } from '../../core/util/Either';

const LOG_TAG: string = 'FEEDER_TEXTSETTINGS';

/** 源 ScaleSetting(valueRange = 1f..2f, steps = 9) */
export const TEXT_SCALE_MIN: number = 1.0;
export const TEXT_SCALE_MAX: number = 2.0;
export const TEXT_SCALE_STEP: number = 0.1;

/** 源 OpenDocument MIME ["application/x-font-ttf", "font/ttf"] */
export const FONT_MIME_TYPES: string[] = ['application/x-font-ttf', 'font/ttf'];
/** UTD 查询失败时的兜底后缀（与上述 MIME 对应的 TrueType 扩展名） */
export const FONT_SUFFIX_FILTERS: string[] = ['.ttf'];

/**
 * DocumentViewPicker 只支持后缀过滤：按源 MIME 列表经 UTD（uniformTypeDescriptor）映射出各自的
 * 文件扩展名并取并集（TS-A07）；查不到任何扩展名时回退 FONT_SUFFIX_FILTERS。
 */
export function fontPickerSuffixFilters(): string[] {
  const out: string[] = [];
  for (const mime of FONT_MIME_TYPES) {
    try {
      const typeIds: string[] = uniformTypeDescriptor.getUniformDataTypesByMIMEType(mime);
      for (const typeId of typeIds) {
        const desc: uniformTypeDescriptor.TypeDescriptor = uniformTypeDescriptor.getTypeDescriptor(typeId);
        const exts: string[] | null | undefined = desc.filenameExtensions;
        if (exts === null || exts === undefined) {
          continue;
        }
        for (const ext of exts) {
          const e: string = ext.startsWith('.') ? ext.toLowerCase() : `.${ext.toLowerCase()}`;
          if (e.length > 1 && out.indexOf(e) < 0) {
            out.push(e);
          }
        }
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: UTD lookup failed for ${mime}: ${(e as Error)?.message}`);
    }
  }
  return out.length > 0 ? out : FONT_SUFFIX_FILTERS.slice();
}

/** 源 errorToDisplay 的三类 Toast：AddFontError / RemoveFontError / 其它 */
export enum TextSettingsErrorKind {
  ADD_FONT = 'AddFontError',
  REMOVE_FONT = 'RemoveFontError',
  OTHER = 'Other',
}

export type TextSettingsErrorListener = (kind: TextSettingsErrorKind) => void;

/** 源 UiFontOption(name, realOption)：realOption=null 表示 `Add font…` */
export class UiFontOption {
  /** 稳定 key：字体 path；Add font 为 '' */
  readonly optionKey: string;
  /** 用户字体显示名（文件名）；内置项为 '' 并用 labelRes */
  readonly nameText: string;
  readonly labelRes: ResourceStr;
  readonly realOption: FontSelection | null;

  constructor(optionKey: string, nameText: string, labelRes: ResourceStr, realOption: FontSelection | null) {
    this.optionKey = optionKey;
    this.nameText = nameText;
    this.labelRes = labelRes;
    this.realOption = realOption;
  }

  get isAddFont(): boolean {
    return this.realOption === null;
  }

  /** 源 sortedBy：RobotoFlex "10"、SystemDefault "30"、UserFont "40 <name>"、Add font "50" */
  get sortKey(): string {
    const f: FontSelection | null = this.realOption;
    if (f === null) {
      return '50';
    }
    if (f.kind === FontSelectionKind.ROBOTO_FLEX) {
      return '10';
    }
    if (f.kind === FontSelectionKind.SYSTEM_DEFAULT) {
      return '30';
    }
    return `40 ${this.nameText}`;
  }

  static addFont(): UiFontOption {
    return new UiFontOption('', '', $r('app.string.add_font'), null);
  }

  /** 源 UiFontOption.fromFontSelection：RobotoFlex→"Roboto"、SystemDefault→system_default、UserFont→path.substringAfter("/") */
  static fromFontSelection(font: FontSelection): UiFontOption {
    if (font.kind === FontSelectionKind.ROBOTO_FLEX) {
      return new UiFontOption(font.path, 'Roboto', 'Roboto', font);
    }
    if (font.kind === FontSelectionKind.SYSTEM_DEFAULT) {
      return new UiFontOption(font.path, '', $r('app.string.system_default'), font);
    }
    const name: string = userFontDisplayName(font.path);
    return new UiFontOption(font.path, name, name, font);
  }
}

/** Kotlin String.substringAfter("/")：无分隔符返回原串 */
export function userFontDisplayName(path: string): string {
  const i: number = path.indexOf('/');
  return i >= 0 ? path.substring(i + 1) : path;
}

/** 当前字体显示名（供 Settings 页 `Text settings` 副标题，TS-A02/A04） */
export function fontDisplayLabel(font: FontSelection): ResourceStr {
  return UiFontOption.fromFontSelection(font).labelRes;
}

function codeUnitCompare(a: string, b: string): number {
  return a < b ? -1 : (a > b ? 1 : 0);
}

/** 源 uiFontOptions：Add font + fontOptions，按 sortKey 稳定排序 */
export function buildUiFontOptions(fontOptions: FontSelection[]): UiFontOption[] {
  const list: UiFontOption[] = [UiFontOption.addFont()];
  for (const f of fontOptions) {
    list.push(UiFontOption.fromFontSelection(f));
  }
  const indexed: number[] = list.map((_v: UiFontOption, i: number): number => i);
  indexed.sort((a: number, b: number): number => {
    const c: number = codeUnitCompare(list[a].sortKey, list[b].sortKey);
    return c !== 0 ? c : a - b;
  });
  return indexed.map((i: number): UiFontOption => list[i]);
}

/** 源 ScaleSetting：currentValue.coerceIn(valueRange) */
export function coerceTextScale(v: number): number {
  if (Number.isNaN(v)) {
    return TEXT_SCALE_MIN;
  }
  return Math.min(TEXT_SCALE_MAX, Math.max(TEXT_SCALE_MIN, v));
}

/** 源 stateDescription = "%.1fx".format(safeCurrentValue) */
export function textScaleStateDescription(v: number): string {
  return `${coerceTextScale(v).toFixed(1)}x`;
}

const STANDARD_WEIGHTS: number[] = [100, 200, 300, 400, 500, 600, 700, 800, 900];

/**
 * 源 Typography.kt variableFont：有字重轴时只生成落在 [min,max] 内的标准字重（TS-A29），
 * Compose 按最接近匹配。此处返回目标字重在可用集合中的最近值；无字重轴返回目标值（交由引擎合成）。
 */
export function effectiveWeight(font: FontSelection, target: number): number {
  if (font.kind !== FontSelectionKind.USER_FONT || !font.hasWeightVariation) {
    return target;
  }
  const avail: number[] = STANDARD_WEIGHTS.filter((w: number): boolean =>
  w >= font.minWeightValue && w <= font.maxWeightValue);
  if (avail.length === 0) {
    return target;
  }
  let best: number = avail[0];
  for (const w of avail) {
    if (Math.abs(w - target) < Math.abs(best - target)) {
      best = w;
    }
  }
  return best;
}

/** 一条字体变体轴设置（源 FontVariation.Setting） */
export class FontAxisSetting {
  readonly axis: string;
  readonly value: number;

  constructor(axis: string, value: number) {
    this.axis = axis;
    this.value = value;
  }
}

/**
 * 源 Typography.kt variableFont(file, font, weights, styles)（TS-A29）：
 *  - 有字重轴：wght = 选中的标准字重（落在 [min,max] 内，最接近目标）；
 *  - 有倾斜轴：斜体 slnt=min（负值前倾），正体 slnt=0；
 *  - 否则有 ital 轴：斜体 ital=max，正体 ital=0。
 */
export function userFontVariations(font: FontSelection, targetWeight: number, italic: boolean): FontAxisSetting[] {
  const out: FontAxisSetting[] = [];
  if (font.kind !== FontSelectionKind.USER_FONT) {
    return out;
  }
  if (font.hasWeightVariation) {
    out.push(new FontAxisSetting('wght', effectiveWeight(font, targetWeight)));
  }
  if (font.hasSlantVariation) {
    out.push(new FontAxisSetting('slnt', italic ? font.minSlantValue : 0));
  } else if (font.hasItalicVariation) {
    out.push(new FontAxisSetting('ital', italic ? font.maxItalicValue : 0));
  }
  return out;
}

/**
 * 用户字体预览的段落样式（graphics.text Paragraph 渲染，ArkUI Text 无变体轴接口）。
 * 源 Compose 匹配规则：字体声明了对应字重/样式则不做合成；无轴时 Compose 合成粗体/斜体。
 */
export class UserFontPreviewSpec {
  readonly fontPath: string;
  readonly fontFile: string;
  /** 段落请求的字重（有 wght 轴时固定 400，由变体轴给真实字重，避免伪粗体叠加） */
  readonly paragraphWeight: number;
  /** 段落请求斜体（仅无 slnt/ital 轴时为 true，走合成斜体） */
  readonly syntheticItalic: boolean;
  readonly variations: FontAxisSetting[];
  readonly scale: number;

  constructor(font: FontSelection, fontFile: string, bold: boolean, italic: boolean, scale: number) {
    const target: number = bold ? 700 : 400;
    this.fontPath = font.path;
    this.fontFile = fontFile;
    this.variations = userFontVariations(font, target, italic);
    this.paragraphWeight = font.hasWeightVariation ? 400 : target;
    this.syntheticItalic = italic && !font.hasSlantVariation && !font.hasItalicVariation;
    this.scale = scale;
  }
}

const PREVIEW_FAMILY_PREFIX: string = 'FeederPreviewFont_';
const loadedPreviewFonts: Map<string, string> = new Map<string, string>();

/** 预览族名（与全局 Typography 注册名区分） */
export function previewFamilyName(path: string): string {
  return PREVIEW_FAMILY_PREFIX + path.replace(new RegExp('[^A-Za-z0-9_]', 'g'), '_');
}

/** 将用户字体载入 graphics.text 全局字体集合；失败返回 null（调用方回退） */
export function ensurePreviewFontLoaded(spec: UserFontPreviewSpec): string | null {
  const cached: string | undefined = loadedPreviewFonts.get(spec.fontPath);
  if (cached !== undefined) {
    return cached;
  }
  const family: string = previewFamilyName(spec.fontPath);
  try {
    text.FontCollection.getGlobalInstance().loadFontSync(family, `file://${spec.fontFile}`);
    loadedPreviewFonts.set(spec.fontPath, family);
    return family;
  } catch (e) {
    console.error(`${LOG_TAG}: load preview font failed: ${(e as Error)?.message}`);
    return null;
  }
}

/** 字体删除后卸载（同名再导入时重新加载新文件） */
export function unloadPreviewFont(path: string): void {
  const family: string | undefined = loadedPreviewFonts.get(path);
  if (family === undefined) {
    return;
  }
  loadedPreviewFonts.delete(path);
  try {
    text.FontCollection.getGlobalInstance().unloadFontSync(family);
  } catch (e) {
    console.warn(`${LOG_TAG}: unload preview font failed: ${(e as Error)?.message}`);
  }
}

/** 源 FontSettingsState + TextSettingsViewModel */
@ObservedV2
export class TextSettingsViewModel {
  @Trace fontOptions: FontSelection[] = [FontSelection.SYSTEM_DEFAULT];
  @Trace sansSerifFont: FontSelection = FontSelection.SYSTEM_DEFAULT;
  @Trace fontScale: number = 1.0;
  /** 仅本页临时，不持久化（TS-A16） */
  @Trace previewBold: boolean = false;
  @Trace previewItalic: boolean = false;
  @Trace previewMonospace: boolean = false;
  /** 源 errorToDisplay（每次失败自增，供 UI 观察） */
  @Trace errorSeq: number = 0;
  @Trace errorKind: TextSettingsErrorKind | null = null;
  /** Font 下拉菜单展开（源 MenuSetting expanded） */
  @Trace menuExpanded: boolean = false;

  private offFonts: (() => void) | null = null;
  private offSettings: (() => void) | null = null;
  private errorListener: TextSettingsErrorListener | null = null;

  @Computed
  get uiFontOptions(): UiFontOption[] {
    return buildUiFontOptions(this.fontOptions);
  }

  @Computed
  get currentUiFontOption(): UiFontOption {
    return UiFontOption.fromFontSelection(this.sansSerifFont);
  }

  @Computed
  get isUserFont(): boolean {
    return this.sansSerifFont.isUserFont;
  }

  @Computed
  get safeFontScale(): number {
    return coerceTextScale(this.fontScale);
  }

  /** 当前项比较（kind + path） */
  isCurrent(option: UiFontOption): boolean {
    const f: FontSelection | null = option.realOption;
    return f !== null && f.kind === this.sansSerifFont.kind && f.path === this.sansSerifFont.path;
  }

  setErrorListener(cb: TextSettingsErrorListener | null): void {
    this.errorListener = cb;
  }

  /** 页面 aboutToAppear：订阅并读首屏状态 */
  start(): void {
    this.stop();
    const repo: Repository = Repository.instance();
    this.reloadFont();
    this.fontScale = repo.textScale;
    this.offFonts = repo.observeFontOptions((options: FontSelection[]) => {
      this.fontOptions = options;
    });
    this.offSettings = SettingsStore.instance().observe((key: string) => {
      if (key === PREF_FONT) {
        this.reloadFont();
      } else if (key === PREF_TEXT_SCALE) {
        this.fontScale = Repository.instance().textScale;
      }
    });
  }

  /** 页面 aboutToDisappear：对称反订阅 */
  stop(): void {
    if (this.offFonts !== null) {
      this.offFonts();
      this.offFonts = null;
    }
    if (this.offSettings !== null) {
      this.offSettings();
      this.offSettings = null;
    }
  }

  /** 源 repository.font：路径解析失败/异常 → RobotoFlex（TS-A20） */
  private reloadFont(): void {
    try {
      this.sansSerifFont = Repository.instance().font;
    } catch (e) {
      console.error(`${LOG_TAG}: resolve font failed: ${(e as Error)?.message}`);
      this.sansSerifFont = DEFAULT_FONT;
    }
  }

  // ---------------------------------------------------------------- 源 onEvent

  /** SetSansSerifFont：与当前相同不写入（TS-A06） */
  setSansSerifFont(font: FontSelection): void {
    if (font.kind === this.sansSerifFont.kind && font.path === this.sansSerifFont.path) {
      return;
    }
    // 乐观更新：副标题/预览立即切换；持久化与全局 Typography 刷新由 SettingsStore 通知完成
    this.sansSerifFont = font;
    AppScope.launch('setFont', async (): Promise<void> => {
      await Repository.instance().setFont(font);
    });
  }

  /** SetFontScale：每次变化立即写入（TS-A14/A21） */
  setFontScale(v: number): void {
    const rounded: number = Math.round(v * 10) / 10;
    this.fontScale = rounded;
    AppScope.launch('setTextScale', async (): Promise<void> => {
      await Repository.instance().setTextScale(rounded);
    });
  }

  /** AddFont(uri)：成功自动成为当前字体（Repository.addFont 内 setFont）；失败 Toast could_not_add_font */
  addFont(uri: string, displayName: string | null = null): void {
    const name: string | null = displayName !== null ? displayName : filenameFromUri(uri);
    AppScope.launch('addFont', async (): Promise<void> => {
      try {
        const res: Either<AddFontError, boolean> = await Repository.instance().addFont(uri, name);
        res.onLeft((_e: AddFontError) => {
          this.reportError(TextSettingsErrorKind.ADD_FONT);
        });
        this.reloadFont();
      } catch (e) {
        console.error(`${LOG_TAG}: addFont failed: ${(e as Error)?.message}`);
        this.reportError(TextSettingsErrorKind.OTHER);
      }
    });
  }

  /** RemoveFont：当前字体回到 RobotoFlex 并删文件；失败 Toast could_not_remove_font */
  removeFont(font: FontSelection): void {
    AppScope.launch('removeFont', async (): Promise<void> => {
      try {
        const res: Either<RemoveFontError, boolean> = await Repository.instance().removeFont(font);
        res.onLeft((_e: RemoveFontError) => {
          this.reportError(TextSettingsErrorKind.REMOVE_FONT);
        });
        if (res.isRight()) {
          unloadPreviewFont(font.path);
        }
        this.reloadFont();
      } catch (e) {
        console.error(`${LOG_TAG}: removeFont failed: ${(e as Error)?.message}`);
        this.reportError(TextSettingsErrorKind.OTHER);
      }
    });
  }

  setPreviewBold(v: boolean): void {
    this.previewBold = v;
  }

  setPreviewItalic(v: boolean): void {
    this.previewItalic = v;
  }

  /** 文件选择器打不开（源 ActivityNotFoundException，源未提示）→ 记录日志 */
  onPickerFailed(e: Error | null): void {
    console.error(`${LOG_TAG}: font picker failed: ${e !== null ? e.message : ''}`);
  }

  reportError(kind: TextSettingsErrorKind): void {
    this.errorKind = kind;
    this.errorSeq = this.errorSeq + 1;
    const cb: TextSettingsErrorListener | null = this.errorListener;
    if (cb !== null) {
      cb(kind);
    }
  }

  /** 当前为用户字体时的变体轴预览样式（TS-A29）；内置字体返回 null（走 ArkUI Text） */
  @Computed
  get userFontPreview(): UserFontPreviewSpec | null {
    const font: FontSelection = this.sansSerifFont;
    if (font.kind !== FontSelectionKind.USER_FONT) {
      return null;
    }
    return new UserFontPreviewSpec(font, Repository.instance().fontStore.userFontFile(font),
      this.previewBold, this.previewItalic, this.safeFontScale);
  }

  /** 预览字重（Bold=700/Normal=400，用户字重轴内取最近标准字重） */
  @Computed
  get previewWeight(): number {
    return effectiveWeight(this.sansSerifFont, this.previewBold ? 700 : 400);
  }
}
