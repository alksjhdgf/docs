/**
 * JavaCodec.ets —— Java 兼容层的底层部件（纯逻辑）：
 *  - Java 异常等价类（MalformedURLException / URISyntaxException / IllegalArgumentException / DateTimeParseException）
 *  - UTF-8 编解码（与 Java String.getBytes / new String(bytes) 的替换语义对齐：坏输入 → '?' / U+FFFD）
 *  - java.net.URLEncoder.encode(s, "UTF-8") / java.net.URLDecoder.decode(s, "UTF-8") 逐位复刻
 *  - java.net.URI 使用的 RFC2396 字符类判定
 * 对外统一经 JavaCompat.ets 再导出。
 */

export class MalformedURLException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MalformedURLException';
  }
}

export class URISyntaxException extends Error {
  input: string;
  reason: string;
  index: number;

  constructor(input: string, reason: string, index: number = -1) {
    super(reason + (index > -1 ? ' at index ' + index : '') + ': ' + input);
    this.name = 'URISyntaxException';
    this.input = input;
    this.reason = reason;
    this.index = index;
  }
}

export class IllegalArgumentException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IllegalArgumentException';
  }
}

export class DateTimeParseException extends Error {
  parsedString: string;

  constructor(message: string, parsedString: string) {
    super(message);
    this.name = 'DateTimeParseException';
    this.parsedString = parsedString;
  }
}

const HEX_UPPER: string = '0123456789ABCDEF';

/** 0..15，非十六进制返回 -1（仅 ASCII，等价 Character.digit(c,16) 的 ASCII 子集）。 */
export function hexDigitValue(c: number): number {
  if (c >= 0x30 && c <= 0x39) {
    return c - 0x30;
  }
  if (c >= 0x41 && c <= 0x46) {
    return c - 0x41 + 10;
  }
  if (c >= 0x61 && c <= 0x66) {
    return c - 0x61 + 10;
  }
  return -1;
}

export function percentByte(b: number): string {
  return '%' + HEX_UPPER.charAt((b >> 4) & 0x0f) + HEX_UPPER.charAt(b & 0x0f);
}

/**
 * UTF-16 字符串 → UTF-8 字节。孤立代理项按 Java 编码器 REPLACE 语义写 '?'(0x3F)。
 */
export function utf8Encode(s: string): number[] {
  const out: number[] = [];
  let i = 0;
  while (i < s.length) {
    const c = s.charCodeAt(i);
    if (c < 0x80) {
      out.push(c);
      i++;
    } else if (c < 0x800) {
      out.push(0xc0 | (c >> 6));
      out.push(0x80 | (c & 0x3f));
      i++;
    } else if (c >= 0xd800 && c <= 0xdbff) {
      const d = i + 1 < s.length ? s.charCodeAt(i + 1) : -1;
      if (d >= 0xdc00 && d <= 0xdfff) {
        const cp = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00);
        out.push(0xf0 | (cp >> 18));
        out.push(0x80 | ((cp >> 12) & 0x3f));
        out.push(0x80 | ((cp >> 6) & 0x3f));
        out.push(0x80 | (cp & 0x3f));
        i += 2;
      } else {
        out.push(0x3f);
        i++;
      }
    } else if (c >= 0xdc00 && c <= 0xdfff) {
      out.push(0x3f);
      i++;
    } else {
      out.push(0xe0 | (c >> 12));
      out.push(0x80 | ((c >> 6) & 0x3f));
      out.push(0x80 | (c & 0x3f));
      i++;
    }
  }
  return out;
}

/**
 * UTF-8 字节 → UTF-16 字符串。非法序列每个坏片段替换为 U+FFFD（Java 解码器 REPLACE 语义的近似）。
 */
