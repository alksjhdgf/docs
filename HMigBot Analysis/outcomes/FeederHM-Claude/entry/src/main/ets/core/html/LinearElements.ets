/**
 * LinearElements.ets —— 源 model/html/LinearStuff.kt 的 LinearElement 判别联合（表格见 LinearTable.ets）。
 * 抽象基类 + 子类（instanceof 窄化，或读 elementType 判别字段）。toString() 为规范化描述（用于相等比较）。
 * （LinearArticle.ets 统一再导出）
 */
import { IllegalArgumentException } from '../util/JavaCompat';
import { LinearTextBlockStyle, LinearTextAnnotation } from './LinearTextAnnotation';

// =============================================================================================
// 元素
// =============================================================================================

export enum LinearElementType {
  TEXT = 'Text',
  IMAGE = 'Image',
  VIDEO = 'Video',
  AUDIO = 'Audio',
  LIST_ITEM = 'ListItem',
  BLOCK_QUOTE = 'BlockQuote',
  TABLE = 'Table'
}

export function linearIdsToString(ids: Set<string>): string {
  const arr: string[] = [];
  ids.forEach((id: string) => {
    arr.push(id);
  });
  arr.sort();
  return '[' + arr.join(',') + ']';
}

function nullableToString(v: LinearText | null): string {
  return v === null ? 'null' : v.toString();
}

function optNum(v: number | null): string {
  return v === null ? 'null' : String(v);
}

function optStr(v: string | null): string {
  return v === null ? 'null' : v;
}

export function linearElementsToString(items: LinearElement[]): string {
  const parts: string[] = [];
  for (let i = 0; i < items.length; i++) {
    parts.push(items[i].toString());
  }
  return '[' + parts.join(', ') + ']';
}

/** 源 sealed interface LinearElement（ids() 扩展 → ids 字段） */
export abstract class LinearElement {
  readonly elementType: LinearElementType;
  readonly ids: Set<string>;

  constructor(elementType: LinearElementType, ids: Set<string>) {
    this.elementType = elementType;
    this.ids = ids;
  }

  /** 源 collectImageUrls（LinearStuff.kt:52） */
  collectImageUrls(target: Set<string>): void {
    // LinearAudio / LinearText / LinearVideo → Unit
  }

  /** 源 LinearPrimitive（只有 LinearText 是原语） */
  isPrimitive(): boolean {
    return false;
  }

  abstract toString(): string;

  equals(other: LinearElement | null): boolean {
    return other !== null && this.toString() === other.toString();
  }
}

/** 源 LinearText（LinearPrimitive） */
export class LinearText extends LinearElement {
  readonly text: string;
  readonly annotations: LinearTextAnnotation[];
  readonly blockStyle: LinearTextBlockStyle;

  constructor(ids: Set<string>, text: string, blockStyle: LinearTextBlockStyle,
    annotations: LinearTextAnnotation[] = []) {
    super(LinearElementType.TEXT, ids);
    this.text = text;
    this.blockStyle = blockStyle;
    this.annotations = annotations;
  }

  isPrimitive(): boolean {
    return true;
  }

  toString(): string {
    const ann: string[] = [];
    for (let i = 0; i < this.annotations.length; i++) {
      ann.push(this.annotations[i].toString());
    }
    return 'LinearText(ids=' + linearIdsToString(this.ids) + ', text=' + JSON.stringify(this.text) + ', annotations=[' +
    ann.join(', ') + '], blockStyle=' + this.blockStyle + ')';
  }
}

/** 源 LinearImageSource：宽/高/屏宽 <1 或像素密度 <=0 抛 IllegalArgumentException */
export class LinearImageSource {
  readonly imgUri: string;
  readonly widthPx: number | null;
  readonly heightPx: number | null;
  readonly pixelDensity: number | null;
  readonly screenWidth: number | null;

