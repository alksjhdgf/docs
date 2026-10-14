/*
 * LocalTranslator — 本地离线翻译（系统设备端翻译 → Bergamot 回退），HTML 文本节点切分与回填。
 * 源：localtranslation/LocalTranslator.kt。
 *   - 源语言未提供时自动检测（≥60%，多样本取众数，失败 'und'）；源==目标原样返回（TR-A14）。
 *   - 先试系统设备端翻译，失败回退 Bergamot（TR-A15）。鸿蒙无系统设备端文本翻译 API
 *     （android.view.translation.TranslationManager 无对应），系统路径恒返回"不可用"错误，等价于 Android 上无设备端模型时的行为。
 *   - HTML：仅替换字母 ≥20 的文本节点并保留首尾空白，其余节点与标签原样（TR-A16，依赖 core/html DOM）。
 *   - 错误映射：清单缺失/无模型(附打开系统设置)/运行时未下载(附下载运行时，不自动下载)/下载失败/5 分钟超时（TR-A17~A19）。
 *   - canTranslateWithoutBergamotDownload 全程不联网（TR-A20）。
 */
import { parseBodyFragment, HtmlNode } from '../../core/html/HtmlParser';
import {
  hasEnoughTextForLanguageDetection, isWhitespaceChar, normalizeLanguageCode, prepareTextForLanguageDetection,
  prepareTextSamplesForLanguageDetection
} from './LanguageUtils';
import { detectLocaleFromText, DetectedLocale } from './LanguageDetector';
import { TranslationErrorAction, TranslationResult } from './DeepLApi';
import { BergamotModelManager } from './BergamotModels';
import {
  BergamotLanguagePairStatus, BergamotModelPreparation, BergamotModelRegistryEntry, BergamotPreparationError
} from './BergamotRegistry';
import { BergamotWebTranslationResult, BergamotWebTranslator } from './BergamotWebTranslator';
import { TranslationStrings } from './TranslationStrings';

const TRANSLATION_TIMEOUT_MS: number = 5 * 60000;
const MAX_LOCAL_TRANSLATION_ERROR_LENGTH: number = 80;
const SOURCE_DETECTION_MIN_CONFIDENCE: number = 60;

/** 源 private sealed LocalTranslationResult */
class LocalTranslationResult {
  readonly isSuccess: boolean;
  readonly values: string[];
  readonly message: string;
  readonly action: TranslationErrorAction;

  private constructor(isSuccess: boolean, values: string[], message: string, action: TranslationErrorAction) {
    this.isSuccess = isSuccess;
    this.values = values;
    this.message = message;
    this.action = action;
  }

  static success(values: string[]): LocalTranslationResult {
    return new LocalTranslationResult(true, values, '', TranslationErrorAction.None);
  }

  static error(message: string, action: TranslationErrorAction = TranslationErrorAction.None): LocalTranslationResult {
    return new LocalTranslationResult(false, [], message, action);
  }
}

/** 源 HtmlTextNodeTranslation */
export class HtmlTextNodeTranslation {
  readonly textNode: HtmlNode;
  readonly leadingWhitespace: string;
  readonly text: string;
  readonly trailingWhitespace: string;

  constructor(textNode: HtmlNode, leadingWhitespace: string, text: string, trailingWhitespace: string) {
    this.textNode = textNode;
    this.leadingWhitespace = leadingWhitespace;
    this.text = text;
    this.trailingWhitespace = trailingWhitespace;
  }

  static from(textNode: HtmlNode): HtmlTextNodeTranslation {
    const whole = textNode.data;
    let lead = 0;
    while (lead < whole.length && isWhitespaceChar(whole.charAt(lead))) {
      lead++;
    }
    let trail = whole.length;
    while (trail > 0 && isWhitespaceChar(whole.charAt(trail - 1))) {
      trail--;
    }
    const leading = whole.substring(0, lead);
    // takeLastWhile(isWhitespace)：全空白时与 leading 相同（dropLast 后 text 为空）
    const trailing = whole.substring(trail);
    const textEnd = Math.max(lead, whole.length - trailing.length);
    return new HtmlTextNodeTranslation(textNode, leading, whole.substring(lead, textEnd), trailing);
  }
}

