/*
 * Dialogs — 源 ui/compose/components/{ConfirmDialog,OkCancel,AutoCompleteText}.kt 与
 * ui/compose/dialog/{RenameTagDialog,EditableListDialog,FeedNotificationsDialog}.kt 的鸿蒙实现。
 * 弹窗统一 ComponentContent + UIContext.getPromptAction().openCustomDialog（禁 CustomDialogController）。
 * 点击外部/返回 → onWillDismiss → 等同 Cancel/onDismiss（UC-A29）。
 * 外观：M3 AlertDialog（surfaceContainerHigh 底、28vp 圆角、24vp 内边距、按钮右对齐）。
 */
import { ComponentContent, promptAction } from '@kit.ArkUI';
import { FeederTheme } from './Theme';
import { textStyle, M3Type, monoTextStyle, buttonLabelStyle, textInputStyle } from './Typography';
import { interceptKey, KEY_ENTER, KEY_ESCAPE } from './CommonWidgets';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

const TEXT_FIELD_MIN_HEIGHT: number = 56;
const MIN_TOUCH: number = 48;

/** 打开中的弹窗句柄：close() 幂等 */
export class DialogHandle {
  private closer: (() => void) | null = null;
  private closed: boolean = false;

  bind(closer: () => void): void {
    this.closer = closer;
  }

  isClosed(): boolean {
    return this.closed;
  }

  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    const c = this.closer;
    if (c !== null) {
      c();
    }
  }
}

function showContent<T extends Object>(ui: UIContext, node: ComponentContent<T>, handle: DialogHandle,
  onDismissRequest: () => void): void {
  const pa = ui.getPromptAction();
  handle.bind(() => {
    pa.closeCustomDialog(node).then(() => {
      node.dispose();
    }).catch((e: Error) => {
      console.error(`Dialogs: close failed: ${e?.message}`);
    });
  });
  const opts: promptAction.BaseDialogOptions = {
    autoCancel: true,
    alignment: DialogAlignment.Center,
    onWillDismiss: (action: DismissDialogAction) => {
      // 点外部 / 返回键 → 视为取消（源 onDismissRequest）
      console.debug(`Dialogs: dismiss request reason=${action.reason}`);
      onDismissRequest();
      handle.close();
    }
  };
  pa.openCustomDialog(node, opts).catch((e: Error) => {
    console.error(`Dialogs: open failed: ${e?.message}`);
  });
}

// ================================================================== ConfirmDialog（UC-A29）
@ObservedV2
export class ConfirmDialogArgs {
  @Trace titleText: ResourceStr = '';
  @Trace bodyText: ResourceStr = '';
  handle: DialogHandle = new DialogHandle();
  onOk: () => void = () => {
    console.info('TODO:onOk:ConfirmDialog');
  };
  onDismiss: () => void = () => {
    console.debug('ConfirmDialog: dismissed');
  };
}

@Builder
function confirmDialogBuilder(args: ConfirmDialogArgs) {
  ConfirmDialogView({ args: args })
}

@ComponentV2
export struct ConfirmDialogView {
  @Param args: ConfirmDialogArgs = new ConfirmDialogArgs();

  build() {
    Column({ space: 16 }) {
      Text(this.args.titleText)
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .textAlign(TextAlign.Center)
        .width('100%')
      Text(this.args.bodyText)
        .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurfaceVariant))
        .width('100%')
      Row({ space: 8 }) {
        Button($r('app.string.cancel'))
          .attributeModifier(buttonLabelStyle())
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.args.onDismiss();
            this.args.handle.close();
          })
        Button($r('app.string.hm_ok'))
          .attributeModifier(buttonLabelStyle())
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.args.onOk();
            this.args.handle.close();
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

/** 源 ConfirmDialog：OK → onOk 后关闭；Cancel/外部/返回 → onDismiss 后关闭 */
export function openConfirmDialog(ui: UIContext, titleText: ResourceStr, bodyText: ResourceStr,
  onOk: () => void, onDismiss: () => void): DialogHandle {
  const args = new ConfirmDialogArgs();
  args.titleText = titleText;
  args.bodyText = bodyText;
  args.onOk = onOk;
  args.onDismiss = onDismiss;
  showContent(ui, new ComponentContent<ConfirmDialogArgs>(ui, wrapBuilder(confirmDialogBuilder), args),
    args.handle, onDismiss);
  return args.handle;
}

