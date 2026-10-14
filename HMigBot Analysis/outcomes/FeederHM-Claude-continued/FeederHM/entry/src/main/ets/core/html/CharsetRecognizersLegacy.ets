/**
 * CharsetRecognizersLegacy.ets —— CharsetDetector（ICU4J 移植）的多字节（ICU CharsetRecog_mbcs）与单字节
 * （ICU CharsetRecog_sbcs，字母三元组）识别器。统计表见 CharsetDetectorData.ets。
 */
import { COMMON_CHARS_BIG5, COMMON_CHARS_EUC_JP, COMMON_CHARS_EUC_KR, COMMON_CHARS_GB18030, COMMON_CHARS_SJIS } from './CharsetDetectorData';
import { CharsetMatch, CharsetRecognizer, DetectorInput, binarySearch } from './CharsetRecognizers';

// =============================================================================================
// 多字节（mbcs）
// =============================================================================================

/** ICU iteratedChar：一次取一个（多字节）字符 */
export class IteratedChar {
  charValue: number = 0;
  nextIndex: number = 0;
  error: boolean = false;
  done: boolean = false;

  nextByte(det: DetectorInput): number {
    if (this.nextIndex >= det.length) {
      this.done = true;
      return -1;
    }
    return det.bytes[this.nextIndex++];
  }
}

export abstract class RecogMbcs extends CharsetRecognizer {
  abstract charsetName(): string;

  abstract language(): string;

  abstract commonChars(): number[];

  /** 取下一个字符；无更多输入返回 false */
  abstract nextChar(it: IteratedChar, det: DetectorInput): boolean;

  match(det: DetectorInput): CharsetMatch | null {
    const confidence: number = this.matchConfidence(det);
    return confidence === 0 ? null : new CharsetMatch(this.charsetName(), confidence, this.language());
  }

  private matchConfidence(det: DetectorInput): number {
    const common: number[] = this.commonChars();
    let doubleByteCharCount: number = 0;
    let commonCharCount: number = 0;
    let badCharCount: number = 0;
    let totalCharCount: number = 0;
    const it: IteratedChar = new IteratedChar();
    while (this.nextChar(it, det)) {
      totalCharCount++;
      if (it.error) {
        badCharCount++;
      } else {
        const cv: number = it.charValue >>> 0;
        if (cv > 0xFF) {
          doubleByteCharCount++;
          if (binarySearch(common, cv)) {
            commonCharCount++;
          }
        }
      }
      if (badCharCount >= 2 && badCharCount * 5 >= doubleByteCharCount) {
        // Bail out early if the byte data is not matching the encoding scheme.
        return 0;
      }
    }
    if (doubleByteCharCount <= 10 && badCharCount === 0) {
      // Not many multi-byte chars.
      return doubleByteCharCount === 0 && totalCharCount < 10 ? 0 : 10;
    }
    // No match if there are too many characters that don't fit the encoding scheme.
    if (doubleByteCharCount < 20 * badCharCount) {
      return 0;
    }
    // Frequency of occurrence of the most common characters, on a log scale.
    const maxVal: number = Math.log(doubleByteCharCount / 4);
    const scaleFactor: number = 90.0 / maxVal;
    const confidence: number = Math.trunc(Math.log(commonCharCount + 1) * scaleFactor + 10);
    return Math.max(0, Math.min(confidence, 100));
  }
}

export class RecogSjis extends RecogMbcs {
  charsetName(): string {
    return 'Shift_JIS';
  }

  language(): string {
    return 'ja';
  }

  commonChars(): number[] {
    return COMMON_CHARS_SJIS;
  }

  nextChar(it: IteratedChar, det: DetectorInput): boolean {
    it.error = false;
    const firstByte: number = it.nextByte(det);
    it.charValue = firstByte;
    if (firstByte < 0) {
      return false;
    }
    if (firstByte <= 0x7f || (firstByte > 0xa0 && firstByte <= 0xdf)) {
      return true;
    }
    const secondByte: number = it.nextByte(det);
    if (secondByte < 0) {
      return false;
    }
    it.charValue = (firstByte << 8) | secondByte;
    if (!((secondByte >= 0x40 && secondByte <= 0x7f) || (secondByte >= 0x80 && secondByte <= 0xff))) {
      // Illegal second byte value.
      it.error = true;
    }
    return true;
  }
}

