/*
 * SettingsActions — Settings 页的对话框流程与外部跳转。
 * 源：ui/compose/settings/Settings.kt
 *   - :1268 NotificationsSetting（POST_NOTIFICATIONS 权限 + ExplainPermissionDialog + FeedNotificationsDialog）
 *   - :525 ListDialogSetting(Filters) → dialog/EditableListDialog.kt
 *   - :644 Battery optimization → Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
 *   - :936 Send bug report → util/BugReport.kt openGithubIssues()，ActivityLauncher.startActivity(openAdjacentIfSuitable=true)
 */
import { common, Want } from '@kit.AbilityKit';
import { ActivityLauncher } from '../../core/platform/LinkOpener';
import { GITHUB_ISSUES_URL } from '../../core/util/Constants';
import {
  EditableListDialogModel, FeedNotificationItem, FeedNotificationsDialogModel, openEditableListDialog,
  openFeedNotificationsDialog
} from '../../ui/common/Dialogs';
import { NotificationPermissionFlow, openExplainPermissionDialog } from '../../ui/common/FeedItemDialogs';
import { SettingsViewModel } from './SettingsViewModel';
import { sortedStrings, UIFeedSettings } from './SettingsOptions';

const LOG_TAG: string = 'FEEDER_SETTINGS_ACTIONS';
const SETTINGS_BUNDLE: string = 'com.huawei.hmos.settings';
const SETTINGS_ABILITY: string = 'com.huawei.hmos.settings.MainAbility';
/** 设置应用"应用信息"页（含耗电/后台活动管理），pushParams = 本应用包名 */
const SETTINGS_APP_INFO_URI: string = 'application_info_entry';

/** 源 ExplainPermissionDialog 是否需要（shouldShowRationale）：本进程内系统授权弹窗已被拒绝过一次 */
let notificationRequestDenied: boolean = false;

export function toNotificationItems(items: UIFeedSettings[]): FeedNotificationItem[] {
  return items.map((f: UIFeedSettings) => FeedNotificationItem.of(f.feedId, f.feedTitle, f.notify));
}

/**
 * Settings 页的对话框控制器：持有已打开对话框的 model，以便存储变化（DB 通知）时刷新其列表。
 */
@ObservedV2
export class SettingsDialogsController {
  /** 源 permissionDenied（PermissionStatus.Denied）→ 副标题显示权限说明（ST-A09） */
  @Trace notificationPermissionDenied: boolean = false;
  private filtersModel: EditableListDialogModel | null = null;
  private notificationsModel: FeedNotificationsDialogModel | null = null;

  /** 页面显示 / 回到前台时刷新通知授权状态 */
  refreshNotificationPermission(): void {
    NotificationPermissionFlow.isEnabled().then((enabled: boolean) => {
      this.notificationPermissionDenied = !enabled;
    }).catch((e: Error) => {
      console.warn(`${LOG_TAG}: notification permission query failed ${e?.message}`);
    });
  }

  // ---------------------------------------------------------------- Block list（ST-A14）

  openFilters(ui: UIContext, vm: SettingsViewModel): void {
    const model = new EditableListDialogModel();
    model.titleText = $r('app.string.filters');
    model.descriptionText = $r('app.string.block_list_description');
    model.exampleText = 'feeder feed?r fe*er';
    model.items = sortedStrings(vm.viewState.blockList);
    model.onAddItem = (value: string) => {
      vm.addToBlockList(value);
    };
    model.onRemoveItem = (value: string) => {
      vm.removeFromBlockList(value);
    };
    model.onDismiss = () => {
      this.filtersModel = null;
    };
    this.filtersModel = model;
    openEditableListDialog(ui, model);
  }

  /** 屏蔽词存储变化 → 已打开的 Filters 对话框列表同步 */
  onBlockListChanged(blockList: string[]): void {
    const m = this.filtersModel;
    if (m !== null && !m.handle.isClosed()) {
      m.items = sortedStrings(blockList);
    }
  }

  // ---------------------------------------------------------------- Notify for new items（ST-A10/A11）

