/**
 * Shared bindSheet options + colors for the business sheets in this directory
 * (SpecSelectSheet / CouponSheets / DictSelectSheet / OrderGoodsSheet).
 *
 * Source sheets are ModalBottomSheet(skipPartiallyExpanded = true) driven by `visible` + `onDismiss`;
 * several also expose `onExpanded` (fired once the sheet is fully expanded, used to lazy-load data —
 * GOODS-A06 / ORDA-A16). In ArkUI the page owns the visibility flag and binds the sheet:
 *
 *   @Local specVisible: boolean = false;
 *   @Builder specSheet() { SpecSelectSheet({ ..., onDismiss: () => { this.specVisible = false; } }) }
 *   Column() {...}
 *     .bindSheet(this.specVisible, this.specSheet(),
 *       CommerceSheet.options(() => { this.specVisible = false; }, () => { this.vm.onSpecModalExpanded(); }))
 *
 * `onExpanded` maps to SheetOptions.onAppear (called after the sheet's show animation completes).
 */
import { SheetDefaults } from '../widget/BottomSheet';
import { ThemeManager } from '../../designsystem/ThemeManager';

export class CommerceSheet {
  /**
   * SheetOptions = SheetDefaults.options (fit content, 16vp top radius, no system drag bar) +
   * optional onExpanded (onAppear). containerColor: undefined → surface (BottomModal default);
   * pass `$r('app.color.bg_page')` for sheets whose source uses colorScheme.background.
   */
  static options(onDismiss: () => void, onExpanded?: () => void, containerColor?: ResourceColor): SheetOptions {
    const opts: SheetOptions = SheetDefaults.options(onDismiss, containerColor);
    if (onExpanded !== undefined) {
      const cb: () => void = onExpanded;
      opts.onAppear = (): void => {
        cb();
      };
    }
    return opts;
  }

  /**
   * Drag indicator color onSurface @ 0.1 used by CouponModal / OrderGoodsModal. BottomModal draws the
   * indicator at opacity 0.8, so the color carries alpha 0.125 (0.125 × 0.8 = 0.1).
   */
  static faintIndicatorColor(): string {
    return ThemeManager.instance.isDark ? '#20D1D1D1' : '#20181818';
  }

  /** colorScheme.outline @ 0.8 (spec item border, radio border uses plain outline) */
  static outline80(): string {
    return ThemeManager.instance.isDark ? '#CC242424' : '#CCEEEEEE';
  }

  /** colorScheme.onSurface @ 0.6 (icon tints) */
  static onSurface60(): string {
    return ThemeManager.instance.isDark ? '#99D1D1D1' : '#99181818';
  }
}
