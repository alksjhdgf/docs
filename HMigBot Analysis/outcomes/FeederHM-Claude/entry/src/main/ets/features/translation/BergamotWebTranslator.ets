/*
 * BergamotWebTranslator — 在隐藏 ArkWeb 容器中运行 Bergamot WASM 翻译引擎。
 * 源：localtranslation/BergamotWebTranslator.kt。
 *   - 隐藏 WebView → BuilderNode 离线创建的 Web 组件（1×1，不挂主树；亦可经 BergamotWebHost 挂入 NodeContainer）。
 *   - file:///android_asset/bergamot/index.html → 应用内置 rawfile `bergamot/*` 复制到 `<filesDir>/bergamot-web/` 后以 file:// 加载；
 *     allowFileAccess/allowFileAccessFromFileURLs → fileAccess(true) + setPathAllowingUniversalAccess([页面目录, 模型目录])。
 *   - addJavascriptInterface(bridge, "AndroidBergamot") → javaScriptProxy（页面加载前注册，onReady、onTranslation 系列、onLog）。
 *   - evaluateJavascript → WebviewController.runJavaScript。
 *   - 60 s 未就绪销毁容器并报错（TR-A30）；请求 id 匹配回调、5 min 超时（TR-A31）；
 *     模型清单/运行时路径变化时重新 initialize（TR-A32）。
 */
import { webview } from '@kit.ArkWeb';
import { BuilderNode, FrameNode, NodeController, UIContext, window } from '@kit.ArkUI';
import { AppBootstrap } from '../../core/app/AppBootstrap';
import { isFile, joinPath, mkdirs, parentDir, writeBytes } from './TranslationIo';
import { AsyncMutex, BergamotModelRegistryEntry, registryToJson } from './BergamotRegistry';
import { TranslationStrings } from './TranslationStrings';

const LOG_TAG: string = 'FEEDER_BERGAMOT';
const BRIDGE_NAME: string = 'AndroidBergamot';
const WEBVIEW_INIT_TIMEOUT_MS: number = 60000;
const WEBVIEW_TRANSLATION_TIMEOUT_MS: number = 5 * 60000;
const WEB_ASSET_DIR_NAME: string = 'bergamot-web';
const RAWFILE_ASSET_ROOT: string = 'bergamot';
const BERGAMOT_ASSETS: string[] = [
  'index.html',
  'feeder-bergamot.js',
  'translator.js',
  'worker/bergamot-translator-worker.js',
  'worker/translator-worker.js'
];

/** 源 sealed BergamotWebTranslationResult */
export class BergamotWebTranslationResult {
  readonly isSuccess: boolean;
  readonly values: string[];
  readonly message: string;

  private constructor(isSuccess: boolean, values: string[], message: string) {
    this.isSuccess = isSuccess;
    this.values = values;
    this.message = message;
  }

  static success(values: string[]): BergamotWebTranslationResult {
    return new BergamotWebTranslationResult(true, values, '');
  }

  static error(message: string): BergamotWebTranslationResult {
    return new BergamotWebTranslationResult(false, [], message);
  }
}

class Deferred<T> {
  readonly promise: Promise<T>;
  private resolver: ((v: T) => void) | null = null;
  private done: boolean = false;

  constructor() {
    this.promise = new Promise<T>((resolve) => {
      this.resolver = resolve;
    });
  }

  complete(v: T): void {
    if (this.done) {
      return;
    }
    this.done = true;
    const r = this.resolver;
    if (r !== null) {
      r(v);
    }
  }
}

class TimeoutError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TimeoutCancellationException';
  }
}

/** withTimeoutOrNull：超时返回 null */
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

/** JS → ArkTS 桥（源 inner class Bridge，@JavascriptInterface 方法） */
export class BergamotBridge {
  readonly pending: Map<number, Deferred<BergamotWebTranslationResult>> = new Map<number, Deferred<BergamotWebTranslationResult>>();
  ready: Deferred<boolean> = new Deferred<boolean>();

  onReady(): void {
    console.info(`${LOG_TAG}: BRIDGE onReady() called from JS!`);
    this.ready.complete(true);
  }

  onTranslationSuccess(id: number, translatedText: string): void {
    this.complete(id, BergamotWebTranslationResult.success([translatedText]));
  }

  onTranslationBatchSuccess(id: number, translatedTextJson: string): void {
    console.info(`${LOG_TAG}: BRIDGE onTranslationBatchSuccess id=${id} jsonLen=${translatedTextJson.length}`);
    let values: string[] = [];
    try {
      const parsed = JSON.parse(translatedTextJson) as Object;
      if (!Array.isArray(parsed)) {
        throw new Error('Expected JSON array');
      }
      const arr = parsed as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        if (typeof arr[i] !== 'string') {
          throw new Error('Expected JSON string element');
        }
        values.push(arr[i] as string);
      }
    } catch (e) {
      const msg = (e as Error)?.message;
      this.complete(id, BergamotWebTranslationResult.error(msg !== undefined && msg.length > 0 ? msg :
        TranslationStrings.get(TranslationStrings.RESPONSE_PARSE_FAILED)));
      return;
    }
    this.complete(id, BergamotWebTranslationResult.success(values));
  }

  onTranslationError(id: number, message: string): void {
    console.info(`${LOG_TAG}: BRIDGE onTranslationError id=${id} message=${message}`);
    this.complete(id, BergamotWebTranslationResult.error(message));
  }

  onLog(message: string): void {
    console.info(`${LOG_TAG}: BRIDGE onLog from JS: ${message}`);
  }

  private complete(id: number, result: BergamotWebTranslationResult): void {
    const d = this.pending.get(id);
    if (d !== undefined) {
      this.pending.delete(id);
      d.complete(result);
    }
  }
}