/** collectTextNodes（深度优先，文档序） */
function collectTextNodes(node: HtmlNode): HtmlNode[] {
  const out: HtmlNode[] = [];
  node.traverse((n: HtmlNode, _d: number) => {
    if (n.isText()) {
      out.push(n);
    }
  });
  return out;
}

/** TR-A16：可翻译文本节点（字母 ≥ 20） */
export function htmlTranslationTargets(body: HtmlNode): HtmlTextNodeTranslation[] {
  return collectTextNodes(body)
    .map((n: HtmlNode) => HtmlTextNodeTranslation.from(n))
    .filter((t: HtmlTextNodeTranslation) => hasEnoughTextForLanguageDetection(t.text));
}

/** 回填译文（保留首尾空白），返回 body 内部 HTML */
export function applyHtmlTranslations(body: HtmlNode, targets: HtmlTextNodeTranslation[], values: string[]): string {
  const n = Math.min(targets.length, values.length);
  for (let i = 0; i < n; i++) {
    const t = targets[i];
    t.textNode.data = t.leadingWhitespace + values[i] + t.trailingWhitespace;
  }
  return body.html();
}

function withTimeoutOrNull<T>(p: Promise<T>, ms: number): Promise<T | null> {
  return new Promise<T | null>((resolve, reject) => {
    const timer = setTimeout(() => {
      resolve(null);
    }, ms);
    p.then((v: T) => {
      clearTimeout(timer);
      resolve(v);
    }, (e: Error) => {
      clearTimeout(timer);
      reject(e);
    });
  });
}

/** 系统设备端翻译钩子（鸿蒙暂无对应 API；若未来平台提供可注册实现） */
export type SystemTranslateHook = (content: string[], sourceLang: string, targetLang: string) => Promise<string[] | null>;
export type SystemModelCheckHook = (sourceLang: string, targetLang: string) => boolean;

let systemTranslateHook: SystemTranslateHook | null = null;
let systemModelCheckHook: SystemModelCheckHook | null = null;

export function setSystemTranslationHooks(translate: SystemTranslateHook | null, hasModel: SystemModelCheckHook | null): void {
  systemTranslateHook = translate;
  systemModelCheckHook = hasModel;
}

export class LocalTranslator {
  private static inst: LocalTranslator | null = null;

  private readonly modelManager: BergamotModelManager;
  private readonly webTranslator: BergamotWebTranslator;

  constructor(modelManager: BergamotModelManager | null = null, webTranslator: BergamotWebTranslator | null = null) {
    this.modelManager = modelManager !== null ? modelManager : BergamotModelManager.instance();
    this.webTranslator = webTranslator !== null ? webTranslator : BergamotWebTranslator.instance();
  }

  static instance(): LocalTranslator {
    if (LocalTranslator.inst === null) {
      LocalTranslator.inst = new LocalTranslator();
    }
    return LocalTranslator.inst as LocalTranslator;
  }

  async translate(content: string, targetLanguage: string, sourceLangHint: string = '',
    preserveHtml: boolean = false): Promise<TranslationResult> {
    const text = prepareTextForLanguageDetection(content, preserveHtml);
    if (text.trim().length === 0) {
      return TranslationResult.success(content, '');
    }
    const targetLang = normalizeLanguageCode(targetLanguage);
    const sourceLang = sourceLangHint.trim().length > 0 ? sourceLangHint :
      LocalTranslator.detectSourceLanguage(content, preserveHtml);
    if (sourceLang === targetLang) {
      return TranslationResult.success(content, sourceLang);
    }
    const systemResult = preserveHtml ?
      await this.translateHtml(content, sourceLang, targetLang, false) :
      await this.translatePlain(content, sourceLang, targetLang, false);
    if (systemResult.isSuccess) {
      return systemResult;
    }
    return preserveHtml ?
      this.translateHtml(content, sourceLang, targetLang, true) :
      this.translatePlain(content, sourceLang, targetLang, true);
  }

