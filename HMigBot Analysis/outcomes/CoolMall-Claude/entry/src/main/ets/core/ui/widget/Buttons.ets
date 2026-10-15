/**
 * Buttons (source: core/ui/component/button/Button.kt, CheckButton.kt, core/ui/component/bottombar/AppBottomButton.kt).
 *
 * Exports: AppButtonType / AppButtonStyle / AppButtonSize / AppButtonShape, AppButtonDefaults,
 * AppButton (AppButton + AppButtonFixed + AppButtonCustomSize knobs), AppButtonFixed, AppButtonBordered,
 * CheckButton, AppBottomButton.
 *
 * The source enums are prefixed with `App` because ArkUI already has a global `ButtonType`.
 * Clicks are only accepted while enabled && !loading; otherwise the button does not take part in hit
 * testing (A2-16), matching Compose's disabled clickable which does not consume the event.
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';
import { AvoidArea } from '../base/AvoidArea';
import { WidgetColors } from './WidgetColors';

export enum AppButtonType {
  /** Primary (theme color) */
  DEFAULT,
  SUCCESS,
  WARNING,
  DANGER,
  PURPLE,
  /** Same color as DEFAULT */
  LINK
}

export enum AppButtonStyle {
  FILLED,
  OUTLINED,
  GRADIENT
}

export enum AppButtonSize {
  /** 48vp */
  MEDIUM,
  /** 40vp */
  SMALL,
  /** 34vp */
  MINI
}

export enum AppButtonShape {
  /** ShapeSmall (8vp) */
  SQUARE,
  /** height / 2 */
  ROUND
}

export class AppButtonDefaults {
  /** Button color ('#RRGGBB'); DEFAULT/LINK follow the live theme primary. */
  static colorHex(type: AppButtonType): string {
    switch (type) {
      case AppButtonType.SUCCESS:
        return WidgetColors.SUCCESS;
      case AppButtonType.WARNING:
        return WidgetColors.WARNING;
      case AppButtonType.DANGER:
        return WidgetColors.DANGER;
      case AppButtonType.PURPLE:
        return WidgetColors.PURPLE;
      default:
        return ThemeManager.instance.primary;
    }
  }

  static height(size: AppButtonSize): number {
    switch (size) {
      case AppButtonSize.SMALL:
        return 40;
      case AppButtonSize.MINI:
        return 34;
      default:
        return 48;
    }
  }

  static radius(shape: AppButtonShape, height: number): number {
    return shape === AppButtonShape.SQUARE ? Dimens.radiusSmall : height / 2;
  }
}

/**
 * Base button. Defaults = source AppButton (MEDIUM, ROUND, FILLED, fullWidth).
 * - fullWidth=false: width wraps content + `contentPaddingH` on each side (M3 default 24; AppButtonFixed 16).
 * - btnHeight > 0 overrides the size-derived height (AppButtonCustomSize); btnWidth > 0 fixes the width.
 * - btnFontSize/btnFontWeight default to titleMedium (14 Bold).
 */
@ComponentV2
export struct AppButton {
  @Param btnText: ResourceStr = '';
  @Param btnType: AppButtonType = AppButtonType.DEFAULT;
  @Param btnStyle: AppButtonStyle = AppButtonStyle.FILLED;
  @Param btnSize: AppButtonSize = AppButtonSize.MEDIUM;
  @Param btnShape: AppButtonShape = AppButtonShape.ROUND;
  @Param btnEnabled: boolean = true;
  @Param loading: boolean = false;
  @Param fullWidth: boolean = true;
  @Param contentPaddingH: number = 24;
  @Param btnHeight: number = 0;
  @Param btnWidth: number = 0;
  @Param btnFontSize: number = Dimens.fontTitleMedium;
  @Param btnFontWeight: FontWeight = FontWeight.Bold;
  @Event onBtnClick: () => void = () => {
  };

  private clickable(): boolean {
    return this.btnEnabled && !this.loading;
  }

  private realHeight(): number {
    return this.btnHeight > 0 ? this.btnHeight : AppButtonDefaults.height(this.btnSize);
  }

  private realWidth(): Length {
    if (this.btnWidth > 0) {
      return this.btnWidth;
    }
    return this.fullWidth ? '100%' : 'auto';
  }

  /** Text / spinner color: white on filled & gradient, button color on outlined. */
  private contentColor(): ResourceColor {
    if (this.btnStyle === AppButtonStyle.OUTLINED) {
      return AppButtonDefaults.colorHex(this.btnType);
    }
    return $r('app.color.text_white');
  }

