/**
 * 同步元数据实体与 DAO（源 db/room/SyncRemote*.kt、ReadStatusSynced*.kt、RemoteReadMark*.kt、RemoteFeed*.kt、
 * SyncDevice*.kt）。DB-A06、DB-A41..A44。
 *
 * - sync_remote 只用 id=1 一行；删除该行显式级联 read_status_synced/remote_read_mark/remote_feed/sync_device。
 * - 源 SyncRemoteDao.insert 为 REPLACE（主键冲突会删旧行并级联删全部子表），此处改为
 *   `INSERT … ON CONFLICT(id) DO UPDATE`，避免级联误删。
 * - 默认 AES 密钥：源 AesCbcWithIntegrity.generateKey().toString() = base64(16B AES):base64(32B HMAC)（NO_WRAP），
 *   默认实现以 cryptoFramework 随机数生成同格式；features/sync/SyncCrypto 可经 setSecretKeyGenerator 覆盖。
 */
import { relationalStore } from '@kit.ArkData';
import { base64Encode } from '../util/TextCodec';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ID_UNSET } from '../model/Enums';
import { Converters, DEFAULT_URL, EPOCH_MS } from '../model/Feed';
import { FeedItemForReadMark } from '../model/FeedItem';
import {
  AppDatabase, DbConn, SqlArg, TABLE_READ_STATUS_SYNCED, TABLE_REMOTE_FEED, TABLE_REMOTE_READ_MARK, TABLE_SYNC_DEVICE,
  TABLE_SYNC_REMOTE, numArgs, observeQuery, placeholders
} from './AppDatabase';
import {
  RowMapper, colInstant, colNum, colStr, colUrl, readAll, readFeedItemForReadMark, readFirst, readStringColumn
} from './DbRows';

const DEFAULT_SERVER_HOST: string = 'feeder-sync.nononsenseapps.com';
const DEFAULT_SERVER_PORT: number = 443;
export const DEFAULT_SERVER_ADDRESS: string = `https://${DEFAULT_SERVER_HOST}:${DEFAULT_SERVER_PORT}`;
export const DEPRECATED_SYNC_HOSTS: string[] = [
  'feederapp.nononsenseapps.com',
  'feeder-sync.nononsenseapps.workers.dev',
];

/** 当前同步配置所用行 id（源各 DAO `WHERE id IS 1`） */
export const SYNC_REMOTE_ID: number = 1;

const SYNC_CHILD_TABLES: string[] =
  [TABLE_SYNC_REMOTE, TABLE_READ_STATUS_SYNCED, TABLE_REMOTE_READ_MARK, TABLE_REMOTE_FEED, TABLE_SYNC_DEVICE];

// ============================================================ secret key / device name

export type SecretKeyGenerator = () => string;

function defaultSecretKey(): string {
  const rnd: cryptoFramework.Random = cryptoFramework.createRandom();
  const aes: string = base64Encode(rnd.generateRandomSync(16).data);
  const hmac: string = base64Encode(rnd.generateRandomSync(32).data);
  return `${aes}:${hmac}`;
}

let secretKeyGenerator: SecretKeyGenerator = defaultSecretKey;

/** 由 features/sync/SyncCrypto 注册（AesCbcWithIntegrity.generateKey().toString() 等价）；传 null 恢复默认 */
export function setSecretKeyGenerator(gen: SecretKeyGenerator | null): void {
  secretKeyGenerator = gen !== null ? gen : defaultSecretKey;
}

export function generateSecretKey(): string {
  return secretKeyGenerator();
}

function isBlank(s: string | null | undefined): boolean {
  return s === null || s === undefined || s.trim().length === 0;
}

/** 源 generateDeviceName()：MANUFACTURER+MODEL（MODEL 已以厂商开头只用 MODEL），首字母大写，空则 0..99999 随机数 */
export function generateDeviceName(): string {
  const manufacturer: string = isBlank(deviceInfo.manufacture) ? '' : deviceInfo.manufacture;
  const model: string = isBlank(deviceInfo.productModel) ? '' : deviceInfo.productModel;
  let name: string = model.toLowerCase().startsWith(manufacturer.toLowerCase()) ? model : `${manufacturer} ${model}`;
  if (name.length > 0) {
    const first: string = name.charAt(0);
    if (first !== first.toUpperCase() && first === first.toLowerCase()) {
      name = first.toUpperCase() + name.substring(1);
    }
  }
  if (isBlank(name)) {
    return `${Math.floor(Math.random() * 100000)}`;
  }
  return name;
}

