/**
 * ArticleBlocks.ets —— 源 ui/compose/html/LinearArticleContent.kt 的鸿蒙实现（阅读器正文唯一渲染入口）。
 *
 * - ColumnArticleContent（源同名，LAC:153）：按 LinearArticle.elements 顺序逐块渲染；每块宽度
 *   min(容器宽, maxReaderWidth 600/640) 且水平居中；块间距默认 16（源 ReaderView Column spacedBy(16.dp)，
 *   源中块直接排在 ReaderView 的 Column 内，这里由本容器承担）；每块回报其在文章容器内的 y（锚点跳转用）。
 * - ArticleElementView（源 LinearElementContent）分派：ListItem / Image / BlockQuote / Text(TEXT→段落，
 *   PRE_FORMATTED 与 CODE_BLOCK→代码块) / Table / Audio / Video。
 * - 图片/视频/音频块在 ArticleMedia.ets（按单文件 ≤600 行拆出）。
 * - 表格：HtmlTable.TableLayout（列宽/行高算法照源），超宽整体横滚；斑马纹/竖分隔线/HEADER 加粗照源。
 * - 文本可长按选择（Text.copyOption）；图片/视频区域无文本可选。
 */
import {
  LinearArticle,
  LinearElement,
  LinearText,
  LinearTextBlockStyle,
  LinearImage,
  LinearVideo,
  LinearAudio,
  LinearListItem,
  LinearBlockQuote,
  LinearTable,
  LinearTableCellItem,
  LinearTableCellItemType
} from '../../core/html/LinearArticle';
import { FeederTheme, surfaceAtElevation } from './Theme';
import { FeederTypography, M3Type, TextStyleModifier, WEIGHT_LIGHT, WEIGHT_BOLD } from './Typography';
import {
  LinearTextContent,
  ArticleTextStyle,
  ColorRole,
  colorOfRole,
  ARTICLE_BODY_STYLE,
  ArticleLinkClick,
  linkTargetIndex
} from './RichText';
import { ArticleAnchors } from './ArticleLinks';
import { TableLayout, TableData, TableCell, linearTableToTableData, tableContainsImage } from './HtmlTable';
import { ImageBlock, VideoBlock, AudioBlock } from './ArticleMedia';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

/** M3 shapes.medium 圆角 */
const SHAPE_MEDIUM_RADIUS: number = 12;

function hashString(s: string): number {
  let h: number = 0;
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(h, 31) + s.charCodeAt(i)) | 0;
  }
  return h;
}

/** 嵌套元素 ForEach key：内容变化即换 key（图片源选择等只在创建时计算的状态随之重建） */
function nestedElementKey(el: LinearElement, i: number): string {
  return i + '_' + el.elementType + '_' + hashString(el.toString());
}

const articleGenerations: WeakMap<LinearArticle, number> = new WeakMap<LinearArticle, number>();
let articleGenerationCounter: number = 0;

function articleGeneration(article: LinearArticle): number {
  const g: number | undefined = articleGenerations.get(article);
  if (g !== undefined) {
    return g;
  }
  articleGenerationCounter++;
  articleGenerations.set(article, articleGenerationCounter);
  return articleGenerationCounter;
}

const EMPTY_TEXT: LinearText = new LinearText(new Set<string>(), '', LinearTextBlockStyle.TEXT);

/** 引用：bodyLarge + Light；颜色取 Surface 的内容色 onSurface */
const QUOTE_STYLE: ArticleTextStyle = ArticleTextStyle.of(M3Type.bodyLarge, WEIGHT_LIGHT, ColorRole.ON_SURFACE);
/** 代码块：bodyLarge + OnCodeBlockBackground(onSurfaceVariant) */
const CODE_STYLE: ArticleTextStyle = ArticleTextStyle.of(M3Type.bodyLarge, -1, ColorRole.ON_SURFACE_VARIANT);

// =============================================================================================
// 各块
// =============================================================================================

