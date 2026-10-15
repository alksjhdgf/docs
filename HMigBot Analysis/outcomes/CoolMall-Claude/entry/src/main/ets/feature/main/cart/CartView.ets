/**
 * CartView (source: feature/main/view/CartScreen.kt — CartRoute / CartScreen / CartContentView / CartBottomBar).
 * Reused by the main tab (showBackIcon = false) and the standalone MainRoutesCart page (showBackIcon from CartParam).
 *
 * Layout (source CommonScaffold → M3 Scaffold, background = bg_page):
 *   Column {
 *     CenterTopAppBar `购物车` (back arrow only when showBackIcon; actions: `编辑`/`完成` when not empty)
 *     content (layoutWeight 1): EmptyCart (no button) | List of OrderGoodsCard (padding 12, spacedBy 12)
 *     CartBottomBar (when not empty)
 *   }
 * Delete flow (source deletingItems + LaunchedEffect): snapshot the selection into `deletingItems` → the selected
 * specs / whole goods cards slide out to the left with a fade (tween 300) → after 300 ms the VM deletes them.
 */
import { Cart, CartGoodsSpec } from '../../../core/model/Order';
import { Dimens } from '../../../core/designsystem/Dimens';
import { CenterTopAppBar } from '../../../core/ui/base/TopAppBars';
import { EmptyCart } from '../../../core/ui/base/StateViews';
import { AvoidArea } from '../../../core/ui/base/AvoidArea';
import { OrderGoodsCard } from '../../../core/ui/commerce/GoodsItems';
import { AppButtonFixed, AppButtonShape, AppButtonSize, AppButtonType, CheckButton } from '../../../core/ui/widget/Buttons';
import { PriceText } from '../../../core/ui/widget/Texts';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { CartViewModel } from './CartViewModel';

/** source delay(300) — wait for the exit animation */
const DELETE_ANIMATION_MS: number = 300;
/** source widthIn(min = 90.dp) on the settle / delete button */
const BOTTOM_BUTTON_MIN_WIDTH: number = 90;

@ComponentV2
export struct CartView {
  /** source MainRoutes.Cart.showBackIcon */
  @Param showBackIcon: boolean = false;

  @Local vm: CartViewModel = new CartViewModel();
  /** source deletingItems: goodsId → spec ids currently animating out */
  @Local deletingItems: Map<number, number[]> = new Map<number, number[]>();
  @Local avoidArea: AvoidArea = AvoidArea.get();

