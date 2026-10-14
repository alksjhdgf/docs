/**
 * FeedWidgetSettingsPage —— 源 widget/FeedWidgetSettingsActivity.kt + FeedWidgetSettingsActivityViewModel.kt。
 *
 * 布局：enableEdgeToEdge + Surface 内直接复用导航抽屉列表 ListOfFeedsAndTags（contentPadding = systemBars），
 * 无顶栏/标题/返回按钮（系统返回关闭）。顶部/底部按 AvoidArea 避让（NW-A26）。
 * 列表 = Repository.getPagedNavDrawerItems：All feeds、Saved articles、标签（箭头展开/收起，与主界面抽屉共享
 * SessionStore 展开态，不关闭页面，NW-A27/A28）、源（含未读数与图标）；第 3 项为源类时上方分隔线。
 * 点任一项（NW-A29）：setCurrentWidgetFeedAndTag(id, tag)（相同不重写）→ 刷新全部小组件 → 立即关闭页面。
 *
 * 源 FeedWidgetSettingsActivity 复用 ListOfFeedsAndTags 并注入自己的 onItemClick；鸿蒙 ui/common/DrawerList 的点选
 * 写死 Repository.setCurrentFeedAndTag（无点选注入参数，且 aboutToAppear 不等 AppBootstrap.ready），无法直接复用，
 * 故行渲染以 DrawerList 的纯函数（类型/分隔线/图标/未读数格式）在页内按相同层级与尺寸重绘。
 * 待 ui/common 地基单元为 DrawerList 增加点选注入（@Event onItemClick 覆盖默认写当前 Feed）后改为直接复用。
 */
import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AppRouter } from '../common/Router';
import { AppBootstrap } from '../core/app/AppBootstrap';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { FeedUnreadCount } from '../core/model/Feed';
import { PagedListHandle } from '../core/repo/RepoTypes';
import { Repository } from '../core/repo/Repository';
import { FeederTheme } from '../ui/common/Theme';
import { M3Type, textStyle } from '../ui/common/Typography';
import {
  DrawerContentType, drawerContentTypeOf, drawerItemIdentity, formatUnreadCount, iconUrlOf, showFeedsDividerAt
} from '../ui/common/DrawerList';
import { FeedWidgetUpdater } from '../features/widget/FeedFormAbility';

const LOG_TAG: string = 'FEEDER_WIDGET_SETTINGS';

@Builder
export function FeedWidgetSettingsPageBuilder() {
  FeedWidgetSettingsPage()
}

/** 列表数据源（整表替换 → onDataReloaded；key 含全部显示字段） */
class WidgetFeedsDataSource implements IDataSource {
  private items: FeedUnreadCount[] = [];
  private listeners: DataChangeListener[] = [];

  setItems(items: FeedUnreadCount[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): FeedUnreadCount {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }
}

/** 源 FeedWidgetSettingsActivityViewModel.setCurrentFeedAndTag 后 updateAll + finish */
export async function selectWidgetFeedAndTag(feedId: number, tag: string): Promise<void> {
  await Repository.instance().setCurrentWidgetFeedAndTag(feedId, tag);
  await FeedWidgetUpdater.refreshAll();
}

@ComponentV2
struct FeedWidgetSettingsPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local itemCount: number = 0;
  private source: WidgetFeedsDataSource = new WidgetFeedsDataSource();
  private handle: PagedListHandle<FeedUnreadCount> | null = null;
  private closing: boolean = false;

  private disposed: boolean = false;

