/**
 * WidgetColors — fixed functional color values used by core/ui widgets when an alpha variant or a
 * theme-independent tint is required (source: core/designsystem/theme/Color.kt).
 *
 * Neutral colors are NOT here: widgets use the `$r('app.color.*')` tokens (light/dark aware) and the
 * dynamic primary color `ThemeManager.instance.primary`. These hex values are only used where the
 * source applies `.copy(alpha = …)` to a functional color (button disabled state) or uses a
 * theme-independent `*Light` tint (Tag LIGHT style), which a resource token cannot express.
 */
export class WidgetColors {
  /** ColorSuccess */
  static readonly SUCCESS: string = '#09BE4F';
  /** ColorWarning */
  static readonly WARNING: string = '#FFB703';
  /** ColorDanger */
  static readonly DANGER: string = '#FF2B2B';
  /** ColorPurple */
  static readonly PURPLE: string = '#6831FF';
  /** TextWhite */
  static readonly WHITE: string = '#FFFFFF';

  /** BgRedLight rgba(255,43,43,.05) — used by Tag LIGHT in both themes (source uses the Light constant) */
  static readonly BG_RED_LIGHT: string = '#FFEDED';
  /** BgYellowLight rgba(255,183,3,.1) */
  static readonly BG_YELLOW_LIGHT: string = '#FFF6E0';
  /** BgPurpleLight rgba(104,49,255,.05) */
  static readonly BG_PURPLE_LIGHT: string = '#F3EEFF';
  /** BgGreenLight rgba(9,190,79,.05) */
  static readonly BG_GREEN_LIGHT: string = '#E8FBF0';

  /** Rate.kt active star 0xffFF6700 */
  static readonly STAR_ACTIVE: string = '#FF6700';
  /** Rate.kt inactive star 0xffC0C0C0 */
  static readonly STAR_INACTIVE: string = '#C0C0C0';
  /** Badge.kt default color = Color.Red */
  static readonly BADGE_RED: string = '#FF0000';
  /** M3 Dialog / sheet scrim (black 32%) */
  static readonly SCRIM: string = '#52000000';
  /** BottomModal shadow / AppBottomButton shadowElevation 4dp approximation */
  static readonly SHADOW: string = '#1A000000';
}
