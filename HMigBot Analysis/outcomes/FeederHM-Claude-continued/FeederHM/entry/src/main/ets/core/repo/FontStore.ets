/**
 * FontStore（源 archmodel/FontStore.kt）+ FontSelection（源 ui/compose/settings/TextSettingsViewModel.kt:139-247）
 * + TrueType 变体轴解析（源 truetype/TrueTypeParser.kt）。
 * 用户字体目录 `<filesDir>/fonts`，拷贝中转 `<cacheDir>`（源 FilePathProvider）。
 * 源 Uri + ContentResolver(OpenableColumns.DISPLAY_NAME) → 鸿蒙 DocumentViewPicker 返回的 uri 字符串
 * （文件名取调用方传入的 displayName，缺省从 uri 末段解析）。
 */
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { FilePathProvider } from '../util/Constants';
import { FONT_PATH_ROBOTO_FLEX, FONT_PATH_SYSTEM_DEFAULT } from '../settings/SettingsKeys';
import { Listeners } from './RepoTypes';

// ============================================================ TrueType 解析

/** 源 data class FloatVariations */
export class FloatVariations {
  readonly minValue: number;
  readonly defaultValue: number;
  readonly maxValue: number;

  constructor(minValue: number, defaultValue: number, maxValue: number) {
    this.minValue = minValue;
    this.defaultValue = defaultValue;
    this.maxValue = maxValue;
  }
}

/** 源 data class TrueTypeMetadata */
export class TrueTypeMetadata {
  weightVariations: FloatVariations | null = null;
  italicVariations: FloatVariations | null = null;
  slantVariations: FloatVariations | null = null;
}

/** 源 IllegalArgumentException("Invalid TrueType font file") */
export class InvalidTrueTypeError extends Error {
  constructor(message: string = 'Invalid TrueType font file') {
    super(message);
    this.name = 'InvalidTrueTypeError';
  }
}

/** 随机读取：从 offset 起最多读 length 字节（文件尾不足则返回更短） */
export type ByteReader = (offset: number, length: number) => Uint8Array;

const TABLE_ENTRY_LEN: number = 16;
const OFFSET_SUBTABLE_LEN: number = 12;

function readExact(read: ByteReader, offset: number, length: number): Uint8Array {
  const b: Uint8Array = read(offset, length);
  if (b.length !== length) {
    throw new InvalidTrueTypeError() as Object as Error;
  }
  return b;
}

/** 源 uBytesToUInt（大端无符号） */
export function uBytesToUInt(bytes: Uint8Array, numBytes: number): number {
  let result: number = 0;
  for (let i = 0; i < numBytes; i++) {
    result = result * 256 + bytes[i];
  }
  return result;
}

/** 源 fixedType32ToSignedFloat（16.16 定点；整数部分有符号，Kotlin Float 运算） */
export function fixedType32ToSignedFloat(bytes: Uint8Array): number {
  let integer: number = uBytesToUInt(bytes, 2);
  if (integer >= 0x8000) {
    integer -= 0x10000;
  }
  const sign: number = integer < 0 ? -1 : 1;
  const decimal: number = bytes[2] * 256 + bytes[3];
  return Math.fround(Math.fround(integer) + Math.fround(sign * Math.fround(decimal / 65536.0)));
}

function tagIs(b: Uint8Array, tag: string): boolean {
  for (let i = 0; i < 4; i++) {
    if (b[i] !== tag.charCodeAt(i)) {
      return false;
    }
  }
  return true;
}

/**
 * 源 parseTrueTypeFont：校验 0x00010000 标量头，查找 fvar 表并读取 wght/ital/slnt 轴。非法抛 InvalidTrueTypeError。
 * 源以 FileInputStream.skip 前后跳转，等价于随机访问偏移。
 */
