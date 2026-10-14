/*
 * CommonWidgets — 源 ui/compose/{modifiers,coil,pullrefresh,components}/* 的鸿蒙实现：
 *  按键拦截（KeyEvents.kt）、可见性追踪（TrackVisibility.kt）、受限缩放 + 图片加载（coil/*、FeederApplication ImageLoader）、
 *  下拉刷新（pullrefresh/* → ArkUI Refresh）、底部操作栏（BottomAppBar.kt）、翻译下载进度（TranslationProgressContent.kt）、
 *  表单 OK/Cancel（OkCancel.kt）、响应式尺寸（再导出 Theme.Dimensions）。自动补全在 Dialogs.ets，UI 启动入口在 Theme.ets。
 */
import { image } from '@kit.ImageKit';
import { HttpClient } from '../../core/net/HttpClient';
import { HttpDiskCache } from '../../core/net/HttpCache';
import { HttpRequest, HttpResponse } from '../../core/net/HttpMessages';
import { FeederTheme, Dimensions, screenDensity } from './Theme';
import { textStyle, M3Type, buttonLabelStyle } from './Typography';

export { Dimensions, phoneDimensions, tabletDimensions, selectDimensions } from './Theme';

/** 当前响应式尺寸（build 中读取即随窗口变化重绘） */
export function currentDimens(): Dimensions {
  return FeederTheme.dimens;
}

// ================================================================== 按键拦截（UC-A44）
export const KEY_ENTER: number = 2054;
export const KEY_ESCAPE: number = 2070;

/**
 * 源 Modifier.interceptKey：目标键抬起时回调一次并消费；目标键按下也消费（不传给子组件）；其它键放行。
 * 用法：.onKeyPreIme((e: KeyEvent) => interceptKey(e, KEY_ENTER, () => {...}))（或 onKeyEvent）
 */
export function interceptKey(event: KeyEvent, keyCode: number, onKeyUp: () => void): boolean {
  if (event.keyCode !== keyCode) {
    return false;
  }
  if (event.type === KeyType.Up) {
    onKeyUp();
  }
  return true;
}

// ================================================================== 可见性追踪（UC-A43）
export class VisibilityInfo {
  isVisible: boolean = false;
  visiblePercentage: number = 0;
  isAboveThreshold: boolean = false;
}

/** 0,0.01,…,1：配合 onVisibleAreaChange 使比例每变化 1% 都能收到回调 */
export const VISIBILITY_RATIOS: number[] = buildRatios();

function buildRatios(): number[] {
  const r: number[] = [];
  for (let i = 0; i <= 100; i++) {
    r.push(i / 100);
  }
  return r;
}

/** 源可见比例：自身与父容器可见区交集面积 / 自身面积（0..1）；自身面积为 0 → -1（不回调） */
export function computeVisibleFraction(left: number, top: number, right: number, bottom: number,
  pLeft: number, pTop: number, pRight: number, pBottom: number): number {
  const total = (right - left) * (bottom - top);
  if (total <= 0) {
    return -1;
  }
  const w = Math.max(0, Math.min(right, pRight) - Math.max(left, pLeft));
  const h = Math.max(0, Math.min(bottom, pBottom) - Math.max(top, pTop));
  return Math.max(0, Math.min(1, (w * h) / total));
}

/**
 * 源 VisibilityTrackerNode：比例变化 ≥0.01 才回调；isAboveThreshold = 比例 ≥ 阈值。
 * 用法：.onVisibleAreaChange(VISIBILITY_RATIOS, (exp: boolean, ratio: number) => tracker.update(ratio))
 */
export class VisibilityTracker {
  static readonly MIN_DELTA: number = 0.01;
  thresholdPercentage: number;
  onVisibilityChanged: (info: VisibilityInfo) => void;
  private previous: number | null = null;

  constructor(thresholdPercentage: number, onVisibilityChanged: (info: VisibilityInfo) => void) {
    this.thresholdPercentage = thresholdPercentage;
    this.onVisibilityChanged = onVisibilityChanged;
  }

  update(ratio: number): void {
    if (ratio < 0) {
      return;
    }
    const pct = Math.max(0, Math.min(1, ratio));
    const prev = this.previous;
    const diff = prev === null ? Number.MAX_VALUE : Math.abs(pct - prev);
    if (diff >= VisibilityTracker.MIN_DELTA - 1e-6) {
      const info = new VisibilityInfo();
      info.isVisible = pct > 0;
      info.visiblePercentage = pct;
      info.isAboveThreshold = pct >= this.thresholdPercentage;
      this.previous = pct;
      this.onVisibilityChanged(info);
    }
  }

