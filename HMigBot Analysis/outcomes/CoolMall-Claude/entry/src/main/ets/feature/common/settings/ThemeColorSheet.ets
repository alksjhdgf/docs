/**
 * ThemeColorSheet — 主题颜色选择弹窗内容 (source: feature/common/component/ThemeColorModal.kt).
 * Render inside a bindSheet builder (SheetDefaults.options(onDismiss, bg_page)).
 * BottomModal(title 主题颜色) + Card of the 5 ThemeColorOption entries: name, 20vp color dot, RadioButton.
 */
import { BottomModal } from '../../../core/ui/widget/BottomSheet';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { ThemeColorKey, ThemeColorOption } from '../../../core/designsystem/ThemeColorOption';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';
import { RADIO_ICON_SIZE, RADIO_TOUCH_SIZE, sheetIndicatorColor } from './ThemeModeSheet';

/** ColorDot size 20.dp */
export const COLOR_DOT_SIZE: number = 20;

@ComponentV2
export struct ThemeColorSheet {
  /** 当前选中的颜色 key */
  @Param selectedColorKey: ThemeColorKey = ThemeColorOption.DEFAULT.storageValue;
  /** 选择颜色回调 */
  @Event onSelect: (option: ThemeColorOption) => void = (option: ThemeColorOption) => {
  };

  private options: ThemeColorOption[] = ThemeColorOption.entries;

  @Builder
  trailingBuilder(option: ThemeColorOption) {
    // Row(verticalAlignment = CenterVertically, spacedBy(12.dp)) { ColorDot; RadioButton }
    Row({ space: 12 }) {
      Circle()
        .width(COLOR_DOT_SIZE)
        .height(COLOR_DOT_SIZE)
        .fill(option.colorHex)
      Stack({ alignContent: Alignment.Center }) {
        Radio({ value: option.storageValue, group: 'settings_theme_color' })
          .checked(this.selectedColorKey === option.storageValue)
          .width(RADIO_ICON_SIZE)
          .height(RADIO_ICON_SIZE)
          .margin(0)
          .radioStyle({ checkedBackgroundColor: ThemeManager.instance.primary })
          .hitTestBehavior(HitTestMode.None) // the whole row (source RadioButton onClick = onSelect) handles taps
      }
      .width(RADIO_TOUCH_SIZE)
      .height(RADIO_TOUCH_SIZE)
    }
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  optionsCard() {
    Column() {
      ForEach(this.options, (option: ThemeColorOption, index: number) => {
        AppListItem({
          itemTitle: option.nameRes,
          showArrow: false,
          horizontalPadding: Dimens.spaceHorizontalLarge,
          verticalPadding: Dimens.spaceVerticalSmall,
          showDivider: index !== this.options.length - 1,
          hasTrailingContent: true,
          trailingContent: (): void => {
            this.trailingBuilder(option)
          },
          onItemClick: () => {
            this.onSelect(option);
          }
        })
      }, (option: ThemeColorOption) => option.storageValue + '_' +
        (this.selectedColorKey === option.storageValue ? '1' : '0'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: $r('app.string.settings_theme_color'),
        indicatorColor: sheetIndicatorColor(),
        sheetContent: (): void => {
          this.optionsCard()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
