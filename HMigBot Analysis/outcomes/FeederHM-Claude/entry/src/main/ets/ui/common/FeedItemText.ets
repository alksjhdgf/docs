/*
 * FeedItemText — 源 ui/compose/feed/FeedItemCard.kt（RowScope.FeedItemText + 长按 DropdownMenu）
 * 与 ui/compose/feed/FeedItemIndicator.kt（收藏星标 / 未读圆点 / 订阅源图标 / 二选一指示器）的鸿蒙实现，
 * 以及四种条目样式共用的回调集合 FeedItemHandlers、阅读时长换算（feedarticle/ReaderView.kt:401）。
 *
 * 文本块结构（Column，间距 4vp）：
 *  1. 合并文本：title 非空白 → title（+ 非 showOnlyTitle 且 snippet 非空白时 '\n'+snippet，摘要样式 Span）；
 *     title 空白 → 仅 snippet。字重未读 Black(900)/已读 Normal(400)；maxLines + 省略号（FI-A01/A02/A03）。
 *  2. 订阅源名（单行省略，占满剩余宽）+ 日期（单行裁切）；长按菜单锚定在这一行（源：菜单居中于中间行，FI-A05）。
 *  3. showReadingTime 且秒数 > 0：`M:SS minutes` + `<n> words`（FI-A07/A08）。
 * 每段文本按内容首个强方向字符决定书写方向（源 WithBidiDeterminedLayoutDirection，FI-A06）。
 */
import { accessibility } from '@kit.AccessibilityKit';
import { FeedListItem } from '../../core/model/FeedItem';
import { ThumbnailImage } from '../../core/model/Thumbnail';
import { FeederTheme, isRtlText } from './Theme';
import { textStyle, FeederTextStyles, M3Type, titleFontWeight, sansFamily } from './Typography';
import { FeederImage, RestrainedScale } from './CommonWidgets';
import { onKeyEventLikeEscape } from '../../core/platform/LayoutAdapt';

/** 源 ui/compose/Constants.kt minimumTouchSize */
export const MINIMUM_TOUCH_SIZE: number = 48;

/** 源 wordsToReadTimeSecs：round(words * 60 / 220.0)（Kotlin roundToInt：.5 向正无穷） */
export function wordsToReadTimeSecs(wordCount: number): number {
  return Math.round(wordCount * 60 / 220.0);
}

/** 两位补零（源 "%02d".format） */
function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 源 "${secs / 60}:%02d"（整除） */
export function readTimeClock(readTimeSecs: number): string {
  const minutes = Math.floor(readTimeSecs / 60);
  return `${minutes}:${pad2(readTimeSecs % 60)}`;
}

/** 源 CARD 缩略图过滤：已知宽/高 < 10px 的极小图不渲染（未知视为 1000） */
export function isThumbnailLargeEnough(image: ThumbnailImage | null): boolean {
  if (image === null) {
    return false;
  }
  const w: number = image.width === null ? 1000 : image.width;
  const h: number = image.height === null ? 1000 : image.height;
  return w >= 10 && h >= 10;
}

const HTTP_URL_RE: RegExp = new RegExp('^https?://[^\\s/?#@]+(:[0-9]*)?([/?#][^\\s]*)?$', 'i');

/** 源 String.toHttpUrlOrNull() != null：合法 http(s) URL（COMPACT_CARD 订阅源图标条件） */
export function isHttpUrl(url: string | null): boolean {
  if (url === null) {
    return false;
  }
  return HTTP_URL_RE.test(url.trim());
}

/** 占位条目（@Param 默认值 / 源 PLACEHOLDER_ITEM 的形状：全空、未读、id=ID_UNSET） */
export function emptyFeedListItem(): FeedListItem {
  return new FeedListItem(0, '', '', '', true, '', null, null, false, null, 0, null, 0);
}

/**
 * 条目动作回调（四种样式 + 外壳共用；一个实例可被整个列表复用，回调带条目参数）。
 * 默认实现只打日志（规则 H.4）；Feed 页用 SwipeableFeedItem.ets 的 createFeedItemHandlers 生成真实实现。
 */
