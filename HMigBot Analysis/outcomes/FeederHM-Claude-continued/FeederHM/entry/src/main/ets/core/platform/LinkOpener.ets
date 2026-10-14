/**
 * LinkOpener.ets —— 源 util/ActivityLauncher.kt 的鸿蒙等价物（主类保留源名 ActivityLauncher，
 * 避免与 core/model/Enums 的 `LinkOpener` 设置枚举撞名）。
 *
 * - openLink：空白/`#` 开头 → false（UT-A23）；`mailto:` → 邮件应用（UT-A24）；其余按设置 linkOpener（UT-A25）。
 * - CUSTOM_TAB：鸿蒙无 Custom Tabs → 若已注册应用内浏览页钩子（setInAppBrowserHook）则走应用内 Web 页
 *   （带工具栏颜色与分享），否则降级为系统浏览器。
 * - DEFAULT_BROWSER：Want(viewData + entity.system.browsable)。`Browser.EXTRA_CREATE_NEW_TAB` 无等价，忽略（台账未登记，见降级候选 deg-acc-new-tab）。
 * - 无应用可处理 → Toast `no_activity_for_link` 并返回 false；链接非法 → 静默 false；任何异常不崩（UT-A26）。
 * - 相邻打开（UT-A27）：允许 && 最小宽度 ≥600vp && pref_open_adjacent → StartOptions.windowMode = 分屏次窗口。
 * - 平台启动是异步的，故返回 Promise<boolean>（源为同步 Boolean）。
 */
import { AbilityConstant, common, StartOptions, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, UIContext, window } from '@kit.ArkUI';
import { url } from '@kit.ArkTS';
import { LinkOpener } from '../model/Enums';
import { SettingsStore } from '../settings/SettingsStore';

const LOG_TAG: string = 'FEEDER_ALAUNCH';

/** 隐式启动无匹配组件 */
export const ERR_NO_MATCHING_ABILITY: number = 16000019;

export const ACTION_VIEW_DATA: string = 'ohos.want.action.viewData';
export const ACTION_SEND_TO_DATA: string = 'ohos.want.action.sendToData';
export const ENTITY_BROWSABLE: string = 'entity.system.browsable';

/** 应用内浏览页（Custom Tab 等价物）钩子：返回 true 表示已打开。由拥有 Web 页的单元注册。 */
export type InAppBrowserHook = (link: string, toolbarColor: number) => boolean;

let inAppBrowserHook: InAppBrowserHook | null = null;

export function setInAppBrowserHook(cb: InAppBrowserHook | null): void {
  inAppBrowserHook = cb;
}

/** openLink 的路由判定（纯逻辑，便于单测） */
export enum LinkRoute {
  IGNORED = 'IGNORED',
  EMAIL = 'EMAIL',
  CUSTOM_TAB = 'CUSTOM_TAB',
  DEFAULT_BROWSER = 'DEFAULT_BROWSER',
}

/** Kotlin String.isBlank：只含空白字符 */
export function isBlankString(s: string): boolean {
  return s.trim().length === 0;
}

export function routeForLink(link: string, opener: LinkOpener): LinkRoute {
  if (isBlankString(link) || link.startsWith('#')) {
    return LinkRoute.IGNORED;
  }
  if (link.startsWith('mailto:')) {
    return LinkRoute.EMAIL;
  }
  return opener === LinkOpener.DEFAULT_BROWSER ? LinkRoute.DEFAULT_BROWSER : LinkRoute.CUSTOM_TAB;
}

/** 源 openAdjacentIfSuitable 条件 */
export function shouldOpenAdjacent(openAdjacentIfSuitable: boolean, smallestScreenWidthVp: number,
  isOpenAdjacent: boolean): boolean {
  return openAdjacentIfSuitable && smallestScreenWidthVp >= 600 && isOpenAdjacent;
}

/** Configuration.smallestScreenWidthDp 等价：默认屏 min(宽,高)/密度。取不到 → 0。 */
export function smallestScreenWidthVp(): number {
  try {
    const d: display.Display = display.getDefaultDisplaySync();
    const density = d.densityPixels > 0 ? d.densityPixels : 1;
    return Math.min(d.width, d.height) / density;
  } catch (e) {
    return 0;
  }
}

export function browserWant(link: string): Want {
  const w: Want = {
    action: ACTION_VIEW_DATA,
    entities: [ENTITY_BROWSABLE],
    uri: link,
  };
  return w;
}

export function emailWant(link: string): Want {
  const w: Want = {
    action: ACTION_SEND_TO_DATA,
    uri: link,
  };
  return w;
}

/** 链接格式校验（WHATWG）；非法 → false */
export function isParsableLink(link: string): boolean {
  try {
    url.URL.parseURL(link);
    return true;
  } catch (e) {
    return false;
  }
}

export class ActivityLauncher {
  private static current: ActivityLauncher | null = null;

  private readonly ctx: common.UIAbilityContext;
  private uiContext: UIContext | null;

