/**
 * Coupon sheets (source: core/ui/component/modal/CouponModal.kt, CouponReceiveModal.kt).
 *
 *  - CouponModal: title (default `领取优惠券`), list of CouponCard (mode, currentPrice), max 500vp high,
 *    each card's action → onCouponAction(coupon.id). Used for receive (home / goods detail, RECEIVE) and
 *    select (order confirm, SELECT + currentPrice + selectedCouponId).
 *  - CouponReceiveModal: the CouponReceiveModal.kt overload (no currentPrice), default RECEIVE.
 *
 * Source containerColor = colorScheme.background, indicator onSurface @ 0.1. Bind with:
 *   .bindSheet(this.couponVisible, this.couponSheet(),
 *     CommerceSheet.options(() => { this.couponVisible = false; }, undefined, $r('app.color.bg_page')))
 */
import { Coupon } from '../../model/Market';
import { Dimens } from '../../designsystem/Dimens';
import { BottomModal } from '../widget/BottomSheet';
import { CouponCard, CouponCardMode } from './CouponCard';
import { CommerceSheet } from './CommerceSheet';

const LIST_MAX_HEIGHT: number = 500;

function isBlank(v: ResourceStr): boolean {
  return typeof v === 'string' && (v as string).length === 0;
}

@ComponentV2
export struct CouponModal {
  @Param coupons: Coupon[] = [];
  /** '' → `领取优惠券` (coupon_modal_title) */
  @Param sheetTitle: ResourceStr = '';
  @Param mode: CouponCardMode = CouponCardMode.RECEIVE;
  /** Order amount for the SELECT-mode condition check; null = no check */
  @Param currentPrice: number | null = null;
  /**
   * Selected coupon id in SELECT mode. The source CouponModalContent never passes isSelected to the
   * cards (so `已选择` is never shown there); keep the default -1 for source behaviour.
   */
  @Param selectedCouponId: number = -1;
  @Event onCouponAction: (couponId: number) => void = (couponId: number) => {
  };

  private finalTitle(): ResourceStr {
    return isBlank(this.sheetTitle) ? $r('app.string.coupon_modal_title') : this.sheetTitle;
  }

  @Builder
  listContent() {
    // WrapColumn { LazyColumn(fillMaxWidth, heightIn(max = 500)) }
    Scroll() {
      Column() {
        ForEach(this.coupons, (coupon: Coupon) => {
          Column() {
            CouponCard({
              coupon: coupon,
              mode: this.mode,
              currentPrice: this.currentPrice,
              isSelected: coupon.id === this.selectedCouponId,
              onActionClick: () => {
                this.onCouponAction(coupon.id);
              }
            })
          }
          .width('100%')
          .padding({ bottom: Dimens.spaceVerticalMedium })
          .alignItems(HorizontalAlign.Start)
        }, (coupon: Coupon) => coupon.id + '_' + coupon.useStatus + '_' + coupon.endTime + '_' + coupon.title)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxHeight: LIST_MAX_HEIGHT })
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  build() {
    Column() {
      BottomModal({
        sheetTitle: this.finalTitle(),
        indicatorColor: CommerceSheet.faintIndicatorColor(),
        sheetContent: (): void => {
          this.listContent()
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** CouponReceiveModal.kt: same sheet without the price condition check (default RECEIVE). */
@ComponentV2
export struct CouponReceiveModal {
  @Param coupons: Coupon[] = [];
  @Param sheetTitle: ResourceStr = '';
  @Param mode: CouponCardMode = CouponCardMode.RECEIVE;
  @Event onCouponAction: (couponId: number) => void = (couponId: number) => {
  };

  build() {
    Column() {
      CouponModal({
        coupons: this.coupons,
        sheetTitle: this.sheetTitle,
        mode: this.mode,
        onCouponAction: (couponId: number) => {
          this.onCouponAction(couponId);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
