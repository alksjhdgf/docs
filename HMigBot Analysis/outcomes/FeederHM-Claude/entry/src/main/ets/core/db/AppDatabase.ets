/**
 * AppDatabase — relationalStore 建库与连接管理（源 db/room/AppDatabase.kt + Room InvalidationTracker 等价物）。
 *
 * - 库名 `rssDatabase`，schema 版本 40；建表/索引/视图 SQL 逐字取自
 *   input/Feeder/app/schemas/com.nononsenseapps.feeder.db.room.AppDatabase/40.json（DB-A01/A02）。
 * - 开启 `PRAGMA foreign_keys = ON`；另外 DAO 的删除路径显式执行级联删除，保证 RdbStore 连接池中任意连接
 *   （含 createTransaction 的事务连接）都满足 ON DELETE CASCADE 语义（DB-A05/A06）。
 * - 写入经单一写锁串行化（避免 SQLITE_BUSY 与事务交错）；`transaction(fn)` 使用 RdbStore.createTransaction，
 *   fn 收到事务连接 DbConn，DAO 方法末参 `tx` 传入即在事务内执行。
 * - DbNotifier：写后按表名通知（视图 feeds_with_items_for_nav_drawer 依赖 feeds/feed_items 自动联动），
 *   等价源 Room Flow/PagingSource 的失效刷新（DB-A28）。
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export const DATABASE_NAME: string = 'rssDatabase';
export const DATABASE_VERSION: number = 40;
/** Room identityHash（40.json），写入 room_master_table 以保持同形 */
export const DATABASE_IDENTITY_HASH: string = 'e89ba6774f07eb4d7672ccbea86d880c';

export const TABLE_FEEDS: string = 'feeds';
export const TABLE_FEED_ITEMS: string = 'feed_items';
export const TABLE_BLOCKLIST: string = 'blocklist';
export const TABLE_SYNC_REMOTE: string = 'sync_remote';
export const TABLE_READ_STATUS_SYNCED: string = 'read_status_synced';
export const TABLE_REMOTE_READ_MARK: string = 'remote_read_mark';
export const TABLE_REMOTE_FEED: string = 'remote_feed';
export const TABLE_SYNC_DEVICE: string = 'sync_device';
export const VIEW_NAV_DRAWER: string = 'feeds_with_items_for_nav_drawer';

export type SqlArg = relationalStore.ValueType;

