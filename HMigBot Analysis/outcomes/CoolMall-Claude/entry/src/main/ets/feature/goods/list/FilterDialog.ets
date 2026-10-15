/**
 * FilterDialog (source: feature/goods/component/FilterDialog.kt) — full-screen filter overlay of the category
 * goods list (GOODS-A30 / GOODS-A31).
 *
 * - Mask (scrim @ 0.5) covering the whole page: tap → onDismiss (conditions are not applied).
 * - Panel centered with 16vp outer padding, max height 680, 16vp corners, background bg_page; the panel itself
 *   blocks touches from reaching the mask (source clickable {} "阻止点击穿透").
 * - Panel content by category state (300 ms cross-fade): loading → PageLoading, error → EmptyNetwork,
 *   success → FilterContentView.
 * - FilterContentView keeps its own working copy of the conditions (source remember { mutableStateOf(...) }):
 *   title `筛选` + close, `价格区间` card (`最低价` / `最高价` numeric inputs), one card per top-level category with its
 *   children as multi-select chips (icon + name), bottom bar `重置` (clear local + onResetFilters, dialog stays) and
 *   `确定` (onApplyFilters(selected, min, max)).
 */
import { LengthMetrics } from '@kit.ArkUI';
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { CategoryTree } from '../../../core/model/Goods';
import { EmptyNetwork, PageLoading } from '../../../core/ui/base/StateViews';
import { AppButton, AppButtonSize, AppButtonStyle, AppButtonType } from '../../../core/ui/widget/Buttons';
import { NetWorkImage } from '../../../core/ui/widget/Images';
import { CategoryUiState } from './GoodsCategoryViewModel';

/** Source heightIn(max = 680.dp) */
const PANEL_MAX_HEIGHT: number = 680;
/** colorScheme.scrim (black) @ 0.5 */
const SCRIM_COLOR: string = '#80000000';
/** AnimatedContent tween(300) */
const STATE_FADE_MS: number = 300;
/** Source padding(bottom = 50.dp, top = 50.dp) reserving the title bar / bottom bar area */
const BAR_RESERVED_HEIGHT: number = 50;
/** ButtonSize.MINI height */
const MINI_BUTTON_HEIGHT: number = 34;

@ComponentV2
export struct FilterDialog {
  @Param categoryState: CategoryUiState = 'loading';
  @Param categoryTree: CategoryTree[] = [];
  @Param selectedCategoryIds: number[] = [];
  @Param minPrice: string = '';
  @Param maxPrice: string = '';
  @Event onDismiss: () => void = () => {
  };
  @Event onApplyFilters: (categoryIds: number[], minPrice: string, maxPrice: string) => void =
    (categoryIds: number[], minPrice: string, maxPrice: string) => {
    };
  @Event onResetFilters: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.Center }) { // source panel .align(Alignment.Center)
      // Mask: full page, tap closes without applying
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(SCRIM_COLOR)
        .onClick(() => {
          this.onDismiss();
        })

      // Panel (Default hit test: touches inside never reach the mask)
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.categoryState === 'loading') {
          Stack({ alignContent: Alignment.TopStart }) {
            PageLoading()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
        } else if (this.categoryState === 'error') {
          Stack({ alignContent: Alignment.TopStart }) {
            EmptyNetwork()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
        } else {
          Stack({ alignContent: Alignment.TopStart }) {
            FilterContentView({
              categoryTree: this.categoryTree,
              initSelectedIds: this.selectedCategoryIds,
              initMinPrice: this.minPrice,
              initMaxPrice: this.maxPrice,
              onDismiss: () => {
                this.onDismiss();
              },
              onApplyFilters: (ids: number[], min: string, max: string) => {
                this.onApplyFilters(ids, min, max);
              },
              onResetFilters: () => {
                this.onResetFilters();
              }
            })
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
        }
      }
      .width('calc(100% - 32vp)')
      .height('calc(100% - 32vp)')
      .constraintSize({ maxHeight: PANEL_MAX_HEIGHT })
      .borderRadius(Dimens.radiusLarge)
      .clip(true)
      .backgroundColor($r('app.color.bg_page'))
    }
    .width('100%')
    .height('100%')
  }
}

