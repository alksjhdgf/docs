/**
 * SyncScreenViewModel —— 源 ui/compose/sync/SyncScreenViewModel.kt（+ SyncScreen.kt 的 syncCodeQueryParam /
 * secretKeyQueryParam 扩展属性）。
 *
 *  - syncCode / secretKey / 请求的 screenToShow 为页面状态；syncRemote 与设备表经 DbNotifier 订阅（≙ combine 五路 Flow）。
 *  - 实际显示的单屏（SY-A03）：已入链（syncChainId 长度 64）时 SETUP/JOIN → DEVICELIST；未入链时 DEVICELIST/ADD_DEVICE → SETUP。
 *  - 加入链接（SY-A20）：`https://feederapp.nononsenseapps.com/sync/join?sync_code=<chainId>&key=<URLEncoder(secretKey)>`。
 */
import { ID_UNSET } from '../../core/model/Enums';
import { Repository } from '../../core/repo/Repository';
import { RepositoryHooks } from '../../core/repo/RepoTypes';
import { SyncDevice, SyncRemote } from '../../core/db/SyncDaos';
import { DEEP_LINK_BASE_URI } from '../../core/util/Constants';
import { javaUrlDecode, javaUrlEncode } from '../../core/util/JavaCodec';
import { toError } from '../../core/net/NetworkResult';
import { Either } from '../../core/util/Either';
import { ErrorResponse } from './FeederSyncApi';
import { SyncChain, SyncChainCreated } from './SyncChain';
import { DeviceListResponse } from './SyncRestBodies';

const LOG_TAG: string = 'FEEDER_SYNCVMODEL';

export enum SyncScreenToShow {
  SETUP = 'SETUP',
  DEVICELIST = 'DEVICELIST',
  ADD_DEVICE = 'ADD_DEVICE',
  JOIN = 'JOIN',
}

export enum LeftScreenToShow {
  SETUP = 'SETUP',
  DEVICELIST = 'DEVICELIST',
}

export enum RightScreenToShow {
  ADD_DEVICE = 'ADD_DEVICE',
  JOIN = 'JOIN',
}

/** Kotlin String.substringAfter(delimiter)：找不到返回原串 */
function substringAfter(s: string, delimiter: string): string {
  const i: number = s.indexOf(delimiter);
  return i < 0 ? s : s.substring(i + delimiter.length);
}

/** Kotlin String.substringBefore(delimiter)：找不到返回原串 */
function substringBefore(s: string, delimiter: string): string {
  const i: number = s.indexOf(delimiter);
  return i < 0 ? s : s.substring(0, i);
}

/** 源 String.syncCodeQueryParam：`sync_code=` 之后（无则原串）的前 64 字符 */
export function syncCodeQueryParam(s: string): string {
  return substringAfter(s, 'sync_code=').substring(0, 64);
}

/** 源 String.secretKeyQueryParam：`key=` 之后、`&` 之前；含 `%3A` 时 URLDecoder 解码（失败保留原值） */
export function secretKeyQueryParam(s: string): string {
  const v: string = substringBefore(substringAfter(s, 'key='), '&');
  // Deeplinks are already decoded - but not if you scan a QR code
  if (v.includes('%3A')) {
    try {
      return javaUrlDecode(v);
    } catch (e) {
      console.error(LOG_TAG, `Failed to decode secret key: ${toError(e as Object).message}`);
      return v;
    }
  }
  return v;
}

/** SY-A20 */
export function addNewDeviceUrlOf(syncChainId: string, secretKey: string): string {
  return `${DEEP_LINK_BASE_URI}/sync/join?sync_code=${syncChainId}&key=${javaUrlEncode(secretKey)}`;
}

@ObservedV2
export class SyncScreenViewModel {
  @Trace syncCode: string = '';
  @Trace secretKey: string = '';
  /** 请求的单屏（源 state["syncScreen"]） */
  @Trace screenToShow: SyncScreenToShow = SyncScreenToShow.SETUP;
  /** syncRemote 快照（null = 尚未读到） */
  @Trace remoteSyncChainId: string = '';
  @Trace remoteSecretKey: string = '';
  @Trace deviceId: number = 0;
  @Trace deviceList: SyncDevice[] = [];