/** 源 replaceWithDefaultSyncRemote 的 `Build.PRODUCT.ifBlank { Build.MODEL.ifBlank { Build.BRAND } }` */
function defaultProductName(): string {
  if (!isBlank(deviceInfo.productSeries)) {
    return deviceInfo.productSeries;
  }
  if (!isBlank(deviceInfo.productModel)) {
    return deviceInfo.productModel;
  }
  return isBlank(deviceInfo.brand) ? '' : deviceInfo.brand;
}

// ============================================================ entities

export class SyncRemote {
  id: number = ID_UNSET;
  url: string = DEFAULT_SERVER_ADDRESS;
  syncChainId: string = '';
  /** epoch ms */
  latestMessageTimestamp: number = EPOCH_MS;
  deviceId: number = 0;
  deviceName: string = '';
  secretKey: string = '';
  lastFeedsRemoteHash: number = 0;

  /** 源默认 deviceName = generateDeviceName() */
  static create(id: number, deviceName: string = generateDeviceName(), secretKey: string = ''): SyncRemote {
    const r: SyncRemote = new SyncRemote();
    r.id = id;
    r.deviceName = deviceName;
    r.secretKey = secretKey;
    return r;
  }

  /** DB-A42 */
  hasSyncChain(): boolean {
    return this.syncChainId.length === 64;
  }

  notHasSyncChain(): boolean {
    return !this.hasSyncChain();
  }

  copy(): SyncRemote {
    const r: SyncRemote = new SyncRemote();
    r.id = this.id;
    r.url = this.url;
    r.syncChainId = this.syncChainId;
    r.latestMessageTimestamp = this.latestMessageTimestamp;
    r.deviceId = this.deviceId;
    r.deviceName = this.deviceName;
    r.secretKey = this.secretKey;
    r.lastFeedsRemoteHash = this.lastFeedsRemoteHash;
    return r;
  }
}

export class ReadStatusSynced {
  id: number = ID_UNSET;
  sync_remote: number = ID_UNSET;
  feed_item: number = ID_UNSET;
}

export class RemoteReadMark {
  id: number = ID_UNSET;
  sync_remote: number = ID_UNSET;
  feedUrl: string = DEFAULT_URL;
  guid: string = '';
  /** epoch ms */
  timestamp: number = EPOCH_MS;
}

export class RemoteReadMarkReadyToBeApplied {
  id: number = ID_UNSET;
  feedItemId: number = ID_UNSET;
}

export class RemoteFeed {
  id: number = ID_UNSET;
  syncRemote: number = ID_UNSET;
  url: string = DEFAULT_URL;
}

export class SyncDevice {
  id: number = ID_UNSET;
  syncRemote: number = ID_UNSET;
  deviceId: number = ID_UNSET;
  deviceName: string = '';
}

const readSyncRemote: RowMapper<SyncRemote> = (rs: relationalStore.ResultSet): SyncRemote => {
  const r: SyncRemote = new SyncRemote();
  r.id = colNum(rs, 'id', ID_UNSET);
  r.url = colUrl(rs, 'url');
  r.syncChainId = colStr(rs, 'sync_chain_id');
  r.latestMessageTimestamp = colInstant(rs, 'latest_message_timestamp');
  r.deviceId = colNum(rs, 'device_id');
  r.deviceName = colStr(rs, 'device_name');
  r.secretKey = colStr(rs, 'secret_key');
  r.lastFeedsRemoteHash = colNum(rs, 'last_feeds_remote_hash');
  return r;
};

const readSyncDevice: RowMapper<SyncDevice> = (rs: relationalStore.ResultSet): SyncDevice => {
  const d: SyncDevice = new SyncDevice();
  d.id = colNum(rs, 'id', ID_UNSET);
  d.syncRemote = colNum(rs, 'sync_remote', ID_UNSET);
  d.deviceId = colNum(rs, 'device_id', ID_UNSET);
  d.deviceName = colStr(rs, 'device_name');
  return d;
};

const readRemoteReadMarkReady: RowMapper<RemoteReadMarkReadyToBeApplied> =
  (rs: relationalStore.ResultSet): RemoteReadMarkReadyToBeApplied => {
    const r: RemoteReadMarkReadyToBeApplied = new RemoteReadMarkReadyToBeApplied();
    r.id = colNum(rs, 'id', ID_UNSET);
    r.feedItemId = colNum(rs, 'feed_item_id', ID_UNSET);
    return r;
  };

async function execChanged(sql: string, args: SqlArg[], tables: string[], tx: DbConn | null): Promise<number> {
  return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
    const n: number = await c.exec(sql, args);
    c.markChanged(tables);
    return n;
  });
}

// ============================================================ SyncRemoteDao

