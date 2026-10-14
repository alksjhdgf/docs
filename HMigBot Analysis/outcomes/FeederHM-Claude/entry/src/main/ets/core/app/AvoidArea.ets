/**
 * AvoidArea.ets —— 沉浸式分层契约（conventions §E）：源 enableEdgeToEdge + WindowInsets.systemBars 的鸿蒙等价物。
 *
 * EntryAbility.onWindowStageCreate 开启 `setWindowLayoutFullScreen(true)`，把状态栏（TYPE_SYSTEM）顶部避让与
 * 导航条（TYPE_NAVIGATION_INDICATOR）底部避让换算为 vp 写入 AppStorageV2 键 `AvoidArea`，并订阅 avoidAreaChange。
 * 页面只读：`@Local avoid: AvoidArea = AvoidAreaStore.get()`，顶部 `.padding({ top: this.avoid.top })`，底部同理；
 * 页面禁自行 expandSafeArea。
 */
import { AppStorageV2, window } from '@kit.ArkUI';

export const AVOID_AREA_KEY: string = 'AvoidArea';

@ObservedV2
export class AvoidArea {
  /** 状态栏（含刘海/挖孔）避让高度，vp */
  @Trace top: number = 0;
  /** 底部导航条/手势条避让高度，vp */
  @Trace bottom: number = 0;
}

export class AvoidAreaStore {
  private static win: window.Window | null = null;
  private static density: number = 1;
  private static cb: ((opts: window.AvoidAreaOptions) => void) | null = null;

  /** 页面读取的全局单例（AppStorageV2 键 `AvoidArea`） */
  static get(): AvoidArea {
    return AppStorageV2.connect(AvoidArea, AVOID_AREA_KEY, () => new AvoidArea()) as AvoidArea;
  }

  /** px → vp（density 为 display.densityPixels） */
  static toVp(px: number, density: number): number {
    const d: number = density > 0 ? density : 1;
    return px / d;
  }

  /** onWindowStageCreate：读当前避让区并订阅变化；幂等（重复 attach 先解绑旧窗口） */
  static attach(win: window.Window, densityPixels: number): void {
    AvoidAreaStore.detach();
    AvoidAreaStore.win = win;
    AvoidAreaStore.density = densityPixels > 0 ? densityPixels : 1;
    const store: AvoidArea = AvoidAreaStore.get();
    try {
      const sys: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      store.top = AvoidAreaStore.toVp(sys.topRect.height, AvoidAreaStore.density);
      const nav: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      store.bottom = AvoidAreaStore.toVp(nav.bottomRect.height, AvoidAreaStore.density);
    } catch (e) {
      console.error(`AvoidAreaStore: getWindowAvoidArea failed: ${JSON.stringify(e)}`);
    }
    const cb = (opts: window.AvoidAreaOptions): void => {
      const s: AvoidArea = AvoidAreaStore.get();
      if (opts.type === window.AvoidAreaType.TYPE_SYSTEM) {
        s.top = AvoidAreaStore.toVp(opts.area.topRect.height, AvoidAreaStore.density);
      } else if (opts.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        s.bottom = AvoidAreaStore.toVp(opts.area.bottomRect.height, AvoidAreaStore.density);
      }
    };
    try {
      win.on('avoidAreaChange', cb);
      AvoidAreaStore.cb = cb;
    } catch (e) {
      console.error(`AvoidAreaStore: subscribe avoidAreaChange failed: ${JSON.stringify(e)}`);
    }
  }

  /** onWindowStageDestroy：对称解绑 */
  static detach(): void {
    const w: window.Window | null = AvoidAreaStore.win;
    const cb: ((opts: window.AvoidAreaOptions) => void) | null = AvoidAreaStore.cb;
    if (w !== null && cb !== null) {
      try {
        w.off('avoidAreaChange', cb);
      } catch (e) {
        console.error(`AvoidAreaStore: off avoidAreaChange failed: ${JSON.stringify(e)}`);
      }
    }
    AvoidAreaStore.win = null;
    AvoidAreaStore.cb = null;
  }
}