  constructor(imgUri: string, widthPx: number | null, heightPx: number | null, pixelDensity: number | null,
    screenWidth: number | null) {
    if (widthPx !== null && widthPx < 1) {
      throw new IllegalArgumentException('Width must be positive: ' + widthPx);
    }
    if (heightPx !== null && heightPx < 1) {
      throw new IllegalArgumentException('Height must be positive: ' + heightPx);
    }
    if (pixelDensity !== null && pixelDensity <= 0) {
      throw new IllegalArgumentException('Pixel density must be positive: ' + pixelDensity);
    }
    if (screenWidth !== null && screenWidth < 1) {
      throw new IllegalArgumentException('Screen width must be positive: ' + screenWidth);
    }
    this.imgUri = imgUri;
    this.widthPx = widthPx;
    this.heightPx = heightPx;
    this.pixelDensity = pixelDensity;
    this.screenWidth = screenWidth;
  }

  toString(): string {
    return 'LinearImageSource(imgUri=' + this.imgUri + ', widthPx=' + optNum(this.widthPx) +
      ', heightPx=' + optNum(this.heightPx) + ', pixelDensity=' + optNum(this.pixelDensity) +
      ', screenWidth=' + optNum(this.screenWidth) + ')';
  }
}

/** 源 LinearImage */
export class LinearImage extends LinearElement {
  readonly sources: LinearImageSource[];
  readonly caption: LinearText | null;
  readonly link: string | null;

  constructor(ids: Set<string>, sources: LinearImageSource[], caption: LinearText | null, link: string | null) {
    super(LinearElementType.IMAGE, ids);
    this.sources = sources;
    this.caption = caption;
    this.link = link;
  }

  collectImageUrls(target: Set<string>): void {
    for (let i = 0; i < this.sources.length; i++) {
      target.add(this.sources[i].imgUri);
    }
  }

  toString(): string {
    const src: string[] = [];
    for (let i = 0; i < this.sources.length; i++) {
      src.push(this.sources[i].toString());
    }
    return 'LinearImage(ids=' + linearIdsToString(this.ids) + ', sources=[' + src.join(', ') + '], caption=' +
      nullableToString(this.caption) + ', link=' + optStr(this.link) + ')';
  }
}

/** 源 LinearVideoSource：宽/高 <1 抛 IllegalArgumentException */
export class LinearVideoSource {
  readonly uri: string;
  /** 可能与 uri 不同（如 YouTube：uri 为 embed 地址，link 为观看地址） */
  readonly link: string;
  readonly imageThumbnail: string | null;
  readonly widthPx: number | null;
  readonly heightPx: number | null;
  readonly mimeType: string | null;

  constructor(uri: string, link: string, imageThumbnail: string | null, widthPx: number | null,
    heightPx: number | null, mimeType: string | null) {
    if (widthPx !== null && widthPx < 1) {
      throw new IllegalArgumentException('Width must be positive: ' + widthPx);
    }
    if (heightPx !== null && heightPx < 1) {
      throw new IllegalArgumentException('Height must be positive: ' + heightPx);
    }
    this.uri = uri;
    this.link = link;
    this.imageThumbnail = imageThumbnail;
    this.widthPx = widthPx;
    this.heightPx = heightPx;
    this.mimeType = mimeType;
  }

  toString(): string {
    return 'LinearVideoSource(uri=' + this.uri + ', link=' + this.link + ', imageThumbnail=' +
      optStr(this.imageThumbnail) + ', widthPx=' + optNum(this.widthPx) + ', heightPx=' +
      optNum(this.heightPx) + ', mimeType=' + optStr(this.mimeType) + ')';
  }
}

/** 源 LinearVideo：sources 为空抛 IllegalArgumentException */
export class LinearVideo extends LinearElement {
  readonly sources: LinearVideoSource[];

  constructor(ids: Set<string>, sources: LinearVideoSource[]) {
    super(LinearElementType.VIDEO, ids);
    if (sources.length === 0) {
      throw new IllegalArgumentException('At least one source must be provided');
    }
    this.sources = sources;
  }

  /** 首个非空缩略图 */
  get imageThumbnail(): string | null {
    for (let i = 0; i < this.sources.length; i++) {
      const t: string | null = this.sources[i].imageThumbnail;
      if (t !== null) {
        return t;
      }
    }
    return null;
  }

  get firstSource(): LinearVideoSource {
    return this.sources[0];
  }

  toString(): string {
    const src: string[] = [];
    for (let i = 0; i < this.sources.length; i++) {
      src.push(this.sources[i].toString());
    }
    return 'LinearVideo(ids=' + linearIdsToString(this.ids) + ', sources=[' + src.join(', ') + '])';
  }
}