  @Builder
  buttonContent() {
    if (this.loading) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(this.contentColor())
    } else {
      Text(this.btnText)
        .fontSize(this.btnFontSize)
        .fontWeight(this.btnFontWeight)
        .fontColor(this.contentColor())
        // M3 OutlinedButton disabled content = onSurface @ 0.38
        .opacity(this.btnStyle === AppButtonStyle.OUTLINED && !this.clickable() ? 0.38 : 1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
  }

  build() {
    if (this.btnStyle === AppButtonStyle.GRADIENT) {
      Row() {
        this.buttonContent()
      }
      // source: Box(contentAlignment = Center)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .width(this.realWidth())
      .height(this.realHeight())
      .padding({ left: this.fullWidth ? 0 : this.contentPaddingH, right: this.fullWidth ? 0 : this.contentPaddingH })
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [
          [ThemeManager.withAlpha(ThemeManager.instance.primaryGradientStart, this.clickable() ? 1 : 0.5), 0.0],
          [ThemeManager.withAlpha(ThemeManager.instance.primaryGradientEnd, this.clickable() ? 1 : 0.5), 1.0]
        ]
      })
      .borderRadius(AppButtonDefaults.radius(this.btnShape, this.realHeight()))
      .clip(true)
      .stateStyles({
        normal: {
          .opacity(1)
        },
        pressed: {
          .opacity(0.85)
        }
      })
      .onClick(() => {
        if (this.clickable()) {
          this.onBtnClick();
        }
      })
      .hitTestBehavior(this.clickable() ? HitTestMode.Default : HitTestMode.None)
    } else {
      Row() {
        this.buttonContent()
      }
      // source: M3 Button content is a centered Row
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .width(this.realWidth())
      .height(this.realHeight())
      .constraintSize({ minWidth: 58 })
      .padding({ left: this.fullWidth ? 0 : this.contentPaddingH, right: this.fullWidth ? 0 : this.contentPaddingH })
      .backgroundColor(this.btnStyle === AppButtonStyle.FILLED ?
        ThemeManager.withAlpha(AppButtonDefaults.colorHex(this.btnType), this.clickable() ? 1 : 0.5) :
      Color.Transparent)
      // M3 OutlinedButton border = 1dp colorScheme.outline
      .border({
        width: this.btnStyle === AppButtonStyle.OUTLINED ? 1 : 0,
        color: $r('app.color.border')
      })
      .borderRadius(AppButtonDefaults.radius(this.btnShape, this.realHeight()))
      .clip(true)
      .stateStyles({
        normal: {
          .opacity(1)
        },
        pressed: {
          .opacity(0.85)
        }
      })
      .onClick(() => {
        if (this.clickable()) {
          this.onBtnClick();
        }
      })
      .hitTestBehavior(this.clickable() ? HitTestMode.Default : HitTestMode.None)
    }
  }
}

/** AppButtonFixed: content-width button, default size SMALL, horizontal content padding 16. */
@ComponentV2
export struct AppButtonFixed {
  @Param btnText: ResourceStr = '';
  @Param btnType: AppButtonType = AppButtonType.DEFAULT;
  @Param btnStyle: AppButtonStyle = AppButtonStyle.FILLED;
  @Param btnSize: AppButtonSize = AppButtonSize.SMALL;
  @Param btnShape: AppButtonShape = AppButtonShape.ROUND;
  @Param btnEnabled: boolean = true;
  @Param loading: boolean = false;
  @Param contentPaddingH: number = 16;
  @Event onBtnClick: () => void = () => {
  };

  build() {
    AppButton({
      btnText: this.btnText,
      btnType: this.btnType,
      btnStyle: this.btnStyle,
      btnSize: this.btnSize,
      btnShape: this.btnShape,
      btnEnabled: this.btnEnabled,
      loading: this.loading,
      fullWidth: false,
      contentPaddingH: this.contentPaddingH,
      onBtnClick: (): void => this.onBtnClick()
    })
  }
}

/**
 * AppButtonBordered: transparent button with a 1vp border in the button color; text bodyMedium (12).
 * `customColor` overrides the type color; `btnHeight` > 0 overrides the size height.
 * Disabled → whole button at 50% alpha (source: border and text both alpha 0.5).
 */