/** 40.json createSql（${TABLE_NAME}/${VIEW_NAME} 已代入），顺序：表 → 索引 → 视图 → Room setupQueries */
const SCHEMA_V40: string[] = [
  'CREATE TABLE IF NOT EXISTS `feeds` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `title` TEXT NOT NULL, `custom_title` TEXT NOT NULL, `url` TEXT NOT NULL, `tag` TEXT NOT NULL, `notify` INTEGER NOT NULL, `image_url` TEXT, `last_sync` INTEGER NOT NULL, `response_hash` INTEGER NOT NULL, `fulltext_by_default` INTEGER NOT NULL, `open_articles_with` TEXT NOT NULL, `alternate_id` INTEGER NOT NULL, `currently_syncing` INTEGER NOT NULL, `when_modified` INTEGER NOT NULL, `site_fetched` INTEGER NOT NULL, `skip_duplicates` INTEGER NOT NULL, `retry_after` INTEGER NOT NULL, `summarize_on_open` INTEGER NOT NULL, `fetch_og_images` INTEGER NOT NULL, `block_rules` TEXT NOT NULL, `allow_rules` TEXT NOT NULL)',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_feeds_url` ON `feeds` (`url`)',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_feeds_id_url_title` ON `feeds` (`id`, `url`, `title`)',
  'CREATE TABLE IF NOT EXISTS `feed_items` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `guid` TEXT NOT NULL, `title` TEXT NOT NULL, `plain_title` TEXT NOT NULL, `plain_snippet` TEXT NOT NULL, `image_url` TEXT, `image_from_body` INTEGER NOT NULL, `enclosure_link` TEXT, `enclosure_type` TEXT, `author` TEXT, `pub_date` TEXT, `link` TEXT, `unread` INTEGER NOT NULL, `notified` INTEGER NOT NULL, `feed_id` INTEGER, `first_synced_time` INTEGER NOT NULL, `primary_sort_time` INTEGER NOT NULL, `pinned` INTEGER NOT NULL, `bookmarked` INTEGER NOT NULL, `fulltext_downloaded` INTEGER NOT NULL, `read_time` INTEGER, `word_count` INTEGER NOT NULL, `word_count_full` INTEGER NOT NULL, `block_time` INTEGER, FOREIGN KEY(`feed_id`) REFERENCES `feeds`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_feed_items_guid_feed_id` ON `feed_items` (`guid`, `feed_id`)',
  'CREATE INDEX IF NOT EXISTS `index_feed_items_feed_id` ON `feed_items` (`feed_id`)',
  'CREATE INDEX IF NOT EXISTS `index_feed_items_block_time` ON `feed_items` (`block_time`)',
  'CREATE UNIQUE INDEX IF NOT EXISTS `idx_feed_items_cursor` ON `feed_items` (`primary_sort_time`, `pub_date`, `id`)',
  'CREATE TABLE IF NOT EXISTS `blocklist` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `glob_pattern` TEXT NOT NULL)',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_blocklist_glob_pattern` ON `blocklist` (`glob_pattern`)',
  'CREATE TABLE IF NOT EXISTS `sync_remote` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `url` TEXT NOT NULL, `sync_chain_id` TEXT NOT NULL, `latest_message_timestamp` INTEGER NOT NULL, `device_id` INTEGER NOT NULL, `device_name` TEXT NOT NULL, `secret_key` TEXT NOT NULL, `last_feeds_remote_hash` INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS `read_status_synced` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `sync_remote` INTEGER NOT NULL, `feed_item` INTEGER NOT NULL, FOREIGN KEY(`feed_item`) REFERENCES `feed_items`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE , FOREIGN KEY(`sync_remote`) REFERENCES `sync_remote`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_read_status_synced_feed_item_sync_remote` ON `read_status_synced` (`feed_item`, `sync_remote`)',
  'CREATE INDEX IF NOT EXISTS `index_read_status_synced_feed_item` ON `read_status_synced` (`feed_item`)',
  'CREATE INDEX IF NOT EXISTS `index_read_status_synced_sync_remote` ON `read_status_synced` (`sync_remote`)',
  'CREATE TABLE IF NOT EXISTS `remote_read_mark` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `sync_remote` INTEGER NOT NULL, `feed_url` TEXT NOT NULL, `guid` TEXT NOT NULL, `timestamp` INTEGER NOT NULL, FOREIGN KEY(`sync_remote`) REFERENCES `sync_remote`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_remote_read_mark_sync_remote_feed_url_guid` ON `remote_read_mark` (`sync_remote`, `feed_url`, `guid`)',
  'CREATE INDEX IF NOT EXISTS `index_remote_read_mark_feed_url_guid` ON `remote_read_mark` (`feed_url`, `guid`)',
  'CREATE INDEX IF NOT EXISTS `index_remote_read_mark_sync_remote` ON `remote_read_mark` (`sync_remote`)',
  'CREATE INDEX IF NOT EXISTS `index_remote_read_mark_timestamp` ON `remote_read_mark` (`timestamp`)',
  'CREATE TABLE IF NOT EXISTS `remote_feed` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `sync_remote` INTEGER NOT NULL, `url` TEXT NOT NULL, FOREIGN KEY(`sync_remote`) REFERENCES `sync_remote`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_remote_feed_sync_remote_url` ON `remote_feed` (`sync_remote`, `url`)',
  'CREATE INDEX IF NOT EXISTS `index_remote_feed_url` ON `remote_feed` (`url`)',
  'CREATE INDEX IF NOT EXISTS `index_remote_feed_sync_remote` ON `remote_feed` (`sync_remote`)',
  'CREATE TABLE IF NOT EXISTS `sync_device` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `sync_remote` INTEGER NOT NULL, `device_id` INTEGER NOT NULL, `device_name` TEXT NOT NULL, FOREIGN KEY(`sync_remote`) REFERENCES `sync_remote`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )',
  'CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_device_sync_remote_device_id` ON `sync_device` (`sync_remote`, `device_id`)',
  'CREATE INDEX IF NOT EXISTS `index_sync_device_sync_remote` ON `sync_device` (`sync_remote`)',
  'CREATE VIEW `feeds_with_items_for_nav_drawer` AS select feeds.id as feed_id, item_id, case when custom_title is \'\' then title else custom_title end as display_title, tag, image_url, unread, bookmarked\n    from feeds\n    left join (\n        select id as item_id, feed_id, read_time is null as unread, bookmarked\n        from feed_items\n        where block_time is null\n    )\n    ON feeds.id = feed_id',
  'CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)',
  'INSERT OR REPLACE INTO room_master_table (id,identity_hash) VALUES(42, \'' + DATABASE_IDENTITY_HASH + '\')',
];