  private screenSet: boolean = false;
  private disposers: (() => void)[] = [];
  private disposed: boolean = false;

  /** 源 SyncScreenViewState.singleScreenToShow（SY-A03） */
  get singleScreenToShow(): SyncScreenToShow {
    const screen: SyncScreenToShow = this.screenToShow;
    if (this.remoteSyncChainId.length === 64) {
      if (screen === SyncScreenToShow.SETUP || screen === SyncScreenToShow.JOIN) {
        return SyncScreenToShow.DEVICELIST;
      }
      return screen;
    }
    if (screen === SyncScreenToShow.DEVICELIST || screen === SyncScreenToShow.ADD_DEVICE) {
      return SyncScreenToShow.SETUP;
    }
    return screen;
  }

  get leftScreenToShow(): LeftScreenToShow {
    const s: SyncScreenToShow = this.singleScreenToShow;
    return s === SyncScreenToShow.SETUP || s === SyncScreenToShow.JOIN ? LeftScreenToShow.SETUP :
    LeftScreenToShow.DEVICELIST;
  }

  get rightScreenToShow(): RightScreenToShow {
    const s: SyncScreenToShow = this.singleScreenToShow;
    return s === SyncScreenToShow.SETUP || s === SyncScreenToShow.JOIN ? RightScreenToShow.JOIN :
    RightScreenToShow.ADD_DEVICE;
  }

  get addNewDeviceUrl(): string {
    return addNewDeviceUrlOf(this.remoteSyncChainId, this.remoteSecretKey);
  }

  /** 已加入同步链：顶栏溢出菜单可见（单屏仅 DEVICELIST；双栏左侧为设备列表时） */
  get hasSyncChain(): boolean {
    return this.remoteSyncChainId.length === 64;
  }

  /**
   * 源构造（init 两段）：路由参数 syncCode/secretKey 任一非空且未指定屏 → JOIN（SY-A12）；
   * 未携带路由参数时以 syncRemote.syncChainId 预填同步码；随后订阅 syncRemote 与设备表。
   * @param argsPresent 路由是否携带了 SyncParam（≙ SavedStateHandle 含 "syncCode"）
   */
  start(syncCodeArg: string, secretKeyArg: string, argsPresent: boolean): void {
    this.syncCode = syncCodeArg;
    this.secretKey = secretKeyArg;
    if (syncCodeArg.trim().length > 0 || secretKeyArg.trim().length > 0) {
      if (!this.screenSet) {
        this.setScreen(SyncScreenToShow.JOIN);
      }
    }
    const repo: Repository = Repository.instance();
    repo.getSyncRemote().then((remote: SyncRemote) => {
      if (this.disposed) {
        return;
      }
      if (!argsPresent) {
        this.setSyncCode(remote.syncChainId);
      }
      this.applyRemote(remote);
    }).catch((e: Error) => {
      console.error(LOG_TAG, `getSyncRemote failed: ${e?.message}`);
    });
    this.disposers.push(repo.observeSyncRemote((remote: SyncRemote | null) => {
      if (!this.disposed) {
        this.applyRemote(remote);
      }
    }));
    this.disposers.push(repo.observeDevices((devices: SyncDevice[]) => {
      if (!this.disposed) {
        this.deviceList = devices;
      }
    }));
  }

  dispose(): void {
    this.disposed = true;
    for (const d of this.disposers) {
      d();
    }
    this.disposers = [];
  }

  private applyRemote(remote: SyncRemote | null): void {
    this.remoteSyncChainId = remote !== null ? remote.syncChainId : '';
    this.remoteSecretKey = remote !== null ? remote.secretKey : '';
    this.deviceId = remote !== null ? remote.deviceId : 0;
    console.debug(LOG_TAG, `Showing ${this.singleScreenToShow}, remoteCode: ${this.remoteSyncChainId.substring(0, 10)}`);
  }

