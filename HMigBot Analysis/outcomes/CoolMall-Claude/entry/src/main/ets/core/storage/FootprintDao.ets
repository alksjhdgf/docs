/**
 * FootprintDao — Room FootprintDao + FootprintDataSource equivalent
 * (source: core/database/dao/FootprintDao.kt, datasource/footprint/FootprintDataSource.kt).
 * DATA-A16: goodsId PK with REPLACE (revisit refreshes viewTime), ordered by viewTime DESC,
 * "Me" page shows getRecentFootprints(8), clearAllFootprints() clears everything.
 */
import { relationalStore } from '@kit.ArkData';
import { Footprint } from '../model/Market';
import { AppDatabase } from './AppDatabase';
import { DaoChangeNotifier } from './DaoChangeNotifier';

const TAG: string = 'FootprintDao';

export class FootprintDao {
  static readonly instance: FootprintDao = new FootprintDao();
  /** MeViewModel: footprintRepository.getRecentFootprints(8) */
  static readonly ME_RECENT_LIMIT: number = 8;

  private notifier: DaoChangeNotifier = new DaoChangeNotifier(TAG);

  private constructor() {
  }

  subscribe(cb: () => void): number {
    return this.notifier.subscribe(cb);
  }

  unsubscribe(id: number): void {
    this.notifier.unsubscribe(id);
  }

  private static readRows(rs: relationalStore.ResultSet): Footprint[] {
    const list: Footprint[] = [];
    try {
      const iId = rs.getColumnIndex('goodsId');
      const iName = rs.getColumnIndex('goodsName');
      const iSub = rs.getColumnIndex('goodsSubTitle');
      const iPic = rs.getColumnIndex('goodsMainPic');
      const iPrice = rs.getColumnIndex('goodsPrice');
      const iSold = rs.getColumnIndex('goodsSold');
      const iTime = rs.getColumnIndex('viewTime');
      while (rs.goToNextRow()) {
        const f = new Footprint();
        f.goodsId = rs.getLong(iId);
        f.goodsName = rs.getString(iName);
        f.goodsSubTitle = rs.isColumnNull(iSub) ? null : rs.getString(iSub);
        f.goodsMainPic = rs.getString(iPic);
        f.goodsPrice = rs.getLong(iPrice);
        f.goodsSold = rs.getLong(iSold);
        f.viewTime = rs.getLong(iTime);
        list.push(f);
      }
    } finally {
      rs.close();
    }
    return list;
  }

  /** @Insert(onConflict = REPLACE) — revisiting a goods refreshes its viewTime */
  async insertFootprint(footprint: Footprint): Promise<void> {
    const store = await AppDatabase.getStore();
    const vb: relationalStore.ValuesBucket = {
      'goodsId': footprint.goodsId,
      'goodsName': footprint.goodsName,
      'goodsSubTitle': footprint.goodsSubTitle,
      'goodsMainPic': footprint.goodsMainPic,
      'goodsPrice': footprint.goodsPrice,
      'goodsSold': footprint.goodsSold,
      'viewTime': footprint.viewTime
    };
    await store.insert(AppDatabase.TABLE_FOOTPRINTS, vb, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    this.notifier.notifyChanged();
  }

  async deleteFootprintByGoodsId(goodsId: number): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM footprints WHERE goodsId = ?', [goodsId]);
    this.notifier.notifyChanged();
  }

  async clearAllFootprints(): Promise<void> {
    const store = await AppDatabase.getStore();
    await store.executeSql('DELETE FROM footprints');
    this.notifier.notifyChanged();
  }

  async getAllFootprints(): Promise<Footprint[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM footprints ORDER BY viewTime DESC');
    return FootprintDao.readRows(rs);
  }

  async getFootprintCount(): Promise<number> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT COUNT(*) AS cnt FROM footprints');
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

  async getRecentFootprints(limit: number): Promise<Footprint[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM footprints ORDER BY viewTime DESC LIMIT ?', [limit]);
    return FootprintDao.readRows(rs);
  }

  async getFootprintByGoodsId(goodsId: number): Promise<Footprint | null> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT * FROM footprints WHERE goodsId = ?', [goodsId]);
    const list = FootprintDao.readRows(rs);
    return list.length > 0 ? list[0] : null;
  }

  // ====================== FootprintDataSource aliases ======================
  async addFootprint(footprint: Footprint): Promise<void> {
    await this.insertFootprint(footprint);
  }

  async removeFootprint(goodsId: number): Promise<void> {
    await this.deleteFootprintByGoodsId(goodsId);
  }
}
