/**
 * CartRepository (source: core/data/repository/CartRepository.kt → CartDataSource → CartDao).
 * Purely local cart (DATA-A14/A15), table `carts`. Room Flow observation is replaced by
 * subscribe/unsubscribe (raw change callbacks) and observeAllCarts/observeCartCount (query + re-query).
 */
import { Cart, CartGoodsSpec } from '../../model/Order';
import { CartDao } from '../../storage/CartDao';
import { QueryObserver } from './QueryObserver';

export class CartRepository {
  static addToCart(cart: Cart): Promise<void> {
    return CartDao.instance.addToCart(cart);
  }

  static updateCart(cart: Cart): Promise<void> {
    return CartDao.instance.updateCart(cart);
  }

  /** DATA-A15: row deleted once every spec count ≤ 0 */
  static updateCartSpecCount(goodsId: number, specId: number, count: number): Promise<void> {
    return CartDao.instance.updateCartSpecCount(goodsId, specId, count);
  }

  static removeFromCart(goodsId: number): Promise<void> {
    return CartDao.instance.removeFromCart(goodsId);
  }

  /** DATA-A15: row deleted when no spec remains */
  static removeSpecFromCart(goodsId: number, specId: number): Promise<void> {
    return CartDao.instance.removeSpecFromCart(goodsId, specId);
  }

  static clearCart(): Promise<void> {
    return CartDao.instance.clearCart();
  }

  /** Snapshot of all cart rows (source getAllCarts() Flow first value) */
  static getAllCarts(): Promise<Cart[]> {
    return CartDao.instance.getAllCarts();
  }

  /** Number of goods rows (not item quantity) */
  static getCartCount(): Promise<number> {
    return CartDao.instance.getCartCount();
  }

  static getCartByGoodsId(goodsId: number): Promise<Cart | null> {
    return CartDao.instance.getCartByGoodsId(goodsId);
  }

  /** Add-to-cart merge shared with goods detail (DATA-A14), see CartDao.mergeAddToCart */
  static mergeAddToCart(goodsId: number, goodsName: string, goodsMainPic: string,
    spec: CartGoodsSpec): Promise<void> {
    return CartDao.instance.mergeAddToCart(goodsId, goodsName, goodsMainPic, spec);
  }

  /** Raw change subscription: cb is called after every write to `carts`. Returns an id for unsubscribe. */
  static subscribe(cb: () => void): number {
    return CartDao.instance.subscribe(cb);
  }

  static unsubscribe(id: number): void {
    CartDao.instance.unsubscribe(id);
  }

  /** Flow equivalent of getAllCarts(): emits now and after every change. */
  static observeAllCarts(onData: (carts: Cart[]) => void): number {
    return QueryObserver.observe<Cart[]>((cb: () => void): number => CartDao.instance.subscribe(cb),
      (): Promise<Cart[]> => CartDao.instance.getAllCarts(), onData);
  }

  /** Flow equivalent of getCartCount(): emits now and after every change. */
  static observeCartCount(onData: (count: number) => void): number {
    return QueryObserver.observe<number>((cb: () => void): number => CartDao.instance.subscribe(cb),
      (): Promise<number> => CartDao.instance.getCartCount(), onData);
  }
}
