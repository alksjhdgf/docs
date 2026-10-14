/**
 * ArticleMedia.ets —— 源 LinearArticleContent.kt 的图片/视频/音频块（LinearImageContent :478-614、
 * LinearVideoContent :321-415、LinearAudioContent :291-319）与 getBestImageForMaxSize、rememberMaxImageWidth。
 * （由 ArticleBlocks.ets 按单文件 ≤600 行拆出；ArticleBlocks 的分派器使用这里的块。）
 *
 * - 图片：多源最佳选择（HU-A16）；加载中 Terrain 占位（sys.symbol.picture）、失败 ErrorOutline
 *   （sys.symbol.exclamationmark_circle）；不放大超过设备密度倍、宽 ≤ 容器；link 非空才可点；caption 显示于下方
 *   （labelMedium）并作无障碍描述，非空白时长按弹出 caption 提示（源 PlainTooltipBox → bindPopup）。
 * - 视频：缩略图（占位 PlayCircleOutline → sys.symbol.play_circle）+ 链接样式 "Touch to play video"；
 *   音频：链接样式 "Touch to play audio"。媒体区域无可选文本。
 */
import { image } from '@kit.ImageKit';
import { LinearText, LinearImage, LinearImageSource, LinearVideo, LinearAudio } from '../../core/html/LinearArticle';
import { FeederTheme, screenDensity } from './Theme';
import { FeederTypography, M3Type, TextStyleModifier } from './Typography';
import { ImageLoader, RestrainedScale, computeRestrainedScale } from './CommonWidgets';
import { LinearTextContent, ArticleTextStyle, ColorRole, ArticleLinkClick, linkTargetIndex } from './RichText';

// =============================================================================================
// 纯逻辑
// =============================================================================================

/** 源 rememberMaxImageWidth：容器宽 px（四舍五入），上限 2000 */
export function maxImageWidthPx(containerWidthVp: number, pixelDensity: number): number {
  return Math.min(Math.round(containerWidthVp * pixelDensity), 2000);
}

/**
 * 源 LinearImage.getBestImageForMaxSize（LAC:599）：每个候选 size =
 *  pixelDensity/设备密度 | screenWidth/maxWidth | widthPx/maxWidth | 1/设备密度（均缺失时视为 1x），取 |size-1| 最小（并列取首个）。
 */
export function selectBestImageSource(sources: LinearImageSource[], pixelDensity: number,
  maxWidthPx: number): LinearImageSource | null {
  let best: LinearImageSource | null = null;
  let bestScore: number = Number.POSITIVE_INFINITY;
  for (let i = 0; i < sources.length; i++) {
    const c: LinearImageSource = sources[i];
    let size: number;
    if (c.pixelDensity !== null) {
      size = c.pixelDensity / pixelDensity;
    } else if (c.screenWidth !== null) {
      size = c.screenWidth / maxWidthPx;
    } else if (c.widthPx !== null) {
      size = c.widthPx / maxWidthPx;
    } else {
      size = 1.0 / pixelDensity;
    }
    const score: number = Math.abs(size - 1.0);
    if (best === null || score < bestScore) {
      best = c;
      bestScore = score;
    }
  }
  return best;
}

/** 源 hasImageAspectRatioInReader → RestrainedFitScaling，否则 RestrainedFillWidthScaling */
export function readerScaleMode(): RestrainedScale {
  return FeederTheme.dimens.hasImageAspectRatioInReader() ? RestrainedScale.FIT : RestrainedScale.FILL_WIDTH;
}

/** 图片 caption：LocalTextStyle.merge(labelMedium + onBackground) */
export const CAPTION_STYLE: ArticleTextStyle = ArticleTextStyle.of(M3Type.labelMedium, -1, ColorRole.ON_BACKGROUND);

/** 链接样式文字（音视频）：bodyLarge × fontScale + primary + 下划线 */
export function linkTextModifier(): TextStyleModifier {
  return new TextStyleModifier(M3Type.bodyLarge, FeederTypography.sansFamily, FeederTypography.fontScale,
    FeederTheme.colors.primary);
}

// =============================================================================================
// ReaderImage（AsyncImage + Restrained* 缩放 + 占位/错误图标）
// =============================================================================================