  /**
   * 源 NotificationsSetting.clickable：
   *  已授权 → 打开订阅通知对话框；
   *  未授权且需解释（已被拒过） → ExplainPermissionDialog，`OK` → 再次请求授权；
   *  未授权且无需解释 → 直接发起系统授权；授权结果 granted → 自动打开对话框（expanded = granted）。
   */
  onNotificationsClick(ui: UIContext, vm: SettingsViewModel): void {
    NotificationPermissionFlow.isEnabled().then((enabled: boolean) => {
      this.notificationPermissionDenied = !enabled;
      if (enabled) {
        this.openNotifications(ui, vm);
        return;
      }
      if (notificationRequestDenied) {
        openExplainPermissionDialog(ui, $r('app.string.explanation_permission_notifications'), () => {
          this.requestPermission(ui, vm);
        }, () => {
          console.debug(`${LOG_TAG}: permission explanation dismissed`);
        });
      } else {
        this.requestPermission(ui, vm);
      }
    }).catch((e: Error) => {
      console.warn(`${LOG_TAG}: notifications click failed ${e?.message}`);
    });
  }

  private requestPermission(ui: UIContext, vm: SettingsViewModel): void {
    NotificationPermissionFlow.requestSystemPermission(ui).then((granted: boolean) => {
      this.notificationPermissionDenied = !granted;
      if (granted) {
        notificationRequestDenied = false;
        this.openNotifications(ui, vm);
      } else {
        notificationRequestDenied = true;
      }
    }).catch((e: Error) => {
      console.warn(`${LOG_TAG}: permission request failed ${e?.message}`);
    });
  }

  private openNotifications(ui: UIContext, vm: SettingsViewModel): void {
    const model = new FeedNotificationsDialogModel();
    model.titleText = $r('app.string.notify_for_new_items');
    model.items = toNotificationItems(vm.viewState.feedsSettings);
    model.onToggleItem = (feedId: number, notify: boolean) => {
      vm.toggleNotifications(feedId, notify);
      model.items = toNotificationItems(vm.viewState.feedsSettings);
    };
    model.onDismiss = () => {
      this.notificationsModel = null;
    };
    this.notificationsModel = model;
    openFeedNotificationsDialog(ui, model);
  }

  /** feeds 通知设置变化 → 已打开的对话框同步 */
  onFeedsSettingsChanged(items: UIFeedSettings[]): void {
    const m = this.notificationsModel;
    if (m !== null && !m.handle.isClosed()) {
      m.items = toNotificationItems(items);
    }
  }

  closeAll(): void {
    const f = this.filtersModel;
    if (f !== null) {
      f.handle.close();
    }
    const n = this.notificationsModel;
    if (n !== null) {
      n.handle.close();
    }
    this.filtersModel = null;
    this.notificationsModel = null;
  }
}

function hostContext(ui: UIContext): common.UIAbilityContext | null {
  try {
    const ctx = ui.getHostContext();
    return ctx !== undefined ? ctx as common.UIAbilityContext : null;
  } catch (e) {
    return null;
  }
}

/**
 * 源 Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)：鸿蒙无"忽略电池优化"列表页 →
 * 打开设置应用中本应用的应用信息页（耗电/后台活动管理入口）；失败回落设置首页。
 */
export async function openBatteryOptimizationSettings(ui: UIContext): Promise<boolean> {
  const ctx = hostContext(ui);
  if (ctx === null) {
    return false;
  }
  const appInfo: Want = {
    bundleName: SETTINGS_BUNDLE,
    abilityName: SETTINGS_ABILITY,
    uri: SETTINGS_APP_INFO_URI,
    parameters: { 'pushParams': ctx.abilityInfo.bundleName }
  };
  try {
    await ctx.startAbility(appInfo);
    return true;
  } catch (e) {
    console.warn(`${LOG_TAG}: open app info settings failed ${(e as Error)?.message}`);
  }
  const home: Want = { bundleName: SETTINGS_BUNDLE, abilityName: SETTINGS_ABILITY };
  try {
    await ctx.startAbility(home);
    return true;
  } catch (e) {
    console.error(`${LOG_TAG}: open settings failed ${(e as Error)?.message}`);
    return false;
  }
}

/**
 * ST-A40：外部浏览器打开 GitHub issues（openAdjacentIfSuitable = true）；
 * 无可处理应用 → Toast `Install something to open this link with first`（ActivityLauncher 内处理）。
 */
export async function sendBugReport(ui: UIContext): Promise<boolean> {
  let launcher: ActivityLauncher | null = ActivityLauncher.instance();
  if (launcher === null) {
    const ctx = hostContext(ui);
    if (ctx === null) {
      return false;
    }
    launcher = new ActivityLauncher(ctx, ui);
  }
  return launcher.openLinkInBrowser(GITHUB_ISSUES_URL, true);
}
