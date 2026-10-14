/**
 * SearchFeedScreen.ets —— 源 ui/compose/searchfeed/SearchFeedScreen.kt 的 SearchFeedScreen（Scaffold + 顶栏）与
 * 无状态 SearchFeedView / leftContent / rightContent / SearchingIndicator / SearchResultView / ErrorResultView。
 * SearchFeedPage 与 SearchPage（分享入口）共用本组件（源两处都调用 SearchFeedScreen）。
 *
 * 层级（源 Scaffold → Box(TopCenter, verticalScroll)）：
 *   Column
 *    ├ SensibleTopAppBar(`Add feed`, ArrowBack `Go back`)  [topInset = 状态栏避让，EF-A01/A19]
 *    └ Scroll（纵向，EF-A14）
 *       └ Column(TopCenter)
 *          ├ DUAL：Row(maxContentWidth){ Column(left, weight1) | Column(right, weight1) }
 *          └ SINGLE：Column(maxContentWidth){ left ; right }
 * left = 单行输入框 `Feed URL`(urlField) + `Search` 描边按钮；right = 推荐区 + 错误卡/结果卡 + 进度圈。
 */
import { common } from '@kit.AbilityKit';
import { AppRouter, Routes } from '../../common/Router';
import { AddFeedParam } from '../../core/app/RouteParams';
import { ScreenType, WindowMetrics, LayoutAdapt, getScreenType } from '../../core/platform/LayoutAdapt';
import { FeedParserError } from '../../core/parser/FeedParserError';
import { FeederTheme, SensibleTopAppBar } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { KEY_ENTER, KEY_ESCAPE, interceptKey } from '../../ui/common/CommonWidgets';
import { SearchFeedViewModel, addAnywayResult } from './SearchFeedViewModel';
import { SearchResult } from './SearchResult';
import { FeederEditMenuOptions } from '../../core/platform/TextToolbar';

const LOG_TAG: string = 'FEEDER_SEARCH';
export const URL_FIELD_ID: string = 'urlField';
export const SEARCHING_INDICATOR_ID: string = 'searchingIndicator';
export const SEARCH_RESULT_ID: string = 'searchResult';
export const ERROR_RESULT_ID: string = 'errorResult';

/** 源 rightContent 的错误标题映射（EF-A10） */
export function errorTitleOf(error: FeedParserError): ResourceStr {
  switch (error.kind) {
    case 'FetchError':
      return $r('app.string.failed_to_download');
    case 'MetaDataParseError':
      return $r('app.string.failed_to_parse_the_page');
    case 'NoAlternateFeeds':
      return $r('app.string.no_feeds_in_the_page');
    case 'NotHTML':
      return $r('app.string.content_is_not_html');
    case 'RSSParseError':
      return $r('app.string.failed_to_parse_rss_feed');
    case 'HttpError':
      return $r('app.string.http_error');
    case 'JsonFeedParseError':
      return $r('app.string.failed_to_parse_json_feed');
    case 'NoBody':
      return $r('app.string.no_body_in_response');
    case 'UnsupportedContentType':
      return $r('app.string.unsupported_content_type');
    case 'FullTextDecodingFailure':
      return $r('app.string.failed_to_parse_full_article');
    case 'FullTextTooLarge':
      return $r('app.string.failed_to_fetch_full_article_too_large');
    case 'NoUrl':
      return $r('app.string.no_url');
    default:
      // NotInitializedYet：源硬编码 "Not initialized yet"（Should never happen）
      return 'Not initialized yet';
  }
}

/** 顶栏标题 `Add feed`（SensibleTopAppBar 取 string，按资源名解析） */
export function resolveAddFeedTitle(ctx: common.Context | undefined): string {
  if (ctx === undefined) {
    return '';
  }
  try {
    return ctx.resourceManager.getStringByNameSync('add_feed');
  } catch (e) {
    console.warn(`${LOG_TAG}: resolve add_feed failed: ${(e as Error)?.message}`);
    return '';
  }
}

/** 源 onClick = { AddFeedDestination.navigate(feedUrl = it.url, feedTitle = it.title, feedImage = it.feedImage) } */
export function navigateToAddFeed(r: SearchResult): void {
  AppRouter.push(Routes.ADD_FEED, AddFeedParam.of(r.url, r.title, r.feedImage));
}

let placeholderVm: SearchFeedViewModel | null = null;

/** @Param 默认值占位（未 initialize，不发起任何请求） */
export function placeholderSearchFeedViewModel(): SearchFeedViewModel {
  if (placeholderVm === null) {
    placeholderVm = new SearchFeedViewModel();
  }
  return placeholderVm as SearchFeedViewModel;
}