/** 隐藏 Web 组件的构建参数 */
export class BergamotWebParams {
  controller: webview.WebviewController = new webview.WebviewController();
  bridge: BergamotBridge = new BergamotBridge();
  pageUrl: string = '';
  allowedPaths: string[] = [];
}

@Builder
function bergamotWebBuilder(params: BergamotWebParams) {
  Web({ src: '', controller: params.controller })
    .width(1)
    .height(1)
    .javaScriptAccess(true)
    .domStorageAccess(false)
    .fileAccess(true)
    .cacheMode(CacheMode.Online)
    .javaScriptProxy({
      object: params.bridge,
      name: BRIDGE_NAME,
      methodList: ['onReady', 'onTranslationSuccess', 'onTranslationBatchSuccess', 'onTranslationError', 'onLog'],
      controller: params.controller
    })
    .onControllerAttached(() => {
      try {
        params.controller.setPathAllowingUniversalAccess(params.allowedPaths);
      } catch (e) {
        console.warn(`${LOG_TAG}: setPathAllowingUniversalAccess failed: ${(e as Error)?.message}`);
      }
      try {
        params.controller.loadUrl(params.pageUrl);
      } catch (e) {
        console.error(`${LOG_TAG}: loadUrl failed: ${(e as Error)?.message}`);
      }
    })
    .onConsole((event: OnConsoleEvent) => {
      console.info(`${LOG_TAG}: WebView console: ${event.message.getSourceId()}:${event.message.getLineNumber()} ${event.message.getMessage()}`);
      return true;
    })
    .onErrorReceive((event: OnErrorReceiveEvent) => {
      console.info(`${LOG_TAG}: WebView error ${event.error.getErrorCode()}: ${event.error.getErrorInfo()} for ${event.request.getRequestUrl()}`);
    })
}

/** 可选：把隐藏 Web 容器挂入页面 NodeContainer（离线容器在个别设备不执行脚本时使用） */
export class BergamotWebHost extends NodeController {
  makeNode(uiContext: UIContext): FrameNode | null {
    return BergamotWebTranslator.instance().takeFrameNode();
  }
}

export class BergamotWebTranslator {
  private static inst: BergamotWebTranslator | null = null;
  private static uiContextOverride: UIContext | null = null;

  private bridge: BergamotBridge = new BergamotBridge();
  private requestId: number = 0;
  private readonly initMutex: AsyncMutex = new AsyncMutex();
  private node: BuilderNode<[BergamotWebParams]> | null = null;
  private params: BergamotWebParams | null = null;
  private initializedRegistryJson: string = '';
  private frameNodeTaken: boolean = false;

  static instance(): BergamotWebTranslator {
    if (BergamotWebTranslator.inst === null) {
      BergamotWebTranslator.inst = new BergamotWebTranslator();
    }
    return BergamotWebTranslator.inst as BergamotWebTranslator;
  }

  /** 由宿主页面提供 UIContext（未提供时取最后一个窗口的 UIContext） */
  static setUIContext(ui: UIContext): void {
    BergamotWebTranslator.uiContextOverride = ui;
  }

  takeFrameNode(): FrameNode | null {
    if (this.node === null || this.frameNodeTaken) {
      return null;
    }
    this.frameNodeTaken = true;
    return this.node.getFrameNode();
  }

  /** 源 translate()：初始化（必要时）后批量翻译 */
  async translate(content: string[], sourceLanguage: string, targetLanguage: string, preserveHtml: boolean,
    modelRegistry: BergamotModelRegistryEntry[], runtimeFileUrl: string): Promise<BergamotWebTranslationResult> {
    await this.initialize(modelRegistry, runtimeFileUrl);
    return this.translateBatch(content, sourceLanguage, targetLanguage, preserveHtml);
  }

  private async initialize(modelRegistry: BergamotModelRegistryEntry[], runtimeFileUrl: string): Promise<void> {
    const registryJson = registryToJson(modelRegistry);
    const initializationKey = `${runtimeFileUrl}\n${registryJson}`;
    await this.initMutex.withLock<void>(async (): Promise<void> => {
      await this.ensureWebView();
      const ready = await withTimeoutOrNull<boolean>(this.bridge.ready.promise, WEBVIEW_INIT_TIMEOUT_MS);
      if (ready === null) {
        this.destroyWebView();
        throw new TimeoutError(`Timed out waiting for ${WEBVIEW_INIT_TIMEOUT_MS} ms`);
      }
      if (this.initializedRegistryJson !== initializationKey) {
        await this.evaluate(`window.FeederBergamot.initialize(${registryJson}, ${JSON.stringify(runtimeFileUrl)});`);
        this.initializedRegistryJson = initializationKey;
      }
    });
  }