/** 源 LinearListItemContent：Row(spacedBy 8, Top) [ "N." | "•" , Column(spacedBy 8) 递归内容 ] */
@ComponentV2
struct ListItemBlock {
  @Param listItem: LinearListItem = new LinearListItem(new Set<string>(), null, []);
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param allowHorizontalScroll: boolean = true;
  @Param fillWidth: boolean = true;
  @Param availWidth: number = 360;
  @Param textStyle: ArticleTextStyle = ARTICLE_BODY_STYLE;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:ListItemBlock ' + url + ' ' + String(index));
  };

  private marker(): string {
    return this.listItem.orderedIndex !== null ? this.listItem.orderedIndex + '.' : '•';
  }

  build() {
    Row({ space: 8 }) {
      // 源标记 Text 不在 ProvideScaledText 内：不随 fontScale 缩放
      Text(this.marker())
        .attributeModifier(new TextStyleModifier(this.textStyle.spec.withWeight(this.textStyle.effectiveWeight()),
          FeederTypography.sansFamily, 1.0, colorOfRole(this.textStyle.colorRole)))
      Column({ space: 8 }) {
        ForEach(this.listItem.content, (el: LinearElement) => {
          ArticleElementView({
            element: el,
            idToIndex: this.idToIndex,
            allowHorizontalScroll: this.allowHorizontalScroll,
            fillWidth: this.fillWidth,
            availWidth: this.availWidth,
            textStyle: this.textStyle,
            onLinkClick: (url: string, index: number | null): void => {
              this.onLinkClick(url, index);
            }
          })
        }, (el: LinearElement, i: number) => nestedElementKey(el, i))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(this.fillWidth ? 1 : 0)
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }
}

/** 源 LinearBlockQuoteContent：只渲染内容中的 LinearText；cite 右对齐可点 */
@ComponentV2
struct BlockQuoteBlock {
  @Param blockQuote: LinearBlockQuote = new LinearBlockQuote(new Set<string>(), null, []);
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param fillWidth: boolean = true;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:BlockQuoteBlock ' + url + ' ' + String(index));
  };

  private texts(): LinearText[] {
    const out: LinearText[] = [];
    for (let i = 0; i < this.blockQuote.content.length; i++) {
      const el: LinearElement = this.blockQuote.content[i];
      if (el instanceof LinearText) {
        out.push(el as LinearText);
      }
    }
    return out;
  }

  private clickCite(): void {
    const cite: string | null = this.blockQuote.cite;
    if (cite !== null) {
      this.onLinkClick(cite, linkTargetIndex(cite, this.idToIndex));
    }
  }

  build() {
    // 外层：源 modifier.padding(start = 8.dp)
    Column() {
      Column({ space: 8 }) {
        ForEach(this.texts(), (t: LinearText) => {
          LinearTextContent({
            linearText: t,
            idToIndex: this.idToIndex,
            textStyle: QUOTE_STYLE,
            fillWidth: this.fillWidth,
            onLinkClick: (url: string, index: number | null): void => {
              this.onLinkClick(url, index);
            }
          })
        }, (t: LinearText, i: number) => nestedElementKey(t, i))
        if (this.blockQuote.cite !== null) {
          Text(this.blockQuote.cite as string)
            .attributeModifier(new TextStyleModifier(M3Type.bodySmall, FeederTypography.sansFamily, 1.0,
              FeederTheme.colors.tertiary))
            .fontStyle(FontStyle.Italic)
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(new FeederEditMenuOptions((): string => this.blockQuote.cite ?? ''))
            .alignSelf(ItemAlign.End)
            .onClick(() => {
              this.clickCite();
            })
        }
      }
      .width(this.fillWidth ? '100%' : 'auto')
      .alignItems(HorizontalAlign.Start)
      .padding(8)
      .backgroundColor(surfaceAtElevation(FeederTheme.colors, 2))
      .borderRadius(SHAPE_MEDIUM_RADIUS)
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 8 })
  }
}

