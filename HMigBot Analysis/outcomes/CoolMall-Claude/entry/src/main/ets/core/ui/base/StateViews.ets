/**
 * StateViews — page state views (source: core/ui/component/{empty,loading,network}/**).
 *
 * Exports:
 *  - EmptyView (source Empty.kt), EmptyData / EmptyNetwork / EmptyError / EmptyCart
 *  - WeLoading / MiLoadingMobile (source loading/Loading.kt), PageLoading (loading/PageLoading.kt)
 *  - LoadMoreFooter (source loading/LoadMore.kt `LoadMore`)
 *  - NetWorkStateView (source network/BaseNetWorkView.kt + BaseNetWorkListView.kt): loading / success / error
 *    (+ 'empty' for list view models), @BuilderParam content, error retry.
 *
 * Source onRetryClick / onRetry is nullable ("no callback → no retry button"); ArkTS @Event cannot be
 * tested for presence, so the empty views take an explicit `showRetry` flag next to `onRetryClick`.
 */
import { LoadMoreState } from '../../common/LoadMoreState';
import { ThemeManager } from '../../designsystem/ThemeManager';
import { Dimens } from '../../designsystem/Dimens';

/** Empty.kt icon size 120.dp */
const EMPTY_ICON_SIZE: number = 120;
/** Empty.kt retry button: padding(horizontal = 50.dp).widthIn(200.dp) */
const EMPTY_BUTTON_MIN_WIDTH: number = 200;
const EMPTY_BUTTON_H_MARGIN: number = 50;
/** M3 OutlinedButton height */
const OUTLINED_BUTTON_HEIGHT: number = 40;
/** AnimatedContent fade (tween(300)) */
const STATE_FADE_MS: number = 300;

/**
 * M3 default outlineVariant (not overridden by the app theme) at alpha 0.8 — LoadMore NoMore divider/dot.
 * light #CAC4D0 / dark #49454F.
 */
function noMoreColor(): string {
  return ThemeManager.instance.isDark ? '#CC49454F' : '#CCCAC4D0';
}

// =====================================================================================================
// Empty states
// =====================================================================================================

/**
 * Generic page state view (source Empty.kt `Empty`; renamed EmptyView to avoid a bare-name clash).
 * Column fillMaxSize + padding 16, centered both ways (source Arrangement.Center + CenterHorizontally).
 */
@ComponentV2
export struct EmptyView {
  /** Main message (source message, default R.string.empty_error) */
  @Param message: ResourceStr = $r('app.string.empty_error');
  /** Subtitle (source subtitle: Int? = null); null → hidden */
  @Param subtitle: ResourceStr | null = null;
  /** Retry button text (source retryButtonText, default R.string.click_retry) */
  @Param retryButtonText: ResourceStr = $r('app.string.click_retry');
  /** Illustration (source icon, default R.drawable.ic_empty_error) */
  @Param icon: Resource = $r('app.media.ic_empty_error');
  /** Show the retry button (source: onRetryClick != null) */
  @Param showRetry: boolean = false;
  /** Retry click */
  @Event onRetryClick: () => void = () => {
  };