export function utf8Decode(bytes: number[]): string {
  let out = '';
  let i = 0;
  const n = bytes.length;
  while (i < n) {
    const b0 = bytes[i] & 0xff;
    if (b0 < 0x80) {
      out += String.fromCharCode(b0);
      i++;
      continue;
    }
    let need = 0;
    let cp = 0;
    let min = 0;
    if (b0 >= 0xc2 && b0 <= 0xdf) {
      need = 1;
      cp = b0 & 0x1f;
      min = 0x80;
    } else if (b0 >= 0xe0 && b0 <= 0xef) {
      need = 2;
      cp = b0 & 0x0f;
      min = 0x800;
    } else if (b0 >= 0xf0 && b0 <= 0xf4) {
      need = 3;
      cp = b0 & 0x07;
      min = 0x10000;
    } else {
      out += '�';
      i++;
      continue;
    }
    let j = 1;
    let ok = true;
    while (j <= need) {
      if (i + j >= n) {
        ok = false;
        break;
      }
      const bj = bytes[i + j] & 0xff;
      if ((bj & 0xc0) !== 0x80) {
        ok = false;
        break;
      }
      cp = (cp << 6) | (bj & 0x3f);
      j++;
    }
    if (!ok || cp < min || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) {
      out += '�';
      // 跳过首字节与已确认的续字节
      i += ok ? need + 1 : j;
      continue;
    }
    out += String.fromCodePoint(cp);
    i += need + 1;
  }
  return out;
}

/**
 * java.net.URLEncoder.encode(s, "UTF-8")：
 * a-z A-Z 0-9 . - * _ 原样；空格 → '+'；其余按 UTF-8 字节 %XX（大写十六进制）。
 */
export function javaUrlEncode(s: string): string {
  let out = '';
  let i = 0;
  while (i < s.length) {
    const c = s.charCodeAt(i);
    if ((c >= 0x61 && c <= 0x7a) || (c >= 0x41 && c <= 0x5a) || (c >= 0x30 && c <= 0x39) ||
      c === 0x2e || c === 0x2d || c === 0x2a || c === 0x5f) {
      out += String.fromCharCode(c);
      i++;
      continue;
    }
    if (c === 0x20) {
      out += '+';
      i++;
      continue;
    }
    // 收集连续需要编码的字符（与 Java 一样整段转字节，保证代理对成对编码）
    let j = i;
    while (j < s.length) {
      const d = s.charCodeAt(j);
      if ((d >= 0x61 && d <= 0x7a) || (d >= 0x41 && d <= 0x5a) || (d >= 0x30 && d <= 0x39) ||
        d === 0x2e || d === 0x2d || d === 0x2a || d === 0x5f || d === 0x20) {
        break;
      }
      j++;
    }
    const bytes = utf8Encode(s.substring(i, j));
    for (let k = 0; k < bytes.length; k++) {
      out += percentByte(bytes[k]);
    }
    i = j;
  }
  return out;
}

/** Integer.parseInt(s, i, i+2, 16) 的语义（允许前导 +/-），非法返回 null。 */
function parseHex2(s: string, i: number): number | null {
  const c0 = s.charCodeAt(i);
  const c1 = s.charCodeAt(i + 1);
  if (c0 === 0x2b || c0 === 0x2d) {
    const v = hexDigitValue(c1);
    if (v < 0) {
      return null;
    }
    return c0 === 0x2d ? -v : v;
  }
  const h = hexDigitValue(c0);
  const l = hexDigitValue(c1);
  if (h < 0 || l < 0) {
    return null;
  }
  return h * 16 + l;
}

/**
 * java.net.URLDecoder.decode(s, "UTF-8")：'+' → 空格；连续 %XX 作为 UTF-8 字节解码；
 * 非法十六进制 / 不完整的尾部 % → 抛 IllegalArgumentException（与 Java 相同，调用方未捕获时会传播）。
 */
