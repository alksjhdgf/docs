/**
 * AppDatabase — Room AppDatabase equivalent (source: core/database/AppDatabase.kt, entity/*.kt).
 * relationalStore database `coolmall-database.db` (source DATABASE_NAME = "coolmall-database", version 1),
 * tables `carts`, `footprints`, `search_history` with column names copied verbatim from the entities.
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LogUtils } from '../util/LogUtils';

const TAG: string = 'AppDatabase';

export class AppDatabase {
  static readonly DATABASE_NAME: string = 'coolmall-database.db';
  static readonly DATABASE_VERSION: number = 1;

  static readonly TABLE_CARTS: string = 'carts';
  static readonly TABLE_FOOTPRINTS: string = 'footprints';
  static readonly TABLE_SEARCH_HISTORY: string = 'search_history';

  /** CartEntity: goodsId PK, goodsName, goodsMainPic, spec (List<CartGoodsSpec> as JSON via CartSpecConverter) */
  private static readonly SQL_CREATE_CARTS: string =
    'CREATE TABLE IF NOT EXISTS `carts` (`goodsId` INTEGER NOT NULL, `goodsName` TEXT NOT NULL, ' +
      '`goodsMainPic` TEXT NOT NULL, `spec` TEXT NOT NULL, PRIMARY KEY(`goodsId`))';

  /** FootprintEntity */
  private static readonly SQL_CREATE_FOOTPRINTS: string =
    'CREATE TABLE IF NOT EXISTS `footprints` (`goodsId` INTEGER NOT NULL, `goodsName` TEXT NOT NULL, ' +
      '`goodsSubTitle` TEXT, `goodsMainPic` TEXT NOT NULL, `goodsPrice` INTEGER NOT NULL, ' +
      '`goodsSold` INTEGER NOT NULL, `viewTime` INTEGER NOT NULL, PRIMARY KEY(`goodsId`))';

  /** SearchHistoryEntity */
  private static readonly SQL_CREATE_SEARCH_HISTORY: string =
    'CREATE TABLE IF NOT EXISTS `search_history` (`keyword` TEXT NOT NULL, `searchTime` INTEGER NOT NULL, ' +
      'PRIMARY KEY(`keyword`))';

  private static storePromise: Promise<relationalStore.RdbStore> | null = null;
  private static readyResolver: ((store: relationalStore.RdbStore) => void) | null = null;
  private static readyPromise: Promise<relationalStore.RdbStore> | null = null;

  /**
   * Opens the database and creates the tables. Call from EntryAbility.onCreate (async is fine);
   * DAOs await getStore(), so calls issued before init completes simply wait for it.
   */
  static init(ctx: common.Context): Promise<void> {
    if (AppDatabase.storePromise === null) {
      AppDatabase.storePromise = AppDatabase.open(ctx);
      AppDatabase.storePromise.then((store: relationalStore.RdbStore) => {
        if (AppDatabase.readyResolver !== null) {
          AppDatabase.readyResolver(store);
          AppDatabase.readyResolver = null;
        }
      }).catch((e: Object) => {
        LogUtils.eTag(TAG, 'open database failed: ' + JSON.stringify(e));
        AppDatabase.storePromise = null;
      });
    }
    return AppDatabase.storePromise.then((): void => {
    });
  }

  private static async open(ctx: common.Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: AppDatabase.DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(ctx, config);
    if (store.version === 0) {
      await store.executeSql(AppDatabase.SQL_CREATE_CARTS);
      await store.executeSql(AppDatabase.SQL_CREATE_FOOTPRINTS);
      await store.executeSql(AppDatabase.SQL_CREATE_SEARCH_HISTORY);
      store.version = AppDatabase.DATABASE_VERSION;
    } else {
      // Defensive: IF NOT EXISTS keeps this idempotent should a table be missing.
      await store.executeSql(AppDatabase.SQL_CREATE_CARTS);
      await store.executeSql(AppDatabase.SQL_CREATE_FOOTPRINTS);
      await store.executeSql(AppDatabase.SQL_CREATE_SEARCH_HISTORY);
    }
    LogUtils.iTag(TAG, 'database ready, version ' + store.version);
    return store;
  }

  /** Resolves with the opened store; waits for init() if it has not completed yet. */
  static getStore(): Promise<relationalStore.RdbStore> {
    if (AppDatabase.storePromise !== null) {
      return AppDatabase.storePromise;
    }
    if (AppDatabase.readyPromise === null) {
      AppDatabase.readyPromise = new Promise<relationalStore.RdbStore>(
        (resolve: (store: relationalStore.RdbStore) => void) => {
          AppDatabase.readyResolver = resolve;
        });
    }
    return AppDatabase.readyPromise;
  }
}
