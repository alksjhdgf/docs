/*
 * FeedItemDialogs — 源 ui/compose/feed/EditFeedDialog.kt 与 ui/compose/feed/ExplainPermissionDialog.kt，
 * 以及其调用方（FeedScreen.kt:892 工具栏“编辑”、Settings.kt:1284-1356 / EditFeedScreen.kt:160-243 通知开关）的权限流程。
 * 弹窗统一 ComponentContent + UIContext.getPromptAction().openCustomDialog（禁 CustomDialogController）。
 *
 *  - EditFeedDialog（FI-A39/A40）：标题 `Edit feed`；正文可滚动的订阅源列表（未选中单选按钮 + 32vp + displayTitle，行最小高 48vp），
 *    点行（或单选按钮）→ onEdit(id) 后关闭；仅 `Cancel` 按钮；点外部/返回仅关闭。
 *  - openEditFeedOrChooser（FI-A38）：可见订阅源恰为 1 个 → 直接 onEdit，否则弹选择对话框。
 *  - ExplainPermissionDialog（FI-A41/A42）：无标题，正文 `Permission must be granted before notifications can be enabled.`，
 *    唯一按钮 `OK` → onOk（发起系统通知授权）；点外部/返回 → onDismiss（不请求）。
 *  - NotificationPermissionFlow（FI-A43）：notificationManager.isNotificationEnabled() 已开 → 直接生效；
 *    未开 → 先弹说明对话框（鸿蒙无 shouldShowRationale，统一“未授权即先说明”），OK 后 requestEnableNotification()，
 *    再查一次是否已开启决定 onGranted / onDenied。
 */
import { ComponentContent, promptAction } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { FeederTheme } from './Theme';
import { textStyle, M3Type } from './Typography';
import { DialogHandle } from './Dialogs';
import { MINIMUM_TOUCH_SIZE } from './FeedItemText';

const LOG_TAG: string = 'FeedItemDialogs';

/** 源 DeletableFeed(id, title)：EditFeedDialog 的行数据（title = feed.displayTitle） */
export class DeletableFeed {
  id: number = 0;
  title: string = '';

  static of(id: number, title: string): DeletableFeed {
    const f = new DeletableFeed();
    f.id = id;
    f.title = title;
    return f;
  }
}

