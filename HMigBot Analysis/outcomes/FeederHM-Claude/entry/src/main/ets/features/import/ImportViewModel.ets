/**
 * ImportViewModel —— 源 ui/compose/ompl/OpmlImportScreen.kt 的状态与动作：
 *  - ViewState（feeds 按 url 去重 / error / initial；okEnabled、feedCount、tagCount 派生，EF-A48/A49）；
 *  - 打开即解析文件做预览（只收集订阅源，不写库、不导入设置/屏蔽词，EF-A48）；
 *  - OK：在应用级作用域（AppScope ≙ ApplicationCoroutineScope）执行完整 importOpml（订阅源按 url 新增/覆盖、
 *    设置与屏蔽词）并触发一次用户同步，页面关闭不影响（EF-A52）；
 *  - DocumentViewPicker 选择 OPML 文件（ImportPage 无 uri 进入时）；
 *  - exportOpml(uri)：导出入口（Feed 菜单 → 保存选择器后调用）。
 */
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { AppScope } from '../../core/app/AppBootstrap';
import { Feed } from '../../core/model/Feed';
import { ID_UNSET } from '../../core/model/Enums';
import { OPMLParserHandler, OpmlError, OpmlPullParser } from '../../core/parser/OpmlParser';
import {
  OpmlExportUnknownError,
  exportOpml as coreExportOpml,
  importOpml as coreImportOpml,
  readAllBytes,
  setOpmlImportSyncHook
} from '../../core/parser/OpmlActions';
import { OPML_IMPORT_SUFFIXES } from '../../core/parser/OpmlWriter';
import { SyncScheduler } from '../../core/sync/SyncScheduler';
import { Either } from '../../core/util/Either';

const LOG_TAG: string = 'FEEDER_OPMLIMPORT';

/** 源 ViewState（@Immutable data class）的可观察等价物 */
@ObservedV2
export class ImportViewState {
  /** 预览订阅源（按 url 去重，按标题排序，EF-A50） */
  @Trace feeds: Feed[] = [];
  @Trace error: boolean = false;
  @Trace initial: boolean = true;
  /** 列表数据版本（驱动 LazyForEach 重载） */
  @Trace version: number = 0;

  /** 源 okEnabled = feeds.isNotEmpty() */
  get okEnabled(): boolean {
    return this.feeds.length > 0;
  }

  /** 源 feedCount = feeds.size（按 url 去重后） */
  get feedCount(): number {
    return this.feeds.length;
  }

  /** 源 tagCount：tag 非空白的订阅源个数（非去重标签数，EF-A49） */
  get tagCount(): number {
    return countTaggedFeeds(this.feeds);
  }
}

/** EF-A49：tag 非空白的订阅源个数 */
export function countTaggedFeeds(feeds: Feed[]): number {
  let n: number = 0;
  for (const f of feeds) {
    if (f.tag.trim().length > 0) {
      n++;
    }
  }
  return n;
}

/** 源 feeds.values.sortedBy { it.title }（Kotlin String.compareTo：UTF-16 码元字典序，稳定） */
export function sortFeedsByTitle(feeds: Feed[]): Feed[] {
  const out: Feed[] = feeds.slice();
  out.sort((a: Feed, b: Feed): number => a.title < b.title ? -1 : (a.title > b.title ? 1 : 0));
  return out;
}

/** 源 Map 去重：同 url 后者覆盖前者（保持首次插入位置，与 Kotlin map + pair 一致） */
export function mergeFeedByUrl(feeds: Feed[], feed: Feed): Feed[] {
  const out: Feed[] = feeds.slice();
  for (let i = 0; i < out.length; i++) {
    if (out[i].url === feed.url) {
      out[i] = feed;
      return out;
    }
  }
  out.push(feed);
  return out;
}

/** 预览 handler：只收集订阅源；设置/屏蔽词忽略（源匿名 OPMLParserHandler） */
class PreviewHandler implements OPMLParserHandler {
  private readonly onFeed: (feed: Feed) => void;

  constructor(onFeed: (feed: Feed) => void) {
    this.onFeed = onFeed;
  }

  async saveFeed(feed: Feed): Promise<void> {
    this.onFeed(feed);
  }

  async saveSetting(key: string, value: string): Promise<void> {
    // 源：预览不导入设置
  }

  async saveBlocklistPatterns(patterns: string[]): Promise<void> {
    // 源：预览不导入屏蔽词
  }
}

