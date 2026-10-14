/*
 * TranslationIo — 翻译域的 SHA-256 与文件小工具。
 * 源：TranslationManager.kt sha256(String)（MessageDigest SHA-256 → 小写 hex）、
 *     BergamotModelManager.kt sha256(File)、File.isFile/readText/writeText/deleteRecursively/walkTopDown。
 * 字符串哈希为纯 ArkTS 实现（主机 Local Test 同效）；文件哈希优先 cryptoFramework（设备原生），失败回落纯实现，
 * 并按 (路径, 大小, mtime) 记忆，避免列表逐卡重复读 50MB 模型（文件变化即 size/mtime 变化，语义不变）。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { encodeUtf8, decodeUtf8 } from '../../core/util/TextCodec';

const SHA256_K: number[] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

/** 增量 SHA-256（纯 ArkTS） */
export class Sha256 {
  private h: Int32Array = new Int32Array([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ]);
  private block: Uint8Array = new Uint8Array(64);
  private blockLen: number = 0;
  private total: number = 0;
  private w: Int32Array = new Int32Array(64);

  update(data: Uint8Array): Sha256 {
    let i = 0;
    this.total += data.length;
    while (i < data.length) {
      const take = Math.min(64 - this.blockLen, data.length - i);
      this.block.set(data.subarray(i, i + take), this.blockLen);
      this.blockLen += take;
      i += take;
      if (this.blockLen === 64) {
        this.compress();
        this.blockLen = 0;
      }
    }
    return this;
  }

  digestHex(): string {
    const bitLenHi = Math.floor(this.total / 0x20000000);
    const bitLenLo = (this.total * 8) >>> 0;
    const pad = new Uint8Array(((this.blockLen < 56) ? 56 : 120) - this.blockLen + 8);
    pad[0] = 0x80;
    const n = pad.length;
    pad[n - 8] = (bitLenHi >>> 24) & 0xff;
    pad[n - 7] = (bitLenHi >>> 16) & 0xff;
    pad[n - 6] = (bitLenHi >>> 8) & 0xff;
    pad[n - 5] = bitLenHi & 0xff;
    pad[n - 4] = (bitLenLo >>> 24) & 0xff;
    pad[n - 3] = (bitLenLo >>> 16) & 0xff;
    pad[n - 2] = (bitLenLo >>> 8) & 0xff;
    pad[n - 1] = bitLenLo & 0xff;
    const savedTotal = this.total;
    this.update(pad);
    this.total = savedTotal;
    let out = '';
    for (let k = 0; k < 8; k++) {
      out += ((this.h[k] >>> 0).toString(16)).padStart(8, '0');
    }
    return out;
  }

  private compress(): void {
    const w = this.w;
    const b = this.block;
    for (let t = 0; t < 16; t++) {
      w[t] = (b[t * 4] << 24) | (b[t * 4 + 1] << 16) | (b[t * 4 + 2] << 8) | b[t * 4 + 3];
    }
    for (let t = 16; t < 64; t++) {
      const x = w[t - 15];
      const y = w[t - 2];
      const s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3);
      const s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
    }
    let a = this.h[0];
    let bb = this.h[1];
    let c = this.h[2];
    let d = this.h[3];
    let e = this.h[4];
    let f = this.h[5];
    let g = this.h[6];
    let hh = this.h[7];
    for (let t = 0; t < 64; t++) {
      const S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7));
      const ch = (e & f) ^ (~e & g);
      const t1 = (hh + S1 + ch + SHA256_K[t] + w[t]) | 0;
      const S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10));
      const maj = (a & bb) ^ (a & c) ^ (bb & c);
      const t2 = (S0 + maj) | 0;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) | 0;
      d = c;
      c = bb;
      bb = a;
      a = (t1 + t2) | 0;
    }
    this.h[0] = (this.h[0] + a) | 0;
    this.h[1] = (this.h[1] + bb) | 0;
    this.h[2] = (this.h[2] + c) | 0;
    this.h[3] = (this.h[3] + d) | 0;
    this.h[4] = (this.h[4] + e) | 0;
    this.h[5] = (this.h[5] + f) | 0;
    this.h[6] = (this.h[6] + g) | 0;
    this.h[7] = (this.h[7] + hh) | 0;
  }
}

