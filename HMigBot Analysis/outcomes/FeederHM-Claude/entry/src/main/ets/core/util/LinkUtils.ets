/**
 * LinkUtils.ets —— 源 util/LinkUtils.kt 逐函数移植（java.net.URL/URI 语义经 JavaCompat 复刻）。
 * 返回 URL 的函数返回 JavaUrl；需要字符串时调用 .toString()（≙ URL.toString/toExternalForm）。
 */
import { JavaUri, JavaUrl, MalformedURLException, URISyntaxException } from './JavaCompat';

/**
 * 确保 url 合法、带 scheme：'google.com' → 'http://google.com'。
 * 空白 → MalformedURLException("String is blank")；可解析为绝对 URI 但协议不受支持（如 gemini://）→ 抛 MalformedURLException。
 */
export function sloppyLinkToStrictURL(url: string): JavaUrl {
  if (url.trim().length === 0) {
    throw new MalformedURLException('String is blank');
  }
  try {
    return JavaUrl.parse(url);
  } catch (e) {
    if (!(e instanceof MalformedURLException)) {
      throw e as Error;
    }
    const uri = sloppyLinktoURIOrNull(url);
    if (uri !== null && uri.isAbsolute()) {
      return uri.toURL();
    }
    return JavaUrl.parse('http://' + url);
  }
}

export function sloppyLinktoURIOrNull(text: string): JavaUri | null {
  try {
    return JavaUri.parse(text);
  } catch (e) {
    if (e instanceof URISyntaxException) {
      return null;
    }
    throw e as Error;
  }
}

export function sloppyLinkToStrictURLOrNull(url: string): JavaUrl | null {
  try {
    return sloppyLinkToStrictURL(url);
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return null;
    }
    throw e as Error;
  }
}

export function urlHasNoAuthParams(url: JavaUrl): boolean {
  return url.userInfo === null || url.userInfo.length === 0;
}

export function urlHasNoQueryParams(url: JavaUrl): boolean {
  return url.query === null || url.query.length === 0;
}

/**
 * 不保证准确反映非法输入；失败返回 URL("http://")（toString 为 "http:"），供 DB 字符串→URL 转换与迁移不崩溃。
 */
export function sloppyLinkToStrictURLNoThrows(url: string): JavaUrl {
  try {
    return sloppyLinkToStrictURL(url);
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return JavaUrl.parse('http://');
    }
    throw e as Error;
  }
}

/** 出错时返回原 link，不抛异常。 */
export function relativeLinkIntoAbsolute(base: JavaUrl, link: string): string {
  try {
    return relativeLinkIntoAbsoluteOrThrow(base, link).toString();
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return link;
    }
    throw e as Error;
  }
}

/** link 为 null 返回 null；出错时返回原 link。 */
export function relativeLinkIntoAbsoluteOrNull(base: JavaUrl, link: string | null): string | null {
  try {
    if (link !== null) {
      return relativeLinkIntoAbsoluteOrThrow(base, link).toString();
    }
    return null;
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return link;
    }
    throw e as Error;
  }
}

/** link 本身是合法 URL 则直接用，否则按 base 解析（new URL(base, link)）；失败抛 MalformedURLException。 */
export function relativeLinkIntoAbsoluteOrThrow(base: JavaUrl, link: string): JavaUrl {
  try {
    return JavaUrl.parse(link);
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return JavaUrl.parse(link, base);
    }
    throw e as Error;
  }
}

/** 出错时返回 null，不抛异常。 */
export function relativeLinkIntoAbsoluteOrNullIfNotValid(base: JavaUrl, link: string | null): JavaUrl | null {
  try {
    if (link !== null) {
      return relativeLinkIntoAbsoluteOrThrow(base, link);
    }
    return null;
  } catch (e) {
    if (e instanceof MalformedURLException) {
      return null;
    }
    throw e as Error;
  }
}
