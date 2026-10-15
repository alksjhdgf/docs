/**
 * CartDao — Room CartDao + CartDataSource equivalent
 * (source: core/database/dao/CartDao.kt, datasource/cart/CartDataSource.kt, util/CartSpecConverter.kt).
 * The cart is purely local (DATA-A14); spec list stored as JSON text in column `spec`.
 * Room Flow observation is replaced by subscribe()/unsubscribe(): listeners fire after every write.
 */
import { relationalStore } from '@kit.ArkData';
import { Cart, CartGoodsSpec } from '../model/Order';
import { AppDatabase } from './AppDatabase';
import { DaoChangeNotifier } from './DaoChangeNotifier';
import { LogUtils } from '../util/LogUtils';

const TAG: string = 'CartDao';

export class CartDao {
  static readonly instance: CartDao = new CartDao();

  private notifier: DaoChangeNotifier = new DaoChangeNotifier(TAG);

  private constructor() {
  }

  // ====================== change notification ======================
  subscribe(cb: () => void): number {
    return this.notifier.subscribe(cb);
  }

  unsubscribe(id: number): void {
    this.notifier.unsubscribe(id);
  }

  // ====================== CartSpecConverter ======================
  /** fromSpecList: null/empty → "[]" */
  static specToJson(value: CartGoodsSpec[] | null): string {
    if (value === null || value.length === 0) {
      return '[]';
    }
    return JSON.stringify(value);
  }

  /** toSpecList: "" / "[]" / unparsable → [] (ignoreUnknownKeys) */
  static specFromJson(value: string): CartGoodsSpec[] {
    if (value.length === 0 || value === '[]') {
      return [];
    }
    try {
      const raw = JSON.parse(value) as CartGoodsSpec[];
      if (!Array.isArray(raw)) {
        return [];
      }
      const result: CartGoodsSpec[] = [];
      for (const item of raw) {
        const s = new CartGoodsSpec();
        s.id = item.id ?? 0;
        s.goodsId = item.goodsId ?? 0;
        s.name = item.name ?? '';
        s.price = item.price ?? 0;
        s.stock = item.stock ?? 0;
        s.count = item.count ?? 0;
        s.images = item.images ?? null;
        result.push(s);
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  private static toValues(cart: Cart): relationalStore.ValuesBucket {
    const vb: relationalStore.ValuesBucket = {
      'goodsId': cart.goodsId,
      'goodsName': cart.goodsName,
      'goodsMainPic': cart.goodsMainPic,
      'spec': CartDao.specToJson(cart.spec)
    };
    return vb;
  }

  private static readRows(rs: relationalStore.ResultSet): Cart[] {
    const list: Cart[] = [];
    try {
      const iId = rs.getColumnIndex('goodsId');
      const iName = rs.getColumnIndex('goodsName');
      const iPic = rs.getColumnIndex('goodsMainPic');
      const iSpec = rs.getColumnIndex('spec');
      while (rs.goToNextRow()) {
        const c = new Cart();
        c.goodsId = rs.getLong(iId);
        c.goodsName = rs.getString(iName);
        c.goodsMainPic = rs.getString(iPic);
        c.spec = CartDao.specFromJson(rs.isColumnNull(iSpec) ? '' : rs.getString(iSpec));
        list.push(c);
      }
    } finally {
      rs.close();
    }
    return list;
  }

  // ====================== Room CartDao ======================
  /** @Insert(onConflict = REPLACE) */
  async insertCart(cart: Cart): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.insert(AppDatabase.TABLE_CARTS, CartDao.toValues(cart),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    this.notifier.notifyChanged();
  }

  /** @Insert(onConflict = REPLACE) batch */
  async insertCarts(carts: Cart[]): Promise<void> {
    const store = await AppDatabase.getStore();
    for (const cart of carts) {
      await store.insert(AppDatabase.TABLE_CARTS, CartDao.toValues(cart),
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    }
    this.notifier.notifyChanged();
  }

  /** @Update — updates the row with the same goodsId; no-op when it does not exist */
  async updateCart(cart: Cart): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('UPDATE carts SET goodsName = ?, goodsMainPic = ?, spec = ? WHERE goodsId = ?',
      [cart.goodsName, cart.goodsMainPic, CartDao.specToJson(cart.spec), cart.goodsId]);
    this.notifier.notifyChanged();
  }

  /** @Delete (by primary key) */
  async deleteCart(cart: Cart): Promise<void> {
    await this.deleteCartByGoodsId(cart.goodsId);
  }

  async deleteCartByGoodsId(goodsId: number): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM carts WHERE goodsId = ?', [goodsId]);
    this.notifier.notifyChanged();
  }

  async clearCart(): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM carts');
    this.notifier.notifyChanged();
  }

  /** SELECT * FROM carts (no ORDER BY → insertion/rowid order, as in the source) */
  async getAllCarts(): Promise<Cart[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM carts');
    return CartDao.readRows(rs);
  }

  async getCartByGoodsId(goodsId: number): Promise<Cart | null> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM carts WHERE goodsId = ?', [goodsId]);
    const list = CartDao.readRows(rs);
    return list.length > 0 ? list[0] : null;
  }

