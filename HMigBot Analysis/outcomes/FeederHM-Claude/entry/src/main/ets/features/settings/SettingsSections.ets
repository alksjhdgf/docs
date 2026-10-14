/*
 * SettingsSections — 源 ui/compose/settings/Settings.kt:403-962 SettingsList：全部分组与条目，逐条照源顺序。
 *   (无组) Theme / Dynamic colors / Preferred dark theme / Notify for new items
 *   Block list · Text · Syncing · Article list · Reader · Image loading · Text to speech · AI and translation
 *   (无组) Send bug report
 * 单列 Column（由页面放进纵向 Scroll），水平 padding dimens.margin，行宽上限 dimens.maxContentWidth 居中，
 * 组间 HorizontalDivider，末尾避让导航条。
 */
import { DYNAMIC_THEME_PLATFORM_SUPPORTED } from '../../core/settings/SettingsModels';
import { fontDisplayLabel } from '../textsettings/TextSettingsViewModel';
import { OpenAISettingsSection } from '../openai/OpenAISettingsSection';
import { FeederTheme } from '../../ui/common/Theme';
import {
  blockListSubtitle, darkThemeFromKey, darkThemeLabel, darkThemeMenuOptions, feedItemStyleFromKey, feedItemStyleLabel,
  feedItemStyleMenuOptions, intMenuOptions, itemOpenerFromKey, itemOpenerLabel, itemOpenerMenuOptions,
  linkOpenerFromKey, linkOpenerLabel, linkOpenerMenuOptions, MAX_ITEMS_PER_FEED_VALUES, MAX_LINES_VALUES,
  notifySubtitle, sortedStrings, sortingFromKey, sortingLabel, sortingMenuOptions, swipeAsReadFromKey,
  swipeAsReadLabel, swipeAsReadMenuOptions, syncFrequencyFromKey, syncFrequencyLabel, syncFrequencyMenuOptions,
  themeFromKey, themeLabel, themeMenuOptions
} from './SettingsOptions';
import { SettingsDialogsController } from './SettingsActions';
import { SettingsViewModel } from './SettingsViewModel';
import {
  ActionSetting, ExternalSetting, GroupTitle, ListDialogSetting, MenuSetting, SettingsDivider, SwitchSetting
} from './SettingsWidgets';

@Builder
function bugReportIcon() {
  SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
    .fontSize(24)
    .fontColor([FeederTheme.colors.onSurface])
}

@ComponentV2
export struct SettingsList {
  @Param vm: SettingsViewModel = new SettingsViewModel();
  @Param dialogs: SettingsDialogsController = new SettingsDialogsController();
  /** 源 LocalConfiguration.smallestScreenWidthDp >= 600（ST-A33） */
  @Param notCompactScreen: boolean = false;
  /** 底部导航条避让（源 Spacer(navigationBarsPadding)） */
  @Param bottomInset: number = 0;
  @Event onOpenSyncSettings: () => void = () => {
    console.info('TODO:openSyncSettings:SettingsList');
  };
  @Event onTextSettings: () => void = () => {
    console.info('TODO:textSettings:SettingsList');
  };
  @Event onBatteryOptimization: () => void = () => {
    console.info('TODO:batteryOptimization:SettingsList');
  };
  @Event onSendFeedback: () => void = () => {
    console.info('TODO:sendFeedback:SettingsList');
  };

  @Monitor('vm.viewState.blockList')
  onBlockListChange(): void {
    this.dialogs.onBlockListChanged(this.vm.viewState.blockList);
  }

  @Monitor('vm.viewState.feedsSettings')
  onFeedsSettingsChange(): void {
    this.dialogs.onFeedsSettingsChanged(this.vm.viewState.feedsSettings);
  }