/** `?, ?, ?`（n 个占位符；n=0 → 空串，SQLite 接受 `IN ()`） */
export function placeholders(n: number): string {
  const parts: string[] = [];
  for (let i = 0; i < n; i++) {
    parts.push('?');
  }
  return parts.join(', ');
}

export function numArgs(values: number[]): SqlArg[] {
  return values.map((v: number): SqlArg => v);
}

export function strArgs(values: string[]): SqlArg[] {
  return values.map((v: string): SqlArg => v);
}

export function boolArg(v: boolean): number {
  return v ? 1 : 0;
}

/**
 * 一条数据库连接视图：普通（RdbStore）或事务（Transaction）。
 * 记录本连接上写过的表，写锁/事务结束后统一 DbNotifier.notify。
 */
export class DbConn {
  private readonly rdb: relationalStore.RdbStore | null;
  private readonly txn: relationalStore.Transaction | null;
  readonly changed: Set<string> = new Set<string>();

  constructor(rdb: relationalStore.RdbStore | null, txn: relationalStore.Transaction | null) {
    this.rdb = rdb;
    this.txn = txn;
  }

  get inTransaction(): boolean {
    return this.txn !== null;
  }

  async query(sql: string, args: SqlArg[] = []): Promise<relationalStore.ResultSet> {
    if (this.txn !== null) {
      return await this.txn.querySql(sql, args);
    }
    return await (this.rdb as relationalStore.RdbStore).querySql(sql, args);
  }

  /** 执行写语句；返回 execute 的数值结果（UPDATE/DELETE 为影响行数，INSERT 为 rowid），非数值 → 0 */
  async exec(sql: string, args: SqlArg[] = []): Promise<number> {
    let v: SqlArg;
    if (this.txn !== null) {
      v = await this.txn.execute(sql, args);
    } else {
      v = await (this.rdb as relationalStore.RdbStore).execute(sql, args);
    }
    return typeof v === 'number' ? v : 0;
  }

  /** 插入一行；返回 rowid，IGNORE 冲突被忽略时为 -1（同 Room） */
  async insert(table: string, values: relationalStore.ValuesBucket,
    conflict: relationalStore.ConflictResolution): Promise<number> {
    if (this.txn !== null) {
      return await this.txn.insert(table, values, conflict);
    }
    return await (this.rdb as relationalStore.RdbStore).insert(table, values, conflict);
  }

  markChanged(tables: string[]): void {
    for (const t of tables) {
      this.changed.add(t);
    }
  }
}

export type DbChangeCallback = () => void;

/** 视图 → 底层表（Room InvalidationTracker 对视图的解析） */
const VIEW_DEPENDENCIES: Map<string, string[]> = new Map<string, string[]>([
  [VIEW_NAV_DRAWER, [TABLE_FEEDS, TABLE_FEED_ITEMS]],
]);

/**
 * 表级变更通知。notify 合并到下一宏任务统一派发（批量写只触发一次）。
 * on(table, cb) 返回反订阅函数；订阅视图名时任一依赖表变更都会回调。
 */
export class DbNotifier {
  private static listeners: Map<string, Set<DbChangeCallback>> = new Map<string, Set<DbChangeCallback>>();
  private static pending: Set<string> = new Set<string>();
  private static scheduled: boolean = false;

