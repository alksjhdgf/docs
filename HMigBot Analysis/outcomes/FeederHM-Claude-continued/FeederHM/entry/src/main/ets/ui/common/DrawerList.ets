/*
 * DrawerList — 源 ui/compose/navdrawer/NavDrawer.kt（ScreenWithNavDrawer / ListOfFeedsAndTags / ExpandableTag /
 * AllFeeds / SavedArticles / TopLevelFeed / ChildFeed / Feed）的鸿蒙实现。
 *
 * 数据：Repository.getPagedNavDrawerItems（FeedDao 导航抽屉 SQL：All feeds → Saved articles → 标签(+展开的子源) → 无标签源；
 * 计数/排序/屏蔽/显示标题均由 SQL 视图 feeds_with_items_for_nav_drawer 决定，UC-A01..A07）；
 * PagedList 订阅 DbNotifier（feeds/feed_items）→ 标记已读、同步、收藏变化后自动重查（UC-A13）；
 * 标签展开态在 SessionStore（纯内存，冷启全部折叠，UC-A06）。
 * 源无长按/上下文菜单，此处亦无。
 */
import { common } from '@kit.AbilityKit';
import { intl, i18n } from '@kit.LocalizationKit';
import { LengthMetrics } from '@kit.ArkUI';
import { FeedUnreadCount } from '../../core/model/Feed';
import { ID_ALL_FEEDS, ID_SAVED_ARTICLES, ID_UNSET } from '../../core/model/Enums';
import { PagedListHandle } from '../../core/repo/RepoTypes';
import { Repository } from '../../core/repo/Repository';
import { FeederTheme } from './Theme';
import { M3Type, textStyle } from './Typography';
import { DrawerState, DrawerValue, NavigationDrawer } from './NavigationDrawer';

/** 抽屉列表组件 id：NavigationDrawer.focusKeyOnOpen 用（源 focusRequester，UM-A09） */
export const DRAWER_LIST_FOCUS_KEY: string = 'feederNavDrawerList';
const LOG_TAG: string = 'FEEDER_DRAWER';

/** 源 enum ContentType */
export enum DrawerContentType {
  AllFeeds = 0,
  SavedArticles = 1,
  Tag = 2,
  ChildFeed = 3,
  TopLevelFeed = 4
}

/** 源 FeedUnreadCount.contentType */
export function drawerContentTypeOf(item: FeedUnreadCount): DrawerContentType {
  if (item.id === ID_UNSET) {
    return DrawerContentType.Tag;
  }
  if (item.id === ID_ALL_FEEDS) {
    return DrawerContentType.AllFeeds;
  }
  if (item.id === ID_SAVED_ARTICLES) {
    return DrawerContentType.SavedArticles;
  }
  return item.tag.length > 0 ? DrawerContentType.ChildFeed : DrawerContentType.TopLevelFeed;
}

/** 源 ContentType.isFeedListItem */
export function isFeedListItem(type: DrawerContentType): boolean {
  return type === DrawerContentType.Tag || type === DrawerContentType.ChildFeed ||
    type === DrawerContentType.TopLevelFeed;
}

/** 源 showFeedsDivider = itemIndex == 2 && item.contentType.isFeedListItem（UC-A11） */
export function showFeedsDividerAt(index: number, item: FeedUnreadCount): boolean {
  return index === 2 && isFeedListItem(drawerContentTypeOf(item));
}

/** 源 itemKey：ID_ALL_FEEDS / ID_SAVED_ARTICLES / 标签名 / 源 id */
export function drawerItemIdentity(item: FeedUnreadCount): string {
  if (item.id === ID_UNSET) {
    return `tag:${item.tag}`;
  }
  return `id:${item.id}`;
}

/** 标签行标题区组件 id（读屏点击由标签行分组转交给它，见 tagRowBuilder） */
export function tagTitleNodeId(tag: string): string {
  return `feederDrawerTag:${tag}`;
}

