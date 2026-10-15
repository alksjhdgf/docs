/**
 * MainRoutesCartPage — standalone cart page (source: MainRoutes.Cart(showBackIcon) → CartRoute / CartScreen).
 * The page content is the shared CartView (also embedded in the main shell's cart tab with showBackIcon=false).
 * Param: CartParam (showBackIcon, source default false); any other / missing param keeps the source default.
 */
import { CartParam } from '../core/navigation/RouteParams';
import { CartView } from '../feature/main/cart/CartView';

@Builder
export function MainRoutesCartPageBuilder() {
  MainRoutesCartPage()
}

@ComponentV2
struct MainRoutesCartPage {
  @Local showBackIcon: boolean = false;

  build() {
    NavDestination() {
      Column() {
        CartView({ showBackIcon: this.showBackIcon })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (p !== undefined && p !== null && p instanceof CartParam) {
        this.showBackIcon = (p as CartParam).showBackIcon;
      }
    })
  }
}