/** EUC-JP / EUC-KR 共用的字符切分 */
export abstract class RecogEuc extends RecogMbcs {
  nextChar(it: IteratedChar, det: DetectorInput): boolean {
    it.error = false;
    const firstByte: number = it.nextByte(det);
    it.charValue = firstByte;
    if (firstByte < 0) {
      // Ran off the end of the input data
      return false;
    }
    if (firstByte <= 0x8d) {
      // single byte char
      return true;
    }
    const secondByte: number = it.nextByte(det);
    it.charValue = (it.charValue << 8) | (secondByte & 0xFF);
    if (firstByte >= 0xA1 && firstByte <= 0xfe) {
      // Two byte Char
      if (secondByte < 0xa1) {
        it.error = true;
      }
      return !it.done;
    }
    if (firstByte === 0x8e) {
      // Code Set 2. In EUC-JP, total char is 2 bytes, only one byte of actual char value.
      if (secondByte < 0xa1) {
        it.error = true;
      }
      return !it.done;
    }
    if (firstByte === 0x8f) {
      // Code set 3. Three byte total char size, two bytes of actual char value.
      const thirdByte: number = it.nextByte(det);
      it.charValue = (it.charValue << 8) | (thirdByte & 0xFF);
      if (thirdByte < 0xa1) {
        it.error = true;
      }
    }
    return !it.done;
  }
}

export class RecogEucJp extends RecogEuc {
  charsetName(): string {
    return 'EUC-JP';
  }

  language(): string {
    return 'ja';
  }

  commonChars(): number[] {
    return COMMON_CHARS_EUC_JP;
  }
}

export class RecogEucKr extends RecogEuc {
  charsetName(): string {
    return 'EUC-KR';
  }

  language(): string {
    return 'ko';
  }

  commonChars(): number[] {
    return COMMON_CHARS_EUC_KR;
  }
}

export class RecogBig5 extends RecogMbcs {
  charsetName(): string {
    return 'Big5';
  }

  language(): string {
    return 'zh';
  }

  commonChars(): number[] {
    return COMMON_CHARS_BIG5;
  }

  nextChar(it: IteratedChar, det: DetectorInput): boolean {
    it.error = false;
    const firstByte: number = it.nextByte(det);
    it.charValue = firstByte;
    if (firstByte < 0) {
      return false;
    }
    if (firstByte <= 0x7f || firstByte === 0xff) {
      // single byte character.
      return true;
    }
    const secondByte: number = it.nextByte(det);
    if (secondByte < 0) {
      return false;
    }
    it.charValue = (it.charValue << 8) | secondByte;
    if (secondByte < 0x40 || secondByte === 0x7f || secondByte === 0xff) {
      it.error = true;
    }
    return true;
  }
}

export class RecogGb18030 extends RecogMbcs {
  charsetName(): string {
    return 'GB18030';
  }

  language(): string {
    return 'zh';
  }

  commonChars(): number[] {
    return COMMON_CHARS_GB18030;
  }

  nextChar(it: IteratedChar, det: DetectorInput): boolean {
    it.error = false;
    const firstByte: number = it.nextByte(det);
    it.charValue = firstByte;
    if (firstByte < 0) {
      // Ran off the end of the input data
      return false;
    }
    if (firstByte <= 0x80) {
      // single byte char
      return true;
    }
    const secondByte: number = it.nextByte(det);
    it.charValue = (it.charValue << 8) | (secondByte & 0xFF);
    if (firstByte >= 0x81 && firstByte <= 0xFE) {
      // Two byte Char（ICU 原实现第二段下界写作十进制 80，这里照搬）
      if ((secondByte >= 0x40 && secondByte <= 0x7E) || (secondByte >= 80 && secondByte <= 0xFE)) {
        return true;
      }
      // Four byte char
      if (secondByte >= 0x30 && secondByte <= 0x39) {
        const thirdByte: number = it.nextByte(det);
        if (thirdByte >= 0x81 && thirdByte <= 0xFE) {
          const fourthByte: number = it.nextByte(det);
          if (fourthByte >= 0x30 && fourthByte <= 0x39) {
            it.charValue = ((it.charValue << 16) | (thirdByte << 8) | fourthByte) >>> 0;
            return true;
          }
        }
      }
      // Something wrong with a double or four byte character.
      it.error = true;
    }
    return !it.done;
  }
}