/** 源 imageUrl?.toString()：无图标为空串 */
export function iconUrlOf(item: FeedUnreadCount): string {
  const u: string | null = item.imageUrl;
  return u === null ? '' : u;
}

let numberFormat: intl.NumberFormat | null = null;

/** 源 "%d".format(locales[0], unreadCount)：按当前语言区域格式化整数（无分组） */
export function formatUnreadCount(count: number): string {
  try {
    if (numberFormat === null) {
      const opts: intl.NumberOptions = { useGrouping: false, maximumFractionDigits: 0 };
      numberFormat = new intl.NumberFormat(i18n.System.getSystemLanguage(), opts);
    }
    return (numberFormat as intl.NumberFormat).format(count);
  } catch (e) {
    return `${Math.trunc(count)}`;
  }
}

/** 列表数据源（整表替换 → onDataReloaded；key 含全部显示字段） */
class DrawerDataSource implements IDataSource {
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

/**
 * 源 ListOfFeedsAndTags：抽屉内订阅源/标签列表。
 * 点选 → Repository.setCurrentFeedAndTag(id, tag) 并回调 onItemSelect（容器据此关闭抽屉）；
 * 标签箭头 → Repository.toggleTagExpansion(tag)（不导航、不关闭抽屉，UC-A08）。
 */
@ComponentV2
export struct DrawerList {
  @Event onItemSelect: (feedId: number, tag: string) => void = (feedId: number, tag: string): void => {
  };
  @Local itemCount: number = 0;
  private source: DrawerDataSource = new DrawerDataSource();
  private handle: PagedListHandle<FeedUnreadCount> | null = null;

  aboutToAppear(): void {
    this.handle = Repository.instance().getPagedNavDrawerItems((items: FeedUnreadCount[], endReached: boolean) => {
      this.source.setItems(items);
      this.itemCount = items.length;
    });
  }

  aboutToDisappear(): void {
    if (this.handle !== null) {
      this.handle.dispose();
      this.handle = null;
    }
  }

  private selectItem(item: FeedUnreadCount): void {
    const feedId: number = item.id;
    const tag: string = item.tag;
    Repository.instance().setCurrentFeedAndTag(feedId, tag).catch((e: Error) => {
      console.error(`${LOG_TAG}: setCurrentFeedAndTag failed: ${e?.message}`);
    });
    this.onItemSelect(feedId, tag);
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

  /** 行尾未读数：仅 > 0 时显示（UC-A09），朗读复数串（UC-A14） */
  @Builder
  unreadCountBuilder(count: number) {
    if (count > 0) {
      Text(formatUnreadCount(count))
        .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .accessibilityText(this.unreadLabel(count))
    }
  }

  /** 源 Text(title, maxLines = 1)：单行，超长裁切不换行（UC-A12） */
  @Builder
  titleBuilder(titleText: ResourceStr) {
    Text(titleText)
      .attributeModifier(textStyle(M3Type.bodyLarge, false, FeederTheme.colors.onSurface))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Clip })
      .textAlign(TextAlign.Start)
      .width('100%')
  }