const SYNC_REMOTE_COLS: string[] = ['url', 'sync_chain_id', 'latest_message_timestamp', 'device_id', 'device_name',
  'secret_key', 'last_feeds_remote_hash'];

function syncRemoteArgs(r: SyncRemote): SqlArg[] {
  return [r.url, r.syncChainId, r.latestMessageTimestamp, r.deviceId, r.deviceName, r.secretKey, r.lastFeedsRemoteHash];
}

/** 显式级联删除（DB-A06） */
async function deleteSyncRemoteWhere(c: DbConn, id: number): Promise<number> {
  await c.exec('DELETE FROM read_status_synced WHERE sync_remote IS ?', [id]);
  await c.exec('DELETE FROM remote_read_mark WHERE sync_remote IS ?', [id]);
  await c.exec('DELETE FROM remote_feed WHERE sync_remote IS ?', [id]);
  await c.exec('DELETE FROM sync_device WHERE sync_remote IS ?', [id]);
  const n: number = await c.exec('DELETE FROM sync_remote WHERE id IS ?', [id]);
  c.markChanged(SYNC_CHILD_TABLES);
  return n;
}

export class SyncRemoteDao {
  /** 源 insert(REPLACE) → ON CONFLICT(id) DO UPDATE；返回行 id */
  static async insert(syncRemote: SyncRemote, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      let n: number;
      if (syncRemote.id > ID_UNSET) {
        const args: SqlArg[] = [syncRemote.id];
        for (const a of syncRemoteArgs(syncRemote)) {
          args.push(a);
        }
        const updates: string = SYNC_REMOTE_COLS.map((col: string): string => `${col} = excluded.${col}`).join(', ');
        await c.exec(`INSERT INTO sync_remote (id, ${SYNC_REMOTE_COLS.join(', ')}) VALUES (?, ${placeholders(
          SYNC_REMOTE_COLS.length)}) ON CONFLICT(id) DO UPDATE SET ${updates}`, args);
        n = syncRemote.id;
      } else {
        n = await c.exec(`INSERT INTO sync_remote (${SYNC_REMOTE_COLS.join(', ')}) VALUES (${placeholders(
          SYNC_REMOTE_COLS.length)})`, syncRemoteArgs(syncRemote));
      }
      c.markChanged([TABLE_SYNC_REMOTE]);
      return n;
    });
  }

  static async update(syncRemote: SyncRemote, tx: DbConn | null = null): Promise<number> {
    const args: SqlArg[] = syncRemoteArgs(syncRemote);
    args.push(syncRemote.id);
    return await execChanged(`UPDATE sync_remote SET ${SYNC_REMOTE_COLS.map((col: string): string => `${col} = ?`)
      .join(', ')} WHERE id = ?`, args, [TABLE_SYNC_REMOTE], tx);
  }

  static async delete(syncRemote: SyncRemote, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, (c: DbConn): Promise<number> => deleteSyncRemoteWhere(c, syncRemote.id));
  }

  static async getSyncRemote(tx: DbConn | null = null): Promise<SyncRemote | null> {
    return readFirst(await AppDatabase.reader(tx).query('SELECT * FROM sync_remote WHERE id IS 1'), readSyncRemote);
  }

  static observeSyncRemote(cb: (remote: SyncRemote | null) => void): () => void {
    return observeQuery<SyncRemote | null>([TABLE_SYNC_REMOTE], () => SyncRemoteDao.getSyncRemote(), cb);
  }

  /** DB-A42：只增不减 */
  static async updateLastMessageTimestamp(timestamp: number, tx: DbConn | null = null): Promise<number> {
    return await execChanged(`
            UPDATE sync_remote
            SET latest_message_timestamp = ?
            WHERE id IS 1 AND latest_message_timestamp < ?
        `, [timestamp, timestamp], [TABLE_SYNC_REMOTE], tx);
  }

  static async deleteSyncRemote(tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, (c: DbConn): Promise<number> => deleteSyncRemoteWhere(c, SYNC_REMOTE_ID));
  }

  /** DB-A41（@Transaction）：删 id=1（级联清空设备/远端记录），插入默认行（新密钥、默认服务器） */
  static async replaceWithDefaultSyncRemote(tx: DbConn | null = null): Promise<void> {
    const body = async (c: DbConn): Promise<void> => {
      await SyncRemoteDao.deleteSyncRemote(c);
      await SyncRemoteDao.insert(SyncRemote.create(SYNC_REMOTE_ID, defaultProductName(), generateSecretKey()), c);
    };
    if (tx !== null) {
      await body(tx);
    } else {
      await AppDatabase.transaction<void>(body);
    }
  }
}

