/**
 * JavaUrl.ets —— java.net.URL 的解析/规整语义逐位复刻（Android libcore = OpenJDK URL + URLStreamHandler.parseURL）。
 *  - JavaUrl.parse(spec) ≙ new URL(spec)；JavaUrl.parse(spec, context) ≙ new URL(context, spec)
 *  - 协议白名单 = Android 内置 handler：http / https / ftp / file / jar；其他协议抛 MalformedURLException("unknown protocol: x")
 *  - 无协议抛 MalformedURLException("no protocol: ...")；端口非法等 IllegalArgument 一律包装为 MalformedURLException
 *  - toString() ≙ URL.toExternalForm()；equals/javaHashCode 按 Android（不做 DNS，主机名忽略大小写比较）
 */
import { MalformedURLException, isIPv6Literal } from './JavaCodec';
import { javaStringHashCode } from './JavaHash';

const KNOWN_PROTOCOLS: string[] = ['http', 'https', 'ftp', 'file', 'jar'];

/** Character.isLetter 近似：ASCII 字母，或有大小写区分的非 ASCII 字符 */
function isLetterChar(ch: string): boolean {
  const c = ch.charCodeAt(0);
  if ((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a)) {
    return true;
  }
  return c >= 0x80 && ch.toLowerCase() !== ch.toUpperCase();
}

/** URL.isValidProtocol：首字符字母，其余字母/数字/'.'/'+'/'-' */
function isValidProtocol(protocol: string): boolean {
  if (protocol.length < 1) {
    return false;
  }
  if (!isLetterChar(protocol.charAt(0))) {
    return false;
  }
  for (let i = 1; i < protocol.length; i++) {
    const ch = protocol.charAt(i);
    const c = protocol.charCodeAt(i);
    if (!isLetterChar(ch) && !(c >= 0x30 && c <= 0x39) && ch !== '.' && ch !== '+' && ch !== '-') {
      return false;
    }
  }
  return true;
}

/** Integer.parseInt(s, 10)：允许前导 +/-，仅 ASCII 数字，int 溢出失败。失败抛 MalformedURLException。 */
function parseJavaInt(s: string): number {
  const re = new RegExp('^[+-]?[0-9]+$');
  if (!re.test(s)) {
    throw new MalformedURLException('For input string: "' + s + '"');
  }
  const v = Number(s);
  if (v > 2147483647 || v < -2147483648) {
    throw new MalformedURLException('For input string: "' + s + '"');
  }
  return v;
}

function defaultPortOf(protocol: string): number {
  if (protocol === 'http') {
    return 80;
  }
  if (protocol === 'https') {
    return 443;
  }
  if (protocol === 'ftp') {
    return 21;
  }
  return -1;
}

/** String.lastIndexOf(ch, fromIndex)，fromIndex < 0 返回 -1（与 Java 一致）。 */
function lastIndexFrom(s: string, ch: string, fromIndex: number): number {
  if (fromIndex < 0) {
    return -1;
  }
  return s.lastIndexOf(ch, fromIndex);
}

export class JavaUrl {
  protocol: string = '';
  host: string = '';
  port: number = -1;
  authority: string | null = null;
  userInfo: string | null = null;
  path: string = '';
  query: string | null = null;
  ref: string | null = null;

  /** URL.getFile() = path + ("?" + query) */
  get file(): string {
    return this.query !== null ? this.path + '?' + this.query : this.path;
  }

  getDefaultPort(): number {
    return defaultPortOf(this.protocol);
  }

  /** port 未指定时取默认端口 */
  getEffectivePort(): number {
    return this.port === -1 ? this.getDefaultPort() : this.port;
  }

  /** URLStreamHandler.toExternalForm */
  toString(): string {
    let s = this.protocol + ':';
    if (this.authority !== null && this.authority.length > 0) {
      s += '//' + this.authority;
    }
    s += this.path;
    if (this.query !== null) {
      s += '?' + this.query;
    }
    if (this.ref !== null) {
      s += '#' + this.ref;
    }
    return s;
  }

  /** URL.equals（Android：不解析 DNS，主机名忽略大小写） */
  equals(other: JavaUrl | null): boolean {
    if (other === null) {
      return false;
    }
    if (this.ref !== other.ref) {
      return false;
    }
    return this.sameFile(other);
  }

  sameFile(other: JavaUrl): boolean {
    if (this.protocol.toLowerCase() !== other.protocol.toLowerCase()) {
      return false;
    }
    if (this.file !== other.file) {
      return false;
    }
    if (this.getEffectivePort() !== other.getEffectivePort()) {
      return false;
    }
    return this.host.toLowerCase() === other.host.toLowerCase();
  }