/**
 * 网络图片。maxWidthVp < 0：盒宽撑满父宽（源 fillMaxWidth）；≥ 0：最大宽（表格内，盒宽随图片）。
 * 显示尺寸 = 源尺寸 × min(容器宽/源宽, max(密度,1))（不放大超过密度倍，宽 ≤ 容器）。
 * 占位图标按源 tinted vector painter 的同一缩放规则显示（24vp 矢量 × 密度）。
 */
@ComponentV2
export struct ReaderImage {
  @Param url: string = '';
  @Param placeholderSymbol: Resource = $r('sys.symbol.picture');
  @Param scaleMode: RestrainedScale = RestrainedScale.FILL_WIDTH;
  @Param maxWidthVp: number = -1;
  @Param altText: string = '';
  @Local pixelMap: image.PixelMap | null = null;
  @Local failed: boolean = false;
  @Local srcW: number = 0;
  @Local srcH: number = 0;
  @Local areaW: number = 0;
  private loadSeq: number = 0;

  aboutToAppear(): void {
    this.startLoad();
  }

  @Monitor('url')
  onUrlChanged(monitor: IMonitor): void {
    this.startLoad();
  }

  private startLoad(): void {
    const seq: number = ++this.loadSeq;
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
      const info: image.ImageInfo = pm.getImageInfoSync();
      this.srcW = info.size.width;
      this.srcH = info.size.height;
      this.pixelMap = pm;
    });
  }

  private dstWidthVp(): number {
    return this.maxWidthVp >= 0 ? this.maxWidthVp : this.areaW;
  }

  private displaySize(): number[] {
    const dst: number = this.dstWidthVp();
    if (this.srcW <= 0 || dst <= 0) {
      return [0, 0];
    }
    const d: number = screenDensity();
    const s: number = computeRestrainedScale(this.scaleMode, this.srcW, this.srcH, dst * d, Number.MAX_VALUE, d);
    return [this.srcW * s / d, this.srcH * s / d];
  }

  private iconSize(): number {
    const icon: number = 24 * Math.max(screenDensity(), 1);
    const dst: number = this.dstWidthVp();
    return dst > 0 ? Math.min(icon, dst) : icon;
  }

  private boxWidth(): Length {
    if (this.maxWidthVp < 0) {
      return '100%';
    }
    return this.pixelMap !== null ? this.displaySize()[0] : this.iconSize();
  }

  private boxHeight(): number {
    return this.pixelMap !== null ? this.displaySize()[1] : this.iconSize();
  }

  build() {
    // 源 AsyncImage 默认 alignment = Center：居中为源本意
    Stack({ alignContent: Alignment.Center }) {
      if (this.pixelMap !== null) {
        Image(this.pixelMap)
          .width(this.displaySize()[0])
          .height(this.displaySize()[1])
          .objectFit(ImageFit.Fill)
          .accessibilityText(this.altText)
          .draggable(false)
      } else {
        SymbolGlyph(this.failed ? $r('sys.symbol.exclamationmark_circle') : this.placeholderSymbol)
          .fontSize(this.iconSize())
          .fontColor([FeederTheme.colors.onBackground])
          .accessibilityText(this.altText)
      }
    }
    .width(this.boxWidth())
    .height(this.boxHeight())
    .clip(true)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.areaW = newArea.width as number;
    })
  }
}

