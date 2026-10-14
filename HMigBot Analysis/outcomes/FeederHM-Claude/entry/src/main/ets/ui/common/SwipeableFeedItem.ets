/*
 * SwipeableFeedItem — 源 ui/compose/feed/SwipeableFeedItemPreview.kt（列表项外壳）+ FeedScreen.kt 中条目动作接线。
 *
 * 外壳：
 *  - 按 FeedItemStyle 分派 CARD / COMPACT_CARD / COMPACT / SUPER_COMPACT；COMPACT/SUPER_COMPACT 直角裁切，其余 12vp 圆角（FI-A17）；
 *    紧凑横屏：CARD/COMPACT_CARD 不显示缩略图，COMPACT 图片列 196vp（否则 64vp，FI-A20）；
 *    宽度不超过 dimens.maxContentWidth；COMPACT/SUPER_COMPACT 且 showDivider 时下方 1vp 分隔线（FI-A18）。
 *  - 单击 → handlers.onItemClick(item.id)（FI-A09）；长按 → 展开菜单（FI-A10/A11，菜单在 FeedItemText）。
 *  - 无障碍（FI-A26）：状态描述 Unread/Read；自定义动作（Toggle read status + 菜单 7 项）由
 *    FeedItemAccessibilityActions 在读屏开启时以可聚焦按钮提供（ArkUI 无 customActions 属性的等价实现）。
 * 滑动（源 AnchoredDraggable，鸿蒙以 PanGesture 自实现）：
 *  - Disabled 不可滑（FI-A27）；Only from end：拖拽区为末端 1/4 宽，只能向起始方向滑（FI-A28）；
 *    From anywhere：拖拽区避开起始侧 48vp，双向（FI-A29）；RTL 镜像（FI-A31）；swipeEnabled=false（列表滚动中）不接收（FI-A32）。
 *  - 锚点 ±宽/2，越过宽/4（50% 位置阈值）或甩动速度 ≥125vp/s 松手 → 触发；否则回弹（FI-A30）。
 *  - 背景：未读或过滤器仅未读 → 红 #FFFF5252 + eye_slash，否则绿 #FF1C9255 + eye；图标在被让出一侧；
 *    越过阈值不透明，否则 0.2 淡显（FI-A33）。
 *  - 触发后：非仅未读 → 回弹归位（不震动）后 onSwipe(滑前 unread)；仅未读 → 保持滑出并 onSwipe（FI-A35）。
 *  - 过滤器或条目已读状态 / 条目身份变化 → 复位居中（FI-A36）；越过阈值触觉反馈一次（FI-A37）。
 */
import { i18n } from '@kit.LocalizationKit';
import { vibrator } from '@kit.SensorServiceKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { FeedListItem } from '../../core/model/FeedItem';
import { FeedItemStyle, SwipeAsRead } from '../../core/model/Enums';
import { FeedListFilter, PrefsFeedListFilter } from '../../core/settings/SettingsModels';
import { Repository } from '../../core/repo/Repository';
import { FeedAndTag } from '../../core/repo/RepoTypes';
import { stripTrackingParameters } from '../../core/util/UrlCleaner';
import { LayoutAdapt, WindowMetrics } from '../../core/platform/LayoutAdapt';
import { FeederTheme, SWIPING_ITEM_TO_READ_COLOR, SWIPING_ITEM_TO_UNREAD_COLOR } from './Theme';
import { FeedItemAccessibilityActions, FeedItemHandlers, emptyFeedListItem } from './FeedItemText';
import { FeedItemCard, FEED_CARD_CORNER_RADIUS } from './FeedItemCard';
import { FeedItemCompact, FeedItemCompactCard } from './FeedItemCompact';
import { FeedItemSuperCompact } from './FeedItemSuperCompact';

const LOG_TAG: string = 'FEEDER_SWIPEITEM';
/** 源 FROM_ANYWHERE 拖拽区起始侧让位（导航抽屉边缘手势） */
const DRAWER_EDGE_GUARD_VP: number = 48;
/** Compose AnchoredDraggable 默认速度阈值 125.dp/s */
const FLING_VELOCITY_THRESHOLD_VP: number = 125;
const SETTLE_ANIMATION_MS: number = 250;