  static notify(table: string): void {
    DbNotifier.notifyAll([table]);
  }

  static notifyAll(tables: string[]): void {
    if (tables.length === 0) {
      return;
    }
    for (const t of tables) {
      DbNotifier.pending.add(t);
    }
    if (DbNotifier.scheduled) {
      return;
    }
    DbNotifier.scheduled = true;
    setTimeout(() => {
      DbNotifier.flush();
    }, 0);
  }

  static on(table: string, cb: DbChangeCallback): () => void {
    const tables: string[] = VIEW_DEPENDENCIES.get(table) ?? [table];
    for (const t of tables) {
      let set: Set<DbChangeCallback> | undefined = DbNotifier.listeners.get(t);
      if (set === undefined) {
        set = new Set<DbChangeCallback>();
        DbNotifier.listeners.set(t, set);
      }
      set.add(cb);
    }
    return () => {
      for (const t of tables) {
        const s: Set<DbChangeCallback> | undefined = DbNotifier.listeners.get(t);
        if (s !== undefined) {
          s.delete(cb);
        }
      }
    };
  }

  /** 订阅多表，任一变更回调一次 */
  static onAny(tables: string[], cb: DbChangeCallback): () => void {
    const offs: (() => void)[] = [];
    for (const t of tables) {
      offs.push(DbNotifier.on(t, cb));
    }
    return () => {
      for (const off of offs) {
        off();
      }
    };
  }

  private static flush(): void {
    DbNotifier.scheduled = false;
    const tables: string[] = Array.from(DbNotifier.pending);
    DbNotifier.pending.clear();
    const fired: Set<DbChangeCallback> = new Set<DbChangeCallback>();
    for (const t of tables) {
      const set: Set<DbChangeCallback> | undefined = DbNotifier.listeners.get(t);
      if (set === undefined) {
        continue;
      }
      for (const cb of Array.from(set)) {
        if (fired.has(cb)) {
          continue;
        }
        fired.add(cb);
        try {
          cb();
        } catch (e) {
          console.error(`DbNotifier: listener failed: ${(e as Error)?.message}`);
        }
      }
    }
  }
}

/**
 * 可观察查询（源 Room Flow 等价）：立即查一次，之后 tables 任一变更重查并回调最新结果。
 * 返回反订阅函数。过期结果（被更新一轮查询超越）被丢弃。
 */
export function observeQuery<T>(tables: string[], query: () => Promise<T>, cb: (value: T) => void): () => void {
  let seq: number = 0;
  let active: boolean = true;
  const run = (): void => {
    seq++;
    const mySeq: number = seq;
    query().then((value: T) => {
      if (active && mySeq === seq) {
        cb(value);
      }
    }).catch((e: Error) => {
      console.error(`observeQuery: query failed: ${e?.message}`);
    });
  };
  const off: () => void = DbNotifier.onAny(tables, run);
  run();
  return () => {
    active = false;
    off();
  };
}

export class AppDatabase {
  private static rdb: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<void> | null = null;
  private static writeChain: Promise<void> = Promise.resolve();

  /** 单例初始化（幂等）；首次建 v40 schema */
  static init(ctx: common.Context): Promise<void> {
    if (AppDatabase.initPromise === null) {
      AppDatabase.initPromise = AppDatabase.doInit(ctx);
      AppDatabase.initPromise.catch((e: Error) => {
        console.error(`AppDatabase: init failed: ${e?.message}`);
        AppDatabase.initPromise = null;
      });
    }
    return AppDatabase.initPromise;
  }

  /** 等待 init 完成（未调用 init 时立即拒绝） */
  static ready(): Promise<void> {
    if (AppDatabase.initPromise === null) {
      return Promise.reject(new Error('AppDatabase not initialized'));
    }
    return AppDatabase.initPromise;
  }

  static isReady(): boolean {
    return AppDatabase.rdb !== null;
  }

  static store(): relationalStore.RdbStore {
    if (AppDatabase.rdb === null) {
      throw new Error('AppDatabase not initialized');
    }
    return AppDatabase.rdb;
  }

