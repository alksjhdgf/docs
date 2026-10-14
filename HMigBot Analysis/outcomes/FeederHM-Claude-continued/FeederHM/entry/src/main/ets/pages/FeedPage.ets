/**
 * FeedPage — 源 ui/compose/feed/FeedScreen.kt（三层 FeedScreen）+ navigation/NavigationDestinations.kt FeedDestination。
 * 参数 FeedParam{ feedId, tag }：feedId ≠ ID_UNSET 或 tag 非空白 → 设为当前 feed/tag；否则沿用上次（pref_last_feed_id/tag）。
 * 结构（源 ScreenWithNavDrawer → Scaffold）：
 *   NavDestination
 *    └ ScreenWithNavDrawer（推挤式抽屉 + DrawerList；抽屉开时系统返回仅关抽屉，FD-A05）
 *       └ Column [padding top = 状态栏避让（FD-A01）]
 *          ├ FeedTopBar（标题/导航/搜索/筛选/更多菜单）
 *          ├ Stack（layoutWeight 1）
 *          │   ├ PullRefreshContainer → FeedList（列表/瀑布流/空态）
 *          │   ├ 翻译模型下载进度（TopCenter，可选，FD-A50）
 *          │   └ FAB 覆盖层（BottomEnd，底栏不可见时，FD-A36）
 *          └ 底栏：播客条 | 朗读条（可嵌 FAB，FD-A37）
 */
import { AppRouter, Routes } from '../common/Router';
import { AppBootstrap } from '../core/app/AppBootstrap';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { ArticleParam, EditFeedParam, FeedParam, SearchFeedParam, SettingsRouteParam } from '../core/app/RouteParams';
import { ID_UNSET } from '../core/model/Enums';
import { FeedTitle, isBlankString } from '../core/model/Feed';
import { ActivityLauncher } from '../core/platform/LinkOpener';
import { DrawerState, DrawerValue } from '../ui/common/NavigationDrawer';
import { ScreenWithNavDrawer } from '../ui/common/DrawerList';
import { PullRefreshContainer, TranslationDownloadProgress, TranslationProgressContent } from '../ui/common/CommonWidgets';
import { FeederTheme } from '../ui/common/Theme';
import { openRenameTagDialog } from '../ui/common/Dialogs';
import { DeletableFeed, openEditFeedOrChooser } from '../ui/common/FeedItemDialogs';
import { FeedItemHandlers } from '../ui/common/FeedItemText';
import { FeedItemHandlerDeps, createFeedItemHandlers } from '../ui/common/SwipeableFeedItem';
import { FeedNavigator, FeedViewModel } from '../features/feed/FeedViewModel';
import { FeedTopBar } from '../features/feed/FeedTopBar';
import { FeedFab, FeedList } from '../features/feed/FeedList';
import { openDeleteFeedDialog } from '../features/feed/FeedDialogs';
import { FeedImportExport } from '../features/feed/FeedImportExport';
import { FeedBottomBarArgs, FeedExternalState, FeedPageHooks } from '../features/feed/FeedHooks';
import { isPlayerBottomBarFullyCollapsed, registerFeedPlayerBars } from '../features/readaloud/PlayerBars';

const LOG_TAG: string = 'FEEDER_FEEDPAGE';

@Builder
export function FeedPageBuilder() {
  FeedPage()
}

@Builder
function emptyBottomBar(args: FeedBottomBarArgs) {
  Column()
    .width('100%')
    .height(0)
}

/** '#AARRGGBB' → ARGB 整数（源 MaterialTheme.colorScheme.surface.toArgb()） */
function argbOf(color: string): number {
  const hex: string = color.startsWith('#') ? color.substring(1) : color;
  const v: number = parseInt(hex, 16);
  return isNaN(v) ? 0 : v;
}

@ComponentV2
struct FeedPage {
  @Local vm: FeedViewModel = new FeedViewModel();
  @Local drawerState: DrawerState = new DrawerState(DrawerValue.Closed);
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local hooks: FeedExternalState = FeedPageHooks.state;
  private handlers: FeedItemHandlers = new FeedItemHandlers();
  private podcastBar: WrappedBuilder<[FeedBottomBarArgs]> = wrapBuilder(emptyBottomBar);
  private ttsBar: WrappedBuilder<[FeedBottomBarArgs]> = wrapBuilder(emptyBottomBar);
  private navigator: FeedNavigator = new FeedNavigator();
  private pendingParam: FeedParam | null = null;
  private ready: boolean = false;
  private disposed: boolean = false;

