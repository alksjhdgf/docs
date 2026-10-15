/**
 * ThemeModeSheet — 主题模式选择弹窗内容 (source: feature/common/component/ThemeModeModal.kt).
 * Render inside a bindSheet builder (SheetDefaults.options(onDismiss, bg_page)).
 * BottomModal(title 夜间模式) + Card of 3 AppListItems (follow system / light / dark), each with a RadioButton.
 */
import { BottomModal } from '../../../core/ui/widget/BottomSheet';
import { AppListItem } from '../../../core/ui/widget/ListItem';
import { ThemeMode, ThemePreference } from '../../../core/designsystem/ThemePreference';
import { ThemeManager } from '../../../core/designsystem/ThemeManager';
import { Dimens } from '../../../core/designsystem/Dimens';

/** M3 RadioButton minimum interactive size */
export const RADIO_TOUCH_SIZE: number = 48;
/** M3 RadioButton icon size */
export const RADIO_ICON_SIZE: number = 20;

/** Sheet drag indicator: onSurface.copy(alpha = 0.1f) */
export function sheetIndicatorColor(): string {
  return ThemeManager.instance.isDark ? '#1AFFFFFF' : '#1A000000';
}

/** Text of a theme mode (SettingsScreen themeModeText) */
export function themeModeLabel(mode: ThemeMode): Resource {
  if (mode === ThemePreference.LIGHT) {
    return $r('app.string.settings_dark_mode_light');
  }
  if (mode === ThemePreference.DARK) {
    return $r('app.string.settings_dark_mode_dark');
  }
  return $r('app.string.settings_dark_mode_follow_system');
}

@ComponentV2
export struct ThemeModeSheet {
  /** 当前选中的主题模式 */
  @Param selectedMode: ThemeMode = ThemePreference.FOLLOW_SYSTEM;
  /** 选择某个模式的回调 */
  @Event onSelect: (mode: ThemeMode) => void = (mode: ThemeMode) => {
  };

  private modes: ThemeMode[] = ThemePreference.entries;

  @Builder
  radioBuilder(mode: ThemeMode) {
    Stack({ alignContent: Alignment.Center }) {
      Radio({ value: mode, group: 'settings_theme_mode' })
        .checked(this.selectedMode === mode)
        .width(RADIO_ICON_SIZE)
        .height(RADIO_ICON_SIZE)
        .margin(0)
        .radioStyle({ checkedBackgroundColor: ThemeManager.instance.primary })
        .hitTestBehavior(HitTestMode.None) // the whole row (source RadioButton onClick = onSelect) handles taps
    }
    .width(RADIO_TOUCH_SIZE)
    .height(RADIO_TOUCH_SIZE)
  }

  @Builder
  optionsCard() {
    // M3 Card (surfaceContainerHighest, 12vp corners)
    Column() {
      ForEach(this.modes, (mode: ThemeMode, index: number) => {
        AppListItem({
          itemTitle: themeModeLabel(mode),
          showArrow: false,
          horizontalPadding: Dimens.spaceHorizontalLarge,
          verticalPadding: Dimens.spaceVerticalSmall,
          showDivider: index !== this.modes.length - 1,
          hasTrailingContent: true,
          trailingContent: (): void => {
            this.radioBuilder(mode)
          },
          onItemClick: () => {
            this.onSelect(mode);
          }
        })
      }, (mode: ThemeMode) => mode + '_' + (this.selectedMode === mode ? '1' : '0'))
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
        sheetTitle: $r('app.string.settings_dark_mode'),
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