// ================================================================== RenameTagDialog（UC-A30）
@ObservedV2
export class RenameTagDialogArgs {
  @Trace currentTagName: string = '';
  @Trace tagName: string = '';
  handle: DialogHandle = new DialogHandle();
  onRename: (newName: string) => void = (newName: string) => {
    console.info(`TODO:onRename:RenameTagDialog ${newName}`);
  };
  onDismiss: () => void = () => {
    console.debug('RenameTagDialog: dismissed');
  };

  okEnabled(): boolean {
    return this.tagName.trim().length > 0 && this.tagName !== this.currentTagName;
  }
}

@Builder
function renameTagDialogBuilder(args: RenameTagDialogArgs) {
  RenameTagDialogView({ args: args })
}

@ComponentV2
export struct RenameTagDialogView {
  @Param args: RenameTagDialogArgs = new RenameTagDialogArgs();

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.rename_tag'))
        .attributeModifier(textStyle(M3Type.headlineSmall, false, FeederTheme.colors.onSurface))
      TextInput({ text: this.args.tagName })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.args.tagName))
        .attributeModifier(textInputStyle())
        .width('100%')
        .maxLines(1)
        .fontColor(FeederTheme.colors.onSurface)
        .onChange((v: string) => {
          this.args.tagName = v;
        })
      Row({ space: 8 }) {
        Button($r('app.string.cancel'))
          .attributeModifier(buttonLabelStyle())
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.args.onDismiss();
            this.args.handle.close();
          })
        Button($r('app.string.hm_ok'))
          .attributeModifier(buttonLabelStyle())
          .enabled(this.args.okEnabled())
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            if (!this.args.okEnabled()) {
              return;
            }
            this.args.onRename(this.args.tagName);
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
    .constraintSize({ minWidth: 280, maxWidth: 560 })
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .borderRadius(28)
  }
}

/** 源 RenameTagDialog：输入框预填当前名；OK 仅非空白且不同于原名可用；OK → onRename 再关闭 */
export function openRenameTagDialog(ui: UIContext, currentTagName: string, onRename: (newName: string) => void,
  onDismiss: () => void): DialogHandle {
  const args = new RenameTagDialogArgs();
  args.currentTagName = currentTagName;
  args.tagName = currentTagName;
  args.onRename = onRename;
  args.onDismiss = onDismiss;
  showContent(ui, new ComponentContent<RenameTagDialogArgs>(ui, wrapBuilder(renameTagDialogBuilder), args),
    args.handle, onDismiss);
  return args.handle;
}

// ================================================================== EditableListDialog（UC-A31/A32）
@ObservedV2
export class EditableListDialogModel {
  @Trace titleText: ResourceStr = '';
  /** 标题下说明（源 Filters 对话框 block_list_description） */
  @Trace descriptionText: ResourceStr = '';
  /** 等宽示例行（源 "feeder feed?r fe*er"） */
  @Trace exampleText: string = '';
  /** 当前列表（调用方在存储变化后整体替换） */
  @Trace items: string[] = [];
  @Trace newValue: string = '';
  handle: DialogHandle = new DialogHandle();
  onAddItem: (value: string) => void = (value: string) => {
    console.info(`TODO:onAddItem:EditableListDialog ${value}`);
  };
  onRemoveItem: (value: string) => void = (value: string) => {
    console.info(`TODO:onRemoveItem:EditableListDialog ${value}`);
  };
  onDismiss: () => void = () => {
    console.debug('EditableListDialog: dismissed');
  };

  /** 源：不在组件内过滤空串（过滤在 SettingsStore.addBlocklistPattern），添加后清空输入 */
  submit(): void {
    this.onAddItem(this.newValue);
    this.newValue = '';
  }
}

@Builder
function editableListDialogBuilder(model: EditableListDialogModel) {
  EditableListDialogView({ model: model })
}

@ComponentV2
export struct EditableListDialogView {
  @Param model: EditableListDialogModel = new EditableListDialogModel();

