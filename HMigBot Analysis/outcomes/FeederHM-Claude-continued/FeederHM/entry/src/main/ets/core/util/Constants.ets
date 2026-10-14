/**
 * Constants.ets —— 跨模块常量：深链、外部链接、目录/文件布局、偏好 key（纯逻辑，不依赖 Context）。
 * 源：util/ContextExtensions.kt:109-110、util/BugReport.kt、util/FilePathProvider.kt、blob/Blob.kt、util/PrefUtils.kt。
 */

// ---------------- 深链（通知、小组件、快捷方式、导航路由共用） ----------------
export const DEEP_LINK_HOST: string = 'feederapp.nononsenseapps.com';
export const DEEP_LINK_BASE_URI: string = 'https://' + DEEP_LINK_HOST;

// ---------------- 外部链接 ----------------
/** 源 openGithubIssues() 的目标 */
export const GITHUB_ISSUES_URL: string = 'https://github.com/spacecowboy/feeder/issues';
/** 源 KOFI_URL */
export const KOFI_URL: string = 'https://ko-fi.com/spacecowboy';

// ---------------- 目录布局（FilePathProvider） ----------------
/** filesDir/articles：文章正文 <id>.txt.gz */
export const ARTICLES_DIR_NAME: string = 'articles';
/** cacheDir/full_articles：全文 <id>.full.html.gz */
export const FULL_ARTICLES_DIR_NAME: string = 'full_articles';
/** filesDir/fonts */
export const FONTS_DIR_NAME: string = 'fonts';
/** cacheDir/http */
export const HTTP_CACHE_DIR_NAME: string = 'http';
/** cacheDir/image_cache */
export const IMAGE_CACHE_DIR_NAME: string = 'image_cache';
/** cacheDir/http_image_cache */
export const HTTP_IMAGE_CACHE_DIR_NAME: string = 'http_image_cache';

/** 文章正文 blob 文件后缀（blob/Blob.kt blobFile） */
export const BLOB_FILE_SUFFIX: string = '.txt.gz';
/** 全文 blob 文件后缀（blob/Blob.kt blobFullFile） */
export const BLOB_FULL_FILE_SUFFIX: string = '.full.html.gz';

function joinPath(dir: string, name: string): string {
  return dir.endsWith('/') ? dir + name : dir + '/' + name;
}

/** blobFile(itemId, articleDir) → "<articleDir>/<id>.txt.gz" */
export function blobFilePath(itemId: number, articleDir: string): string {
  return joinPath(articleDir, String(itemId) + BLOB_FILE_SUFFIX);
}

/** blobFullFile(itemId, fullArticleDir) → "<fullArticleDir>/<id>.full.html.gz" */
export function blobFullFilePath(itemId: number, fullArticleDir: string): string {
  return joinPath(fullArticleDir, String(itemId) + BLOB_FULL_FILE_SUFFIX);
}

/**
 * 源 FilePathProvider：由 cacheDir / filesDir（鸿蒙 UIAbilityContext.cacheDir / filesDir）派生全部目录。
 * 只计算路径，不创建目录（与源一致，创建由使用方负责）。
 */
export class FilePathProvider {
  readonly cacheDir: string;
  readonly filesDir: string;

  constructor(cacheDir: string, filesDir: string) {
    this.cacheDir = cacheDir;
    this.filesDir = filesDir;
  }

  get articleDir(): string {
    return joinPath(this.filesDir, ARTICLES_DIR_NAME);
  }

  get fullArticleDir(): string {
    return joinPath(this.cacheDir, FULL_ARTICLES_DIR_NAME);
  }

  get fontsDir(): string {
    return joinPath(this.filesDir, FONTS_DIR_NAME);
  }

  get httpCacheDir(): string {
    return joinPath(this.cacheDir, HTTP_CACHE_DIR_NAME);
  }

  get imageCacheDir(): string {
    return joinPath(this.cacheDir, IMAGE_CACHE_DIR_NAME);
  }

  get httpImageCacheDir(): string {
    return joinPath(this.cacheDir, HTTP_IMAGE_CACHE_DIR_NAME);
  }
}

// ---------------- 偏好（util/PrefUtils.kt） ----------------
/** 以字符串存储；与 core/settings/SettingsKeys.ets 中同名常量值一致 */
export const PREF_MAX_ITEM_COUNT_PER_FEED: string = 'pref_max_item_count_per_feed';
export const DEFAULT_MAX_ITEM_COUNT_PER_FEED: string = '100';

/** SharedPreferences.getStringNonNull：读取为 null 时回落默认值 */
export function getStringNonNull(value: string | null, defaultValue: string): string {
  return value !== null ? value : defaultValue;
}