// ================================================================== 过滤器判定（源 FeedViewModel.kt:809-813）

export function filterOnlyUnread(f: FeedListFilter): boolean {
  return f.unread && !f.saved && !f.recentlyRead && !f.read;
}

export function filterOnlyUnreadAndSaved(f: FeedListFilter): boolean {
  return f.unread && f.saved && !f.recentlyRead && !f.read;
}

/** 源 FeedScreen.kt:1588：COMPACT/SUPER_COMPACT 时除最后一项外条目下方加分隔线 */
export function feedItemShowsDivider(style: FeedItemStyle, index: number, count: number): boolean {
  return style !== FeedItemStyle.CARD && style !== FeedItemStyle.COMPACT_CARD && index < count - 1;
}

// ================================================================== 条目动作（FeedScreen.kt / FeedViewModel.kt）

export class FeedItemActions {
  /**
   * 源 FeedScreen markAsReadOnSwipe(itemId, unread=目标未读状态, saved)（FI-A34）：
   *  仅未读 → 标记已读且已读时间 = minReadTime−1s；仅未读+已保存且条目未收藏 → 同上；
   *  否则目标未读 → markAsUnread；目标已读 → markAsReadAndNotified。
   */
  static async markAsReadOnSwipe(filter: FeedListFilter, itemId: number, unread: boolean,
    saved: boolean): Promise<void> {
    const repo = Repository.instance();
    try {
      if (filterOnlyUnread(filter)) {
        await repo.markAsReadAndNotified(itemId, true);
      } else if (filterOnlyUnreadAndSaved(filter) && !saved) {
        await repo.markAsReadAndNotified(itemId, true);
      } else if (unread) {
        await repo.markAsUnread(itemId);
      } else {
        await repo.markAsReadAndNotified(itemId);
      }
    } catch (e) {
      console.error(`${LOG_TAG}: markAsReadOnSwipe failed: ${JSON.stringify(e)}`);
    }
  }

  /** 源 onSwipe = { cur -> markAsReadOnSwipe(id, unread = !cur, saved = bookmarked) } */
  static async onSwipe(filter: FeedListFilter, item: FeedListItem, currentUnread: boolean): Promise<void> {
    await FeedItemActions.markAsReadOnSwipe(filter, item.id, !currentUnread, item.bookmarked);
  }

  /** FI-A13：收藏状态置为 !bookmarked */
  static async toggleBookmark(item: FeedListItem): Promise<void> {
    try {
      await Repository.instance().setBookmarked(item.id, !item.bookmarked);
    } catch (e) {
      console.error(`${LOG_TAG}: setBookmarked failed: ${JSON.stringify(e)}`);
    }
  }

  /** FI-A14：当前 feed/tag 范围内游标之上的条目标为已读（Repository 内触发已读同步） */
  static async markAboveAsRead(item: FeedListItem): Promise<void> {
    try {
      const repo = Repository.instance();
      const cur: FeedAndTag = repo.currentFeedAndTag;
      await repo.markBeforeAsRead(item.cursor, cur.feedId, cur.tag);
    } catch (e) {
      console.error(`${LOG_TAG}: markBeforeAsRead failed: ${JSON.stringify(e)}`);
    }
  }

  /** FI-A15：游标之下 */
  static async markBelowAsRead(item: FeedListItem): Promise<void> {
    try {
      const repo = Repository.instance();
      const cur: FeedAndTag = repo.currentFeedAndTag;
      await repo.markAfterAsRead(item.cursor, cur.feedId, cur.tag);
    } catch (e) {
      console.error(`${LOG_TAG}: markAfterAsRead failed: ${JSON.stringify(e)}`);
    }
  }

  /** FI-A16：系统分享面板，纯文本 = 去追踪参数的链接（链接为空则无正文），标题 = 条目 title */
  static async share(ui: UIContext, item: FeedListItem): Promise<void> {
    try {
      const record: systemShare.SharedRecord = {
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        title: item.title
      };
      const link = item.link;
      if (link !== null) {
        record.content = stripTrackingParameters(link);
      }
      const data = new systemShare.SharedData(record);
      const controller = new systemShare.ShareController(data);
      const ctx = ui.getHostContext() as common.UIAbilityContext;
      const options: systemShare.ShareControllerOptions = {};
      await controller.show(ctx, options);
    } catch (e) {
      console.error(`${LOG_TAG}: share failed: ${JSON.stringify(e)}`);
    }
  }
}