// ============================================================ ReadStatusSyncedDao

export class ReadStatusSyncedDao {
  /** IGNORE：重复被忽略返回 -1 */
  static async insert(value: ReadStatusSynced, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const v: relationalStore.ValuesBucket = { 'sync_remote': value.sync_remote, 'feed_item': value.feed_item };
      if (value.id > ID_UNSET) {
        v['id'] = value.id;
      }
      const id: number = await c.insert(TABLE_READ_STATUS_SYNCED, v, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      c.markChanged([TABLE_READ_STATUS_SYNCED]);
      return id;
    });
  }

  static async update(value: ReadStatusSynced, tx: DbConn | null = null): Promise<number> {
    return await execChanged('UPDATE read_status_synced SET sync_remote = ?, feed_item = ? WHERE id = ?',
      [value.sync_remote, value.feed_item, value.id], [TABLE_READ_STATUS_SYNCED], tx);
  }

  static async delete(value: ReadStatusSynced, tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM read_status_synced WHERE id = ?', [value.id], [TABLE_READ_STATUS_SYNCED], tx);
  }

  static async deleteAll(tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM read_status_synced', [], [TABLE_READ_STATUS_SYNCED], tx);
  }

  /** DB-A43：已读且尚无 read_status_synced 记录，id 降序 */
  static async getFeedItemsWithoutSyncedReadMark(tx: DbConn | null = null): Promise<FeedItemForReadMark[]> {
    return readAll(await AppDatabase.reader(tx).query(`
            SELECT
                fi.id AS id,
                f.id AS feed_id,
                fi.guid AS guid,
                f.url AS feed_url
            FROM feed_items fi
            JOIN feeds f ON f.id = fi.feed_id
            WHERE
                fi.read_time is not null and
                fi.id NOT IN (
                    SELECT feed_item
                    FROM read_status_synced
                )
            ORDER BY fi.id DESC
        `), readFeedItemForReadMark);
  }

  static async deleteReadStatusSyncForItem(feedItemId: number, tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM read_status_synced WHERE feed_item = ?', [feedItemId],
      [TABLE_READ_STATUS_SYNCED], tx);
  }
}

// ============================================================ RemoteReadMarkDao

export class RemoteReadMarkDao {
  /** IGNORE：重复被忽略返回 -1 */
  static async insert(readMark: RemoteReadMark, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const v: relationalStore.ValuesBucket = {
        'sync_remote': readMark.sync_remote,
        'feed_url': readMark.feedUrl,
        'guid': readMark.guid,
        'timestamp': readMark.timestamp,
      };
      if (readMark.id > ID_UNSET) {
        v['id'] = readMark.id;
      }
      const id: number = await c.insert(TABLE_REMOTE_READ_MARK, v, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      c.markChanged([TABLE_REMOTE_READ_MARK]);
      return id;
    });
  }

  static async delete(readMark: RemoteReadMark, tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM remote_read_mark WHERE id = ?', [readMark.id], [TABLE_REMOTE_READ_MARK], tx);
  }

  /** 调用方传 now - 7 天（源 SyncRemoteStore.deleteStaleRemoteReadMarks） */
  static async deleteStaleRemoteReadMarks(oldestTimestamp: number, tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM remote_read_mark WHERE timestamp < ?', [oldestTimestamp],
      [TABLE_REMOTE_READ_MARK], tx);
  }

  static async deleteByIds(ids: number[], tx: DbConn | null = null): Promise<number> {
    return await execChanged(`DELETE FROM remote_read_mark WHERE id in (${placeholders(ids.length)})`, numArgs(ids),
      [TABLE_REMOTE_READ_MARK], tx);
  }

  /** 本地已读者的远端标记删除（防止用户标未读后被旧远端标记重新标已读） */
  static async deleteRemoteReadMarksForReadItems(tx: DbConn | null = null): Promise<number> {
    return await execChanged(`
            DELETE FROM remote_read_mark
            WHERE id IN (
                SELECT rrm.id FROM remote_read_mark rrm
                INNER JOIN feed_items fi ON rrm.guid = fi.guid
                INNER JOIN feeds f ON f.id = fi.feed_id
                WHERE f.url IS rrm.feed_url AND fi.read_time IS NOT NULL
            )
        `, [], [TABLE_REMOTE_READ_MARK], tx);
  }

  /** 仅本地未读、同 feed_url+guid 的文章 */
  static async getRemoteReadMarksReadyToBeApplied(tx: DbConn | null = null): Promise<RemoteReadMarkReadyToBeApplied[]> {
    return readAll(await AppDatabase.reader(tx).query(`
            SELECT remote_read_mark.id as id, fi.id as feed_item_id
            FROM remote_read_mark
            INNER JOIN feed_items fi ON remote_read_mark.guid = fi.guid
            INNER JOIN feeds f on f.id = fi.feed_id
            WHERE f.url IS remote_read_mark.feed_url AND fi.read_time is null
        `), readRemoteReadMarkReady);
  }

  static async getGuidsWhichAreSyncedAsReadInFeed(feedUrl: string, tx: DbConn | null = null): Promise<string[]> {
    return readStringColumn(await AppDatabase.reader(tx).query(`
            SELECT remote_read_mark.guid
            FROM remote_read_mark
            WHERE remote_read_mark.feed_url = ?
        `, [feedUrl]));
  }
}

