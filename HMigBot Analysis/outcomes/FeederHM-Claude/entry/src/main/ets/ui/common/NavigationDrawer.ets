/*
 * NavigationDrawer — 源 ui/compose/material3/NavigationDrawer.kt（DrawerState / DismissibleNavigationDrawer /
 * DismissibleDrawerSheet）与 tokens/NavigationDrawerTokens.getContainerWidth 的鸿蒙实现。
 *
 * 只移植源实际生效的 Dismissible 路径（Modal/Permanent/NavigationDrawerItem 在源中为死代码，见 explore/ui-material.md §2）：
 *  - 推挤式：抽屉在起始边，主内容整体平移 = 抽屉宽度 + offset，无遮罩、主内容仍可交互（UM-A01）；
 *  - 两锚点 {-width: Closed, 0: Open}，水平拖动/甩动：越过中点(50%)或速度 ≥ 400vp/s 落到对应端，否则回弹（UM-A03）；
 *  - RTL：抽屉在右侧，拖动方向镜像（UM-A04）；
 *  - 宽度 = min(360vp, 屏宽)，竖直折痕时止于折痕 − gutter/2；抽屉 sheet 最小 240vp（UM-A05/UM-A06）；
 *  - 动画 TweenSpec(256ms, FastOutSlowIn)；currentValue 仅在落到锚点后更新（UM-A12）。
 * 平台 SideBarContainer 无法表达"推挤平移 + 50%/400vp/s 判定"，故自绘（Stack + translate + PanGesture + Animator）。
 */
import { AnimatorResult, LengthMetrics, window } from '@kit.ArkUI';
import { accessibility } from '@kit.AccessibilityKit';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { FoldableHinge, LayoutAdapt, onKeyEventLikeEscape, WindowMetrics } from '../../core/platform/LayoutAdapt';
import { FeederTheme, screenDensity } from './Theme';

/** 源 NavigationDrawerTokens.ContainerWidth */
export const DRAWER_CONTAINER_WIDTH_VP: number = 360;
/** 源 MinimumDrawerWidth */
export const DRAWER_MIN_WIDTH_VP: number = 240;
/** 源 DrawerVelocityThreshold = 400.dp（/s） */
export const DRAWER_VELOCITY_THRESHOLD_VP: number = 400;
/** 源 AnimationSpec = TweenSpec(durationMillis = 256)，默认 easing FastOutSlowInEasing */
export const DRAWER_ANIMATION_MS: number = 256;
const FAST_OUT_SLOW_IN: string = 'cubic-bezier(0.4, 0.0, 0.2, 1.0)';
const LOG_TAG: string = 'FEEDER_DRAWER';

/** 源 enum DrawerValue */
export enum DrawerValue {
  Closed = 0,
  Open = 1
}

/**
 * 源 NavigationDrawerTokens.getContainerWidth()：
 * 竖直折痕（hinge.top == 0）时 = (LTR ? hinge.left : 屏宽 − hinge.right) − gutter/2，否则 360；最终不超过屏宽。
 */
export function computeDrawerContainerWidth(screenWidthVp: number, hinge: FoldableHinge | null, gutterVp: number,
  isRtl: boolean): number {
  let w: number = DRAWER_CONTAINER_WIDTH_VP;
  if (hinge !== null && hinge.isTopToBottom) {
    w = (isRtl ? screenWidthVp - hinge.right : hinge.left) - gutterVp / 2;
  }
  return Math.min(w, screenWidthVp);
}

/**
 * 源 SwipeableState.computeTarget（两锚点 lower=-width / upper=0，FractionalThreshold(0.5)）。
 * offset/lastValue/velocity 均已换算到"抽屉坐标"（向打开方向为正，RTL 已镜像）。返回目标锚点 offset。
 */
