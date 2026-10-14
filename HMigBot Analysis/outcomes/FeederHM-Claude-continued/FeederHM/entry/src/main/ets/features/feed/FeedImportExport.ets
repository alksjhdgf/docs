/**
 * FeedImportExport — 源 FeedScreen.kt:188-231 的四个 SAF 启动器 + onImport/onExportOPML/onImportSavedArticles/
 * onExportSavedArticles（:356-415）的鸿蒙实现：
 *  - OpenDocument → picker.DocumentViewPicker.select（MIME 过滤 → 后缀过滤 fileSuffixFilters，含 `.*` 即任意文件）；
 *  - CreateDocument → picker.DocumentViewPicker.save（newFileNames = 源默认文件名，fileSuffixChoices = 后缀）；
 *  - 选择器打不开（源 ActivityNotFoundException）→ toast 失败文案；
 *  - 选中后在应用级作用域（AppScope，等价 ApplicationCoroutineScope）执行 core/parser/OpmlActions 的导入/导出，
 *    失败 toast 由 OpmlActions 负责（FD-A28..A31）。
 */
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { AppScope } from '../../core/app/AppBootstrap';
import { ID_UNSET } from '../../core/model/Enums';
import {
  exportOpml, exportSavedArticles, importOpml, importSavedArticles, setOpmlImportSyncHook
} from '../../core/parser/OpmlActions';
import { OPML_IMPORT_SUFFIXES, opmlExportFileName } from '../../core/parser/OpmlWriter';
import { savedArticlesExportFileName } from '../../core/parser/SavedArticlesExport';
import { SyncScheduler } from '../../core/sync/SyncScheduler';

const LOG_TAG: string = 'FEEDER_FEEDIMPORTEXPORT';
/** 源 savedArticleImporter MIME [text/plain, application/octet-stream, *&#47;*] → 后缀 */
export const SAVED_ARTICLES_IMPORT_SUFFIXES: string[] = ['.txt', '.json', '.*'];
export const OPML_EXPORT_SUFFIX: string = '.opml';
export const SAVED_ARTICLES_EXPORT_SUFFIX: string = '.json';

function toast(ui: UIContext, message: Resource): void {
  try {
    ui.getPromptAction().showToast({ message: message, duration: 2000 });
  } catch (e) {
    console.error(`${LOG_TAG}: toast failed: ${(e as Error)?.message}`);
  }
}

function newPicker(ui: UIContext): picker.DocumentViewPicker {
  const ctx: common.Context | undefined = ui.getHostContext();
  if (ctx === undefined) {
    return new picker.DocumentViewPicker();
  }
  return new picker.DocumentViewPicker(ctx as common.UIAbilityContext);
}

/** 打开文件选择器选一个文件；用户取消返回 null；打不开抛错 */
async function pickOne(ui: UIContext, suffixes: string[]): Promise<string | null> {
  const opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
  opts.maxSelectNumber = 1;
  opts.fileSuffixFilters = suffixes;
  const uris: string[] = await newPicker(ui).select(opts);
  return uris.length > 0 ? uris[0] : null;
}

/** 打开新建文档选择器；用户取消返回 null；打不开抛错 */
async function pickSave(ui: UIContext, fileName: string, suffix: string): Promise<string | null> {
  const opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
  opts.newFileNames = [fileName];
  opts.fileSuffixChoices = [suffix];
  const uris: string[] = await newPicker(ui).save(opts);
  return uris.length > 0 ? uris[0] : null;
}

/**
 * 源 importOpml 后 runOnceRssSync(di, triggeredByUser = true)（forceNetwork 默认 false）。
 * 同步钩子归同步引擎/启动单元注册；此处在调用前确保已注册（幂等覆盖为同一语义）。
 */
function ensureOpmlImportSyncHook(): void {
  setOpmlImportSyncHook(async (): Promise<void> => {
    await SyncScheduler.runOnceRssSync(ID_UNSET, '', false, true);
  });
}

export class FeedImportExport {
  /** FD-A28 */
  static importOpml(ui: UIContext): void {
    pickOne(ui, OPML_IMPORT_SUFFIXES).then((uri: string | null) => {
      if (uri === null) {
        return;
      }
      const target: string = uri;
      ensureOpmlImportSyncHook();
      AppScope.launch('importOpml', async (): Promise<void> => {
        await importOpml(target);
      });
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: OPML picker failed: ${e?.message}`);
      toast(ui, $r('app.string.failed_to_import_OPML'));
    });
  }

  /** FD-A29：默认名 feeder-export-<yyyy-MM-dd>-<当日秒数>.opml */
  static exportOpml(ui: UIContext): void {
    pickSave(ui, opmlExportFileName(Date.now()), OPML_EXPORT_SUFFIX).then((uri: string | null) => {
      if (uri === null) {
        return;
      }
      const target: string = uri;
      AppScope.launch('exportOpml', async (): Promise<void> => {
        await exportOpml(target);
      });
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: OPML save picker failed: ${e?.message}`);
      toast(ui, $r('app.string.failed_to_export_OPML'));
    });
  }

  /** FD-A30 */
  static importSavedArticles(ui: UIContext): void {
    pickOne(ui, SAVED_ARTICLES_IMPORT_SUFFIXES).then((uri: string | null) => {
      if (uri === null) {
        return;
      }
      const target: string = uri;
      AppScope.launch('importSavedArticles', async (): Promise<void> => {
        await importSavedArticles(target);
      });
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: saved articles picker failed: ${e?.message}`);
      toast(ui, $r('app.string.failed_to_import_saved_articles'));
    });
  }

  /** FD-A31：默认名 feeder-saved-articles-<yyyy-MM-dd>-<当日秒数>.json */
  static exportSavedArticles(ui: UIContext): void {
    pickSave(ui, savedArticlesExportFileName(Date.now()), SAVED_ARTICLES_EXPORT_SUFFIX).then((uri: string | null) => {
      if (uri === null) {
        return;
      }
      const target: string = uri;
      AppScope.launch('exportSavedArticles', async (): Promise<void> => {
        await exportSavedArticles(target);
      });
    }).catch((e: Error) => {
      console.error(`${LOG_TAG}: saved articles save picker failed: ${e?.message}`);
      toast(ui, $r('app.string.failed_to_export_saved_articles'));
    });
  }
}