export class FeedItemHandlers {
  /** 单击条目（FI-A09：具体打开方式由 Feed 页按 ItemOpener 决定） */
  onItemClick: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onItemClick:FeedItem ${itemId}`);
  };
  onOpenInReader: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onOpenInReader:FeedItem ${itemId}`);
  };
  onOpenInCustomTab: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onOpenInCustomTab:FeedItem ${itemId}`);
  };
  onOpenInBrowser: (itemId: number) => void = (itemId: number) => {
    console.info(`TODO:onOpenInBrowser:FeedItem ${itemId}`);
  };
  onToggleBookmark: (item: FeedListItem) => void = (item: FeedListItem) => {
    console.info(`TODO:onToggleBookmark:FeedItem ${item.id}`);
  };
  onMarkAboveAsRead: (item: FeedListItem) => void = (item: FeedListItem) => {
    console.info(`TODO:onMarkAboveAsRead:FeedItem ${item.id}`);
  };
  onMarkBelowAsRead: (item: FeedListItem) => void = (item: FeedListItem) => {
    console.info(`TODO:onMarkBelowAsRead:FeedItem ${item.id}`);
  };
  onShareItem: (item: FeedListItem) => void = (item: FeedListItem) => {
    console.info(`TODO:onShareItem:FeedItem ${item.id}`);
  };
  /** 源 onSwipe(Boolean)：参数为滑动前的 item.unread */
  onSwipe: (item: FeedListItem, currentUnread: boolean) => void = (item: FeedListItem, currentUnread: boolean) => {
    console.info(`TODO:onSwipe:FeedItem ${item.id} ${currentUnread}`);
  };
}

/** 源 sealed FeedItemEvent（菜单 7 项 + 关闭） */
export enum FeedItemEvent {
  OPEN_IN_READER = 0,
  OPEN_IN_CUSTOM_TAB = 1,
  OPEN_IN_BROWSER = 2,
  TOGGLE_BOOKMARKED = 3,
  MARK_ABOVE_AS_READ = 4,
  MARK_BELOW_AS_READ = 5,
  SHARE_ITEM = 6,
  DISMISS_DROPDOWN = 7,
}

/** 把菜单事件分派到回调（FI-A12/A13/A14/A15/A16 由回调实现） */
export function dispatchFeedItemEvent(handlers: FeedItemHandlers, item: FeedListItem, event: FeedItemEvent): void {
  switch (event) {
    case FeedItemEvent.OPEN_IN_READER:
      handlers.onOpenInReader(item.id);
      break;
    case FeedItemEvent.OPEN_IN_CUSTOM_TAB:
      handlers.onOpenInCustomTab(item.id);
      break;
    case FeedItemEvent.OPEN_IN_BROWSER:
      handlers.onOpenInBrowser(item.id);
      break;
    case FeedItemEvent.TOGGLE_BOOKMARKED:
      handlers.onToggleBookmark(item);
      break;
    case FeedItemEvent.MARK_ABOVE_AS_READ:
      handlers.onMarkAboveAsRead(item);
      break;
    case FeedItemEvent.MARK_BELOW_AS_READ:
      handlers.onMarkBelowAsRead(item);
      break;
    case FeedItemEvent.SHARE_ITEM:
      handlers.onShareItem(item);
      break;
    default:
      break;
  }
}

/**
 * 复数串（源 pluralStringResource(id, count).format(arg)）。
 * 资源中 plural 值若为对另一字符串的引用（`@string/x` / `$string:x`，前场照搬 Android 写法），按名再取一次；
 * 统一把 `%1$s` / `%s` 替换为 arg。全部失败时回落英文 `<arg> <fallbackUnit>`。
 */
export function pluralText(ui: UIContext, res: Resource, count: number, arg: string, fallbackUnit: string): string {
  let raw: string = '';
  try {
    const ctx = ui.getHostContext();
    if (ctx !== undefined) {
      raw = ctx.resourceManager.getIntPluralStringValueSync(res.id, count, arg);
      const t = raw.trim();
      let refName: string | null = null;
      if (t.startsWith('@string/')) {
        refName = t.substring('@string/'.length);
      } else if (t.startsWith('$string:')) {
        refName = t.substring('$string:'.length);
      }
      if (refName !== null) {
        raw = ctx.resourceManager.getStringByNameSync(refName);
      }
    }
  } catch (e) {
    console.warn(`FeedItemText: plural lookup failed: ${JSON.stringify(e)}`);
    raw = '';
  }
  if (raw === '') {
    return `${arg} ${fallbackUnit}`;
  }
  return raw.replace('%1$s', arg).replace('%1$d', arg).replace('%s', arg).replace('%d', arg);
}

// ================================================================== 指示器（FeedItemIndicator.kt）

/** 源 FeedItemSavedIndicator：Icons.Default.Star、primary 着色、cd `Saved article` */
@ComponentV2
export struct FeedItemSavedIndicator {
  @Param iconSize: number = 24;

  build() {
    // 源 Box(contentAlignment = Center)
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.star_fill'))
        .fontSize(`${this.iconSize}vp`)
        .fontColor([FeederTheme.colors.primary])
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .accessibilityText($r('app.string.saved_article'))
  }
}

/** 源 FeedItemNewIndicator：Icons.Outlined.Circle、primary 着色、cd `Unread`（仅 COMPACT_CARD 使用） */
@ComponentV2
export struct FeedItemNewIndicator {
  @Param iconSize: number = 24;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.circle'))
        .fontSize(`${this.iconSize}vp`)
        .fontColor([FeederTheme.colors.primary])
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .accessibilityText($r('app.string.unread_adjective'))
  }
}

/** 源 FeedItemFeedIconIndicator：订阅源图标，Fit，无障碍不朗读 */
@ComponentV2
export struct FeedItemFeedIconIndicator {
  @Param feedImageUrl: string = '';
  @Param iconSize: number = 24;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      FeederImage({
        url: this.feedImageUrl,
        scaleMode: RestrainedScale.FIT,
        boxWidth: this.iconSize,
        boxHeightVp: this.iconSize,
        iconSize: this.iconSize,
        altText: ''
      })
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .accessibilityLevel('no')
  }
}

/**
 * 源 FeedItemEitherIndicator：收藏 → 星标；否则订阅源图标；否则等尺寸空白。
 * （源 itemImage 分支所有调用方都传 null，未读分支被注释掉——未读圆点不在此出现。）
 */
@ComponentV2
export struct FeedItemEitherIndicator {
  @Param bookmarked: boolean = false;
  @Param feedImageUrl: string | null = null;
  @Param iconSize: number = 8;

  build() {
    if (this.bookmarked) {
      FeedItemSavedIndicator({ iconSize: this.iconSize })
    } else if (this.feedImageUrl !== null) {
      FeedItemFeedIconIndicator({ feedImageUrl: this.feedImageUrl as string, iconSize: this.iconSize })
    } else {
      Column()
        .width(this.iconSize)
        .height(this.iconSize)
    }
  }
}

// ================================================================== 文本块

/**
 * 源 RowScope.FeedItemText。宽度撑满父容器（调用方用外层 Column.layoutWeight(1) 表达源 weight(1f)）。
 * 长按菜单由外壳 SwipeableFeedItem 持有展开状态（menuShown），本组件负责渲染与分派；
 * 点任一菜单项：先 onDismissMenu 再执行动作；点外部/返回仅关闭（FI-A10/A11）。
 */
@ComponentV2
export struct FeedItemText {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param maxLines: number = 2;
  @Param showOnlyTitle: boolean = false;
  @Param showReadingTime: boolean = false;
  /** 文字色；空串 = 当前内容色 onSurface（源 LocalContentColor） */
  @Param textColor: string = '';
  @Param menuShown: boolean = false;
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  @Event onDismissMenu: () => void = () => {
    console.debug('FeedItemText: dismiss menu');
  };

  private color(): ResourceColor {
    return this.textColor === '' ? FeederTheme.colors.onSurface : this.textColor;
  }

  private hasTitle(): boolean {
    return this.item.title.trim().length > 0;
  }

  private showSnippetSpan(): boolean {
    return this.hasTitle() && !this.showOnlyTitle && this.item.snippet.trim().length > 0;
  }

  private firstSpanText(): string {
    return this.hasTitle() ? this.item.title : this.item.snippet;
  }

  private snippetSpanText(): string {
    return this.showSnippetSpan() ? `\n${this.item.snippet}` : '';
  }

  /** 合并文本的纯文本（用于判定段落方向） */
  private joinedText(): string {
    if (this.hasTitle()) {
      return this.showSnippetSpan() ? `${this.item.title}\n${this.item.snippet}` : this.item.title;
    }
    return this.item.snippet;
  }

  private dir(text: string): Direction {
    return isRtlText(text) ? Direction.Rtl : Direction.Ltr;
  }

  private readTimeSecs(): number {
    return wordsToReadTimeSecs(this.item.wordCount);
  }

  private readTimeText(): string {
    const secs = this.readTimeSecs();
    return pluralText(this.getUIContext(), $r('app.plural.n_minutes'), Math.floor(secs / 60), readTimeClock(secs),
      'minutes');
  }

  private wordCountText(): string {
    return pluralText(this.getUIContext(), $r('app.plural.n_words'), this.item.wordCount, `${this.item.wordCount}`,
      'words');
  }

  private onMenuEvent(event: FeedItemEvent): void {
    this.onDismissMenu();
    dispatchFeedItemEvent(this.handlers, this.item, event);
  }

  @Builder
  itemMenuBuilder() {
    Menu() {
      MenuItem({ content: $r('app.string.open_article_in_reader') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.OPEN_IN_READER);
        })
      MenuItem({ content: $r('app.string.open_article_in_custom_tab') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.OPEN_IN_CUSTOM_TAB);
        })
      MenuItem({ content: $r('app.string.open_article_in_default_browser') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.OPEN_IN_BROWSER);
        })
      MenuItem({ content: this.item.bookmarked ? $r('app.string.unsave_article') : $r('app.string.save_article') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.TOGGLE_BOOKMARKED);
        })
      MenuItem({ content: $r('app.string.mark_items_above_as_read') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.MARK_ABOVE_AS_READ);
        })
      MenuItem({ content: $r('app.string.mark_items_below_as_read') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.MARK_BELOW_AS_READ);
        })
      MenuItem({ content: $r('app.string.share') })
        .onClick(() => {
          this.onMenuEvent(FeedItemEvent.SHARE_ITEM);
        })
    }
    // UT-A44：源 FeedItemCard.kt:268 DropdownMenu.onKeyEventLikeEscape（Escape/Back 关闭菜单）
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.onDismissMenu();
    }))
  }

  build() {
    Column({ space: 4 }) {
      // 1. 合并文本（标题样式 titleMedium + 未读字重；摘要 Span = titleSmall）
      // 源：title 非空白 → title [+ '\n' + snippet（摘要样式）]；title 空白 → 仅 snippet（有源没有标题）
      Text() {
        Span(this.firstSpanText())
        Span(this.snippetSpanText())
          .fontSize(FeederTextStyles.feedListItemSnippet.size)
          .lineHeight(FeederTextStyles.feedListItemSnippet.lineHeight)
          .fontWeight(FeederTextStyles.feedListItemSnippet.weight)
          .letterSpacing(FeederTextStyles.feedListItemSnippet.letterSpacing)
          .fontFamily(sansFamily())
          .fontColor(this.color())
      }
      .attributeModifier(textStyle(FeederTextStyles.feedListItemTitle.withWeight(titleFontWeight(this.item.unread)),
        false, this.color()))
      .maxLines(this.maxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .wordBreak(WordBreak.BREAK_WORD)
      .direction(this.dir(this.joinedText()))
      .textAlign(TextAlign.Start)
      .width('100%')

      // 2. 订阅源名 + 日期（长按菜单锚点）
      Row({ space: 4 }) {
        Text(this.item.feedTitle)
          .attributeModifier(textStyle(FeederTextStyles.feedListItemFeedTitle, false, this.color()))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .direction(this.dir(this.item.feedTitle))
          .textAlign(TextAlign.Start)
          .layoutWeight(1)
        Text(this.item.pubDate)
          .attributeModifier(textStyle(FeederTextStyles.feedListItemDate, false, this.color()))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
          .direction(this.dir(this.item.pubDate))
          .textAlign(TextAlign.Start)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)
      .bindMenu(this.menuShown, () => {
        this.itemMenuBuilder();
      }, {
        onDisappear: () => {
          // 点菜单外部 / 返回键 / 选中菜单项后菜单消失：同步收起状态
          this.onDismissMenu();
        }
      })

      // 3. 阅读时长
      if (this.showReadingTime && this.readTimeSecs() > 0) {
        Row({ space: 4 }) {
          Text(this.readTimeText())
            .attributeModifier(textStyle(FeederTextStyles.feedListItemFeedTitle, false, this.color()))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .direction(this.dir(this.readTimeText()))
            .textAlign(TextAlign.Start)
            .layoutWeight(1)
          Text(this.wordCountText())
            .attributeModifier(textStyle(FeederTextStyles.feedListItemFeedTitle, false, this.color()))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .direction(this.dir(this.wordCountText()))
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}

// ================================================================== 无障碍自定义动作（FI-A26）

/**
 * 读屏（屏幕朗读）开关状态单例：模块内只订阅一次 screenReaderStateChange（不随列表项增减反复注册）。
 */
@ObservedV2
export class ScreenReaderState {
  @Trace enabled: boolean = false;
  private static inst: ScreenReaderState | null = null;

  static instance(): ScreenReaderState {
    if (ScreenReaderState.inst === null) {
      const s = new ScreenReaderState();
      try {
        s.enabled = accessibility.isScreenReaderOpenSync();
        accessibility.on('screenReaderStateChange', (on: boolean) => {
          s.enabled = on;
        });
      } catch (e) {
        console.warn(`FeedItemText: screen reader state unavailable: ${JSON.stringify(e)}`);
      }
      ScreenReaderState.inst = s;
    }
    return ScreenReaderState.inst as ScreenReaderState;
  }
}

/**
 * 源 SwipeableFeedItemPreview.kt:180-226 semantics.customActions 的鸿蒙等价实现。
 * ArkUI（API 24）无“自定义无障碍动作”属性（仅 accessibilityActionOptions.scrollStep / 点击拦截），
 * 故在读屏开启时于条目下方渲染 8 个可被读屏逐个聚焦、双击执行的动作按钮（顺序与文案同源）：
 *  Toggle read status（= 一次滑动切换：onSwipe(item, item.unread)）+ 长按菜单 7 项（同名同效，经 dispatchFeedItemEvent）。
 * 读屏关闭时不渲染任何内容，视觉与源一致。
 */
@ComponentV2
export struct FeedItemAccessibilityActions {
  @Param item: FeedListItem = emptyFeedListItem();
  @Param handlers: FeedItemHandlers = new FeedItemHandlers();
  @Local srState: ScreenReaderState = ScreenReaderState.instance();

  @Builder
  actionBuilder(label: ResourceStr, action: () => void) {
    Text(label)
      .attributeModifier(textStyle(M3Type.labelLarge, true, FeederTheme.colors.primary))
      .constraintSize({ minHeight: MINIMUM_TOUCH_SIZE })
      .padding({ left: 12, right: 12 })
      .textAlign(TextAlign.Center)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .onClick(() => {
        action();
      })
  }

  build() {
    if (this.srState.enabled) {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        this.actionBuilder($r('app.string.toggle_read_status'), () => {
          this.handlers.onSwipe(this.item, this.item.unread);
        })
        this.actionBuilder($r('app.string.open_article_in_reader'), () => {
          dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.OPEN_IN_READER);
        })
        this.actionBuilder($r('app.string.open_article_in_custom_tab'), () => {
          dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.OPEN_IN_CUSTOM_TAB);
        })
        this.actionBuilder($r('app.string.open_article_in_default_browser'), () => {
          dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.OPEN_IN_BROWSER);
        })
        this.actionBuilder(this.item.bookmarked ? $r('app.string.unsave_article') : $r('app.string.save_article'),
          () => {
            dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.TOGGLE_BOOKMARKED);
          })
        this.actionBuilder($r('app.string.mark_items_above_as_read'), () => {
          dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.MARK_ABOVE_AS_READ);
        })
        this.actionBuilder($r('app.string.mark_items_below_as_read'), () => {
          dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.MARK_BELOW_AS_READ);
        })
        this.actionBuilder($r('app.string.share'), () => {
          dispatchFeedItemEvent(this.handlers, this.item, FeedItemEvent.SHARE_ITEM);
        })
      }
      .width('100%')
    }
  }
}
