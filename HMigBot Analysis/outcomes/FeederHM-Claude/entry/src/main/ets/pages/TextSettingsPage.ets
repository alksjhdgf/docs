/**
 * TextSettingsPage —— 源 ui/compose/settings/TextSettings.kt（TextSettingsScreen / TextSettingsView /
 * TextSettingsSinglePane / TextSettingsDualPane / TextSettingsContent / ScaleSetting / PreviewFontContent）。
 *  - Scaffold + SensibleTopAppBar → 自绘顶栏（返回 + `Text settings`），顶部避让状态栏（AvoidArea.top）。
 *  - 宽度 Compact → 单栏（设置在上、预览在下，整体纵向滚动）；否则双栏（左设置、右预览独立滚动）。
 *  - MenuSetting(DropdownMenu) → bindMenu；OpenDocument → DocumentViewPicker（源 MIME 经 UTD 映射为后缀过滤）。
 *  - 用户字体预览：源 variableFont 的 wght/slnt/ital 变体轴 → graphics.text Paragraph（fontVariations）自绘。
 *  - errorToDisplay → Toast（could_not_add_font / could_not_remove_font / something_went_wrong）。
 */
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { common2D, text } from '@kit.ArkGraphics2D';
import { DrawContext, FrameNode, NodeController, RenderNode, UIContext } from '@kit.ArkUI';
import { AppRouter } from '../common/Router';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { onKeyEventLikeEscape, LayoutAdapt, ScreenType, WindowMetrics } from '../core/platform/LayoutAdapt';
import { FeederTheme } from '../ui/common/Theme';
import { M3Type, monoFamily, sansFamily, textStyle } from '../ui/common/Typography';
import {
  TEXT_SCALE_MAX,
  TEXT_SCALE_MIN,
  TEXT_SCALE_STEP,
  TextSettingsErrorKind,
  TextSettingsViewModel,
  UiFontOption,
  UserFontPreviewSpec,
  ensurePreviewFontLoaded,
  fontPickerSuffixFilters,
  textScaleStateDescription
} from '../features/textsettings/TextSettingsViewModel';

const LOG_TAG: string = 'FEEDER_TEXTSETTINGS_PAGE';

/** 源 PreviewFontContent 的 10 行样例；rtl=true 的两行 TextAlign.Right */
class PreviewLine {
  text: string = '';
  rtl: boolean = false;

  constructor(text: string, rtl: boolean) {
    this.text = text;
    this.rtl = rtl;
  }
}

const PREVIEW_LINES: PreviewLine[] = [
  new PreviewLine('The quick brown fox jumps over the lazy dog.', false),
  new PreviewLine('В чащах юга жил-был цитрус... да, но фальшивый экземпляр!', false),
  new PreviewLine('Η γρήγορη καφέ αλεπού πηδάει πάνω από τον τεμπέλη σκύλο', false),
  new PreviewLine('كل إنسان يولد حراً ومتساوياً في الكرامة والحقوق', true),
  new PreviewLine('כל בני האדם נולדו חופשיים ושווים בכבודם ובזכויותיהם', true),
  new PreviewLine('सभी मनुष्य स्वतंत्र और समान अधिकारों के साथ जन्म लेते', false),
  new PreviewLine('人人生而自由', false),
  new PreviewLine('日本語の漢字ひらがなカタカナ', false),
  new PreviewLine('모든 인간은 태어날 때부터 자유롭고 평등하다', false),
  new PreviewLine('มนุษย์ทุกคนเกิดมาอิสระและเท่าเทียมกันในศักดิ์ศรีและสิทธิ', false),
];

/** 源 SegmentedButtonDefaults.itemShape(index, count = 2)：两端圆角 */
const SEGMENT_START_RADIUS: BorderRadiuses = { topLeft: 20, bottomLeft: 20, topRight: 0, bottomRight: 0 };
const SEGMENT_END_RADIUS: BorderRadiuses = { topLeft: 0, bottomLeft: 0, topRight: 20, bottomRight: 20 };

@Builder
export function TextSettingsPageBuilder() {
  TextSettingsPage()
}

