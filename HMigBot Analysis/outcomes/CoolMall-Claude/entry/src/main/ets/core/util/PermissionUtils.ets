/**
 * PermissionUtils (source: core/util/permission/PermissionUtils.kt, XXPermissions) — DATA-A22.
 * Result handling (source handlePermissionResult):
 *   all granted            -> callback(true)
 *   permanently denied     -> toast error "<name>被永久拒绝，请手动授予", open the system settings page, callback(false)
 *   denied                 -> toast error "<name>获取失败", callback(false)
 * Runtime permissions use abilityAccessCtrl; "permanently denied" = denied without the dialog being shown
 * (PermissionRequestResult.dialogShownResults false), which is how HarmonyOS reports a previous refusal.
 * Notification "permission" on HarmonyOS is the notification switch (notificationManager.requestEnableNotification);
 * see requestNotificationPermission for how permanent denial is detected there.
 */
import { abilityAccessCtrl, bundleManager, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ToastUtils } from './ToastUtils';
import { LogUtils } from './LogUtils';

const TAG: string = 'PermissionUtils';
const SUFFIX_PERMANENT: string = '被永久拒绝，请手动授予';
const SUFFIX_FAILED: string = '获取失败';
const NAME_NOTIFICATION: string = '通知权限';
const NAME_CAMERA: string = '相机权限';
const NAME_AUDIO: string = '录音权限';
const NAME_LOCATION: string = '位置权限';
const NAME_GALLERY: string = '相册权限';
const NAME_STORAGE: string = '存储权限';
const NAME_CAMERA_GALLERY: string = '相机和相册权限';
const NO_CONTEXT_MSG: string = '无法获取Activity实例，权限申请失败';
const PERMISSION_CAMERA: Permissions = 'ohos.permission.CAMERA';
const PERMISSION_MICROPHONE: Permissions = 'ohos.permission.MICROPHONE';
const PERMISSION_APPROXIMATELY_LOCATION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const PERMISSION_LOCATION: Permissions = 'ohos.permission.LOCATION';
const ERR_NOTIFICATION_DIALOG_SHOWING: number = 1600013;

export type PermissionCallback = (granted: boolean) => void;

export class PermissionUtils {
  /** Set after the user refused the notification dialog in this process; the next refusal counts as permanent. */
  private static notificationRefused: boolean = false;

  /**
   * Notification permission (used by SMS login / register before fetching the SMS code).
   * Already enabled -> true. Otherwise shows the system enable dialog; a refusal toasts "通知权限获取失败";
   * a refusal after an earlier refusal in this process toasts "通知权限被永久拒绝，请手动授予" and opens the
   * app notification settings page (XXPermissions.startPermissionActivity equivalent).
   */
  static requestNotificationPermission(ctx: common.UIAbilityContext | undefined | null,
    callback: PermissionCallback): void {
    if (ctx === undefined || ctx === null) {
      ToastUtils.showError(NO_CONTEXT_MSG);
      callback(false);
      return;
    }
    const uiCtx: common.UIAbilityContext = ctx;
    notificationManager.isNotificationEnabled().then((enabled: boolean) => {
      if (enabled) {
        callback(true);
        return;
      }
      notificationManager.requestEnableNotification(uiCtx).then(() => {
        return notificationManager.isNotificationEnabled();
      }).then((nowEnabled: boolean) => {
        if (nowEnabled) {
          PermissionUtils.notificationRefused = false;
          callback(true);
        } else {
          PermissionUtils.onNotificationRefused(uiCtx, callback);
        }
      }).catch((e: BusinessError) => {
        LogUtils.wTag(TAG, `requestEnableNotification: ${e.code} ${e.message}`);
        if (e.code === ERR_NOTIFICATION_DIALOG_SHOWING) {
          // A dialog is already on screen; the user's answer is handled by that request.
          callback(false);
          return;
        }
        PermissionUtils.onNotificationRefused(uiCtx, callback);
      });
    }).catch((e: BusinessError) => {
      LogUtils.wTag(TAG, `isNotificationEnabled: ${e.code} ${e.message}`);
      ToastUtils.showError(NAME_NOTIFICATION + SUFFIX_FAILED);
      callback(false);
    });
  }

  static requestCameraPermission(ctx: common.UIAbilityContext | undefined | null, callback: PermissionCallback): void {
    PermissionUtils.requestCustomPermissions(ctx, [PERMISSION_CAMERA], NAME_CAMERA, callback);
  }

  static requestAudioPermission(ctx: common.UIAbilityContext | undefined | null, callback: PermissionCallback): void {
    PermissionUtils.requestCustomPermissions(ctx, [PERMISSION_MICROPHONE], NAME_AUDIO, callback);
  }

