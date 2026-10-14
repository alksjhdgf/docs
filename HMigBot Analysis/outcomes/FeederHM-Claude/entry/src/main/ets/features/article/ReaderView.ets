/**
 * ReaderView —— 源 ui/compose/feedarticle/ReaderView.kt：SelectionContainer > ColumnScrollbar > Column(verticalScroll,
 * spacedBy 16dp, 水平 margin) 内依次：头部块（标题 / 源名链接 / 作者日期 / 阅读时长）、附件链接、头图、正文槽、底部 92dp。
 *
 *  - 滚动条：源 nanihadesuka ColumnScrollbar → Scroll 自带滚动条（outlineVariant 着色）。
 *  - 文本选择：源 SelectionContainer → 各 Text.copyOption(LocalDevice)（AR-A36）。
 *  - 正文槽 articleBody 必须直接产出若干子组件（不包外层容器）：正文 ColumnArticleContent 的根即本 Column 的直接子节点，
 *    其 onAreaChange 的 position.y 即滚动内容坐标，锚点表（ArticleAnchors）据此平滑滚动到目标元素（AR-A34）。
 *  - 滚动位置：onDidScroll 上报偏移（页面 500ms 防抖保存）；内容高度足够后一次性恢复保存的位置（AR-A48）。
 *  - 视口/内容高度上报给页面用于翻页模式（AR-A46/A47）。
 */
import { Enclosure } from '../../core/repo/RepoTypes';
import { FeederImage } from '../../ui/common/CommonWidgets';
import { readerScaleMode } from '../../ui/common/ArticleMedia';
import { pluralText, readTimeClock } from '../../ui/common/FeedItemText';
import { FeederTheme, isRtlText } from '../../ui/common/Theme';
import { FeederTypography, M3Type, textStyle } from '../../ui/common/Typography';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

/** 源 ContentAlpha.medium */
const MEDIUM_ALPHA: number = 0.74;

@Builder
function emptyArticleBody() {
}

/** 源 Modifier.verticalScroll 容器的度量（视口高度 / 内容高度 / 当前偏移，vp） */
export class ReaderScrollMetrics {
  viewportHeight: number = 0;
  contentHeight: number = 0;

  maxOffset(): number {
    return Math.max(0, this.contentHeight - this.viewportHeight);
  }
}

@ComponentV2
export struct ReaderView {
  @Param scroller: Scroller = new Scroller();
  @Param metrics: ReaderScrollMetrics = new ReaderScrollMetrics();
  @Param readTimeSecs: number = 0;
  @Param enclosure: Enclosure = new Enclosure();
  @Param articleTitle: string = '';
  @Param feedTitle: string = '';
  /** null → 不显示作者/日期行 */
  @Param authorDate: string | null = null;
  @Param showImage: boolean = false;
  @Param imageUrl: string = '';
  /** 进入页面时要恢复的滚动位置（vp） */
  @Param initialScrollPosition: number = 0;
  @Event onEnclosureClick: () => void = () => {
    console.info('TODO:enclosureClick:ReaderView');
  };
  @Event onFeedTitleClick: () => void = () => {
    console.info('TODO:feedTitleClick:ReaderView');
  };
  @Event onScrollOffset: (y: number) => void = (y: number) => {
    console.info('TODO:scrollOffset:ReaderView ' + y);
  };
  @BuilderParam articleBody: () => void = emptyArticleBody;
  private restored: boolean = false;

  private maxWidth(): number {
    return FeederTheme.dimens.maxReaderWidth;
  }

  private readTimeText(): string {
    const secs: number = this.readTimeSecs;
    return pluralText(this.getUIContext(), $r('app.plural.n_minutes'), Math.floor(secs / 60), readTimeClock(secs),
      'minutes');
  }

  private openLabel(): ResourceStr {
    if (this.enclosure.name.trim().length === 0) {
      return $r('app.string.open_enclosed_media');
    }
    return $r('app.string.open_enclosed_media_file', this.enclosure.name);
  }

