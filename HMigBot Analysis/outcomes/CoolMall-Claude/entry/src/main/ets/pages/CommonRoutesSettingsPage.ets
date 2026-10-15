/**
 * CommonRoutesSettingsPage — 设置 (source: feature/common/view/SettingsScreen.kt + SettingsViewModel.kt).
 *
 * AppScaffold(title 设置, useLargeTopBar) + VerticalList(verticalScroll, padding 12, spacedBy 12):
 *  Card[账号与安全] / 外观与语言 Card[夜间模式, 主题颜色, 语言切换] / 隐私与协议 Card[隐私政策, 用户协议] /
 *  其他 Card[不展示启动页 (page-local Switch), 应用引导] / 通用 Card[清除缓存, 意见反馈, 关于应用].
 * Sheets: ThemeModeSheet (夜间模式) and ThemeColorSheet (主题颜色), both on bg_page (colorScheme.background).
 */
import { Routes } from '../common/Router';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { GuideParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { AppListItem } from '../core/ui/widget/ListItem';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { SheetDefaults } from '../core/ui/widget/BottomSheet';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { ThemeMode } from '../core/designsystem/ThemePreference';
import { ThemeColorOption } from '../core/designsystem/ThemeColorOption';
import { Dimens } from '../core/designsystem/Dimens';
import { SettingsViewModel } from '../feature/common/settings/SettingsViewModel';
import { ThemeModeSheet, themeModeLabel } from '../feature/common/settings/ThemeModeSheet';
import { ThemeColorSheet, COLOR_DOT_SIZE } from '../feature/common/settings/ThemeColorSheet';

@Builder
export function CommonRoutesSettingsPageBuilder() {
  CommonRoutesSettingsPage()
}

@ComponentV2
struct CommonRoutesSettingsPage {
  @Local vm: SettingsViewModel = new SettingsViewModel();
  /** 展示启动页开关：仅页面内状态（源 remember { mutableStateOf(false) }），不持久化、不接入启动流程 */
  @Local hideSplashChecked: boolean = false;

  private scroller: Scroller = new Scroller();

  // ============================== sheets ==============================

  @Builder
  themeModeSheetBuilder() {
    ThemeModeSheet({
      selectedMode: ThemeManager.instance.mode,
      onSelect: (mode: ThemeMode) => {
        this.vm.onThemeModeSelected(mode);
      }
    })
  }

  @Builder
  themeColorSheetBuilder() {
    ThemeColorSheet({
      selectedColorKey: ThemeManager.instance.colorKey,
      onSelect: (option: ThemeColorOption) => {
        this.vm.onThemeColorSelected(option);
      }
    })
  }

  // ============================== row slots ==============================

  @Builder
  themeColorDot() {
    // Box(size 20.dp, clip CircleShape, background(themeColor))
    Circle()
      .width(COLOR_DOT_SIZE)
      .height(COLOR_DOT_SIZE)
      .fill(ThemeManager.instance.primary)
  }

  @Builder
  hideSplashSwitch() {
    Toggle({ type: ToggleType.Switch, isOn: this.hideSplashChecked })
      .selectedColor(ThemeManager.instance.primary)
      .margin(0)
      .onChange((isOn: boolean) => {
        this.hideSplashChecked = isOn;
      })
  }

  // ============================== content ==============================

  @Builder
  sectionTitle(text: Resource) {
    // TitleWithLine(modifier = Modifier.padding(top = SpaceVerticalSmall))
    Row() {
      TitleWithLine({ titleText: text })
    }
    .padding({ top: Dimens.spaceVerticalSmall })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  accountCard() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.settings_account_security'),
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          AppNavigator.navigate(Routes.USER_ROUTES_PROFILE);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  appearanceCard() {
    Column() {
      // 夜间模式
      AppListItem({
        itemTitle: $r('app.string.settings_dark_mode'),
        showArrow: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        trailingText: themeModeLabel(ThemeManager.instance.mode),
        onItemClick: () => {
          this.vm.onDarkModeClick();
        }
      })
      // 主题颜色
      AppListItem({
        itemTitle: $r('app.string.settings_theme_color'),
        showArrow: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.themeColorDot()
        },
        onItemClick: () => {
          this.vm.onThemeColorClick();
        }
      })
      // 语言切换：固定 中文，点击无动作（源 onClick 默认空实现）
      AppListItem({
        itemTitle: $r('app.string.settings_language'),
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        trailingText: $r('app.string.settings_language_chinese'),
        clickable: false
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  privacyCard() {
    Column() {
      // 隐私政策
      AppListItem({
        itemTitle: $r('app.string.about_privacy_policy'),
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          AppNavigator.navigate(Routes.COMMON_ROUTES_PRIVACY_POLICY);
        }
      })
      // 用户协议
      AppListItem({
        itemTitle: $r('app.string.about_user_agreement'),
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          AppNavigator.navigate(Routes.COMMON_ROUTES_USER_AGREEMENT);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  otherCard() {
    Column() {
      // 不展示启动页（行本身点击无动作，开关切换页面内状态）
      AppListItem({
        itemTitle: $r('app.string.settings_hide_splash'),
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalSmall,
        showArrow: false,
        description: $r('app.string.settings_hide_splash_desc'),
        hasTrailingContent: true,
        trailingContent: (): void => {
          this.hideSplashSwitch()
        },
        onItemClick: () => {
          console.info('settings: hide-splash row click is a no-op (source onClick = {})');
        }
      })
      // 应用引导
      AppListItem({
        itemTitle: $r('app.string.settings_app_guide'),
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          AppNavigator.navigate(Routes.LAUNCH_ROUTES_GUIDE, new GuideParam(true));
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  generalCard() {
    Column() {
      // 清除缓存：固定 13.24MB，无点击动作
      AppListItem({
        itemTitle: $r('app.string.settings_clear_cache'),
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        trailingText: $r('app.string.settings_cache_size'),
        clickable: false
      })
      // 意见反馈
      AppListItem({
        itemTitle: $r('app.string.settings_feedback'),
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          AppNavigator.navigate(Routes.FEEDBACK_ROUTES_LIST);
        }
      })
      // 关于应用
      AppListItem({
        itemTitle: $r('app.string.settings_about_app'),
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          AppNavigator.navigate(Routes.COMMON_ROUTES_ABOUT);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  settingsContent() {
    // VerticalList(Modifier.verticalScroll): Column(spacedBy(12), padding(12), start aligned)
    Scroll(this.scroller) {
      Column({ space: Dimens.spaceVerticalMedium }) {
        this.accountCard()
        this.sectionTitle($r('app.string.settings_section_appearance'))
        this.appearanceCard()
        this.sectionTitle($r('app.string.settings_section_privacy'))
        this.privacyCard()
        this.sectionTitle($r('app.string.settings_section_other'))
        this.otherCard()
        this.sectionTitle($r('app.string.settings_section_general'))
        this.generalCard()
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    // collapse the large top bar first while scrolling forward (exitUntilCollapsed nestedScroll)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          AppScaffold({
            titleText: $r('app.string.settings_title'),
            useLargeTopBar: true,
            onBack: () => {
              AppNavigator.back();
            },
            content: (): void => {
              this.settingsContent()
            }
          })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .bindSheet(this.vm.showThemeModal, this.themeModeSheetBuilder(),
          SheetDefaults.options((): void => {
            this.vm.dismissThemeModal();
          }, $r('app.color.bg_page')))
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .bindSheet(this.vm.showThemeColorModal, this.themeColorSheetBuilder(),
        SheetDefaults.options((): void => {
          this.vm.dismissThemeColorModal();
        }, $r('app.color.bg_page')))
    }
    .hideTitleBar(true)
  }
}