/** 源 LinearAudioSource */
export class LinearAudioSource {
  readonly uri: string;
  readonly mimeType: string | null;

  constructor(uri: string, mimeType: string | null) {
    this.uri = uri;
    this.mimeType = mimeType;
  }

  toString(): string {
    return 'LinearAudioSource(uri=' + this.uri + ', mimeType=' + optStr(this.mimeType) + ')';
  }
}

/** 源 LinearAudio：sources 为空抛 IllegalArgumentException */
export class LinearAudio extends LinearElement {
  readonly sources: LinearAudioSource[];

  constructor(ids: Set<string>, sources: LinearAudioSource[]) {
    super(LinearElementType.AUDIO, ids);
    if (sources.length === 0) {
      throw new IllegalArgumentException('At least one source must be provided');
    }
    this.sources = sources;
  }

  get firstSource(): LinearAudioSource {
    return this.sources[0];
  }

  toString(): string {
    const src: string[] = [];
    for (let i = 0; i < this.sources.length; i++) {
      src.push(this.sources[i].toString());
    }
    return 'LinearAudio(ids=' + linearIdsToString(this.ids) + ', sources=[' + src.join(', ') + '])';
  }
}

/** 源 LinearListItem（orderedIndex 非 null 表示有序列表中的用户可见序号） */
export class LinearListItem extends LinearElement {
  readonly orderedIndex: number | null;
  readonly content: LinearElement[];

  constructor(ids: Set<string>, orderedIndex: number | null, content: LinearElement[]) {
    super(LinearElementType.LIST_ITEM, ids);
    this.orderedIndex = orderedIndex;
    this.content = content;
  }

  isEmpty(): boolean {
    return this.content.length === 0;
  }

  isNotEmpty(): boolean {
    return this.content.length > 0;
  }

  collectImageUrls(target: Set<string>): void {
    for (let i = 0; i < this.content.length; i++) {
      this.content[i].collectImageUrls(target);
    }
  }

  toString(): string {
    return 'LinearListItem(ids=' + linearIdsToString(this.ids) + ', orderedIndex=' + optNum(this.orderedIndex) +
      ', content=' + linearElementsToString(this.content) + ')';
  }
}

/** 源 LinearListItem.Builder */
export class LinearListItemBuilder {
  ids: Set<string> = new Set<string>();
  orderedIndex: number | null = null;
  private content: LinearElement[] = [];

  add(element: LinearElement): void {
    this.content.push(element);
  }

  build(): LinearListItem {
    return new LinearListItem(this.ids, this.orderedIndex, this.content);
  }
}

/** 源 LinearList（不是 LinearElement；线性化器不产出） */
export class LinearList {
  readonly ordered: boolean;
  readonly items: LinearListItem[];

  constructor(ordered: boolean, items: LinearListItem[]) {
    this.ordered = ordered;
    this.items = items;
  }

  isEmpty(): boolean {
    return this.items.length === 0;
  }

  isNotEmpty(): boolean {
    return this.items.length > 0;
  }

  static build(ordered: boolean, block: (builder: LinearListBuilder) => void): LinearList {
    const b: LinearListBuilder = new LinearListBuilder(ordered);
    block(b);
    return b.build();
  }
}

export class LinearListBuilder {
  private readonly ordered: boolean;
  private items: LinearListItem[] = [];

  constructor(ordered: boolean) {
    this.ordered = ordered;
  }

  add(item: LinearListItem): void {
    this.items.push(item);
  }

  build(): LinearList {
    return new LinearList(this.ordered, this.items);
  }
}

/** 源 LinearBlockQuote（实际只装 LinearText） */
export class LinearBlockQuote extends LinearElement {
  readonly cite: string | null;
  readonly content: LinearElement[];

  constructor(ids: Set<string>, cite: string | null, content: LinearElement[]) {
    super(LinearElementType.BLOCK_QUOTE, ids);
    this.cite = cite;
    this.content = content;
  }

  collectImageUrls(target: Set<string>): void {
    for (let i = 0; i < this.content.length; i++) {
      this.content[i].collectImageUrls(target);
    }
  }

  toString(): string {
    return 'LinearBlockQuote(ids=' + linearIdsToString(this.ids) + ', cite=' + optStr(this.cite) + ', content=' +
    linearElementsToString(this.content) + ')';
  }
}
