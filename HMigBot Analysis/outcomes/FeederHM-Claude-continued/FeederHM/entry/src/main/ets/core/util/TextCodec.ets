/**
 * TextCodec.ets —— 纯 ArkTS 文本/Base64 编解码（不依赖 util.TextEncoder / util.TextDecoder / util.Base64Helper）。
 *
 * 原因：本地单测（host Local Test）运行时里上述 @kit.ArkTS util API 是空桩（编码返回 0 字节、解码返回 ''、
 * Base64 返回 ''），导致依赖它们的核心逻辑（OPML 导入、Basic 认证、og:image、Feed 解码）在门里不可测。
 * UTF-8 / UTF-16 / ISO-8859-1 / Base64 自研实现与设备上行为一致（WHATWG 替换语义：非法序列 → U+FFFD）；
 * 其它字符集（gbk、windows-125x…）才交给设备 util.TextDecoder。
 */
import { util } from '@kit.ArkTS';

const UTF8_LABEL_SET: string[] = ['utf-8', 'utf8', 'unicode-1-1-utf-8'];
const LATIN1_LABEL_SET: string[] = ['iso-8859-1', 'iso8859-1', 'iso_8859-1', 'iso88591', 'latin1', 'l1', 'cp819',
  'ibm819', 'iso-ir-100', 'csisolatin1', 'iso_8859-1:1987'];
const ASCII_LABEL_SET: string[] = ['us-ascii', 'ascii', 'ansi_x3.4-1968'];

const B64: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/** 字符串 → UTF-8 字节（孤立代理项编码为 U+FFFD，同 WHATWG TextEncoder） */
export function encodeUtf8(s: string): Uint8Array {
  const out: Uint8Array = new Uint8Array(s.length * 3);
  let n: number = 0;
  let i: number = 0;
  while (i < s.length) {
    let c: number = s.charCodeAt(i);
    i++;
    if (c >= 0xd800 && c <= 0xdbff && i < s.length) {
      const d: number = s.charCodeAt(i);
      if (d >= 0xdc00 && d <= 0xdfff) {
        c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00);
        i++;
      } else {
        c = 0xfffd;
      }
    } else if (c >= 0xd800 && c <= 0xdfff) {
      c = 0xfffd;
    }
    if (c < 0x80) {
      out[n++] = c;
    } else if (c < 0x800) {
      out[n++] = 0xc0 | (c >> 6);
      out[n++] = 0x80 | (c & 0x3f);
    } else if (c < 0x10000) {
      out[n++] = 0xe0 | (c >> 12);
      out[n++] = 0x80 | ((c >> 6) & 0x3f);
      out[n++] = 0x80 | (c & 0x3f);
    } else {
      out[n++] = 0xf0 | (c >> 18);
      out[n++] = 0x80 | ((c >> 12) & 0x3f);
      out[n++] = 0x80 | ((c >> 6) & 0x3f);
      out[n++] = 0x80 | (c & 0x3f);
    }
  }
  return out.slice(0, n);
}

/** UTF-8 字符串 → 独立 ArrayBuffer */
export function encodeUtf8Buffer(s: string): ArrayBuffer {
  return encodeUtf8(s).buffer as ArrayBuffer;
}

class CodeUnitSink {
  private parts: string[] = [];
  private chunk: number[] = [];

  push(u: number): void {
    this.chunk.push(u);
    if (this.chunk.length >= 4096) {
      this.flush();
    }
  }

  pushCodePoint(cp: number): void {
    if (cp >= 0x10000) {
      const v: number = cp - 0x10000;
      this.push(0xd800 + (v >> 10));
      this.push(0xdc00 + (v & 0x3ff));
    } else {
      this.push(cp);
    }
  }

  private flush(): void {
    if (this.chunk.length > 0) {
      this.parts.push(String.fromCharCode(...this.chunk));
      this.chunk = [];
    }
  }

  toString(): string {
    this.flush();
    return this.parts.join('');
  }
}

/** UTF-8 字节 → 字符串（不剥 BOM；非法序列按 WHATWG"最大子部分"替换为 U+FFFD） */
export function decodeUtf8(bytes: Uint8Array): string {
  const sink: CodeUnitSink = new CodeUnitSink();
  const n: number = bytes.length;
  let i: number = 0;
  while (i < n) {
    const b0: number = bytes[i];
    if (b0 < 0x80) {
      sink.push(b0);
      i++;
      continue;
    }
    let need: number = 0;
    let cp: number = 0;
    let lo: number = 0x80;
    let hi: number = 0xbf;
    if (b0 >= 0xc2 && b0 <= 0xdf) {
      need = 1;
      cp = b0 & 0x1f;
    } else if (b0 >= 0xe0 && b0 <= 0xef) {
      need = 2;
      cp = b0 & 0x0f;
      if (b0 === 0xe0) {
        lo = 0xa0;
      } else if (b0 === 0xed) {
        hi = 0x9f;
      }
    } else if (b0 >= 0xf0 && b0 <= 0xf4) {
      need = 3;
      cp = b0 & 0x07;
      if (b0 === 0xf0) {
        lo = 0x90;
      } else if (b0 === 0xf4) {
        hi = 0x8f;
      }
    } else {
      sink.push(0xfffd);
      i++;
      continue;
    }
    let j: number = 1;
    let ok: boolean = true;
    while (j <= need) {
      if (i + j >= n) {
        ok = false;
        break;
      }
      const bj: number = bytes[i + j];
      const min: number = j === 1 ? lo : 0x80;
      const max: number = j === 1 ? hi : 0xbf;
      if (bj < min || bj > max) {
        ok = false;
        break;
      }
      cp = (cp << 6) | (bj & 0x3f);
      j++;
    }
    if (!ok) {
      sink.push(0xfffd);
      i += j;
      continue;
    }
    sink.pushCodePoint(cp);
    i += need + 1;
  }
  return sink.toString();
}

