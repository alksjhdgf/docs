/**
 * Spec selection sheet content (source: core/ui/component/modal/SpecSelectModal.kt) — GOODS-A06~A09.
 *
 * Put `SpecSelectSheet` at the root of a bindSheet builder and open it with
 * `CommerceSheet.options(onDismiss, onExpanded)` (see CommerceSheet.ets). The page/VM owns:
 *  - specUiState ('loading' | 'success' | 'error') + specs: spec list request, started from onExpanded
 *    (GOODS-A06: only after the sheet is fully shown, not again after a success);
 *  - selectedSpec: last spec reported through onSpecSelected (restores the selection on reopen);
 *  - optionally a `SpecSelectState` instance (quantity + grid/list mode): pass the same instance every
 *    time to keep them across openings like the source's remember{} state; omitted → fresh per opening.
 *
 * Behaviour:
 *  - Header: image (selected spec's first image or goods mainPic), price (spec price or goods price),
 *    `已选：name` / `未选择`, `库存：stock` (0 when nothing selected).
 *  - `规格分类` + grid/list toggle; grid = 3 per row (image 100 + 46vp name), list = 50vp image + name + `¥price`.
 *  - Tap selects; tapping the selected spec again deselects (onSpecSelected is still called, as in the source).
 *  - `数量` stepper (min 1) only once a spec is selected.
 *  - `加入购物车` / `立即购买` enabled only when a spec is selected and its stock > 0; on tap they emit a
 *    SelectedGoods {goodsId, goodsInfo, spec, count} and then onDismiss.
 */
import { display } from '@kit.ArkUI';
import { Goods, GoodsSpec } from '../../model/Goods';
import { SelectedGoods } from '../../model/Order';
import { Dimens } from '../../designsystem/Dimens';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { BottomModal } from '../widget/BottomSheet';
import { NetWorkImage } from '../widget/Images';
import { WeDivider, TitleWithLine } from '../widget/AppCard';
import { PriceText, AppTextStyles, AppTextSize, AppTextType } from '../widget/Texts';
import { QuantityStepper } from '../widget/QuantityStepper';
import { AppButton, AppButtonSize, AppButtonStyle, AppButtonDefaults, AppButtonType } from '../widget/Buttons';
import { PageLoading, EmptyNetwork } from '../base/StateViews';
import { CommerceSheet } from './CommerceSheet';

const ITEMS_PER_ROW: number = 3;
/** Reserved height around the spec area (header ~120 + title/gaps ~60 + quantity ~60 + buttons ~60 + margin ~80) */
const RESERVED_HEIGHT: number = 380;
const MIN_SPEC_HEIGHT: number = 200;
const STATE_HEIGHT: number = 300;
const SWITCH_MS: number = 300;

/** remember{} state of SpecSelectModal that outlives one opening when the caller keeps the instance. */
@ObservedV2
export class SpecSelectState {
  @Trace quantity: number = 1;
  /** true = grid, false = list */
  @Trace isGridMode: boolean = true;
}

/** One grid row: up to 3 specs with their absolute indexes; -1 = invisible filler */
class SpecRow {
  key: string = '';
  indexes: number[] = [];
}

@ComponentV2
export struct SpecSelectSheet {
  @Param goods: Goods | null = null;
  @Param specUiState: string = 'loading';
  @Param specs: GoodsSpec[] = [];
  @Param selectedSpec: GoodsSpec | null = null;
  @Param sheetState: SpecSelectState = new SpecSelectState();
  @Event onDismiss: () => void = () => {
  };
  @Event onSpecSelected: (spec: GoodsSpec) => void = (spec: GoodsSpec) => {
  };
  @Event onAddToCart: (goods: SelectedGoods) => void = (goods: SelectedGoods) => {
  };
  @Event onBuyNow: (goods: SelectedGoods) => void = (goods: SelectedGoods) => {
  };
  @Event onRetry: () => void = () => {
  };
  @Local selectedSpecIndex: number = -1;
  @Local currentSpec: GoodsSpec | null = null;
  @Local maxSpecHeight: number = MIN_SPEC_HEIGHT;