/** Dialog content (source FilterContentView) */
@ComponentV2
struct FilterContentView {
  @Param categoryTree: CategoryTree[] = [];
  /** Initial values (source remember { mutableStateOf(param) }: copied once) */
  @Param @Once initSelectedIds: number[] = [];
  @Param @Once initMinPrice: string = '';
  @Param @Once initMaxPrice: string = '';
  @Local currentMinPrice: string = '';
  @Local currentMaxPrice: string = '';
  @Local selectedCategories: number[] = [];
  @Event onDismiss: () => void = () => {
  };
  @Event onApplyFilters: (categoryIds: number[], minPrice: string, maxPrice: string) => void =
    (categoryIds: number[], minPrice: string, maxPrice: string) => {
    };
  @Event onResetFilters: () => void = () => {
  };

  aboutToAppear(): void {
    this.currentMinPrice = this.initMinPrice;
    this.currentMaxPrice = this.initMaxPrice;
    // toSet(): drop duplicates
    const ids: number[] = [];
    for (const id of this.initSelectedIds) {
      if (ids.indexOf(id) < 0) {
        ids.push(id);
      }
    }
    this.selectedCategories = ids;
  }

  private isSelected(id: number): boolean {
    return this.selectedCategories.indexOf(id) >= 0;
  }

  private toggleCategory(id: number): void {
    if (this.isSelected(id)) {
      this.selectedCategories = this.selectedCategories.filter((v: number): boolean => v !== id);
    } else {
      this.selectedCategories = this.selectedCategories.concat([id]);
    }
  }

  private reset(): void {
    this.currentMinPrice = '';
    this.currentMaxPrice = '';
    this.selectedCategories = [];
    this.onResetFilters();
  }

  private confirm(): void {
    this.onApplyFilters(this.selectedCategories.slice(), this.currentMinPrice, this.currentMaxPrice);
  }