export function computeDrawerTarget(offset: number, lastValue: number, widthVp: number, velocity: number,
  velocityThreshold: number): number {
  const lower: number = -widthVp;
  const upper: number = 0;
  if (offset <= lower) {
    return lower;
  }
  if (offset >= upper) {
    return upper;
  }
  if (lastValue <= offset) {
    // 向打开方向（正）滑动
    if (velocity >= velocityThreshold) {
      return upper;
    }
    const threshold: number = lower + (upper - lower) * 0.5;
    return offset < threshold ? lower : upper;
  }
  // 向关闭方向（负）滑动
  if (velocity <= -velocityThreshold) {
    return lower;
  }
  const threshold: number = upper + (lower - upper) * 0.5;
  return offset > threshold ? upper : lower;
}

/**
 * 源 DismissibleDrawerSheet.sizeIn(minWidth = MinimumDrawerWidth, maxWidth = containerWidth)：
 * Compose 约束 min > max 时 min 被压到 max，故屏宽/折痕宽 < 240vp 时 sheet 宽 = 容器宽（不超出锚点）。
 * sheet 内容（列表行 fillMaxWidth）撑满上限 → 宽度取上限。
 */
export function computeDrawerSheetWidth(containerWidthVp: number): number {
  const maxW: number = Math.max(0, containerWidthVp);
  const minW: number = Math.min(DRAWER_MIN_WIDTH_VP, maxW);
  return Math.max(minW, maxW);
}

/** 避让区起始边宽度（vp）：LTR 取 leftRect，RTL 取 rightRect（源 WindowInsetsSides.Start） */
export function avoidAreaStartVp(area: window.AvoidArea, isRtl: boolean, density: number): number {
  const r: window.Rect = isRtl ? area.rightRect : area.leftRect;
  const d: number = density > 0 ? density : 1;
  return r.width > 0 ? r.width / d : 0;
}

/** 当前系统语言是否 RTL（LocalLayoutDirection 等价） */
export function isRtlLayout(): boolean {
  try {
    return i18n.isRTL(i18n.System.getSystemLanguage());
  } catch (e) {
    return false;
  }
}

/**
 * 源 class DrawerState（+ 内部 SwipeableState 的两锚点子集）。
 * - offset：vp，Closed = -widthVp，Open = 0；
 * - isOpen/isClosed 由 currentValue 决定；currentValue 仅在动画/拖动结束落到锚点后更新；
 * - open()/close() 为异步动画（Promise 在动画结束或被中断时 resolve；源被中断时抛 CancellationException，此处不抛）；
 *   被新动画/拖动中断时，若 offset 距某锚点 < 0.5px 则 currentValue 定为该锚点，否则保留原值（UM-A12）；
 * - 首次布局（宽度未知）前调用 open()/close() 会挂起到宽度就绪（源 latestNonEmptyAnchorsFlow）。
 * 页面持有实例：ArkUI 旋转/深浅色切换不重建组件，开关态天然保持（UM-A11，源 rememberSaveable + saver）。
 */
@ObservedV2
export class DrawerState {
  @Trace currentValue: DrawerValue = DrawerValue.Closed;
  @Trace targetValue: DrawerValue = DrawerValue.Closed;
  @Trace offset: number = 0;
  @Trace widthVp: number = 0;
  @Trace isAnimationRunning: boolean = false;
  @Trace isDragging: boolean = false;

  private uiCtx: UIContext | null = null;
  private anim: AnimatorResult | null = null;
  private animToken: number = 0;
  private animResolve: (() => void) | null = null;
  private pendingTarget: DrawerValue | null = null;
  private pendingResolves: (() => void)[] = [];
  private dragStartOffset: number = 0;

  constructor(initialValue: DrawerValue = DrawerValue.Closed) {
    this.currentValue = initialValue;
    this.targetValue = initialValue;
  }

  get isOpen(): boolean {
    return this.currentValue === DrawerValue.Open;
  }

  get isClosed(): boolean {
    return this.currentValue === DrawerValue.Closed;
  }

  /** 抽屉 sheet 是否需要渲染（完全收起且静止时隐藏，避免屏外内容获焦/被读屏） */
  get sheetVisible(): boolean {
    if (this.widthVp <= 0) {
      return false;
    }
    return this.isDragging || this.isAnimationRunning || this.offset > -this.widthVp + 0.01;
  }