  aboutToAppear(): void {
    // 播客条/朗读条由朗读单元注册（幂等）；route_map 懒加载下须由本页触发其模块加载
    registerFeedPlayerBars();
    this.syncBottomBarBuilders();
    this.navigator.navigateToArticle = (itemId: number) => {
      AppRouter.push(Routes.ARTICLE, ArticleParam.of(itemId));
    };
    this.navigator.openInCustomTab = (link: string) => {
      const launcher: ActivityLauncher | null = ActivityLauncher.instance();
      if (launcher === null) {
        console.warn(`${LOG_TAG}: ActivityLauncher not bound`);
        return;
      }
      launcher.openLinkInCustomTab(link, argbOf(FeederTheme.colors.surface)).catch((e: Error) => {
        console.error(`${LOG_TAG}: custom tab failed: ${e?.message}`);
      });
    };
    this.navigator.openInBrowser = (link: string) => {
      const launcher: ActivityLauncher | null = ActivityLauncher.instance();
      if (launcher === null) {
        console.warn(`${LOG_TAG}: ActivityLauncher not bound`);
        return;
      }
      launcher.openLinkInBrowser(link).catch((e: Error) => {
        console.error(`${LOG_TAG}: browser failed: ${e?.message}`);
      });
    };
    this.navigator.toast = (message: Resource) => {
      this.toast(message);
    };

    const deps: FeedItemHandlerDeps = new FeedItemHandlerDeps();
    deps.ui = this.getUIContext();
    deps.currentFilter = () => this.vm.filter;
    deps.onItemClick = (itemId: number) => {
      this.vm.openArticle(itemId, this.navigator).catch((e: Error) => {
        console.error(`${LOG_TAG}: openArticle failed: ${e?.message}`);
      });
    };
    deps.onOpenInReader = (itemId: number) => {
      this.vm.openArticleInReader(itemId, this.navigator);
    };
    deps.onOpenInCustomTab = (itemId: number) => {
      this.vm.openArticleInCustomTab(itemId, this.navigator).catch((e: Error) => {
        console.error(`${LOG_TAG}: openArticleInCustomTab failed: ${e?.message}`);
      });
    };
    deps.onOpenInBrowser = (itemId: number) => {
      this.vm.openArticleInBrowser(itemId, this.navigator).catch((e: Error) => {
        console.error(`${LOG_TAG}: openArticleInBrowser failed: ${e?.message}`);
      });
    };
    deps.scrollToTop = () => {
      this.vm.requestScrollToTop();
    };
    this.handlers = createFeedItemHandlers(deps);

    AppBootstrap.ready().then(() => {
      if (this.disposed) {
        return;
      }
      this.ready = true;
      this.applyPendingParam();
      this.vm.start();
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: bootstrap failed: ${e?.message}`);
    });
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.vm.dispose();
  }

  /** 源 FeedDestination.RegisterScreen：LaunchedEffect(feedId, tag) { if (id != UNSET || tag.isNotBlank()) set } */
  private onRouteParam(p: FeedParam): void {
    this.pendingParam = p;
    if (this.ready) {
      this.applyPendingParam();
    }
  }

  private applyPendingParam(): void {
    const p: FeedParam | null = this.pendingParam;
    this.pendingParam = null;
    if (p === null) {
      return;
    }
    if (p.feedId !== ID_UNSET || !isBlankString(p.tag)) {
      this.vm.setCurrentFeedAndTag(p.feedId, p.tag);
    }
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (e) {
      console.error(`${LOG_TAG}: toast failed: ${(e as Error)?.message}`);
    }
  }

  // ---------------------------------------------------------------- 抽屉 / 导航

  /** 源 onOpenNavDrawer：开着则关，否则开（FD-A04） */
  private toggleDrawer(): void {
    if (this.drawerState.isOpen) {
      this.drawerState.close();
    } else {
      this.drawerState.open();
    }
  }

  /**
   * 源 FeedDestination.navigate(feedId, tag)：popUpTo(graph, inclusive) + launchSingleTop（FD-A06）。
   * Feed 页单顶复用：移除本页以下全部栈项（Feed 成为唯一栈底），再切换当前 feed/tag；抽屉由 ScreenWithNavDrawer 关闭。
   */
  private onDrawerItemSelect(feedId: number, tag: string): void {
    try {
      const size: number = AppRouter.stack.size();
      if (size > 1) {
        const below: number[] = [];
        for (let i = 0; i < size - 1; i++) {
          below.push(i);
        }
        AppRouter.stack.removeByIndexes(below);
      }
    } catch (e) {
      console.error(`${LOG_TAG}: clear back stack failed: ${(e as Error)?.message}`);
    }
    if (feedId !== ID_UNSET || !isBlankString(tag)) {
      this.vm.setCurrentFeedAndTag(feedId, tag);
    }
  }

  private visibleDeletableFeeds(): DeletableFeed[] {
    return this.vm.visibleFeeds.map((f: FeedTitle): DeletableFeed => DeletableFeed.of(f.id, f.displayTitle));
  }

  private onAddFeed(): void {
    AppRouter.push(Routes.SEARCH_FEED, SearchFeedParam.of(''));
  }

  /** FD-A24 */
  private onEditFeed(): void {
    openEditFeedOrChooser(this.getUIContext(), this.visibleDeletableFeeds(), (feedId: number) => {
      AppRouter.push(Routes.EDIT_FEED, EditFeedParam.of(feedId));
    });
  }

  /** FD-A25 */
  private onDeleteFeed(): void {
    openDeleteFeedDialog(this.getUIContext(), this.visibleDeletableFeeds(), (feedIds: number[]) => {
      this.vm.deleteFeeds(feedIds);
    }, () => {
      console.debug(`${LOG_TAG}: delete dialog closed`);
    });
  }

  /** FD-A27：预填当前标签名（feedScreenTitle.title） */
  private onRenameTag(): void {
    const t: string | null = this.vm.feedScreenTitle.title;
    const current: string = t !== null ? t : '';
    openRenameTagDialog(this.getUIContext(), current, (newName: string) => {
      this.vm.renameTag(current, newName);
    }, () => {
      console.debug(`${LOG_TAG}: rename tag dialog closed`);
    });
  }

  /** 源 FAB onClick：markAllAsRead；isOpenDrawerOnFab → onOpenNavDrawer（FD-A36） */
  private onFabClick(): void {
    this.vm.markAllAsRead();
    if (this.vm.settings.openDrawerOnFab) {
      this.toggleDrawer();
    }
  }

  // ---------------------------------------------------------------- 底栏（FD-A37）

  @Monitor('hooks.barsVersion')
  onBarsRegistered(): void {
    this.syncBottomBarBuilders();
  }

  private podcastBarVisible(): boolean {
    return this.hooks.barsVersion >= 0 && this.hooks.podcastPlayerVisible && FeedPageHooks.podcastBarBuilder() !== null;
  }

  private ttsBarVisible(): boolean {
    return this.hooks.barsVersion >= 0 && this.hooks.ttsActive && FeedPageHooks.ttsBarBuilder() !== null;
  }

  private bottomBarVisible(): boolean {
    return this.podcastBarVisible() || this.ttsBarVisible();
  }

  private bottomBarArgs(withFab: boolean): FeedBottomBarArgs {
    const a: FeedBottomBarArgs = new FeedBottomBarArgs();
    a.showFab = withFab && this.vm.showFab;
    a.bottomInset = this.avoid.bottom;
    a.onFabClick = () => {
      this.onFabClick();
    };
    return a;
  }

  /** 刷新已注册底栏 builder（aboutToAppear / onShown；注册发生在应用启动期） */
  private syncBottomBarBuilders(): void {
    const podcast: WrappedBuilder<[FeedBottomBarArgs]> | null = FeedPageHooks.podcastBarBuilder();
    const tts: WrappedBuilder<[FeedBottomBarArgs]> | null = FeedPageHooks.ttsBarBuilder();
    this.podcastBar = podcast !== null ? podcast : wrapBuilder(emptyBottomBar);
    this.ttsBar = tts !== null ? tts : wrapBuilder(emptyBottomBar);
  }

  @Builder
  bottomBarBuilder() {
    if (this.podcastBarVisible()) {
      this.podcastBar.builder(this.bottomBarArgs(false))
    } else if (this.ttsBarVisible()) {
      this.ttsBar.builder(this.bottomBarArgs(true))
    }
  }

  // ---------------------------------------------------------------- 布局

  @Builder
  listBuilder() {
    FeedList({
      vm: this.vm,
      handlers: this.handlers,
      bottomBarVisible: this.bottomBarVisible(),
      bottomInset: this.avoid.bottom,
      onOpenNavDrawer: () => {
        this.toggleDrawer();
      },
      onAddFeed: () => {
        this.onAddFeed();
      }
    })
  }

  @Builder
  screenBuilder() {
    Column() {
      FeedTopBar({
        vm: this.vm,
        onToggleDrawer: () => {
          this.toggleDrawer();
        },
        onAddFeed: () => {
          this.onAddFeed();
        },
        onEditFeed: () => {
          this.onEditFeed();
        },
        onDeleteFeed: () => {
          this.onDeleteFeed();
        },
        onRenameTag: () => {
          this.onRenameTag();
        },
        onImportOpml: () => {
          FeedImportExport.importOpml(this.getUIContext());
        },
        onExportOpml: () => {
          FeedImportExport.exportOpml(this.getUIContext());
        },
        onImportSavedArticles: () => {
          FeedImportExport.importSavedArticles(this.getUIContext());
        },
        onExportSavedArticles: () => {
          FeedImportExport.exportSavedArticles(this.getUIContext());
        },
        onSettings: () => {
          AppRouter.push(Routes.SETTINGS, new SettingsRouteParam());
        }
      })

      Stack({ alignContent: Alignment.Top }) {
        PullRefreshContainer({
          refreshing: this.vm.isRefreshing,
          onRefresh: () => {
            this.vm.requestImmediateSyncOfCurrentFeedOrTag();
          },
          contentBuilder: (): void => {
            this.listBuilder()
          }
        })

        // 源 TranslationModelDownloadProgress（align TopCenter + fillMaxWidth）
        if (this.vm.translations.downloadProgress !== null) {
          Column() {
            TranslationProgressContent({
              progress: this.vm.translations.downloadProgress as TranslationDownloadProgress
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        // 源 FeedScreen.kt:1272-1275 floatingActionButton：visible = bottomBarVisibleState.isIdle && !targetState，
        // 即底栏滑出动画结束（完全收起）后才单独显示（RA-A24；右下角锚定覆盖层，透传点击）
        if (this.vm.showFab && !this.bottomBarVisible() && isPlayerBottomBarFullyCollapsed()) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            FeedFab({
              bottomInset: this.avoid.bottom,
              onFabClick: () => {
                this.onFabClick();
              }
            })
          }
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .transition(TransitionEffect.scale({ x: 0, y: 0 }).animation({ duration: 256 }))
        }
      }
      .width('100%')
      .layoutWeight(1)

      this.bottomBarBuilder()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.avoid.top })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(FeederTheme.colors.background)
  }

  build() {
    NavDestination() {
      ScreenWithNavDrawer({
        drawerState: this.drawerState,
        gesturesEnabled: true,
        avoidTop: this.avoid.top,
        avoidBottom: this.avoid.bottom,
        avoidStart: 0,
        onDrawerItemSelect: (feedId: number, tag: string) => {
          this.onDrawerItemSelect(feedId, tag);
        },
        contentBuilder: (): void => {
          this.screenBuilder()
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
    .onReady((ctx: NavDestinationContext) => {
      const p: Object = ctx.pathInfo.param as Object;
      if (p instanceof FeedParam) {
        this.onRouteParam(p as FeedParam);
      }
    })
    .onShown(() => {
      this.syncBottomBarBuilders();
    })
    .onBackPressed((): boolean => this.drawerState.handleBack())
  }
}
