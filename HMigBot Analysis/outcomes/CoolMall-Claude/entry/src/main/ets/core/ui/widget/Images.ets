/**
 * NetWorkImage + Avatar / SmallAvatar / MediumAvatar
 * (source: core/ui/component/image/NetWorkImage.kt, core/ui/component/image/Avatar.kt).
 *
 * NetWorkImage states (SubcomposeAsyncImage): Empty (model null/'' → optional background only),
 * Loading (centered 24vp spinner), Error (centered 24vp ic_error, optionally clickable), Success (image,
 * optional background behind it).
 * A2-15: Image callbacks never write state synchronously — onComplete (loadingStatus === 1 only) and
 * onError defer the write with setTimeout(…, 0), ignore results of a previous model, and stop after
 * the component is gone.
 * Sizing: `imageSize` > 0 → square of that size; otherwise the image fills the slot the caller gives it
 * (wrap it in a container with width/height or aspectRatio).
 */
const STATE_LOADING: number = 0;
const STATE_SUCCESS: number = 1;
const STATE_ERROR: number = 2;

function isEmptyModel(m: ResourceStr | PixelMap | null | undefined): boolean {
  if (m === undefined || m === null) {
    return true;
  }
  if (typeof m === 'string') {
    return m.length === 0;
  }
  return false;
}

@ComponentV2
export struct NetWorkImage {
  @Param model: ResourceStr | PixelMap | null | undefined = undefined;
  @Param imageSize: number = 0;
  /** ContentScale: default Crop → Cover */
  @Param contentScale: ImageFit = ImageFit.Cover;
  /** Spinner color; undefined = theme default (Color.Unspecified) */
  @Param loadingColor: ResourceColor | undefined = undefined;
  @Param errorColor: ResourceColor = Color.Gray;
  @Param showBackground: boolean = false;
  /** colorScheme.surfaceVariant */
  @Param backgroundColorRes: ResourceColor = $r('app.color.bg_content');
  /** cornerShape radius (0 = none) */
  @Param cornerRadius: number = 0;
  /** Source: onErrorClick != null → error icon becomes an IconButton */
  @Param errorClickable: boolean = false;
  @Event onErrorClick: () => void = () => {
  };
  @Local loadState: number = STATE_LOADING;
  private loadSeq: number = 0;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  @Monitor('model')
  onModelChanged(): void {
    this.loadSeq++;
    this.loadState = STATE_LOADING;
  }

  private deferState(seq: number, state: number): void {
    setTimeout(() => {
      if (this.alive && seq === this.loadSeq) {
        this.loadState = state;
      }
    }, 0);
  }

  private boxSize(): Length {
    return this.imageSize > 0 ? this.imageSize : '100%';
  }

  build() {
    // source: state placeholders use contentAlignment = Center
    Stack({ alignContent: Alignment.Center }) {
      if (this.showBackground) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.backgroundColorRes)
          .hitTestBehavior(HitTestMode.Transparent)
      }
      if (!isEmptyModel(this.model)) {
        Image(this.model as ResourceStr | PixelMap)
          .width('100%')
          .height('100%')
          .objectFit(this.contentScale)
          .draggable(false)
          .visibility(this.loadState === STATE_ERROR ? Visibility.Hidden : Visibility.Visible)
          .onComplete((event) => {
            if (event !== undefined && event.loadingStatus === 1) {
              this.deferState(this.loadSeq, STATE_SUCCESS);
            }
          })
          .onError(() => {
            this.deferState(this.loadSeq, STATE_ERROR);
          })
        if (this.loadState === STATE_LOADING) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.loadingColor !== undefined ? this.loadingColor : $r('app.color.text_tertiary'))
            .hitTestBehavior(HitTestMode.Transparent)
        } else if (this.loadState === STATE_ERROR) {
          Image($r('app.media.ic_error'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
            .fillColor(this.errorColor)
            .accessibilityText($r('app.string.image_load_error'))
            .onClick(() => {
              if (this.errorClickable) {
                this.onErrorClick();
              }
            })
            .hitTestBehavior(this.errorClickable ? HitTestMode.Default : HitTestMode.Transparent)
        }
      }
    }
    .width(this.boxSize())
    .height(this.boxSize())
    .borderRadius(this.cornerRadius)
    .clip(true)
  }
}

/**
 * Avatar: default avatar (ic_my_fill at half size on a faint background) when the url is empty,
 * otherwise NetWorkImage with background. `avatarRadius` < 0 → circle. Clickable only when
 * `clickable` (source: onClick != null).
 */
@ComponentV2
export struct Avatar {
  @Param avatarUrl: string | null | undefined = undefined;
  @Param avatarSize: number = 36;
  @Param avatarRadius: number = -1;
  @Param contentScale: ImageFit = ImageFit.Cover;
  @Param clickable: boolean = false;
  @Event onAvatarClick: () => void = () => {
  };

  private radius(): number {
    return this.avatarRadius < 0 ? this.avatarSize / 2 : this.avatarRadius;
  }

  private isDefault(): boolean {
    return this.avatarUrl === undefined || this.avatarUrl === null || (this.avatarUrl as string).length === 0;
  }

  build() {
    // DefaultAvatar: Box(contentAlignment = Center)
    Stack({ alignContent: Alignment.Center }) {
      if (this.isDefault()) {
        Image($r('app.media.ic_my_fill'))
          .width(this.avatarSize * 0.5)
          .height(this.avatarSize * 0.5)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_tertiary'))
          .accessibilityText($r('app.string.default_avatar'))
      } else {
        NetWorkImage({
          model: this.avatarUrl,
          contentScale: this.contentScale,
          showBackground: true,
          cornerRadius: this.radius()
        })
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .backgroundColor(this.isDefault() ? $r('app.color.bg_content') : Color.Transparent)
    .borderRadius(this.radius())
    .clip(true)
    .onClick(() => {
      if (this.clickable) {
        this.onAvatarClick();
      }
    })
    .hitTestBehavior(this.clickable ? HitTestMode.Default : HitTestMode.None)
  }
}

/** SmallAvatar: Avatar with default size 36. */
@ComponentV2
export struct SmallAvatar {
  @Param avatarUrl: string | null | undefined = undefined;
  @Param avatarSize: number = 36;
  @Param clickable: boolean = false;
  @Event onAvatarClick: () => void = () => {
  };

  build() {
    Avatar({
      avatarUrl: this.avatarUrl,
      avatarSize: this.avatarSize,
      clickable: this.clickable,
      onAvatarClick: (): void => this.onAvatarClick()
    })
  }
}

/** MediumAvatar: Avatar with default size 48. */
@ComponentV2
export struct MediumAvatar {
  @Param avatarUrl: string | null | undefined = undefined;
  @Param avatarSize: number = 48;
  @Param clickable: boolean = false;
  @Event onAvatarClick: () => void = () => {
  };

  build() {
    Avatar({
      avatarUrl: this.avatarUrl,
      avatarSize: this.avatarSize,
      clickable: this.clickable,
      onAvatarClick: (): void => this.onAvatarClick()
    })
  }
}