  /** 普通（非事务）连接视图；读操作直接用 */
  static conn(): DbConn {
    return new DbConn(AppDatabase.store(), null);
  }

  /** 串行写：fn 内写过的表在完成后通知 */
  static async write<T>(fn: (c: DbConn) => Promise<T>): Promise<T> {
    return await AppDatabase.withLock<T>(async (): Promise<T> => {
      const c: DbConn = AppDatabase.conn();
      try {
        return await fn(c);
      } finally {
        DbNotifier.notifyAll(Array.from(c.changed));
      }
    });
  }

  /** DAO 写入口：tx 非空则在调用方事务内执行（变更随事务提交后通知），否则走串行写 */
  static async run<T>(tx: DbConn | null, fn: (c: DbConn) => Promise<T>): Promise<T> {
    if (tx !== null) {
      return await fn(tx);
    }
    return await AppDatabase.write<T>(fn);
  }

  /** DAO 读入口 */
  static reader(tx: DbConn | null): DbConn {
    return tx !== null ? tx : AppDatabase.conn();
  }

  /** 源 @Transaction / withTransaction：fn 内经 tx 执行的 DAO 调用原子提交；异常回滚并重抛 */
  static async transaction<T>(fn: (tx: DbConn) => Promise<T>): Promise<T> {
    return await AppDatabase.withLock<T>(async (): Promise<T> => {
      const options: relationalStore.TransactionOptions = {
        transactionType: relationalStore.TransactionType.IMMEDIATE,
      };
      const txn: relationalStore.Transaction = await AppDatabase.store().createTransaction(options);
      const c: DbConn = new DbConn(null, txn);
      let result: T;
      try {
        result = await fn(c);
      } catch (e) {
        try {
          await txn.rollback();
        } catch (re) {
          console.error(`AppDatabase: rollback failed: ${(re as Error)?.message}`);
        }
        throw e as Error;
      }
      await txn.commit();
      DbNotifier.notifyAll(Array.from(c.changed));
      return result;
    });
  }

  private static async withLock<T>(fn: () => Promise<T>): Promise<T> {
    const prev: Promise<void> = AppDatabase.writeChain;
    let release: () => void = () => {
    };
    AppDatabase.writeChain = new Promise<void>((resolve) => {
      release = () => {
        resolve();
      };
    });
    try {
      await prev;
      return await fn();
    } finally {
      release();
    }
  }

  private static async doInit(ctx: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    const rdb: relationalStore.RdbStore = await relationalStore.getRdbStore(ctx, config);
    try {
      await rdb.execute('PRAGMA foreign_keys = ON');
    } catch (e) {
      console.error(`AppDatabase: enabling foreign_keys failed: ${(e as Error)?.message}`);
    }
    const current: number = rdb.version;
    if (current === 0) {
      await AppDatabase.createSchema(rdb);
      rdb.version = DATABASE_VERSION;
    } else if (current < DATABASE_VERSION) {
      // 鸿蒙为全新安装，不存在 Android v5..v39 旧库；保留升级框架供后续版本
      AppDatabase.onUpgrade(rdb, current, DATABASE_VERSION);
      rdb.version = DATABASE_VERSION;
    } else if (current > DATABASE_VERSION) {
      console.warn(`AppDatabase: on-disk version ${current} newer than ${DATABASE_VERSION}`);
    }
    AppDatabase.rdb = rdb;
  }

  private static async createSchema(rdb: relationalStore.RdbStore): Promise<void> {
    const txn: relationalStore.Transaction = await rdb.createTransaction();
    try {
      for (const sql of SCHEMA_V40) {
        await txn.execute(sql);
      }
      await txn.commit();
    } catch (e) {
      try {
        await txn.rollback();
      } catch (re) {
        console.error(`AppDatabase: schema rollback failed: ${(re as Error)?.message}`);
      }
      throw e as Error;
    }
  }

  private static onUpgrade(rdb: relationalStore.RdbStore, from: number, to: number): void {
    console.warn(`AppDatabase: no migration path ${from} -> ${to} (fresh-install port); keeping data as-is`);
  }
}