  anchorOf(value: DrawerValue): number {
    return value === DrawerValue.Open ? 0 : -this.widthVp;
  }

  /** 源 open()：动画打开 */
  open(): Promise<void> {
    return this.animateTo(DrawerValue.Open);
  }

  /** 源 close()：动画关闭 */
  close(): Promise<void> {
    return this.animateTo(DrawerValue.Closed);
  }

  /** 源 BackHandler(enabled = drawerState.isOpen) { close() }：页面 onBackPressed 调用；已处理返回 true */
  handleBack(): boolean {
    if (this.isOpen) {
      this.close();
      return true;
    }
    return false;
  }

  /** 源 snapTo：无动画直接落到锚点 */
  snapTo(target: DrawerValue): void {
    this.interrupt();
    this.targetValue = target;
    this.currentValue = target;
    if (this.widthVp > 0) {
      this.offset = this.anchorOf(target);
    }
  }

  /** 源 animateTo(targetValue, TweenSpec(256)) */
  animateTo(target: DrawerValue): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      if (this.widthVp <= 0) {
        // 锚点未就绪：挂起到首次布局
        this.pendingTarget = target;
        this.pendingResolves.push(resolve);
        return;
      }
      this.startAnimation(target, resolve);
    });
  }

  // ---------------------------------------------------------------- 组件内部接口（NavigationDrawer 调用）

  attachContext(ctx: UIContext): void {
    this.uiCtx = ctx;
  }

  detachContext(): void {
    this.interrupt();
    this.uiCtx = null;
  }

  /** 锚点宽度变化（首次布局 / 旋转 / 折叠状态变化）：源 processNewAnchors 的简化——落到新锚点 */
  setAnchorWidth(widthVp: number): void {
    if (widthVp <= 0 || Math.abs(widthVp - this.widthVp) < 0.01) {
      return;
    }
    this.widthVp = widthVp;
    if (this.isDragging) {
      this.offset = Math.max(-widthVp, Math.min(0, this.offset));
    } else if (this.isAnimationRunning) {
      const t: DrawerValue = this.targetValue;
      const prev: (() => void) | null = this.takeResolve();
      this.startAnimation(t, () => {
        if (prev !== null) {
          prev();
        }
      });
    } else {
      this.offset = this.anchorOf(this.currentValue);
    }
    if (this.pendingTarget !== null) {
      const t: DrawerValue = this.pendingTarget as DrawerValue;
      const resolves: (() => void)[] = this.pendingResolves;
      this.pendingTarget = null;
      this.pendingResolves = [];
      this.startAnimation(t, () => {
        for (const r of resolves) {
          r();
        }
      });
    }
  }

  /** 拖动开始：源 startDragImmediately = isAnimationRunning（动画中可直接抓住） */
  dragStart(): void {
    if (this.widthVp <= 0) {
      return;
    }
    this.interrupt();
    this.isDragging = true;
    this.dragStartOffset = this.offset;
  }

  /** deltaVp：自拖动开始的累计位移（已按 RTL 镜像为"打开方向为正"）；resistance = null → 硬夹紧 */
  dragUpdate(deltaVp: number): void {
    if (!this.isDragging) {
      return;
    }
    this.offset = Math.max(-this.widthVp, Math.min(0, this.dragStartOffset + deltaVp));
  }

  /** 松手：源 performFling(velocity) → computeTarget → animateTo */
  dragEnd(velocityVp: number): void {
    if (!this.isDragging) {
      return;
    }
    this.isDragging = false;
    const lastValue: number = this.anchorOf(this.currentValue);
    const targetOffset: number = computeDrawerTarget(this.offset, lastValue, this.widthVp, velocityVp,
      DRAWER_VELOCITY_THRESHOLD_VP);
    const target: DrawerValue = targetOffset === 0 ? DrawerValue.Open : DrawerValue.Closed;
    this.startAnimation(target, () => {
    });
  }

  dragCancel(): void {
    if (!this.isDragging) {
      return;
    }
    this.isDragging = false;
    this.startAnimation(this.currentValue, () => {
    });
  }

  // ---------------------------------------------------------------- 动画

  private takeResolve(): (() => void) | null {
    const r: (() => void) | null = this.animResolve;
    this.animResolve = null;
    return r;
  }

  /** 中断正在进行的动画：按最近锚点（< 0.5px）定值，否则保留原 currentValue */
  private interrupt(): void {
    if (this.anim === null) {
      return;
    }
    const a: AnimatorResult = this.anim as AnimatorResult;
    this.anim = null;
    this.animToken++;
    try {
      a.cancel();
    } catch (e) {
      console.warn(`${LOG_TAG}: cancel failed: ${(e as Error)?.message}`);
    }
    this.settleNearestAnchor();
    this.isAnimationRunning = false;
    const r: (() => void) | null = this.takeResolve();
    if (r !== null) {
      r();
    }
  }

  private settleNearestAnchor(): void {
    const halfPxVp: number = 0.5 / screenDensity();
    if (Math.abs(this.offset - this.anchorOf(DrawerValue.Open)) < halfPxVp) {
      this.currentValue = DrawerValue.Open;
    } else if (Math.abs(this.offset - this.anchorOf(DrawerValue.Closed)) < halfPxVp) {
      this.currentValue = DrawerValue.Closed;
    }
    this.targetValue = this.currentValue;
  }

  private finishAt(target: DrawerValue): void {
    this.offset = this.anchorOf(target);
    this.currentValue = target;
    this.targetValue = target;
    this.isAnimationRunning = false;
  }

  private startAnimation(target: DrawerValue, resolve: () => void): void {
    this.interrupt();
    const from: number = this.offset;
    const to: number = this.anchorOf(target);
    this.targetValue = target;
    const ctx: UIContext | null = this.uiCtx;
    if (ctx === null || Math.abs(from - to) < 0.01) {
      this.finishAt(target);
      resolve();
      return;
    }
    const token: number = ++this.animToken;
    let a: AnimatorResult;
    try {
      a = ctx.createAnimator({
        duration: DRAWER_ANIMATION_MS,
        easing: FAST_OUT_SLOW_IN,
        delay: 0,
        fill: 'forwards',
        direction: 'normal',
        iterations: 1,
        begin: 0,
        end: 1
      });
    } catch (e) {
      console.warn(`${LOG_TAG}: createAnimator failed: ${(e as Error)?.message}`);
      this.finishAt(target);
      resolve();
      return;
    }
    this.anim = a;
    this.animResolve = resolve;
    this.isAnimationRunning = true;
    a.onFrame = (progress: number): void => {
      if (token === this.animToken) {
        this.offset = from + (to - from) * progress;
      }
    };
    a.onFinish = (): void => {
      if (token !== this.animToken) {
        return;
      }
      this.anim = null;
      this.finishAt(target);
      const r: (() => void) | null = this.takeResolve();
      if (r !== null) {
        r();
      }
    };
    a.onCancel = (): void => {
      // 由 interrupt() 统一处理（token 已失效）
    };
    a.play();
  }
}