  /** URL.hashCode（Android 变体：主机名小写 hashCode，不做 DNS）。未在设备上与 Android 对拍。 */
  javaHashCode(): number {
    let h = 0;
    h = (h + javaStringHashCode(this.protocol)) | 0;
    h = (h + javaStringHashCode(this.host.toLowerCase())) | 0;
    h = (h + javaStringHashCode(this.file)) | 0;
    h = (h + this.getEffectivePort()) | 0;
    if (this.ref !== null) {
      h = (h + javaStringHashCode(this.ref)) | 0;
    }
    return h;
  }

  /** new URL(spec) / new URL(context, spec) */
  static parse(spec: string, context: JavaUrl | null = null): JavaUrl {
    const original = spec;
    let limit = spec.length;
    while (limit > 0 && spec.charCodeAt(limit - 1) <= 0x20) {
      limit--;
    }
    let start = 0;
    while (start < limit && spec.charCodeAt(start) <= 0x20) {
      start++;
    }
    if (spec.substring(start, start + 4).toLowerCase() === 'url:') {
      start += 4;
    }
    const aRef = start < spec.length && spec.charAt(start) === '#';
    let newProtocol: string | null = null;
    if (!aRef) {
      for (let i = start; i < limit; i++) {
        const c = spec.charAt(i);
        if (c === '/') {
          break;
        }
        if (c === ':') {
          const s = spec.substring(start, i).toLowerCase();
          if (isValidProtocol(s)) {
            newProtocol = s;
            start = i + 1;
          }
          break;
        }
      }
    }

    const u = new JavaUrl();
    let protocol: string | null = newProtocol;
    let isRelative = false;
    if (context !== null && (newProtocol === null || newProtocol === context.protocol.toLowerCase())) {
      // 层级 scheme 且 spec 带相同 scheme：按 RFC2396 5.2.3 当作无 scheme 处理
      if (context.path.startsWith('/')) {
        newProtocol = null;
      }
      if (newProtocol === null) {
        protocol = context.protocol;
        u.authority = context.authority;
        u.userInfo = context.userInfo;
        u.host = context.host;
        u.port = context.port;
        u.path = context.path;
        isRelative = true;
      }
    }
    if (protocol === null) {
      throw new MalformedURLException('no protocol: ' + original);
    }
    if (KNOWN_PROTOCOLS.indexOf(protocol) < 0) {
      throw new MalformedURLException('unknown protocol: ' + protocol);
    }
    u.protocol = protocol;

    const hashIdx = spec.indexOf('#', start);
    if (hashIdx >= 0) {
      u.ref = spec.substring(hashIdx + 1, limit);
      limit = hashIdx;
    }
    if (isRelative && start === limit && context !== null) {
      u.query = context.query;
      if (u.ref === null) {
        u.ref = context.ref;
      }
    }
    if (protocol === 'jar') {
      JavaUrl.parseJar(u, spec, start, limit, isRelative);
    } else {
      JavaUrl.parseUrl(u, spec, start, limit, isRelative);
    }
    return u;
  }

  /** sun.net.www.protocol.jar.Handler 的简化：绝对 jar URL 必须含 "!/" 且内层 URL 合法。 */
  private static parseJar(u: JavaUrl, spec: string, start: number, limit: number, isRelative: boolean): void {
    const body = spec.substring(start, limit);
    if (!isRelative) {
      const bang = body.indexOf('!/');
      if (bang < 0) {
        throw new MalformedURLException('no !/ in spec');
      }
      JavaUrl.parse(body.substring(0, bang));
      u.authority = null;
      u.host = '';
      u.port = -1;
      u.userInfo = null;
      u.path = body;
      u.query = null;
      return;
    }
    JavaUrl.parseUrl(u, spec, start, limit, isRelative);
  }

  /** 首个 ASCII 控制字符（0x00-0x1F、0x7F）或 extra 中字符的位置；无则 -1 */
  private static firstIllegal(s: string, extra: string): number {
    for (let i = 0; i < s.length; i++) {
      const c = s.charCodeAt(i);
      if (c < 0x20 || c === 0x7f || extra.indexOf(s.charAt(i)) >= 0) {
        return i;
      }
    }
    return -1;
  }

