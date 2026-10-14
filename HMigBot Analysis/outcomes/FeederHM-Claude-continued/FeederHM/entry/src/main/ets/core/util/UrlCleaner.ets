/**
 * UrlCleaner.ets —— 源 util/UrlCleaner.kt：分享前剔除常见追踪参数。
 * 规则全集：参数名（URLDecoder 解码后）以 "utm_" 或 "traffic_source" 开头（区分大小写）即删除；其余参数保持原顺序与原始值。
 * 无 query / 无追踪参数 / 无法解析为 URI → 原串逐字返回。
 * 有追踪参数时按 java.net.URI 五参构造器重建（逐位复刻其引用规则，包括保留值中的 '%' 被编码为 '%25' 的源怪癖）。
 */
import { JavaUri, javaUrlDecode, javaUrlEncode } from './JavaCompat';

export const TRACKING_PREFIXES: string[] = ['utm_', 'traffic_source'];

class QueryParam {
  name: string = '';
  value: string = '';
}

function isTracking(name: string): boolean {
  for (let i = 0; i < TRACKING_PREFIXES.length; i++) {
    if (name.startsWith(TRACKING_PREFIXES[i])) {
      return true;
    }
  }
  return false;
}

export function stripTrackingParameters(url: string): string {
  let uri: JavaUri;
  try {
    uri = JavaUri.parse(url);
  } catch (e) {
    return url;
  }

  const query = uri.rawQuery;
  if (query === null) {
    return url;
  }

  const params: QueryParam[] = [];
  const pieces = query.split('&');
  for (let i = 0; i < pieces.length; i++) {
    const param = pieces[i];
    const eq = param.indexOf('=');
    const p = new QueryParam();
    // URLDecoder.decode：非法 % 转义抛 IllegalArgumentException（与源一致，不捕获）
    p.name = javaUrlDecode(eq >= 0 ? param.substring(0, eq) : param);
    p.value = eq >= 0 ? param.substring(eq + 1) : '';
    params.push(p);
  }

  let hasTracking = false;
  for (let i = 0; i < params.length; i++) {
    if (isTracking(params[i].name)) {
      hasTracking = true;
      break;
    }
  }
  if (!hasTracking) {
    return url;
  }

  const kept: string[] = [];
  for (let i = 0; i < params.length; i++) {
    const p = params[i];
    if (isTracking(p.name)) {
      continue;
    }
    const encodedName = javaUrlEncode(p.name);
    kept.push(p.value.length === 0 ? encodedName : encodedName + '=' + p.value);
  }
  const newQuery: string | null = kept.length === 0 ? null : kept.join('&');

  return JavaUri.create5(uri.scheme, uri.getAuthority(), uri.getPath(), newQuery, uri.getFragment()).toString();
}