export function parseTrueTypeFont(read: ByteReader): TrueTypeMetadata {
  const meta: TrueTypeMetadata = new TrueTypeMetadata();
  const head: Uint8Array = readExact(read, 0, 4);
  if (head[0] !== 0x00 || head[1] !== 0x01 || head[2] !== 0x00 || head[3] !== 0x00) {
    throw new InvalidTrueTypeError() as Object as Error;
  }
  const numTables: number = uBytesToUInt(readExact(read, 4, 2), 2);
  let off: number = OFFSET_SUBTABLE_LEN;
  let fvarOffset: number = 0;
  let fvarLength: number = 0;
  for (let t = 0; t < numTables; t++) {
    const tag: Uint8Array = readExact(read, off, 4);
    off += 4;
    if (tagIs(tag, 'fvar')) {
      off += 4; // checksum
      fvarOffset = uBytesToUInt(readExact(read, off, 4), 4);
      off += 4;
      fvarLength = uBytesToUInt(readExact(read, off, 4), 4);
      off += 4;
      break;
    }
    off += TABLE_ENTRY_LEN - 4;
  }
  if (fvarOffset > 0 && fvarLength > 0) {
    // majorVersion, minorVersion, offsetToData, countSizePairs
    off = fvarOffset + 8;
    const axisCount: number = uBytesToUInt(readExact(read, off, 2), 2);
    off += 2;
    const axisSize: number = uBytesToUInt(readExact(read, off, 2), 2);
    off += 2;
    // instanceCount, instanceSize
    off += 4;
    for (let a = 0; a < axisCount; a++) {
      const axisStart: number = off;
      const axisTag: Uint8Array = readExact(read, off, 4);
      const minValue: number = fixedType32ToSignedFloat(readExact(read, off + 4, 4));
      const defaultValue: number = fixedType32ToSignedFloat(readExact(read, off + 8, 4));
      const maxValue: number = fixedType32ToSignedFloat(readExact(read, off + 12, 4));
      const v: FloatVariations = new FloatVariations(minValue, defaultValue, maxValue);
      if (tagIs(axisTag, 'wght')) {
        meta.weightVariations = v;
      } else if (tagIs(axisTag, 'ital')) {
        meta.italicVariations = v;
      } else if (tagIs(axisTag, 'slnt')) {
        meta.slantVariations = v;
      }
      off = axisStart + axisSize;
    }
  }
  return meta;
}

/** 源 getFontMetadata(file)：解析失败返回 null */
export function getFontMetadata(path: string): TrueTypeMetadata | null {
  let file: fs.File | null = null;
  try {
    file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    const fd: number = file.fd;
    const reader: ByteReader = (offset: number, length: number): Uint8Array => {
      if (offset < 0 || length <= 0) {
        return new Uint8Array(0);
      }
      const buf: ArrayBuffer = new ArrayBuffer(length);
      const n: number = fs.readSync(fd, buf, { offset: offset, length: length });
      return new Uint8Array(buf, 0, Math.max(0, n));
    };
    return parseTrueTypeFont(reader);
  } catch (e) {
    console.error(`FEEDER_FONT: Error parsing font file ${path}: ${(e as Error)?.message}`);
    return null;
  } finally {
    if (file !== null) {
      try {
        fs.closeSync(file);
      } catch (ce) {
        console.error(`FEEDER_FONT: close failed: ${(ce as Error)?.message}`);
      }
    }
  }
}

// ============================================================ FontSelection

export enum FontSelectionKind {
  ROBOTO_FLEX = 'RobotoFlex',
  SYSTEM_DEFAULT = 'SystemDefault',
  USER_FONT = 'UserFont',
}

/** 源 sealed interface FontSelection（RobotoFlex / SystemDefault / UserFont） */
export class FontSelection {
  readonly kind: FontSelectionKind;
  readonly path: string;
  readonly minWeightValue: number;
  readonly maxWeightValue: number;
  readonly minItalicValue: number;
  readonly maxItalicValue: number;
  readonly minSlantValue: number;
  readonly maxSlantValue: number;

  /** Grad: -200,0,150 / Wdth: 25,100,151 / Slnt: -10,0,0 / Wght: 100,400,1000 */
  static readonly ROBOTO_FLEX: FontSelection =
    new FontSelection(FontSelectionKind.ROBOTO_FLEX, FONT_PATH_ROBOTO_FLEX, 100, 1000, 0, 0, -10, 0);
  static readonly SYSTEM_DEFAULT: FontSelection =
    new FontSelection(FontSelectionKind.SYSTEM_DEFAULT, FONT_PATH_SYSTEM_DEFAULT, 100, 900, 0, 1, 0, 0);

  constructor(kind: FontSelectionKind, path: string, minWeightValue: number = 0, maxWeightValue: number = 0,
    minItalicValue: number = 0, maxItalicValue: number = 0, minSlantValue: number = 0, maxSlantValue: number = 0) {
    this.kind = kind;
    this.path = path;
    this.minWeightValue = minWeightValue;
    this.maxWeightValue = maxWeightValue;
    this.minItalicValue = minItalicValue;
    this.maxItalicValue = maxItalicValue;
    this.minSlantValue = minSlantValue;
    this.maxSlantValue = maxSlantValue;
  }

