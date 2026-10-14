/**
 * FeedTopBar — 源 FeedScreen.kt 的 topBar：SensibleTopAppBar(title, nav=Menu, actions)（:1210-1240）+ toolbarActions（:579-1033）。
 *  - 标题：FEED/TAG → 显示名/标签名；SAVED_ARTICLES → `Saved articles`；ALL_FEEDS → `All feeds`；
 *    pref_show_title_unread_count 开、非收藏视图、未读数≠0 → 追加 " (N)"（FD-A02/A03），单行省略；
 *  - 导航按钮 `Open navigation drawer` → 切换抽屉（FD-A04）；
 *  - 动作：搜索栏可见时为搜索输入框（自动获焦、占位 `Search`、`Cancel search`/Esc 收起并清空，FD-A10/A12/A13），
 *    否则依次 `Search`、`Filter`（非收藏视图）、`Open menu`（FD-A09）；
 *  - 筛选菜单 4 项（FD-A15）与更多菜单逐项（FD-A20）；点任一项先关闭菜单再执行。
 * 菜单/筛选菜单开关由 ViewModel 持有（SavedState，FD-A51），bindMenu(isShow) 受控显示。
 */
import { FeedType } from '../../core/repo/RepoTypes';
import { onKeyEventLikeEscape } from '../../core/platform/LayoutAdapt';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { FeedViewModel } from './FeedViewModel';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

export const FEED_SEARCH_INPUT_ID: string = 'feederFeedSearchInput';
/** 源 TopAppBar 高度 64dp */
export const FEED_TOP_BAR_HEIGHT: number = 64;
/** M3 SearchBarMinWidth 360dp */
const SEARCH_BAR_MIN_WIDTH: number = 360;

let placeholderVm: FeedViewModel | null = null;

/** @Param 默认值占位（不启动订阅） */
export function placeholderFeedViewModel(): FeedViewModel {
  if (placeholderVm === null) {
    placeholderVm = new FeedViewModel();
  }
  return placeholderVm as FeedViewModel;
}

@ComponentV2
export struct FeedTopBar {
  @Param vm: FeedViewModel = placeholderFeedViewModel();
  @Event onToggleDrawer: () => void = () => {
    console.info('TODO:toggleDrawer:FeedTopBar');
  };
  @Event onAddFeed: () => void = () => {
    console.info('TODO:addFeed:FeedTopBar');
  };
  @Event onEditFeed: () => void = () => {
    console.info('TODO:editFeed:FeedTopBar');
  };
  @Event onDeleteFeed: () => void = () => {
    console.info('TODO:deleteFeed:FeedTopBar');
  };
  @Event onRenameTag: () => void = () => {
    console.info('TODO:renameTag:FeedTopBar');
  };
  @Event onImportOpml: () => void = () => {
    console.info('TODO:importOpml:FeedTopBar');
  };
  @Event onExportOpml: () => void = () => {
    console.info('TODO:exportOpml:FeedTopBar');
  };
  @Event onImportSavedArticles: () => void = () => {
    console.info('TODO:importSavedArticles:FeedTopBar');
  };
  @Event onExportSavedArticles: () => void = () => {
    console.info('TODO:exportSavedArticles:FeedTopBar');
  };
  @Event onSettings: () => void = () => {
    console.info('TODO:settings:FeedTopBar');
  };

  // ---------------------------------------------------------------- 标题（FD-A02 / FD-A03）

  private titleBase(): ResourceStr {
    const t = this.vm.feedScreenTitle;
    switch (t.type) {
      case FeedType.SAVED_ARTICLES:
        return $r('app.string.saved_articles');
      case FeedType.ALL_FEEDS:
        return $r('app.string.all_feeds');
      default:
        return t.title !== null ? t.title : '';
    }
  }

  private showUnreadCount(): boolean {
    const t = this.vm.feedScreenTitle;
    if (t.type === FeedType.SAVED_ARTICLES || !this.vm.settings.showTitleUnreadCount || t.unreadCount === 0) {
      return false;
    }
    // 源 title == null 时不追加（仅 FEED/TAG 可能为 null）
    return !((t.type === FeedType.FEED || t.type === FeedType.TAG) && t.title === null);
  }