function showDialogContent<T extends Object>(ui: UIContext, node: ComponentContent<T>, handle: DialogHandle,
  onDismissRequest: () => void): void {
  const pa = ui.getPromptAction();
  handle.bind(() => {
    pa.closeCustomDialog(node).then(() => {
      node.dispose();
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: close failed: ${e?.message}`);
    });
  });
  const opts: promptAction.BaseDialogOptions = {
    autoCancel: true,
    alignment: DialogAlignment.Center,
    onWillDismiss: (action: DismissDialogAction) => {
      // 点外部 / 返回键 → 源 onDismissRequest
      console.debug(`${LOG_TAG}: dismiss request reason=${action.reason}`);
      onDismissRequest();
      handle.close();
    }
  };
  pa.openCustomDialog(node, opts).catch((e: Error) => {
    console.error(`${LOG_TAG}: open failed: ${e?.message}`);
  });
}

// ================================================================== EditFeedDialog

@ObservedV2
export class EditFeedDialogArgs {
  @Trace feeds: DeletableFeed[] = [];
  handle: DialogHandle = new DialogHandle();
  onEdit: (feedId: number) => void = (feedId: number) => {
    console.info(`TODO:onEdit:EditFeedDialog ${feedId}`);
  };
  onDismiss: () => void = () => {
    console.debug('EditFeedDialog: dismissed');
  };
}

@Builder
function editFeedDialogBuilder(args: EditFeedDialogArgs) {
  EditFeedDialogView({ args: args })
}

@ComponentV2
export struct EditFeedDialogView {
  @Param args: EditFeedDialogArgs = new EditFeedDialogArgs();

  private pick(feedId: number): void {
    this.args.onEdit(feedId);
    this.args.onDismiss();
    this.args.handle.close();
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.edit_feed'))
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .textAlign(TextAlign.Center)
        .padding({ top: 8, bottom: 8 })
        .width('100%')
      List() {
        ForEach(this.args.feeds, (feed: DeletableFeed) => {
          ListItem() {
            Row() {
              // 源 RadioButton(selected = false)，语义清空；点它与点行同效 → 交给行处理
              Radio({ value: `${feed.id}`, group: 'feederEditFeedDialog' })
                .checked(false)
                .hitTestBehavior(HitTestMode.None)
                .accessibilityLevel('no')
              Column()
                .width(32)
                .height(1)
              Text(feed.title)
                .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
            }
            .width('100%')
            .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
            .onClick(() => {
              this.pick(feed.id);
            })
          }
        }, (feed: DeletableFeed) => `${feed.id}:${feed.title}`)
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .edgeEffect(EdgeEffect.None)

      Row() {
        Button($r('app.string.cancel'))
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.args.onDismiss();
            this.args.handle.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(24)
    .constraintSize({ minWidth: 280, maxWidth: 560, maxHeight: 560 })
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .borderRadius(28)
  }
}

/** 打开订阅源选择对话框（源 EditFeedDialog） */
export function openEditFeedDialog(ui: UIContext, feeds: DeletableFeed[], onEdit: (feedId: number) => void,
  onDismiss: () => void): DialogHandle {
  const args = new EditFeedDialogArgs();
  args.feeds = feeds;
  args.onEdit = onEdit;
  args.onDismiss = onDismiss;
  showDialogContent(ui, new ComponentContent<EditFeedDialogArgs>(ui, wrapBuilder(editFeedDialogBuilder), args),
    args.handle, onDismiss);
  return args.handle;
}

/**
 * 源 FeedScreen.kt:892 工具栏“编辑”项：可见订阅源恰为 1 个 → 直接进入该源 EditFeed，否则弹选择对话框。
 * 返回打开的对话框句柄（直接跳转时为 null）。
 */
export function openEditFeedOrChooser(ui: UIContext, visibleFeeds: DeletableFeed[],
  onEdit: (feedId: number) => void): DialogHandle | null {
  if (visibleFeeds.length === 1) {
    onEdit(visibleFeeds[0].id);
    return null;
  }
  return openEditFeedDialog(ui, visibleFeeds, onEdit, () => {
    console.debug('EditFeedDialog: closed');
  });
}

// ================================================================== ExplainPermissionDialog

@ObservedV2
export class ExplainPermissionDialogArgs {
  @Trace explanation: ResourceStr = '';
  handle: DialogHandle = new DialogHandle();
  onOk: () => void = () => {
    console.info('TODO:onOk:ExplainPermissionDialog');
  };
  onDismiss: () => void = () => {
    console.debug('ExplainPermissionDialog: dismissed');
  };
}

@Builder
function explainPermissionDialogBuilder(args: ExplainPermissionDialogArgs) {
  ExplainPermissionDialogView({ args: args })
}

@ComponentV2
export struct ExplainPermissionDialogView {
  @Param args: ExplainPermissionDialogArgs = new ExplainPermissionDialogArgs();

  build() {
    Column({ space: 16 }) {
      Text(this.args.explanation)
        .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurfaceVariant))
        .padding({ top: 8, bottom: 8 })
        .width('100%')
        .textAlign(TextAlign.Start)
      Row() {
        Button($r('app.string.hm_ok'))
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.args.handle.close();
            this.args.onOk();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(24)
    .constraintSize({ minWidth: 280, maxWidth: 560 })
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .borderRadius(28)
  }
}

/** 源 ExplainPermissionDialog(explanation, onDismiss, onOk) */
export function openExplainPermissionDialog(ui: UIContext, explanation: ResourceStr, onOk: () => void,
  onDismiss: () => void): DialogHandle {
  const args = new ExplainPermissionDialogArgs();
  args.explanation = explanation;
  args.onOk = onOk;
  args.onDismiss = onDismiss;
  showDialogContent(ui,
    new ComponentContent<ExplainPermissionDialogArgs>(ui, wrapBuilder(explainPermissionDialogBuilder), args),
    args.handle, onDismiss);
  return args.handle;
}

// ================================================================== 通知权限流程（FI-A43）

export class NotificationPermissionFlow {
  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (e) {
      console.warn(`${LOG_TAG}: isNotificationEnabled failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /** 发起系统通知授权（源 launchPermissionRequest），返回之后是否已开启 */
  static async requestSystemPermission(ui: UIContext): Promise<boolean> {
    try {
      const ctx = ui.getHostContext() as common.UIAbilityContext;
      await notificationManager.requestEnableNotification(ctx);
    } catch (e) {
      // 用户拒绝 / 已弹过不再弹 → 以实际开关状态为准
      console.info(`${LOG_TAG}: requestEnableNotification: ${JSON.stringify(e)}`);
    }
    return await NotificationPermissionFlow.isEnabled();
  }

  /**
   * 打开通知开关时调用：已授权 → onGranted()（EditFeed 开关置开 / Settings 展开通知选择）；
   * 未授权 → 说明对话框，OK → 系统授权 → 授权成功 onGranted()，否则 onDenied()；点外部/返回仅关闭（不请求、不回调）。
   */
  static ensureEnabled(ui: UIContext, onGranted: () => void, onDenied: () => void): void {
    NotificationPermissionFlow.isEnabled().then((enabled: boolean) => {
      if (enabled) {
        onGranted();
        return;
      }
      openExplainPermissionDialog(ui, $r('app.string.explanation_permission_notifications'), () => {
        NotificationPermissionFlow.requestSystemPermission(ui).then((granted: boolean) => {
          if (granted) {
            onGranted();
          } else {
            onDenied();
          }
        });
      }, () => {
        console.debug(`${LOG_TAG}: permission explanation dismissed`);
      });
    });
  }
}