/** 源 TranslationManager.sha256(value)：UTF-8 字节的 SHA-256 小写 hex */
export function sha256OfString(value: string): string {
  return new Sha256().update(encodeUtf8(value)).digestHex();
}

export function sha256OfBytes(bytes: Uint8Array): string {
  return new Sha256().update(bytes).digestHex();
}

function bytesToHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, '0');
  }
  return out;
}

class FileHashMemo {
  size: number = 0;
  mtime: number = 0;
  hash: string = '';
}

const fileHashMemo: Map<string, FileHashMemo> = new Map<string, FileHashMemo>();
const HASH_BUFFER_SIZE: number = 1024 * 1024;

function hashFileNative(path: string): string {
  // 同步文件 IO 自带保护：失败返回空串（调用方按读失败处理）
  try {
    const md = cryptoFramework.createMd('SHA256');
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const buf = new ArrayBuffer(HASH_BUFFER_SIZE);
      while (true) {
        const read = fs.readSync(file.fd, buf);
        if (read <= 0) {
          break;
        }
        const blob: cryptoFramework.DataBlob = { data: new Uint8Array(buf, 0, read) };
        md.updateSync(blob);
      }
    } finally {
      fs.closeSync(file);
    }
    return bytesToHex(md.digestSync().data);
  } catch (e) {
    return '';
  }
}

function hashFilePure(path: string): string {
  // 同步文件 IO 自带保护：失败返回空串（调用方按读失败处理）
  try {
    const sha = new Sha256();
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const buf = new ArrayBuffer(HASH_BUFFER_SIZE);
      while (true) {
        const read = fs.readSync(file.fd, buf);
        if (read <= 0) {
          break;
        }
        sha.update(new Uint8Array(buf, 0, read));
      }
    } finally {
      fs.closeSync(file);
    }
    return sha.digestHex();
  
  } catch (e) {
    return '';
  }
}

/** 源 BergamotModelManager.sha256(File)；文件不存在/读失败返回空串 */
export function sha256OfFile(path: string): string {
  try {
    const st = fs.statSync(path);
    if (!st.isFile()) {
      return '';
    }
    const memo = fileHashMemo.get(path);
    if (memo !== undefined && memo.size === st.size && memo.mtime === st.mtime) {
      return memo.hash;
    }
    let hash = '';
    hash = hashFileNative(path);
    if (hash.length === 0) {
      hash = hashFilePure(path);
    }
    const m = new FileHashMemo();
    m.size = st.size;
    m.mtime = st.mtime;
    m.hash = hash;
    fileHashMemo.set(path, m);
    return hash;
  } catch (e) {
    return '';
  }
}

export function forgetFileHash(path: string): void {
  fileHashMemo.delete(path);
}

// ------------------------------------------------------------------ 文件小工具（java.io.File 语义）

export function joinPath(dir: string, name: string): string {
  return dir.endsWith('/') ? `${dir}${name}` : `${dir}/${name}`;
}

export function isFile(path: string): boolean {
  try {
    return fs.accessSync(path) && fs.statSync(path).isFile();
  } catch (e) {
    return false;
  }
}

export function isDirectory(path: string): boolean {
  try {
    return fs.accessSync(path) && fs.statSync(path).isDirectory();
  } catch (e) {
    return false;
  }
}

/** File.lastModified()（epoch ms；不存在为 0） */
export function lastModifiedMs(path: string): number {
  try {
    return fs.statSync(path).mtime * 1000;
  } catch (e) {
    return 0;
  }
}

export function fileLength(path: string): number {
  try {
    return fs.statSync(path).size;
  } catch (e) {
    return 0;
  }
}

export function mkdirs(dir: string): void {
  try {
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
  } catch (e) {
    console.warn(`TranslationIo: mkdirs ${dir} failed: ${(e as Error)?.message}`);
  }
}

export function parentDir(path: string): string {
  const i = path.lastIndexOf('/');
  return i > 0 ? path.substring(0, i) : '/';
}

