/**
 * SyncChain —— 源 archmodel/Repository.kt §同步链（updateDeviceList / joinSyncChain / leaveSyncChain / removeDevice /
 * startNewSyncChain / remoteMarkAsRead / applyRemoteReadMarks / isSyncChainConfigured）的门面，
 * 以及 SyncRestClient 向同步引擎（core/sync/RssLocalSync.setSyncChainClient）的注册。
 *
 * 安装：`installSyncChain(ctx)` 幂等；须在 AppDatabase/SettingsStore/HttpClient 初始化之后调用
 * （应用进程：AppBootstrap.run；WorkScheduler 扩展进程：SyncScheduler.bootstrapHeadless）。
 * 同步页加载时也会调用一次，保证页面可用。
 *
 * 调度（SY-A49..A51 / RP-A47）由 core/sync/SyncScheduler 负责：
 *  - RSS 同步前 getFeeds→getRead→getDevices→sendUpdatedFeeds→markAsRead（RssLocalSync，异常只记日志）；
 *  - 已读后 ≥10 秒合并上传（runOnceSyncChainSendRead，未入链不调度）；
 *  - 回前台 getRead→applyRemoteReadMarks→getDevices（runOnceSyncChainGetUpdates，未入链不调度）。
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Repository } from '../../core/repo/Repository';
import { setSecretKeyGenerator } from '../../core/db/SyncDaos';
import { SyncChainClient, setSyncChainClient } from '../../core/sync/RssLocalSync';
import { SyncScheduler } from '../../core/sync/SyncScheduler';
import { Either, leftOf, rightOf } from '../../core/util/Either';
import { toError } from '../../core/net/NetworkResult';
import { generateSecretKeyString } from './SyncCrypto';
import { ErrorResponse } from './FeederSyncApi';
import { DeviceIdRegistry, DeviceListResponse } from './SyncRestBodies';
import { SyncRestClient } from './SyncRestClient';

const LOG_TAG: string = 'FEEDER_SYNC_CHAIN';
const DEVICE_ID_PREFS: string = 'feeder_sync_device_ids';
const DEVICE_ID_KEY: string = 'exact_device_ids';

/** 源 Pair<String, String>（syncCode, secretKey） */
export class SyncChainCreated {
  syncCode: string = '';
  secretKey: string = '';
}

/** SyncChainClient 适配（RssLocalSync / SyncScheduler 使用；异常由调用方吞掉只记日志） */
class RestSyncChainClient implements SyncChainClient {
  isConfigured(): boolean {
    return SyncRestClient.instance().isConfigured;
  }

  async getFeeds(): Promise<void> {
    await SyncRestClient.instance().getFeeds();
  }

  async getRead(): Promise<void> {
    await SyncRestClient.instance().getRead();
  }

  async getDevices(): Promise<void> {
    await SyncRestClient.instance().getDevices();
  }

  async sendUpdatedFeeds(): Promise<void> {
    await SyncRestClient.instance().sendUpdatedFeeds();
  }

  async markAsRead(): Promise<void> {
    await SyncRestClient.instance().markAsRead();
  }
}

let installed: boolean = false;
let devicePrefs: preferences.Preferences | null = null;

function loadDeviceIds(ctx: common.Context): void {
  try {
    const opts: preferences.Options = { name: DEVICE_ID_PREFS };
    const p: preferences.Preferences = preferences.getPreferencesSync(ctx, opts);
    devicePrefs = p;
    const raw: preferences.ValueType = p.getSync(DEVICE_ID_KEY, '[]');
    const parsed: Object | null = JSON.parse(typeof raw === 'string' ? raw as string : '[]') as Object | null;
    const entries: Map<number, string> = new Map<number, string>();
    if (parsed !== null && Array.isArray(parsed)) {
      for (const v of parsed as Object[]) {
        if (typeof v === 'string') {
          entries.set(Number(v as string), v as string);
        }
      }
    }
    DeviceIdRegistry.load(entries);
    DeviceIdRegistry.setPersister((all: Map<number, string>) => {
      const p2: preferences.Preferences | null = devicePrefs;
      if (p2 === null) {
        return;
      }
      const list: string[] = [];
      all.forEach((v: string) => {
        list.push(v);
      });
      try {
        p2.putSync(DEVICE_ID_KEY, JSON.stringify(list));
        p2.flush().catch((e: Error) => {
          console.error(LOG_TAG, `flush device ids failed: ${e?.message}`);
        });
      } catch (e) {
        console.error(LOG_TAG, `persist device ids failed: ${toError(e as Object).message}`);
      }
    });
  } catch (e) {
    console.error(LOG_TAG, `load device ids failed: ${toError(e as Object).message}`);
  }
}