  aboutToAppear(): void {
    this.currentSpec = this.selectedSpec;
    this.syncSelectedIndex();
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const screenH: number = this.getUIContext().px2vp(d.height);
      this.maxSpecHeight = Math.max(screenH - RESERVED_HEIGHT, MIN_SPEC_HEIGHT);
    } catch (e) {
      this.maxSpecHeight = MIN_SPEC_HEIGHT;
    }
  }

  /** remember(selectedSpec) { selectedSpec } */
  @Monitor('selectedSpec')
  onSelectedSpecChanged(): void {
    this.currentSpec = this.selectedSpec;
    this.syncSelectedIndex();
  }

  /** LaunchedEffect(visible, uiState): restore the index of the externally selected spec after loading */
  @Monitor('specUiState', 'specs')
  onSpecsChanged(): void {
    this.syncSelectedIndex();
  }

  private syncSelectedIndex(): void {
    if (this.specUiState !== 'success' || this.selectedSpec === null) {
      return;
    }
    const target: GoodsSpec = this.selectedSpec as GoodsSpec;
    const index: number = this.specs.findIndex((s: GoodsSpec) => s.id === target.id);
    if (index >= 0) {
      this.selectedSpecIndex = index;
      this.currentSpec = target;
    }
  }

  private selectSpec(index: number, spec: GoodsSpec): void {
    if (index === this.selectedSpecIndex) {
      this.selectedSpecIndex = -1;
      this.currentSpec = null;
      this.onSpecSelected(spec); // source notifies even on deselect
    } else {
      this.selectedSpecIndex = index;
      this.currentSpec = spec;
      this.onSpecSelected(spec);
    }
  }

  private buildSelectedGoods(spec: GoodsSpec): SelectedGoods {
    const sg: SelectedGoods = new SelectedGoods();
    sg.goodsId = spec.goodsId;
    sg.goodsInfo = this.goods;
    sg.spec = spec;
    sg.count = this.sheetState.quantity;
    return sg;
  }

  private buttonEnabled(): boolean {
    return this.currentSpec !== null && (this.currentSpec as GoodsSpec).stock > 0;
  }

  private specImage(spec: GoodsSpec): string {
    if (spec.images !== null && spec.images.length > 0) {
      return spec.images[0];
    }
    return this.goods !== null ? (this.goods as Goods).mainPic : '';
  }

  private goodsMainPic(): string {
    return this.goods !== null ? (this.goods as Goods).mainPic : '';
  }

  private goodsPrice(): number {
    return this.goods !== null ? (this.goods as Goods).price : 0;
  }

  private gridRows(): SpecRow[] {
    const rows: SpecRow[] = [];
    for (let i = 0; i < this.specs.length; i += ITEMS_PER_ROW) {
      const row: SpecRow = new SpecRow();
      for (let j = 0; j < ITEMS_PER_ROW; j++) {
        row.indexes.push(i + j < this.specs.length ? i + j : -1);
      }
      row.key = 'r' + i;
      rows.push(row);
    }
    return rows;
  }

  private itemBorderColor(index: number): ResourceColor {
    return index === this.selectedSpecIndex ? ThemeManager.instance.primary : CommerceSheet.outline80();
  }

  private itemBgColor(index: number): ResourceColor {
    return index === this.selectedSpecIndex ? ThemeManager.instance.primaryWithAlpha(0.05) : Color.Transparent;
  }

  private itemTextColor(index: number): ResourceColor {
    return index === this.selectedSpecIndex ? ThemeManager.instance.primary : $r('app.color.text_primary');
  }

  // ------------------------------------------------------------------ header

  @Builder
  headerInfo() {
    Row() {
      NetWorkImage({
        model: this.currentSpec !== null ? this.specImage(this.currentSpec as GoodsSpec) : this.goodsMainPic(),
        imageSize: 100,
        cornerRadius: Dimens.radiusSmall,
        showBackground: true
      })
      Column() {
        PriceText({
          price: this.currentSpec !== null ? (this.currentSpec as GoodsSpec).price : this.goodsPrice(),
          integerTextSize: AppTextSize.DISPLAY_LARGE
        })
        if (this.currentSpec !== null) {
          Text() {
            Span($r('app.string.spec_selected'))
            Span('：' + (this.currentSpec as GoodsSpec).name)
          }
          .margin({ top: Dimens.spaceVerticalSmall })
          .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
          .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
          .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
        } else {
          Text($r('app.string.spec_not_selected'))
            .margin({ top: Dimens.spaceVerticalSmall })
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
        }
        Text() {
          Span($r('app.string.spec_stock'))
          Span('：' + (this.currentSpec !== null ? (this.currentSpec as GoodsSpec).stock : 0))
        }
        .margin({ top: Dimens.spaceVerticalSmall })
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
        .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium })
      // source: Column without alignment = start
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    // source StartRow: Arrangement.Start + CenterVertically
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  // ------------------------------------------------------------------ spec views

  @Builder
  gridItem(index: number) {
    if (index < 0) {
      // invisible filler keeping 3 equal columns
      Column()
        .layoutWeight(1)
        .constraintSize({ minHeight: 130 })
    } else {
      Column() {
        // image: fillMaxWidth × 100, top corners clipped by the item shape
        Column() {
          NetWorkImage({ model: this.specImage(this.specs[index]), showBackground: true })
        }
        .width('100%')
        .height(100)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.specs[index].name)
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
            .fontColor(this.itemTextColor(index))
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(46)
        .padding({ left: Dimens.spaceHorizontalSmall, right: Dimens.spaceHorizontalSmall })
        // source: CenterHorizontally + Arrangement.Center
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 130 })
      // source CenterColumn: CenterHorizontally + Arrangement.Center
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .borderRadius(Dimens.radiusSmall)
      .clip(true)
      .border({ width: 1, color: this.itemBorderColor(index), radius: Dimens.radiusSmall })
      .backgroundColor(this.itemBgColor(index))
      .onClick(() => {
        this.selectSpec(index, this.specs[index]);
      })
    }
  }

  @Builder
  gridContent() {
    Column({ space: Dimens.spaceVerticalSmall }) {
      ForEach(this.gridRows(), (row: SpecRow) => {
        Row({ space: Dimens.spaceVerticalSmall }) {
          ForEach(row.indexes, (index: number) => {
            this.gridItem(index)
          }, (index: number, pos: number) => row.key + '_' + pos + '_' + index)
        }
        .width('100%')
        // FlowRow default vertical alignment = top
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Start)
      }, (row: SpecRow) => row.key + '_' + row.indexes.join(','))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  listContent() {
    Column({ space: Dimens.spaceVerticalMedium }) {
      ForEach(this.specs, (spec: GoodsSpec, index: number) => {
        Row() {
          NetWorkImage({
            model: this.specImage(spec),
            imageSize: 50,
            cornerRadius: Dimens.radiusSmall,
            showBackground: true
          })
          // SmallPaddingColumn (fillMaxWidth, padding 8)
          Column() {
            Text(spec.name)
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_MEDIUM))
              .fontColor(this.itemTextColor(index))
            Text('¥' + spec.price)
              .margin({ top: Dimens.spaceVerticalXSmall })
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
              .fontColor($r('app.color.danger'))
          }
          .layoutWeight(1)
          .margin({ left: Dimens.spaceHorizontalSmall })
          .padding(Dimens.spacePaddingSmall)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(Dimens.spacePaddingSmall)
        // source StartRow: Start + CenterVertically
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .borderRadius(Dimens.radiusSmall)
        .clip(true)
        .border({ width: 1, color: this.itemBorderColor(index), radius: Dimens.radiusSmall })
        .backgroundColor(this.itemBgColor(index))
        .onClick(() => {
          this.selectSpec(index, spec);
        })
      }, (spec: GoodsSpec, index: number) => spec.id + '_' + index)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ------------------------------------------------------------------ bottom

  /** AppButtonBordered(SMALL) filling its weighted slot (the shared widget has no fill-width knob). */
  @Builder
  borderedFillButton(text: ResourceStr, onTap: () => void) {
    Row() {
      Text(text)
        .fontSize(Dimens.fontBodyMedium)
        .fontColor(AppButtonDefaults.colorHex(AppButtonType.DEFAULT))
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .width('100%')
    .height(AppButtonDefaults.height(AppButtonSize.SMALL))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .border({ width: 1, color: AppButtonDefaults.colorHex(AppButtonType.DEFAULT) })
    .borderRadius(AppButtonDefaults.height(AppButtonSize.SMALL) / 2)
    .clip(true)
    .opacity(this.buttonEnabled() ? 1 : 0.5)
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor($r('app.color.press'))
      }
    })
    .onClick(() => {
      if (this.buttonEnabled()) {
        onTap();
      }
    })
    .hitTestBehavior(this.buttonEnabled() ? HitTestMode.Default : HitTestMode.None)
  }

  @Builder
  bottomButtons() {
    Row() {
      Row() {
        this.borderedFillButton($r('app.string.modal_add_to_cart'), () => {
          if (this.currentSpec !== null) {
            this.onAddToCart(this.buildSelectedGoods(this.currentSpec as GoodsSpec));
            this.onDismiss();
          }
        })
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)

      Row() {
        AppButton({
          btnText: $r('app.string.modal_buy_now'),
          btnEnabled: this.buttonEnabled(),
          btnSize: AppButtonSize.SMALL,
          btnStyle: AppButtonStyle.GRADIENT,
          onBtnClick: () => {
            if (this.currentSpec !== null) {
              this.onBuyNow(this.buildSelectedGoods(this.currentSpec as GoodsSpec));
              this.onDismiss();
            }
          }
        })
      }
      .layoutWeight(1)
      .margin({ left: Dimens.spaceHorizontalMedium })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    // source: Row without alignment = top / start
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  // ------------------------------------------------------------------ content

  @Builder
  contentView() {
    Column() {
      if (this.goods !== null) {
        this.headerInfo()
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalMedium)
        WeDivider()
      }
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalMedium)

      // SpaceBetweenRow: `规格分类` + view mode toggle
      Row() {
        TitleWithLine({ titleText: $r('app.string.spec_category') })
        Image(this.sheetState.isGridMode ? $r('app.media.ic_menu_list') : $r('app.media.ic_menu'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor(CommerceSheet.onSurface60())
          .onClick(() => {
            this.sheetState.isGridMode = !this.sheetState.isGridMode;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: Dimens.spaceVerticalMedium })

      // spec area: heightIn(max = screenHeight - 380, ≥ 200) + vertical scroll
      Scroll() {
        // AnimatedContent: fade + scale(0.92) 300ms linear, old and new overlap (Box)
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.sheetState.isGridMode) {
            Column() {
              this.gridContent()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
              .animation({ duration: SWITCH_MS, curve: Curve.Linear }))
          } else {
            Column() {
              this.listContent()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
              .animation({ duration: SWITCH_MS, curve: Curve.Linear }))
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: this.maxSpecHeight })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .align(Alignment.TopStart) // source verticalScroll Column is top aligned (rule 7)

      Row()
        .width('100%')
        .height(Dimens.spaceVerticalLarge)

      // quantity: only with a selected spec (GOODS-A08)
      if (this.currentSpec !== null) {
        Row() {
          TitleWithLine({ titleText: $r('app.string.quantity') })
          QuantityStepper({
            quantity: this.sheetState.quantity,
            minValue: 1,
            onQuantityChanged: (value: number) => {
              this.sheetState.quantity = value < 1 ? 1 : value;
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: Dimens.spaceVerticalLarge })
      }

      this.bottomButtons()
    }
    .width('100%')
    // source WrapColumn: Arrangement.Top + Alignment.Start
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  body() {
    if (this.specUiState === 'loading') {
      Column() {
        PageLoading()
      }
      .width('100%')
      .height(STATE_HEIGHT)
      .alignItems(HorizontalAlign.Center)
    } else if (this.specUiState === 'error') {
      Column() {
        EmptyNetwork({
          showRetry: true,
          onRetryClick: () => {
            this.onRetry();
          }
        })
      }
      .width('100%')
      .height(STATE_HEIGHT)
      .alignItems(HorizontalAlign.Center)
    } else {
      this.contentView()
    }
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: $r('app.string.modal_select_spec'),
        sheetContent: (): void => {
          this.body()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