/** createFeedItemHandlers 的依赖（Feed 页提供：过滤器快照、打开方式、滚回顶部） */
export class FeedItemHandlerDeps {
  ui: UIContext | null = null;
  currentFilter: () => FeedListFilter = () => PrefsFeedListFilter.of(false, true, true);
  onItemClick: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onItemClick:FeedItemHandlerDeps ${itemId}`);
  };
  onOpenInReader: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onOpenInReader:FeedItemHandlerDeps ${itemId}`);
  };
  onOpenInCustomTab: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onOpenInCustomTab:FeedItemHandlerDeps ${itemId}`);
  };
  onOpenInBrowser: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onOpenInBrowser:FeedItemHandlerDeps ${itemId}`);
  };
  /** 源 listState.scrollToItem(0)（仅未读过滤下“标记上方已读”后） */
  scrollToTop: () => void = () => {
    console.info('TODO:scrollToTop:FeedItemHandlerDeps');
  };
}

/** 照 FeedScreen.kt:1482-1520 接线生成条目回调（打开方式由 deps 决定，其余走 Repository） */
export function createFeedItemHandlers(deps: FeedItemHandlerDeps): FeedItemHandlers {
  const h = new FeedItemHandlers();
  h.onItemClick = deps.onItemClick;
  h.onOpenInReader = deps.onOpenInReader;
  h.onOpenInCustomTab = deps.onOpenInCustomTab;
  h.onOpenInBrowser = deps.onOpenInBrowser;
  h.onToggleBookmark = (item: FeedListItem) => {
    FeedItemActions.toggleBookmark(item);
  };
  h.onMarkAboveAsRead = (item: FeedListItem) => {
    FeedItemActions.markAboveAsRead(item);
    if (filterOnlyUnread(deps.currentFilter())) {
      deps.scrollToTop();
    }
  };
  h.onMarkBelowAsRead = (item: FeedListItem) => {
    FeedItemActions.markBelowAsRead(item);
  };
  h.onShareItem = (item: FeedListItem) => {
    const ui = deps.ui;
    if (ui !== null) {
      FeedItemActions.share(ui, item);
    } else {
      console.warn(`${LOG_TAG}: share without UIContext`);
    }
  };
  h.onSwipe = (item: FeedListItem, currentUnread: boolean) => {
    FeedItemActions.onSwipe(deps.currentFilter(), item, currentUnread);
  };
  return h;
}

// ================================================================== 外壳组件

export enum FeedItemSwipeState {
  CENTER = 0,
  START = 1,
  END = 2,
}

function systemIsRtl(): boolean {
  try {
    return i18n.isRTL(i18n.System.getSystemLocale());
  } catch (e) {
    return false;
  }
}

/** 触感反馈可用性：startVibration 失败（无马达/无权限）即置不可用并 warn 一次（源无马达时亦为 no-op） */
let hapticAvailable: boolean = true;

function markHapticUnavailable(reason: string): void {
  if (hapticAvailable) {
    hapticAvailable = false;
    console.warn(`${LOG_TAG}: haptic feedback disabled for this session: ${reason}`);
  }
}

function performThresholdHaptic(): void {
  if (!hapticAvailable) {
    return;
  }
  try {
    const effect: vibrator.VibrateTime = { type: 'time', duration: 20 };
    const attribute: vibrator.VibrateAttribute = { id: 0, usage: 'touch' };
    vibrator.startVibration(effect, attribute).catch((e: Error) => {
      markHapticUnavailable(`${e?.message}`);
    });
  } catch (e) {
    markHapticUnavailable(JSON.stringify(e));
  }
}

