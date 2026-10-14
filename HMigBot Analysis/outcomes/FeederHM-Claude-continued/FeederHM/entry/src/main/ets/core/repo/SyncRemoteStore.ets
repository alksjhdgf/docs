/**
 * SyncRemoteStore（源 archmodel/SyncRemoteStore.kt）：跨设备同步链的本地存储（sync_remote / read_status_synced /
 * remote_read_mark / remote_feed / sync_device）。网络部分（SyncRestClient）属 features/sync 切片。
 */
import { FeedItemForReadMark } from '../model/FeedItem';
import {
  ReadStatusSynced, ReadStatusSyncedDao, RemoteFeed, RemoteFeedDao, RemoteReadMark, RemoteReadMarkDao,
  RemoteReadMarkReadyToBeApplied, SYNC_REMOTE_ID, SyncDevice, SyncDeviceDao, SyncRemote, SyncRemoteDao,
  generateDeviceName, generateSecretKey
} from '../db/SyncDaos';

const SEVEN_DAYS_MS: number = 7 * 24 * 60 * 60 * 1000;

export class SyncRemoteStore {
  private static inst: SyncRemoteStore | null = null;

  static instance(): SyncRemoteStore {
    if (SyncRemoteStore.inst === null) {
      SyncRemoteStore.inst = new SyncRemoteStore();
    }
    return SyncRemoteStore.inst as SyncRemoteStore;
  }

  /** RP-A42：无记录时创建 id=1 默认远端（设备名=制造商/型号，新随机密钥）并持久化 */
  async getSyncRemote(): Promise<SyncRemote> {
    const existing: SyncRemote | null = await SyncRemoteDao.getSyncRemote();
    if (existing !== null) {
      return existing;
    }
    return await this.createDefaultSyncRemote();
  }

  observeSyncRemote(cb: (remote: SyncRemote | null) => void): () => void {
    return SyncRemoteDao.observeSyncRemote(cb);
  }

  async updateSyncRemote(syncRemote: SyncRemote): Promise<void> {
    await SyncRemoteDao.update(syncRemote);
  }

  async updateSyncRemoteMessageTimestamp(timestamp: number): Promise<void> {
    await SyncRemoteDao.updateLastMessageTimestamp(timestamp);
  }

  async deleteAllReadStatusSyncs(): Promise<void> {
    await ReadStatusSyncedDao.deleteAll();
  }

  async deleteAppliedRemoteReadMarks(ids: number[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    await RemoteReadMarkDao.deleteByIds(ids);
  }

  async getFeedItemsWithoutSyncedReadMark(): Promise<FeedItemForReadMark[]> {
    return await ReadStatusSyncedDao.getFeedItemsWithoutSyncedReadMark();
  }

  /** Ignores duplicates */
  async setSynced(feedItemId: number): Promise<void> {
    const v: ReadStatusSynced = new ReadStatusSynced();
    v.feed_item = feedItemId;
    v.sync_remote = SYNC_REMOTE_ID;
    await ReadStatusSyncedDao.insert(v);
  }

  /** RP-A25：删除该条目的已同步标记 */
  async setNotSynced(feedItemId: number): Promise<void> {
    await ReadStatusSyncedDao.deleteReadStatusSyncForItem(feedItemId);
  }

  /** Ignores duplicates */
  async addRemoteReadMark(feedUrl: string, articleGuid: string): Promise<void> {
    const m: RemoteReadMark = new RemoteReadMark();
    m.sync_remote = SYNC_REMOTE_ID;
    m.feedUrl = feedUrl;
    m.guid = articleGuid;
    m.timestamp = Date.now();
    await RemoteReadMarkDao.insert(m);
  }

  /** RP-A45：删除 7 天前的远端已读标记 */
  async deleteStaleRemoteReadMarks(now: number): Promise<void> {
    await RemoteReadMarkDao.deleteStaleRemoteReadMarks(now - SEVEN_DAYS_MS);
  }

  async deleteRemoteReadMarksForReadItems(): Promise<void> {
    await RemoteReadMarkDao.deleteRemoteReadMarksForReadItems();
  }

  async getRemoteReadMarksReadyToBeApplied(): Promise<RemoteReadMarkReadyToBeApplied[]> {
    return await RemoteReadMarkDao.getRemoteReadMarksReadyToBeApplied();
  }

  async getGuidsWhichAreSyncedAsReadInFeed(feedUrl: string): Promise<string[]> {
    return await RemoteReadMarkDao.getGuidsWhichAreSyncedAsReadInFeed(feedUrl);
  }

  async replaceWithDefaultSyncRemote(): Promise<void> {
    await SyncRemoteDao.replaceWithDefaultSyncRemote();
  }

  private async createDefaultSyncRemote(): Promise<SyncRemote> {
    const remote: SyncRemote = SyncRemote.create(SYNC_REMOTE_ID, generateDeviceName(), generateSecretKey());
    await SyncRemoteDao.insert(remote);
    return remote;
  }

  observeDevices(cb: (devices: SyncDevice[]) => void): () => void {
    return SyncDeviceDao.observeDevices(cb);
  }

  async replaceDevices(devices: SyncDevice[]): Promise<void> {
    await SyncDeviceDao.replaceDevices(devices);
  }

  async getRemotelySeenFeeds(): Promise<string[]> {
    return await RemoteFeedDao.getRemotelySeenFeeds();
  }

  async replaceRemoteFeedsWith(remoteFeeds: RemoteFeed[]): Promise<void> {
    await RemoteFeedDao.replaceRemoteFeedsWith(remoteFeeds);
  }
}