@Builder
function emptyDrawerBuilder() {
}

/**
 * 源 DismissibleNavigationDrawer + DismissibleDrawerSheet。
 * 用法（页面）：
 *   NavigationDrawer({ drawerState: this.drawerState, avoidTop: avoid.top, avoidBottom: avoid.bottom,
 *     focusKeyOnOpen: DRAWER_LIST_FOCUS_KEY,
 *     drawerContentBuilder: (): void => { this.drawerBuilder() }, contentBuilder: (): void => { this.bodyBuilder() } })
 * 系统返回键由页面 NavDestination.onBackPressed 调 drawerState.handleBack()。
 */
@ComponentV2
export struct NavigationDrawer {
  @Param drawerState: DrawerState = new DrawerState(DrawerValue.Closed);
  /** 源 gesturesEnabled（Feed 页为 true） */
  @Param gesturesEnabled: boolean = true;
  /** 源 DrawerDefaults.windowInsets = systemBars.only(Vertical + Start)（vp，来自 AppStorageV2 AvoidArea） */
  @Param avoidTop: number = 0;
  @Param avoidBottom: number = 0;
  @Param avoidStart: number = 0;
  /** 抽屉变为打开后请求焦点的组件 id（源 focusRequester.requestFocus()，UM-A09） */
  @Param focusKeyOnOpen: string = '';
  @BuilderParam drawerContentBuilder: () => void = emptyDrawerBuilder;
  @BuilderParam contentBuilder: () => void = emptyDrawerBuilder;

  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local measuredWidth: number = 0;
  @Local rtl: boolean = false;
  /** 起始边系统栏避让（vp）：TYPE_SYSTEM（状态栏/三键导航栏）与 TYPE_NAVIGATION_INDICATOR 的起始侧（UM-A07） */
  @Local sysStartInset: number = 0;
  @Local navStartInset: number = 0;
  private win: window.Window | null = null;
  private avoidCb: ((opts: window.AvoidAreaOptions) => void) | null = null;

