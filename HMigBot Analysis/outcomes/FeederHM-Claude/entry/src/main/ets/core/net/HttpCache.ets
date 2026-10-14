/**
 * HttpCache.ets —— 自研 HTTP 磁盘缓存，等价 OkHttp Cache + CacheStrategy + CacheInterceptor 的判定逻辑。
 * 源依赖 OkHttp 标准 HTTP 缓存语义（FS-A11 max-age=60 条件请求、FS-A16 4xx 强制缓存、FS-A17 only-if-cached、
 * FS-A21 图片 max-stale/max-age/only-if-cached）；@kit.NetworkKit http 的 usingCache 不可按请求控制，故自研。
 * 存储：<dir>/<key>.meta（JSON 元数据）+ <dir>/<key>.body（原始字节）；超上限按最近访问 LRU 淘汰。
 * 只缓存 GET；POST/PUT/DELETE/PATCH/MOVE 使同 URL 条目失效（OkHttp HttpMethod.invalidatesCache）。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { HttpRequest, HttpResponse } from './HttpMessages';
import { varyFields } from './CacheStrategy';

const LOG_TAG: string = 'FEEDER_HTTPCACHE';

// ---------------------------------------------------------------- 磁盘存储

class CacheMeta {
  url: string = '';
  method: string = 'GET';
  code: number = 0;
  message: string = '';
  headerNames: string[] = [];
  headerValues: string[] = [];
  finalUrl: string = '';
  sentAt: number = 0;
  receivedAt: number = 0;
  varyNames: string[] = [];
  varyValues: string[] = [];

  toJson(): string {
    return JSON.stringify(this);
  }

  static fromJson(text: string): CacheMeta | null {
    try {
      const o = JSON.parse(text) as Record<string, Object>;
      const m = new CacheMeta();
      m.url = o['url'] as string;
      m.method = o['method'] as string;
      m.code = o['code'] as number;
      m.message = o['message'] as string;
      m.headerNames = o['headerNames'] as string[];
      m.headerValues = o['headerValues'] as string[];
      m.finalUrl = o['finalUrl'] as string;
      m.sentAt = o['sentAt'] as number;
      m.receivedAt = o['receivedAt'] as number;
      m.varyNames = o['varyNames'] as string[];
      m.varyValues = o['varyValues'] as string[];
      if (typeof m.url !== 'string' || !Array.isArray(m.headerNames)) {
        return null;
      }
      return m;
    } catch (e) {
      return null;
    }
  }
}

class IndexEntry {
  size: number = 0;
  lastAccess: number = 0;
}

/** cyrb53 → 16 位十六进制（含 url 校验，碰撞视为未命中） */
function cacheKey(url: string): string {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < url.length; i++) {
    const ch = url.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  const a = (h2 >>> 0).toString(16).padStart(8, '0');
  const b = (h1 >>> 0).toString(16).padStart(8, '0');
  return a + b;
}

export class HttpDiskCache {
  readonly directory: string;
  readonly maxSize: number;
  private index: Map<string, IndexEntry> = new Map<string, IndexEntry>();
  private totalSize: number = 0;
  private initPromise: Promise<void> | null = null;

  constructor(directory: string, maxSize: number) {
    this.directory = directory;
    this.maxSize = maxSize;
  }

  private metaPath(key: string): string {
    return `${this.directory}/${key}.meta`;
  }

  private bodyPath(key: string): string {
    return `${this.directory}/${key}.body`;
  }

  private ensureInit(): Promise<void> {
    if (this.initPromise === null) {
      this.initPromise = this.loadIndex();
    }
    return this.initPromise as Promise<void>;
  }

  private async loadIndex(): Promise<void> {
    try {
      if (!fs.accessSync(this.directory)) {
        fs.mkdirSync(this.directory, true);
      }
      const names = await fs.listFile(this.directory);
      for (const n of names) {
        if (!n.endsWith('.meta') && !n.endsWith('.body')) {
          continue;
        }
        const key = n.substring(0, n.length - 5);
        const st = await fs.stat(`${this.directory}/${n}`);
        const e = this.index.get(key);
        const entry = e !== undefined ? e : new IndexEntry();
        entry.size += st.size;
        entry.lastAccess = Math.max(entry.lastAccess, st.mtime * 1000);
        this.index.set(key, entry);
        this.totalSize += st.size;
      }
    } catch (e) {
      console.error(`${LOG_TAG}: init failed ${JSON.stringify(e)}`);
    }
  }

