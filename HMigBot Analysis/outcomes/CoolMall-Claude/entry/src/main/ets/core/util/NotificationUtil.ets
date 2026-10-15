/**
 * NotificationUtil (source: core/util/notification/NotificationUtil.kt) — DATA-A21 / AUTH-A22.
 * Android channels map to HarmonyOS slots:
 *   default_channel ("默认通知", IMPORTANCE_DEFAULT)        -> SlotType.OTHER_TYPES
 *   verification_code_channel ("验证码通知", IMPORTANCE_HIGH) -> SlotType.SOCIAL_COMMUNICATION (high reminder)
 * Verification notification: title "验证码", text "您的验证码是: " + code, auto-cancel on tap.
 */
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtils } from './LogUtils';

const TAG: string = 'NotificationUtil';
const VERIFICATION_TITLE: string = '验证码';
const VERIFICATION_TEXT_PREFIX: string = '您的验证码是: ';

export class NotificationUtil {
  /** Source: initNotificationChannels(context). Creates both slots; failures are logged only. */
  static async initNotificationChannels(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.OTHER_TYPES);
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
    } catch (e) {
      LogUtils.wTag(TAG, `addSlot failed: ${JSON.stringify(e)}`);
    }
  }

  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (e) {
      LogUtils.wTag(TAG, `isNotificationEnabled failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * Ask the user to enable notifications (system dialog). Resolves true when enabled.
   * Rejects nothing: errors (1600004 user denied, 1600013 dialog already shown, ...) resolve false.
   */
  static async requestEnable(ctx: common.UIAbilityContext): Promise<boolean> {
    if (await NotificationUtil.isEnabled()) {
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(ctx);
      return await NotificationUtil.isEnabled();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      LogUtils.wTag(TAG, `requestEnableNotification failed: ${err.code} ${err.message}`);
      return false;
    }
  }

  /** Source: sendNotification(context, title, content, ...). Returns the notification id (-1 on failure). */
  static async sendNotification(title: string, content: string): Promise<number> {
    return NotificationUtil.publish(title, content, notificationManager.SlotType.OTHER_TYPES);
  }

  /** Source: sendVerificationCodeNotification(context, code). Returns the notification id (-1 on failure). */
  static async sendVerificationCodeNotification(code: string): Promise<number> {
    return NotificationUtil.publish(VERIFICATION_TITLE, VERIFICATION_TEXT_PREFIX + code,
      notificationManager.SlotType.SOCIAL_COMMUNICATION);
  }

  /** Work-card alias of sendVerificationCodeNotification. */
  static async showVerificationCode(code: string): Promise<number> {
    return NotificationUtil.sendVerificationCodeNotification(code);
  }

  static async cancelNotification(notificationId: number): Promise<void> {
    try {
      await notificationManager.cancel(notificationId);
    } catch (e) {
      LogUtils.wTag(TAG, `cancel failed: ${JSON.stringify(e)}`);
    }
  }

  static async cancelAllNotifications(): Promise<void> {
    try {
      await notificationManager.cancelAll();
    } catch (e) {
      LogUtils.wTag(TAG, `cancelAll failed: ${JSON.stringify(e)}`);
    }
  }

  private static async publish(title: string, text: string,
    slotType: notificationManager.SlotType): Promise<number> {
    // Source: System.currentTimeMillis().toInt() — keep within int32 range.
    const notificationId: number = Date.now() % 2147483647;
    try {
      await notificationManager.addSlot(slotType);
    } catch (e) {
      LogUtils.wTag(TAG, `addSlot failed: ${JSON.stringify(e)}`);
    }
    const request: notificationManager.NotificationRequest = {
      id: notificationId,
      notificationSlotType: slotType,
      tapDismissed: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: text
        }
      }
    };
    try {
      await notificationManager.publish(request);
      return notificationId;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      LogUtils.wTag(TAG, `publish failed: ${err.code} ${err.message}`);
      return -1;
    }
  }
}
