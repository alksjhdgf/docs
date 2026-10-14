/**
 * JavaUri.ets —— java.net.URI（RFC2396 解析器）在本工程所需子集的逐位复刻：
 *  - parse(s)：语法校验（非法抛 URISyntaxException），拆出 scheme / 不透明部分 / authority / path / query / fragment
 *  - 解码 getter（getAuthority/getPath/getFragment，等价 URI.decode，UTF-8 + REPLACE）
 *  - create5(scheme, authority, path, query, fragment)：5 参构造器的引用（quote）规则，含 '%' → '%25' 的二次编码怪癖
 *  - toURL()：绝对 URI → JavaUrl（未知协议抛 MalformedURLException）
 * 源：input/Feeder 使用 java.net.URI 的位置（util/LinkUtils.kt、util/UrlCleaner.kt）。
 */
import {
  CS_ALPHA,
  CS_PATH,
  CS_REG_NAME,
  CS_SCHEME,
  CS_SERVER,
  CS_URIC,
  CS_USERINFO,
  IllegalArgumentException,
  isIPv6Literal,
  URISyntaxException,
  hexDigitValue,
  inCharSet,
  isJavaIsoControl,
  isJavaSpaceChar,
  isUriOther,
  percentByte,
  utf8Decode,
  utf8Encode
} from './JavaCodec';
import { JavaUrl } from './JavaUrl';

/** checkChars：所有字符属于 set，或（allowEscaped 时）为合法 %HH 转义 / "other" 字符；返回首个非法位置或 -1。 */
function firstIllegal(s: string, start: number, end: number, set: string, allowEscaped: boolean): number {
  let p = start;
  while (p < end) {
    const c = s.charCodeAt(p);
    if (inCharSet(c, set)) {
      p++;
      continue;
    }
    if (allowEscaped && c === 0x25) {
      if (p + 2 < end && hexDigitValue(s.charCodeAt(p + 1)) >= 0 && hexDigitValue(s.charCodeAt(p + 2)) >= 0) {
        p += 3;
        continue;
      }
      return p;
    }
    if (allowEscaped && isUriOther(c)) {
      p++;
      continue;
    }
    return p;
  }
  return -1;
}

function checkChars(input: string, start: number, end: number, set: string, allowEscaped: boolean,
  what: string): void {
  const bad = firstIllegal(input, start, end, set, allowEscaped);
  if (bad >= 0) {
    const c = input.charCodeAt(bad);
    if (c === 0x25) {
      throw new URISyntaxException(input, 'Malformed escape pair', bad);
    }
    throw new URISyntaxException(input, 'Illegal character in ' + what, bad);
  }
}

/** scan(start,end,err,stop)：遇 err 字符返回 -1，遇 stop 字符返回其位置，否则返回 end。 */
function scan(s: string, start: number, end: number, err: string, stop: string): number {
  let p = start;
  while (p < end) {
    const ch = s.charAt(p);
    if (err.indexOf(ch) >= 0) {
      return -1;
    }
    if (stop.indexOf(ch) >= 0) {
      break;
    }
    p++;
  }
  return p;
}

/** 字符全属于（set ∪ 转义 ∪ other）？ */
function allIn(s: string, set: string, allowEscaped: boolean): boolean {
  return firstIllegal(s, 0, s.length, set, allowEscaped) < 0;
}

/** server-based authority 的近似校验：[userinfo@]host[:port]，host 为 IPv6 字面量 / 主机名 / IPv4。 */
function isServerAuthority(auth: string): boolean {
  let rest = auth;
  const at = rest.lastIndexOf('@');
  if (at >= 0) {
    if (!allIn(rest.substring(0, at), CS_USERINFO, true)) {
      return false;
    }
    rest = rest.substring(at + 1);
  }
  let hostPart = rest;
  let portPart: string | null = null;
  if (rest.startsWith('[')) {
    const close = rest.indexOf(']');
    if (close < 0 || !isIPv6Literal(rest.substring(1, close))) {
      return false;
    }
    hostPart = rest.substring(0, close + 1);
    const after = rest.substring(close + 1);
    if (after.length > 0) {
      if (!after.startsWith(':')) {
        return false;
      }
      portPart = after.substring(1);
    }
  } else {
    const colon = rest.indexOf(':');
    if (colon >= 0) {
      hostPart = rest.substring(0, colon);
      portPart = rest.substring(colon + 1);
    }
    const hostRe = new RegExp('^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\\.)*[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\\.?$');
    if (hostPart.length > 0 && !hostRe.test(hostPart)) {
      return false;
    }
  }
  if (portPart !== null && portPart.length > 0) {
    const portRe = new RegExp('^[0-9]+$');
    if (!portRe.test(portPart)) {
      return false;
    }
  }
  return true;
}