@ComponentV2
export struct SwipeableFeedItem {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param listFilter: FeedListFilter = PrefsFeedListFilter.of(false, true, true);
  @Param showThumbnail: boolean = true;
  @Param feedItemStyle: FeedItemStyle = FeedItemStyle.CARD;
  @Param swipeAsRead: SwipeAsRead = SwipeAsRead.ONLY_FROM_END;
  @Param bookmarkIndicator: boolean = true;
  @Param maxLines: number = 2;
  @Param showOnlyTitle: boolean = false;
  @Param showReadingTime: boolean = false;
  /** 源 swipeEnabled = !listState.isScrollInProgress */
  @Param swipeEnabled: boolean = true;
  /** feedItemShowsDivider(style, index, count) */
  @Param showDivider: boolean = false;
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local offsetX: number = 0;
  /** 源 anchoredDraggableState.currentValue（拖动中按位置阈值更新） */
  @Local swipeState: FeedItemSwipeState = FeedItemSwipeState.CENTER;
  @Local itemWidth: number = 0;
  @Local itemHeight: number = 0;
  @Local menuShown: boolean = false;
  private isRtl: boolean = false;
  private dragStartOffset: number = 0;
  private skipHapticFeedback: boolean = false;
  private lastItemId: number = -1;
  private lastUnread: boolean = true;
  private animSeq: number = 0;

  aboutToAppear(): void {
    this.isRtl = systemIsRtl();
    this.lastItemId = this.item.id;
    this.lastUnread = this.item.unread;
  }

  /** 源 LaunchedEffect(filter, item.unread)：关键状态变化 → 复位（含复用列表项换了条目） */
  @Monitor('item')
  onItemChanged(monitor: IMonitor): void {
    const changed = this.item.id !== this.lastItemId || this.item.unread !== this.lastUnread;
    this.lastItemId = this.item.id;
    this.lastUnread = this.item.unread;
    if (changed) {
      this.resetToCenter();
    }
  }

  @Monitor('listFilter')
  onFilterChanged(monitor: IMonitor): void {
    this.resetToCenter();
  }

  private resetToCenter(): void {
    if (this.offsetX === 0 && this.swipeState === FeedItemSwipeState.CENTER) {
      return;
    }
    this.swipeState = FeedItemSwipeState.CENTER;
    this.animateOffset(0, () => {
      console.debug(`${LOG_TAG}: reset to center`);
    });
  }

  private onlyUnread(): boolean { return filterOnlyUnread(this.listFilter); }

  private compactLandscape(): boolean { return this.metrics.isCompactLandscape; }

  // ---------------------------------------------------------------- 几何（逻辑方向：LTR 下与视觉一致，RTL 取反）
  private half(): number { return this.itemWidth / 2; }

  /** 逻辑锚点（源 DraggableAnchors） */
  private anchors(): number[] {
    if (this.swipeAsRead === SwipeAsRead.ONLY_FROM_END) {
      return [-this.half(), 0];
    }
    return [-this.half(), 0, this.half()];
  }

  private toLogical(visual: number): number { return this.isRtl ? -visual : visual; }

  private toVisual(logical: number): number { return this.isRtl ? -logical : logical; }

  private stateOf(anchor: number): FeedItemSwipeState {
    return anchor < 0 ? FeedItemSwipeState.START : (anchor > 0 ? FeedItemSwipeState.END : FeedItemSwipeState.CENTER);
  }

  private closestAnchor(logical: number): number {
    const a = this.anchors();
    let best = a[0];
    for (let i = 1; i < a.length; i++) {
      if (Math.abs(a[i] - logical) < Math.abs(best - logical)) {
        best = a[i];
      }
    }
    return best;
  }

  /** 源 closestAnchor(offset, searchUpwards)：速度方向上最近的锚点（含当前位置） */
  private anchorInDirection(logical: number, upwards: boolean): number {
    const a = this.anchors();
    let best: number | null = null;
    for (let i = 0; i < a.length; i++) {
      const ok = upwards ? a[i] >= logical : a[i] <= logical;
      if (ok && (best === null || Math.abs(a[i] - logical) < Math.abs(best - logical))) {
        best = a[i];
      }
    }
    return best === null ? this.closestAnchor(logical) : best;
  }

  /** 拖拽区（视觉坐标）：[x, width] */
  private dragZone(): number[] {
    const w = this.itemWidth;
    if (this.swipeAsRead === SwipeAsRead.ONLY_FROM_END) {
      return this.isRtl ? [0, w / 4] : [w * 3 / 4, w / 4];
    }
    const zw = Math.max(0, w - DRAWER_EDGE_GUARD_VP);
    return this.isRtl ? [0, zw] : [DRAWER_EDGE_GUARD_VP, zw];
  }

