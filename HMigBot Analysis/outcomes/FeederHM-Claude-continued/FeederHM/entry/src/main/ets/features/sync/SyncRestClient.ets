/**
 * SyncRestClient —— 源 sync/SyncRestClient.kt：Feeder Sync 客户端（加密设备名/已读标记/订阅列表的收发与本地合并）。
 *
 * 契约（SY-A26/A29..A42）：
 *  - initialize：存量远端 URL 含废弃主机 → 改写为默认地址并持久化；已入链则解码密钥、建立 API 客户端。
 *  - safeBlock：未入链（syncChainId 长度 ≠ 64）或客户端/密钥未初始化 → Left(1001)，不发请求。
 *  - 任何链内请求失败且错误体含 `Device not registered`（忽略大小写）→ 自动 leave()。
 *  - 异常：create 原样抛出（调用方 catch）；join → Left(999)；其余 → Left(1000) 或仅记日志（getRead/getFeeds）。
 */
import { Repository } from '../../core/repo/Repository';
import {
  DEFAULT_SERVER_ADDRESS, DEPRECATED_SYNC_HOSTS, RemoteFeed, SYNC_REMOTE_ID, SyncDevice, SyncRemote, generateDeviceName
} from '../../core/db/SyncDaos';
import { EPOCH_MS, Feed } from '../../core/model/Feed';
import { FeedItemForReadMark } from '../../core/model/FeedItem';
import { toError } from '../../core/net/NetworkResult';
import { Either, leftOf, rightOf } from '../../core/util/Either';
import { AesCbcWithIntegrity, SecretKeys } from './SyncCrypto';
import { ErrorResponse, FeederSyncApi } from './FeederSyncApi';
import {
  CreateRequest, DeviceListResponse, DeviceMessage, EncryptedFeed, EncryptedFeeds, EncryptedReadMark,
  GetEncryptedReadMarksResponse, GetFeedsResponse, JoinRequest, JoinResponse, ReadMarkContent,
  SendEncryptedReadMarkBulkRequest, SendEncryptedReadMarkRequest, SendReadMarkResponse, UpdateFeedsRequest,
  UpdateFeedsResponse, asWeakETagValue, encryptedFeedsListHash, toEncryptedFeed, urlEquals
} from './SyncRestBodies';

const LOG_TAG: string = 'FEEDER_REST_CLIENT';
const DEVICE_NOT_REGISTERED: string = 'Device not registered';
const READ_MARK_BATCH_SIZE: number = 100;

type SafeBlock<A> = (syncRemote: SyncRemote, feederSync: FeederSyncApi,
  secretKey: SecretKeys) => Promise<Either<ErrorResponse, A>>;

function errorOf(e: Object | null | undefined): Error {
  return toError(e);
}

export class SyncRestClient {
  private static inst: SyncRestClient | null = null;
  private feederSync: FeederSyncApi | null = null;
  private secretKey: SecretKeys | null = null;
  private initPromise: Promise<void> | null = null;

  static instance(): SyncRestClient {
    if (SyncRestClient.inst === null) {
      SyncRestClient.inst = new SyncRestClient();
    }
    return SyncRestClient.inst as SyncRestClient;
  }

  private get repository(): Repository {
    return Repository.instance();
  }

  /** 源 isConfigured = feederSync != null && secretKey != null */
  get isConfigured(): boolean {
    return this.isInitialized;
  }

  private get isInitialized(): boolean {
    return this.feederSync !== null && this.secretKey !== null;
  }

  /** 源 init { runBlocking { initialize() } }：未初始化时发起（并发调用共享同一 Promise；失败只记日志） */
  ensureInitialized(): Promise<void> {
    if (this.isInitialized) {
      return Promise.resolve();
    }
    if (this.initPromise === null) {
      this.initPromise = this.initialize().finally(() => {
        this.initPromise = null;
      });
    }
    return this.initPromise as Promise<void>;
  }