  /** TR-A20：仅本地判定，不联网 */
  async canTranslateWithoutBergamotDownload(content: string, targetLanguage: string, sourceLangHint: string = '',
    preserveHtml: boolean = false): Promise<boolean> {
    const text = prepareTextForLanguageDetection(content, preserveHtml);
    if (text.trim().length === 0) {
      return true;
    }
    const targetLang = normalizeLanguageCode(targetLanguage);
    const sourceLang = sourceLangHint.trim().length > 0 ? sourceLangHint :
      LocalTranslator.detectSourceLanguage(content, preserveHtml);
    if (sourceLang === targetLang) {
      return true;
    }
    const hasModel = systemModelCheckHook;
    if (hasModel !== null && hasModel(sourceLang, targetLang)) {
      return true;
    }
    const status = await this.modelManager.languagePairStatus(sourceLang, targetLang, false);
    return status === BergamotLanguagePairStatus.Downloaded && await this.modelManager.isRuntimeDownloaded();
  }

  private async translateHtml(html: string, sourceLang: string, targetLang: string,
    useBergamot: boolean): Promise<TranslationResult> {
    const document = parseBodyFragment(html);
    const body = document.body();
    if (body === null) {
      return TranslationResult.success(html, sourceLang);
    }
    const targets = htmlTranslationTargets(body);
    if (targets.length === 0) {
      return TranslationResult.success(html, sourceLang);
    }
    const texts = targets.map((t: HtmlTextNodeTranslation) => t.text);
    const translated = useBergamot ?
      await this.translateTextValuesWithBergamot(texts, sourceLang, targetLang, false) :
      await this.translateTextValuesWithSystem(texts, sourceLang, targetLang);
    if (!translated.isSuccess) {
      return TranslationResult.error(translated.message, translated.action);
    }
    return TranslationResult.success(applyHtmlTranslations(body, targets, translated.values), sourceLang);
  }

  private async translatePlain(content: string, sourceLang: string, targetLang: string,
    useBergamot: boolean): Promise<TranslationResult> {
    const result = useBergamot ?
      await this.translateTextValuesWithBergamot([content], sourceLang, targetLang, false) :
      await this.translateTextValuesWithSystem([content], sourceLang, targetLang);
    if (!result.isSuccess) {
      return TranslationResult.error(result.message, result.action);
    }
    return TranslationResult.success(result.values.length > 0 ? result.values[0] : '', sourceLang);
  }