  constructor(ctx: common.UIAbilityContext, uiContext?: UIContext) {
    this.ctx = ctx;
    this.uiContext = uiContext !== undefined ? uiContext : null;
  }

  /** 每个 Ability 一个实例（源由 DIAwareComponentActivity 绑定）；EntryAbility 在 onWindowStageCreate 后调用。 */
  static bind(ctx: common.UIAbilityContext, uiContext?: UIContext): ActivityLauncher {
    const l = new ActivityLauncher(ctx, uiContext);
    ActivityLauncher.current = l;
    return l;
  }

  static instance(): ActivityLauncher | null {
    return ActivityLauncher.current;
  }

  setUIContext(uiContext: UIContext): void {
    this.uiContext = uiContext;
  }

  /**
   * 源 startActivity：成功 true；无应用可处理 → 日志 + Toast + false；其他失败 → 日志 + false（不崩）。
   */
  async startAbility(openAdjacentIfSuitable: boolean, want: Want): Promise<boolean> {
    try {
      if (shouldOpenAdjacent(openAdjacentIfSuitable, smallestScreenWidthVp(), SettingsStore.instance().openAdjacent)) {
        const opts: StartOptions = {
          windowMode: AbilityConstant.WindowMode.WINDOW_MODE_SPLIT_SECONDARY,
        };
        try {
          await this.ctx.startAbility(want, opts);
          return true;
        } catch (e) {
          const code = (e as BusinessError).code;
          if (code === ERR_NO_MATCHING_ABILITY) {
            throw e as Object as Error;
          }
          // 设备不支持分屏启动 → 降级为普通启动
          console.warn(`${LOG_TAG}: adjacent launch failed (${code}), fallback to normal launch`);
        }
      }
      await this.ctx.startAbility(want);
      return true;
    } catch (e) {
      const code = (e as BusinessError).code;
      console.error(`${LOG_TAG}: Failed to launch: ${code} ${(e as BusinessError).message}`);
      if (code === ERR_NO_MATCHING_ABILITY) {
        await this.showNoActivityToast();
      }
      return false;
    }
  }

  /** 源 openLink（UT-A23/A24/A25） */
  async openLink(link: string, toolbarColor: number, openAdjacentIfSuitable: boolean = true): Promise<boolean> {
    const route = routeForLink(link, SettingsStore.instance().linkOpener);
    switch (route) {
      case LinkRoute.IGNORED:
        return false;
      case LinkRoute.EMAIL:
        // 源 openEmailClient 固定 openAdjacentIfSuitable = true，忽略打开方式设置
        return this.startAbility(true, emailWant(link));
      case LinkRoute.DEFAULT_BROWSER:
        return this.openLinkInBrowser(link, openAdjacentIfSuitable);
      default:
        return this.openLinkInCustomTab(link, toolbarColor, openAdjacentIfSuitable);
    }
  }

  /** 源 openLinkInBrowser：外部浏览器 */
  async openLinkInBrowser(link: string, openAdjacentIfSuitable: boolean = true): Promise<boolean> {
    if (!isParsableLink(link)) {
      console.warn(`${LOG_TAG}: Maybe bad link? ${link}`);
      return false;
    }
    return this.startAbility(openAdjacentIfSuitable, browserWant(link));
  }

  /**
   * 源 openLinkInCustomTab：应用内浏览页（工具栏颜色 + 分享菜单）。
   * 未注册应用内浏览页时降级为系统浏览器。坏链接 → 静默 false。
   */
  async openLinkInCustomTab(link: string, toolbarColor: number, openAdjacentIfSuitable: boolean = true): Promise<boolean> {
    try {
      if (!isParsableLink(link)) {
        console.warn(`${LOG_TAG}: Maybe bad link? ${link}`);
        return false;
      }
      const hook = inAppBrowserHook;
      if (hook !== null) {
        return hook(link, toolbarColor);
      }
      return await this.startAbility(openAdjacentIfSuitable, browserWant(link));
    } catch (e) {
      console.error(`${LOG_TAG}: Failed to custom tab: ${JSON.stringify(e)}`);
      return false;
    }
  }

  private async showNoActivityToast(): Promise<void> {
    try {
      let ui: UIContext | null = this.uiContext;
      if (ui === null) {
        const w: window.Window = await window.getLastWindow(this.ctx);
        ui = w.getUIContext();
      }
      ui.getPromptAction().showToast({
        message: $r('app.string.no_activity_for_link'),
        duration: 2000,
      });
    } catch (e) {
      console.warn(`${LOG_TAG}: toast failed: ${JSON.stringify(e)}`);
    }
  }
}

/** 便捷入口：用已绑定的 ActivityLauncher 打开链接；未绑定 → false（不崩）。 */
export async function openLink(link: string, toolbarColor: number, openAdjacentIfSuitable: boolean = true): Promise<boolean> {
  const l = ActivityLauncher.instance();
  if (l === null) {
    console.warn(`${LOG_TAG}: ActivityLauncher not bound`);
    return false;
  }
  return l.openLink(link, toolbarColor, openAdjacentIfSuitable);
}