/** java.net.URI.decode（authority 时忽略方括号内的 %）。 */
export function javaUriDecode(s: string | null, ignorePercentInSquareBrackets: boolean): string | null {
  if (s === null) {
    return null;
  }
  if (s.length === 0 || s.indexOf('%') < 0) {
    return s;
  }
  let out = '';
  let betweenBrackets = false;
  let i = 0;
  const n = s.length;
  while (i < n) {
    const c = s.charAt(i);
    if (ignorePercentInSquareBrackets) {
      if (c === '[') {
        betweenBrackets = true;
      } else if (betweenBrackets && c === ']') {
        betweenBrackets = false;
      }
    }
    if (c !== '%' || betweenBrackets) {
      out += c;
      i++;
      continue;
    }
    const bytes: number[] = [];
    while (i + 2 < n && s.charAt(i) === '%') {
      const h = hexDigitValue(s.charCodeAt(i + 1));
      const l = hexDigitValue(s.charCodeAt(i + 2));
      if (h < 0 || l < 0) {
        break;
      }
      bytes.push(h * 16 + l);
      i += 3;
    }
    if (bytes.length === 0) {
      // 解析期已校验转义；防御：原样输出
      out += c;
      i++;
      continue;
    }
    out += utf8Decode(bytes);
  }
  return out;
}

/** URI.quote：ASCII 非 set 字符 → %XX；非 ASCII 的空白/控制字符 → UTF-8 %XX；其余原样。'%' 不在任何 set 中 → %25。 */
export function javaUriQuote(s: string, set: string): string {
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < 0x80) {
      if (!inCharSet(c, set)) {
        out += percentByte(c);
      } else {
        out += s.charAt(i);
      }
    } else if (isJavaSpaceChar(c) || isJavaIsoControl(c)) {
      const bytes = utf8Encode(s.charAt(i));
      for (let k = 0; k < bytes.length; k++) {
        out += percentByte(bytes[k]);
      }
    } else {
      out += s.charAt(i);
    }
  }
  return out;
}

export class JavaUri {
  /** 原始输入（URI.toString 对解析得到的 URI 返回原串） */
  private source: string = '';
  scheme: string | null = null;
  rawSchemeSpecificPart: string = '';
  rawAuthority: string | null = null;
  rawPath: string | null = null;
  rawQuery: string | null = null;
  rawFragment: string | null = null;
  opaque: boolean = false;

  /** java.net.URI(String)：非法抛 URISyntaxException。 */
  static parse(input: string): JavaUri {
    const u = new JavaUri();
    u.source = input;
    const n = input.length;
    let p = scan(input, 0, n, '/?#', ':');
    if (p >= 0 && p < n && input.charAt(p) === ':') {
      if (p === 0) {
        throw new URISyntaxException(input, 'Expected scheme name', 0);
      }
      if (!inCharSet(input.charCodeAt(0), CS_ALPHA)) {
        throw new URISyntaxException(input, 'Illegal character in scheme name', 0);
      }
      checkChars(input, 1, p, CS_SCHEME, false, 'scheme name');
      u.scheme = input.substring(0, p);
      p++;
      const sspStart = p;
      if (p < n && input.charAt(p) === '/') {
        p = JavaUri.parseHierarchical(u, input, p, n);
      } else {
        const q = scan(input, p, n, '', '#');
        if (q <= p) {
          throw new URISyntaxException(input, 'Expected scheme-specific part', p);
        }
        checkChars(input, p, q, CS_URIC, true, 'opaque part');
        u.opaque = true;
        p = q;
      }
      u.rawSchemeSpecificPart = input.substring(sspStart, p);
    } else {
      p = JavaUri.parseHierarchical(u, input, 0, n);
      u.rawSchemeSpecificPart = input.substring(0, p);
    }
    if (p < n && input.charAt(p) === '#') {
      checkChars(input, p + 1, n, CS_URIC, true, 'fragment');
      u.rawFragment = input.substring(p + 1, n);
      p = n;
    }
    if (p < n) {
      throw new URISyntaxException(input, 'Expected end of URI', p);
    }
    return u;
  }

