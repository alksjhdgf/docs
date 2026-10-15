/**
 * DependencyModal (source: feature/common/component/DependencyModal.kt) — content of the `引用致谢` sheet.
 *
 * BottomModal(title `引用致谢`, drag indicator, horizontal padding 16, container = background,
 * indicator = onSurface @ 0.1) {
 *   LazyColumn(spacedBy 12, bottom padding 16) of DependencyCard
 * }
 * DependencyCard: Card(radius 12, clickable) { Column(padding 16) {
 *   name (bodyLarge SemiBold, 1 line ellipsis) · 8 · description (bodyMedium secondary, ≤2 lines) · 8 ·
 *   Tag(category, PRIMARY, SMALL, LIGHT) } }
 *
 * The page binds it with bindSheet(..., SheetDefaults.options(onDismiss, $r('app.color.bg_page'))).
 * `listMaxHeight` bounds the list so the 21 items scroll inside the sheet.
 */
import { Dimens } from '../../../core/designsystem/Dimens';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { BottomModal } from '../../../core/ui/widget/BottomSheet';
import { Tag, TagSize, TagStyle, TagType } from '../../../core/ui/widget/Tags';
import { Dependency } from './Dependency';

@ComponentV2
export struct DependencyModal {
  @Param dependencies: Dependency[] = [];
  /** Max list height (vp); <= 0 → unbounded */
  @Param listMaxHeight: number = 0;
  @Event onDependencyClick: (dependency: Dependency) => void = (dependency: Dependency) => {
  };

  /** onSurface @ 0.1 */
  private indicatorColor(): string {
    return ThemeManager.instance.isDark ? ThemeManager.withAlpha('#D1D1D1', 0.1) :
    ThemeManager.withAlpha('#181818', 0.1);
  }

  @Builder
  dependencyCard(dependency: Dependency) {
    Column() {
      Text(dependency.name)
        .width('100%')
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontWeight(Dimens.weightSemiBold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // SpaceVerticalSmall
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalSmall)

      if (dependency.description.length > 0) {
        Text(dependency.description)
          .fontSize(Dimens.fontBodyMedium)
          .lineHeight(Dimens.lineBodyMedium)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalSmall)
      }

      Tag({
        tagText: dependency.category,
        tagType: TagType.PRIMARY,
        tagSize: TagSize.SMALL,
        tagStyle: TagStyle.LIGHT
      })
    }
    .width('100%')
    .padding(Dimens.spacePaddingLarge)
    // source Column without alignment = start
    .alignItems(HorizontalAlign.Start)
    .borderRadius(12)
    .clip(true)
    .stateStyles({
      normal: {
        .backgroundColor($r('app.color.bg_card'))
      },
      pressed: {
        .backgroundColor($r('app.color.press'))
      }
    })
    .onClick(() => {
      this.onDependencyClick(dependency);
    })
  }

  @Builder
  listBody() {
    List({ space: Dimens.spacePaddingMedium }) {
      ForEach(this.dependencies, (d: Dependency, index: number) => {
        ListItem() {
          this.dependencyCard(d)
        }
      }, (d: Dependency, index: number) => index + '_' + d.name)
    }
    .width('100%')
    .constraintSize({ maxHeight: this.listMaxHeight > 0 ? this.listMaxHeight : 100000 })
    .padding({ bottom: Dimens.spacePaddingLarge })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: $r('app.string.dependency_modal_title'),
        showDragIndicator: true,
        horizontalPadding: Dimens.spacePaddingLarge,
        indicatorColor: this.indicatorColor(),
        sheetContent: (): void => {
          this.listBody()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