  build() {
    Column() {
      this.topSection()
      SettingsDivider()
      this.blockListGroup()
      SettingsDivider()
      this.textGroup()
      SettingsDivider()
      this.syncGroup()
      SettingsDivider()
      this.articleListGroup()
      SettingsDivider()
      this.readerGroup()
      SettingsDivider()
      this.imageLoadingGroup()
      SettingsDivider()
      this.ttsGroup()
      SettingsDivider()
      this.aiGroup()
      SettingsDivider()
      ActionSetting({
        rowTitle: $r('app.string.send_bug_report'),
        // 全局 @Builder 须直接作 @BuilderParam 传入；包进箭头函数调用会丢失 this（observeComponentCreation2 of undefined）
        iconBuilder: bugReportIcon,
        onAction: () => {
          this.onSendFeedback();
        }
      })
      SettingsDivider()
      Column()
        .width('100%')
        .height(this.bottomInset)
    }
    .width('100%')
    .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin })
    .alignItems(HorizontalAlign.Center)
  }

  // ---------------------------------------------------------------- 无组：主题 / 动态色 / 深色 / 通知

  @Builder
  topSection() {
    MenuSetting({
      rowTitle: $r('app.string.theme'),
      currentLabel: themeLabel(this.vm.viewState.currentTheme),
      currentKey: this.vm.viewState.currentTheme.toString(),
      options: themeMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setCurrentTheme(themeFromKey(k));
      }
    })
    // ST-A07：平台无动态取色 → 禁用 + 说明，值视为关（store 生效值恒 false）
    SwitchSetting({
      rowTitle: $r('app.string.dynamic_theme_use'),
      checked: this.vm.viewState.useDynamicTheme,
      description: $r('app.string.only_available_on_android_n', '12'),
      hasDescription: !DYNAMIC_THEME_PLATFORM_SUPPORTED,
      rowEnabled: DYNAMIC_THEME_PLATFORM_SUPPORTED,
      onCheckedChange: (v: boolean) => {
        this.vm.setUseDynamicTheme(v);
      }
    })
    MenuSetting({
      rowTitle: $r('app.string.dark_theme_preference'),
      currentLabel: darkThemeLabel(this.vm.viewState.darkThemePreference),
      currentKey: this.vm.viewState.darkThemePreference.toString(),
      options: darkThemeMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setPreferredDarkTheme(darkThemeFromKey(k));
      }
    })
    // 源 NotificationsSetting（ST-A09/A10）：权限被拒 → 说明文案；否则已开启通知的订阅标题
    ListDialogSetting({
      rowTitle: $r('app.string.notify_for_new_items'),
      currentValue: this.dialogs.notificationPermissionDenied ? $r('app.string.explanation_permission_notifications') :
      notifySubtitle(this.vm.viewState.feedsSettings),
      onOpen: () => {
        this.dialogs.onNotificationsClick(this.getUIContext(), this.vm);
      }
    })
  }

  // ---------------------------------------------------------------- Block list（ST-A12..A14）

  @Builder
  blockListGroup() {
    GroupTitle({ groupTitle: $r('app.string.block_list') })
    ListDialogSetting({
      rowTitle: $r('app.string.filters'),
      currentValue: blockListSubtitle(sortedStrings(this.vm.viewState.blockList)),
      onOpen: () => {
        this.dialogs.openFilters(this.getUIContext(), this.vm);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.apply_blocklist_to_summaries'),
      checked: this.vm.viewState.applyBlocklistToSummaries,
      onCheckedChange: (v: boolean) => {
        this.vm.setApplyBlocklistToSummaries(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.apply_blocklist_to_links'),
      checked: this.vm.viewState.applyBlocklistToLinks,
      onCheckedChange: (v: boolean) => {
        this.vm.setApplyBlocklistToLinks(v);
      }
    })
  }

  // ---------------------------------------------------------------- Text（ST-A16）

  @Builder
  textGroup() {
    GroupTitle({ groupTitle: $r('app.string.text') })
    ExternalSetting({
      rowTitle: $r('app.string.text_settings'),
      currentValue: fontDisplayLabel(this.vm.viewState.font),
      onAction: () => {
        this.onTextSettings();
      }
    })
  }

  // ---------------------------------------------------------------- Syncing（ST-A17..A23）

  @Builder
  syncGroup() {
    GroupTitle({ groupTitle: $r('app.string.synchronization') })
    MenuSetting({
      rowTitle: $r('app.string.check_for_updates'),
      currentLabel: syncFrequencyLabel(this.vm.viewState.syncFrequency),
      currentKey: `${this.vm.viewState.syncFrequency as number}`,
      options: syncFrequencyMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setSyncFrequency(syncFrequencyFromKey(k));
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.on_startup'),
      checked: this.vm.viewState.syncOnResume,
      onCheckedChange: (v: boolean) => {
        this.vm.setSyncOnResume(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.only_on_wifi'),
      checked: this.vm.viewState.syncOnlyOnWifi,
      onCheckedChange: (v: boolean) => {
        this.vm.setSyncOnlyOnWifi(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.only_when_charging'),
      checked: this.vm.viewState.syncOnlyWhenCharging,
      onCheckedChange: (v: boolean) => {
        this.vm.setSyncOnlyWhenCharging(v);
      }
    })
    MenuSetting({
      rowTitle: $r('app.string.max_feed_items'),
      currentLabel: `${this.vm.viewState.maximumCountPerFeed}`,
      currentKey: `${this.vm.viewState.maximumCountPerFeed}`,
      options: intMenuOptions(MAX_ITEMS_PER_FEED_VALUES),
      onSelection: (k: string) => {
        this.vm.setMaxCountPerFeed(Number.parseInt(k, 10));
      }
    })
    ExternalSetting({
      rowTitle: $r('app.string.battery_optimization'),
      currentValue: this.vm.viewState.batteryOptimizationIgnored ? $r('app.string.battery_optimization_disabled') :
      $r('app.string.battery_optimization_enabled'),
      onAction: () => {
        this.onBatteryOptimization();
      }
    })
    ExternalSetting({
      rowTitle: $r('app.string.device_sync'),
      currentValue: '',
      onAction: () => {
        this.onOpenSyncSettings();
      }
    })
  }

  // ---------------------------------------------------------------- Article list（ST-A24..A29）

  @Builder
  articleListGroup() {
    GroupTitle({ groupTitle: $r('app.string.article_list_settings') })
    MenuSetting({
      rowTitle: $r('app.string.sort'),
      currentLabel: sortingLabel(this.vm.viewState.currentSorting),
      currentKey: this.vm.viewState.currentSorting.toString(),
      options: sortingMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setCurrentSorting(sortingFromKey(k));
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.show_fab'),
      checked: this.vm.viewState.showFab,
      onCheckedChange: (v: boolean) => {
        this.vm.setShowFab(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.open_drawer_on_fab'),
      checked: this.vm.viewState.isOpenDrawerOnFab,
      onCheckedChange: (v: boolean) => {
        this.vm.setOpenDrawerOnFab(v);
      }
    })
    MenuSetting({
      rowTitle: $r('app.string.feed_item_style'),
      currentLabel: feedItemStyleLabel(this.vm.viewState.feedItemStyle),
      currentKey: this.vm.viewState.feedItemStyle.toString(),
      options: feedItemStyleMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setFeedItemStyle(feedItemStyleFromKey(k));
      }
    })
    MenuSetting({
      rowTitle: $r('app.string.max_lines'),
      currentLabel: `${this.vm.viewState.maxLines}`,
      currentKey: `${this.vm.viewState.maxLines}`,
      options: intMenuOptions(MAX_LINES_VALUES),
      onSelection: (k: string) => {
        this.vm.setMaxLines(Number.parseInt(k, 10));
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.show_only_title'),
      checked: this.vm.viewState.showOnlyTitle,
      onCheckedChange: (v: boolean) => {
        this.vm.setShowOnlyTitles(v);
      }
    })
    MenuSetting({
      rowTitle: $r('app.string.swipe_to_mark_as_read'),
      currentLabel: swipeAsReadLabel(this.vm.viewState.swipeAsRead),
      currentKey: this.vm.viewState.swipeAsRead.toString(),
      options: swipeAsReadMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setSwipeAsRead(swipeAsReadFromKey(k));
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.mark_as_read_on_scroll'),
      checked: this.vm.viewState.isMarkAsReadOnScroll,
      onCheckedChange: (v: boolean) => {
        this.vm.setIsMarkAsReadOnScroll(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.show_thumbnails'),
      checked: this.vm.viewState.showThumbnails,
      onCheckedChange: (v: boolean) => {
        this.vm.setShowThumbnails(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.show_reading_time'),
      checked: this.vm.viewState.showReadingTime,
      onCheckedChange: (v: boolean) => {
        this.vm.setShowReadingTime(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.show_title_unread_count'),
      checked: this.vm.viewState.showTitleUnreadCount,
      onCheckedChange: (v: boolean) => {
        this.vm.setShowTitleUnreadCount(v);
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.force_single_column'),
      checked: this.vm.viewState.forceSingleColumn,
      onCheckedChange: (v: boolean) => {
        this.vm.setForceSingleColumn(v);
      }
    })
  }

  // ---------------------------------------------------------------- Reader（ST-A30..A34）

  @Builder
  readerGroup() {
    GroupTitle({ groupTitle: $r('app.string.reader_settings') })
    MenuSetting({
      rowTitle: $r('app.string.open_item_by_default_with'),
      currentLabel: itemOpenerLabel(this.vm.viewState.itemOpener),
      currentKey: this.vm.viewState.itemOpener.toString(),
      options: itemOpenerMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setItemOpener(itemOpenerFromKey(k));
      }
    })
    MenuSetting({
      rowTitle: $r('app.string.open_links_with'),
      currentLabel: linkOpenerLabel(this.vm.viewState.linkOpener),
      currentKey: this.vm.viewState.linkOpener.toString(),
      options: linkOpenerMenuOptions(),
      onSelection: (k: string) => {
        this.vm.setLinkOpener(linkOpenerFromKey(k));
      }
    })
    SwitchSetting({
      rowTitle: $r('app.string.use_in_app_audio_player'),
      checked: this.vm.viewState.useInAppAudioPlayer,
      description: $r('app.string.use_in_app_audio_player_description'),
      hasDescription: true,
      onCheckedChange: (v: boolean) => {
        this.vm.setUseInAppAudioPlayer(v);
      }
    })
    if (this.notCompactScreen) {
      SwitchSetting({
        rowTitle: $r('app.string.open_browser_in_split_screen'),
        checked: this.vm.viewState.isOpenAdjacent,
        onCheckedChange: (v: boolean) => {
          this.vm.setIsOpenAdjacent(v);
        }
      })
    }
    SwitchSetting({
      rowTitle: $r('app.string.pref_paging_mode_title'),
      checked: this.vm.viewState.isPagingMode,
      description: $r('app.string.pref_paging_mode_description'),
      hasDescription: true,
      onCheckedChange: (v: boolean) => {
        this.vm.setIsPagingMode(v);
      }
    })
    if (this.vm.viewState.isPagingMode) {
      SwitchSetting({
        rowTitle: $r('app.string.pref_animated_paging_title'),
        checked: this.vm.viewState.isAnimatedPaging,
        description: $r('app.string.pref_animated_paging_description'),
        hasDescription: true,
        onCheckedChange: (v: boolean) => {
          this.vm.setIsAnimatedPaging(v);
        }
      })
    }
  }

  // ---------------------------------------------------------------- Image loading（ST-A35）

  @Builder
  imageLoadingGroup() {
    GroupTitle({ groupTitle: $r('app.string.image_loading') })
    SwitchSetting({
      rowTitle: $r('app.string.only_on_wifi'),
      checked: this.vm.viewState.loadImageOnlyOnWifi,
      onCheckedChange: (v: boolean) => {
        this.vm.setLoadImageOnlyOnWifi(v);
      }
    })
  }

  // ---------------------------------------------------------------- Text to speech（ST-A36）

  @Builder
  ttsGroup() {
    GroupTitle({ groupTitle: $r('app.string.text_to_speech') })
    SwitchSetting({
      rowTitle: $r('app.string.use_detect_language'),
      checked: this.vm.viewState.useDetectLanguage,
      description: $r('app.string.description_for_read_aloud'),
      hasDescription: true,
      onCheckedChange: (v: boolean) => {
        this.vm.setUseDetectLanguage(v);
      }
    })
  }

  // ---------------------------------------------------------------- AI and translation（ST-A37/A38，SS-A27..A29）

  @Builder
  aiGroup() {
    GroupTitle({ groupTitle: $r('app.string.openai_settings') })
    // Summary API / Translation API（含已下载模型区两阶段删除）/ canTranslate 时两开关：core-openai 实现
    OpenAISettingsSection({ showGroupTitle: false })
  }
}
