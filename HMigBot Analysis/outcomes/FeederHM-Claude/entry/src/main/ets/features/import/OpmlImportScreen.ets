/**
 * OpmlImportScreen —— 源 ui/compose/ompl/OpmlImportScreen.kt（OpmlImportScreen + OpmlImportView）：
 *  Scaffold(contentWindowInsets = statusBars) + SensibleTopAppBar(`Import feeds from OPML`，返回 `Go back`)
 *  + OkCancelWithNonScrollableContent{ 摘要（titleMedium，按段落定方向）; LazyColumn(spacedBy 8, vertical 16, weight 1)
 *  { FlowRow(spacedBy 4){ 标题 titleSmall; url bodySmall } } }。
 * 回调：onNavigateUp / onDismiss / onOk（OK 先在应用级作用域启动导入，再回调 onOk，EF-A52）。
 */
import { AvoidArea, AvoidAreaStore } from '../../core/app/AvoidArea';
import { Feed } from '../../core/model/Feed';
import { FeederTheme, SensibleTopAppBar, isRtlText } from '../../ui/common/Theme';
import { OkCancelButtons } from '../../ui/common/CommonWidgets';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { pluralText } from '../../ui/common/FeedItemText';
import { ImportViewModel, ImportViewState } from './ImportViewModel';
import { LayoutAdapt, ScreenType, WindowMetrics } from '../../core/platform/LayoutAdapt';

const LOG_TAG: string = 'FEEDER_OPMLIMPORT';

/** 源 stringResource(R.string.failed_to_import_OPML)：Android 资源的成对引号在取值时去除 */
function stripAndroidQuotes(s: string): string {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

function stringByName(ui: UIContext, name: string, fallback: string): string {
  try {
    const ctx = ui.getHostContext();
    if (ctx !== undefined) {
      return stripAndroidQuotes(ctx.resourceManager.getStringByNameSync(name));
    }
  } catch (e) {
    console.warn(LOG_TAG, `string ${name} lookup failed: ${JSON.stringify(e)}`);
  }
  return fallback;
}

/** 源 OpmlImportView 的摘要文本分支（EF-A48） */
export function importSummaryText(ui: UIContext, s: ImportViewState): string {
  if (s.initial) {
    return '';
  }
  if (s.error) {
    return stringByName(ui, 'failed_to_import_OPML', 'Failed to import OPML');
  }
  if (s.feeds.length === 0) {
    return stringByName(ui, 'no_feeds', 'No feeds');
  }
  const feedCount: number = s.feedCount;
  const tagCount: number = s.tagCount;
  const feedsText: string = pluralText(ui, $r('app.plural.n_feeds'), feedCount, `${feedCount}`,
    feedCount === 1 ? 'feed' : 'feeds');
  const tagsText: string = pluralText(ui, $r('app.plural.n_tags'), tagCount, `${tagCount}`,
    tagCount === 1 ? 'tag' : 'tags');
  const fmt: string = stringByName(ui, 'import_x_feeds_with_y_tags', 'Import %1$s with %2$s?');
  return fmt.replace('%1$s', feedsText).replace('%2$s', tagsText);
}

@ComponentV2
export struct OpmlImportScreen {
  /** 导入源文件 URI（空串 ≙ 源 uri == null） */
  @Param uri: string = '';
  @Event onNavigateUp: () => void = () => {
    console.info('TODO:onNavigateUp:OpmlImportScreen');
  };
  @Event onDismiss: () => void = () => {
    console.info('TODO:onDismiss:OpmlImportScreen');
  };
  @Event onOk: () => void = () => {
    console.info('TODO:onOk:OpmlImportScreen');
  };
  @Local vm: ImportViewModel = new ImportViewModel();
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local listScrolled: boolean = false;
  /** 源 LocalWindowSizeMetrics（OpmlImportScreen.kt:117） */
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  private listScroller: Scroller = new Scroller();

  /** 源 OpmlImportScreen.kt:118-124：getScreenType DUAL → fillMaxHeight(0.5f)，SINGLE → 1.0f（UT-A42） */
  private screenHeightFraction(): string {
    return this.metrics.screenType === ScreenType.DUAL ? '50%' : '100%';
  }

  aboutToAppear(): void {
    this.vm.loadPreview(this.uri.length > 0 ? this.uri : null);
  }

  @Monitor('uri')
  onUriChange(): void {
    this.vm.loadPreview(this.uri.length > 0 ? this.uri : null);
  }

  @Computed
  get summaryText(): string {
    return importSummaryText(this.getUIContext(), this.vm.state);
  }

  @Builder
  navIconBuilder() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.arrow_left'))
        .fontSize('24vp')
        .fontColor([FeederTheme.colors.onSurface])
        .direction(Direction.Auto)
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .accessibilityText($r('app.string.go_back'))
    .onClick(() => {
      this.onNavigateUp();
    })
  }

  @Builder
  feedRowBuilder(feed: Feed) {
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
      Text(feed.title)
        .attributeModifier(textStyle(M3Type.titleSmall, true, FeederTheme.colors.onSurface))
        .direction(isRtlText(feed.title) ? Direction.Rtl : Direction.Ltr)
        .margin({ right: 4 })
      Text(feed.url)
        .attributeModifier(textStyle(M3Type.bodySmall, true, FeederTheme.colors.onSurface))
    }
    .width('100%')
  }

  build() {
    Column() {
      SensibleTopAppBar({
        titleText: stringByName(this.getUIContext(), 'import_feeds_from_opml', 'Import feeds from OPML'),
        scrolled: this.listScrolled,
        topInset: this.avoid.top,
        navigationIconBuilder: (): void => {
          this.navIconBuilder()
        }
      })
      // 源 OkCancelWithNonScrollableContent（padding horizontal = dimens.margin，fillMaxHeight）
      Column() {
        Text(this.summaryText)
          .attributeModifier(textStyle(M3Type.titleMedium, true, FeederTheme.colors.onSurface))
          .direction(isRtlText(this.summaryText) ? Direction.Rtl : Direction.Ltr)
          .width('100%')
        List({ space: 8, scroller: this.listScroller }) {
          LazyForEach(this.vm.dataSource, (feed: Feed) => {
            ListItem() {
              this.feedRowBuilder(feed)
            }
          }, (feed: Feed, index: number): string => `${this.vm.state.version}:${index}:${feed.url}:${feed.title}:${feed.tag}`)
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 16, bottom: 16 })
        .edgeEffect(EdgeEffect.Spring)
        .onDidScroll(() => {
          // 源 pinnedScrollBehavior：内容滚离顶部后顶栏换为 scrolledContainerColor
          this.listScrolled = this.listScroller.currentOffset().yOffset > 0;
        })
        OkCancelButtons({
          okEnabled: this.vm.state.okEnabled,
          onOk: () => {
            this.vm.confirmImport();
            this.onOk();
          },
          onCancel: () => {
            this.onDismiss();
          }
        })
        Column().height(this.avoid.bottom)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(this.screenHeightFraction())
    .backgroundColor(FeederTheme.colors.background)
  }
}