  build() {
    // Source: Column(verticalArrangement = Center, horizontalAlignment = CenterHorizontally)
    Column() {
      Image(this.icon)
        .width(EMPTY_ICON_SIZE)
        .height(EMPTY_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        // tint = onSurface.copy(alpha = 0.2F): single-color svg tinted with text_primary at 20 % opacity
        .fillColor($r('app.color.text_primary'))
        .opacity(0.2)
      Text(this.message)
        .margin({ top: Dimens.spaceVerticalXLarge })
        .fontSize(Dimens.fontTitleLarge)
        .lineHeight(Dimens.lineTitleLarge)
        .fontWeight(Dimens.weightBold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      if (this.subtitle !== null) {
        Text(this.subtitle as ResourceStr)
          .margin({ top: Dimens.spaceVerticalSmall })
          .fontSize(Dimens.fontBodyMedium)
          .lineHeight(Dimens.lineBodyMedium)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
      }
      if (this.showRetry) {
        // OutlinedButton(border = 0.5dp primary).padding(horizontal = 50.dp).widthIn(200.dp)
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Text(this.retryButtonText)
            .fontSize(Dimens.fontBodyLarge)
            .fontWeight(Dimens.weightMedium)
            .fontColor(ThemeManager.instance.primary)
        }
        .height(OUTLINED_BUTTON_HEIGHT)
        .constraintSize({ minWidth: EMPTY_BUTTON_MIN_WIDTH })
        .padding({ left: Dimens.spaceHorizontalXLarge, right: Dimens.spaceHorizontalXLarge })
        .margin({ top: Dimens.spaceVerticalXLarge, left: EMPTY_BUTTON_H_MARGIN, right: EMPTY_BUTTON_H_MARGIN })
        .backgroundColor(Color.Transparent)
        .border({ width: 0.5, color: ThemeManager.instance.primary })
        .onClick(() => {
          this.onRetryClick();
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding(Dimens.spacePaddingLarge)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center) // source horizontalAlignment = CenterHorizontally
  }
}

/** No data (source EmptyData.kt): `暂无数据` / `暂时没有相关内容` */
@ComponentV2
export struct EmptyData {
  @Param showRetry: boolean = false;
  @Event onRetryClick: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      EmptyView({
        message: $r('app.string.empty_data'),
        subtitle: $r('app.string.empty_data_subtitle'),
        icon: $r('app.media.ic_empty_data'),
        retryButtonText: $r('app.string.click_retry'),
        showRetry: this.showRetry,
        onRetryClick: () => {
          this.onRetryClick();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

/** Network failure (source EmptyNetwork.kt): `网络连接失败` / `请检查网络连接后重试` / `重新加载` */
@ComponentV2
export struct EmptyNetwork {
  @Param showRetry: boolean = false;
  @Event onRetryClick: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      EmptyView({
        message: $r('app.string.empty_network'),
        subtitle: $r('app.string.empty_network_subtitle'),
        icon: $r('app.media.ic_empty_network'),
        retryButtonText: $r('app.string.click_retry'),
        showRetry: this.showRetry,
        onRetryClick: () => {
          this.onRetryClick();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

/** Load failure (source EmptyError.kt): `加载失败` / `页面加载出现了问题` */
@ComponentV2
export struct EmptyError {
  @Param showRetry: boolean = false;
  @Event onRetryClick: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      EmptyView({
        message: $r('app.string.empty_error'),
        subtitle: $r('app.string.empty_error_subtitle'),
        icon: $r('app.media.ic_empty_error'),
        retryButtonText: $r('app.string.click_retry'),
        showRetry: this.showRetry,
        onRetryClick: () => {
          this.onRetryClick();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

/** Empty cart (source EmptyCart.kt): `购物车是空的` / `快去添加商品吧` / button `去逛逛` */
@ComponentV2
export struct EmptyCart {
  @Param showRetry: boolean = false;
  @Event onRetryClick: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      EmptyView({
        message: $r('app.string.empty_cart'),
        subtitle: $r('app.string.empty_cart_subtitle'),
        icon: $r('app.media.ic_empty_cart'),
        retryButtonText: $r('app.string.empty_cart_btn'),
        showRetry: this.showRetry,
        onRetryClick: () => {
          this.onRetryClick();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

// =====================================================================================================
// Loading indicators
// =====================================================================================================

/**
 * Small rotating loading icon (source Loading.kt `WeLoading`, 16dp, 1000 ms linear rotation).
 * The converted ic_loading.svg lost its gradient fills (stroke-only black outline), so the built-in
 * LoadingProgress spinner is used instead (visual approximation).
 */
@ComponentV2
export struct WeLoading {
  @Param loadingSize: number = 16;
  /** Source tint (Color.Unspecified → the drawable's own #606060 gray) */
  @Param loadingColor: ResourceColor = '#E6606060';

  build() {
    Stack({ alignContent: Alignment.Center }) { // icon centered in its own box
      LoadingProgress()
        .width(this.loadingSize)
        .height(this.loadingSize)
        .color(this.loadingColor)
    }
    .width(this.loadingSize)
    .height(this.loadingSize)
  }
}

/**
 * Xiaomi-style loader: a dot orbiting inside a 28dp ring with a 2dp border (source `MiLoadingMobile`,
 * 1200 ms linear, orbit radius = ringSize/2 - 8, dot radius 3dp).
 * `rotating = false` draws the static ring with the dot at angle 0 (RefreshHeader idle state).
 * `ringSize`: 28 by default; RefreshHeader constrains it to a 24dp box (orbit radius 4).
 */
@ComponentV2
export struct MiLoadingMobile {
  @Param ringColor: ResourceColor = $r('app.color.text_primary');
  /** Dot color; undefined → same as ringColor */
  @Param dotColor: ResourceColor | undefined = undefined;
  @Param rotating: boolean = true;
  @Param ringSize: number = 28;
  @Local angle: number = 0;

  private startRotation(): void {
    if (!this.rotating) {
      return;
    }
    this.getUIContext().animateTo({ duration: 1200, curve: Curve.Linear, iterations: -1 }, () => {
      this.angle = 360;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) { // dot orbit is centered on the ring
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(6)
          .height(6)
          .fill(this.dotColor !== undefined ? this.dotColor as ResourceColor : this.ringColor)
          .translate({ x: Math.max(0, this.ringSize / 2 - 8) })
      }
      .width('100%')
      .height('100%')
      .rotate({ angle: this.rotating ? this.angle : 0 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width(this.ringSize)
    .height(this.ringSize)
    .borderRadius(this.ringSize / 2)
    .border({ width: 2, color: this.ringColor })
    .onAppear(() => {
      this.startRotation();
    })
  }
}

/** Page loading (source PageLoading.kt): centered MiLoadingMobile(onSurface@0.6) + `加载中...` */
@ComponentV2
export struct PageLoading {
  build() {
    Column() {
      MiLoadingMobile({ ringColor: ThemeManager.instance.isDark ? '#99D1D1D1' : '#99181818' })
      Text($r('app.string.loading'))
        .margin({ top: Dimens.spaceVerticalSmall })
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(Dimens.lineBodyMedium)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center) // source horizontalAlignment = CenterHorizontally
  }
}

// =====================================================================================================
// Load more footer
// =====================================================================================================

/**
 * List footer load state (source LoadMore.kt `LoadMore`). Row fillMaxWidth, padding(vertical = 20.dp),
 * Arrangement.Center + CenterVertically.
 *  - PullToLoad: divider · `上拉加载更多` · divider
 *  - Loading:    spinner + `正在加载...`
 *  - Success:    divider · `加载成功` · divider
 *  - Error:      divider · `加载失败，点击重试` (clickable, when retry enabled) or `加载失败` · divider
 *  - NoMore:     divider · dot · divider (source shows no text in this state)
 * The auto-scroll-to-bottom while Loading lives in RefreshList (it owns the Scroller).
 */
@ComponentV2
export struct LoadMoreFooter {
  @Param loadState: LoadMoreState = LoadMoreState.PullToLoad;
  /** Source onRetry != null */
  @Param retryEnabled: boolean = false;
  @Event onRetry: () => void = () => {
  };

  @Builder
  lineDivider(color: ResourceColor) {
    Divider()
      .strokeWidth(0.5)
      .color(color)
      .layoutWeight(1)
  }

  build() {
    Row() {
      if (this.loadState === LoadMoreState.PullToLoad) {
        this.lineDivider($r('app.color.border'))
        Text($r('app.string.load_more_pull'))
          .padding({ left: 8, right: 8 })
          .fontSize(Dimens.fontBodyLarge)
          .fontColor($r('app.color.text_secondary'))
        this.lineDivider($r('app.color.border'))
      } else if (this.loadState === LoadMoreState.Loading) {
        WeLoading()
        Text($r('app.string.load_more_loading'))
          .margin({ left: 8 })
          .fontSize(Dimens.fontBodyLarge)
          .fontColor($r('app.color.text_primary'))
      } else if (this.loadState === LoadMoreState.Success) {
        this.lineDivider($r('app.color.border'))
        Text($r('app.string.load_more_success'))
          .padding({ left: 8, right: 8 })
          .fontSize(Dimens.fontBodyLarge)
          .fontColor($r('app.color.text_primary'))
        this.lineDivider($r('app.color.border'))
      } else if (this.loadState === LoadMoreState.Error) {
        this.lineDivider($r('app.color.border'))
        if (this.retryEnabled) {
          Text($r('app.string.load_more_error_retry'))
            .margin({ left: 8, right: 8 })
            .padding({ top: 4, bottom: 4 })
            .borderRadius(Dimens.radiusSmall)
            .fontSize(Dimens.fontBodyLarge)
            .fontColor($r('app.color.danger'))
            .onClick(() => {
              this.onRetry();
            })
        } else {
          Text($r('app.string.load_more_error'))
            .padding({ left: 8, right: 8 })
            .fontSize(Dimens.fontBodyLarge)
            .fontColor($r('app.color.danger'))
        }
        this.lineDivider($r('app.color.border'))
      } else {
        // NoMore: divider + 4dp dot + divider (outlineVariant @ 0.8)
        this.lineDivider(noMoreColor())
        Circle()
          .width(4)
          .height(4)
          .fill(noMoreColor())
          .margin({ left: 8, right: 8 })
        this.lineDivider(noMoreColor())
      }
    }
    .width('100%')
    .padding({ top: 20, bottom: 20 })
    .justifyContent(FlexAlign.Center) // source horizontalArrangement = Center
    .alignItems(VerticalAlign.Center) // source verticalAlignment = CenterVertically
  }
}

// =====================================================================================================
// Network state container
// =====================================================================================================

/**
 * Network state container (source BaseNetWorkView / BaseNetWorkListView).
 * uiState: 'loading' | 'success' | 'error' (BaseNetWorkViewModel.uiState) or additionally 'empty'
 * (BaseNetWorkListViewModel.uiState). Defaults: PageLoading / EmptyNetwork(retry) / EmptyData(retry).
 * State switches cross-fade in 300 ms (source AnimatedContent fadeIn/fadeOut tween(300)).
 *
 * Usage:
 *   NetWorkStateView({
 *     uiState: this.vm.uiState,
 *     onRetry: () => { this.vm.retryRequest(); },
 *     content: (): void => { this.successContent() },
 *     customLoading: (): void => { this.skeleton() },        // optional
 *     useCustomLoading: true
 *   })
 */
@ComponentV2
export struct NetWorkStateView {
  /** Current UI state string */
  @Param uiState: string = 'loading';
  /** Source `padding: PaddingValues` applied to the root box */
  @Param statePadding: Padding | Length = 0;
  /** Use customLoading / customError / customEmpty instead of the defaults */
  @Param useCustomLoading: boolean = false;
  @Param useCustomError: boolean = false;
  @Param useCustomEmpty: boolean = false;
  /** Retry from the default error / empty views */
  @Event onRetry: () => void = () => {
  };
  /** Success content (read data from the view model directly) */
  @BuilderParam content: () => void = this.emptyBuilder;
  @BuilderParam customLoading: () => void = this.emptyBuilder;
  @BuilderParam customError: () => void = this.emptyBuilder;
  @BuilderParam customEmpty: () => void = this.emptyBuilder;

  @Builder
  emptyBuilder() {
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) { // source Box (top-start)
      if (this.uiState === 'loading') {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.useCustomLoading) {
            this.customLoading()
          } else {
            PageLoading()
          }
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      } else if (this.uiState === 'error') {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.useCustomError) {
            this.customError()
          } else {
            EmptyNetwork({
              showRetry: true,
              onRetryClick: () => {
                this.onRetry();
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      } else if (this.uiState === 'empty') {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.useCustomEmpty) {
            this.customEmpty()
          } else {
            EmptyData({
              showRetry: true,
              onRetryClick: () => {
                this.onRetry();
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          this.content()
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: STATE_FADE_MS }))
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.statePadding)
  }
}