  /** 源：父为空或未 attach → 置 0 不回调 */
  reset(): void {
    this.previous = 0;
  }
}

// ================================================================== 受限缩放（UC-A47）
export enum RestrainedScale {
  FIT = 0,
  CROP = 1,
  FILL_WIDTH = 2,
}

/** 源 Restrained*Scaling：标准 Fit/Crop/FillWidth 比例，但不超过 max(pixelDensity, 1)。尺寸单位须一致（px） */
export function computeRestrainedScale(mode: RestrainedScale, srcW: number, srcH: number, dstW: number,
  dstH: number, pixelDensity: number): number {
  if (srcW <= 0 || srcH <= 0) {
    return 1;
  }
  const cap = Math.max(pixelDensity, 1);
  const fillW = dstW / srcW;
  const fillH = dstH / srcH;
  let s: number;
  if (mode === RestrainedScale.FIT) {
    s = Math.min(fillW, fillH);
  } else if (mode === RestrainedScale.CROP) {
    s = Math.max(fillW, fillH);
  } else {
    s = fillW;
  }
  return Math.min(cap, s);
}

// ================================================================== 图片加载（UC-A48/A49）
/**
 * 源 Coil ImageLoader：内存 LRU → Coil DiskCache（cacheDir/image_cache 200MB，FeederApplication.kt:185-189，APP-A72）
 * → HttpClient.images()（独立 300MB HTTP 缓存；仅 Wi-Fi 时计费网络只读缓存，无缓存 504 失败；每主机串行）
 * + ImageKit 解码（含 .ico，依系统解码器）；位图最大 2500×2500。
 * 磁盘缓存命中即用（Coil 默认对已缓存原始字节直接解码；不做 HTTP 头再校验——HTTP 层已由 AlwaysUseCacheIfPossible 放宽）。
 */
export class ImageLoader {
  static readonly MAX_MEMORY_ENTRIES: number = 64;
  static readonly MAX_BITMAP_SIZE: number = 2500;
  private static memory: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private static inflight: Map<string, Promise<image.PixelMap | null>> = new Map<string, Promise<image.PixelMap | null>>();

  static load(url: string): Promise<image.PixelMap | null> {
    const hit = ImageLoader.memory.get(url);
    if (hit !== undefined) {
      ImageLoader.memory.delete(url);
      ImageLoader.memory.set(url, hit);
      return Promise.resolve<image.PixelMap | null>(hit);
    }
    const running = ImageLoader.inflight.get(url);
    if (running !== undefined) {
      return running;
    }
    const p = ImageLoader.fetchAndDecode(url).finally(() => {
      ImageLoader.inflight.delete(url);
    });
    ImageLoader.inflight.set(url, p);
    return p;
  }