  /** 源 UserFont(path, …)：变体值来自 TrueType 轴，缺省 0 */
  static userFont(path: string, meta: TrueTypeMetadata | null, includeSlant: boolean = true): FontSelection {
    const w: FloatVariations | null = meta !== null ? meta.weightVariations : null;
    const i: FloatVariations | null = meta !== null ? meta.italicVariations : null;
    const s: FloatVariations | null = meta !== null && includeSlant ? meta.slantVariations : null;
    return new FontSelection(FontSelectionKind.USER_FONT, path,
      w !== null ? w.minValue : 0, w !== null ? w.maxValue : 0,
      i !== null ? i.minValue : 0, i !== null ? i.maxValue : 0,
      s !== null ? s.minValue : 0, s !== null ? s.maxValue : 0);
  }

  get isUserFont(): boolean {
    return this.kind === FontSelectionKind.USER_FONT;
  }

  get hasWeightVariation(): boolean {
    if (this.kind === FontSelectionKind.SYSTEM_DEFAULT) {
      return true;
    }
    return this.minWeightValue > 0 && this.maxWeightValue > this.minWeightValue;
  }

  get hasItalicVariation(): boolean {
    if (this.kind === FontSelectionKind.SYSTEM_DEFAULT) {
      return true;
    }
    return this.minItalicValue >= 0 && this.maxItalicValue > this.minItalicValue;
  }

  /** -15f to 15f where negative values means regular italic lean */
  get hasSlantVariation(): boolean {
    return this.maxSlantValue >= 0 && this.maxSlantValue > this.minSlantValue;
  }

  serialize(): string {
    return this.path;
  }

  equals(o: FontSelection): boolean {
    return this.kind === o.kind && this.path === o.path && this.minWeightValue === o.minWeightValue &&
      this.maxWeightValue === o.maxWeightValue && this.minItalicValue === o.minItalicValue &&
      this.maxItalicValue === o.maxItalicValue && this.minSlantValue === o.minSlantValue &&
      this.maxSlantValue === o.maxSlantValue;
  }
}

/** 源 defaultFont = FontSelection.RobotoFlex（SettingsStore.kt:998） */
export const DEFAULT_FONT: FontSelection = FontSelection.ROBOTO_FLEX;

// ============================================================ FontStore

@ObservedV2
export class FontState {
  @Trace fontOptions: FontSelection[] = [FontSelection.SYSTEM_DEFAULT, FontSelection.ROBOTO_FLEX];
}

function joinPath(dir: string, name: string): string {
  return dir.endsWith('/') ? `${dir}${name}` : `${dir}/${name}`;
}

function exists(path: string): boolean {
  try {
    return fs.accessSync(path);
  } catch (e) {
    return false;
  }
}

/** 从 uri 末段解析文件名（OpenableColumns.DISPLAY_NAME 的近似） */
export function filenameFromUri(uri: string): string | null {
  let s: string = uri;
  const q: number = s.indexOf('?');
  if (q >= 0) {
    s = s.substring(0, q);
  }
  const h: number = s.indexOf('#');
  if (h >= 0) {
    s = s.substring(0, h);
  }
  const slash: number = s.lastIndexOf('/');
  let name: string = slash >= 0 ? s.substring(slash + 1) : s;
  try {
    name = decodeURIComponent(name);
  } catch (e) {
    console.warn(`FEEDER_FONT: cannot decode filename ${name}`);
  }
  return name.length > 0 ? name : null;
}

export class FontStore {
  private static inst: FontStore | null = null;

  readonly state: FontState = new FontState();
  private paths: FilePathProvider | null = null;
  private readonly listeners: Listeners<FontSelection[]> = new Listeners<FontSelection[]>();

  static instance(): FontStore {
    if (FontStore.inst === null) {
      FontStore.inst = new FontStore();
    }
    return FontStore.inst as FontStore;
  }

  /** 设定目录并扫描字体（幂等） */
  init(ctx: common.Context): void {
    this.paths = new FilePathProvider(ctx.cacheDir, ctx.filesDir);
    this.refresh();
  }

  get fontsDir(): string {
    return this.paths !== null ? this.paths.fontsDir : '';
  }

  /** 用户字体文件绝对路径（供 UI font.registerFont） */
  userFontFile(font: FontSelection): string {
    return joinPath(this.fontsDir, font.path);
  }

  /** 源 fontOptions: StateFlow<List<FontSelection>>（RP-A38） */
  get fontOptions(): FontSelection[] {
    return this.state.fontOptions.slice();
  }