  /** URLStreamHandler.parseURL（OpenJDK/Android libcore） */
  private static parseUrl(u: JavaUrl, specIn: string, startIn: number, limitIn: number, hasContext: boolean): void {
    let spec = specIn;
    let start = startIn;
    let limit = limitIn;
    let authority: string | null = u.authority;
    let userInfo: string | null = u.userInfo;
    let host: string | null = u.host;
    let port = u.port;
    let path: string | null = hasContext ? u.path : null;
    let query: string | null = u.query;
    let isRelPath = false;
    let queryOnly = false;

    if (start < limit) {
      const queryStart = spec.indexOf('?');
      queryOnly = queryStart === start;
      if (queryStart !== -1 && queryStart < limit) {
        query = spec.substring(queryStart + 1, limit);
        if (limit > queryStart) {
          limit = queryStart;
        }
        spec = spec.substring(0, queryStart);
      }
    }

    let i = 0;
    const isUNCName = (start <= limit - 4) && spec.charAt(start) === '/' && spec.charAt(start + 1) === '/' &&
      spec.charAt(start + 2) === '/' && spec.charAt(start + 3) === '/';
    if (!isUNCName && (start <= limit - 2) && spec.charAt(start) === '/' && spec.charAt(start + 1) === '/') {
      start += 2;
      i = spec.indexOf('/', start);
      if (i < 0 || i > limit) {
        i = spec.indexOf('?', start);
        if (i < 0 || i > limit) {
          i = limit;
        }
      }
      authority = spec.substring(start, i);
      host = authority;
      let ind = authority.indexOf('@');
      if (ind !== -1) {
        if (ind !== authority.lastIndexOf('@')) {
          userInfo = null;
          host = null;
        } else {
          userInfo = authority.substring(0, ind);
          host = authority.substring(ind + 1);
        }
      } else {
        userInfo = null;
      }
      if (host !== null) {
        if (host.length > 0 && host.charAt(0) === '[') {
          ind = host.indexOf(']');
          if (ind > 2) {
            const nhost = host;
            host = nhost.substring(0, ind + 1);
            if (!isIPv6Literal(host.substring(1, ind))) {
              throw new MalformedURLException('Invalid host: ' + host);
            }
            port = -1;
            if (nhost.length > ind + 1) {
              if (nhost.charAt(ind + 1) === ':') {
                ++ind;
                if (nhost.length > ind + 1) {
                  port = parseJavaInt(nhost.substring(ind + 1));
                }
              } else {
                throw new MalformedURLException('Invalid authority field: ' + authority);
              }
            }
          } else {
            throw new MalformedURLException('Invalid authority field: ' + authority);
          }
        } else {
          ind = host.indexOf(':');
          port = -1;
          if (ind >= 0) {
            if (host.length > ind + 1) {
              port = parseJavaInt(host.substring(ind + 1));
            }
            host = host.substring(0, ind);
          }
        }
      } else {
        host = '';
      }
      if (port < -1) {
        throw new MalformedURLException('Invalid port number :' + port);
      }
      start = i;
      if (authority !== null && authority.length > 0) {
        path = '';
      }
    }

    if (host === null) {
      host = '';
    }

    if (start < limit) {
      if (spec.charAt(start) === '/') {
        path = spec.substring(start, limit);
      } else if (path !== null && path.length > 0) {
        isRelPath = true;
        const ind = path.lastIndexOf('/');
        let separator = '';
        if (ind === -1 && authority !== null) {
          separator = '/';
        }
        path = path.substring(0, ind + 1) + separator + spec.substring(start, limit);
      } else {
        const tail = spec.substring(start, limit);
        path = authority !== null ? '/' + tail : tail;
      }
    } else if (queryOnly && path !== null) {
      let ind = path.lastIndexOf('/');
      if (ind < 0) {
        ind = 0;
      }
      path = path.substring(0, ind) + '/';
    }
    if (path === null) {
      path = '';
    }

    if (isRelPath) {
      let p: string = path;
      // 去掉内嵌 /./
      let k = p.indexOf('/./');
      while (k >= 0) {
        p = p.substring(0, k) + p.substring(k + 2);
        k = p.indexOf('/./');
      }
      // 尽可能消去内嵌 /../
      k = 0;
      k = p.indexOf('/../', k);
      while (k >= 0) {
        const lim = lastIndexFrom(p, '/', k - 1);
        if (k > 0 && lim >= 0 && p.indexOf('/../', lim) !== 0) {
          p = p.substring(0, lim) + p.substring(k + 3);
          k = 0;
        } else {
          k = k + 3;
        }
        k = p.indexOf('/../', k);
      }
      // 尽可能消去结尾 ..
      while (p.endsWith('/..')) {
        const k2 = p.indexOf('/..');
        const lim2 = lastIndexFrom(p, '/', k2 - 1);
        if (lim2 >= 0) {
          p = p.substring(0, lim2 + 1);
        } else {
          break;
        }
      }
      if (p.startsWith('./') && p.length > 2) {
        p = p.substring(2);
      }
      if (p.endsWith('/.')) {
        p = p.substring(0, p.length - 1);
      }
      path = p;
    }

    // JDK IPAddressUtil.checkAuthority：host 拒绝控制字符与 ` "<>\^`{|}`，userInfo 拒绝控制字符与 '\'
    if (userInfo !== null && JavaUrl.firstIllegal(userInfo, '\\') >= 0) {
      throw new MalformedURLException('Illegal character found in user-info: ' + userInfo);
    }
    if (JavaUrl.firstIllegal(host, ' "<>\\^`{|}') >= 0) {
      throw new MalformedURLException('Illegal character found in host: ' + host);
    }

    u.authority = authority;
    u.userInfo = userInfo;
    u.host = host;
    u.port = port;
    u.path = path;
    u.query = query;
  }
}