  /** SY-A26 */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }
    try {
      let syncRemote: SyncRemote = await this.repository.getSyncRemote();
      const url: string = syncRemote.url;
      if (DEPRECATED_SYNC_HOSTS.some((host: string): boolean => url.includes(host))) {
        console.debug(LOG_TAG, `Updating to latest sync host: ${DEFAULT_SERVER_ADDRESS}`);
        syncRemote = syncRemote.copy();
        syncRemote.url = DEFAULT_SERVER_ADDRESS;
        await this.repository.updateSyncRemote(syncRemote);
      }
      if (syncRemote.hasSyncChain()) {
        this.secretKey = AesCbcWithIntegrity.decodeKey(syncRemote.secretKey);
        this.feederSync = FeederSyncApi.forRemote(syncRemote.url);
      }
    } catch (e) {
      console.error(LOG_TAG, `Failed to initialize: ${errorOf(e as Object).message}`);
    }
  }

  /** SY-A33 */
  private async safeBlock<A>(block: SafeBlock<A>): Promise<Either<ErrorResponse, A>> {
    const syncRemote: SyncRemote = await this.repository.getSyncRemote();
    if (syncRemote.hasSyncChain()) {
      const feederSync: FeederSyncApi | null = this.feederSync;
      const secretKey: SecretKeys | null = this.secretKey;
      if (feederSync !== null && secretKey !== null) {
        return await block(syncRemote, feederSync, secretKey);
      }
    }
    return leftOf<ErrorResponse, A>(ErrorResponse.of(1001, null));
  }

  /** SY-A29：返回 syncCode。异常向上抛出 */
  async create(): Promise<Either<ErrorResponse, string>> {
    console.debug(LOG_TAG, 'create');
    // To ensure always uses correct client, manually set remote here ALWAYS
    const syncRemote: SyncRemote = await this.repository.getSyncRemote();
    const secretKey: SecretKeys = AesCbcWithIntegrity.decodeKey(syncRemote.secretKey);
    this.secretKey = secretKey;
    const feederSync: FeederSyncApi = FeederSyncApi.forRemote(syncRemote.url);
    this.feederSync = feederSync;

    const deviceName: string = generateDeviceName();
    const req: CreateRequest = new CreateRequest();
    req.deviceName = AesCbcWithIntegrity.encryptString(deviceName, secretKey);
    const result: Either<ErrorResponse, JoinResponse> = await feederSync.create(req);
    const response: JoinResponse | null = result.getOrNull();
    if (result.isRight() && response !== null) {
      const updated: SyncRemote = syncRemote.copy();
      updated.syncChainId = response.syncCode;
      updated.deviceId = response.deviceId;
      updated.deviceName = deviceName;
      updated.latestMessageTimestamp = EPOCH_MS;
      await this.repository.updateSyncRemote(updated);
      return rightOf<ErrorResponse, string>(response.syncCode);
    }
    return leftOf<ErrorResponse, string>(result.leftOrNull() as ErrorResponse);
  }

  /** SY-A30 */
  async join(syncCode: string, remoteSecretKey: string): Promise<Either<ErrorResponse, string>> {
    console.debug(LOG_TAG, 'join');
    try {
      console.debug(LOG_TAG, 'Really joining');
      // To ensure always uses correct client, manually set remote here ALWAYS
      const syncRemote: SyncRemote = await this.repository.getSyncRemote();
      syncRemote.secretKey = remoteSecretKey;
      syncRemote.deviceName = generateDeviceName();
      await this.repository.updateSyncRemote(syncRemote);

      const secretKey: SecretKeys = AesCbcWithIntegrity.decodeKey(syncRemote.secretKey);
      this.secretKey = secretKey;
      const feederSync: FeederSyncApi = FeederSyncApi.forRemote(syncRemote.url);
      this.feederSync = feederSync;
      console.debug(LOG_TAG, 'Updated objects');

      const req: JoinRequest = new JoinRequest();
      req.deviceName = AesCbcWithIntegrity.encryptString(syncRemote.deviceName, secretKey);
      const result: Either<ErrorResponse, JoinResponse> = await feederSync.join(syncCode, req);
      const response: JoinResponse | null = result.getOrNull();
      if (result.isRight() && response !== null) {
        console.debug(LOG_TAG, `Join response: deviceId=${response.deviceId}`);
        const updated: SyncRemote = syncRemote.copy();
        updated.syncChainId = response.syncCode;
        updated.deviceId = response.deviceId;
        updated.latestMessageTimestamp = EPOCH_MS;
        await this.repository.updateSyncRemote(updated);
        console.debug(LOG_TAG, 'Updated sync remote');
        return rightOf<ErrorResponse, string>(response.syncCode);
      }
      return leftOf<ErrorResponse, string>(result.leftOrNull() as ErrorResponse);
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error during join: ${err.message}`);
      return leftOf<ErrorResponse, string>(ErrorResponse.of(999, err.message));
    }
  }

  /** SY-A31 */
  async leave(): Promise<Either<ErrorResponse, boolean>> {
    console.debug(LOG_TAG, 'leave');
    try {
      return await this.safeBlock<boolean>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, boolean>> => {
        console.debug(LOG_TAG, 'Really leaving');
        try {
          const r: Either<ErrorResponse, DeviceListResponse> =
            await feederSync.removeDevice(syncRemote.syncChainId, syncRemote.deviceId, syncRemote.deviceId);
          const err: ErrorResponse | null = r.leftOrNull();
          if (err !== null) {
            console.error(LOG_TAG, `Error during leave: ${err.code}, ${err.body}`);
            return leftOf<ErrorResponse, boolean>(err);
          }
          return rightOf<ErrorResponse, boolean>(true);
        } finally {
          this.feederSync = null;
          this.secretKey = null;
        }
      });
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error during leave: ${err.message}`);
      return leftOf<ErrorResponse, boolean>(ErrorResponse.of(1000, err.message, err));
    } finally {
      this.feederSync = null;
      this.secretKey = null;
      await this.repository.replaceWithDefaultSyncRemote();
    }
  }

  private toSyncDevices(devices: DeviceMessage[], secretKey: SecretKeys, syncRemote: SyncRemote): SyncDevice[] {
    return devices.map((m: DeviceMessage): SyncDevice => {
      const d: SyncDevice = new SyncDevice();
      d.deviceId = m.deviceId;
      d.deviceName = AesCbcWithIntegrity.decryptString(m.deviceName, secretKey);
      d.syncRemote = syncRemote.id;
      return d;
    });
  }

  /** SY-A16：服务器移除设备，用返回列表替换本地设备表 */
  async removeDevice(deviceId: number): Promise<Either<ErrorResponse, DeviceListResponse>> {
    try {
      return await this.safeBlock<DeviceListResponse>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, DeviceListResponse>> => {
        console.debug(LOG_TAG, 'removeDevice');
        const r: Either<ErrorResponse, DeviceListResponse> =
          await feederSync.removeDevice(syncRemote.syncChainId, syncRemote.deviceId, deviceId);
        await this.afterDeviceList(r, syncRemote, secretKey);
        return r;
      });
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error in removeDevice: ${err.message}`);
      return leftOf<ErrorResponse, DeviceListResponse>(ErrorResponse.of(1000, err.message, err));
    }
  }

  private async afterDeviceList(r: Either<ErrorResponse, DeviceListResponse>, syncRemote: SyncRemote,
    secretKey: SecretKeys): Promise<void> {
    const response: DeviceListResponse | null = r.getOrNull();
    if (r.isRight() && response !== null) {
      console.debug(LOG_TAG, `Updating device list: ${response.devices.length} devices`);
      await this.repository.replaceDevices(this.toSyncDevices(response.devices, secretKey, syncRemote));
    } else {
      await this.leaveChainIfKickedOutElseLog(r.leftOrNull() as ErrorResponse);
    }
  }

  /** SY-A34 */
  private async sendReadMarksBatch(feedItems: FeedItemForReadMark[]): Promise<Either<ErrorResponse, SendReadMarkResponse>> {
    try {
      return await this.safeBlock<SendReadMarkResponse>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, SendReadMarkResponse>> => {
        console.debug(LOG_TAG, `markAsRead: ${feedItems.length} items`);
        const req: SendEncryptedReadMarkBulkRequest = new SendEncryptedReadMarkBulkRequest();
        for (const feedItem of feedItems) {
          const item: SendEncryptedReadMarkRequest = new SendEncryptedReadMarkRequest();
          item.encrypted = AesCbcWithIntegrity.encryptString(
            ReadMarkContent.of(feedItem.feedUrl, feedItem.guid).toJson(), secretKey);
          req.items.push(item);
        }
        const r: Either<ErrorResponse, SendReadMarkResponse> =
          await feederSync.sendEncryptedReadMarks(syncRemote.syncChainId, syncRemote.deviceId, req);
        if (r.isRight()) {
          for (const feedItem of feedItems) {
            await this.repository.setSynced(feedItem.id);
          }
        } else {
          await this.leaveChainIfKickedOutElseLog(r.leftOrNull() as ErrorResponse);
        }
        // Should not set latest timestamp here because we cant be sure to retrieved them
        return r;
      });
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error in markAsRead: ${err.message}`);
      return leftOf<ErrorResponse, SendReadMarkResponse>(ErrorResponse.of(1000, err.message, err));
    }
  }

  async markAsRead(): Promise<Either<ErrorResponse, boolean>> {
    try {
      return await this.safeBlock<boolean>(async (_syncRemote: SyncRemote, _feederSync: FeederSyncApi,
        _secretKey: SecretKeys): Promise<Either<ErrorResponse, boolean>> => {
        const readItems: FeedItemForReadMark[] = await this.repository.getFeedItemsWithoutSyncedReadMark();
        if (readItems.length > 0) {
          console.debug(LOG_TAG, `markAsReadBatch: ${readItems.length} items`);
          for (let i = 0; i < readItems.length; i += READ_MARK_BATCH_SIZE) {
            await this.sendReadMarksBatch(readItems.slice(i, i + READ_MARK_BATCH_SIZE));
          }
        }
        return rightOf<ErrorResponse, boolean>(true);
      });
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error in markAsRead: ${err.message}`);
      return leftOf<ErrorResponse, boolean>(ErrorResponse.of(1000, err.message, err));
    }
  }

  /** SY-A32 */
  async getDevices(): Promise<Either<ErrorResponse, DeviceListResponse>> {
    try {
      console.debug(LOG_TAG, 'getDevices');
      return await this.safeBlock<DeviceListResponse>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, DeviceListResponse>> => {
        const r: Either<ErrorResponse, DeviceListResponse> =
          await feederSync.getDevices(syncRemote.syncChainId, syncRemote.deviceId);
        await this.afterDeviceList(r, syncRemote, secretKey);
        return r;
      });
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error in getDevices: ${err.message}`);
      return leftOf<ErrorResponse, DeviceListResponse>(ErrorResponse.of(1000, err.message, err));
    }
  }

  /** SY-A35 */
  async getRead(): Promise<void> {
    try {
      await this.safeBlock<boolean>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, boolean>> => {
        console.debug(LOG_TAG, 'getRead');
        // Add one ms so we don't get inclusive of last message we got
        const r: Either<ErrorResponse, GetEncryptedReadMarksResponse> = await feederSync.getEncryptedReadMarks(
          syncRemote.syncChainId, syncRemote.deviceId, syncRemote.latestMessageTimestamp + 1);
        const response: GetEncryptedReadMarksResponse | null = r.getOrNull();
        if (r.isRight() && response !== null) {
          console.debug(LOG_TAG, `getRead: ${response.readMarks.length} read marks`);
          for (const readMark of response.readMarks) {
            await this.applyReadMark(readMark, secretKey);
          }
          return rightOf<ErrorResponse, boolean>(true);
        }
        const err: ErrorResponse = r.leftOrNull() as ErrorResponse;
        await this.leaveChainIfKickedOutElseLog(err);
        return leftOf<ErrorResponse, boolean>(err);
      });
    } catch (e) {
      console.error(LOG_TAG, `Error in getRead: ${errorOf(e as Object).message}`);
    }
  }

  private async applyReadMark(readMark: EncryptedReadMark, secretKey: SecretKeys): Promise<void> {
    const readMarkContent: ReadMarkContent | null =
      ReadMarkContent.fromJson(AesCbcWithIntegrity.decryptString(readMark.encrypted, secretKey));
    if (readMarkContent === null) {
      console.error(LOG_TAG, 'Failed to decrypt readMark content');
      // Advance the timestamp so the same corrupt mark is not retried indefinitely.
      await this.repository.updateSyncRemoteMessageTimestamp(readMark.timestamp);
      return;
    }
    await this.repository.remoteMarkAsRead(readMarkContent.feedUrl, readMarkContent.articleGuid);
    await this.repository.updateSyncRemoteMessageTimestamp(readMark.timestamp);
  }

  /** SY-A36 */
  async getFeeds(): Promise<void> {
    try {
      await this.safeBlock<boolean>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, boolean>> => {
        console.debug(LOG_TAG, 'getFeeds');
        const r: Either<ErrorResponse, GetFeedsResponse> =
          await feederSync.getFeeds(syncRemote.syncChainId, syncRemote.deviceId);
        const response: GetFeedsResponse | null = r.getOrNull();
        if (!r.isRight() || response === null) {
          const err: ErrorResponse = r.leftOrNull() as ErrorResponse;
          await this.leaveChainIfKickedOutElseLog(err);
          return leftOf<ErrorResponse, boolean>(err);
        }
        console.debug(LOG_TAG, `GetFeeds response hash: ${response.hash}`);
        if (response.hash === syncRemote.lastFeedsRemoteHash) {
          // Nothing to do
          console.debug(LOG_TAG, 'GetFeeds got nothing new, returning.');
          return rightOf<ErrorResponse, boolean>(true);
        }
        const encryptedFeeds: EncryptedFeeds | null =
          EncryptedFeeds.fromJson(AesCbcWithIntegrity.decryptString(response.encrypted, secretKey));
        if (encryptedFeeds === null) {
          console.error(LOG_TAG, 'Failed to decrypt encrypted feeds');
          return rightOf<ErrorResponse, boolean>(true);
        }
        await this.feedDiffing(encryptedFeeds.feeds);
        syncRemote.lastFeedsRemoteHash = response.hash;
        await this.repository.updateSyncRemote(syncRemote);
        return rightOf<ErrorResponse, boolean>(true);
      });
    } catch (e) {
      console.error(LOG_TAG, `Error in getFeeds: ${errorOf(e as Object).message}`);
    }
  }

  /** SY-A37 */
  private async feedDiffing(remoteFeeds: EncryptedFeed[]): Promise<void> {
    try {
      console.debug(LOG_TAG, `feedDiffing: ${remoteFeeds.length}`);
      const remotelySeenFeedUrls: string[] = await this.repository.getRemotelySeenFeeds();
      const containsUrl = (list: string[], url: string): boolean =>
        list.some((u: string): boolean => urlEquals(u, url));
      const remoteUrls: string[] = remoteFeeds.map((f: EncryptedFeed): string => f.url);

      const feedUrlsWhichWereDeletedOnRemote: string[] =
        remotelySeenFeedUrls.filter((url: string): boolean => !containsUrl(remoteUrls, url));
      console.debug(LOG_TAG, `RemotelyDeleted: ${feedUrlsWhichWereDeletedOnRemote.length}`);
      for (const url of feedUrlsWhichWereDeletedOnRemote) {
        console.debug(LOG_TAG, `Deleting remotely deleted feed: ${url}`);
        await this.repository.deleteFeed(url);
      }

      for (const remoteFeed of remoteFeeds) {
        const seenRemotelyBefore: boolean = containsUrl(remotelySeenFeedUrls, remoteFeed.url);
        const dbFeed: Feed | null = await this.repository.getFeedByUrl(remoteFeed.url);
        if (dbFeed === null && !seenRemotelyBefore) {
          // Entirely new remote feed
          console.debug(LOG_TAG, `Saving new feed: ${remoteFeed.url}`);
          await this.repository.saveFeed(remoteFeed.updateFeedCopy(new Feed()));
        } else if (dbFeed === null) {
          // Has been locally deleted, it will be deleted on next call of updateFeeds
          console.debug(LOG_TAG, `Received update for locally deleted feed: ${remoteFeed.url}`);
        } else if (remoteFeed.whenModified > dbFeed.whenModified) {
          // Compare modification date - only save if remote is newer
          console.debug(LOG_TAG, `Saving updated feed: ${remoteFeed.url}`);
          await this.repository.saveFeed(remoteFeed.updateFeedCopy(dbFeed));
        } else {
          console.debug(LOG_TAG, `Not saving feed because local date trumps it: ${remoteFeed.url}`);
        }
      }

      await this.repository.replaceRemoteFeedsWith(remoteFeeds.map((f: EncryptedFeed): RemoteFeed => {
        const rf: RemoteFeed = new RemoteFeed();
        rf.syncRemote = SYNC_REMOTE_ID;
        rf.url = f.url;
        return rf;
      }));
    } catch (e) {
      console.error(LOG_TAG, `Error in feedDiffing: ${errorOf(e as Object).message}`);
    }
  }

  /** SY-A39/A40 */
  async sendUpdatedFeeds(): Promise<Either<ErrorResponse, boolean>> {
    try {
      return await this.safeBlock<boolean>(async (syncRemote: SyncRemote, feederSync: FeederSyncApi,
        secretKey: SecretKeys): Promise<Either<ErrorResponse, boolean>> => {
        console.debug(LOG_TAG, 'sendUpdatedFeeds');
        const lastRemoteHash: number = syncRemote.lastFeedsRemoteHash;
        // Important to keep iteration order stable - across devices. So sort on URL, not ID or date
        const feeds: EncryptedFeed[] =
          (await this.repository.getFeedsOrderedByUrl()).map((f: Feed): EncryptedFeed => toEncryptedFeed(f));
        // List hashCodes are based on elements
        const currentContentHash: number = encryptedFeedsListHash(feeds);
        if (lastRemoteHash === currentContentHash) {
          console.debug(LOG_TAG, "Feeds haven't changed - so not sending");
          return rightOf<ErrorResponse, boolean>(false);
        }
        const body: EncryptedFeeds = new EncryptedFeeds();
        body.feeds = feeds;
        const req: UpdateFeedsRequest = new UpdateFeedsRequest();
        req.contentHash = currentContentHash;
        req.encrypted = AesCbcWithIntegrity.encryptString(body.toJson(), secretKey);
        console.debug(LOG_TAG, `Sending updated feeds with locally computed hash: ${currentContentHash}`);
        // Might fail with 412 in case already updated remotely - need to call get
        const r: Either<ErrorResponse, UpdateFeedsResponse> = await feederSync.updateFeeds(syncRemote.syncChainId,
          syncRemote.deviceId, asWeakETagValue(syncRemote.lastFeedsRemoteHash), req);
        const response: UpdateFeedsResponse | null = r.getOrNull();
        if (r.isRight() && response !== null) {
          // Store hash for future
          syncRemote.lastFeedsRemoteHash = response.hash;
          await this.repository.updateSyncRemote(syncRemote);
          console.debug(LOG_TAG, `Received updated feeds hash: ${response.hash}`);
          return rightOf<ErrorResponse, boolean>(true);
        }
        const err: ErrorResponse = r.leftOrNull() as ErrorResponse;
        if (err.code === 412) {
          // Need to call get first because updates have happened
          await this.getFeeds();
          // Now try again
          await this.sendUpdatedFeeds();
        } else {
          await this.leaveChainIfKickedOutElseLog(err);
        }
        return leftOf<ErrorResponse, boolean>(err);
      });
    } catch (e) {
      const err: Error = errorOf(e as Object);
      console.error(LOG_TAG, `Error in sendUpdatedFeeds: ${err.message}`);
      return leftOf<ErrorResponse, boolean>(ErrorResponse.of(1000, err.message, err));
    }
  }

  /** SY-A41 */
  private async leaveChainIfKickedOutElseLog(err: ErrorResponse): Promise<void> {
    console.error(LOG_TAG, `leaveChainIfKickedOutElseLog: ${err.code}, ${err.body}`);
    const body: string | null = err.body;
    if (body !== null && body.toLowerCase().includes(DEVICE_NOT_REGISTERED.toLowerCase())) {
      // this device has been removed from the chain from another device
      await this.leave();
    }
  }
}