@ComponentV2
struct TextSettingsPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local vm: TextSettingsViewModel = new TextSettingsViewModel();
  private singleScroller: Scroller = new Scroller();
  private previewScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.vm.setErrorListener((kind: TextSettingsErrorKind) => {
      this.showErrorToast(kind);
    });
    this.vm.start();
  }

  aboutToDisappear(): void {
    this.vm.setErrorListener(null);
    this.vm.stop();
  }

  /** 源 LaunchedEffect(viewState.errorToDisplay) */
  private showErrorToast(kind: TextSettingsErrorKind): void {
    let msg: Resource = $r('app.string.something_went_wrong');
    if (kind === TextSettingsErrorKind.ADD_FONT) {
      msg = $r('app.string.could_not_add_font');
    } else if (kind === TextSettingsErrorKind.REMOVE_FONT) {
      msg = $r('app.string.could_not_remove_font');
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (e) {
      console.error(`${LOG_TAG}: toast failed: ${(e as Error)?.message}`);
    }
  }

  /** 源 addFontPicker.launch(arrayOf("application/x-font-ttf", "font/ttf"))；取消 → 无变化 */
  private launchFontPicker(): void {
    try {
      const opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      opts.fileSuffixFilters = fontPickerSuffixFilters();
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      const dvp: picker.DocumentViewPicker = ctx !== undefined ?
        new picker.DocumentViewPicker(ctx as common.UIAbilityContext) : new picker.DocumentViewPicker();
      dvp.select(opts).then((uris: string[]) => {
        if (uris !== undefined && uris !== null && uris.length > 0) {
          this.vm.addFont(uris[0], null);
        }
      }).catch((e: Error) => {
        this.vm.onPickerFailed(e);
      });
    } catch (e) {
      this.vm.onPickerFailed(e as Error);
    }
  }

  private onFontOptionSelected(option: UiFontOption): void {
    this.vm.menuExpanded = false;
    if (option.realOption === null) {
      this.launchFontPicker();
    } else {
      this.vm.setSansSerifFont(option.realOption);
    }
  }

  build() {
    NavDestination() {
      Column() {
        this.topBarBuilder()
        if (this.metrics.screenType === ScreenType.DUAL) {
          this.dualPaneBuilder()
        } else {
          this.singlePaneBuilder()
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: this.avoid.top, bottom: this.avoid.bottom })
      .backgroundColor(FeederTheme.colors.background)
    }
    .hideTitleBar(true)
  }

  // ---------------------------------------------------------------- 顶栏
  @Builder
  topBarBuilder() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(24)
          .fontColor([FeederTheme.colors.onSurface])
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.go_back'))
      .onClick(() => {
        AppRouter.back();
      })

      Text($r('app.string.text_settings'))
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height(64)
    .padding({ left: 4, right: 4 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(FeederTheme.colors.background)
  }

  // ---------------------------------------------------------------- 单栏/双栏
  @Builder
  singlePaneBuilder() {
    Scroll(this.singleScroller) {
      Column({ space: 8 }) {
        this.settingsContentBuilder()
        this.previewContentBuilder()
      }
      .width('100%')
      .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
      .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  @Builder
  dualPaneBuilder() {
    Row() {
      Column({ space: 8 }) {
        this.settingsContentBuilder()
      }
      .layoutWeight(1)
      .height('100%')
      .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)

      Scroll(this.previewScroller) {
        Column({ space: 8 }) {
          this.previewContentBuilder()
        }
        .width('100%')
        .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .height('100%')
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  // ---------------------------------------------------------------- 设置区（源 TextSettingsContent）
  @Builder
  settingsContentBuilder() {
    Row({ space: 8 }) {
      // 源 MenuSetting(title = font, currentValue, values, icon = null)
      Column() {
        Text($r('app.string.font'))
          .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.vm.currentUiFontOption.labelRes)
          .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurfaceVariant))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 64 })
      .padding({ top: 4, bottom: 4 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .onClick(() => {
        this.vm.menuExpanded = !this.vm.menuExpanded;
      })
      .bindMenu(this.vm.menuExpanded, (): void => {
        this.fontMenuBuilder()
      }, {
        onDisappear: () => {
          this.vm.menuExpanded = false;
        }
      })

      if (this.vm.isUserFont) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(24)
            .fontColor([FeederTheme.colors.onSurfaceVariant])
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.remove'))
        .onClick(() => {
          this.vm.removeFont(this.vm.sansSerifFont);
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)

    this.headerBuilder($r('app.string.text_scale'))
    this.scaleSettingBuilder()

    this.headerBuilder($r('app.string.text_preview'))
    this.segmentedBuilder()
  }

  @Builder
  fontMenuBuilder() {
    Menu() {
      ForEach(this.vm.uiFontOptions, (opt: UiFontOption) => {
        MenuItem({ content: opt.labelRes })
          .contentFont({
            size: M3Type.bodyLarge.size,
            weight: this.vm.isCurrent(opt) ? FontWeight.Bold : FontWeight.Normal,
            family: sansFamily()
          })
          .contentFontColor(this.vm.isCurrent(opt) ? FeederTheme.colors.secondary : FeederTheme.colors.onSurface)
          .onClick(() => {
            this.onFontOptionSelected(opt);
          })
      }, (opt: UiFontOption) => `${opt.optionKey}|${this.vm.isCurrent(opt)}`)
    }
    // UT-A44：源 TextSettings.kt:299→Settings.kt:1151 DropdownMenu.onKeyEventLikeEscape（Escape/Back 关闭菜单）
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.vm.menuExpanded = false;
    }))
  }

  /** 源 Header：labelMedium + primary 色，heading 语义，顶部 8 */
  @Builder
  headerBuilder(text: ResourceStr) {
    Text(text)
      .attributeModifier(textStyle(M3Type.labelMedium, false, FeederTheme.colors.primary))
      .width('100%')
      .textAlign(TextAlign.Start)
      .margin({ top: 8 })
  }

  /** 源 ScaleSetting + SliderWithEndLabels（1.0–2.0，steps=9 → 11 个刻度） */
  @Builder
  scaleSettingBuilder() {
    Column({ space: 8 }) {
      Row() {
        Text('A')
          .fontFamily(sansFamily())
          .fontSize(M3Type.bodyLarge.size * TEXT_SCALE_MIN)
          .fontColor(FeederTheme.colors.onSurface)
        Text('A')
          .fontFamily(sansFamily())
          .fontSize(M3Type.bodyLarge.size * TEXT_SCALE_MAX)
          .fontColor(FeederTheme.colors.onSurface)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
      .accessibilityLevel('no')

      Slider({
        value: this.vm.safeFontScale,
        min: TEXT_SCALE_MIN,
        max: TEXT_SCALE_MAX,
        step: TEXT_SCALE_STEP,
        style: SliderStyle.InSet
      })
        .width('100%')
        .showSteps(true)
        .selectedColor(FeederTheme.colors.primary)
        .trackColor(FeederTheme.colors.secondaryContainer)
        .blockColor(FeederTheme.colors.primary)
        .accessibilityText($r('app.string.text_scale'))
        .accessibilityStateDescription(textScaleStateDescription(this.vm.fontScale))
        .onChange((value: number, _mode: SliderChangeMode) => {
          if (Math.round(value * 10) !== Math.round(this.vm.fontScale * 10)) {
            this.vm.setFontScale(value);
          }
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 源 MultiChoiceSegmentedButtonRow（Bold / Italic，可独立多选） */
  @Builder
  segmentedBuilder() {
    Row() {
      this.segmentButtonBuilder(true)
      this.segmentButtonBuilder(false)
    }
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  /** isBold=true → Bold 段（左）；false → Italic 段（右）。选中态在内部读 vm 以保证刷新 */
  @Builder
  segmentButtonBuilder(isBold: boolean) {
    Row({ space: 8 }) {
      if (isBold ? this.vm.previewBold : this.vm.previewItalic) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([FeederTheme.colors.onSecondaryContainer])
      }
      Text(isBold ? $r('app.string.bold') : $r('app.string.italic'))
        .attributeModifier(textStyle(M3Type.labelLarge, false,
          (isBold ? this.vm.previewBold : this.vm.previewItalic) ? FeederTheme.colors.onSecondaryContainer :
          FeederTheme.colors.onSurface))
        .maxLines(1)
    }
    .height(40)
    .constraintSize({ minWidth: 104 })
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor((isBold ? this.vm.previewBold : this.vm.previewItalic) ?
      FeederTheme.colors.secondaryContainer : Color.Transparent)
    .border({
      width: 1,
      color: FeederTheme.colors.outline,
      radius: isBold ? SEGMENT_START_RADIUS : SEGMENT_END_RADIUS
    })
    .margin({ left: isBold ? 0 : -1 })
    .accessibilityRole(AccessibilityRoleType.CHECKBOX)
    .accessibilityChecked(isBold ? this.vm.previewBold : this.vm.previewItalic)
    .onClick(() => {
      if (isBold) {
        this.vm.setPreviewBold(!this.vm.previewBold);
      } else {
        this.vm.setPreviewItalic(!this.vm.previewItalic);
      }
    })
  }

  // ---------------------------------------------------------------- 预览区（源 PreviewFontContent + ProvideScaledText）
  @Builder
  previewContentBuilder() {
    if (this.vm.userFontPreview !== null) {
      ForEach(PREVIEW_LINES, (line: PreviewLine) => {
        Column() {
          UserFontPreviewLine({
            lineText: line.text,
            rtl: line.rtl,
            spec: this.vm.userFontPreview,
            textColor: FeederTheme.colors.onSurface
          })
        }
        .width('100%')
        .padding(4)
        .accessibilityGroup(true)
        .accessibilityText($r('app.string.text_preview'))
      }, (line: PreviewLine) => line.text)
    } else {
      this.builtinPreviewBuilder()
    }
  }

  @Builder
  builtinPreviewBuilder() {
    ForEach(PREVIEW_LINES, (line: PreviewLine) => {
      Text(line.text)
        .width('100%')
        .padding(4)
        .textAlign(line.rtl ? TextAlign.RIGHT : TextAlign.LEFT)
        .fontFamily(this.vm.previewMonospace ? monoFamily() : sansFamily())
        .fontSize(M3Type.bodyMedium.size * this.vm.safeFontScale)
        .lineHeight(M3Type.bodyMedium.lineHeight * this.vm.safeFontScale)
        .letterSpacing(M3Type.bodyMedium.letterSpacing)
        .fontWeight(this.vm.previewWeight, { enableVariableFontWeight: true })
        .fontStyle(this.vm.previewItalic ? FontStyle.Italic : FontStyle.Normal)
        .fontColor(FeederTheme.colors.onSurface)
        .accessibilityText($r('app.string.text_preview'))
    }, (line: PreviewLine) => line.text)
  }
}

// ------------------------------------------------------------------ 用户字体变体轴预览（TS-A29）
const PARAGRAPH_WEIGHTS: text.FontWeight[] = [
  text.FontWeight.W100, text.FontWeight.W200, text.FontWeight.W300, text.FontWeight.W400, text.FontWeight.W500,
  text.FontWeight.W600, text.FontWeight.W700, text.FontWeight.W800, text.FontWeight.W900
];

function toParagraphWeight(w: number): text.FontWeight {
  const idx: number = Math.min(8, Math.max(0, Math.round(w / 100) - 1));
  return PARAGRAPH_WEIGHTS[idx];
}

/** '#AARRGGBB' / '#RRGGBB' → common2D.Color */
function parseArgb(c: string): common2D.Color {
  let hex: string = c.startsWith('#') ? c.substring(1) : c;
  if (hex.length === 6) {
    hex = `FF${hex}`;
  }
  const v: number = parseInt(hex, 16);
  if (hex.length !== 8 || Number.isNaN(v)) {
    const black: common2D.Color = { alpha: 255, red: 0, green: 0, blue: 0 };
    return black;
  }
  const color: common2D.Color = {
    alpha: Math.floor(v / 0x1000000) & 0xFF,
    red: (v >> 16) & 0xFF,
    green: (v >> 8) & 0xFF,
    blue: v & 0xFF
  };
  return color;
}

class ParagraphRenderNode extends RenderNode {
  paragraph: text.Paragraph | null = null;

  draw(context: DrawContext): void {
    const p: text.Paragraph | null = this.paragraph;
    if (p !== null) {
      p.paint(context.canvas, 0, 0);
    }
  }
}

class ParagraphNodeController extends NodeController {
  private rootNode: FrameNode | null = null;
  private readonly paintNode: ParagraphRenderNode = new ParagraphRenderNode();

  makeNode(uiContext: UIContext): FrameNode | null {
    if (this.rootNode !== null) {
      return this.rootNode;
    }
    const node: FrameNode = new FrameNode(uiContext);
    const r: RenderNode | null = node.getRenderNode();
    try {
      r?.appendChild(this.paintNode);
    } catch (e) {
      console.error(`${LOG_TAG}: attach paint node failed: ${(e as Error)?.message}`);
    }
    this.rootNode = node;
    return node;
  }

  setParagraph(p: text.Paragraph | null, widthVp: number, heightVp: number): void {
    this.paintNode.paragraph = p;
    this.paintNode.frame = { x: 0, y: 0, width: widthVp, height: heightVp };
    this.paintNode.invalidate();
  }
}

/** 单行预览：源 Font(file, weight, style, variationSettings) → TextStyle.fontVariations（wght/slnt/ital）；字号/行高同乘缩放 */
@ComponentV2
struct UserFontPreviewLine {
  @Param lineText: string = '';
  @Param rtl: boolean = false;
  @Param spec: UserFontPreviewSpec | null = null;
  @Param textColor: string = '';
  @Local paintHeight: number = 0;
  private paintWidth: number = 0;
  private nodeController: ParagraphNodeController = new ParagraphNodeController();

  @Monitor('spec', 'textColor', 'lineText', 'rtl')
  onStyleChange(_m: IMonitor): void {
    this.relayout();
  }

  private relayout(): void {
    const spec: UserFontPreviewSpec | null = this.spec;
    if (spec === null || this.paintWidth <= 0) {
      return;
    }
    const family: string | null = ensurePreviewFontLoaded(spec);
    const ui: UIContext = this.getUIContext();
    const sizePx: number = ui.fp2px(M3Type.bodyMedium.size * spec.scale);
    const lineHeightPx: number = ui.fp2px(M3Type.bodyMedium.lineHeight * spec.scale);
    const variations: text.FontVariation[] = spec.variations.map((v): text.FontVariation => {
      const fv: text.FontVariation = { axis: v.axis, value: v.value };
      return fv;
    });
    const style: text.TextStyle = {
      color: parseArgb(this.textColor),
      fontFamilies: family !== null ? [family] : [],
      fontSize: sizePx,
      fontWeight: toParagraphWeight(spec.paragraphWeight),
      fontStyle: spec.syntheticItalic ? text.FontStyle.ITALIC : text.FontStyle.NORMAL,
      letterSpacing: ui.fp2px(M3Type.bodyMedium.letterSpacing),
      heightScale: sizePx > 0 ? lineHeightPx / sizePx : 1,
      heightOnly: true,
      fontVariations: variations
    };
    const paragraphStyle: text.ParagraphStyle = {
      textStyle: style,
      align: this.rtl ? text.TextAlign.RIGHT : text.TextAlign.LEFT
    };
    try {
      const builder: text.ParagraphBuilder =
        new text.ParagraphBuilder(paragraphStyle, text.FontCollection.getGlobalInstance());
      builder.pushStyle(style);
      builder.addText(this.lineText);
      const p: text.Paragraph = builder.build();
      p.layoutSync(ui.vp2px(this.paintWidth));
      const h: number = ui.px2vp(p.getHeight());
      this.paintHeight = h;
      this.nodeController.setParagraph(p, this.paintWidth, h);
    } catch (e) {
      console.error(`${LOG_TAG}: preview paragraph failed: ${(e as Error)?.message}`);
    }
  }

  build() {
    NodeContainer(this.nodeController)
      .width('100%')
      .height(this.paintHeight)
      .onAreaChange((_o: Area, n: Area) => {
        const w: number = Number(n.width);
        if (w > 0 && Math.abs(w - this.paintWidth) > 0.5) {
          this.paintWidth = w;
          this.relayout();
        }
      })
  }
}