/** 源 CodeBlock：surfaceVariant 圆角容器、onSurfaceVariant、不换行；allowHorizontalScroll 时可横滚 */
@ComponentV2
struct CodeBlock {
  @Param linearText: LinearText = EMPTY_TEXT;
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param allowHorizontalScroll: boolean = true;
  @Param fillWidth: boolean = true;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:CodeBlock ' + url + ' ' + String(index));
  };

  @Builder
  codeSurface() {
    Column() {
      LinearTextContent({
        linearText: this.linearText,
        idToIndex: this.idToIndex,
        textStyle: CODE_STYLE,
        softWrap: false,
        fillWidth: false,
        onLinkClick: (url: string, index: number | null): void => {
          this.onLinkClick(url, index);
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(8)
    .backgroundColor(FeederTheme.colors.surfaceVariant)
    .borderRadius(SHAPE_MEDIUM_RADIUS)
  }

  build() {
    // 源 Box(contentAlignment = TopStart)
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.allowHorizontalScroll) {
        Scroll() {
          this.codeSurface()
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .align(Alignment.TopStart)
        .width('100%')
      } else {
        this.codeSurface()
      }
    }
    .width(this.fillWidth ? '100%' : 'auto')
  }
}

/** 表格单元格（源 LinearTableContent content lambda） */
@ComponentV2
struct TableCellView {
  @Param linearTable: LinearTable = new LinearTable(new Set<string>(), 0, 0, new Map<string, LinearTableCellItem>());
  @Param cell: TableCell = new TableCell(0, 1, 0, 1);
  @Param hasImage: boolean = false;
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param availWidth: number = 360;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:TableCellView ' + url + ' ' + String(index));
  };

  private item(): LinearTableCellItem | null {
    return this.linearTable.cellAt(this.cell.row, this.cell.column);
  }

  private contents(): LinearElement[] {
    const it: LinearTableCellItem | null = this.item();
    return it === null ? [] : it.content;
  }

  /** HEADER：bodyLarge + Bold；颜色按行奇偶（偶 onBackground，奇 HEADER→onSurfaceVariant / DATA→onSurface） */
  private cellStyle(): ArticleTextStyle {
    const it: LinearTableCellItem | null = this.item();
    const even: boolean = this.cell.row % 2 === 0;
    if (it !== null && it.type === LinearTableCellItemType.HEADER) {
      return ArticleTextStyle.of(M3Type.bodyLarge, WEIGHT_BOLD,
        even ? ColorRole.ON_BACKGROUND : ColorRole.ON_SURFACE_VARIANT);
    }
    return ArticleTextStyle.of(M3Type.bodyLarge, -1, even ? ColorRole.ON_BACKGROUND : ColorRole.ON_SURFACE);
  }

  private cellBackground(): string {
    // if table contains image, don't color rows alternatively
    return this.cell.row % 2 === 0 || this.hasImage ? FeederTheme.colors.background :
    FeederTheme.colors.surfaceVariant;
  }

  /** 非最后一列右侧 1vp outlineVariant 竖线（多列时才出现）；无横线 */
  private cellBorder(): BorderOptions {
    const showDivider: boolean = this.cell.column < this.linearTable.colCount - 1;
    const w: EdgeWidths = { right: showDivider ? 1 : 0 };
    const c: EdgeColors = { right: FeederTheme.colors.outlineVariant };
    const b: BorderOptions = { width: w, color: c };
    return b;
  }

  build() {
    Column({ space: 4 }) {
      ForEach(this.contents(), (el: LinearElement) => {
        ArticleElementView({
          element: el,
          idToIndex: this.idToIndex,
          allowHorizontalScroll: false,
          fillWidth: false,
          availWidth: this.availWidth,
          textStyle: this.cellStyle(),
          onLinkClick: (url: string, index: number | null): void => {
            this.onLinkClick(url, index);
          }
        })
      }, (el: LinearElement, i: number) => nestedElementKey(el, i))
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .backgroundColor(this.cellBackground())
    .border(this.cellBorder())
    .padding(4)
  }
}

/** 源 LinearTableContent + layouts/Table */
@ComponentV2
struct TableBlock {
  @Param linearTable: LinearTable = new LinearTable(new Set<string>(), 0, 0, new Map<string, LinearTableCellItem>());
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param allowHorizontalScroll: boolean = true;
  @Param fillWidth: boolean = true;
  @Param availWidth: number = 360;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:TableBlock ' + url + ' ' + String(index));
  };

  @Computed
  get tableData(): TableData {
    return linearTableToTableData(this.linearTable);
  }

  @Computed
  get hasImage(): boolean {
    return tableContainsImage(this.linearTable);
  }

  @Builder
  cellsBuilder() {
    ForEach(this.tableData.cells, (cell: TableCell) => {
      TableCellView({
        linearTable: this.linearTable,
        cell: cell,
        hasImage: this.hasImage,
        idToIndex: this.idToIndex,
        availWidth: this.availWidth,
        onLinkClick: (url: string, index: number | null): void => {
          this.onLinkClick(url, index);
        }
      })
    }, (cell: TableCell) => cell.key())
  }

  build() {
    // 源 Box(contentAlignment = Center)：窄表居中为源本意
    Stack({ alignContent: Alignment.Center }) {
      if (this.allowHorizontalScroll) {
        Scroll() {
          TableLayout({
            tableData: this.tableData,
            cellsBuilder: (): void => {
              this.cellsBuilder()
            }
          })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .align(Alignment.Center)
        .width('100%')
      } else {
        TableLayout({
          tableData: this.tableData,
          cellsBuilder: (): void => {
            this.cellsBuilder()
          }
        })
      }
    }
    .width(this.fillWidth ? '100%' : 'auto')
  }
}

// =============================================================================================
// 分派（源 LinearElementContent）
// =============================================================================================

@ComponentV2
export struct ArticleElementView {
  @Param element: LinearElement = EMPTY_TEXT;
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  /** 源 allowHorizontalScroll：表格单元格内为 false（代码块/嵌套表格不单独横滚） */
  @Param allowHorizontalScroll: boolean = true;
  /** 是否撑满父宽（表格单元格内为 false：按内容定宽） */
  @Param fillWidth: boolean = true;
  /** 可用宽度 vp（图片源选择 / 表格内图片最大宽） */
  @Param availWidth: number = 360;
  /** 当前文本基础样式（源 LocalTextStyle） */
  @Param textStyle: ArticleTextStyle = ARTICLE_BODY_STYLE;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:ArticleElementView ' + url + ' ' + String(index));
  };

  private forward(url: string, index: number | null): void {
    this.onLinkClick(url, index);
  }

  private isText(): boolean {
    return this.element instanceof LinearText;
  }

  private isPlainText(): boolean {
    return this.isText() && (this.element as LinearText).blockStyle === LinearTextBlockStyle.TEXT;
  }

  build() {
    Column() {
      if (this.element instanceof LinearListItem) {
        ListItemBlock({
          listItem: this.element as LinearListItem,
          idToIndex: this.idToIndex,
          allowHorizontalScroll: this.allowHorizontalScroll,
          fillWidth: this.fillWidth,
          availWidth: this.availWidth,
          textStyle: this.textStyle,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.element instanceof LinearImage) {
        ImageBlock({
          linearImage: this.element as LinearImage,
          idToIndex: this.idToIndex,
          fillWidth: this.fillWidth,
          availWidth: this.availWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.element instanceof LinearBlockQuote) {
        BlockQuoteBlock({
          blockQuote: this.element as LinearBlockQuote,
          idToIndex: this.idToIndex,
          fillWidth: this.fillWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.isPlainText()) {
        LinearTextContent({
          linearText: this.element as LinearText,
          idToIndex: this.idToIndex,
          textStyle: this.textStyle,
          fillWidth: this.fillWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.isText()) {
        // PRE_FORMATTED 与 CODE_BLOCK 都渲染为代码块（源 PreFormattedBlock 已注释）
        CodeBlock({
          linearText: this.element as LinearText,
          idToIndex: this.idToIndex,
          allowHorizontalScroll: this.allowHorizontalScroll,
          fillWidth: this.fillWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.element instanceof LinearTable) {
        TableBlock({
          linearTable: this.element as LinearTable,
          idToIndex: this.idToIndex,
          allowHorizontalScroll: this.allowHorizontalScroll,
          fillWidth: this.fillWidth,
          availWidth: this.availWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.element instanceof LinearAudio) {
        AudioBlock({
          linearAudio: this.element as LinearAudio,
          fillWidth: this.fillWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      } else if (this.element instanceof LinearVideo) {
        VideoBlock({
          linearVideo: this.element as LinearVideo,
          fillWidth: this.fillWidth,
          availWidth: this.availWidth,
          onLinkClick: (url: string, index: number | null): void => {
            this.forward(url, index);
          }
        })
      }
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .alignItems(HorizontalAlign.Start)
  }
}

// =============================================================================================
// 入口（源 ColumnArticleContent）
// =============================================================================================

/**
 * 正文：放在页面的纵向 Scroll 内容 Column 中。
 * 锚点：传入 anchors（RichText.ArticleAnchors，持有页面 Scroll 的 Scroller）则自动登记文章容器偏移与各块偏移；
 * 也可监听 onElementPosition / onArticleTop 自行登记。位置为内容坐标（不随滚动变化）。
 */
@ComponentV2
export struct ColumnArticleContent {
  @Param article: LinearArticle = new LinearArticle([]);
  /** 块间距（源 ReaderView Column spacedBy(16.dp)） */
  @Param elementSpacing: number = 16;
  @Param anchors: ArticleAnchors | null = null;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:ColumnArticleContent ' + url + ' ' + String(index));
  };
  /** 元素 index 在文章容器内的 y（vp） */
  @Event onElementPosition: (index: number, y: number) => void = (index: number, y: number) => {
    console.info('TODO:elementPosition:ColumnArticleContent ' + index + ' ' + y);
  };
  /** 文章容器在其父容器内的 y（vp） */
  @Event onArticleTop: (y: number) => void = (y: number) => {
    console.info('TODO:articleTop:ColumnArticleContent ' + y);
  };
  @Local containerWidth: number = 0;

  @Monitor('article')
  onArticleChanged(monitor: IMonitor): void {
    if (this.anchors !== null) {
      (this.anchors as ArticleAnchors).reset();
    }
  }

  private availWidth(): number {
    const w: number = this.containerWidth > 0 ? this.containerWidth : FeederTheme.windowWidthVp;
    return Math.min(w, FeederTheme.dimens.maxReaderWidth);
  }

  private reportElement(index: number, y: number): void {
    if (this.anchors !== null) {
      (this.anchors as ArticleAnchors).setElementPosition(index, y);
    }
    this.onElementPosition(index, y);
  }

  private reportTop(y: number): void {
    if (this.anchors !== null) {
      (this.anchors as ArticleAnchors).setArticleTop(y);
    }
    this.onArticleTop(y);
  }

  build() {
    Column({ space: this.elementSpacing }) {
      ForEach(this.article.elements, (el: LinearElement, index: number) => {
        // 源 BoxWithConstraints(fillMaxWidth, contentAlignment = Center)：块水平居中为源本意
        Column() {
          Column() {
            ArticleElementView({
              element: el,
              idToIndex: this.article.idToIndex,
              allowHorizontalScroll: true,
              fillWidth: true,
              availWidth: this.availWidth(),
              textStyle: ARTICLE_BODY_STYLE,
              onLinkClick: (url: string, i: number | null): void => {
                this.onLinkClick(url, i);
              }
            })
          }
          .width('100%')
          .constraintSize({ maxWidth: FeederTheme.dimens.maxReaderWidth })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.reportElement(index, newArea.position.y as number);
        })
      }, (el: LinearElement, index: number) => articleGeneration(this.article) + '_' + index)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.containerWidth = newArea.width as number;
      this.reportTop(newArea.position.y as number);
    })
  }
}