// =============================================================================================
// 单字节（sbcs）：字母三元组
// =============================================================================================

export class NGramLanguage {
  readonly language: string;
  readonly ngrams: number[];

  constructor(language: string, ngrams: number[]) {
    this.language = language;
    this.ngrams = ngrams;
  }
}

export const SPACE: number = 0x20;

/** ICU NGramParser.parse 的命中率 → 置信度：> 0.33 → 98，否则 rawPercent * 300 */
export function ngramConfidence(hitCount: number, ngramCount: number): number {
  if (ngramCount === 0) {
    return 0;
  }
  const rawPercent: number = hitCount / ngramCount;
  if (rawPercent > 0.33) {
    return 98;
  }
  return Math.trunc(rawPercent * 300.0);
}

export class RecogSbcs extends CharsetRecognizer {
  private readonly isoName: string;
  private readonly c1Name: string | null;
  private readonly byteMap: number[];
  private readonly languages: NGramLanguage[];
  /** 三元组 → 命中语言位掩码（第 i 位 = languages[i]），一次扫描统计全部语言 */
  private readonly gramToLanguages: Map<number, number> = new Map<number, number>();

  /** c1Name：输入含 0x80..0x9F 时报告的 windows-125x 名；null 表示名称固定 */
  constructor(isoName: string, c1Name: string | null, byteMap: number[], languages: NGramLanguage[]) {
    super();
    this.isoName = isoName;
    this.c1Name = c1Name;
    this.byteMap = byteMap;
    this.languages = languages;
    for (let li = 0; li < languages.length; li++) {
      const grams: number[] = languages[li].ngrams;
      for (let g = 0; g < grams.length; g++) {
        const prev: number | undefined = this.gramToLanguages.get(grams[g]);
        this.gramToLanguages.set(grams[g], (prev !== undefined ? prev : 0) | (1 << li));
      }
    }
  }

  match(det: DetectorInput): CharsetMatch | null {
    // ICU NGramParser.parseCharacters：字节经 byteMap 映射，连续空格只计一次；结束时再 addByte(空格)
    const hits: number[] = [];
    for (let li = 0; li < this.languages.length; li++) {
      hits.push(0);
    }
    const byteMap: number[] = this.byteMap;
    const input: Uint8Array = det.bytes;
    const len: number = det.length;
    let ngram: number = 0;
    let ngramCount: number = 0;
    let ignoreSpace: boolean = false;
    for (let i = 0; i <= len; i++) {
      const mb: number = i < len ? byteMap[input[i]] : SPACE;
      if (mb === 0) {
        continue;
      }
      if (i < len && mb === SPACE && ignoreSpace) {
        continue;
      }
      ignoreSpace = mb === SPACE;
      ngram = ((ngram << 8) + mb) & 0xFFFFFF;
      ngramCount++;
      const mask: number | undefined = this.gramToLanguages.get(ngram);
      if (mask !== undefined) {
        for (let li = 0; li < hits.length; li++) {
          if ((mask & (1 << li)) !== 0) {
            hits[li]++;
          }
        }
      }
    }
    let bestConfidence: number = -1;
    let lang: string | null = null;
    for (let li = 0; li < this.languages.length; li++) {
      const confidence: number = ngramConfidence(hits[li], ngramCount);
      if (confidence > bestConfidence) {
        bestConfidence = confidence;
        lang = this.languages[li].language;
      }
    }
    if (bestConfidence <= 0) {
      return null;
    }
    const name: string = det.c1Bytes && this.c1Name !== null ? this.c1Name : this.isoName;
    return new CharsetMatch(name, bestConfidence, lang);
  }
}