  // ---------------------------------------------------------------- 状态机
  private setSwipeState(next: FeedItemSwipeState): void {
    if (next === this.swipeState) {
      return;
    }
    this.swipeState = next;
    if (this.skipHapticFeedback) {
      this.skipHapticFeedback = false;
      return;
    }
    if (this.offsetX !== 0) {
      performThresholdHaptic();
    }
  }

  private animateOffset(targetVisual: number, onFinish: () => void): void {
    const seq = ++this.animSeq;
    this.getUIContext().animateTo({
      duration: SETTLE_ANIMATION_MS,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        if (seq === this.animSeq) {
          onFinish();
        }
      }
    }, () => {
      this.offsetX = targetVisual;
    });
  }

  private handleDragStart(): void { this.animSeq++; this.dragStartOffset = this.offsetX; }

  private handleDragUpdate(deltaVisual: number): void {
    const a = this.anchors();
    const minL = a[0];
    const maxL = a[a.length - 1];
    const logical = Math.min(maxL, Math.max(minL, this.toLogical(this.dragStartOffset + deltaVisual)));
    this.offsetX = this.toVisual(logical);
    this.setSwipeState(this.stateOf(this.closestAnchor(logical)));
  }

  private handleDragEnd(velocityVisual: number): void {
    const logical = this.toLogical(this.offsetX);
    const v = this.toLogical(velocityVisual);
    const target = Math.abs(v) >= FLING_VELOCITY_THRESHOLD_VP ? this.anchorInDirection(logical, v > 0) :
    this.closestAnchor(logical);
    const targetState = this.stateOf(target);
    this.setSwipeState(targetState);
    this.animateOffset(this.toVisual(target), () => {
      if (targetState !== FeedItemSwipeState.CENTER) {
        this.onSettledOutside();
      }
    });
  }

  /** 源 LaunchedEffect(settledValue)：非 CENTER 时 */
  private onSettledOutside(): void {
    const item = this.item;
    const currentUnread = item.unread;
    if (!this.onlyUnread()) {
      this.skipHapticFeedback = true;
      this.setSwipeState(FeedItemSwipeState.CENTER);
      this.animateOffset(0, () => {
        this.handlers.onSwipe(item, currentUnread);
      });
    } else {
      // 仅未读：保持滑出，待条目从分页数据中消失
      this.handlers.onSwipe(item, currentUnread);
    }
  }

  // ---------------------------------------------------------------- 视图
  private cornerRadius(): number {
    return this.feedItemStyle === FeedItemStyle.COMPACT || this.feedItemStyle === FeedItemStyle.SUPER_COMPACT ?
      0 : FEED_CARD_CORNER_RADIUS;
  }

  private swipeColor(): string {
    return this.item.unread || this.onlyUnread() ? SWIPING_ITEM_TO_READ_COLOR : SWIPING_ITEM_TO_UNREAD_COLOR;
  }

  @Builder
  swipeBackgroundBuilder() {
    // 视觉方向固定 LTR：offset>0（内容右移）→ 图标在左，否则在右
    Row() {
      SymbolGlyph(this.item.unread ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
        .fontSize('24vp')
        .fontColor([FeederTheme.colors.onSurface])
        .accessibilityLevel('no')
    }
    .position({ x: 0, y: 0 })
    .width(this.itemWidth)
    .height(this.itemHeight)
    .direction(Direction.Ltr)
    .padding({ left: 24, right: 24 })
    .justifyContent(this.offsetX > 0 ? FlexAlign.Start : FlexAlign.End)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.swipeColor())
    .opacity(this.swipeState !== FeedItemSwipeState.CENTER ? 1.0 : 0.2)
    .animation({ duration: 300, curve: Curve.EaseInOut })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  styledItemBuilder() {
    if (this.feedItemStyle === FeedItemStyle.CARD) {
      FeedItemCard({
        item: this.item,
        showThumbnail: this.showThumbnail && !this.compactLandscape(),
        bookmarkIndicator: this.bookmarkIndicator,
        maxLines: this.maxLines,
        showOnlyTitle: this.showOnlyTitle,
        showReadingTime: this.showReadingTime,
        menuShown: this.menuShown,
        handlers: this.handlers,
        onDismissMenu: () => {
          this.menuShown = false;
        }
      })
    } else if (this.feedItemStyle === FeedItemStyle.COMPACT_CARD) {
      FeedItemCompactCard({
        item: this.item,
        showThumbnail: this.showThumbnail && !this.compactLandscape(),
        bookmarkIndicator: this.bookmarkIndicator,
        maxLines: this.maxLines,
        showReadingTime: this.showReadingTime,
        menuShown: this.menuShown,
        handlers: this.handlers,
        onDismissMenu: () => {
          this.menuShown = false;
        }
      })
    } else if (this.feedItemStyle === FeedItemStyle.COMPACT) {
      FeedItemCompact({
        item: this.item,
        showThumbnail: this.showThumbnail,
        bookmarkIndicator: this.bookmarkIndicator,
        maxLines: this.maxLines,
        showOnlyTitle: this.showOnlyTitle,
        showReadingTime: this.showReadingTime,
        menuShown: this.menuShown,
        handlers: this.handlers,
        imageWidth: this.compactLandscape() ? 196 : 64,
        onDismissMenu: () => {
          this.menuShown = false;
        }
      })
    } else {
      FeedItemSuperCompact({
        item: this.item,
        bookmarkIndicator: this.bookmarkIndicator,
        maxLines: this.maxLines,
        showOnlyTitle: this.showOnlyTitle,
        showReadingTime: this.showReadingTime,
        menuShown: this.menuShown,
        handlers: this.handlers,
        onDismissMenu: () => {
          this.menuShown = false;
        }
      })
    }
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        // 背景色块 + 图标（源 matchParentSize 的 Box，位于前景之下；尺寸取前景测得值）
        // 源无论 swipeAsRead 如何都绘制（已读 75% 不透明的直角样式下会透出淡色）
        if (this.itemWidth > 0) {
          this.swipeBackgroundBuilder()
        }
        // 前景：按样式分派，随滑动平移（源 Modifier.offset）
        Column() {
          this.styledItemBuilder()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .translate({ x: this.offsetX })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.itemWidth = newArea.width as number;
          this.itemHeight = newArea.height as number;
        })

        // 滑动层：覆盖在前景之上；点击/长按仍由外层 Stack 处理（源注释：clickable 必须在父层）
        if (this.swipeAsRead !== SwipeAsRead.DISABLED && this.itemWidth > 0) {
          Column()
            .position({ x: this.dragZone()[0], y: 0 })
            .width(this.dragZone()[1])
            .height(this.itemHeight)
            .hitTestBehavior(this.swipeEnabled ? HitTestMode.Default : HitTestMode.None)
            .accessibilityLevel('no')
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart((event: GestureEvent) => {
                  this.handleDragStart();
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.handleDragUpdate(event.offsetX);
                })
                .onActionEnd((event: GestureEvent) => {
                  this.handleDragEnd(event.velocityX);
                })
                .onActionCancel(() => {
                  this.handleDragEnd(0);
                })
            )
        }
      }
      .width('100%')
      .borderRadius(this.cornerRadius())
      .clip(true)
      .accessibilityGroup(true)
      .accessibilityStateDescription(this.item.unread ? $r('app.string.unread_adjective') :
      $r('app.string.read_adjective'))
      .onClick(() => {
        this.handlers.onItemClick(this.item.id);
      })
      .gesture(
        LongPressGesture()
          .onAction((event: GestureEvent) => {
            this.menuShown = true;
          })
      )

      // FI-A26：读屏开启时的自定义无障碍动作（读屏关闭不渲染）
      FeedItemAccessibilityActions({ item: this.item, handlers: this.handlers })

      if (this.showDivider && (this.feedItemStyle === FeedItemStyle.COMPACT ||
        this.feedItemStyle === FeedItemStyle.SUPER_COMPACT)) {
        Divider()
          .strokeWidth(1)
          .color(FeederTheme.colors.outlineVariant)
          .width('100%')
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .alignItems(HorizontalAlign.Start)
  }
}