  private searchBarWidth(): number {
    // 导航按钮 56vp + 右侧 8vp 余量之外的空间，至多 M3 最小宽 360
    return Math.max(0, Math.min(SEARCH_BAR_MIN_WIDTH, FeederTheme.windowWidthVp - 64));
  }

  // ---------------------------------------------------------------- 动作

  private closeMenuThen(action: () => void): void {
    this.vm.setToolbarMenuVisible(false);
    action();
  }

  @Builder
  iconGlyph(icon: Resource) {
    SymbolGlyph(icon)
      .fontSize(24)
      .fontColor([FeederTheme.colors.onSurfaceVariant])
  }

  @Builder
  filterRow(label: Resource, checked: boolean, rowEnabled: boolean, toggle: () => void) {
    Row() {
      SymbolGlyph(checked ? $r('sys.symbol.checkmark_square_fill') : $r('sys.symbol.square'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurfaceVariant])
      Text(label)
        .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onSurface))
        .margin({ left: 12 })
    }
    .constraintSize({ minWidth: 112, minHeight: 48 })
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .opacity(rowEnabled ? 1.0 : 0.38)
    .hitTestBehavior(rowEnabled ? HitTestMode.Default : HitTestMode.None)
    .accessibilityGroup(true)
    .accessibilityChecked(checked)
    .onClick(() => {
      toggle();
    })
  }

  @Builder
  filterMenuBuilder() {
    Column() {
      // 源：Unread 恒勾选且不可点（only shown for completeness）
      this.filterRow($r('app.string.unread_adjective'), true, false, () => {
        console.info('Unread filter cannot be modified');
      })
      this.filterRow($r('app.string.saved_adjective'), this.vm.filter.saved, true, () => {
        this.vm.setFilterSaved(!this.vm.filter.saved);
        this.vm.setFilterMenuVisible(false);
      })
      this.filterRow($r('app.string.recently_read_adjective'), this.vm.filter.recentlyRead, true, () => {
        this.vm.setFilterRecentlyRead(!this.vm.filter.recentlyRead);
        this.vm.setFilterMenuVisible(false);
      })
      this.filterRow($r('app.string.read_adjective'), this.vm.filter.read, true, () => {
        this.vm.setFilterRead(!this.vm.filter.read);
        this.vm.setFilterMenuVisible(false);
      })
    }
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.vm.setFilterMenuVisible(false);
    }))
  }

  @Builder
  menuRow(icon: Resource, label: Resource, action: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurfaceVariant])
      Text(label)
        .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onSurface))
        .margin({ left: 12 })
    }
    .width('100%')
    .constraintSize({ minWidth: 112, minHeight: 48 })
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.closeMenuThen(action);
    })
  }

  @Builder
  toolbarMenuBuilder() {
    Column() {
      this.menuRow($r('sys.symbol.checkmark_square_on_square'), $r('app.string.mark_all_as_read'), () => {
        this.vm.markAllAsRead();
      })
      Divider().color(FeederTheme.colors.outlineVariant)
      this.menuRow($r('sys.symbol.arrow_clockwise'), $r('app.string.synchronize_feeds'), () => {
        this.vm.requestImmediateSyncOfAll();
      })
      Divider().color(FeederTheme.colors.outlineVariant)
      this.menuRow($r('sys.symbol.plus'), $r('app.string.add_feed'), () => {
        this.onAddFeed();
      })
      this.menuRow($r('sys.symbol.square_and_pencil'), $r('app.string.edit_feed'), () => {
        this.onEditFeed();
      })
      this.menuRow($r('sys.symbol.trash'), $r('app.string.delete_feed'), () => {
        this.onDeleteFeed();
      })
      if (this.vm.showRenameTag) {
        Divider().color(FeederTheme.colors.outlineVariant)
        this.menuRow($r('sys.symbol.square_and_pencil'), $r('app.string.rename_tag'), () => {
          this.onRenameTag();
        })
      }
      Divider().color(FeederTheme.colors.outlineVariant)
      this.menuRow($r('sys.symbol.arrow_down_and_line_horizontal_and_arrow_up'),
        $r('app.string.import_feeds_from_opml'), () => {
          this.onImportOpml();
        })
      this.menuRow($r('sys.symbol.arrow_down_and_line_horizontal_and_arrow_up'),
        $r('app.string.export_feeds_to_opml'), () => {
          this.onExportOpml();
        })
      this.menuRow($r('sys.symbol.arrow_down_and_line_horizontal_and_arrow_up'),
        $r('app.string.import_saved_articles'), () => {
          this.onImportSavedArticles();
        })
      this.menuRow($r('sys.symbol.arrow_down_and_line_horizontal_and_arrow_up'),
        $r('app.string.export_saved_articles'), () => {
          this.onExportSavedArticles();
        })
      Divider().color(FeederTheme.colors.outlineVariant)
      this.menuRow($r('sys.symbol.gearshape'), $r('app.string.action_settings'), () => {
        this.onSettings();
      })
    }
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.vm.setToolbarMenuVisible(false);
    }))
  }

  @Builder
  searchBarBuilder() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurfaceVariant])
        .margin({ left: 16 })
      TextInput({ text: this.vm.search, placeholder: $r('app.string.search_verb') })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.vm.search))
        .id(FEED_SEARCH_INPUT_ID)
        .layoutWeight(1)
        .height(56)
        .backgroundColor(Color.Transparent)
        .fontColor(FeederTheme.colors.onSurface)
        .placeholderColor(FeederTheme.colors.onSurfaceVariant)
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.vm.searchFor(value);
        })
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
          this.vm.searchFor(event.text);
        })
        .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
          this.vm.cancelSearch();
        }))
        .onAppear(() => {
          setTimeout(() => {
            try {
              this.getUIContext().getFocusController().requestFocus(FEED_SEARCH_INPUT_ID);
            } catch (e) {
              console.info(`FeedTopBar: search focus skipped: ${(e as Error)?.message}`);
            }
          }, 0);
        })
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        this.iconGlyph($r('sys.symbol.xmark'))
      }
      .width(48)
      .height(48)
      .margin({ right: 4 })
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.cancel_search'))
      .onClick(() => {
        this.vm.cancelSearch();
      })
    }
    .width(this.searchBarWidth())
    .height(56)
    .borderRadius(28)
    .backgroundColor(FeederTheme.colors.surfaceContainerHigh)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Row() {
      // 导航图标（源 navigationIcon：IconButton(Menu)，起始 4dp）
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        this.iconGlyph($r('sys.symbol.line_3_horizontal'))
      }
      .width(48)
      .height(48)
      .margin({ left: 4 })
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.navigation_drawer_open'))
      .onClick(() => {
        this.onToggleDrawer();
      })

      Text() {
        Span(this.titleBase())
        Span(this.showUnreadCount() ? ' ' : '')
        Span(this.showUnreadCount() ? $r('app.string.title_unread_count', this.vm.feedScreenTitle.unreadCount) : '')
      }
      .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)
      .textAlign(TextAlign.Start)
      .margin({ left: 4, right: 4 })

      Row() {
        if (this.vm.searchBarVisible) {
          this.searchBarBuilder()
        } else {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            this.iconGlyph($r('sys.symbol.magnifyingglass'))
          }
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.search_verb'))
          .onClick(() => {
            this.vm.setSearchBarVisible(true);
          })

          if (!this.vm.isSavedArticles) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              this.iconGlyph($r('sys.symbol.slider_horizontal_2'))
            }
            .width(48)
            .height(48)
            .backgroundColor(Color.Transparent)
            .accessibilityText($r('app.string.filter_noun'))
            .onClick(() => {
              this.vm.setFilterMenuVisible(true);
            })
            .bindMenu(this.vm.showFilterMenu, (): void => {
              this.filterMenuBuilder()
            }, {
              onDisappear: () => {
                this.vm.setFilterMenuVisible(false);
              }
            })
          }

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            this.iconGlyph($r('sys.symbol.dot_grid_1x2'))
          }
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.open_menu'))
          .onClick(() => {
            this.vm.setToolbarMenuVisible(true);
          })
          .bindMenu(this.vm.showToolbarMenu, (): void => {
            this.toolbarMenuBuilder()
          }, {
            onDisappear: () => {
              this.vm.setToolbarMenuVisible(false);
            }
          })
        }
      }
      .margin({ right: 4 })
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(FEED_TOP_BAR_HEIGHT)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(FeederTheme.colors.background)
  }
}