/**
 * 注册同步链客户端与密钥生成器（幂等）。ctx 用于持久化超出 2^53 的 deviceId 精确值；null 时仅内存。
 * 返回客户端初始化（源 SyncRestClient init 的 runBlocking initialize）完成的 Promise。
 */
export function installSyncChain(ctx: common.Context | null): Promise<void> {
  if (ctx !== null && devicePrefs === null) {
    loadDeviceIds(ctx);
  }
  if (!installed) {
    installed = true;
    setSecretKeyGenerator(generateSecretKeyString);
    setSyncChainClient(new RestSyncChainClient());
  }
  return SyncRestClient.instance().ensureInitialized();
}

export class SyncChain {
  /** 源 Repository.isSyncChainConfigured */
  static isSyncChainConfigured(): boolean {
    return SyncRestClient.instance().isConfigured;
  }

  /** 源 Repository.updateDeviceList（SY-A14） */
  static async updateDeviceList(): Promise<Either<ErrorResponse, DeviceListResponse>> {
    await SyncRestClient.instance().ensureInitialized();
    return await SyncRestClient.instance().getDevices();
  }

  /** 源 Repository.joinSyncChain：成功后刷新设备列表 */
  static async joinSyncChain(syncCode: string, secretKey: string): Promise<Either<ErrorResponse, string>> {
    await SyncRestClient.instance().ensureInitialized();
    const r: Either<ErrorResponse, string> = await SyncRestClient.instance().join(syncCode, secretKey);
    if (r.isRight()) {
      await SyncRestClient.instance().getDevices();
    }
    return r;
  }

  /** 源 Repository.leaveSyncChain */
  static async leaveSyncChain(): Promise<void> {
    await SyncRestClient.instance().ensureInitialized();
    const r: Either<ErrorResponse, boolean> = await SyncRestClient.instance().leave();
    const err: ErrorResponse | null = r.leftOrNull();
    if (err !== null) {
      console.error(LOG_TAG, `leaveSyncChain: ${err.code}, ${err.body}`);
    }
  }

  /** 源 Repository.removeDevice */
  static async removeDevice(deviceId: number): Promise<void> {
    await SyncRestClient.instance().ensureInitialized();
    const r: Either<ErrorResponse, DeviceListResponse> = await SyncRestClient.instance().removeDevice(deviceId);
    const err: ErrorResponse | null = r.leftOrNull();
    if (err !== null) {
      console.error(LOG_TAG, `removeDevice: ${err.code}, ${err.body}`);
    }
  }

  /** 源 Repository.startNewSyncChain（RP-A46）：成功后刷新设备列表并返回 (syncCode, 本地 secretKey) */
  static async startNewSyncChain(): Promise<Either<ErrorResponse, SyncChainCreated>> {
    await SyncRestClient.instance().ensureInitialized();
    const r: Either<ErrorResponse, string> = await SyncRestClient.instance().create();
    const syncCode: string | null = r.getOrNull();
    if (r.isRight() && syncCode !== null) {
      await SyncChain.updateDeviceList();
      const created: SyncChainCreated = new SyncChainCreated();
      created.syncCode = syncCode;
      created.secretKey = (await Repository.instance().getSyncRemote()).secretKey;
      return rightOf<ErrorResponse, SyncChainCreated>(created);
    }
    return leftOf<ErrorResponse, SyncChainCreated>(r.leftOrNull() as ErrorResponse);
  }

  /** 源 Repository.remoteMarkAsRead（RP-A43） */
  static async remoteMarkAsRead(feedUrl: string, articleGuid: string): Promise<void> {
    await Repository.instance().remoteMarkAsRead(feedUrl, articleGuid);
  }

  /** 源 Repository.applyRemoteReadMarks（RP-A44） */
  static async applyRemoteReadMarks(): Promise<void> {
    await Repository.instance().applyRemoteReadMarks();
  }

  /** 源 Repository.deleteStaleRemoteReadMarks（RP-A45） */
  static async deleteStaleRemoteReadMarks(): Promise<void> {
    await Repository.instance().deleteStaleRemoteReadMarks();
  }
}

/**
 * 向 core 的存储层就绪钩子注册 installSyncChain（幂等）。各进程入口模块加载时调用：
 * EntryAbility（AppBootstrap.run 第 5 步后执行）、WorkScheduler 扩展壳 / 卡片扩展（SyncScheduler.bootstrapHeadless 内执行）。
 */
export function registerSyncChainStartupHook(): void {
  SyncScheduler.addStorageReadyHook('installSyncChain', (ctx: common.Context): Promise<void> => installSyncChain(ctx));
}