  /** SELECT COUNT(*) FROM carts — number of goods rows (not the sum of spec counts) */
  async getCartCount(): Promise<number> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT COUNT(*) AS cnt FROM carts');
    let count = 0;
    try {
      if (rs.goToFirstRow()) {
        count = rs.getLong(0);
      }
    } finally {
      rs.close();
    }
    return count;
  }

  // ====================== CartDataSource ======================
  /** addToCart: REPLACE insert of the whole row */
  async addToCart(cart: Cart): Promise<void> {
    await this.insertCart(cart);
  }

  /**
   * updateCartSpecCount (DATA-A15): set one spec's count; if every spec count ≤ 0 afterwards
   * the whole row is deleted, otherwise the row is updated. Missing row → no-op.
   */
  async updateCartSpecCount(goodsId: number, specId: number, count: number): Promise<void> {
    const cart = await this.getCartByGoodsId(goodsId);
    if (cart === null) {
      return;
    }
    const updatedSpecs: CartGoodsSpec[] = cart.spec.map((spec: CartGoodsSpec): CartGoodsSpec => {
      if (spec.id === specId) {
        const copy = CartDao.copySpec(spec);
        copy.count = count;
        return copy;
      }
      return spec;
    });
    if (updatedSpecs.every((s: CartGoodsSpec): boolean => s.count <= 0)) {
      await this.deleteCartByGoodsId(goodsId);
    } else {
      cart.spec = updatedSpecs;
      await this.updateCart(cart);
    }
  }

  async removeFromCart(goodsId: number): Promise<void> {
    await this.deleteCartByGoodsId(goodsId);
  }

  /** removeSpecFromCart (DATA-A15): drop one spec; delete the row when no spec remains. */
  async removeSpecFromCart(goodsId: number, specId: number): Promise<void> {
    const cart = await this.getCartByGoodsId(goodsId);
    if (cart === null) {
      return;
    }
    const updatedSpecs = cart.spec.filter((s: CartGoodsSpec): boolean => s.id !== specId);
    if (updatedSpecs.length === 0) {
      await this.deleteCartByGoodsId(goodsId);
    } else {
      cart.spec = updatedSpecs;
      await this.updateCart(cart);
    }
  }

  /**
   * Add-to-cart merge (DATA-A14), lifted from GoodsDetailViewModel.addToCart so callers share one
   * implementation: existing row + same spec id → count += spec.count (via updateCartSpecCount);
   * existing row + new spec → append and updateCart; no row → insert a new row with this spec.
   * `spec.count` must already hold the quantity being added.
   */
  async mergeAddToCart(goodsId: number, goodsName: string, goodsMainPic: string,
    spec: CartGoodsSpec): Promise<void> {
    const existing = await this.getCartByGoodsId(goodsId);
    if (existing !== null) {
      let existingSpec: CartGoodsSpec | null = null;
      for (const s of existing.spec) {
        if (s.id === spec.id) {
          existingSpec = s;
          break;
        }
      }
      if (existingSpec !== null) {
        await this.updateCartSpecCount(goodsId, existingSpec.id, existingSpec.count + spec.count);
      } else {
        const specs: CartGoodsSpec[] = existing.spec.slice();
        specs.push(spec);
        existing.spec = specs;
        await this.updateCart(existing);
      }
    } else {
      const cart = new Cart();
      cart.goodsId = goodsId;
      cart.goodsName = goodsName;
      cart.goodsMainPic = goodsMainPic;
      cart.spec = [spec];
      await this.addToCart(cart);
    }
    LogUtils.dTag(TAG, 'mergeAddToCart goodsId=' + goodsId + ' specId=' + spec.id);
  }

  private static copySpec(spec: CartGoodsSpec): CartGoodsSpec {
    const s = new CartGoodsSpec();
    s.id = spec.id;
    s.goodsId = spec.goodsId;
    s.name = spec.name;
    s.price = spec.price;
    s.stock = spec.stock;
    s.count = spec.count;
    s.images = spec.images;
    return s;
  }
}