  aboutToAppear(): void {
    this.rtl = isRtlLayout();
    this.drawerState.attachContext(this.getUIContext());
    this.syncWidth();
    this.attachSideInsets();
  }

  aboutToDisappear(): void {
    this.detachSideInsets();
    this.drawerState.detachContext();
  }

  /**
   * 源 DrawerDefaults.windowInsets = systemBarsForVisualComponents.only(Vertical + Start)：
   * 顶/底由页面传入（AppStorageV2 AvoidArea 契约只含 top/bottom）；起始边（横屏侧置导航栏等）此处直接读窗口避让区并订阅变化。
   */
  private attachSideInsets(): void {
    try {
      const name: string | undefined = this.getUIContext().getWindowName();
      if (name === undefined) {
        return;
      }
      const w: window.Window = window.findWindow(name);
      this.win = w;
      this.sysStartInset = avoidAreaStartVp(w.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM), this.rtl,
        screenDensity());
      this.navStartInset = avoidAreaStartVp(w.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR),
        this.rtl, screenDensity());
      const cb = (opts: window.AvoidAreaOptions): void => {
        if (opts.type === window.AvoidAreaType.TYPE_SYSTEM) {
          this.sysStartInset = avoidAreaStartVp(opts.area, this.rtl, screenDensity());
        } else if (opts.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.navStartInset = avoidAreaStartVp(opts.area, this.rtl, screenDensity());
        }
      };
      w.on('avoidAreaChange', cb);
      this.avoidCb = cb;
    } catch (e) {
      console.warn(`${LOG_TAG}: side insets unavailable: ${(e as Error)?.message}`);
    }
  }

  private detachSideInsets(): void {
    const w: window.Window | null = this.win;
    const cb: ((opts: window.AvoidAreaOptions) => void) | null = this.avoidCb;
    if (w !== null && cb !== null) {
      try {
        w.off('avoidAreaChange', cb);
      } catch (e) {
        console.warn(`${LOG_TAG}: off avoidAreaChange failed: ${(e as Error)?.message}`);
      }
    }
    this.win = null;
    this.avoidCb = null;
  }

  private startInset(): number {
    return Math.max(this.avoidStart, this.sysStartInset, this.navStartInset);
  }

  /**
   * 源 paneTitle = "Navigation menu"：Android 读屏在窗格出现时播报窗格标题。ArkUI 无 paneTitle 语义，
   * 等价做法：抽屉落到 Open 时（读屏开启）主动播报同一字符串；sheet 容器同时以其为无障碍文本。
   */
  private announcePaneTitle(): void {
    try {
      if (!accessibility.isScreenReaderOpenSync()) {
        return;
      }
      const ctx: common.Context | undefined = this.getUIContext().getHostContext() as common.Context | undefined;
      if (ctx === undefined) {
        return;
      }
      const label: string = ctx.resourceManager.getStringSync($r('app.string.hm_navigation_menu').id);
      const ev: accessibility.EventInfo = new accessibility.EventInfo('announceForAccessibility',
        ctx.applicationInfo.name, 'common');
      ev.textAnnouncedForAccessibility = label;
      accessibility.sendAccessibilityEvent(ev).catch((e: Error) => {
        console.info(`${LOG_TAG}: announce pane title failed: ${e?.message}`);
      });
    } catch (e) {
      console.info(`${LOG_TAG}: announce pane title skipped: ${(e as Error)?.message}`);
    }
  }

  @Monitor('metrics.widthVp', 'metrics.hinge', 'measuredWidth')
  onMetricsChanged(): void {
    this.syncWidth();
  }

  @Monitor('drawerState.currentValue')
  onDrawerValueChanged(): void {
    if (this.drawerState.isOpen) {
      this.announcePaneTitle();
    }
    if (this.drawerState.isOpen && this.focusKeyOnOpen.length > 0) {
      try {
        this.getUIContext().getFocusController().requestFocus(this.focusKeyOnOpen);
      } catch (e) {
        console.info(`${LOG_TAG}: requestFocus skipped: ${(e as Error)?.message}`);
      }
    }
  }

  private screenWidth(): number {
    return this.measuredWidth > 0 ? this.measuredWidth : this.metrics.widthVp;
  }

  private syncWidth(): void {
    const w: number = computeDrawerContainerWidth(this.screenWidth(), this.metrics.hinge, FeederTheme.dimens.gutter,
      this.rtl);
    this.drawerState.setAnchorWidth(w);
  }

  /** 源 DismissibleDrawerSheet sizeIn(minWidth = 240, maxWidth = containerWidth) */
  private sheetWidth(): number {
    return computeDrawerSheetWidth(this.drawerState.widthVp);
  }

  private dirSign(): number {
    return this.rtl ? -1 : 1;
  }

  /** 源 contentPlaceable.placeRelative(sheetWidth + offset, 0)；宽度未就绪时不平移 */
  private contentShift(): number {
    if (this.drawerState.widthVp <= 0) {
      return 0;
    }
    return (this.sheetWidth() + this.drawerState.offset) * this.dirSign();
  }

  /** 源 sheetPlaceable.placeRelative(offset, 0) */
  private sheetShift(): number {
    if (this.drawerState.widthVp <= 0) {
      return -DRAWER_CONTAINER_WIDTH_VP * this.dirSign();
    }
    return this.drawerState.offset * this.dirSign();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.contentBuilder()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .translate({ x: this.contentShift() })

      Column() {
        this.drawerContentBuilder()
      }
      .width(this.sheetWidth())
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        top: LengthMetrics.vp(this.avoidTop),
        bottom: LengthMetrics.vp(this.avoidBottom),
        start: LengthMetrics.vp(this.startInset())
      })
      .backgroundColor(FeederTheme.colors.surface)
      .translate({ x: this.sheetShift() })
      .visibility(this.drawerState.sheetVisible ? Visibility.Visible : Visibility.Hidden)
      .accessibilityText($r('app.string.hm_navigation_menu'))
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
      const w: number = Number(newValue.width);
      if (!isNaN(w) && w > 0) {
        this.measuredWidth = w;
      }
    })
    .gesture(
      PanGesture({ direction: this.gesturesEnabled ? PanDirection.Horizontal : PanDirection.None })
        .onActionStart((event: GestureEvent) => {
          this.drawerState.dragStart();
        })
        .onActionUpdate((event: GestureEvent) => {
          this.drawerState.dragUpdate(event.offsetX * this.dirSign());
        })
        .onActionEnd((event: GestureEvent) => {
          this.drawerState.dragEnd(event.velocityX * this.dirSign());
        })
        .onActionCancel(() => {
          this.drawerState.dragCancel();
        })
    )
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.drawerState.close();
    }))
  }
}