  /**
   * 源 ExpandableTag：箭头切换展开；标签名点击导航（UC-A08/UC-A14）。
   * 无障碍（源 Row.safeSemantics(mergeDescendants) { stateDescription; customActions = [Toggle tag expansion] }，
   * 箭头 clearAndSetSemantics {}）：ArkUI 无自定义无障碍动作（AccessibilityAction 仅 UNDEFINED/CLICK），
   * 故拆为两个读屏节点——
   *  ① 标题+未读数合并为一组（accessibilityGroup），朗读"标签名, N unread articles, Open tag/Closed tag"，
   *    读屏点击经 actionControllerId 转给标题区（导航）；
   *  ② 箭头为独立按钮节点"Toggle tag expansion"（带同一状态描述），双击切换展开——承载源自定义动作的功能。
   */
  @Builder
  tagRowBuilder(item: FeedUnreadCount) {
    Row({ space: 4 }) {
      // 源 ExpandArrow：IconButton + ExpandLess 图标，展开 0°、折叠 180°（tween 动画）
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.chevron_up'))
          .fontSize(24)
          .fontColor([FeederTheme.colors.onSurface])
          .rotate({ angle: item.expanded ? 0 : 180 })
          .animation({ duration: 300, curve: Curve.FastOutSlowIn })
          .accessibilityLevel('no')
      }
      .width(48)
      .height(48)
      .onClick(() => {
        this.toggleTag(item.tag);
      })
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText($r('app.string.toggle_tag_expansion'))
      .accessibilityStateDescription(item.expanded ? $r('app.string.expanded_tag') : $r('app.string.contracted_tag'))

      Row({ space: 4 }) {
        Stack({ alignContent: Alignment.Start }) {
          this.titleBuilder(item.tag)
        }
        .id(tagTitleNodeId(item.tag))
        .layoutWeight(1)
        .height('100%')
        .onClick(() => {
          this.selectItem(item);
        })

        this.unreadCountBuilder(item.unreadCount)
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .accessibilityGroup(true, {
        accessibilityPreferred: true,
        actionControllerId: tagTitleNodeId(item.tag)
      })
      .accessibilityStateDescription(item.expanded ? $r('app.string.expanded_tag') : $r('app.string.contracted_tag'))
    }
    .width('100%')
    .height(52)
    .padding({ top: LengthMetrics.vp(2), bottom: LengthMetrics.vp(2), end: LengthMetrics.vp(16) })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  /** 源 Feed(title, image, unreadCount, onItemClick)：整行可点；图标位 48×48（minimumInteractiveComponentSize） */
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
          // 源 AsyncImage(size 24dp, ContentScale.Crop)；加载失败保留空白占位（UC-A10）
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
          this.titleBuilder($r('app.string.all_feeds'))
        } else if (type === DrawerContentType.SavedArticles) {
          this.titleBuilder($r('app.string.saved_articles'))
        } else {
          this.titleBuilder(item.displayTitle)
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
    // 源 Row.clickable 合并子语义：图标 "Feed Icon" + 标题 + 未读复数串 作为一个读屏节点
    .accessibilityGroup(true, { accessibilityPreferred: true })
  }

  build() {
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
    .id(DRAWER_LIST_FOCUS_KEY)
    .focusable(true)
    .width('100%')
    .height('100%')
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
  }
}

@Builder
function emptyScreenBuilder() {
}

/**
 * 源 ScreenWithNavDrawer：NavigationDrawer + DrawerList 的组合。
 * 选中条目 → onDrawerItemSelect(feedId, tag)（页面导航到该 Feed）→ 关闭抽屉；抽屉打开后焦点移入列表。
 */
@ComponentV2
export struct ScreenWithNavDrawer {
  @Param drawerState: DrawerState = new DrawerState(DrawerValue.Closed);
  @Param gesturesEnabled: boolean = true;
  @Param avoidTop: number = 0;
  @Param avoidBottom: number = 0;
  @Param avoidStart: number = 0;
  @Event onDrawerItemSelect: (feedId: number, tag: string) => void = (feedId: number, tag: string): void => {
  };
  @BuilderParam contentBuilder: () => void = emptyScreenBuilder;

  @Builder
  drawerBuilder() {
    DrawerList({
      onItemSelect: (feedId: number, tag: string): void => {
        this.onDrawerItemSelect(feedId, tag);
        this.drawerState.close();
      }
    })
  }

  build() {
    NavigationDrawer({
      drawerState: this.drawerState,
      gesturesEnabled: this.gesturesEnabled,
      avoidTop: this.avoidTop,
      avoidBottom: this.avoidBottom,
      avoidStart: this.avoidStart,
      focusKeyOnOpen: DRAWER_LIST_FOCUS_KEY,
      drawerContentBuilder: (): void => {
        this.drawerBuilder()
      },
      contentBuilder: (): void => {
        this.contentBuilder()
      }
    })
  }
}
