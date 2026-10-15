/**
 * PackageUtils (source: core/util/package/PackageUtils.kt) — app name / versionName / versionCode
 * via bundleManager.getBundleInfoForSelfSync (used by the About page).
 * Failures return '' / 0 like the source.
 */
import { bundleManager, common } from '@kit.AbilityKit';
import { LogUtils } from './LogUtils';

const TAG: string = 'PackageUtils';

export class PackageUtils {
  private static cachedInfo: bundleManager.BundleInfo | null = null;

  private static bundleInfo(): bundleManager.BundleInfo | null {
    if (PackageUtils.cachedInfo !== null) {
      return PackageUtils.cachedInfo;
    }
    try {
      PackageUtils.cachedInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    } catch (e) {
      LogUtils.wTag(TAG, `getBundleInfoForSelfSync failed: ${JSON.stringify(e)}`);
      PackageUtils.cachedInfo = null;
    }
    return PackageUtils.cachedInfo;
  }

  /**
   * Application label (app.json5 label resolved through the resource manager).
   * ctx: any Context (e.g. getUIContext().getHostContext()).
   */
  static getCurrentAppName(ctx: common.Context | undefined | null): string {
    const info: bundleManager.BundleInfo | null = PackageUtils.bundleInfo();
    if (info === null) {
      return '';
    }
    const labelId: number = info.appInfo.labelId;
    if (ctx !== undefined && ctx !== null && labelId > 0) {
      try {
        return ctx.resourceManager.getStringSync(labelId);
      } catch (e) {
        LogUtils.wTag(TAG, `resolve label failed: ${JSON.stringify(e)}`);
      }
    }
    return info.appInfo.label;
  }

  static getCurrentVersionName(): string {
    const info: bundleManager.BundleInfo | null = PackageUtils.bundleInfo();
    return info === null ? '' : info.versionName;
  }

  static getCurrentVersionCode(): number {
    const info: bundleManager.BundleInfo | null = PackageUtils.bundleInfo();
    return info === null ? 0 : info.versionCode;
  }

  static getBundleName(): string {
    const info: bundleManager.BundleInfo | null = PackageUtils.bundleInfo();
    return info === null ? '' : info.name;
  }
}