/** LazyForEach 数据源（整体替换 → onDataReloaded） */
export class PreviewFeedDataSource implements IDataSource {
  private items: Feed[] = [];
  private listeners: DataChangeListener[] = [];

  setItems(items: Feed[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Feed {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }
}

/** 源 importOpml 后 runOnceRssSync(di, triggeredByUser = true)（forceNetwork 默认 false） */
function ensureOpmlImportSyncHook(): void {
  setOpmlImportSyncHook(async (): Promise<void> => {
    await SyncScheduler.runOnceRssSync(ID_UNSET, '', false, true);
  });
}

function newPicker(ui: UIContext): picker.DocumentViewPicker {
  const ctx: common.Context | undefined = ui.getHostContext();
  if (ctx === undefined) {
    return new picker.DocumentViewPicker();
  }
  return new picker.DocumentViewPicker(ctx as common.UIAbilityContext);
}

@ObservedV2
export class ImportViewModel {
  @Trace state: ImportViewState = new ImportViewState();
  readonly dataSource: PreviewFeedDataSource = new PreviewFeedDataSource();
  private loadedUri: string | null = null;
  private loadToken: number = 0;

  /**
   * 源 LaunchedEffect(uri)：uri 为空 → error；否则逐个 saveFeed 更新预览；读文件抛异常 → error。
   * 解析结束仍未收集到订阅源时：成功 → initial=false（显示 `No feeds`）；解析失败 → error（EF-A48）。
   */
  async loadPreview(uri: string | null): Promise<void> {
    const token: number = ++this.loadToken;
    this.loadedUri = uri;
    this.state = new ImportViewState();
    this.dataSource.setItems([]);
    if (uri === null || uri.length === 0) {
      const s: ImportViewState = new ImportViewState();
      s.error = true;
      s.initial = false;
      this.state = s;
      return;
    }
    let collected: Feed[] = [];
    const parser: OpmlPullParser = new OpmlPullParser(new PreviewHandler((feed: Feed): void => {
      if (token !== this.loadToken) {
        return;
      }
      collected = mergeFeedByUrl(collected, feed);
      this.publish(collected, false, false);
    }));
    try {
      const bytes: Uint8Array = await readAllBytes(uri);
      const result: Either<OpmlError, boolean> = await parser.parseBytesWithFallback(bytes);
      if (token !== this.loadToken) {
        return;
      }
      if (collected.length === 0) {
        this.publish(collected, result.isLeft(), false);
      }
    } catch (t) {
      console.error(LOG_TAG, `Could not import file: ${(t as Error)?.message}`);
      if (token !== this.loadToken) {
        return;
      }
      this.publish(collected, true, false);
    }
  }

  private publish(feeds: Feed[], error: boolean, initial: boolean): void {
    const s: ImportViewState = new ImportViewState();
    s.feeds = sortFeedsByTitle(feeds);
    s.error = error;
    s.initial = initial;
    s.version = this.state.version + 1;
    this.state = s;
    this.dataSource.setItems(s.feeds);
  }

  /** 源 onOk 前段：uri 非空 → applicationCoroutineScope.launch { importOpml(di, uri) }（EF-A52） */
  confirmImport(): void {
    const uri: string | null = this.loadedUri;
    if (uri === null || uri.length === 0) {
      return;
    }
    const target: string = uri;
    ensureOpmlImportSyncHook();
    AppScope.launch('importOpml', async (): Promise<void> => {
      await coreImportOpml(target);
    });
  }

  /** DocumentViewPicker 选一个 OPML 文件；取消返回 null；选择器打不开抛错 */
  static async pickOpmlFile(ui: UIContext): Promise<string | null> {
    const opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    opts.maxSelectNumber = 1;
    opts.fileSuffixFilters = OPML_IMPORT_SUFFIXES;
    const uris: string[] = await newPicker(ui).select(opts);
    return uris.length > 0 ? uris[0] : null;
  }
}

/** 导出入口（Feed 菜单 → 保存选择器得到 uri 后调用）：应用级作用域执行 core exportOpml */
export function exportOpml(uri: string): Promise<Either<OpmlExportUnknownError, boolean>> {
  return new Promise<Either<OpmlExportUnknownError, boolean>>(
    (resolve: (v: Either<OpmlExportUnknownError, boolean>) => void) => {
      AppScope.launch('exportOpml', async (): Promise<void> => {
        resolve(await coreExportOpml(uri));
      });
    });
}