// ============================================================ RemoteFeedDao

export class RemoteFeedDao {
  static async insert(remoteFeed: RemoteFeed, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const v: relationalStore.ValuesBucket = { 'sync_remote': remoteFeed.syncRemote, 'url': remoteFeed.url };
      if (remoteFeed.id > ID_UNSET) {
        v['id'] = remoteFeed.id;
      }
      const id: number = await c.insert(TABLE_REMOTE_FEED, v, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      c.markChanged([TABLE_REMOTE_FEED]);
      return id;
    });
  }

  static async delete(remoteFeed: RemoteFeed, tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM remote_feed WHERE id = ?', [remoteFeed.id], [TABLE_REMOTE_FEED], tx);
  }

  static async getRemotelySeenFeeds(tx: DbConn | null = null): Promise<string[]> {
    const raw: string[] = readStringColumn(await AppDatabase.reader(tx).query(`
            SELECT url
            FROM remote_feed
            WHERE sync_remote IS 1
        `));
    return raw.map((u: string): string => {
      const v: string | null = Converters.urlFromString(u);
      return v === null ? DEFAULT_URL : v;
    });
  }

  static async deleteAllRemoteFeeds(tx: DbConn | null = null): Promise<void> {
    await execChanged('DELETE FROM remote_feed', [], [TABLE_REMOTE_FEED], tx);
  }

  /** DB-A44（@Transaction）：整表替换 */
  static async replaceRemoteFeedsWith(remoteFeeds: RemoteFeed[], tx: DbConn | null = null): Promise<void> {
    const body = async (c: DbConn): Promise<void> => {
      await RemoteFeedDao.deleteAllRemoteFeeds(c);
      for (const f of remoteFeeds) {
        await RemoteFeedDao.insert(f, c);
      }
    };
    if (tx !== null) {
      await body(tx);
    } else {
      await AppDatabase.transaction<void>(body);
    }
  }
}

// ============================================================ SyncDeviceDao

export class SyncDeviceDao {
  /** 源 REPLACE（sync_device 无子表，REPLACE 无级联风险，保留） */
  static async insert(device: SyncDevice, tx: DbConn | null = null): Promise<number> {
    return await AppDatabase.run<number>(tx, async (c: DbConn): Promise<number> => {
      const v: relationalStore.ValuesBucket = {
        'sync_remote': device.syncRemote,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
      };
      if (device.id > ID_UNSET) {
        v['id'] = device.id;
      }
      const id: number = await c.insert(TABLE_SYNC_DEVICE, v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      c.markChanged([TABLE_SYNC_DEVICE]);
      return id;
    });
  }

  static async delete(device: SyncDevice, tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM sync_device WHERE id = ?', [device.id], [TABLE_SYNC_DEVICE], tx);
  }

  static async getDevices(tx: DbConn | null = null): Promise<SyncDevice[]> {
    return readAll(await AppDatabase.reader(tx).query(`
            SELECT *
            FROM sync_device
            ORDER BY device_name
        `), readSyncDevice);
  }

  static observeDevices(cb: (devices: SyncDevice[]) => void): () => void {
    return observeQuery<SyncDevice[]>([TABLE_SYNC_DEVICE], () => SyncDeviceDao.getDevices(), cb);
  }

  static async deleteAll(tx: DbConn | null = null): Promise<number> {
    return await execChanged('DELETE FROM sync_device', [], [TABLE_SYNC_DEVICE], tx);
  }

  /** DB-A44（@Transaction）：整表替换 */
  static async replaceDevices(devices: SyncDevice[], tx: DbConn | null = null): Promise<void> {
    const body = async (c: DbConn): Promise<void> => {
      await SyncDeviceDao.deleteAll(c);
      for (const d of devices) {
        await SyncDeviceDao.insert(d, c);
      }
    };
    if (tx !== null) {
      await body(tx);
    } else {
      await AppDatabase.transaction<void>(body);
    }
  }
}