  static requestLocationPermission(ctx: common.UIAbilityContext | undefined | null,
    callback: PermissionCallback): void {
    PermissionUtils.requestCustomPermissions(ctx, [PERMISSION_APPROXIMATELY_LOCATION, PERMISSION_LOCATION],
      NAME_LOCATION, callback);
  }

  /**
   * Gallery / storage: HarmonyOS apps read photos through PhotoViewPicker and write via save pickers,
   * which need no runtime permission, so these grant immediately.
   */
  static requestGalleryPermission(ctx: common.UIAbilityContext | undefined | null, callback: PermissionCallback): void {
    LogUtils.dTag(TAG, `${NAME_GALLERY}: picker-based, no runtime permission needed`);
    callback(true);
  }

  static requestStoragePermission(ctx: common.UIAbilityContext | undefined | null, callback: PermissionCallback): void {
    LogUtils.dTag(TAG, `${NAME_STORAGE}: picker-based, no runtime permission needed`);
    callback(true);
  }

  /** Camera + gallery: only the camera needs a runtime permission on HarmonyOS. */
  static requestCameraAndGalleryPermission(ctx: common.UIAbilityContext | undefined | null,
    callback: PermissionCallback): void {
    PermissionUtils.requestCustomPermissions(ctx, [PERMISSION_CAMERA], NAME_CAMERA_GALLERY, callback);
  }

  /**
   * Request arbitrary runtime permissions (each must be declared in module.json5 requestPermissions).
   */
  static requestCustomPermissions(ctx: common.UIAbilityContext | undefined | null, permissions: Permissions[],
    permissionName: string, callback: PermissionCallback): void {
    if (ctx === undefined || ctx === null) {
      ToastUtils.showError(NO_CONTEXT_MSG);
      callback(false);
      return;
    }
    const uiCtx: common.UIAbilityContext = ctx;
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(uiCtx, permissions).then((result: PermissionRequestResult) => {
      let allGranted: boolean = true;
      let permanentlyDenied: boolean = false;
      for (let i = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          allGranted = false;
          const shown: boolean[] | undefined = result.dialogShownResults;
          if (shown !== undefined && i < shown.length && !shown[i]) {
            permanentlyDenied = true;
          }
        }
      }
      if (allGranted) {
        callback(true);
        return;
      }
      if (permanentlyDenied) {
        ToastUtils.showError(permissionName + SUFFIX_PERMANENT);
        PermissionUtils.openPermissionSettings(uiCtx, permissions);
      } else {
        ToastUtils.showError(permissionName + SUFFIX_FAILED);
      }
      callback(false);
    }).catch((e: BusinessError) => {
      LogUtils.wTag(TAG, `requestPermissionsFromUser: ${e.code} ${e.message}`);
      ToastUtils.showError(permissionName + SUFFIX_FAILED);
      callback(false);
    });
  }

  /** Synchronous grant check for the current app. */
  static hasPermission(permission: Permissions): boolean {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      return atManager.checkAccessTokenSync(info.appInfo.accessTokenId, permission) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      LogUtils.wTag(TAG, `hasPermission failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  static hasPermissions(permissions: Permissions[]): boolean {
    return permissions.every((p: Permissions) => PermissionUtils.hasPermission(p));
  }

  /**
   * Open the system permission settings for the given permissions (re-grant dialog);
   * with none given, open the app's notification settings page.
   */
  static openPermissionSettings(ctx: common.UIAbilityContext, permissions?: Permissions[]): void {
    if (permissions !== undefined && permissions.length > 0) {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionOnSetting(ctx, permissions).then(() => {
        LogUtils.dTag(TAG, 'requestPermissionOnSetting done');
      }).catch((e: BusinessError) => {
        LogUtils.wTag(TAG, `requestPermissionOnSetting: ${e.code} ${e.message}`);
      });
      return;
    }
    PermissionUtils.openNotificationSettings(ctx);
  }

  static openNotificationSettings(ctx: common.UIAbilityContext): void {
    notificationManager.openNotificationSettings(ctx).then(() => {
      LogUtils.dTag(TAG, 'openNotificationSettings done');
    }).catch((e: BusinessError) => {
      LogUtils.wTag(TAG, `openNotificationSettings: ${e.code} ${e.message}`);
    });
  }

  private static onNotificationRefused(ctx: common.UIAbilityContext, callback: PermissionCallback): void {
    if (PermissionUtils.notificationRefused) {
      ToastUtils.showError(NAME_NOTIFICATION + SUFFIX_PERMANENT);
      PermissionUtils.openNotificationSettings(ctx);
    } else {
      PermissionUtils.notificationRefused = true;
      ToastUtils.showError(NAME_NOTIFICATION + SUFFIX_FAILED);
    }
    callback(false);
  }
}