  /** Cache.get(request)：仅 GET；Vary 不匹配视为未命中 */
  async get(request: HttpRequest): Promise<HttpResponse | null> {
    if (request.method !== 'GET') {
      return null;
    }
    await this.ensureInit();
    const key = cacheKey(request.url);
    try {
      if (!fs.accessSync(this.metaPath(key)) || !fs.accessSync(this.bodyPath(key))) {
        return null;
      }
      const meta = CacheMeta.fromJson(await fs.readText(this.metaPath(key)));
      if (meta === null || meta.url !== request.url) {
        return null;
      }
      for (let i = 0; i < meta.varyNames.length; i++) {
        const current = request.header(meta.varyNames[i]);
        if ((current !== null ? current : '') !== meta.varyValues[i]) {
          return null;
        }
      }
      const body = await this.readBody(this.bodyPath(key));
      const r = new HttpResponse();
      r.code = meta.code;
      r.message = meta.message;
      for (let i = 0; i < meta.headerNames.length; i++) {
        r.headers.add(meta.headerNames[i], meta.headerValues[i]);
      }
      r.body = body;
      r.finalUrl = meta.finalUrl;
      r.request = request;
      r.sentRequestAtMillis = meta.sentAt;
      r.receivedResponseAtMillis = meta.receivedAt;
      r.fromCache = true;
      r.networkUsed = false;
      const e = this.index.get(key);
      if (e !== undefined) {
        e.lastAccess = Date.now();
      }
      return r;
    } catch (e) {
      console.warn(`${LOG_TAG}: read failed ${request.url}: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /** Cache.put：调用方已判定 isCacheable；Vary:* 不缓存；非 GET 不缓存 */
  async put(response: HttpResponse): Promise<void> {
    const request = response.request;
    if (request.method !== 'GET') {
      return;
    }
    const vary = varyFields(response.headers);
    if (vary.indexOf('*') >= 0) {
      return;
    }
    await this.ensureInit();
    const meta = new CacheMeta();
    meta.url = request.url;
    meta.method = request.method;
    meta.code = response.code;
    meta.message = response.message;
    for (let i = 0; i < response.headers.size(); i++) {
      meta.headerNames.push(response.headers.nameAt(i));
      meta.headerValues.push(response.headers.valueAt(i));
    }
    meta.finalUrl = response.finalUrl;
    meta.sentAt = response.sentRequestAtMillis;
    meta.receivedAt = response.receivedResponseAtMillis;
    for (const v of vary) {
      const cur = request.header(v);
      meta.varyNames.push(v);
      meta.varyValues.push(cur !== null ? cur : '');
    }
    const body = response.body !== null ? response.body : new ArrayBuffer(0);
    const key = cacheKey(request.url);
    try {
      await this.removeKey(key);
      const metaText = meta.toJson();
      await this.writeFile(this.bodyPath(key), body);
      await this.writeFile(this.metaPath(key), metaText);
      const entry = new IndexEntry();
      entry.size = body.byteLength + metaText.length;
      entry.lastAccess = Date.now();
      this.index.set(key, entry);
      this.totalSize += entry.size;
      await this.trimToSize();
    } catch (e) {
      console.warn(`${LOG_TAG}: write failed ${request.url}: ${JSON.stringify(e)}`);
      await this.removeKey(key);
    }
  }

  /** Cache.remove(request) */
  async remove(url: string): Promise<void> {
    await this.ensureInit();
    await this.removeKey(cacheKey(url));
  }

  private async removeKey(key: string): Promise<void> {
    const e = this.index.get(key);
    if (e !== undefined) {
      this.totalSize -= e.size;
      this.index.delete(key);
    }
    for (const p of [this.metaPath(key), this.bodyPath(key)]) {
      try {
        if (fs.accessSync(p)) {
          await fs.unlink(p);
        }
      } catch (err) {
        console.warn(`${LOG_TAG}: unlink failed ${p}`);
      }
    }
  }

  private async trimToSize(): Promise<void> {
    if (this.totalSize <= this.maxSize) {
      return;
    }
    const keys: string[] = [];
    this.index.forEach((_v: IndexEntry, k: string) => {
      keys.push(k);
    });
    keys.sort((a: string, b: string) => {
      const ea = this.index.get(a);
      const eb = this.index.get(b);
      return (ea !== undefined ? ea.lastAccess : 0) - (eb !== undefined ? eb.lastAccess : 0);
    });
    for (const k of keys) {
      if (this.totalSize <= this.maxSize) {
        break;
      }
      await this.removeKey(k);
    }
  }

  private async writeFile(path: string, data: ArrayBuffer | string): Promise<void> {
    const tmp = path + '.tmp';
    const file = await fs.open(tmp, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
    try {
      await fs.write(file.fd, data);
    } finally {
      await fs.close(file);
    }
    await fs.rename(tmp, path);
  }

  private async readBody(path: string): Promise<ArrayBuffer> {
    const st = await fs.stat(path);
    const buf = new ArrayBuffer(st.size);
    if (st.size === 0) {
      return buf;
    }
    const file = await fs.open(path, fs.OpenMode.READ_ONLY);
    try {
      const target = new Uint8Array(buf);
      let off = 0;
      while (off < st.size) {
        // ReadOptions.offset 是文件偏移；数据总写入 chunk 起始处，再拷到目标位置
        const chunk = new ArrayBuffer(Math.min(st.size - off, 1024 * 1024));
        const n = await fs.read(file.fd, chunk, { offset: off });
        if (n <= 0) {
          break;
        }
        target.set(new Uint8Array(chunk, 0, n), off);
        off += n;
      }
    } finally {
      await fs.close(file);
    }
    return buf;
  }

  /** 清空（设置页"清缓存"等可用） */
  async evictAll(): Promise<void> {
    await this.ensureInit();
    const keys: string[] = [];
    this.index.forEach((_v: IndexEntry, k: string) => {
      keys.push(k);
    });
    for (const k of keys) {
      await this.removeKey(k);
    }
  }

  size(): number {
    return this.totalSize;
  }
}
