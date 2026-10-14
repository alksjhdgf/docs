/**
 * RepoBackground — 源 Repository.kt 中屏蔽词与供后台作业（RSS 同步 / 全文 / 通知 / 同步链本地存储）使用的透传与逻辑
 * （自 Repository.ets 拆出以满足单文件 ≤600 行）。Repository 继承本类；对外统一经 Repository.instance() 调用。
 */
import { Feed, isBlankString } from '../model/Feed';
import { FeedItem, FeedItemForReadMark, FeedItemIdWithLink } from '../model/FeedItem';
import { BlocklistDao } from '../db/BlocklistDao';
import { FeedItemTextBlock, FeedItemWithText } from '../db/FeedItemDao';
import { RemoteFeed, RemoteReadMarkReadyToBeApplied, SyncDevice, SyncRemote } from '../db/SyncDaos';
import { fireSyncScheduleHook } from '../settings/SettingsHooks';
import { RepoSettings } from './RepoSettings';
import { FeedStore } from './FeedStore';
import { FeedItemStore } from './FeedItemStore';
import { SyncRemoteStore } from './SyncRemoteStore';

export class RepoBackground extends RepoSettings {
  readonly feedStore: FeedStore = FeedStore.instance();
  readonly feedItemStore: FeedItemStore = FeedItemStore.instance();
  readonly syncRemoteStore: SyncRemoteStore = SyncRemoteStore.instance();

  // ================================================================ 屏蔽词（SS-A21..A23 / RP-A35）

  /** SS-A22：按字母序返回原始词（去掉首尾 `*`） */
  observeBlockList(cb: (patterns: string[]) => void): () => void {
    return BlocklistDao.observeGlobPatterns((globs: string[]) => {
      cb(globs.map((g: string): string => g.length >= 2 ? g.substring(1, g.length - 1) : ''));
    });
  }

  /** SS-A21：空白忽略；小写+去首尾空白；重复（唯一约束）忽略。之后重算屏蔽状态 */
  async addBlocklistPattern(pattern: string): Promise<void> {
    if (!isBlankString(pattern)) {
      try {
        await BlocklistDao.insertSafely(pattern.toLowerCase().trim());
      } catch (e) {
        // Ignore: Query style method can't define ignore on constraint failures
        console.info(`FEEDER_REPO: blocklist insert ignored: ${(e as Error)?.message}`);
      }
    }
    await this.runOnceBlocklistUpdate();
  }

  async removeBlocklistPattern(pattern: string): Promise<void> {
    await BlocklistDao.deletePattern(pattern);
    await this.runOnceBlocklistUpdate();
  }

  /** SettingsStore setter 触发 SettingsHooks.fireBlocklistChanged → 本类注册的钩子重算 */
  async setApplyBlocklistToSummaries(v: boolean): Promise<void> { await this.settings.setApplyBlocklistToSummaries(v); }

  async setApplyBlocklistToLinks(v: boolean): Promise<void> { await this.settings.setApplyBlocklistToLinks(v); }

  async setBlockStatusForNewInFeed(feedId: number, blockTime: number): Promise<void> {
    await this.feedItemStore.setBlockStatusForNewInFeed(feedId, blockTime);
  }

  /** 源 runOnceBlocklistUpdate → BlocklistUpdateJob 默认分支：全表重算 */
  async runOnceBlocklistUpdate(): Promise<void> {
    await this.feedItemStore.setItemBlockStatus(Date.now());
  }

  // ================================================================ 同步 / 后台透传

  /** 源 ensurePeriodicSyncConfigured → schedulePeriodicRssSync(replace=false)（RP-A37，由同步引擎经 SettingsHooks 实现） */
  ensurePeriodicSyncConfigured(): void { fireSyncScheduleHook(false); }

  observeFeedsItemsWithDefaultFullTextNeedingDownload(cb: (items: FeedItemIdWithLink[]) => void): () => void {
    return this.feedItemStore.observeFeedsItemsWithDefaultFullTextNeedingDownload(cb);
  }

  async markAsFullTextDownloaded(feedItemId: number): Promise<void> {
    await this.feedItemStore.markAsFullTextDownloaded(feedItemId);
  }

  observeFeedItemsNeedingNotifying(cb: (ids: number[]) => void): () => void {
    return this.feedItemStore.observeFeedItemsNeedingNotifying(cb);
  }

  async loadFeedItem(guid: string, feedId: number): Promise<FeedItem | null> {
    return await this.feedItemStore.loadFeedItem(guid, feedId);
  }

  async upsertFeedItems(itemsWithText: FeedItemWithText[], block: FeedItemTextBlock): Promise<void> {
    await this.feedItemStore.upsertFeedItems(itemsWithText, block);
  }

  async getItemsToBeCleanedFromFeed(feedId: number, keepCount: number): Promise<number[]> {
    return await this.feedItemStore.getItemsToBeCleanedFromFeed(feedId, keepCount);
  }

  async deleteFeedItems(ids: number[]): Promise<void> { await this.feedItemStore.deleteFeedItems(ids); }

  async updateWordCountFull(id: number, wordCount: number): Promise<void> {
    await this.feedItemStore.updateWordCountFull(id, wordCount);
  }

  async duplicateStoryExists(id: number, title: string, link: string | null): Promise<boolean> {
    return await this.feedItemStore.duplicateStoryExists(id, title, link);
  }