  private deleteTimer: number = -1;
  private alive: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    this.vm.showBackIcon = this.showBackIcon;
    this.vm.start();
  }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.deleteTimer >= 0) {
      clearTimeout(this.deleteTimer);
      this.deleteTimer = -1;
    }
    this.vm.stop();
  }

  @Monitor('showBackIcon')
  onShowBackIconChanged(): void {
    this.vm.showBackIcon = this.showBackIcon;
  }

  /** source handleDeleteWithAnimation + LaunchedEffect(deletingItems) */
  private handleDeleteWithAnimation(): void {
    if (this.deleteTimer >= 0) {
      return;
    }
    const snapshot: Map<number, number[]> = this.vm.snapshotSelection();
    if (snapshot.size === 0) {
      return;
    }
    this.deletingItems = snapshot;
    this.deleteTimer = setTimeout(() => {
      this.deleteTimer = -1;
      if (!this.alive) {
        return;
      }
      this.vm.deleteSelectedItems().then((): void => {
        if (this.alive) {
          this.deletingItems = new Map<number, number[]>();
        }
      });
    }, DELETE_ANIMATION_MS);
  }

  private deletingSpecsOf(goodsId: number): number[] {
    return this.deletingItems.get(goodsId) ?? [];
  }

  /**
   * source isCartDeleting: every spec of the goods was selected and is being deleted. Decided from the
   * deleting snapshot alone so the card stays hidden until the reloaded list arrives.
   */
  private isCartDeleting(cart: Cart): boolean {
    const deleting: number[] = this.deletingSpecsOf(cart.goodsId);
    if (deleting.length === 0 || cart.spec.length === 0) {
      return false;
    }
    for (const spec of cart.spec) {
      if (deleting.indexOf(spec.id) < 0) {
        return false;
      }
    }
    return true;
  }

  private cartKey(cart: Cart): string {
    const specKey: string = cart.spec.map((s: CartGoodsSpec): string =>
    s.id + ':' + s.count + ':' + s.price + ':' + s.name).join(',');
    return 'cart-' + cart.goodsId + '_' + cart.goodsName + '_' + cart.goodsMainPic + '_' + specKey;
  }

  // ============================== top bar ==============================

  @Builder
  editAction() {
    if (!this.vm.isEmpty()) {
      // source TextButton (labelLarge, onSurface)
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text(this.vm.isEditing ? $r('app.string.complete') : $r('app.string.edit'))
          .fontSize(Dimens.fontTitleMedium)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .height(40)
      .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.vm.toggleEditMode();
      })
    }
  }

  // ============================== content ==============================

  @Builder
  specSelectSlot(goodsId: number, spec: CartGoodsSpec) {
    // selection read live from this.vm (A2-7)
    CheckButton({
      isSelected: this.vm.isSpecSelected(goodsId, spec.id),
      onCheckClick: () => {
        this.vm.toggleItemSelection(goodsId, spec.id);
      }
    })
  }

  @Builder
  cartContent() {
    List({ space: Dimens.spaceVerticalMedium }) {
      ForEach(this.vm.cartItems, (cart: Cart) => {
        ListItem() {
          if (!this.isCartDeleting(cart)) {
            Column() {
              OrderGoodsCard({
                data: cart,
                deletingSpecIds: this.deletingSpecsOf(cart.goodsId),
                hasSelectSlot: true,
                itemSelectSlot: (spec: CartGoodsSpec): void => {
                  this.specSelectSlot(cart.goodsId, spec)
                },
                onGoodsClick: (goodsId: number) => {
                  this.vm.toGoodsDetail(goodsId);
                },
                onQuantityChanged: (specId: number, count: number) => {
                  this.vm.updateCartItemCount(cart.goodsId, specId, count);
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            // source AnimatedVisibility exit: slideOutHorizontally(-width) + fadeOut, tween(300)
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.IDENTITY,
              TransitionEffect.translate({ x: '-100%' }).combine(TransitionEffect.OPACITY)
                .animation({ duration: DELETE_ANIMATION_MS, curve: Curve.EaseInOut })
            ))
          }
        }
        .width('100%')
      }, (cart: Cart) => this.cartKey(cart))
    }
    .width('100%')
    .height('100%')
    // source LazyColumn contentPadding(12): horizontal as padding, vertical as content offsets (scrolls with content)
    .padding({ left: Dimens.spacePaddingMedium, right: Dimens.spacePaddingMedium })
    .contentStartOffset(Dimens.spacePaddingMedium)
    .contentEndOffset(Dimens.spacePaddingMedium)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // ============================== bottom bar ==============================

  @Builder
  bottomBar() {
    Row() {
      CheckButton({
        isSelected: this.vm.isAllSelected(),
        onCheckClick: () => {
          this.vm.toggleSelectAll();
        }
      })
      // SpaceHorizontalSmall
      Row()
        .width(Dimens.spaceHorizontalSmall)
        .height(1)
      Text($r('app.string.select_all'))
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
      Blank()
      if (!this.vm.isEditing) {
        // source feature/main R.string.total = `合计:` (the merged app.string.total is `合计`, so the colon is appended)
        Text() {
          Span($r('app.string.total'))
          Span(':')
        }
        .fontSize(Dimens.fontBodyLarge)
        .lineHeight(Dimens.lineBodyLarge)
        .fontColor($r('app.color.text_primary'))
        Row()
          .width(Dimens.spaceHorizontalSmall)
          .height(1)
        PriceText({ price: this.vm.selectedTotalAmount() })
        Row()
          .width(Dimens.spaceHorizontalSmall)
          .height(1)
        Row() {
          AppButtonFixed({
            btnText: this.vm.selectedCount() === 0 ? $r('app.string.settle_account') :
            $r('app.string.settle_account_count', this.vm.selectedCount()),
            btnType: AppButtonType.DEFAULT,
            btnSize: AppButtonSize.MINI,
            btnShape: AppButtonShape.ROUND,
            btnEnabled: this.vm.selectedCount() > 0,
            onBtnClick: () => {
              this.vm.onCheckoutClick();
            }
          })
        }
        .constraintSize({ minWidth: BOTTOM_BUTTON_MIN_WIDTH })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      } else {
        Row() {
          AppButtonFixed({
            btnText: this.vm.selectedCount() === 0 ? $r('app.string.delete') :
            $r('app.string.delete_count', this.vm.selectedCount()),
            btnType: AppButtonType.DANGER,
            btnSize: AppButtonSize.MINI,
            btnShape: AppButtonShape.ROUND,
            btnEnabled: this.vm.selectedCount() > 0,
            onBtnClick: () => {
              this.handleDeleteWithAnimation();
            }
          })
        }
        .constraintSize({ minWidth: BOTTOM_BUTTON_MIN_WIDTH })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({
      left: Dimens.spacePaddingMedium,
      right: Dimens.spacePaddingMedium,
      top: Dimens.spacePaddingMedium,
      // standalone page: the bottom bar owns the navigation-bar inset; on the tab the shell's nav bar does
      bottom: Dimens.spacePaddingMedium + (this.showBackIcon ? this.avoidArea.bottom : 0)
    })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    // source Surface(shadowElevation 1dp, border 1dp outline@0.6)
    .backgroundColor($r('app.color.surface'))
    .border({ width: { top: 1 }, color: $r('app.color.divider') })
    .shadow({ radius: 2, color: '#1A000000', offsetY: -1 })
  }

  build() {
    Column() {
      CenterTopAppBar({
        titleText: $r('app.string.cart'),
        showBackIcon: this.showBackIcon,
        onBack: () => {
          AppNavigator.back();
        },
        actions: (): void => {
          this.editAction()
        }
      })

      Column() {
        if (this.vm.isEmpty()) {
          // source EmptyCart() — no button
          EmptyCart({ showRetry: false })
        } else {
          this.cartContent()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: (this.vm.isEmpty() && this.showBackIcon) ? this.avoidArea.bottom : 0 })

      if (!this.vm.isEmpty()) {
        this.bottomBar()
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_page'))
  }
}
