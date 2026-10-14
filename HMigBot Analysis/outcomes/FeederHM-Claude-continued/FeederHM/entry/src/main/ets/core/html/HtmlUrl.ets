/**
 * HtmlUrl.ets —— Jsoup StringUtil.resolve(baseUrl, relUrl) 语义（Element.absUrl / attr("abs:x") 的底层）。
 *  1. 去掉两者中的控制字符 [\x00-\x1f]（故跨行 data: URL 会被拼成一行）
 *  2. base 非法 → 尝试 rel 自身作为绝对 URL；
 *  3. 否则 new URL(base, rel)（rel 以 '?' 开头时先补 base.path，Jsoup workaround）；
 *  4. 失败（含 java.net.URL 不认识的协议，如 data:/tel:/mailto?）→ rel 若有合法 scheme 原样返回，否则 ''。
 */
import { JavaUrl, MalformedURLException } from '../util/JavaCompat';

const VALID_URI_SCHEME: RegExp = new RegExp('^[a-zA-Z][a-zA-Z0-9+\\-.]*:');

export function stripControlChars(s: string): string {
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    if (s.charCodeAt(i) > 0x1f) {
      out += s.charAt(i);
    }
  }
  return out;
}

export function resolveUrl(baseUrl: string, relUrl: string): string {
  const base: string = stripControlChars(baseUrl);
  let rel: string = stripControlChars(relUrl);
  try {
    let baseU: JavaUrl | null = null;
    try {
      baseU = JavaUrl.parse(base);
    } catch (e) {
      if (!(e instanceof MalformedURLException)) {
        throw e as Error;
      }
      baseU = null;
    }
    if (baseU === null) {
      return JavaUrl.parse(rel).toString();
    }
    if (rel.startsWith('?')) {
      rel = baseU.path + rel;
    }
    return JavaUrl.parse(rel, baseU).toString();
  } catch (e) {
    if (!(e instanceof MalformedURLException)) {
      throw e as Error;
    }
    return VALID_URI_SCHEME.test(rel) ? rel : '';
  }
}
