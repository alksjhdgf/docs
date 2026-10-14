/**
 * FeedDialogs — 源 ui/compose/deletefeed/DeleteFeedScreen.kt（DeleteFeedDialog，FD-A25）。
 * ComponentContent + UIContext.getPromptAction().openCustomDialog（禁 CustomDialogController）。
 *  - 标题 `Delete feed` + 右侧 `Open menu` 溢出菜单（唯一项“全选/全不选”勾选框）；
 *  - 正文：可滚动订阅源列表，每行勾选框 + displayTitle，点行翻转；
 *  - `OK` → onDelete(勾选的 id) 后关闭；`Cancel` / 点外部 / 返回 → 仅关闭。
 * 编辑对话框与改名对话框复用 ui/common（openEditFeedOrChooser / openRenameTagDialog）。
 */
import { ComponentContent, promptAction } from '@kit.ArkUI';
import { DialogHandle } from '../../ui/common/Dialogs';
import { DeletableFeed } from '../../ui/common/FeedItemDialogs';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { MINIMUM_TOUCH_SIZE } from '../../ui/common/FeedItemText';

const LOG_TAG: string = 'FEEDER_FEEDDIALOGS';

@ObservedV2
export class DeleteFeedDialogArgs {
  @Trace feeds: DeletableFeed[] = [];
  /** 源 feedsToDelete: Map<Long, Boolean>（以选中 id 数组表示） */
  @Trace checkedIds: number[] = [];
  @Trace menuExpanded: boolean = false;
  handle: DialogHandle = new DialogHandle();
  onDelete: (feedIds: number[]) => void = (feedIds: number[]) => {
    console.info(`TODO:onDelete:DeleteFeedDialog ${feedIds.length}`);
  };
  onDismiss: () => void = () => {
    console.debug(`${LOG_TAG}: delete dialog dismissed`);
  };

  isChecked(feedId: number): boolean {
    return this.checkedIds.indexOf(feedId) >= 0;
  }

  /** 源 selectAllSelected = feeds.all { checked } */
  get selectAllSelected(): boolean {
    for (const f of this.feeds) {
      if (!this.isChecked(f.id)) {
        return false;
      }
    }
    return true;
  }

  toggle(feedId: number): void {
    const next: number[] = this.checkedIds.slice();
    const i: number = next.indexOf(feedId);
    if (i >= 0) {
      next.splice(i, 1);
    } else {
      next.push(feedId);
    }
    this.checkedIds = next;
  }

  selectAll(checked: boolean): void {
    this.checkedIds = checked ? this.feeds.map((f: DeletableFeed): number => f.id) : [];
  }
}

@Builder
function deleteFeedDialogBuilder(args: DeleteFeedDialogArgs) {
  DeleteFeedDialogView({ args: args })
}

@ComponentV2
export struct DeleteFeedDialogView {
  @Param args: DeleteFeedDialogArgs = new DeleteFeedDialogArgs();

  private dismiss(): void {
    this.args.onDismiss();
    this.args.handle.close();
  }

  @Builder
  selectAllMenu() {
    Column() {
      Row() {
        Checkbox({ name: 'feederDeleteSelectAll', group: 'feederDeleteSelectAllGroup' })
          .select(this.args.selectAllSelected)
          .hitTestBehavior(HitTestMode.None)
          .accessibilityLevel('no')
        Text($r('sys.string.text_overlay_menu_select_all'))
          .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
          .margin({ left: 4 })
      }
      .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE, minWidth: 112 })
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .accessibilityGroup(true)
      .onClick(() => {
        this.args.selectAll(!this.args.selectAllSelected);
        this.args.menuExpanded = false;
      })
    }
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 16 }) {
      Stack({ alignContent: Alignment.Start }) {
        Text($r('app.string.delete_feed'))
          .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
        Row() {
          Blank()
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.dot_grid_1x2'))
              .fontSize(24)
              .fontColor([FeederTheme.colors.onSurfaceVariant])
          }
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.open_menu'))
          .onClick(() => {
            this.args.menuExpanded = true;
          })
          .bindMenu(this.args.menuExpanded, this.selectAllMenu, {
            onDisappear: () => {
              this.args.menuExpanded = false;
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')

      List() {
        ForEach(this.args.feeds, (feed: DeletableFeed) => {
          ListItem() {
            Row() {
              Checkbox({ name: `feederDelete${feed.id}`, group: 'feederDeleteFeeds' })
                .select(this.args.isChecked(feed.id))
                .hitTestBehavior(HitTestMode.None)
                .accessibilityLevel('no')
              Text(feed.title)
                .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
                .margin({ left: 32 })
            }
            .width('100%')
            .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
            .accessibilityChecked(this.args.isChecked(feed.id))
            .onClick(() => {
              this.args.toggle(feed.id);
            })
          }
        }, (feed: DeletableFeed) => `${feed.id}:${feed.title}`)
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .edgeEffect(EdgeEffect.None)

      Row({ space: 8 }) {
        Button($r('app.string.cancel'))
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.dismiss();
          })
        Button($r('app.string.hm_ok'))
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.args.onDelete(this.args.checkedIds.slice());
            this.dismiss();
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

/** 打开删除订阅源对话框（源 DeleteFeedDialog(feeds, onDismiss, onDelete)） */
export function openDeleteFeedDialog(ui: UIContext, feeds: DeletableFeed[], onDelete: (feedIds: number[]) => void,
  onDismiss: () => void): DialogHandle {
  const args: DeleteFeedDialogArgs = new DeleteFeedDialogArgs();
  args.feeds = feeds;
  args.onDelete = onDelete;
  args.onDismiss = onDismiss;
  const node: ComponentContent<DeleteFeedDialogArgs> =
    new ComponentContent<DeleteFeedDialogArgs>(ui, wrapBuilder(deleteFeedDialogBuilder), args);
  const pa = ui.getPromptAction();
  args.handle.bind(() => {
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
      console.debug(`${LOG_TAG}: dismiss request reason=${action.reason}`);
      onDismiss();
      args.handle.close();
    }
  };
  pa.openCustomDialog(node, opts).catch((e: Error) => {
    console.error(`${LOG_TAG}: open failed: ${e?.message}`);
  });
  return args.handle;
}