@ComponentV2
export struct SearchFeedScreen {
  @Param vm: SearchFeedViewModel = placeholderSearchFeedViewModel();
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param barTitle: string = '';
  @Event onNavigateUp: () => void = () => {
  };
  @Event onResultClick: (r: SearchResult) => void = (r: SearchResult) => {
  };
  @Local metrics: WindowMetrics = LayoutAdapt.metrics();
  @Local inputFocused: boolean = false;
  private scroller: Scroller = new Scroller();

  private screenType(): ScreenType {
    return getScreenType(this.metrics.widthClass);
  }

  private dropFocus(): void {
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (e) {
      console.warn(`${LOG_TAG}: clearFocus failed: ${(e as Error)?.message}`);
    }
  }

  /** 源 onSearch + keyboardController.hide()/clearFocus()（EF-A05） */
  private submitSearch(): void {
    if (this.vm.searchCurrentInput()) {
      this.dropFocus();
    }
  }

  // ---------------------------------------------------------------- 顶栏

  @Builder
  navIconBuilder() {
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
      this.onNavigateUp();
    })
  }

  // ---------------------------------------------------------------- 左栏：输入框 + 按钮

  @Builder
  urlFieldBuilder() {
    // 源 M3 TextField（filled）：容器 surfaceContainerHighest、浮动标签、底部指示线；isError → 错误色
    Column() {
      if (this.vm.feedUrl.length > 0 || this.inputFocused) {
        Text($r('app.string.add_feed_search_hint'))
          .attributeModifier(textStyle(M3Type.bodySmall, false,
            this.vm.isNotValidUrl ? FeederTheme.colors.error :
              (this.inputFocused ? FeederTheme.colors.primary : FeederTheme.colors.onSurfaceVariant)))
          .padding({ left: 16, right: 16, top: 8 })
      }
      TextInput({
        text: this.vm.feedUrl,
        placeholder: (this.vm.feedUrl.length > 0 || this.inputFocused) ? '' : $r('app.string.add_feed_search_hint')
      })
        .editMenuOptions(new FeederEditMenuOptions((): string => this.vm.feedUrl))
        .id(URL_FIELD_ID)
        .type(InputType.URL)
        .enterKeyType(EnterKeyType.Search)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .fontColor(FeederTheme.colors.onSurface)
        .caretColor(this.vm.isNotValidUrl ? FeederTheme.colors.error : FeederTheme.colors.primary)
        .placeholderColor(this.vm.isNotValidUrl ? FeederTheme.colors.error : FeederTheme.colors.onSurfaceVariant)
        .fontSize(16)
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .width('100%')
        .onChange((value: string) => {
          if (value !== this.vm.feedUrl) {
            this.vm.onUrlChange(value);
          }
        })
        .onSubmit((key: EnterKeyType) => {
          // 软键盘搜索键（源 KeyboardActions.onSearch）
          this.submitSearch();
        })
        .onKeyPreIme((event: KeyEvent): boolean => {
          // 源 interceptKey(Key.Enter) / interceptKey(Key.Escape, clearFocus)
          if (interceptKey(event, KEY_ENTER, () => {
            this.submitSearch();
          })) {
            return true;
          }
          return interceptKey(event, KEY_ESCAPE, () => {
            this.dropFocus();
          });
        })
        .onFocus(() => {
          this.inputFocused = true;
        })
        .onBlur(() => {
          this.inputFocused = false;
        })
      Divider()
        .strokeWidth(this.inputFocused || this.vm.isNotValidUrl ? 2 : 1)
        .color(this.vm.isNotValidUrl ? FeederTheme.colors.error :
          (this.inputFocused ? FeederTheme.colors.primary : FeederTheme.colors.onSurfaceVariant))
    }
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .borderRadius({ topLeft: 4, topRight: 4 })
  }

  @Builder
  leftContentBuilder() {
    this.urlFieldBuilder()
    // 源 OutlinedButton(enabled = isValidUrl) { Text(android.R.string.search_go) }
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text($r('app.string.search_verb'))
        .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.primary))
    }
    .enabled(this.vm.isValidUrl)
    .opacity(this.vm.isValidUrl ? 1 : 0.38)
    .height(40)
    .padding({ left: 24, right: 24 })
    .backgroundColor(Color.Transparent)
    .border({ width: 1, color: this.vm.isValidUrl ? FeederTheme.colors.outline : FeederTheme.colors.onSurface })
    .onClick(() => {
      this.submitSearch();
    })
  }

  // ---------------------------------------------------------------- 右栏：推荐 / 错误 / 结果 / 进度

  @Builder
  resultCardBuilder(item: SearchResult) {
    // 源 SearchResultView：Card(onClick){ Column(spacedBy 4, padding 8){ 标题 titleSmall; 描述(非空白); URL } }
    Column({ space: 4 }) {
      Text(item.title)
        .attributeModifier(textStyle(M3Type.titleSmall, false, FeederTheme.colors.onSurface))
      if (item.description.trim().length > 0) {
        Text(item.description)
          .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurface))
      }
      Text(item.url)
        .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurface))
    }
    .id(SEARCH_RESULT_ID)
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .padding(8)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .borderRadius(12)
    .clip(true)
    .stateStyles({
      pressed: {
        .backgroundColor(FeederTheme.colors.surfaceVariant)
      }
    })
    .onClick(() => {
      this.onResultClick(item);
    })
  }

  @Builder
  errorCardBuilder(error: FeedParserError) {
    // 源 ErrorResultView：Card{ Column(spacedBy 4, padding 8){ 错误色标题; URL; 描述; OutlinedButton(Add anyway) } }
    Column({ space: 4 }) {
      Text(errorTitleOf(error))
        .attributeModifier(textStyle(M3Type.titleSmall, false, FeederTheme.colors.error))
      Text(error.url)
        .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurface))
      Text(error.description)
        .attributeModifier(textStyle(M3Type.bodyMedium, false, FeederTheme.colors.onSurface))
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text($r('app.string.add_anyway'))
          .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.primary))
      }
      .height(40)
      .padding({ left: 24, right: 24 })
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: FeederTheme.colors.outline })
      .onClick(() => {
        this.onResultClick(addAnywayResult(error));
      })
    }
    .id(ERROR_RESULT_ID)
    .width('100%')
    .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
    .padding(8)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(FeederTheme.colors.surfaceContainerHighest)
    .borderRadius(12)
  }

  @Builder
  rightContentBuilder() {
    Column({ space: 8 }) {
      if (this.vm.suggestions.length > 0) {
        Text($r('app.string.feed_search_suggestions_header'))
          .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onSurface))
          .alignSelf(ItemAlign.Start)
        ForEach(this.vm.suggestions, (s: SearchResult) => {
          this.resultCardBuilder(s)
        }, (s: SearchResult, idx: number) => `sug-${idx}-${s.url}-${s.title}-${s.description}`)
      }
      if (this.vm.results.length === 0) {
        ForEach(this.vm.visibleErrors, (e: FeedParserError) => {
          this.errorCardBuilder(e)
        }, (e: FeedParserError, idx: number) => `err-${idx}-${e.kind}-${e.url}-${e.description}`)
      }
      ForEach(this.vm.results, (r: SearchResult) => {
        this.resultCardBuilder(r)
      }, (r: SearchResult, idx: number) => `res-${idx}-${r.url}-${r.title}-${r.description}-${r.feedImage}`)
      if (this.vm.currentlySearching) {
        // 源 AnimatedVisibility { SearchingIndicator() }：Box(Center, fillMaxWidth){ CircularProgressIndicator }
        Row() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(FeederTheme.colors.primary)
        }
        .id(SEARCHING_INDICATOR_ID)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ---------------------------------------------------------------- 布局

  @Builder
  bodyBuilder() {
    if (this.screenType() === ScreenType.DUAL) {
      Row() {
        Column({ space: 8 }) {
          this.leftContentBuilder()
        }
        .layoutWeight(1)
        .padding({
          left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8
        })
        .alignItems(HorizontalAlign.Center)

        Column({ space: 8 }) {
          this.rightContentBuilder()
        }
        .layoutWeight(1)
        .padding({
          left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8
        })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)
    } else {
      Column({ space: 8 }) {
        this.leftContentBuilder()
        this.rightContentBuilder()
      }
      .width('100%')
      .constraintSize({ maxWidth: FeederTheme.dimens.maxContentWidth })
      .padding({
        left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin, top: 8, bottom: 8
      })
      .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    Column() {
      SensibleTopAppBar({
        titleText: this.barTitle,
        scrolled: false,
        topInset: this.topInset,
        navigationIconBuilder: (): void => {
          this.navIconBuilder()
        }
      })
      Scroll(this.scroller) {
        Column() {
          this.bodyBuilder()
        }
        .width('100%')
        .padding({ bottom: this.bottomInset })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(FeederTheme.colors.background)
  }
}
