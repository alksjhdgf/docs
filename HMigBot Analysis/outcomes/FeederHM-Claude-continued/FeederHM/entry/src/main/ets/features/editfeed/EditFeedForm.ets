/**
 * EditFeedForm —— 源 ui/compose/editfeed/EditFeedScreen.kt 的 EditFeedView / LeftContent / RightContent / RulesField，
 * 以及 EditFeedScreen 中通知开关的权限包装（screenState.notify setter + ExplainPermissionDialog）。
 *
 * 布局（EF-A25/A37）：OkCancelWithContent(可滚动) ← 横向 margin；
 *  - ScreenType.DUAL：Row(maxContentWidth){ 左 Column(URL/Title/Tag) | 右 Column(开关/打开方式/规则) }，两列各 weight 1、
 *    padding(horizontal=margin, vertical=8)、spacedBy(8)；
 *  - SINGLE：Column(spacedBy 8, maxContentWidth){ 左; HorizontalDivider; 右 }。
 * 焦点（EF-A27/A28）：URL/Title 的 Next(回车) → 下一字段；Tag 的 Done(回车) → 收起候选/键盘，焦点移到第一个开关；
 * Tag 框所在焦点组有焦点时显示候选；点候选 → 填入、关闭候选、焦点移到第一个开关。
 */
import { ScreenType } from '../../core/platform/LayoutAdapt';
import { PREF_VAL_OPEN_WITH_BROWSER, PREF_VAL_OPEN_WITH_CUSTOM_TAB,
  PREF_VAL_OPEN_WITH_READER } from '../../core/settings/SettingsKeys';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { NotificationPermissionFlow, openExplainPermissionDialog } from '../../ui/common/FeedItemDialogs';
import { EditFeedViewModel } from './EditFeedViewModel';
import { FormRadioRow, FormSwitchRow, RulesFieldView } from './EditFeedFormRows';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

const LOG_TAG: string = 'EditFeedForm';

const KEY_URL: string = 'editFeedUrl';
const KEY_TITLE: string = 'editFeedTitle';
const KEY_TAG: string = 'editFeedTag';
const KEY_FIRST_SWITCH: string = 'editFeedFirstSwitch';

/** 源 PermissionStatus.shouldShowRationale 的近似：本进程内被拒绝过一次后，下次先弹说明对话框 */
let notificationRationaleNeeded: boolean = false;

// ====================================================================== 表单主体

@ComponentV2
export struct EditFeedForm {
  @Param vm: EditFeedViewModel = new EditFeedViewModel();
  @Param screenType: ScreenType = ScreenType.SINGLE;
  /** 导航条避让（vp） */
  @Param bottomInset: number = 0;
  @Event onOk: () => void = () => {
    console.info('TODO:onOk:EditFeedForm');
  };
  @Event onCancel: () => void = () => {
    console.info('TODO:onCancel:EditFeedForm');
  };
  @Local showTagSuggestions: boolean = false;

  private focusOn(key: string): void {
    try {
      this.getUIContext().getFocusController().requestFocus(key);
    } catch (e) {
      console.warn(`${LOG_TAG}: requestFocus(${key}) failed: ${JSON.stringify(e)}`);
    }
  }

  // ------------------------------------------------------------ 通知开关权限包装（EF-A33）
  private onNotifyToggle(value: boolean): void {
    if (!value) {
      this.vm.setNotify(false);
      return;
    }
    NotificationPermissionFlow.isEnabled().then((enabled: boolean) => {
      if (enabled) {
        this.vm.setNotify(true);
        return;
      }
      if (notificationRationaleNeeded) {
        openExplainPermissionDialog(this.getUIContext(), $r('app.string.explanation_permission_notifications'),
          () => {
            this.launchNotificationRequest();
          }, () => {
            console.debug(`${LOG_TAG}: permission explanation dismissed`);
          });
      } else {
        this.launchNotificationRequest();
      }
    });
  }

  private launchNotificationRequest(): void {
    NotificationPermissionFlow.requestSystemPermission(this.getUIContext()).then((granted: boolean) => {
      // 源 rememberApiPermissionState 回调：viewState.notify = 授权结果
      this.vm.setNotify(granted);
      if (!granted) {
        notificationRationaleNeeded = true;
      }
    });
  }

  // ------------------------------------------------------------ 左列（URL / Title / Tag）
  /** 静态字段标签（源 TextField label） */
  @Builder
  fieldLabel(text: ResourceStr) {
    Text(text)
      .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
      .padding({ left: 4, bottom: 4 })
  }