  build() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text(this.model.titleText)
          .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        if (this.model.descriptionText !== '') {
          Text(this.model.descriptionText)
            .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurfaceVariant))
        }
        if (this.model.exampleText !== '') {
          Text(this.model.exampleText)
            .attributeModifier(monoTextStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      List() {
        ForEach(this.model.items, (item: string) => {
          ListItem() {
            Row() {
              Text(item)
                .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
                .layoutWeight(1)
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(24)
                  .fontColor([FeederTheme.colors.onSurfaceVariant])
              }
              .width(MIN_TOUCH)
              .height(MIN_TOUCH)
              .backgroundColor(Color.Transparent)
              .accessibilityText($r('app.string.remove'))
              .onClick(() => {
                this.model.onRemoveItem(item);
              })
            }
            .width('100%')
            .constraintSize({ minHeight: MIN_TOUCH })
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
          }
        }, (item: string) => item)
      }
      .width('100%')
      .constraintSize({ minHeight: TEXT_FIELD_MIN_HEIGHT * 3.3, maxHeight: 360 })

      TextInput({ placeholder: $r('app.string.add_item'), text: this.model.newValue })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.model.newValue))

        .attributeModifier(textInputStyle())
        .width('100%')
        .maxLines(1)
        .enterKeyType(EnterKeyType.Next)
        .fontColor(FeederTheme.colors.onSurface)
        .onChange((v: string) => {
          this.model.newValue = v;
        })
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
          // 软键盘"下一项"：添加并清空，保持键盘
          this.model.submit();
          event.keepEditableState();
        })
        .onKeyPreIme((event: KeyEvent) => {
          // 硬件 Enter（抬起触发一次）/ Esc 关闭（UC-A44 语义）
          if (interceptKey(event, KEY_ENTER, () => {
            this.model.submit();
          })) {
            return true;
          }
          return interceptKey(event, KEY_ESCAPE, () => {
            this.model.onDismiss();
            this.model.handle.close();
          });
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(24)
    .constraintSize({ minWidth: 280, maxWidth: 560, maxHeight: '80%' })
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .borderRadius(28)
  }
}

/** 源 EditableListDialog：无确认按钮，点击外部关闭；调用方保留 model 以便在列表变化后更新 model.items */
export function openEditableListDialog(ui: UIContext, model: EditableListDialogModel): DialogHandle {
  const onDismiss = (): void => {
    model.onDismiss();
  };
  showContent(ui, new ComponentContent<EditableListDialogModel>(ui, wrapBuilder(editableListDialogBuilder), model),
    model.handle, onDismiss);
  return model.handle;
}

// ================================================================== FeedNotificationsDialog（UC-A34）
/** 源 UIFeedSettings(feedId, title, notify) */
export class FeedNotificationItem {
  feedId: number = 0;
  itemTitle: string = '';
  notify: boolean = false;

  static of(feedId: number, itemTitle: string, notify: boolean): FeedNotificationItem {
    const i = new FeedNotificationItem();
    i.feedId = feedId;
    i.itemTitle = itemTitle;
    i.notify = notify;
    return i;
  }
}

@ObservedV2
export class FeedNotificationsDialogModel {
  @Trace titleText: ResourceStr = $r('app.string.notify_for_new_items');
  @Trace items: FeedNotificationItem[] = [];
  handle: DialogHandle = new DialogHandle();
  onToggleItem: (feedId: number, notify: boolean) => void = (feedId: number, notify: boolean) => {
    console.info(`TODO:onToggleItem:FeedNotificationsDialog ${feedId} ${notify}`);
  };
  onDismiss: () => void = () => {
    console.debug('FeedNotificationsDialog: dismissed');
  };
}

@Builder
function feedNotificationsDialogBuilder(model: FeedNotificationsDialogModel) {
  FeedNotificationsDialogView({ model: model })
}

@ComponentV2
export struct FeedNotificationsDialogView {
  @Param model: FeedNotificationsDialogModel = new FeedNotificationsDialogModel();

  build() {
    Column({ space: 16 }) {
      Text(this.model.titleText)
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
      List() {
        ForEach(this.model.items, (item: FeedNotificationItem) => {
          ListItem() {
            Row({ space: 16 }) {
              Text(item.itemTitle)
                .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: item.notify })
                .selectedColor(FeederTheme.colors.primary)
                .accessibilityLevel('no')
                .onChange((isOn: boolean) => {
                  if (isOn !== item.notify) {
                    this.model.onToggleItem(item.feedId, !item.notify);
                  }
                })
            }
            .width('100%')
            .constraintSize({ minHeight: 64 })
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
            .accessibilityRole(AccessibilityRoleType.SWITCH)
            .accessibilityStateDescription(item.notify ? $r('app.string.on') : $r('app.string.off'))
            .onClick(() => {
              this.model.onToggleItem(item.feedId, !item.notify);
            })
          }
        }, (item: FeedNotificationItem) => `${item.feedId}:${item.notify}:${item.itemTitle}`)
      }
      .width('100%')
      .constraintSize({ minHeight: TEXT_FIELD_MIN_HEIGHT * 3.3, maxHeight: 420 })

