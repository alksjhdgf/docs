/**
 * MainPage —— 源 com.nononsenseapps.feeder.ui.MainActivity（启动壳）。
 *
 * 冷启链：Index（冻结）→ Main →（本页）`await AppBootstrap.ready()` → MainViewModel.launch（≙ onCreate/onStart/onResume）
 * → DeepLinkRouter.launchFromMain()：立即 replacePath 为 Feed（无深链 = 上次 feed/tag；Feed 深链带参替换；
 * Article/Sync 等目标在 Feed 之上打开，返回落 Feed），此后热启 Want 由 EntryAbility.onNewWant → DeepLinkRouter 直接导航。
 * 本页仅在 ready() 期间可见：源 NavHost 起始即 Feed、无自有内容 → 只铺主题背景 + 状态栏/导航条避让（≙ enableEdgeToEdge）。
 */
import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../core/app/AppBootstrap';
import { AvoidArea, AvoidAreaStore } from '../core/app/AvoidArea';
import { DeepLinkRouter } from '../core/app/DeepLinkRouter';
import { FeederTheme } from '../ui/common/Theme';
import { MainViewModel } from '../features/main/MainViewModel';

const LOG_TAG: string = 'FEEDER_MAIN';

@Builder
export function MainPageBuilder() {
  MainPage()
}

@ComponentV2
struct MainPage {
  @Local avoid: AvoidArea = AvoidAreaStore.get();
  private launched: boolean = false;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.start().catch((e: Error) => {
      console.error(`${LOG_TAG}: launch failed: ${e?.message}`);
    });
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  private async start(): Promise<void> {
    if (this.launched) {
      return;
    }
    this.launched = true;
    await AppBootstrap.ready();
    if (!this.alive) {
      return;
    }
    let ctx: common.UIAbilityContext | null = AppBootstrap.context();
    if (ctx === null) {
      try {
        ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      } catch (e) {
        console.warn(`${LOG_TAG}: getHostContext failed: ${JSON.stringify(e)}`);
      }
    }
    try {
      MainViewModel.instance().launch(ctx);
    } catch (e) {
      console.error(`${LOG_TAG}: MainViewModel.launch failed: ${JSON.stringify(e)}`);
    }
    // 禁停留壳页：替换为 Feed 并消费冷启 Want
    await DeepLinkRouter.launchFromMain();
  }

  build() {
    NavDestination() {
      Column() {
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: this.avoid.top, bottom: this.avoid.bottom })
      .backgroundColor(FeederTheme.colors.background)
    }
    .hideTitleBar(true)
    .backgroundColor(FeederTheme.colors.background)
  }
}
