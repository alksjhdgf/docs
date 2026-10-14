/**
 * LinearArticle.ets —— 源 model/html/LinearStuff.kt + LinearTextAnnotation.kt：线性化文章模型（纯数据）。
 *
 * - LinearElement 判别联合：抽象基类 + 子类（instanceof 窄化，或读 elementType 判别字段）：
 *   LinearText / LinearImage / LinearVideo / LinearAudio / LinearListItem / LinearBlockQuote / LinearTable。
 * - LinearList 照源保留（不是 LinearElement；线性化器不产出它，列表项平铺为顶层 LinearListItem）。
 * - 表格坐标：源 ArrayMap<Coordinate, …> → Map<string, …>（key = `${row},${col}`，ArkTS Map 以引用比较对象键）。
 * - 注解闭区间 [start, end]，endExclusive = end + 1。
 * - toString() 输出规范化描述（集合/表格单元按确定顺序），用于相等比较（≙ Kotlin data class equals）。
 */
import { linearElementsToString, LinearElement } from './LinearElements';

export {
  LinearTextBlockStyle,
  shouldSoftWrap,
  LinearTextAnnotationKind,
  LinearTextAnnotationData,
  LinearTextAnnotationLink,
  LinearTextAnnotationFont,
  LinearTextAnnotationH1,
  LinearTextAnnotationH2,
  LinearTextAnnotationH3,
  LinearTextAnnotationH4,
  LinearTextAnnotationH5,
  LinearTextAnnotationH6,
  LinearTextAnnotationBold,
  LinearTextAnnotationItalic,
  LinearTextAnnotationMonospace,
  LinearTextAnnotationUnderline,
  LinearTextAnnotationStrikethrough,
  LinearTextAnnotationSuperscript,
  LinearTextAnnotationSubscript,
  LinearTextAnnotationCode,
  LinearTextAnnotation
} from './LinearTextAnnotation';
export {
  LinearElementType,
  linearIdsToString,
  linearElementsToString,
  LinearElement,
  LinearText,
  LinearImageSource,
  LinearImage,
  LinearVideoSource,
  LinearVideo,
  LinearAudioSource,
  LinearAudio,
  LinearListItem,
  LinearListItemBuilder,
  LinearList,
  LinearListBuilder,
  LinearBlockQuote
} from './LinearElements';
export {
  LinearTableCellItemType,
  Coordinate,
  coordinateKey,
  LinearTableCellItem,
  LinearTable,
  LinearTableBuilder
} from './LinearTable';

// =============================================================================================
// 文章
// =============================================================================================

/** 源 data class LinearArticle(elements) */
export class LinearArticle {
  readonly elements: LinearElement[];
  /** 每个 id → 所在顶层元素下标（后出现的覆盖先出现的，≙ Kotlin toMap） */
  readonly idToIndex: Map<string, number>;
  private imageUrlsCache: Set<string> | null = null;

  constructor(elements: LinearElement[]) {
    this.elements = elements;
    const m: Map<string, number> = new Map<string, number>();
    for (let index = 0; index < elements.length; index++) {
      elements[index].ids.forEach((id: string) => {
        m.set(id, index);
      });
    }
    this.idToIndex = m;
  }

  /** 递归收集全部图片候选 URL（lazy，首次访问计算后缓存） */
  get imageUrls(): Set<string> {
    if (this.imageUrlsCache === null) {
      const s: Set<string> = new Set<string>();
      for (let i = 0; i < this.elements.length; i++) {
        this.elements[i].collectImageUrls(s);
      }
      this.imageUrlsCache = s;
    }
    return this.imageUrlsCache as Set<string>;
  }

  containsImageUrl(url: string): boolean {
    return this.imageUrls.has(url);
  }

  toString(): string {
    return 'LinearArticle(elements=' + linearElementsToString(this.elements) + ')';
  }
}

/** 源 LinearElement.ids() */
export function idsOf(element: LinearElement): Set<string> {
  return element.ids;
}

/** 便捷：Kotlin setOf(...) */
export function idSet(ids: string[] = []): Set<string> {
  return new Set<string>(ids);
}
