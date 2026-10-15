/**
 * Dimens — spacing / radius / typography tokens
 * (source: core/designsystem/theme/Size.kt, Shape.kt, Type.kt). dp → vp, sp → fp (plain numbers:
 * numbers passed to width/margin/padding/borderRadius are vp, to fontSize/lineHeight are fp).
 */
export class Dimens {
  // ====================== Size.kt: spacing (vp) ======================
  static readonly spaceVerticalXXLarge: number = 32;
  static readonly spaceVerticalXLarge: number = 24;
  static readonly spaceVerticalLarge: number = 16;
  static readonly spaceVerticalMedium: number = 12;
  static readonly spaceVerticalSmall: number = 8;
  static readonly spaceVerticalXSmall: number = 4;

  static readonly spaceHorizontalXXLarge: number = 32;
  static readonly spaceHorizontalXLarge: number = 24;
  static readonly spaceHorizontalLarge: number = 16;
  static readonly spaceHorizontalMedium: number = 12;
  static readonly spaceHorizontalSmall: number = 8;
  static readonly spaceHorizontalXSmall: number = 4;

  static readonly spacePaddingLarge: number = 16;
  static readonly spacePaddingMedium: number = 12;
  static readonly spacePaddingSmall: number = 8;
  static readonly spacePaddingXSmall: number = 4;

  /** Divider thickness 0.5dp */
  static readonly spaceDivider: number = 0.5;
  /** Indicator height 2dp */
  static readonly spaceIndicator: number = 2;

  // ====================== Shape.kt: corner radius (vp) ======================
  static readonly radiusXSmall: number = 4;
  static readonly radiusSmall: number = 8;
  static readonly radiusMedium: number = 12;
  static readonly radiusLarge: number = 16;
  static readonly radiusExtraLarge: number = 24;
  /** ShapeCircle (50%): use borderRadius(size / 2) or Circle/clipShape; this is a large-enough fallback */
  static readonly radiusCircle: number = 9999;

  // ====================== Type.kt: typography (fp) ======================
  /** DisplayLarge 22/31 SemiBold — page main title, splash title */
  static readonly fontDisplayLarge: number = 22;
  static readonly lineDisplayLarge: number = 31;
  /** DisplayMedium 18/27 SemiBold — large page/module title */
  static readonly fontDisplayMedium: number = 18;
  static readonly lineDisplayMedium: number = 27;
  /** displaySmall (M3 mapping) 16/24 SemiBold */
  static readonly fontDisplaySmall: number = 16;
  static readonly lineDisplaySmall: number = 24;
  /** TitleLarge 16/24 Bold — secondary title, nav bar title, list title */
  static readonly fontTitleLarge: number = 16;
  static readonly lineTitleLarge: number = 24;
  /** TitleMedium 14/22 Bold — category name, card title (titleSmall: same size, Medium) */
  static readonly fontTitleMedium: number = 14;
  static readonly lineTitleMedium: number = 22;
  /** BodyLarge 14/22 Normal — body text */
  static readonly fontBodyLarge: number = 14;
  static readonly lineBodyLarge: number = 22;
  /** BodyMedium 12/18 Normal — auxiliary text, labels, bottom-nav text (labelLarge/labelMedium) */
  static readonly fontBodyMedium: number = 12;
  static readonly lineBodyMedium: number = 18;
  /** bodySmall / labelSmall (M3 mapping) 11/16 */
  static readonly fontBodySmall: number = 11;
  static readonly lineBodySmall: number = 16;

  /** FontWeight.SemiBold (DisplayLarge/DisplayMedium); ArkUI has no SemiBold enum, 600 is accepted by .fontWeight() */
  static readonly weightSemiBold: number = 600;
  static readonly weightBold: FontWeight = FontWeight.Bold;
  static readonly weightMedium: FontWeight = FontWeight.Medium;
  static readonly weightNormal: FontWeight = FontWeight.Normal;
}
