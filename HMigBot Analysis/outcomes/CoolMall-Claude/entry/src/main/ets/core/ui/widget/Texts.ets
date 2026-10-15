/**
 * Texts — text style helpers + PriceText
 * (source: core/ui/component/text/Text.kt (TextType/TextSize/AppText color+style mapping) and
 * core/ui/component/text/PriceText.kt).
 *
 * ArkUI `Text` already covers AppText's knobs (maxLines/overflow/decoration/align…), so instead of a
 * wrapper component (which could not take chained attributes) the TextType/TextSize mapping is
 * exposed as `AppTextStyles` helpers:
 *   Text(x).fontSize(AppTextStyles.fontSize(AppTextSize.BODY_MEDIUM))
 *          .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
 */
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';

/** TextType (renamed AppTextType to avoid clashing with ArkUI global type names). */
export enum AppTextType {
  /** onBackground / text_primary */
  PRIMARY,
  /** onSurface @ 0.75 → text_secondary */
  SECONDARY,
  /** onSurfaceVariant @ 0.6 → text_tertiary */
  TERTIARY,
  /** Color.White */
  WHITE,
  /** Primary (dynamic theme color) */
  LINK,
  /** ColorSuccess */
  SUCCESS,
  /** ColorWarning */
  WARNING,
  /** ColorDanger */
  ERROR
}

/** TextSize (typography mapping from Type.kt). */
export enum AppTextSize {
  /** displayLarge 22/31 SemiBold */
  DISPLAY_LARGE,
  /** displayMedium 18/27 SemiBold */
  DISPLAY_MEDIUM,
  /** titleLarge 16/24 Bold */
  TITLE_LARGE,
  /** titleMedium 14/22 Bold */
  TITLE_MEDIUM,
  /** bodyLarge 14/22 Normal */
  BODY_LARGE,
  /** bodyMedium 12/18 Normal */
  BODY_MEDIUM,
  /** bodySmall 11/16 Normal (Type.kt bodySmall = BodyMedium.copy(11sp/16sp)) */
  BODY_SMALL
}

export class AppTextStyles {
  /** Font size (fp) of a TextSize. */
  static fontSize(size: AppTextSize): number {
    switch (size) {
      case AppTextSize.DISPLAY_LARGE:
        return Dimens.fontDisplayLarge;
      case AppTextSize.DISPLAY_MEDIUM:
        return Dimens.fontDisplayMedium;
      case AppTextSize.TITLE_LARGE:
        return Dimens.fontTitleLarge;
      case AppTextSize.TITLE_MEDIUM:
        return Dimens.fontTitleMedium;
      case AppTextSize.BODY_LARGE:
        return Dimens.fontBodyLarge;
      case AppTextSize.BODY_MEDIUM:
        return Dimens.fontBodyMedium;
      default:
        return Dimens.fontBodySmall;
    }
  }

  /** Line height (fp) of a TextSize. */
  static lineHeight(size: AppTextSize): number {
    switch (size) {
      case AppTextSize.DISPLAY_LARGE:
        return Dimens.lineDisplayLarge;
      case AppTextSize.DISPLAY_MEDIUM:
        return Dimens.lineDisplayMedium;
      case AppTextSize.TITLE_LARGE:
        return Dimens.lineTitleLarge;
      case AppTextSize.TITLE_MEDIUM:
        return Dimens.lineTitleMedium;
      case AppTextSize.BODY_LARGE:
        return Dimens.lineBodyLarge;
      case AppTextSize.BODY_MEDIUM:
        return Dimens.lineBodyMedium;
      default:
        return Dimens.lineBodySmall;
    }
  }

  /** Default font weight of a TextSize (Type.kt). */
  static fontWeight(size: AppTextSize): number | FontWeight {
    switch (size) {
      case AppTextSize.DISPLAY_LARGE:
      case AppTextSize.DISPLAY_MEDIUM:
        return Dimens.weightSemiBold;
      case AppTextSize.TITLE_LARGE:
      case AppTextSize.TITLE_MEDIUM:
        return FontWeight.Bold;
      default:
        return FontWeight.Normal;
    }
  }

  /** Text color of a TextType (AppText color mapping). LINK reads the live theme primary. */
  static color(type: AppTextType): ResourceColor {
    switch (type) {
      case AppTextType.SECONDARY:
        return $r('app.color.text_secondary');
      case AppTextType.TERTIARY:
        return $r('app.color.text_tertiary');
      case AppTextType.WHITE:
        return $r('app.color.text_white');
      case AppTextType.LINK:
        return ThemeManager.instance.primary;
      case AppTextType.SUCCESS:
        return $r('app.color.success');
      case AppTextType.WARNING:
        return $r('app.color.warning');
      case AppTextType.ERROR:
        return $r('app.color.danger');
      default:
        return $r('app.color.text_primary');
    }
  }
}

/**
 * PriceText: `¥` + integer part (bold) + fixed `.00`, all baseline-aligned (source alignByBaseline →
 * spans of a single Text share one baseline). The `¥` keeps the source's 1dp end padding via letterSpacing.
 */
@ComponentV2
export struct PriceText {
  /** Price (source Int); fractional input is truncated so the `.00` suffix stays truthful to the source format. */
  @Param price: number = 0;
  @Param priceType: AppTextType = AppTextType.ERROR;
  @Param integerTextSize: AppTextSize = AppTextSize.DISPLAY_MEDIUM;
  @Param decimalTextSize: AppTextSize = AppTextSize.BODY_MEDIUM;
  @Param symbolTextSize: AppTextSize = AppTextSize.BODY_MEDIUM;

  build() {
    Text() {
      Span('¥')
        .fontSize(AppTextStyles.fontSize(this.symbolTextSize))
        .fontWeight(AppTextStyles.fontWeight(this.symbolTextSize))
        .fontColor(AppTextStyles.color(this.priceType))
        .letterSpacing(1)
      Span(String(Math.trunc(this.price)))
        .fontSize(AppTextStyles.fontSize(this.integerTextSize))
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTextStyles.color(this.priceType))
      Span('.00')
        .fontSize(AppTextStyles.fontSize(this.decimalTextSize))
        .fontWeight(AppTextStyles.fontWeight(this.decimalTextSize))
        .fontColor(AppTextStyles.color(this.priceType))
    }
    .maxLines(1)
  }
}