  aboutToAppear(): void {
    // 冷启直达（小组件设置入口/深链）时数据库可能尚未初始化：先等应用初始化完成再订阅
    AppBootstrap.ready().then(() => {
      if (this.disposed) {
        return;
      }
      this.handle = Repository.instance().getPagedNavDrawerItems((items: FeedUnreadCount[], endReached: boolean) => {
        this.source.setItems(items);
        this.itemCount = items.length;
      });
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: bootstrap not ready: ${e?.message}`);
    });
  }

  aboutToDisappear(): void {
    this.disposed = true;
    if (this.handle !== null) {
      this.handle.dispose();
      this.handle = null;
    }
  }

  /** 点任一项：保存小组件源 → 刷新小组件 → 立即关闭页面 */
  private selectItem(item: FeedUnreadCount): void {
    if (this.closing) {
      return;
    }
    this.closing = true;
    selectWidgetFeedAndTag(item.id, item.tag).catch((e: Error) => {
      console.error(`${LOG_TAG}: set widget feed failed: ${e?.message}`);
    });
    AppRouter.back();
  }

  private toggleTag(tag: string): void {
    Repository.instance().toggleTagExpansion(tag);
  }

  /** 源 getQuantityString(R.plurals.n_unread_articles, n, n) */
  private unreadLabel(count: number): string {
    const formatted: string = formatUnreadCount(count);
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext() as common.Context | undefined;
      if (ctx !== undefined) {
        return ctx.resourceManager.getIntPluralStringValueSync($r('app.plural.n_unread_articles').id, count, formatted);
      }
    } catch (e) {
      console.warn(`${LOG_TAG}: plural lookup failed: ${(e as Error)?.message}`);
    }
    return formatted;
  }

  private itemKey(item: FeedUnreadCount, index: number): string {
    return `${drawerItemIdentity(item)}|${item.displayTitle}|${item.unreadCount}|${item.expanded}|` +
      `${item.imageUrl ?? ''}|${showFeedsDividerAt(index, item)}`;
  }

  @Builder
  unreadCountBuilder(count: number) {
    if (count > 0) {
      Text(formatUnreadCount(count))
        .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .accessibilityText(this.unreadLabel(count))
    }
  }

  @Builder
  rowTitleBuilder(titleText: ResourceStr) {
    Text(titleText)
      .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Clip })
      .textAlign(TextAlign.Start)
      .width('100%')
  }

  /** 源 ExpandableTag：箭头切换展开（不关闭页面）；标签名点击 = 选中该 tag */
  @Builder
  tagRowBuilder(item: FeedUnreadCount) {
    Row({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.chevron_up'))
          .fontSize(24)
          .fontColor([FeederTheme.colors.onSurface])
          .rotate({ angle: item.expanded ? 0 : 180 })
          .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      }
      .width(48)
      .height(48)
      .onClick(() => {
        this.toggleTag(item.tag);
      })
      .accessibilityText($r('app.string.toggle_tag_expansion'))

      Stack({ alignContent: Alignment.Start }) {
        this.rowTitleBuilder(item.tag)
      }
      .layoutWeight(1)
      .height('100%')
      .onClick(() => {
        this.selectItem(item);
      })

      this.unreadCountBuilder(item.unreadCount)
    }
    .width('100%')
    .height(52)
    .padding({ top: LengthMetrics.vp(2), bottom: LengthMetrics.vp(2), end: LengthMetrics.vp(16) })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .accessibilityStateDescription(item.expanded ? $r('app.string.expanded_tag') : $r('app.string.contracted_tag'))
  }

  /** 源 Feed(title, image, unreadCount, onItemClick)：整行可点 */
  @Builder
  feedRowBuilder(item: FeedUnreadCount, type: DrawerContentType) {
    Row({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (type === DrawerContentType.SavedArticles) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(24)
            .fontColor([FeederTheme.colors.onSurface])
            .accessibilityLevel('no')
        } else if (type !== DrawerContentType.AllFeeds && iconUrlOf(item).length > 0) {
          Image(iconUrlOf(item))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Cover)
            .accessibilityText($r('app.string.feed_icon'))
            .onError(() => {
              console.debug(`${LOG_TAG}: icon load failed for feed ${item.id}`);
            })
        } else {
          Column()
            .width(24)
            .height(24)
        }
      }
      .width(48)
      .height(48)

      Stack({ alignContent: Alignment.Start }) {
        if (type === DrawerContentType.AllFeeds) {
          this.rowTitleBuilder($r('app.string.all_feeds'))
        } else if (type === DrawerContentType.SavedArticles) {
          this.rowTitleBuilder($r('app.string.saved_articles'))
        } else {
          this.rowTitleBuilder(item.displayTitle)
        }
      }
      .layoutWeight(1)
      .height('100%')

      this.unreadCountBuilder(item.unreadCount)
    }
    .width('100%')
    .height(52)
    .padding({ top: LengthMetrics.vp(2), bottom: LengthMetrics.vp(2), end: LengthMetrics.vp(16) })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.selectItem(item);
    })
  }

  build() {
    NavDestination() {
      List() {
        LazyForEach(this.source, (item: FeedUnreadCount, index: number) => {
          ListItem() {
            Column() {
              if (showFeedsDividerAt(index, item)) {
                Divider()
                  .strokeWidth(1)
                  .color(FeederTheme.colors.outlineVariant)
                  .width('100%')
              }
              if (drawerContentTypeOf(item) === DrawerContentType.Tag) {
                this.tagRowBuilder(item)
              } else {
                this.feedRowBuilder(item, drawerContentTypeOf(item))
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }, (item: FeedUnreadCount, index: number) => this.itemKey(item, index))
      }
      .id('feedsAndTags')
      .width('100%')
      .height('100%')
      .padding({ top: this.avoid.top, bottom: this.avoid.bottom })
      .edgeEffect(EdgeEffect.None)
      .onScrollIndex((start: number, end: number) => {
        if (this.handle !== null) {
          this.handle.onItemAccessed(end);
        }
      })
      .onReachEnd(() => {
        if (this.handle !== null) {
          this.handle.loadMore();
        }
      })
      .backgroundColor(FeederTheme.colors.surface)
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.surface)
  }
}
