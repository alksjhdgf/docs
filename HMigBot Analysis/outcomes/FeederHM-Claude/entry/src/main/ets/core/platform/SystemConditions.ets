/**
 * SystemConditions.ets —— 源 util/SystemUtils.kt + MainActivityViewModel.isOkToSyncAutomatically
 * + ui/compose/utils/Permissions.kt 的鸿蒙等价物。
 *
 * - 联网/计费/Wi-Fi：@kit.NetworkKit connection（需 ohos.permission.GET_NETWORK_INFO，module.json5 由 fnd-app-init 声明）。
 * - 充电：@kit.BasicServicesKit batteryInfo.chargingStatus。
 * - 计费判断与 core/net 的图片拦截器共用同一实现（UT-A29：同一 currentlyUnmetered 判断）。
 */
import { connection } from '@kit.NetworkKit';
import { batteryInfo, deviceInfo } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { currentlyUnmetered } from '../net/Interceptors';
import { SettingsStore } from '../settings/SettingsStore';
import { javaUrlEncode } from '../util/JavaCodec';

export { currentlyUnmetered };

const LOG_TAG: string = 'FEEDER_SYSCOND';

/**
 * 源 currentlyMetered：系统"计费网络"标志（不是网络类型；热点也可能计费）。取不到 → false（视为不计费）。
 */
export function currentlyMetered(): boolean {
  return !currentlyUnmetered();
}

/** 源 currentlyConnected：活动（默认）网络存在且已连接。异常 → false。 */
export function currentlyConnected(): boolean {
  try {
    if (!connection.hasDefaultNetSync()) {
      return false;
    }
    const handle: connection.NetHandle = connection.getDefaultNetSync();
    // netId 为 0 表示无默认网络
    return handle !== undefined && handle !== null && handle.netId !== 0;
  } catch (e) {
    console.warn(`${LOG_TAG}: hasDefaultNet failed: ${JSON.stringify(e)}`);
    return false;
  }
}

/** 当前默认网络承载是否为 Wi-Fi（源无独立函数；"仅 Wi-Fi" 设置语义实际用 currentlyUnmetered）。 */
export function currentlyOnWifi(): boolean {
  try {
    if (!connection.hasDefaultNetSync()) {
      return false;
    }
    const caps: connection.NetCapabilities = connection.getNetCapabilitiesSync(connection.getDefaultNetSync());
    return caps.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0;
  } catch (e) {
    console.warn(`${LOG_TAG}: getNetCapabilities failed: ${JSON.stringify(e)}`);
    return false;
  }
}

/** 源 currentlyCharging：BatteryManager.isCharging。鸿蒙：充电中或已充满（仍接电源）视为充电。异常 → false。 */
export function currentlyCharging(): boolean {
  try {
    const st: batteryInfo.BatteryChargeState = batteryInfo.chargingStatus;
    return st === batteryInfo.BatteryChargeState.ENABLE || st === batteryInfo.BatteryChargeState.FULL;
  } catch (e) {
    console.warn(`${LOG_TAG}: chargingStatus failed: ${JSON.stringify(e)}`);
    return false;
  }
}

/** 纯组合逻辑（便于单测）：UT-A28 */
export function okToSyncAutomatically(connected: boolean, charging: boolean, unmetered: boolean,
  syncOnlyWhenCharging: boolean, syncOnlyOnWifi: boolean): boolean {
  return connected && (!syncOnlyWhenCharging || charging) && (!syncOnlyOnWifi || unmetered);
}

/**
 * 源 MainActivityViewModel.isOkToSyncAutomatically（UT-A28）：
 * 已联网 且（未开仅充电 或 正在充电）且（未开仅 Wi-Fi 或 当前不计费）。短路求值顺序照源。
 */
export function isOkToSyncAutomatically(): boolean {
  const s: SettingsStore = SettingsStore.instance();
  if (!currentlyConnected()) {
    return false;
  }
  if (s.syncOnlyWhenCharging && !currentlyCharging()) {
    return false;
  }
  if (s.syncOnlyOnWifi && !currentlyUnmetered()) {
    return false;
  }
  return true;
}

/** UT-A29 纯判断：仅 Wi-Fi 加载图片且当前计费 → 不发起网络加载 */
export function shouldLoadImagesFromNetwork(loadImageOnlyOnWifi: boolean, unmetered: boolean): boolean {
  return !loadImageOnlyOnWifi || unmetered;
}

/** 当前设置 + 当前网络下是否允许网络加载图片（与 net/ImageOnlyOnWifiInterceptor 同一判断） */
export function imagesAllowedFromNetwork(): boolean {
  return shouldLoadImagesFromNetwork(SettingsStore.instance().loadImageOnlyOnWifi, currentlyUnmetered());
}

/** 源 String.urlEncode() = URLEncoder.encode(s, "UTF-8")：表单编码，空格 → '+'（UT-A30） */
export function urlEncode(s: string): string {
  return javaUrlEncode(s);
}

// ---------------------------------------------------------------- 运行时权限（源 Permissions.kt，UT-A48）

export enum PermissionStatus {
  GRANTED = 'GRANTED',
  DENIED = 'DENIED',
}

/**
 * 源 rememberApiPermissionState：系统 API 级别低于 minimumApiLevel 时返回恒"已授予"的假状态（不弹框）。
 * 鸿蒙：deviceInfo.sdkApiVersion 对应 Build.VERSION.SDK_INT；真实状态走 abilityAccessCtrl。
 */
export class ApiPermissionState {
  readonly permission: Permissions;
  readonly grantedByDefault: boolean;
  status: PermissionStatus = PermissionStatus.DENIED;
  private onResult: (granted: boolean) => void;

  constructor(permission: Permissions, minimumApiLevel: number, onPermissionResult?: (granted: boolean) => void) {
    this.permission = permission;
    this.onResult = onPermissionResult !== undefined ? onPermissionResult : (granted: boolean): void => {
      console.info(`${LOG_TAG}: permission ${permission} result ${granted}`);
    };
    this.grantedByDefault = isGrantedByApiLevel(currentApiLevel(), minimumApiLevel);
    this.status = this.grantedByDefault ? PermissionStatus.GRANTED : checkPermission(permission);
  }

  get isGranted(): boolean {
    return this.status === PermissionStatus.GRANTED;
  }

  /** 源 launchPermissionRequest；GrantedByDefault 时什么都不做 */
  async launchPermissionRequest(ctx: common.UIAbilityContext): Promise<void> {
    if (this.grantedByDefault) {
      return;
    }
    let granted = false;
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(ctx, [this.permission]);
      granted = res.authResults.length > 0 && res.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      console.warn(`${LOG_TAG}: requestPermissions failed: ${JSON.stringify(e)}`);
    }
    this.status = granted ? PermissionStatus.GRANTED : PermissionStatus.DENIED;
    this.onResult(granted);
  }
}

/** 纯逻辑：API 级别低于最低要求 → 视为已授予 */
export function isGrantedByApiLevel(apiLevel: number, minimumApiLevel: number): boolean {
  return apiLevel < minimumApiLevel;
}

export function currentApiLevel(): number {
  try {
    return deviceInfo.sdkApiVersion;
  } catch (e) {
    return 0;
  }
}

export function checkPermission(permission: Permissions): PermissionStatus {
  try {
    const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const st = atManager.checkAccessTokenSync(info.appInfo.accessTokenId, permission);
    return st === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ? PermissionStatus.GRANTED : PermissionStatus.DENIED;
  } catch (e) {
    console.warn(`${LOG_TAG}: checkAccessToken failed: ${JSON.stringify(e)}`);
    return PermissionStatus.DENIED;
  }
}
