/**
 * BlocklistDao（源 db/room/BlocklistDao.kt + BlocklistEntry.kt）。DB-A39/A40。
 * 模式以 `'*' || pattern || '*'` glob 存储；匹配对象为 lower(plain_title)（可选 plain_snippet、link），
 * glob 区分大小写，故调用方须传入小写模式（源 SettingsStore.addBlocklistPattern 先 lowercase().trim()）。
 */
import { ID_UNSET } from '../model/Enums';
import { AppDatabase, DbConn, SqlArg, TABLE_BLOCKLIST, TABLE_FEED_ITEMS, boolArg, observeQuery } from './AppDatabase';
import { readStringColumn } from './DbRows';

/** 源 BlocklistEntry 实体 */
export class BlocklistEntry {
  id: number = ID_UNSET;
  globPattern: string = '';
}

/** 三个重算语句共用的命中判定（源逐字） */
const MATCH_EXISTS: string = `exists(
                    select 1 from blocklist
                    where lower(feed_items.plain_title) glob blocklist.glob_pattern
                        or ? and lower(feed_items.plain_snippet) glob blocklist.glob_pattern
                        or ? and lower(feed_items.link) glob blocklist.glob_pattern
                )`;

export class BlocklistDao {
  private static async write(sql: string, args: SqlArg[], tables: string[], tx: DbConn | null): Promise<void> {
    await AppDatabase.run<void>(tx, async (c: DbConn): Promise<void> => {
      await c.exec(sql, args);
      c.markChanged(tables);
    });
  }

  /** 唯一冲突时抛错（同源 @Query INSERT，无冲突策略） */
  static async insertSafely(pattern: string, tx: DbConn | null = null): Promise<void> {
    await BlocklistDao.write(`
            INSERT INTO blocklist (id, glob_pattern)
            VALUES (null, '*' || ? || '*')
        `, [pattern], [TABLE_BLOCKLIST], tx);
  }

  static async deletePattern(pattern: string, tx: DbConn | null = null): Promise<void> {
    await BlocklistDao.write(`
            DELETE FROM blocklist
            WHERE glob_pattern = ('*' || ? || '*')
        `, [pattern], [TABLE_BLOCKLIST], tx);
  }

  static async getGlobPatterns(tx: DbConn | null = null): Promise<string[]> {
    return readStringColumn(await AppDatabase.reader(tx).query(`
            SELECT glob_pattern
            FROM blocklist
            ORDER BY glob_pattern
        `));
  }

  static observeGlobPatterns(cb: (patterns: string[]) => void): () => void {
    return observeQuery<string[]>([TABLE_BLOCKLIST], () => BlocklistDao.getGlobPatterns(), cb);
  }

  /** 全表重算：命中 → coalesce(block_time, blockTime)（已有保留），未命中 → null */
  static async setItemBlockStatus(blockTime: number, applyToSummaries: boolean, applyToLinks: boolean,
    tx: DbConn | null = null): Promise<void> {
    await BlocklistDao.write(`
            update feed_items
            set block_time = case
                when ${MATCH_EXISTS}
                then coalesce(block_time, ?)
                else null
                end
        `, [boolArg(applyToSummaries), boolArg(applyToLinks), blockTime], [TABLE_FEED_ITEMS], tx);
  }

  static async setItemBlockStatusWhereNull(blockTime: number, applyToSummaries: boolean, applyToLinks: boolean,
    tx: DbConn | null = null): Promise<void> {
    await BlocklistDao.write(`
            update feed_items
            set block_time = case
                when ${MATCH_EXISTS}
                then ?
                else null
                end
            where block_time is null
        `, [boolArg(applyToSummaries), boolArg(applyToLinks), blockTime], [TABLE_FEED_ITEMS], tx);
  }

  /** 新同步文章：仅本订阅 block_time 为 null 的条目 */
  static async setItemBlockStatusForNewInFeed(feedId: number, blockTime: number, applyToSummaries: boolean,
    applyToLinks: boolean, tx: DbConn | null = null): Promise<void> {
    await BlocklistDao.write(`
            update feed_items
            set block_time = case
                when ${MATCH_EXISTS}
                then ?
                else null
                end
            where feed_id = ? and block_time is null
        `, [boolArg(applyToSummaries), boolArg(applyToLinks), blockTime, feedId], [TABLE_FEED_ITEMS], tx);
  }
}