  @Builder
  leftContent() {
    // URL（源 TextField，filled）
    Column() {
      Text($r('app.string.url'))
        .attributeModifier(textStyle(M3Type.bodySmall, false,
          this.vm.isNotValidUrl ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant))
        .padding({ left: 4, bottom: 4 })
      TextInput({ text: this.vm.feedUrl })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.vm.feedUrl))
        .id(KEY_URL)
        .type(InputType.URL)
        .enterKeyType(EnterKeyType.Next)
        .maxLines(1)
        .fontSize(16)
        .fontColor(FeederTheme.colors.onSurface)
        .caretColor(FeederTheme.colors.primary)
        .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
        .borderRadius({ topLeft: 4, topRight: 4 })
        .border({
          width: { bottom: this.vm.isNotValidUrl ? 2 : 1 },
          color: { bottom: this.vm.isNotValidUrl ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant }
        })
        .constraintSize({ minHeight: 56 })
        .width('100%')
        .onChange((v: string) => {
          const trimmed: string = v.trim();
          if (trimmed !== v) {
            // 先写原文再写去空白值，确保输入框被回写为去空白后的内容
            this.vm.feedUrl = v;
          }
          this.vm.setFeedUrl(trimmed);
        })
        .onSubmit(() => {
          this.focusOn(KEY_TITLE);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)

    if (this.vm.isNotValidUrl) {
      Text($r('app.string.invalid_url'))
        .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.error))
        .textAlign(TextAlign.Center)
        .transition(TransitionEffect.OPACITY)
    }

    // Title（源 OutlinedTextField，占位 defaultTitle）
    Column() {
      this.fieldLabel($r('app.string.title'))
      TextInput({ text: this.vm.feedTitle, placeholder: this.vm.defaultTitle })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.vm.feedTitle))
        .id(KEY_TITLE)
        .type(InputType.Normal)
        .enterKeyType(EnterKeyType.Next)
        .maxLines(1)
        .fontSize(16)
        .fontColor(FeederTheme.colors.onSurface)
        .placeholderColor(FeederTheme.colors.onSurfaceVariant)
        .caretColor(FeederTheme.colors.primary)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: FeederTheme.colors.outline, radius: 4 })
        .constraintSize({ minHeight: 56 })
        .width('100%')
        .onChange((v: string) => {
          this.vm.setFeedTitle(v);
        })
        .onSubmit(() => {
          this.focusOn(KEY_TAG);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)

    // Tag + 自动补全（源 AutoCompleteResults，focusGroup 有焦点时显示候选）
    Column() {
      this.fieldLabel($r('app.string.tag'))
      TextInput({ text: this.vm.feedTag })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.vm.feedTag))
        .id(KEY_TAG)
        .type(InputType.Normal)
        .enterKeyType(EnterKeyType.Done)
        .maxLines(1)
        .fontSize(16)
        .fontColor(FeederTheme.colors.onSurface)
        .caretColor(FeederTheme.colors.primary)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: FeederTheme.colors.outline, radius: 4 })
        .constraintSize({ minHeight: 56 })
        .width('100%')
        .onFocus(() => {
          this.showTagSuggestions = true;
        })
        .onChange((v: string) => {
          this.vm.setFeedTag(v);
        })
        .onSubmit(() => {
          this.showTagSuggestions = false;
          this.focusOn(KEY_FIRST_SWITCH);
        })
      Column().height(4)
      if (this.showTagSuggestions && this.vm.filteredTags.length > 0) {
        List() {
          ForEach(this.vm.filteredTags, (tag: string) => {
            ListItem() {
              Row() {
                Text(tag)
                  .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .justifyContent(FlexAlign.Start)
              .alignItems(VerticalAlign.Center)
              .focusable(true)
              .focusOnTouch(true)
              .onClick(() => {
                this.vm.setFeedTag(tag);
                this.showTagSuggestions = false;
                this.focusOn(KEY_FIRST_SWITCH);
              })
            }
          }, (tag: string) => tag)
        }
        .width('90%')
        .constraintSize({ maxHeight: 56 * 3 })
        .border({ width: 2, color: FeederTheme.colors.onBackground, radius: 8 })
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onFocus(() => {
      this.showTagSuggestions = true;
    })
    .onBlur(() => {
      this.showTagSuggestions = false;
    })
  }

  // ------------------------------------------------------------ 右列（开关 / 打开方式 / 规则）
  @Builder
  groupHeader(text: ResourceStr) {
    Row() {
      Text(text)
        .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.primary))
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  rightContent() {
    FormSwitchRow({
      labelText: $r('app.string.fetch_full_articles_by_default'),
      checked: this.vm.fullTextByDefault,
      rowKey: KEY_FIRST_SWITCH,
      onToggle: (v: boolean) => {
        this.vm.setFullTextByDefault(v);
      }
    })
    FormSwitchRow({
      labelText: $r('app.string.summarize_on_open'),
      checked: this.vm.summarizeOnOpen,
      rowKey: 'editFeedSummarize',
      onToggle: (v: boolean) => {
        this.vm.setSummarizeOnOpen(v);
      }
    })
    FormSwitchRow({
      labelText: $r('app.string.fetch_og_images'),
      descText: $r('app.string.fetch_og_images_desc'),
      hasDesc: true,
      checked: this.vm.fetchOgImages,
      rowKey: 'editFeedOgImages',
      onToggle: (v: boolean) => {
        this.vm.setFetchOgImages(v);
      }
    })
    FormSwitchRow({
      labelText: $r('app.string.notify_for_new_items'),
      checked: this.vm.notify,
      rowKey: 'editFeedNotify',
      onToggle: (v: boolean) => {
        this.onNotifyToggle(v);
      }
    })
    FormSwitchRow({
      labelText: $r('app.string.skip_duplicate_articles'),
      descText: $r('app.string.skip_duplicate_articles_desc'),
      hasDesc: true,
      checked: this.vm.skipDuplicates,
      rowKey: 'editFeedSkipDuplicates',
      onToggle: (v: boolean) => {
        this.vm.setSkipDuplicates(v);
      }
    })
    FormSwitchRow({
      labelText: $r('app.string.generate_extra_unique_ids'),
      descText: $r('app.string.only_enable_for_bad_id_feeds'),
      hasDesc: true,
      checked: this.vm.alternateId,
      rowKey: 'editFeedAlternateId',
      onToggle: (v: boolean) => {
        this.vm.setAlternateId(v);
      }
    })
    Divider()
      .strokeWidth(1)
      .color(FeederTheme.colors.outlineVariant)
      .width('100%')
    this.groupHeader($r('app.string.open_item_by_default_with'))
    FormRadioRow({
      labelText: $r('app.string.use_app_default'),
      isSelected: this.vm.isOpenItemWithAppDefault,
      radioValue: 'default',
      onSelect: () => {
        this.vm.setArticleOpener('');
      }
    })
    FormRadioRow({
      labelText: $r('app.string.open_in_reader'),
      isSelected: this.vm.isOpenItemWithReader,
      radioValue: 'reader',
      onSelect: () => {
        this.vm.setArticleOpener(PREF_VAL_OPEN_WITH_READER);
      }
    })
    FormRadioRow({
      labelText: $r('app.string.open_in_custom_tab'),
      isSelected: this.vm.isOpenItemWithCustomTab,
      radioValue: 'customtab',
      onSelect: () => {
        this.vm.setArticleOpener(PREF_VAL_OPEN_WITH_CUSTOM_TAB);
      }
    })
    FormRadioRow({
      labelText: $r('app.string.open_in_default_browser'),
      isSelected: this.vm.isOpenItemWithBrowser,
      radioValue: 'browser',
      onSelect: () => {
        this.vm.setArticleOpener(PREF_VAL_OPEN_WITH_BROWSER);
      }
    })
    Divider()
      .strokeWidth(1)
      .color(FeederTheme.colors.outlineVariant)
      .width('100%')
    this.groupHeader($r('app.string.article_filter_rules'))
    Text($r('app.string.article_filter_rules_desc'))
      .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurface))
      .width('100%')
    RulesFieldView({
      labelText: $r('app.string.block_rules'),
      supportText: $r('app.string.block_rules_desc'),
      value: this.vm.blockRules,
      error: this.vm.blockRulesError,
      onValueChange: (v: string) => {
        this.vm.setBlockRules(v);
      }
    })
    RulesFieldView({
      labelText: $r('app.string.allow_rules'),
      supportText: $r('app.string.allow_rules_desc'),
      value: this.vm.allowRules,
      error: this.vm.allowRulesError,
      onValueChange: (v: string) => {
        this.vm.setAllowRules(v);
      }
    })
  }

  // ------------------------------------------------------------ OK / Cancel（源 OkCancelButtons）
  @Builder
  okCancelRow() {
    Row({ space: 8 }) {
      Button($r('app.string.cancel'), { type: ButtonType.Capsule })
        .backgroundColor(Color.Transparent)
        .fontColor(FeederTheme.colors.primary)
        .onClick(() => {
          this.onCancel();
        })
      Button($r('app.string.hm_ok'), { type: ButtonType.Capsule })
        .backgroundColor(Color.Transparent)
        .fontColor(FeederTheme.colors.primary)
        .enabled(this.vm.isOkToSave)
        .opacity(this.vm.isOkToSave ? 1 : 0.38)
        .onClick(() => {
          this.onOk();
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .padding({ bottom: 16 })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    // 源 OkCancelWithContent：可滚动 Column(水平居中){ 16; content; 24; OkCancelButtons }
    Scroll() {
      Column() {
        Column().height(16)
        if (this.screenType === ScreenType.DUAL) {
          Row() {
            Column({ space: 8 }) {
              this.leftContent()
            }
            .layoutWeight(1)
            .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
            .alignItems(HorizontalAlign.Start)
            Column({ space: 8 }) {
              this.rightContent()
            }
            .layoutWeight(1)
            .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Top)
        } else {
          Column({ space: 8 }) {
            this.leftContent()
            Divider()
              .strokeWidth(1)
              .color(FeederTheme.colors.outlineVariant)
              .width('100%')
            this.rightContent()
          }
          .width('100%')
          .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
          .alignItems(HorizontalAlign.Start)
        }
        Column().height(24)
        this.okCancelRow()
        Column().height(this.bottomInset)
      }
      .width('100%')
      .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }
}