  private static parseHierarchical(u: JavaUri, input: string, start: number, n: number): number {
    let p = start;
    if (p + 1 < n && input.charAt(p) === '/' && input.charAt(p + 1) === '/') {
      p += 2;
      const q = scan(input, p, n, '', '/?#');
      if (q > p) {
        JavaUri.parseAuthority(u, input, p, q);
        p = q;
      } else if (q < n) {
        // DEVIATION（Java 自身）：允许空 authority 后跟非空 path/query/fragment
      } else {
        throw new URISyntaxException(input, 'Expected authority', p);
      }
    }
    const q2 = scan(input, p, n, '', '?#');
    checkChars(input, p, q2, CS_PATH, true, 'path');
    u.rawPath = input.substring(p, q2);
    p = q2;
    if (p < n && input.charAt(p) === '?') {
      p++;
      const q3 = scan(input, p, n, '', '#');
      checkChars(input, p, q3, CS_URIC, true, 'query');
      u.rawQuery = input.substring(p, q3);
      p = q3;
    }
    return p;
  }

  private static parseAuthority(u: JavaUri, input: string, start: number, end: number): void {
    const auth = input.substring(start, end);
    const serverChars = allIn(auth, CS_SERVER, true);
    const regChars = allIn(auth, CS_REG_NAME, true);
    if (regChars && !serverChars) {
      u.rawAuthority = auth;
      return;
    }
    if (serverChars && isServerAuthority(auth)) {
      u.rawAuthority = auth;
      return;
    }
    if (regChars) {
      u.rawAuthority = auth;
      return;
    }
    const bad = firstIllegal(input, start, end, CS_SERVER, true);
    throw new URISyntaxException(input, 'Illegal character in authority', bad >= 0 ? bad : start);
  }

  isAbsolute(): boolean {
    return this.scheme !== null;
  }

  isOpaque(): boolean {
    return this.opaque;
  }

  getAuthority(): string | null {
    return javaUriDecode(this.rawAuthority, true);
  }

  getPath(): string | null {
    return javaUriDecode(this.rawPath, false);
  }

  getQuery(): string | null {
    return javaUriDecode(this.rawQuery, false);
  }

  getFragment(): string | null {
    return javaUriDecode(this.rawFragment, false);
  }

  toString(): string {
    return this.source;
  }

  /** URI.toURL()：非绝对 → IllegalArgumentException；否则 new URL(toString())（未知协议抛 MalformedURLException）。 */
  toURL(): JavaUrl {
    if (!this.isAbsolute()) {
      throw new IllegalArgumentException('URI is not absolute');
    }
    return JavaUrl.parse(this.toString());
  }

  /**
   * java.net.URI(scheme, authority, path, query, fragment) 五参构造器。
   * 逐位复刻引用规则（含 '%' → '%25'），随后与 Java 一样做 checkPath 与重新解析（失败抛 URISyntaxException）。
   */
  static create5(scheme: string | null, authority: string | null, path: string | null, query: string | null,
    fragment: string | null): JavaUri {
    let sb = '';
    if (scheme !== null) {
      sb += scheme + ':';
    }
    if (authority !== null) {
      sb += '//';
      const authQuoteSet = CS_REG_NAME + CS_SERVER;
      if (authority.startsWith('[')) {
        const end = authority.indexOf(']');
        let doquote = authority;
        let dontquote = '';
        if (end !== -1 && authority.indexOf(':') !== -1) {
          if (end === authority.length) {
            dontquote = authority;
            doquote = '';
          } else {
            dontquote = authority.substring(0, end + 1);
            doquote = authority.substring(end + 1);
          }
        }
        sb += dontquote + javaUriQuote(doquote, authQuoteSet);
      } else {
        sb += javaUriQuote(authority, authQuoteSet);
      }
    }
    if (path !== null) {
      sb += javaUriQuote(path, CS_PATH);
    }
    if (query !== null) {
      sb += '?' + javaUriQuote(query, CS_URIC);
    }
    if (fragment !== null) {
      sb += '#' + javaUriQuote(fragment, CS_URIC);
    }
    if (scheme !== null && path !== null && path.length > 0 && path.charAt(0) !== '/') {
      throw new URISyntaxException(sb, 'Relative path in absolute URI');
    }
    return JavaUri.parse(sb);
  }
}