export function javaUrlDecode(s: string): string {
  const numChars = s.length;
  let out = '';
  let i = 0;
  while (i < numChars) {
    let c = s.charCodeAt(i);
    if (c === 0x2b) {
      out += ' ';
      i++;
    } else if (c === 0x25) {
      const bytes: number[] = [];
      while ((i + 2) < numChars && c === 0x25) {
        const v = parseHex2(s, i + 1);
        if (v === null) {
          throw new IllegalArgumentException('URLDecoder: Illegal hex characters in escape (%) pattern - ' +
            'Error at index 0 in: "' + s.substring(i + 1, i + 3) + '"');
        }
        if (v < 0) {
          throw new IllegalArgumentException(
            'URLDecoder: Illegal hex characters in escape (%) pattern - negative value');
        }
        bytes.push(v);
        i += 3;
        if (i < numChars) {
          c = s.charCodeAt(i);
        }
      }
      if (i < numChars && c === 0x25) {
        throw new IllegalArgumentException('URLDecoder: Incomplete trailing escape (%) pattern');
      }
      out += utf8Decode(bytes);
    } else {
      out += s.charAt(i);
      i++;
    }
  }
  return out;
}

// ---------------- RFC2396 字符类（java.net.URI 的 L_/H_ 掩码等价） ----------------

const ALNUM: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const MARK: string = '-_.!~*\'()';
export const CS_ALPHA: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
export const CS_SCHEME: string = ALNUM + '+-.';
export const CS_UNRESERVED: string = ALNUM + MARK;
export const CS_RESERVED: string = ';/?:@&=+$,[]';
export const CS_URIC: string = CS_RESERVED + CS_UNRESERVED;
export const CS_PCHAR: string = CS_UNRESERVED + ':@&=+$,';
export const CS_PATH: string = CS_PCHAR + ';/';
export const CS_REG_NAME: string = CS_UNRESERVED + '$,;:@&=+';
export const CS_USERINFO: string = CS_UNRESERVED + ';:&=+$,';
export const CS_SERVER: string = CS_USERINFO + ALNUM + '-.:@[]';

/** Character.isSpaceChar（Unicode Zs/Zl/Zp，UTF-16 码元级；显式列表，避免依赖 \\p{} 正则支持）。 */
export function isJavaSpaceChar(c: number): boolean {
  return c === 0x20 || c === 0xa0 || c === 0x1680 || (c >= 0x2000 && c <= 0x200a) || c === 0x2028 ||
    c === 0x2029 || c === 0x202f || c === 0x205f || c === 0x3000;
}

/** Character.isISOControl。 */
export function isJavaIsoControl(c: number): boolean {
  return (c >= 0 && c <= 0x1f) || (c >= 0x7f && c <= 0x9f);
}

/** java.net.URI 的 "other" 类：非 ASCII、非空白、非控制字符。 */
export function isUriOther(c: number): boolean {
  return c >= 0x80 && !isJavaSpaceChar(c) && !isJavaIsoControl(c);
}

export function inCharSet(c: number, set: string): boolean {
  return c > 0 && c < 0x80 && set.indexOf(String.fromCharCode(c)) >= 0;
}

/** IPv6 字面量（不含方括号）的宽松校验：hex 组、至多一个 '::'、可选尾部 IPv4、可选 %scope。 */
export function isIPv6Literal(addr: string): boolean {
  let a = addr;
  const pct = a.indexOf('%');
  if (pct >= 0) {
    a = a.substring(0, pct);
  }
  if (a.length < 2) {
    return false;
  }
  const re = new RegExp('^[0-9A-Fa-f:.]+$');
  if (!re.test(a)) {
    return false;
  }
  const dbl = a.indexOf('::');
  if (dbl >= 0 && a.indexOf('::', dbl + 1) >= 0) {
    return false;
  }
  const parts = a.split(':');
  let groups = 0;
  for (let i = 0; i < parts.length; i++) {
    const g = parts[i];
    if (g.length === 0) {
      continue;
    }
    if (g.indexOf('.') >= 0) {
      if (i !== parts.length - 1) {
        return false;
      }
      const v4 = new RegExp('^(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})$');
      const m = v4.exec(g);
      if (m === null) {
        return false;
      }
      for (let k = 1; k <= 4; k++) {
        if (Number(m[k]) > 255) {
          return false;
        }
      }
      groups += 2;
      continue;
    }
    if (g.length > 4) {
      return false;
    }
    groups++;
  }
  if (dbl >= 0) {
    return groups < 8;
  }
  return groups === 8;
}
