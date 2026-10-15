/**
 * FocusableDivider (source: feature/auth/component/FocusableDivider.kt).
 * Optional 16vp spacer (SpaceVerticalLarge) + a 1vp line; primary color while the owning field is focused,
 * colorScheme.outline otherwise.
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';

@ComponentV2
export struct FocusableDivider {
  /** Whether the owning input is focused (source focusState) */
  @Param fieldFocused: boolean = false;
  /** Line thickness in vp (source thickness = 1f) */
  @Param lineThickness: number = 1;
  /** Leading 16vp spacer (source withSpacing = true) */
  @Param withSpacing: boolean = true;

  build() {
    Column() {
      if (this.withSpacing) {
        Row()
          .width('100%')
          .height(Dimens.spaceVerticalLarge)
      }
      Row()
        .width('100%')
        .height(this.lineThickness)
        .backgroundColor(this.fieldFocused ? ThemeManager.instance.primary : $r('app.color.border'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