  private static async fetchAndDecode(url: string): Promise<image.PixelMap | null> {
    try {
      const body: ArrayBuffer | null = await ImageLoader.loadBytes(url);
      if (body === null) {
        return null;
      }
      const src = image.createImageSource(body);
      try {
        const info = await src.getImageInfo();
        const w = info.size.width;
        const h = info.size.height;
        const max = ImageLoader.MAX_BITMAP_SIZE;
        const opts: image.DecodingOptions = {};
        if (w > max || h > max) {
          const k = Math.min(max / w, max / h);
          const size: image.Size = { width: Math.max(1, Math.floor(w * k)), height: Math.max(1, Math.floor(h * k)) };
          opts.desiredSize = size;
        }
        const pm = await src.createPixelMap(opts);
        ImageLoader.remember(url, pm);
        return pm;
      } finally {
        src.release();
      }
    } catch (e) {
      console.warn(`ImageLoader: failed ${url.substring(0, 64)}: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /** 磁盘缓存（image_cache）→ 网络；网络成功的 http(s) 图片字节写回磁盘缓存 */
  private static async loadBytes(url: string): Promise<ArrayBuffer | null> {
    const disk: HttpDiskCache | null = url.startsWith('http') ? HttpClient.imageDiskCache() : null;
    if (disk !== null) {
      const cached: HttpResponse | null = await disk.get(HttpRequest.get(url));
      if (cached !== null && cached.isSuccessful() && cached.body !== null && cached.body.byteLength > 0) {
        return cached.body;
      }
    }
    const result = await HttpClient.images().fetchImage(url);
    const resp = result.getOrNull();
    if (resp === null || !resp.isSuccessful() || resp.body === null || resp.body.byteLength === 0) {
      return null;
    }
    if (disk !== null) {
      const toStore: HttpResponse = resp;
      disk.put(toStore).catch((e: Error) => {
        console.warn(`ImageLoader: disk cache put failed: ${e?.message}`);
      });
    }
    return resp.body;
  }

  private static remember(url: string, pm: image.PixelMap): void {
    ImageLoader.memory.set(url, pm);
    while (ImageLoader.memory.size > ImageLoader.MAX_MEMORY_ENTRIES) {
      const first = ImageLoader.memory.keys().next();
      if (first.done) {
        break;
      }
      ImageLoader.memory.delete(first.value as string);
    }
  }
}

/**
 * 网络图片：加载中显示随内容色着色的占位图标（源 Icons.Outlined.Terrain → sys.symbol.picture），
 * 失败显示错误图标（ErrorOutline → sys.symbol.exclamationmark_circle）；缩放按 RestrainedScale。
 * boxHeightVp < 0 表示高度随图片（FIT/FILL_WIDTH 按宽度计算）。
 */
@ComponentV2
export struct FeederImage {
  @Param url: string = '';
  @Param scaleMode: RestrainedScale = RestrainedScale.FIT;
  @Param boxWidth: Length = '100%';
  @Param boxHeightVp: number = -1;
  /** 占位/错误图标颜色；空串 = 当前 onSurface（源 LocalContentColor） */
  @Param contentColor: ResourceColor = '';
  @Param iconSize: number = 48;
  @Param altText: string = '';
  @Local pixelMap: image.PixelMap | null = null;
  @Local failed: boolean = false;
  @Local srcW: number = 0;
  @Local srcH: number = 0;
  @Local areaW: number = 0;
  @Local areaH: number = 0;
  private loadSeq: number = 0;

  aboutToAppear(): void {
    this.startLoad();
  }

  @Monitor('url')
  onUrlChanged(monitor: IMonitor): void {
    this.startLoad();
  }

  private startLoad(): void {
    const seq = ++this.loadSeq;
    this.pixelMap = null;
    this.failed = false;
    if (this.url === '') {
      this.failed = true;
      return;
    }
    ImageLoader.load(this.url).then((pm: image.PixelMap | null) => {
      if (seq !== this.loadSeq) {
        return;
      }
      if (pm === null) {
        this.failed = true;
        return;
      }
      const info = pm.getImageInfoSync();
      this.srcW = info.size.width;
      this.srcH = info.size.height;
      this.pixelMap = pm;
    });
  }

  private displaySize(): number[] {
    if (this.srcW <= 0 || this.areaW <= 0) {
      return [0, 0];
    }
    const d = screenDensity();
    const fixedH = this.boxHeightVp >= 0;
    let mode = this.scaleMode;
    if (!fixedH && mode !== RestrainedScale.FILL_WIDTH) {
      mode = mode === RestrainedScale.CROP ? RestrainedScale.FILL_WIDTH : mode;
    }
    const dstH = fixedH ? this.areaH * d : Number.MAX_VALUE;
    const s = computeRestrainedScale(mode, this.srcW, this.srcH, this.areaW * d, dstH, d);
    return [this.srcW * s / d, this.srcH * s / d];
  }

  private boxHeight(): number {
    if (this.boxHeightVp >= 0) {
      return this.boxHeightVp;
    }
    if (this.pixelMap !== null) {
      return this.displaySize()[1];
    }
    return this.iconSize * 2;
  }

  private iconColor(): ResourceColor {
    return this.contentColor === '' ? FeederTheme.colors.onSurface : this.contentColor;
  }

  build() {
    // 居中：源 Image/AsyncImage 默认 alignment = Center
    Stack({ alignContent: Alignment.Center }) {
      if (this.pixelMap !== null) {
        Image(this.pixelMap)
          .width(this.displaySize()[0])
          .height(this.displaySize()[1])
          .objectFit(ImageFit.Fill)
          .alt(this.altText)
          .accessibilityText(this.altText)
          // Image 默认可拖拽，长按会被拖拽抢占，导致卡片长按菜单（外层 LongPressGesture）不弹
          .draggable(false)
      } else {
        SymbolGlyph(this.failed ? $r('sys.symbol.exclamationmark_circle') : $r('sys.symbol.picture'))
          .fontSize(this.iconSize)
          .fontColor([this.iconColor()])
      }
    }
    .width(this.boxWidth)
    .height(this.boxHeight())
    .clip(true)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.areaW = newArea.width as number;
      this.areaH = newArea.height as number;
    })
  }
}

// ================================================================== 下拉刷新（UC-A39/A40）
@Builder
function emptyWidgetBuilder() {
}

/**
 * 源 pullRefresh + PullRefreshIndicator → ArkUI Refresh：只有子滚动容器在顶部时下拉才拉出指示器（Refresh 原生语义）；
 * 阈值 80vp（refreshOffset）、拖动系数 0.5（pullDownRatio，源 DRAG_MULTIPLIER）；超阈值松手 → onRefresh，否则回弹；
 * 刷新中指示器停留转圈、再次下拉不重复触发；外部 refreshing 变 false 时收回。
 */
@ComponentV2
export struct PullRefreshContainer {
  @Param refreshing: boolean = false;
  @Event onRefresh: () => void = () => {
    console.info('TODO:onRefresh:PullRefreshContainer');
  };
  @BuilderParam contentBuilder: () => void = emptyWidgetBuilder;
  @Local isRefreshing: boolean = false;
  private settleTimer: number = -1;

  aboutToAppear(): void {
    this.isRefreshing = this.refreshing;
  }

  aboutToDisappear(): void {
    if (this.settleTimer >= 0) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
  }

  @Monitor('refreshing')
  onRefreshingChanged(monitor: IMonitor): void {
    this.isRefreshing = this.refreshing;
  }

  build() {
    Refresh({ refreshing: this.isRefreshing }) {
      this.contentBuilder()
    }
    .refreshOffset(80)
    .pullToRefresh(true)
    .pullDownRatio(0.5)
    .onRefreshing(() => {
      this.isRefreshing = true;
      // 外部已在刷新（同步开始时 @Monitor 把 isRefreshing 置真也会触发 onRefreshing）：不是用户下拉，不再发起同步
      //（否则菜单 Sync feeds 一次会连发两次同步，通知发布撞系统频控 1600009）
      if (this.refreshing) {
        return;
      }
      this.onRefresh();
      // 源 setRefreshing 只跟随外部状态：调用方没有进入刷新态时指示器收回
      if (this.settleTimer >= 0) {
        clearTimeout(this.settleTimer);
      }
      this.settleTimer = setTimeout(() => {
        this.settleTimer = -1;
        if (!this.refreshing) {
          this.isRefreshing = false;
        }
      }, 800);
    })
  }
}

// ================================================================== 底部操作栏（UC-A42）
/** 源 PaddedBottomAppBar：高 80vp、内容避让导航栏、actions 左排、FAB（可选）右侧 */
@ComponentV2
export struct PaddedBottomAppBar {
  /** 导航栏避让高度（vp，来自 AppStorageV2 AvoidArea.bottom） */
  @Param bottomInset: number = 0;
  /** 空串 = M3 BottomAppBarDefaults.containerColor（surfaceContainer） */
  @Param containerColor: ResourceColor = '';
  @Param hasFab: boolean = false;
  @BuilderParam actionsBuilder: () => void = emptyWidgetBuilder;
  @BuilderParam fabBuilder: () => void = emptyWidgetBuilder;

  build() {
    Column() {
      Row() {
        this.actionsBuilder()
        if (this.hasFab) {
          Blank()
          Stack({ alignContent: Alignment.TopStart }) {
            this.fabBuilder()
          }
          .height('100%')
          .padding({ top: 8, right: 12 })
        }
      }
      .width('100%')
      .height(80)
      .padding({ left: 4, top: 4, right: 4 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ bottom: this.bottomInset })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.containerColor === '' ? FeederTheme.colors.surfaceContainer : this.containerColor)
  }
}

// ================================================================== 翻译模型下载进度（UC-A41）
/** 源 BergamotModelDownloadProgress */
export class TranslationDownloadProgress {
  sourceLanguage: string = '';
  targetLanguage: string = '';
  fileName: string = '';
  downloadedBytes: number = 0;
  totalBytes: number = 0;
  isRuntimeDownload: boolean = false;

  isIndeterminate(): boolean {
    return this.totalBytes <= 0;
  }

  fraction(): number {
    return this.totalBytes <= 0 ? 0 : Math.max(0, Math.min(1, this.downloadedBytes / this.totalBytes));
  }

  percent(): number {
    return Math.trunc(this.fraction() * 100);
  }
}

@ComponentV2
struct IndeterminateLinearProgress {
  @Local trackWidth: number = 0;
  @Local pos: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('30%')
        .height(4)
        .backgroundColor(FeederTheme.colors.primary)
        .borderRadius(2)
        .translate({ x: this.pos * this.trackWidth * 1.3 - this.trackWidth * 0.3 })
    }
    .width('100%')
    .height(4)
    .clip(true)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .borderRadius(2)
    .onAreaChange((o: Area, n: Area) => {
      this.trackWidth = n.width as number;
    })
    .onAppear(() => {
      this.getUIContext().animateTo({ duration: 1500, iterations: -1, curve: Curve.EaseInOut }, () => {
        this.pos = 1;
      });
    })
  }
}

@ComponentV2
export struct TranslationProgressContent {
  @Param progress: TranslationDownloadProgress = new TranslationDownloadProgress();

  private label(): Resource {
    const p = this.progress;
    if (p.isRuntimeDownload) {
      return $r('app.string.downloading_offline_translation_runtime', p.percent());
    }
    if (p.isIndeterminate()) {
      return $r('app.string.preparing_offline_translation_model', p.sourceLanguage, p.targetLanguage);
    }
    return $r('app.string.downloading_offline_translation_model', p.sourceLanguage, p.targetLanguage, p.percent());
  }

  build() {
    Column() {
      Text(this.label())
        .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurface))
      Column() {
        if (this.progress.isIndeterminate()) {
          IndeterminateLinearProgress()
        } else {
          Progress({ value: this.progress.fraction() * 100, total: 100, type: ProgressType.Linear })
            .width('100%')
            .color(FeederTheme.colors.primary)
            .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
        }
      }
      .width('100%')
      .padding({ top: 8 })
      .alignItems(HorizontalAlign.Start)
      Text($r('app.string.offline_translation_model_download_hint'))
        .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.outline))
        .padding({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
  }
}

// ================================================================== 表单 OK/Cancel（UC-A35）
@ComponentV2
export struct OkCancelButtons {
  @Param okEnabled: boolean = true;
  @Event onOk: () => void = () => {
    console.info('TODO:onOk:OkCancelButtons');
  };
  @Event onCancel: () => void = () => {
    console.info('TODO:onCancel:OkCancelButtons');
  };

  build() {
    Row({ space: 8 }) {
      Button($r('app.string.cancel'), { type: ButtonType.Capsule })
        .attributeModifier(buttonLabelStyle())
        .backgroundColor(Color.Transparent)
        .fontColor(FeederTheme.colors.primary)
        .onClick(() => {
          this.onCancel();
        })
      Button($r('app.string.hm_ok'), { type: ButtonType.Capsule })
        .attributeModifier(buttonLabelStyle())
        .backgroundColor(Color.Transparent)
        .fontColor(FeederTheme.colors.primary)
        .enabled(this.okEnabled)
        .opacity(this.okEnabled ? 1 : 0.38)
        .onClick(() => {
          this.onOk();
        })
    }
    // ArkUI 不会像 Compose 那样按父约束钳制显式宽度：用 100% + maxWidth 避免溢出父容器（UC-A35）
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .padding({ bottom: 16 })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }
}

/** 源 OkCancelWithContent（scrollable=true）/ OkCancelWithNonScrollableContent（false）；底部避让导航栏 */
@ComponentV2
export struct OkCancelWithContent {
  @Param okEnabled: boolean = true;
  @Param scrollable: boolean = true;
  @Param bottomInset: number = 0;
  @Event onOk: () => void = () => {
    console.info('TODO:onOk:OkCancelWithContent');
  };
  @Event onCancel: () => void = () => {
    console.info('TODO:onCancel:OkCancelWithContent');
  };
  @BuilderParam contentBuilder: () => void = emptyWidgetBuilder;

  @Builder
  bodyBuilder() {
    Column() {
      if (this.scrollable) {
        Column().height(16)
      }
      this.contentBuilder()
      if (this.scrollable) {
        Column().height(24)
      }
      OkCancelButtons({
        okEnabled: this.okEnabled,
        onOk: () => {
          this.onOk();
        },
        onCancel: () => {
          this.onCancel();
        }
      })
      Column().height(this.bottomInset)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    if (this.scrollable) {
      Scroll() {
        this.bodyBuilder()
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
    } else {
      this.bodyBuilder()
    }
  }
}