      Row() {
        Button($r('app.string.hm_ok'))
          .attributeModifier(buttonLabelStyle())
          .backgroundColor(FeederTheme.colors.primary)
          .fontColor(FeederTheme.colors.onPrimary)
          .onClick(() => {
            this.model.onDismiss();
            this.model.handle.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(24)
    .constraintSize({ minWidth: 280, maxWidth: 560, maxHeight: '80%' })
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .borderRadius(28)
  }
}

export function openFeedNotificationsDialog(ui: UIContext, model: FeedNotificationsDialogModel): DialogHandle {
  const onDismiss = (): void => {
    model.onDismiss();
  };
  showContent(ui,
    new ComponentContent<FeedNotificationsDialogModel>(ui, wrapBuilder(feedNotificationsDialogBuilder), model),
    model.handle, onDismiss);
  return model.handle;
}

// ================================================================== 单选对话框（设置项通用）
@ObservedV2
export class SingleChoiceDialogArgs {
  @Trace titleText: ResourceStr = '';
  @Trace options: ResourceStr[] = [];
  @Trace selectedIndex: number = -1;
  handle: DialogHandle = new DialogHandle();
  onSelect: (index: number) => void = (index: number) => {
    console.info(`TODO:onSelect:SingleChoiceDialog ${index}`);
  };
  onDismiss: () => void = () => {
    console.debug('SingleChoiceDialog: dismissed');
  };
}

@Builder
function singleChoiceDialogBuilder(args: SingleChoiceDialogArgs) {
  SingleChoiceDialogView({ args: args })
}

@ComponentV2
export struct SingleChoiceDialogView {
  @Param args: SingleChoiceDialogArgs = new SingleChoiceDialogArgs();

  build() {
    Column({ space: 16 }) {
      Text(this.args.titleText)
        .attributeModifier(textStyle(M3Type.headlineSmall, false, FeederTheme.colors.onSurface))
      List() {
        ForEach(this.args.options, (opt: ResourceStr, index: number) => {
          ListItem() {
            Row({ space: 16 }) {
              Radio({ value: `${index}`, group: 'feederSingleChoice' })
                .checked(index === this.args.selectedIndex)
                .hitTestBehavior(HitTestMode.None)
              Text(opt)
                .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
                .layoutWeight(1)
            }
            .width('100%')
            .constraintSize({ minHeight: MIN_TOUCH })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
            .accessibilityRole(AccessibilityRoleType.RADIO)
            .accessibilityChecked(index === this.args.selectedIndex)
            .onClick(() => {
              this.args.onSelect(index);
              this.args.handle.close();
            })
          }
        }, (opt: ResourceStr, index: number) => `${index}:${index === this.args.selectedIndex}`)
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(24)
    .constraintSize({ minWidth: 280, maxWidth: 560 })
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .borderRadius(28)
  }
}

export function openSingleChoiceDialog(ui: UIContext, titleText: ResourceStr, options: ResourceStr[],
  selectedIndex: number, onSelect: (index: number) => void, onDismiss: () => void): DialogHandle {
  const args = new SingleChoiceDialogArgs();
  args.titleText = titleText;
  args.options = options;
  args.selectedIndex = selectedIndex;
  args.onSelect = onSelect;
  args.onDismiss = onDismiss;
  showContent(ui, new ComponentContent<SingleChoiceDialogArgs>(ui, wrapBuilder(singleChoiceDialogBuilder), args),
    args.handle, onDismiss);
  return args.handle;
}

// ================================================================== 自动补全（UC-A36）
@Builder
function emptyInputBuilder() {
}

@Builder
function defaultSuggestionBuilder(item: string) {
  Text(item)
    .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
    .padding(12)
}

@ComponentV2
export struct AutoCompleteResults {
  @Param displaySuggestions: boolean = false;
  @Param suggestions: string[] = [];
  @Event onSuggestionClick: (item: string) => void = (item: string) => {
    console.info(`TODO:onSuggestionClick:AutoCompleteResults ${item}`);
  };
  @BuilderParam inputBuilder: () => void = emptyInputBuilder;
  @BuilderParam suggestionBuilder: (item: string) => void = defaultSuggestionBuilder;

  build() {
    Column() {
      this.inputBuilder()
      Column().height(4)
      if (this.displaySuggestions) {
        List() {
          ForEach(this.suggestions, (item: string) => {
            ListItem() {
              Stack({ alignContent: Alignment.TopStart }) {
                this.suggestionBuilder(item)
              }
              .onClick(() => {
                this.onSuggestionClick(item);
              })
            }
          }, (item: string) => item)
        }
        .width('90%')
        .constraintSize({ maxHeight: 56 * 3 })
        .border({ width: 2, color: FeederTheme.colors.onBackground, radius: 8 })
        .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