export function readTextOrNull(path: string): string | null {
  if (!isFile(path)) {
    return null;
  }
  try {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const size = fs.statSync(path).size;
      const out = new Uint8Array(size);
      let off = 0;
      while (off < size) {
        const chunk = new ArrayBuffer(Math.min(HASH_BUFFER_SIZE, size - off));
        const read = fs.readSync(file.fd, chunk);
        if (read <= 0) {
          break;
        }
        out.set(new Uint8Array(chunk, 0, read), off);
        off += read;
      }
      return decodeUtf8(out.subarray(0, off));
    } finally {
      fs.closeSync(file);
    }
  } catch (e) {
    return null;
  }
}

/**
 * 同步写文件。fs 同步 API 在无权限/只读/空间不足时同步抛 BusinessError；
 * 此处统一捕获并转成带路径的明确 Error 抛给调用方（调用方均有 try/catch 走失败分支），
 * 并保证已打开的句柄被关闭、不完整的目标文件被清理。
 */
export function writeBytes(path: string, bytes: Uint8Array): void {
  mkdirs(parentDir(path));
  let file: fs.File | null = null;
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    let off = 0;
    while (off < bytes.length) {
      const chunk = bytes.subarray(off);
      const ab = chunk.buffer.slice(chunk.byteOffset, chunk.byteOffset + chunk.byteLength) as ArrayBuffer;
      const written = fs.writeSync(file.fd, ab);
      if (written <= 0) {
        throw new Error(`short write at ${off}/${bytes.length}`);
      }
      off += written;
    }
  } catch (e) {
    const err = e as BusinessError;
    const detail = err?.code !== undefined ? `code=${err.code} ${err.message}` : `${(e as Error)?.message}`;
    console.error(`TranslationIo: write ${path} failed: ${detail}`);
    if (file !== null) {
      try {
        fs.closeSync(file);
      } catch (closeErr) {
        console.warn(`TranslationIo: close ${path} failed: ${(closeErr as Error)?.message}`);
      }
      file = null;
      try {
        fs.unlinkSync(path);
      } catch (unlinkErr) {
        console.warn(`TranslationIo: cleanup ${path} failed: ${(unlinkErr as Error)?.message}`);
      }
    }
    throw new Error(`TranslationIo: write ${path} failed: ${detail}`);
  } finally {
    if (file !== null) {
      try {
        fs.closeSync(file);
      } catch (closeErr) {
        console.warn(`TranslationIo: close ${path} failed: ${(closeErr as Error)?.message}`);
      }
    }
  }
}

/** File.writeText（UTF-8） */
export function writeText(path: string, text: string): void {
  writeBytes(path, encodeUtf8(text));
}

export function deleteFile(path: string): void {
  try {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  } catch (e) {
    console.warn(`TranslationIo: delete ${path} failed: ${(e as Error)?.message}`);
  }
  forgetFileHash(path);
}

/** File.deleteRecursively() */
export function deleteRecursively(path: string): void {
  try {
    if (!fs.accessSync(path)) {
      return;
    }
    if (fs.statSync(path).isDirectory()) {
      fs.rmdirSync(path);
    } else {
      fs.unlinkSync(path);
    }
  } catch (e) {
    console.warn(`TranslationIo: deleteRecursively ${path} failed: ${(e as Error)?.message}`);
  }
}

/** dir.walkTopDown().filter{isFile}.sumOf{length} */
export function directorySize(dir: string): number {
  if (!isDirectory(dir)) {
    return 0;
  }
  let total = 0;
  try {
    const names = fs.listFileSync(dir);
    for (let i = 0; i < names.length; i++) {
      const p = joinPath(dir, names[i]);
      if (isDirectory(p)) {
        total += directorySize(p);
      } else {
        total += fileLength(p);
      }
    }
  } catch (e) {
    return total;
  }
  return total;
}

/** Files.move(REPLACE_EXISTING)；失败删除临时文件并返回 false */
export function moveReplacing(tempPath: string, destination: string): boolean {
  try {
    if (fs.accessSync(destination)) {
      fs.unlinkSync(destination);
    }
    forgetFileHash(destination);
    fs.renameSync(tempPath, destination);
    return true;
  } catch (e) {
    try {
      fs.moveFileSync(tempPath, destination, 0);
      return true;
    } catch (e2) {
      deleteFile(tempPath);
      return false;
    }
  }
}