  /** SY-A10：粘贴整条链接时提取 64 位同步码 */
  setSyncCode(value: string): void {
    const possibleUrlCode: string = syncCodeQueryParam(value);
    this.syncCode = possibleUrlCode.length === 64 ? possibleUrlCode : value;
  }

  /** SY-A10：含 `key=` 时只保留其值 */
  setSecretKey(value: string): void {
    this.secretKey = secretKeyQueryParam(value);
  }

  setScreen(value: SyncScreenToShow): void {
    this.screenSet = true;
    this.screenToShow = value;
  }

  /** SY-A14（应用作用域：页面销毁不取消） */
  updateDeviceList(): void {
    console.debug(LOG_TAG, 'Update Devices');
    SyncChain.updateDeviceList().then((r: Either<ErrorResponse, DeviceListResponse>) => {
      const err: ErrorResponse | null = r.leftOrNull();
      if (err !== null) {
        console.error(LOG_TAG, `updateDeviceList: ${err.code}: ${err.body}`);
      }
    }).catch((e: Error) => {
      console.error(LOG_TAG, `updateDeviceList failed: ${e?.message}`);
    });
  }

  /** SY-A11：成功 → 一次非用户触发 RSS 同步 + 切到添加设备页；失败只记日志 */
  joinSyncChain(syncCode: string, secretKey: string): void {
    console.debug(LOG_TAG, 'Joining sync chain');
    SyncChain.joinSyncChain(syncCode, secretKey).then((r: Either<ErrorResponse, string>) => {
      if (r.isRight()) {
        RepositoryHooks.runOnceRssSync(ID_UNSET, '', false, false);
        if (!this.disposed) {
          this.joinedWithSyncCode(syncCode, secretKey);
        }
      } else {
        const err: ErrorResponse = r.leftOrNull() as ErrorResponse;
        console.error(LOG_TAG, `joinSyncChain: ${err.code}, ${err.body}`);
      }
    }).catch((e: Error) => {
      console.error(LOG_TAG, `Error when joining sync chain: ${e?.message}`);
    });
  }

  /** SY-A18 */
  leaveSyncChain(): void {
    SyncChain.leaveSyncChain().then(() => {
      this.setSyncCode('');
      this.setSecretKey('');
      this.setScreen(SyncScreenToShow.SETUP);
    }).catch((e: Error) => {
      console.error(LOG_TAG, `Error when leaving sync chain: ${e?.message}`);
    });
  }

  removeDevice(deviceId: number): void {
    SyncChain.removeDevice(deviceId).catch((e: Error) => {
      console.error(LOG_TAG, `Error when removing device: ${e?.message}`);
    });
  }

  private joinedWithSyncCode(syncCode: string, secretKey: string): void {
    this.setSyncCode(syncCode);
    this.setSecretKey(secretKey);
    this.setScreen(SyncScreenToShow.ADD_DEVICE);
  }

  /** SY-A04：成功 → 添加设备页；失败只记日志 */
  startNewSyncChain(): void {
    SyncChain.startNewSyncChain().then((r: Either<ErrorResponse, SyncChainCreated>) => {
      const created: SyncChainCreated | null = r.getOrNull();
      if (r.isRight() && created !== null) {
        this.joinedWithSyncCode(created.syncCode, created.secretKey);
      } else {
        const err: ErrorResponse = r.leftOrNull() as ErrorResponse;
        console.error(LOG_TAG, `startNewChain: ${err.body}`);
      }
    }).catch((e: Error) => {
      console.error(LOG_TAG, `Error when starting new sync chain: ${e?.message}`);
    });
  }

  /** SY-A06 */
  onMissingBarCodeScanner(ui: UIContext): void {
    try {
      ui.getPromptAction().showToast({ message: $r('app.string.no_barcode_scanner_installed'), duration: 2000 });
    } catch (e) {
      console.error(LOG_TAG, `toast failed: ${toError(e as Object).message}`);
    }
  }
}
