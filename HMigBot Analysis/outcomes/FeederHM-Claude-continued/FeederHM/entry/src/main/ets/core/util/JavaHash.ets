/**
 * JavaHash.ets —— Java/Kotlin hashCode 语义逐位复刻（32 位有符号 int）。
 * 用途：RssLocalSync alternateId（`"$id|${content_text.hashCode()}|${title.hashCode()}"`）、
 * 字母图标配色（Long.hashCode）、Feeder Sync 内容哈希（List/data class 组合）。
 */

/** String.hashCode：UTF-16 码元，h = 31*h + c，int 溢出。Kotlin `Any?.hashCode()` 对 null 返回 0。 */
export function javaStringHashCode(s: string | null): number {
  if (s === null) {
    return 0;
  }
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  }
  return h;
}

/** Integer.hashCode */
export function javaIntHashCode(v: number): number {
  return v | 0;
}

/**
 * Long.hashCode = (int)(v ^ (v >>> 32))。要求 v 为安全整数（|v| < 2^53）；更大的 id 请用字符串 + BigInt 自行处理。
 */
export function javaLongHashCode(v: number): number {
  const hi = Math.floor(v / 4294967296);
  const lo = v - hi * 4294967296;
  return ((lo | 0) ^ (hi | 0)) | 0;
}

/** Boolean.hashCode：true 1231 / false 1237 */
export function javaBooleanHashCode(v: boolean): number {
  return v ? 1231 : 1237;
}

/** List.hashCode（AbstractList）：h = 31*h + (e==null ? 0 : e.hashCode())，元素哈希由调用方先算好。 */
export function javaListHashCode(elementHashes: number[]): number {
  let h = 1;
  for (let i = 0; i < elementHashes.length; i++) {
    h = (Math.imul(31, h) + (elementHashes[i] | 0)) | 0;
  }
  return h;
}

/** Kotlin data class 生成的 hashCode：result = h0; result = 31*result + h_i ... */
export function kotlinDataClassHashCode(fieldHashes: number[]): number {
  if (fieldHashes.length === 0) {
    return 0;
  }
  let h = fieldHashes[0] | 0;
  for (let i = 1; i < fieldHashes.length; i++) {
    h = (Math.imul(31, h) + (fieldHashes[i] | 0)) | 0;
  }
  return h;
}

/** java.time.Instant.hashCode = ((int)(seconds ^ (seconds >>> 32))) + 51 * nanos，入参 epoch 毫秒。 */
export function javaInstantHashCode(epochMs: number): number {
  const seconds = Math.floor(epochMs / 1000);
  const nanos = (epochMs - seconds * 1000) * 1000000;
  return (javaLongHashCode(seconds) + Math.imul(51, nanos | 0)) | 0;
}

/** Java 的 `%` 取余（符号随被除数），供 `hashCode() % n` 之类表达式使用。 */
export function javaIntRem(a: number, b: number): number {
  return (a % b) | 0;
}