/** 源 LinearImageContent */
@ComponentV2
export struct ImageBlock {
  @Param linearImage: LinearImage = new LinearImage(new Set<string>(), [], null, null);
  @Param idToIndex: Map<string, number> = new Map<string, number>();
  @Param fillWidth: boolean = true;
  @Param availWidth: number = 360;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:ImageBlock ' + url + ' ' + String(index));
  };
  @Local chosenUrl: string = '';
  @Local tipVisible: boolean = false;

  aboutToAppear(): void {
    this.chooseSource();
  }

  @Monitor('linearImage')
  onImageChanged(monitor: IMonitor): void {
    this.chooseSource();
  }

  private chooseSource(): void {
    const d: number = screenDensity();
    const best: LinearImageSource | null =
      selectBestImageSource(this.linearImage.sources, d, maxImageWidthPx(this.availWidth, d));
    this.chosenUrl = best === null ? '' : best.imgUri;
  }

  private captionText(): string {
    const c: LinearText | null = this.linearImage.caption;
    return c === null ? '' : c.text;
  }

  private clickImage(): void {
    const link: string | null = this.linearImage.link;
    if (link !== null) {
      this.onLinkClick(link, linkTargetIndex(link, this.idToIndex));
    }
  }

  private longPressTip(): void {
    if (this.captionText().trim().length > 0) {
      this.tipVisible = true;
    }
  }

  private popupOptions(): PopupOptions {
    const opts: PopupOptions = {
      message: this.captionText(),
      onStateChange: (e) => {
        if (!e.isVisible) {
          this.tipVisible = false;
        }
      }
    };
    return opts;
  }

  @Builder
  picture() {
    ReaderImage({
      url: this.chosenUrl,
      placeholderSymbol: $r('sys.symbol.picture'),
      scaleMode: readerScaleMode(),
      maxWidthVp: this.fillWidth ? -1 : this.availWidth,
      altText: this.captionText()
    })
  }

  build() {
    Column({ space: 8 }) {
      if (this.linearImage.sources.length > 0) {
        if (this.linearImage.link !== null) {
          // 源 BoxWithConstraints(contentAlignment = Center)：居中为源本意
          Stack({ alignContent: Alignment.Center }) {
            this.picture()
          }
          .width(this.fillWidth ? '100%' : 'auto')
          .clip(true)
          .onClick(() => {
            this.clickImage();
          })
          .gesture(LongPressGesture().onAction(() => {
            this.longPressTip();
          }))
          .bindPopup(this.tipVisible, this.popupOptions())
        } else {
          Stack({ alignContent: Alignment.Center }) {
            this.picture()
          }
          .width(this.fillWidth ? '100%' : 'auto')
          .clip(true)
          .gesture(LongPressGesture().onAction(() => {
            this.longPressTip();
          }))
          .bindPopup(this.tipVisible, this.popupOptions())
        }
        if (this.linearImage.caption !== null) {
          LinearTextContent({
            linearText: this.linearImage.caption as LinearText,
            idToIndex: this.idToIndex,
            textStyle: CAPTION_STYLE,
            fillWidth: this.fillWidth,
            onLinkClick: (url: string, index: number | null): void => {
              this.onLinkClick(url, index);
            }
          })
        }
      }
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .alignItems(HorizontalAlign.Center)
  }
}

/** 源 LinearVideoContent */
@ComponentV2
export struct VideoBlock {
  @Param linearVideo: LinearVideo | null = null;
  @Param fillWidth: boolean = true;
  @Param availWidth: number = 360;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:VideoBlock ' + url + ' ' + String(index));
  };
  @Local playLabel: string = '';

  aboutToAppear(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.playLabel = ctx.resourceManager.getStringByNameSync('touch_to_play_video');
      }
    } catch (e) {
      console.warn('VideoBlock: resolve label failed: ' + JSON.stringify(e));
    }
  }

  private thumbnail(): string | null {
    return this.linearVideo === null ? null : (this.linearVideo as LinearVideo).imageThumbnail;
  }

  private play(): void {
    if (this.linearVideo !== null) {
      this.onLinkClick((this.linearVideo as LinearVideo).firstSource.link, null);
    }
  }

  build() {
    Column({ space: 8 }) {
      if (this.thumbnail() !== null) {
        // 源 BoxWithConstraints(contentAlignment = Center)
        Stack({ alignContent: Alignment.Center }) {
          ReaderImage({
            url: this.thumbnail() as string,
            placeholderSymbol: $r('sys.symbol.play_circle'),
            scaleMode: readerScaleMode(),
            maxWidthVp: this.fillWidth ? -1 : this.availWidth,
            altText: this.playLabel
          })
        }
        .width(this.fillWidth ? '100%' : 'auto')
        .clip(true)
        .onClick(() => {
          this.play();
        })
      }
      Text($r('app.string.touch_to_play_video'))
        .attributeModifier(linkTextModifier())
        .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
        .onClick(() => {
          this.play();
        })
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .alignItems(HorizontalAlign.Center)
  }
}

/** 源 LinearAudioContent */
@ComponentV2
export struct AudioBlock {
  @Param linearAudio: LinearAudio | null = null;
  @Param fillWidth: boolean = true;
  @Event onLinkClick: ArticleLinkClick = (url: string, index: number | null) => {
    console.info('TODO:linkClick:AudioBlock ' + url + ' ' + String(index));
  };

  private play(): void {
    if (this.linearAudio !== null) {
      this.onLinkClick((this.linearAudio as LinearAudio).firstSource.uri, null);
    }
  }

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.touch_to_play_audio'))
        .attributeModifier(linkTextModifier())
        .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
        .onClick(() => {
          this.play();
        })
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .alignItems(HorizontalAlign.Center)
  }
}