  private destroyWebView(): void {
    const n = this.node;
    if (n !== null) {
      try {
        n.dispose();
      } catch (e) {
        console.warn(`${LOG_TAG}: dispose failed: ${(e as Error)?.message}`);
      }
    }
    this.node = null;
    this.params = null;
    this.frameNodeTaken = false;
    this.initializedRegistryJson = '';
  }

  private async translateBatch(content: string[], sourceLanguage: string, targetLanguage: string,
    preserveHtml: boolean): Promise<BergamotWebTranslationResult> {
    this.requestId++;
    const id = this.requestId;
    const response = new Deferred<BergamotWebTranslationResult>();
    this.bridge.pending.set(id, response);
    await this.evaluate(`window.FeederBergamot.translateBatch(${id},${JSON.stringify(sourceLanguage)},` +
      `${JSON.stringify(targetLanguage)},${JSON.stringify(content)},${preserveHtml});`);
    const result = await withTimeoutOrNull<BergamotWebTranslationResult>(response.promise, WEBVIEW_TRANSLATION_TIMEOUT_MS);
    if (result === null) {
      this.bridge.pending.delete(id);
      return BergamotWebTranslationResult.error(TranslationStrings.get(TranslationStrings.WEBVIEW_TIMED_OUT));
    }
    return result;
  }

  private async resolveUIContext(): Promise<UIContext> {
    const override = BergamotWebTranslator.uiContextOverride;
    if (override !== null) {
      return override;
    }
    const ctx = AppBootstrap.context();
    if (ctx === null) {
      throw new Error(TranslationStrings.get(TranslationStrings.WEBVIEW_NOT_INITIALIZED));
    }
    const win = await window.getLastWindow(ctx);
    return win.getUIContext();
  }

  /** rawfile `bergamot/*` → `<filesDir>/bergamot-web/*`（每进程首次覆盖写，保证与安装包一致） */
  private assetsCopied: boolean = false;

  private copyAssets(filesDir: string): string {
    const dir = joinPath(filesDir, WEB_ASSET_DIR_NAME);
    if (this.assetsCopied && isFile(joinPath(dir, 'index.html'))) {
      return dir;
    }
    const ctx = AppBootstrap.context();
    if (ctx === null) {
      throw new Error(TranslationStrings.get(TranslationStrings.WEBVIEW_NOT_INITIALIZED));
    }
    for (let i = 0; i < BERGAMOT_ASSETS.length; i++) {
      const rel = BERGAMOT_ASSETS[i];
      const bytes = ctx.resourceManager.getRawFileContentSync(`${RAWFILE_ASSET_ROOT}/${rel}`);
      const dest = joinPath(dir, rel);
      mkdirs(parentDir(dest));
      writeBytes(dest, bytes);
    }
    this.assetsCopied = true;
    return dir;
  }

  private async ensureWebView(): Promise<void> {
    if (this.node !== null) {
      return;
    }
    const paths = AppBootstrap.filePaths();
    if (paths === null) {
      throw new Error(TranslationStrings.get(TranslationStrings.WEBVIEW_NOT_INITIALIZED));
    }
    const assetDir = this.copyAssets(paths.filesDir);
    const modelsDir = joinPath(paths.filesDir, 'translation-models');
    mkdirs(modelsDir);
    const uiContext = await this.resolveUIContext();
    this.bridge.ready = new Deferred<boolean>();
    const params = new BergamotWebParams();
    params.bridge = this.bridge;
    params.pageUrl = `file://${joinPath(assetDir, 'index.html')}`;
    params.allowedPaths = [assetDir, modelsDir];
    const node = new BuilderNode<[BergamotWebParams]>(uiContext, { selfIdealSize: { width: 1, height: 1 } });
    node.build(wrapBuilder<[BergamotWebParams]>(bergamotWebBuilder), params);
    this.node = node;
    this.params = params;
    this.frameNodeTaken = false;
    this.bridge.ready.promise.then(() => {
      try {
        params.controller.onActive();
      } catch (e) {
        console.warn(`${LOG_TAG}: onActive failed: ${(e as Error)?.message}`);
      }
    });
  }

  private async evaluate(script: string): Promise<void> {
    const p = this.params;
    if (p === null) {
      throw new Error(TranslationStrings.get(TranslationStrings.WEBVIEW_NOT_INITIALIZED));
    }
    try {
      await p.controller.runJavaScript(script);
    } catch (e) {
      const msg = (e as Error)?.message;
      throw new Error(msg !== undefined && msg.length > 0 ? msg : TranslationStrings.get(TranslationStrings.WEBVIEW_NOT_INITIALIZED));
    }
  }
}
