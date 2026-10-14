/**
 * InAppBrowser —— 源 CustomTabsIntent（ActivityLauncher.openLinkInCustomTab）的鸿蒙等价物：应用内浏览页。
 * 全屏自定义对话框（ComponentContent + openCustomDialog）内嵌 ArkWeb Web 组件：
 *  - 顶部工具栏（toolbarColor 着色）：关闭、页面标题/地址、分享（源 CustomTab 默认分享菜单项）、用外部浏览器打开；
 *  - 系统返回：网页可后退则后退，否则关闭浏览页。
 * 模块加载即向 core/platform/LinkOpener 注册 setInAppBrowserHook（CUSTOM_TAB 路由与 Article 顶栏 `Open in Web view` 使用，
 * AR-A17/A34/A49）；registerInAppBrowser() 幂等，可由任意入口提前调用。
 */
import { common } from '@kit.AbilityKit';
import { ComponentContent, promptAction, window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { AvoidArea, AvoidAreaStore } from '../../core/app/AvoidArea';
import { ActivityLauncher, setInAppBrowserHook } from '../../core/platform/LinkOpener';
import { FeederTheme } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { shareArticle } from './ArticleContentLoader';

const LOG_TAG: string = 'FEEDER_INAPP_BROWSER';

/** ARGB 整数 → '#AARRGGBB'（0 → 当前主题 surface） */
function argbToColor(argb: number): string {
  if (argb === 0) {
    return FeederTheme.colors.surface;
  }
  const v: number = argb >>> 0;
  let hex: string = v.toString(16).toUpperCase();
  while (hex.length < 8) {
    hex = '0' + hex;
  }
  return '#' + hex;
}

/** 对话框参数（ComponentContent 的 builder 参数） */
export class InAppBrowserArgs {
  link: string = '';
  toolbarColor: string = '';
  ui: UIContext | null = null;
  controller: webview.WebviewController = new webview.WebviewController();
  content: ComponentContent<InAppBrowserArgs> | null = null;

  close(): void {
    const ui: UIContext | null = this.ui;
    const c: ComponentContent<InAppBrowserArgs> | null = this.content;
    if (ui === null || c === null) {
      return;
    }
    try {
      ui.getPromptAction().closeCustomDialog(c).catch((e: Error) => {
        console.warn(`${LOG_TAG}: close failed: ${e?.message}`);
      });
    } catch (e) {
      console.warn(`${LOG_TAG}: close failed: ${(e as Error)?.message}`);
    }
    this.content = null;
  }
}

@ComponentV2
struct InAppBrowserView {
  @Param args: InAppBrowserArgs = new InAppBrowserArgs();
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  @Local pageTitle: string = '';
  @Local currentUrl: string = '';
  @Local progress: number = 0;

  aboutToAppear(): void {
    this.currentUrl = this.args.link;
  }

  @Builder
  toolButton(icon: Resource, label: Resource, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurface])
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .onClick(() => {
      action();
    })
  }

  build() {
    Column() {
      Row() {
        this.toolButton($r('sys.symbol.xmark'), $r('app.string.close_menu'), () => {
          this.args.close();
        })
        Column() {
          Text(this.pageTitle.length > 0 ? this.pageTitle : this.currentUrl)
            .attributeModifier(textStyle(M3Type.titleMedium, false, FeederTheme.colors.onSurface))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.pageTitle.length > 0) {
            Text(this.currentUrl)
              .attributeModifier(textStyle(M3Type.bodySmall, false, FeederTheme.colors.onSurfaceVariant))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 8, right: 8 })
        this.toolButton($r('sys.symbol.share'), $r('app.string.share'), () => {
          const ui: UIContext | null = this.args.ui;
          if (ui !== null) {
            shareArticle(ui, this.currentUrl, this.pageTitle).catch((e: Error) => {
              console.error(`${LOG_TAG}: share failed: ${e?.message}`);
            });
          }
        })
        this.toolButton($r('sys.symbol.compass'), $r('app.string.open_in_browser'), () => {
          const launcher: ActivityLauncher | null = ActivityLauncher.instance();
          if (launcher !== null) {
            launcher.openLinkInBrowser(this.currentUrl).catch((e: Error) => {
              console.error(`${LOG_TAG}: open in browser failed: ${e?.message}`);
            });
          }
        })
      }
      .width('100%')
      .height(56 + this.avoid.top)
      .padding({ top: this.avoid.top, left: 4, right: 4 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.args.toolbarColor)

      if (this.progress > 0 && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color(FeederTheme.colors.primary)
      }

      Web({ src: this.args.link, controller: this.args.controller })
        .width('100%')
        .layoutWeight(1)
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .onTitleReceive((event: OnTitleReceiveEvent) => {
          this.pageTitle = event.title;
        })
        .onPageBegin((event: OnPageBeginEvent) => {
          this.currentUrl = event.url;
        })
        .onProgressChange((event: OnProgressChangeEvent) => {
          this.progress = event.newProgress;
        })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.avoid.bottom })
    .backgroundColor(FeederTheme.colors.surface)
  }
}

