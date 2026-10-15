/**
 * CaptchaImage (source: feature/auth/component/ImageCaptchaDialog.kt CaptchaImage).
 * 120x40 captcha image decoded from base64 (an optional `data:...;base64,` prefix is stripped); tapping it
 * fetches a new captcha. When the data is blank, cannot be base64-decoded, or the image fails to decode,
 * a light-gray `点击刷新` placeholder of the same size is shown instead, which also refreshes on tap.
 */
import { util } from '@kit.ArkTS';

const CAPTCHA_WIDTH: number = 120;
const CAPTCHA_HEIGHT: number = 40;
/** Color.LightGray (#CCCCCC) @ alpha 0.3 */
const PLACEHOLDER_BG: string = '#4DCCCCCC';

@ComponentV2
export struct CaptchaImage {
  /** Captcha.data (base64, possibly with a data URI prefix) */
  @Param captchaData: string = '';
  @Event onRefresh: () => void = () => {
  };
  /** Image source (data URI) or '' when the data is unusable */
  @Local imageSrc: string = '';
  /** The image component reported a decode failure for the current data */
  @Local decodeFailed: boolean = false;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.rebuildSource();
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  @Monitor('captchaData')
  onCaptchaChanged(monitor: IMonitor): void {
    this.rebuildSource();
  }

  private rebuildSource(): void {
    this.decodeFailed = false;
    const data: string = this.captchaData ?? '';
    if (data.trim().length === 0) {
      this.imageSrc = '';
      return;
    }
    const idx: number = data.indexOf('base64,');
    const pureBase64: string = idx >= 0 ? data.substring(idx + 'base64,'.length) : data;
    let bytes: Uint8Array | null = null;
    try {
      bytes = new util.Base64Helper().decodeSync(pureBase64.replace(new RegExp('\\s', 'g'), ''));
    } catch (e) {
      console.error(`CaptchaImage Base64 decode failed: ${(e as Error).message}`);
      bytes = null;
    }
    if (bytes === null || bytes.length === 0) {
      this.imageSrc = '';
      return;
    }
    this.imageSrc = 'data:image/png;base64,' + pureBase64;
  }

  @Builder
  refreshPlaceholder() {
    Stack({ alignContent: Alignment.Center }) { // source Box(contentAlignment = Center)
      Text($r('app.string.refresh_captcha'))
        .fontSize(12)
        .fontColor(Color.Gray)
        .textAlign(TextAlign.Center)
    }
    .width(CAPTCHA_WIDTH)
    .height(CAPTCHA_HEIGHT)
    .backgroundColor(PLACEHOLDER_BG)
    .onClick(() => {
      this.onRefresh();
    })
  }

  build() {
    Column() {
      if (this.imageSrc.length === 0 || this.decodeFailed) {
        this.refreshPlaceholder()
      } else {
        Image(this.imageSrc)
          .width(CAPTCHA_WIDTH)
          .height(CAPTCHA_HEIGHT)
          .objectFit(ImageFit.Contain) // Compose Image default ContentScale.Fit
          .draggable(false)
          .accessibilityText($r('app.string.image_captcha_description'))
          .onError(() => {
            // A2-15: never write state synchronously from an image callback
            setTimeout(() => {
              if (this.alive) {
                this.decodeFailed = true;
              }
            }, 0);
          })
          .onClick(() => {
            this.onRefresh();
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
  }
}