@ComponentV2
export struct AppButtonBordered {
  @Param btnText: ResourceStr = '';
  @Param btnType: AppButtonType = AppButtonType.DEFAULT;
  @Param btnSize: AppButtonSize = AppButtonSize.SMALL;
  @Param btnShape: AppButtonShape = AppButtonShape.ROUND;
  @Param btnEnabled: boolean = true;
  @Param loading: boolean = false;
  @Param contentPaddingH: number = 16;
  @Param customColor: ResourceColor | undefined = undefined;
  @Param btnFontSize: number = Dimens.fontBodyMedium;
  @Param btnFontWeight: FontWeight = FontWeight.Normal;
  @Param btnHeight: number = 0;
  @Event onBtnClick: () => void = () => {
  };

  private clickable(): boolean {
    return this.btnEnabled && !this.loading;
  }

  private realHeight(): number {
    return this.btnHeight > 0 ? this.btnHeight : AppButtonDefaults.height(this.btnSize);
  }

  private color(): ResourceColor {
    return this.customColor !== undefined ? this.customColor : AppButtonDefaults.colorHex(this.btnType);
  }

  build() {
    Row() {
      if (this.loading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.color())
      } else {
        Text(this.btnText)
          .fontSize(this.btnFontSize)
          .fontWeight(this.btnFontWeight)
          .fontColor(this.color())
          .textAlign(TextAlign.Center)
          .maxLines(1)
      }
    }
    // source: Box(contentAlignment = Center)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .height(this.realHeight())
    .padding({ left: this.contentPaddingH, right: this.contentPaddingH })
    .border({ width: 1, color: this.color() })
    .borderRadius(AppButtonDefaults.radius(this.btnShape, this.realHeight()))
    .clip(true)
    .opacity(this.btnEnabled ? 1 : 0.5)
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor($r('app.color.press'))
      }
    })
    .onClick(() => {
      if (this.clickable()) {
        this.onBtnClick();
      }
    })
    .hitTestBehavior(this.clickable() ? HitTestMode.Default : HitTestMode.None)
  }
}

/**
 * CheckButton: circular select indicator (ic_success_circle / ic_circle), tinted primary when selected,
 * onSurfaceVariant@0.6 (text_tertiary) otherwise. `clickable=false` makes it display-only so the
 * surrounding row receives the tap (A2-16).
 */
@ComponentV2
export struct CheckButton {
  @Param isSelected: boolean = false;
  @Param checkSize: number = 24;
  @Param clickable: boolean = true;
  @Param selectedIcon: Resource = $r('app.media.ic_success_circle');
  @Param unselectedIcon: Resource = $r('app.media.ic_circle');
  @Event onCheckClick: () => void = () => {
  };

  build() {
    Image(this.isSelected ? this.selectedIcon : this.unselectedIcon)
      .width(this.checkSize)
      .height(this.checkSize)
      .objectFit(ImageFit.Contain)
      .fillColor(this.isSelected ? ThemeManager.instance.primary : $r('app.color.text_tertiary'))
      .borderRadius(this.checkSize / 2)
      .accessibilityText(this.isSelected ? $r('app.string.selected') : $r('app.string.unselected'))
      .onClick(() => {
        if (this.clickable) {
          this.onCheckClick();
        }
      })
      .hitTestBehavior(this.clickable ? HitTestMode.Default : HitTestMode.None)
  }
}

/**
 * AppBottomButton: full-width bottom bar (surface + 4dp shadow) holding a MEDIUM AppButton,
 * padded 12vp and lifted above the navigation indicator (navigationBarsPadding → AvoidArea.bottom).
 */
@ComponentV2
export struct AppBottomButton {
  @Param btnText: ResourceStr = '';
  @Param btnEnabled: boolean = true;
  @Param loading: boolean = false;
  @Event onBtnClick: () => void = () => {
  };
  @Local avoidArea: AvoidArea = AvoidArea.get();

  build() {
    Column() {
      AppButton({
        btnText: this.btnText,
        btnEnabled: this.btnEnabled,
        loading: this.loading,
        onBtnClick: (): void => this.onBtnClick()
      })
    }
    .width('100%')
    // source: Surface content = single button, start-aligned (button is fillMaxWidth anyway)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spacePaddingMedium,
      bottom: Dimens.spacePaddingMedium + this.avoidArea.bottom
    })
    .backgroundColor($r('app.color.surface'))
    .shadow({ radius: 8, color: WidgetColors.SHADOW, offsetX: 0, offsetY: -2 })
  }
}