  /** 内容足够高后恢复保存的阅读位置（源 rememberScrollState(initial = viewModel.scrollPosition)） */
  private tryRestore(): void {
    if (this.restored) {
      return;
    }
    const target: number = this.initialScrollPosition;
    if (target <= 0) {
      this.restored = true;
      return;
    }
    const max: number = this.metrics.maxOffset();
    if (this.metrics.viewportHeight <= 0 || max <= 0) {
      return;
    }
    this.scroller.scrollTo({ xOffset: 0, yOffset: Math.min(target, max), animation: false });
    if (max >= target) {
      this.restored = true;
    }
  }

  @Builder
  headerBlock() {
    Column({ space: 8 }) {
      if (this.articleTitle.trim().length > 0) {
        Text(this.articleTitle)
          .attributeModifier(textStyle(M3Type.headlineLarge, false, FeederTheme.colors.onBackground))
          .direction(isRtlText(this.articleTitle) ? Direction.Rtl : Direction.Ltr)
          .textAlign(TextAlign.Start)
          .width('100%')
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(new FeederEditMenuOptions((): string => this.articleTitle))
      }
      // 源 ProvideScaledText(titleMedium.merge(LinkTextStyle()))：primary + 下划线，可点 → 该源 Feed 页（AR-A25）
      Text(this.feedTitle)
        .attributeModifier(textStyle(M3Type.titleMedium, true, FeederTheme.colors.primary))
        .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
        .direction(isRtlText(this.feedTitle) ? Direction.Rtl : Direction.Ltr)
        .textAlign(TextAlign.Start)
        .width('100%')
        .accessibilityText(this.feedTitle)
        .accessibilityDescription($r('app.string.go_to_feed', this.feedTitle))
        .onClick(() => {
          this.onFeedTitleClick();
        })
      if (this.authorDate !== null) {
        Text(this.authorDate as string)
          .attributeModifier(textStyle(M3Type.titleMedium, true, FeederTheme.colors.onBackground))
          .opacity(MEDIUM_ALPHA)
          .direction(isRtlText(this.authorDate as string) ? Direction.Rtl : Direction.Ltr)
          .textAlign(TextAlign.Start)
          .width('100%')
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(new FeederEditMenuOptions((): string => this.authorDate ?? ''))
      }
      if (this.readTimeSecs > 0) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.timer'))
            .fontSize(24 * FeederTypography.fontScale)
            .fontColor([FeederTheme.colors.onBackground])
          Text(this.readTimeText())
            .attributeModifier(textStyle(M3Type.titleMedium, true, FeederTheme.colors.onBackground))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(new FeederEditMenuOptions((): string => this.readTimeText()))
        }
        .width('100%')
        .opacity(MEDIUM_ALPHA)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: this.maxWidth() })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        this.headerBlock()

        // 源 enclosure.present && !isImage → `Open enclosed media` / `Open <name>`（AR-A30/A31）
        if (this.enclosure.present && !this.enclosure.isImage) {
          Text(this.openLabel())
            .attributeModifier(textStyle(M3Type.bodyLarge, true, FeederTheme.colors.primary))
            .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
            .textAlign(TextAlign.Start)
            .width('100%')
            .constraintSize({ maxWidth: this.maxWidth() })
            .onClick(() => {
              this.onEnclosureClick();
            })
        }

        // 头图（AR-A33）：占位 picture / 错误 exclamationmark_circle（FeederImage 内置）
        if (this.showImage) {
          Stack({ alignContent: Alignment.Center }) {
            FeederImage({
              url: this.imageUrl,
              scaleMode: readerScaleMode(),
              boxWidth: '100%',
              altText: this.enclosure.name
            })
          }
          .width('100%')
          .constraintSize({ maxWidth: this.maxWidth() })
          .clip(true)
          .accessibilityDescription($r('app.string.article_image'))
        }

        this.articleBody()

        // Bottom spacing
        Column()
          .width('100%')
          .height(92)
      }
      .width('100%')
      .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin })
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.metrics.contentHeight = newArea.height as number;
        this.tryRestore();
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .scrollBarColor(FeederTheme.colors.outlineVariant)
    .edgeEffect(EdgeEffect.Fade)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.metrics.viewportHeight = newArea.height as number;
      this.tryRestore();
    })
    .onDidScroll(() => {
      this.onScrollOffset(this.scroller.currentOffset().yOffset);
    })
    .id('readerColumn')
  }
}