  observeFontOptions(cb: (options: FontSelection[]) => void): () => void {
    const off: () => void = this.listeners.add(cb);
    cb(this.fontOptions);
    return off;
  }

  /** 源 getAllFonts：字体目录下可解析的 .ttf 用户字体（不含 slant，照源）+ SystemDefault + RobotoFlex */
  getAllFonts(): FontSelection[] {
    const result: FontSelection[] = [];
    const dir: string = this.fontsDir;
    if (dir !== '' && exists(dir)) {
      let names: string[] = [];
      try {
        names = fs.listFileSync(dir);
      } catch (e) {
        console.error(`FEEDER_FONT: list ${dir} failed: ${(e as Error)?.message}`);
      }
      for (const name of names) {
        const full: string = joinPath(dir, name);
        let isFile: boolean = false;
        try {
          isFile = fs.statSync(full).isFile();
        } catch (e) {
          isFile = false;
        }
        if (!isFile || !name.endsWith('.ttf')) {
          continue;
        }
        const meta: TrueTypeMetadata | null = getFontMetadata(full);
        if (meta === null) {
          continue;
        }
        result.push(FontSelection.userFont(name, meta, false));
      }
    }
    result.push(FontSelection.SYSTEM_DEFAULT);
    result.push(FontSelection.ROBOTO_FLEX);
    return result;
  }

  refresh(): void {
    const all: FontSelection[] = this.getAllFonts();
    this.state.fontOptions = all;
    this.listeners.emit(all.slice());
  }

  /**
   * 源 getFontSelectionFromPath：内置路径 → 内置字体；用户字体文件不存在或不可解析 → null。
   */
  getFontSelectionFromPath(path: string): FontSelection | null {
    if (path === FONT_PATH_ROBOTO_FLEX) {
      return FontSelection.ROBOTO_FLEX;
    }
    if (path === FONT_PATH_SYSTEM_DEFAULT) {
      return FontSelection.SYSTEM_DEFAULT;
    }
    const full: string = joinPath(this.fontsDir, path);
    if (this.fontsDir === '' || !exists(full)) {
      console.error(`FontSelection: Font file does not exist: ${path}`);
      return null;
    }
    const meta: TrueTypeMetadata | null = getFontMetadata(full);
    if (meta === null) {
      console.error(`FontSelection: Error parsing font file: ${path}`);
      return null;
    }
    return FontSelection.userFont(path, meta, true);
  }

  /**
   * 源 addFont(uri)（RP-A39/A40）：无文件名 → "No filename"；目标已存在 → "File already exists"；
   * 先拷到 cache 校验 TrueType，失败删 cache 并抛 "Error parsing font file"；成功拷入字体目录并刷新列表。
   */
  async addFont(uri: string, displayName: string | null = null): Promise<FontSelection> {
    const p: FilePathProvider | null = this.paths;
    if (p === null) {
      throw new Error('FontStore not initialized');
    }
    const filename: string | null = displayName !== null && displayName.length > 0 ? displayName : filenameFromUri(uri);
    if (filename === null) {
      throw new Error('No filename');
    }
    const fontFile: string = joinPath(p.fontsDir, filename);
    if (exists(fontFile)) {
      console.error(`FEEDER_FONT: File already exists: ${filename}`);
      throw new Error('File already exists');
    }
    // First copy to cache
    const cacheFile: string = joinPath(p.cacheDir, filename);
    if (exists(cacheFile)) {
      await fs.unlink(cacheFile);
    }
    const src: fs.File = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      await fs.copyFile(src.fd, cacheFile);
    } finally {
      await fs.close(src);
    }
    // Then verify font metadata
    const meta: TrueTypeMetadata | null = getFontMetadata(cacheFile);
    if (meta === null) {
      console.error(`FEEDER_FONT: Error parsing font file: ${filename}`);
      await fs.unlink(cacheFile);
      throw new Error('Error parsing font file');
    }
    // File is valid, copy to fonts directory
    if (!exists(p.fontsDir)) {
      await fs.mkdir(p.fontsDir, true);
    }
    await fs.copyFile(cacheFile, fontFile);
    const userFont: FontSelection = FontSelection.userFont(filename, meta, false);
    this.refresh();
    return userFont;
  }

  /** 源 removeFont(UserFont)：删除文件并刷新列表 */
  async removeFont(font: FontSelection): Promise<void> {
    if (!font.isUserFont) {
      return;
    }
    const file: string = joinPath(this.fontsDir, font.path);
    if (this.fontsDir !== '' && exists(file)) {
      await fs.unlink(file);
    }
    this.refresh();
  }
}