  async syncLoadFeedIfStale(feedId: number, staleTime: number, retryAfter: number): Promise<Feed | null> {
    return await this.feedStore.syncLoadFeedIfStale(feedId, staleTime, retryAfter);
  }

  async syncLoadFeed(feedId: number, retryAfter: number): Promise<Feed | null> {
    return await this.feedStore.syncLoadFeed(feedId, retryAfter);
  }

  /** 源 syncLoadFeedsIfStale(tag, …) */
  async syncLoadFeedsInTagIfStale(tag: string, staleTime: number, retryAfter: number): Promise<Feed[]> {
    return await this.feedStore.syncLoadFeedsInTagIfStale(tag, staleTime, retryAfter);
  }

  async syncLoadFeedsIfStale(staleTime: number, retryAfter: number): Promise<Feed[]> {
    return await this.feedStore.syncLoadFeedsIfStale(staleTime, retryAfter);
  }

  /** 源 syncLoadFeeds(tag, …) */
  async syncLoadFeedsInTag(tag: string, retryAfter: number): Promise<Feed[]> {
    return await this.feedStore.syncLoadFeedsInTag(tag, retryAfter);
  }

  async syncLoadFeeds(retryAfter: number): Promise<Feed[]> { return await this.feedStore.syncLoadFeeds(retryAfter); }

  async setCurrentlySyncingOn(feedId: number, syncing: boolean, lastSync: number | null = null): Promise<void> {
    await this.feedStore.setCurrentlySyncingOn(feedId, syncing, lastSync);
  }

  async setRetryAfterForFeedsWithBaseUrl(host: string, retryAfter: number): Promise<void> {
    await this.feedStore.setRetryAfterForFeedsWithBaseUrl(host, retryAfter);
  }

  // ================================================================ 同步链（本地存储部分）

  /** RP-A43：总是记录远端已读标记；本地有该条目 → 记已同步并标已读 */
  async remoteMarkAsRead(feedUrl: string, articleGuid: string): Promise<void> {
    await this.syncRemoteStore.addRemoteReadMark(feedUrl, articleGuid);
    const itemId: number | null = await this.feedItemStore.getFeedItemId(feedUrl, articleGuid);
    if (itemId !== null) {
      await this.syncRemoteStore.setSynced(itemId);
      await this.feedItemStore.markAsReadAndNotified(itemId);
    }
  }

  /** RP-A44 */
  async applyRemoteReadMarks(): Promise<void> {
    const toBeApplied: RemoteReadMarkReadyToBeApplied[] = await this.syncRemoteStore.getRemoteReadMarksReadyToBeApplied();
    const itemIds: number[] = toBeApplied.map((r: RemoteReadMarkReadyToBeApplied): number => r.feedItemId);
    await this.feedItemStore.markAsRead(itemIds);
    for (const itemId of itemIds) {
      await this.syncRemoteStore.setSynced(itemId);
    }
    await this.syncRemoteStore.deleteAppliedRemoteReadMarks(
      toBeApplied.map((r: RemoteReadMarkReadyToBeApplied): number => r.id));
    // Remove stale marks for items that are already read so they don't override a deliberate "mark as unread"
    await this.syncRemoteStore.deleteRemoteReadMarksForReadItems();
  }

  observeSyncRemote(cb: (remote: SyncRemote | null) => void): () => void {
    return this.syncRemoteStore.observeSyncRemote(cb);
  }

  async getSyncRemote(): Promise<SyncRemote> { return await this.syncRemoteStore.getSyncRemote(); }

  async updateSyncRemote(syncRemote: SyncRemote): Promise<void> { await this.syncRemoteStore.updateSyncRemote(syncRemote); }

  async updateSyncRemoteMessageTimestamp(timestamp: number): Promise<void> {
    await this.syncRemoteStore.updateSyncRemoteMessageTimestamp(timestamp);
  }

  async getFeedItemsWithoutSyncedReadMark(): Promise<FeedItemForReadMark[]> {
    return await this.syncRemoteStore.getFeedItemsWithoutSyncedReadMark();
  }

  async setSynced(feedItemId: number): Promise<void> { await this.syncRemoteStore.setSynced(feedItemId); }

  /** RP-A45 */
  async deleteStaleRemoteReadMarks(): Promise<void> { await this.syncRemoteStore.deleteStaleRemoteReadMarks(Date.now()); }

  async getGuidsWhichAreSyncedAsReadInFeed(feed: Feed): Promise<string[]> {
    return await this.syncRemoteStore.getGuidsWhichAreSyncedAsReadInFeed(feed.url);
  }

  async replaceWithDefaultSyncRemote(): Promise<void> { await this.syncRemoteStore.replaceWithDefaultSyncRemote(); }

  observeDevices(cb: (devices: SyncDevice[]) => void): () => void { return this.syncRemoteStore.observeDevices(cb); }

  async replaceDevices(devices: SyncDevice[]): Promise<void> { await this.syncRemoteStore.replaceDevices(devices); }

  async getRemotelySeenFeeds(): Promise<string[]> { return await this.syncRemoteStore.getRemotelySeenFeeds(); }

  async replaceRemoteFeedsWith(remoteFeeds: RemoteFeed[]): Promise<void> {
    await this.syncRemoteStore.replaceRemoteFeedsWith(remoteFeeds);
  }
}
