/**
 * CartViewModel (source: feature/main/viewmodel/CartViewModel.kt).
 *
 * - Cart rows come from the local `carts` table (CartRepository, no network, not tied to the account) and are
 *   observed live: query once, then re-query after every CartDao write (J3 / MAIN-A12). Each CartView
 *   instance (main tab + standalone page) owns one VM, so both refresh on any write.
 * - Selection is a goodsId → specId[] map, replaced immutably on every change (source StateFlow<Map<Long, Set<Long>>>).
 * - Derived values (isEmpty / isAllSelected / selectedCount / selectedTotalAmount) are methods reading @Trace state.
 */
import { Routes } from '../../../common/Router';
import { Cart, CartGoodsSpec } from '../../../core/model/Order';
import { CartRepository } from '../../../core/data/repository/CartRepository';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { GoodsDetailParam } from '../../../core/navigation/RouteParams';
import { KvKeys, KvStore } from '../../../core/storage/KvStore';
import { ToastUtils } from '../../../core/util/ToastUtils';
import { LogUtils } from '../../../core/util/LogUtils';

const TAG: string = 'CartViewModel';

/** Serialized GoodsSpec (kotlinx encodeDefaults=false: default-valued fields omitted) */
interface GoodsSpecJson {
  id?: number;
  goodsId?: number;
  name?: string;
  price?: number;
  stock?: number;
  images?: string[];
}

/** Serialized Goods (only the fields the source sets: id / title / mainPic; defaults omitted) */
interface GoodsJson {
  id?: number;
  title?: string;
  mainPic?: string;
}

/** Serialized SelectedGoods */
interface SelectedGoodsJson {
  goodsId?: number;
  goodsInfo?: GoodsJson;
  spec?: GoodsSpecJson;
  count?: number;
}

/** Serialized CartGoodsSpec */
interface CartGoodsSpecJson {
  id?: number;
  goodsId?: number;
  name?: string;
  price?: number;
  stock?: number;
  count?: number;
  images?: string[];
}

/** Serialized Cart */
interface CartJson {
  goodsId?: number;
  goodsName?: string;
  goodsMainPic?: string;
  spec?: CartGoodsSpecJson[];
}

@ObservedV2
export class CartViewModel {
  /** Show the back arrow (source navKey.showBackIcon) */
  @Trace showBackIcon: boolean = false;
  /** Edit mode */
  @Trace isEditing: boolean = false;
  /** goodsId → selected spec ids */
  @Trace selectedItems: Map<number, number[]> = new Map<number, number[]>();
  /** Cart rows (source cartItems, initial emptyList) */
  @Trace cartItems: Cart[] = [];

  private observeId: number = -1;
  private active: boolean = false;

  constructor(showBackIcon: boolean = false) {
    this.showBackIcon = showBackIcon;
  }

  // ============================== lifecycle ==============================

  /** Start observing the carts table (query now + after every write) */
  start(): void {
    if (this.active) {
      return;
    }
    this.active = true;
    this.observeId = CartRepository.observeAllCarts((carts: Cart[]): void => {
      if (!this.active) {
        return;
      }
      this.cartItems = carts;
    });
  }

  /** Stop observing (aboutToDisappear) */
  stop(): void {
    this.active = false;
    if (this.observeId >= 0) {
      CartRepository.unsubscribe(this.observeId);
      this.observeId = -1;
    }
  }

  // ============================== derived state ==============================

  /** source isEmpty */
  isEmpty(): boolean {
    return this.cartItems.length === 0;
  }

  /** source isAllSelected: total spec count > 0 && == selected spec count */
  isAllSelected(): boolean {
    if (this.cartItems.length === 0) {
      return false;
    }
    let totalSpecCount: number = 0;
    for (const cart of this.cartItems) {
      totalSpecCount += cart.spec.length;
    }
    return totalSpecCount > 0 && totalSpecCount === this.selectedCount();
  }

  /** source selectedCount: number of selected specs */
  selectedCount(): number {
    let count: number = 0;
    this.selectedItems.forEach((specIds: number[]): void => {
      count += specIds.length;
    });
    return count;
  }

  /** source selectedTotalAmount: Σ price × count of selected specs */
  selectedTotalAmount(): number {
    let total: number = 0;
    for (const cart of this.cartItems) {
      const specIds: number[] | undefined = this.selectedItems.get(cart.goodsId);
      if (specIds === undefined) {
        continue;
      }
      for (const spec of cart.spec) {
        if (specIds.indexOf(spec.id) >= 0) {
          total += spec.price * spec.count;
        }
      }
    }
    return total;
  }

