/*
 * TranslationStrings — 后端错误消息的字符串解析（源 application.getString(R.string.x, args)）。
 * 有 Ability 上下文时按资源名取本地化文案；否则（主机单测/早期调用）回落源英文原文并按 %n$s/%n$d 格式化。
 */
import { AppBootstrap } from '../../core/app/AppBootstrap';

export class TranslationStrings {
  static readonly NO_BERGAMOT_MODEL: string = 'no_bergamot_translation_model';
  static readonly BERGAMOT_TIMED_OUT: string = 'bergamot_translation_timed_out';
  static readonly BERGAMOT_FAILED: string = 'bergamot_translation_failed';
  static readonly REGISTRY_UNAVAILABLE: string = 'bergamot_model_registry_unavailable';
  static readonly MODEL_DOWNLOAD_FAILED: string = 'bergamot_model_download_failed';
  static readonly RUNTIME_DOWNLOAD_REQUIRED: string = 'bergamot_runtime_download_required';
  static readonly RUNTIME_DOWNLOAD_FAILED: string = 'bergamot_runtime_download_failed';
  static readonly WEBVIEW_TIMED_OUT: string = 'bergamot_webview_translation_timed_out';
  static readonly WEBVIEW_NOT_INITIALIZED: string = 'bergamot_webview_not_initialized';
  static readonly RESPONSE_PARSE_FAILED: string = 'bergamot_response_parse_failed';
  static readonly SET_LANGUAGE_FIRST: string = 'set_translation_language_first';
  static readonly LOCAL_UNAVAILABLE: string = 'local_translation_unavailable';

  private static readonly FALLBACKS: Map<string, string> = new Map<string, string>([
    ['no_bergamot_translation_model', 'No Bergamot model for %1$s -> %2$s. Check system translation languages'],
    ['bergamot_translation_timed_out', 'Bergamot translation timed out.'],
    ['bergamot_translation_failed', 'Bergamot translation failed.'],
    ['bergamot_model_registry_unavailable', 'Connect to download model list.'],
    ['bergamot_model_download_failed', 'Could not download %1$s -> %2$s model.'],
    ['bergamot_runtime_download_required', 'Download the offline translation engine to continue.'],
    ['bergamot_runtime_download_failed', 'Could not download the offline translation engine.'],
    ['bergamot_webview_translation_timed_out', 'Bergamot WebView translation timed out.'],
    ['bergamot_webview_not_initialized', 'Bergamot WebView is not initialized.'],
    ['bergamot_response_parse_failed', 'Could not parse Bergamot response.'],
    ['set_translation_language_first', 'Set a preferred translation language in AI settings'],
    ['local_translation_unavailable', 'Local translation is not available on this device.']
  ]);

  /** 测试可置 true 强制使用源英文原文 */
  static forceFallback: boolean = false;

  static get(name: string, args: string[] = []): string {
    if (!TranslationStrings.forceFallback) {
      const ctx = AppBootstrap.context();
      if (ctx !== null) {
        try {
          if (args.length === 0) {
            return ctx.resourceManager.getStringByNameSync(name);
          }
          return ctx.resourceManager.getStringByNameSync(name, ...args);
        } catch (e) {
          console.warn(`TranslationStrings: missing ${name}: ${(e as Error)?.message}`);
        }
      }
    }
    const fallback = TranslationStrings.FALLBACKS.get(name);
    return TranslationStrings.format(fallback !== undefined ? fallback : name, args);
  }

  /** Android String.format 的 %n$s / %s 子集 */
  static format(template: string, args: string[]): string {
    let out = template;
    for (let i = 0; i < args.length; i++) {
      out = out.split(`%${i + 1}$s`).join(args[i]).split(`%${i + 1}$d`).join(args[i]);
    }
    let next = 0;
    while (out.includes('%s') && next < args.length) {
      out = out.replace('%s', args[next]);
      next++;
    }
    return out;
  }
}