  @Builder
  priceInput(isMin: boolean) {
    Row() {
      TextInput({
        text: isMin ? this.currentMinPrice : this.currentMaxPrice,
        placeholder: isMin ? $r('app.string.min_price') : $r('app.string.max_price')
      })
        .layoutWeight(1)
        .height(Dimens.lineBodyMedium)
        .padding(0)
        .borderRadius(0)
        .backgroundColor(Color.Transparent)
        .type(InputType.Number) // source KeyboardType.Number, singleLine
        .fontSize(Dimens.fontBodyMedium)
        .fontColor($r('app.color.text_primary'))
        .placeholderFont({ size: Dimens.fontBodyMedium })
        .placeholderColor($r('app.color.text_tertiary'))
        .caretColor(ThemeManager.instance.primary)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => {
          if (isMin) {
            this.currentMinPrice = value;
          } else {
            this.currentMaxPrice = value;
          }
        })
    }
    .layoutWeight(1)
    .padding({
      left: Dimens.spaceHorizontalLarge,
      right: Dimens.spaceHorizontalLarge,
      top: Dimens.spaceVerticalSmall,
      bottom: Dimens.spaceVerticalSmall
    })
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius(Dimens.radiusCircle)
    .clip(true)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  priceCard() {
    Column() {
      Text($r('app.string.price_range'))
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
        .padding({ bottom: Dimens.spacePaddingMedium })
      Row({ space: Dimens.spacePaddingMedium }) {
        this.priceInput(true)
        Column()
          .width(16)
          .height(1)
          .backgroundColor($r('app.color.border'))
        this.priceInput(false)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center) // source verticalAlignment = CenterVertically
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  categoryChip(child: CategoryTree) {
    Row() {
      NetWorkImage({ model: child.pic, imageSize: 18 })
      Text(child.name)
        .margin({ left: Dimens.spaceHorizontalXSmall })
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(Dimens.lineBodyMedium)
        .fontColor(this.isSelected(child.id) ? ThemeManager.instance.primary : $r('app.color.text_primary'))
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .border({
      width: 1,
      color: this.isSelected(child.id) ? ThemeManager.instance.primary : $r('app.color.border')
    })
    .borderRadius(Dimens.radiusCircle)
    .clip(true)
    .backgroundColor(this.isSelected(child.id) ? ThemeManager.withAlpha(ThemeManager.instance.primary, 0.1) :
    $r('app.color.surface'))
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center) // source Row(verticalAlignment = CenterVertically)
    .onClick(() => {
      this.toggleCategory(child.id);
    })
  }

  @Builder
  categoryCard(category: CategoryTree) {
    Column() {
      Text(category.name)
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
        .padding({ bottom: Dimens.spacePaddingMedium })
      if (category.children.length > 0) {
        Flex({
          wrap: FlexWrap.Wrap,
          justifyContent: FlexAlign.Start,
          alignItems: ItemAlign.Start,
          space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }
        }) {
          ForEach(category.children, (child: CategoryTree) => {
            this.categoryChip(child)
          }, (child: CategoryTree) => 'chip_' + child.id + '_' + this.isSelected(child.id) + '_' + child.name +
            '_' + child.pic)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(Dimens.spacePaddingMedium)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    RelativeContainer() {
      // Scrollable conditions (scroll under the title / bottom bar, source padding top/bottom 50)
      Scroll() {
        Column({ space: Dimens.spaceVerticalMedium }) {
          this.priceCard()
          ForEach(this.categoryTree, (category: CategoryTree) => {
            this.categoryCard(category)
          }, (category: CategoryTree) => 'cat_' + category.id + '_' + category.name + '_' + category.children.length)
        }
        .width('100%')
        .padding({
          left: Dimens.spacePaddingMedium,
          right: Dimens.spacePaddingMedium,
          top: BAR_RESERVED_HEIGHT + Dimens.spacePaddingMedium,
          bottom: BAR_RESERVED_HEIGHT + Dimens.spacePaddingMedium
        })
        .alignItems(HorizontalAlign.Start)
      }
      .id('filter_scroll')
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .alignRules({
        top: { anchor: '__container__', align: VerticalAlign.Top },
        left: { anchor: '__container__', align: HorizontalAlign.Start }
      })

      // Title bar (top, above the scroll)
      Row() {
        Text($r('app.string.filter'))
          .fontSize(Dimens.fontTitleLarge)
          .lineHeight(Dimens.lineTitleLarge)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Stack({ alignContent: Alignment.Center }) { // icon inside its 4vp padded touch box
          Image($r('app.media.ic_close'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.text_primary'))
            .accessibilityText($r('app.string.modal_close'))
        }
        .padding(Dimens.spacePaddingXSmall)
        .borderRadius(Dimens.radiusSmall)
        .clip(true)
        .onClick(() => {
          this.onDismiss();
        })
      }
      .id('filter_title')
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .backgroundColor($r('app.color.bg_page'))
      .justifyContent(FlexAlign.SpaceBetween) // source SpaceBetweenRow
      .alignItems(VerticalAlign.Center)
      .zIndex(1)
      .alignRules({
        top: { anchor: '__container__', align: VerticalAlign.Top },
        left: { anchor: '__container__', align: HorizontalAlign.Start }
      })

      // Bottom buttons (Surface, shadowElevation 4)
      Row() {
        Row() {
          Text($r('app.string.reset'))
            .fontSize(Dimens.fontBodyMedium)
            .fontColor(ThemeManager.instance.primary)
            .textAlign(TextAlign.Center)
            .maxLines(1)
        }
        .layoutWeight(1)
        .height(MINI_BUTTON_HEIGHT)
        .justifyContent(FlexAlign.Center) // source button content centered
        .alignItems(VerticalAlign.Center)
        .border({ width: 1, color: ThemeManager.instance.primary })
        .borderRadius(MINI_BUTTON_HEIGHT / 2)
        .clip(true)
        .stateStyles({
          normal: {
            .backgroundColor(Color.Transparent)
          },
          pressed: {
            .backgroundColor($r('app.color.press'))
          }
        })
        .onClick(() => {
          this.reset();
        })

        Column() {
          AppButton({
            btnText: $r('app.string.confirm'),
            btnType: AppButtonType.DEFAULT,
            btnSize: AppButtonSize.MINI,
            btnStyle: AppButtonStyle.GRADIENT,
            onBtnClick: () => {
              this.confirm();
            }
          })
        }
        .layoutWeight(1)
        .margin({ left: Dimens.spaceHorizontalMedium })
        .alignItems(HorizontalAlign.Start)
      }
      .id('filter_bottom')
      .width('100%')
      .padding(Dimens.spacePaddingSmall)
      .backgroundColor($r('app.color.surface'))
      .shadow({ radius: 8, color: '#1F000000', offsetX: 0, offsetY: -1 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .zIndex(1)
      .alignRules({
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
        left: { anchor: '__container__', align: HorizontalAlign.Start }
      })
    }
    .width('100%')
    .height('100%')
  }
}
