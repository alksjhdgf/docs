/**
 * FootprintRepository (source: core/data/repository/FootprintRepository.kt → FootprintDao).
 * Table `footprints`, goodsId PK REPLACE, ordered by viewTime DESC (DATA-A16).
 * Room Flow observation is replaced by subscribe/unsubscribe and observe* helpers.
 */
import { Footprint } from '../../model/Market';
import { FootprintDao } from '../../storage/FootprintDao';
import { QueryObserver } from './QueryObserver';

export class FootprintRepository {
  /** "Me" page shows the latest 8 footprints */
  static readonly ME_RECENT_LIMIT: number = FootprintDao.ME_RECENT_LIMIT;

  static addFootprint(footprint: Footprint): Promise<void> {
    return FootprintDao.instance.addFootprint(footprint);
  }

  static removeFootprint(goodsId: number): Promise<void> {
    return FootprintDao.instance.removeFootprint(goodsId);
  }

  static clearAllFootprints(): Promise<void> {
    return FootprintDao.instance.clearAllFootprints();
  }

  static getAllFootprints(): Promise<Footprint[]> {
    return FootprintDao.instance.getAllFootprints();
  }

  static getFootprintCount(): Promise<number> {
    return FootprintDao.instance.getFootprintCount();
  }

  static getRecentFootprints(limit: number): Promise<Footprint[]> {
    return FootprintDao.instance.getRecentFootprints(limit);
  }

  static getFootprintByGoodsId(goodsId: number): Promise<Footprint | null> {
    return FootprintDao.instance.getFootprintByGoodsId(goodsId);
  }

  /** Raw change subscription: cb is called after every write to `footprints`. */
  static subscribe(cb: () => void): number {
    return FootprintDao.instance.subscribe(cb);
  }

  static unsubscribe(id: number): void {
    FootprintDao.instance.unsubscribe(id);
  }

  /** Flow equivalent of getAllFootprints() */
  static observeAllFootprints(onData: (list: Footprint[]) => void): number {
    return QueryObserver.observe<Footprint[]>((cb: () => void): number => FootprintDao.instance.subscribe(cb),
      (): Promise<Footprint[]> => FootprintDao.instance.getAllFootprints(), onData);
  }

  /** Flow equivalent of getRecentFootprints(limit) */
  static observeRecentFootprints(limit: number, onData: (list: Footprint[]) => void): number {
    return QueryObserver.observe<Footprint[]>((cb: () => void): number => FootprintDao.instance.subscribe(cb),
      (): Promise<Footprint[]> => FootprintDao.instance.getRecentFootprints(limit), onData);
  }

  /** Flow equivalent of getFootprintCount() */
  static observeFootprintCount(onData: (count: number) => void): number {
    return QueryObserver.observe<number>((cb: () => void): number => FootprintDao.instance.subscribe(cb),
      (): Promise<number> => FootprintDao.instance.getFootprintCount(), onData);
  }
}
