/*
 * TranslationUiSupport — 文章/列表/设置共用的翻译 UI 辅助：
 *   - 下载进度 → ui/common TranslationDownloadProgress（TR-A38/A42 进度卡数据）；
 *   - 运行时下载 / 打开系统设置对话框（TR-A36/A37，源 AlertDialog → promptAction.showDialog 简单确认）；
 *   - Toast（源 ToastMaker）；打开系统设置（源 Intent(Settings.ACTION_SETTINGS)）。
 */
import { common, Want } from '@kit.AbilityKit';
import { promptAction, UIContext, window } from '@kit.ArkUI';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { TranslationDownloadProgress } from '../../ui/common/CommonWidgets';
import { FeederTheme } from '../../ui/common/Theme';
import { BergamotModelDownloadProgress } from './BergamotRegistry';

const LOG_TAG: string = 'FEEDER_TRANSLATION_UI';
const SETTINGS_BUNDLE: string = 'com.huawei.hmos.settings';
const SETTINGS_ABILITY: string = 'com.huawei.hmos.settings.MainAbility';

export function toUiDownloadProgress(p: BergamotModelDownloadProgress | null): TranslationDownloadProgress | null {
  if (p === null) {
    return null;
  }
  const u = new TranslationDownloadProgress();
  u.sourceLanguage = p.sourceLanguage;
  u.targetLanguage = p.targetLanguage;
  u.fileName = p.fileName;
  u.downloadedBytes = p.downloadedBytes;
  u.totalBytes = p.totalBytes;
  u.isRuntimeDownload = p.isRuntimeDownload;
  return u;
}

export type TranslationToast = (message: string) => void;

async function resolveUIContext(): Promise<UIContext | null> {
  const ctx = AppBootstrap.context();
  if (ctx === null) {
    return null;
  }
  try {
    const w = await window.getLastWindow(ctx);
    return w.getUIContext();
  } catch (e) {
    return null;
  }
}

/** 源 ToastMaker.makeToast(text) */
export function showTranslationToast(message: string): void {
  resolveUIContext().then((ui: UIContext | null) => {
    if (ui !== null) {
      ui.getPromptAction().showToast({ message: message, duration: 2000 });
    } else {
      promptAction.showToast({ message: message, duration: 2000 });
    }
  }).catch((e: Error) => {
    console.warn(`${LOG_TAG}: toast failed: ${e?.message}`);
  });
}

/** 资源串（带参数）同步取值；无上下文回落 fallback */
export function translationString(name: string, fallback: string, args: string[] = []): string {
  const ctx = AppBootstrap.context();
  if (ctx !== null) {
    try {
      return args.length === 0 ? ctx.resourceManager.getStringByNameSync(name) :
        ctx.resourceManager.getStringByNameSync(name, ...args);
    } catch (e) {
      console.warn(`${LOG_TAG}: missing string ${name}`);
    }
  }
  let out = fallback;
  for (let i = 0; i < args.length; i++) {
    out = out.split(`%${i + 1}$s`).join(args[i]).split(`%${i + 1}$d`).join(args[i]);
  }
  return out;
}

/** 源 Intent(Settings.ACTION_SETTINGS) */
export async function openSystemSettings(): Promise<boolean> {
  const ctx: common.UIAbilityContext | null = AppBootstrap.context();
  if (ctx === null) {
    return false;
  }
  const want: Want = {
    bundleName: SETTINGS_BUNDLE,
    abilityName: SETTINGS_ABILITY
  };
  try {
    await ctx.startAbility(want);
    return true;
  } catch (e) {
    console.warn(`${LOG_TAG}: open settings failed: ${(e as Error)?.message}`);
    return false;
  }
}

/** TR-A36：`Download offline translation engine?` + 4.9 MB 警告；返回 true=Download */
export async function confirmRuntimeDownload(ui: UIContext | null = null): Promise<boolean> {
  const u = ui !== null ? ui : await resolveUIContext();
  if (u === null) {
    return false;
  }
  try {
    const r = await u.getPromptAction().showDialog({
      title: $r('app.string.bergamot_runtime_download_title'),
      message: $r('app.string.bergamot_runtime_download_warning'),
      buttons: [
        { text: $r('app.string.cancel'), color: FeederTheme.colors.primary },
        { text: $r('app.string.download'), color: FeederTheme.colors.primary }
      ]
    });
    return r.index === 1;
  } catch (e) {
    return false;
  }
}

/** TR-A37：显示错误消息，`Open settings`/`Cancel`；返回 true=Open settings */
export async function confirmOpenSystemSettings(message: string, ui: UIContext | null = null): Promise<boolean> {
  const u = ui !== null ? ui : await resolveUIContext();
  if (u === null) {
    return false;
  }
  try {
    const r = await u.getPromptAction().showDialog({
      message: message,
      buttons: [
        { text: $r('app.string.cancel'), color: FeederTheme.colors.primary },
        { text: $r('app.string.open_settings'), color: FeederTheme.colors.primary }
      ]
    });
    return r.index === 1;
  } catch (e) {
    return false;
  }
}