  /** 源 translateTextValues（系统设备端翻译）：鸿蒙无对应能力 → 不可用错误（除非注册了平台钩子） */
  private async translateTextValuesWithSystem(content: string[], sourceLang: string,
    targetLang: string): Promise<LocalTranslationResult> {
    const hook = systemTranslateHook;
    if (hook === null) {
      return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.LOCAL_UNAVAILABLE));
    }
    try {
      const values = await hook(content, sourceLang, targetLang);
      if (values === null || values.length !== content.length || values.some((v: string) => v.trim().length === 0)) {
        return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.LOCAL_UNAVAILABLE));
      }
      return LocalTranslationResult.success(values);
    } catch (e) {
      return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.LOCAL_UNAVAILABLE));
    }
  }

  private async translateTextValuesWithBergamot(content: string[], sourceLang: string, targetLang: string,
    preserveHtml: boolean): Promise<LocalTranslationResult> {
    const status = await this.modelManager.languagePairStatus(sourceLang, targetLang);
    if (status === BergamotLanguagePairStatus.RegistryMissing) {
      return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.REGISTRY_UNAVAILABLE));
    }
    if (status === BergamotLanguagePairStatus.Unavailable) {
      return LocalTranslationResult.error(
        TranslationStrings.get(TranslationStrings.NO_BERGAMOT_MODEL, [sourceLang, targetLang]),
        TranslationErrorAction.OpenSystemTranslationSettings);
    }
    if (!(await this.modelManager.isRuntimeDownloaded())) {
      return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.RUNTIME_DOWNLOAD_REQUIRED),
        TranslationErrorAction.DownloadBergamotRuntime);
    }
    const preparation: BergamotModelPreparation = await this.modelManager.prepare(sourceLang, targetLang);
    if (!preparation.isReady) {
      switch (preparation.reason) {
        case BergamotPreparationError.NoAppModel:
          return LocalTranslationResult.error(
            TranslationStrings.get(TranslationStrings.NO_BERGAMOT_MODEL, [sourceLang, targetLang]),
            TranslationErrorAction.OpenSystemTranslationSettings);
        case BergamotPreparationError.RegistryMissing:
          return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.REGISTRY_UNAVAILABLE));
        default:
          return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.MODEL_DOWNLOAD_FAILED,
            [preparation.sourceLanguage, preparation.targetLanguage]));
      }
    }
    const modelRegistry: BergamotModelRegistryEntry[] = preparation.modelRegistry;
    try {
      const work = this.runBergamot(content, sourceLang, targetLang, preserveHtml, modelRegistry);
      const result = await withTimeoutOrNull<BergamotWebTranslationResult>(work, TRANSLATION_TIMEOUT_MS);
      if (result === null) {
        return LocalTranslationResult.error(TranslationStrings.get(TranslationStrings.BERGAMOT_TIMED_OUT));
      }
      if (result.isSuccess) {
        return LocalTranslationResult.success(result.values);
      }
      return LocalTranslationResult.error(LocalTranslator.toLocalTranslationError(result.message));
    } catch (e) {
      const msg = (e as Error)?.message;
      return LocalTranslationResult.error(LocalTranslator.toLocalTranslationError(msg !== undefined ? msg : ''));
    }
  }

  private async runBergamot(content: string[], sourceLang: string, targetLang: string, preserveHtml: boolean,
    modelRegistry: BergamotModelRegistryEntry[]): Promise<BergamotWebTranslationResult> {
    const runtimeUrl = await this.modelManager.runtimeFileUrl();
    if (runtimeUrl === null) {
      return BergamotWebTranslationResult.error(TranslationStrings.get(TranslationStrings.RUNTIME_DOWNLOAD_REQUIRED));
    }
    return this.webTranslator.translate(content, sourceLang, targetLang, preserveHtml, modelRegistry, runtimeUrl);
  }

  /** TR-A14：≥60% 置信度，多样本取出现最多者（并列取先出现），失败 'und' */
  static detectSourceLanguage(content: string, preserveHtml: boolean): string {
    try {
      const samples = prepareTextSamplesForLanguageDetection(content, preserveHtml)
        .filter((s: string) => hasEnoughTextForLanguageDetection(s));
      const detected: string[] = [];
      for (let i = 0; i < samples.length; i++) {
        const found: DetectedLocale[] = detectLocaleFromText(samples[i], SOURCE_DETECTION_MIN_CONFIDENCE);
        if (found.length === 0) {
          continue;
        }
        const tag = found[0].languageTag;
        const dash = tag.indexOf('-');
        const lang = normalizeLanguageCode(dash < 0 ? tag : tag.substring(0, dash));
        if (lang !== 'und') {
          detected.push(lang);
        }
      }
      const counts = new Map<string, number>();
      for (let i = 0; i < detected.length; i++) {
        const c = counts.get(detected[i]);
        counts.set(detected[i], (c !== undefined ? c : 0) + 1);
      }
      let best = '';
      let bestCount = -1;
      for (let i = 0; i < detected.length; i++) {
        const c = counts.get(detected[i]) as number;
        if (c > bestCount) {
          best = detected[i];
          bestCount = c;
        }
      }
      return best.length > 0 ? best : 'und';
    } catch (e) {
      return 'und';
    }
  }

  /** 首个非空行，截 80 字符，空则 Bergamot 通用失败文案 */
  static toLocalTranslationError(message: string): string {
    const lines = message.split(new RegExp('\\r\\n|\\n|\\r'));
    let first = '';
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim().length > 0) {
        first = lines[i];
        break;
      }
    }
    const cut = first.substring(0, MAX_LOCAL_TRANSLATION_ERROR_LENGTH);
    return cut.trim().length > 0 ? cut : TranslationStrings.get(TranslationStrings.BERGAMOT_FAILED);
  }
}