  /** Whether one spec row is selected (selection is by goodsId + specId) */
  isSpecSelected(goodsId: number, specId: number): boolean {
    const specIds: number[] | undefined = this.selectedItems.get(goodsId);
    return specIds !== undefined && specIds.indexOf(specId) >= 0;
  }

  /** Snapshot copy of the current selection (for the delete animation) */
  snapshotSelection(): Map<number, number[]> {
    const copy: Map<number, number[]> = new Map<number, number[]>();
    this.selectedItems.forEach((specIds: number[], goodsId: number): void => {
      copy.set(goodsId, specIds.slice());
    });
    return copy;
  }

  // ============================== actions ==============================

  /** source toggleEditMode: clear selection, flip edit mode */
  toggleEditMode(): void {
    this.selectedItems = new Map<number, number[]>();
    this.isEditing = !this.isEditing;
  }

  /** source toggleSelectAll */
  toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.selectedItems = new Map<number, number[]>();
      return;
    }
    const newSelected: Map<number, number[]> = new Map<number, number[]>();
    for (const cart of this.cartItems) {
      const specIds: number[] = cart.spec.map((s: CartGoodsSpec): number => s.id);
      if (specIds.length > 0) {
        newSelected.set(cart.goodsId, specIds);
      }
    }
    this.selectedItems = newSelected;
  }

  /** source toggleItemSelection(goodsId, specId) */
  toggleItemSelection(goodsId: number, specId: number): void {
    const newSelected: Map<number, number[]> = this.snapshotSelection();
    const current: number[] = newSelected.get(goodsId) ?? [];
    const idx: number = current.indexOf(specId);
    if (idx >= 0) {
      current.splice(idx, 1);
      if (current.length === 0) {
        newSelected.delete(goodsId);
      } else {
        newSelected.set(goodsId, current);
      }
    } else {
      current.push(specId);
      newSelected.set(goodsId, current);
    }
    this.selectedItems = newSelected;
  }

  /** source updateCartItemCount: written to the local DB immediately (list refreshes via observation) */
  updateCartItemCount(goodsId: number, specId: number, count: number): void {
    CartRepository.updateCartSpecCount(goodsId, specId, count).catch((err: Error): void => {
      LogUtils.eTag(TAG, 'updateCartSpecCount failed: ' + (err?.message ?? ''));
    });
  }

  /**
   * source deleteSelectedItems: a goods whose specs are all selected is removed as a whole, otherwise
   * each selected spec is removed (the DAO deletes the row once no spec remains). Then selection is
   * cleared and edit mode ends.
   */
  async deleteSelectedItems(): Promise<void> {
    const itemsToDelete: Map<number, number[]> = this.snapshotSelection();
    const carts: Cart[] = this.cartItems;
    const goodsIds: number[] = Array.from(itemsToDelete.keys());
    try {
      for (const goodsId of goodsIds) {
        const specIds: number[] = itemsToDelete.get(goodsId) ?? [];
        const cart: Cart | undefined = carts.find((c: Cart): boolean => c.goodsId === goodsId);
        if (cart === undefined) {
          continue;
        }
        if (specIds.length === cart.spec.length) {
          await CartRepository.removeFromCart(goodsId);
        } else {
          for (const specId of specIds) {
            await CartRepository.removeSpecFromCart(goodsId, specId);
          }
        }
      }
    } catch (err) {
      LogUtils.eTag(TAG, 'deleteSelectedItems failed: ' + ((err as Error)?.message ?? ''));
    }
    if (!this.active) {
      return;
    }
    // reload now so the deleted rows are gone before the view drops its deleting snapshot
    try {
      this.cartItems = await CartRepository.getAllCarts();
    } catch (err) {
      LogUtils.eTag(TAG, 'reload after delete failed: ' + ((err as Error)?.message ?? ''));
    }
    if (!this.active) {
      return;
    }
    this.selectedItems = new Map<number, number[]>();
    this.isEditing = false;
  }

  /**
   * source onCheckoutClick: toast when nothing is selected; otherwise cache the selected carts (KV `carts`)
   * and the SelectedGoods list (KV `selectedGoodsList`), then go to OrderRoutes.Confirm (login wall applies).
   */
  onCheckoutClick(): void {
    if (this.selectedItems.size === 0) {
      ToastUtils.showError($r('app.string.please_select_settlement_goods'));
      return;
    }
    const selectedCarts: Cart[] = this.getSelectedCarts();
    if (selectedCarts.length === 0) {
      ToastUtils.showError($r('app.string.get_selected_goods_failed'));
      return;
    }
    KvStore.putObject(KvKeys.CARTS, CartViewModel.cartsToJson(selectedCarts));
    KvStore.putObject(KvKeys.SELECTED_GOODS_LIST, CartViewModel.convertCartsToSelectedGoods(selectedCarts));
    AppNavigator.navigate(Routes.ORDER_ROUTES_CONFIRM);
  }

  /** Go to goods detail (source GoodsNavigator.toDetail) */
  toGoodsDetail(goodsId: number): void {
    AppNavigator.navigate(Routes.GOODS_ROUTES_DETAIL, new GoodsDetailParam(goodsId));
  }

  // ============================== helpers ==============================

  /** source getSelectedCarts: copies of the carts holding only their selected specs */
  private getSelectedCarts(): Cart[] {
    const result: Cart[] = [];
    for (const cart of this.cartItems) {
      const specIds: number[] | undefined = this.selectedItems.get(cart.goodsId);
      if (specIds === undefined) {
        continue;
      }
      const newCart: Cart = new Cart();
      newCart.goodsId = cart.goodsId;
      newCart.goodsName = cart.goodsName;
      newCart.goodsMainPic = cart.goodsMainPic;
      newCart.spec = cart.spec.filter((s: CartGoodsSpec): boolean => specIds.indexOf(s.id) >= 0);
      if (newCart.spec.length > 0) {
        result.push(newCart);
      }
    }
    return result;
  }

  private static cartsToJson(carts: Cart[]): CartJson[] {
    const result: CartJson[] = [];
    for (const cart of carts) {
      const c: CartJson = {};
      if (cart.goodsId !== 0) {
        c.goodsId = cart.goodsId;
      }
      if (cart.goodsName !== '') {
        c.goodsName = cart.goodsName;
      }
      if (cart.goodsMainPic !== '') {
        c.goodsMainPic = cart.goodsMainPic;
      }
      if (cart.spec.length > 0) {
        const specs: CartGoodsSpecJson[] = [];
        for (const s of cart.spec) {
          const sj: CartGoodsSpecJson = {};
          if (s.id !== 0) {
            sj.id = s.id;
          }
          if (s.goodsId !== 0) {
            sj.goodsId = s.goodsId;
          }
          if (s.name !== '') {
            sj.name = s.name;
          }
          if (s.price !== 0) {
            sj.price = s.price;
          }
          if (s.stock !== 0) {
            sj.stock = s.stock;
          }
          if (s.count !== 0) {
            sj.count = s.count;
          }
          if (s.images !== null && s.images !== undefined) {
            sj.images = s.images;
          }
          specs.push(sj);
        }
        c.spec = specs;
      }
      result.push(c);
    }
    return result;
  }

  /** source convertCartsToSelectedGoods: one SelectedGoods per cart spec */
  private static convertCartsToSelectedGoods(carts: Cart[]): SelectedGoodsJson[] {
    const result: SelectedGoodsJson[] = [];
    for (const cart of carts) {
      for (const cartSpec of cart.spec) {
        const spec: GoodsSpecJson = {};
        if (cartSpec.id !== 0) {
          spec.id = cartSpec.id;
        }
        if (cartSpec.goodsId !== 0) {
          spec.goodsId = cartSpec.goodsId;
        }
        if (cartSpec.name !== '') {
          spec.name = cartSpec.name;
        }
        if (cartSpec.price !== 0) {
          spec.price = cartSpec.price;
        }
        if (cartSpec.stock !== 0) {
          spec.stock = cartSpec.stock;
        }
        if (cartSpec.images !== null && cartSpec.images !== undefined) {
          spec.images = cartSpec.images;
        }
        const goodsInfo: GoodsJson = {};
        if (cart.goodsId !== 0) {
          goodsInfo.id = cart.goodsId;
        }
        if (cart.goodsName !== '') {
          goodsInfo.title = cart.goodsName;
        }
        if (cart.goodsMainPic !== '') {
          goodsInfo.mainPic = cart.goodsMainPic;
        }
        const sg: SelectedGoodsJson = {};
        if (cart.goodsId !== 0) {
          sg.goodsId = cart.goodsId;
        }
        sg.goodsInfo = goodsInfo;
        sg.spec = spec;
        if (cartSpec.count !== 0) {
          sg.count = cartSpec.count;
        }
        result.push(sg);
      }
    }
    return result;
  }
}