@Builder
function inAppBrowserBuilder(args: InAppBrowserArgs) {
  InAppBrowserView({ args: args })
}

async function resolveUIContext(): Promise<UIContext | null> {
  const ctx: common.UIAbilityContext | null = AppBootstrap.context();
  if (ctx === null) {
    return null;
  }
  try {
    const w: window.Window = await window.getLastWindow(ctx);
    return w.getUIContext();
  } catch (e) {
    return null;
  }
}

async function openInAppBrowserAsync(link: string, toolbarColor: number): Promise<void> {
  const ui: UIContext | null = await resolveUIContext();
  if (ui === null) {
    throw new Error('No UIContext');
  }
  const args: InAppBrowserArgs = new InAppBrowserArgs();
  args.link = link;
  args.toolbarColor = argbToColor(toolbarColor);
  args.ui = ui;
  const content: ComponentContent<InAppBrowserArgs> =
    new ComponentContent<InAppBrowserArgs>(ui, wrapBuilder(inAppBrowserBuilder), args);
  args.content = content;
  const options: promptAction.BaseDialogOptions = {
    isModal: true,
    autoCancel: false,
    alignment: DialogAlignment.Top,
    maskColor: Color.Transparent,
    onWillDismiss: (action: DismissDialogAction) => {
      // 系统返回：网页可后退则后退，否则关闭
      try {
        if (args.controller.accessBackward()) {
          args.controller.backward();
          return;
        }
      } catch (e) {
        console.warn(`${LOG_TAG}: backward failed: ${(e as Error)?.message}`);
      }
      args.content = null;
      action.dismiss();
    }
  };
  await ui.getPromptAction().openCustomDialog(content, options);
}

/** 应用内浏览页打开链接（Custom Tab 等价）；失败回落系统浏览器 */
export function openInAppBrowser(link: string, toolbarColor: number): boolean {
  openInAppBrowserAsync(link, toolbarColor).catch((e: Error) => {
    console.warn(`${LOG_TAG}: in-app browser unavailable (${e?.message}), fallback to browser`);
    const launcher: ActivityLauncher | null = ActivityLauncher.instance();
    if (launcher !== null) {
      launcher.openLinkInBrowser(link).catch((e2: Error) => {
        console.error(`${LOG_TAG}: browser fallback failed: ${e2?.message}`);
      });
    }
  });
  return true;
}

let registered: boolean = false;

/** 向 LinkOpener 注册应用内浏览页钩子（幂等） */
export function registerInAppBrowser(): void {
  if (registered) {
    return;
  }
  registered = true;
  setInAppBrowserHook((link: string, toolbarColor: number): boolean => openInAppBrowser(link, toolbarColor));
}

registerInAppBrowser();