/** UTF-16 字节 → 字符串（不剥 BOM；奇数尾字节 → U+FFFD） */
export function decodeUtf16(bytes: Uint8Array, littleEndian: boolean): string {
  const sink: CodeUnitSink = new CodeUnitSink();
  const n: number = bytes.length - (bytes.length % 2);
  for (let i = 0; i < n; i += 2) {
    sink.push(littleEndian ? (bytes[i] | (bytes[i + 1] << 8)) : ((bytes[i] << 8) | bytes[i + 1]));
  }
  if (n < bytes.length) {
    sink.push(0xfffd);
  }
  return sink.toString();
}

/** ISO-8859-1 字节 → 字符串（逐字节映射 U+0000..U+00FF） */
export function decodeLatin1(bytes: Uint8Array): string {
  const sink: CodeUnitSink = new CodeUnitSink();
  for (let i = 0; i < bytes.length; i++) {
    sink.push(bytes[i]);
  }
  return sink.toString();
}

/** US-ASCII：>= 0x80 → U+FFFD */
function decodeAscii(bytes: Uint8Array): string {
  const sink: CodeUnitSink = new CodeUnitSink();
  for (let i = 0; i < bytes.length; i++) {
    sink.push(bytes[i] < 0x80 ? bytes[i] : 0xfffd);
  }
  return sink.toString();
}

/** 是否为本模块纯实现覆盖的字符集标签 */
export function isPureCharset(label: string): boolean {
  const l: string = label.trim().toLowerCase();
  return UTF8_LABEL_SET.indexOf(l) >= 0 || LATIN1_LABEL_SET.indexOf(l) >= 0 || ASCII_LABEL_SET.indexOf(l) >= 0 ||
    l === 'utf-16le' || l === 'utf-16be' || l === 'utf-16';
}

/**
 * 按字符集标签解码（不剥 BOM）。UTF-8/UTF-16/ISO-8859-1/ASCII 走纯实现；
 * 其它标签交给设备 util.TextDecoder，不支持（抛错）时回落 UTF-8。
 */
export function decodeCharset(bytes: Uint8Array, label: string): string {
  const l: string = label.trim().toLowerCase();
  if (l.length === 0 || UTF8_LABEL_SET.indexOf(l) >= 0) {
    return decodeUtf8(bytes);
  }
  if (l === 'utf-16le') {
    return decodeUtf16(bytes, true);
  }
  if (l === 'utf-16be' || l === 'utf-16') {
    return decodeUtf16(bytes, false);
  }
  if (LATIN1_LABEL_SET.indexOf(l) >= 0) {
    return decodeLatin1(bytes);
  }
  if (ASCII_LABEL_SET.indexOf(l) >= 0) {
    return decodeAscii(bytes);
  }
  try {
    return util.TextDecoder.create(l, { fatal: false, ignoreBOM: true }).decodeToString(bytes, { stream: false });
  } catch (e) {
    return decodeUtf8(bytes);
  }
}

/** 标准 Base64（RFC 4648，带 '=' 填充，无换行） */
export function base64Encode(bytes: Uint8Array): string {
  const parts: string[] = [];
  let i: number = 0;
  for (; i + 2 < bytes.length; i += 3) {
    const v: number = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    parts.push(B64.charAt((v >> 18) & 63) + B64.charAt((v >> 12) & 63) + B64.charAt((v >> 6) & 63) +
      B64.charAt(v & 63));
  }
  const rest: number = bytes.length - i;
  if (rest === 1) {
    const v: number = bytes[i] << 16;
    parts.push(B64.charAt((v >> 18) & 63) + B64.charAt((v >> 12) & 63) + '==');
  } else if (rest === 2) {
    const v: number = (bytes[i] << 16) | (bytes[i + 1] << 8);
    parts.push(B64.charAt((v >> 18) & 63) + B64.charAt((v >> 12) & 63) + B64.charAt((v >> 6) & 63) + '=');
  }
  return parts.join('');
}

/**
 * 标准 Base64 解码（Go base64.StdEncoding 语义：长度须为 4 的倍数、填充只在末尾、
 * 非 Strict 模式不校验尾部未用比特）；非法返回 null。调用方自行去除允许忽略的字符（如 \r \n）。
 */
export function base64DecodeStrict(s: string): Uint8Array | null {
  if (s.length % 4 !== 0) {
    return null;
  }
  let pad: number = 0;
  if (s.endsWith('==')) {
    pad = 2;
  } else if (s.endsWith('=')) {
    pad = 1;
  }
  const out: Uint8Array = new Uint8Array(s.length / 4 * 3);
  let n: number = 0;
  for (let i = 0; i < s.length; i += 4) {
    const last: boolean = i + 4 === s.length;
    const v: number[] = [0, 0, 0, 0];
    for (let k = 0; k < 4; k++) {
      const ch: string = s.charAt(i + k);
      if (ch === '=' && last && k >= 4 - pad) {
        v[k] = 0;
        continue;
      }
      const idx: number = B64.indexOf(ch);
      if (idx < 0) {
        return null;
      }
      v[k] = idx;
    }
    const triple: number = (v[0] << 18) | (v[1] << 12) | (v[2] << 6) | v[3];
    out[n++] = (triple >> 16) & 0xff;
    if (!(last && pad === 2)) {
      out[n++] = (triple >> 8) & 0xff;
    }
    if (!(last && pad >= 1)) {
      out[n++] = triple & 0xff;
    }
  }
  return out.slice(0, n);
}
