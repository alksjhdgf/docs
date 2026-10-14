/**
 * CharsetRecognizers.ets —— CharsetDetector（ICU4J CharsetDetector 移植）的公共结构与 Unicode / ISO-2022 识别器。
 * 多字节（Shift_JIS/GB18030/EUC/Big5）与单字节（ISO-8859-x/windows-125x/KOI8-R）识别器见 CharsetRecognizersLegacy.ets。
 */

/** 一次探测的输入（对应 ICU CharsetDetector 内部状态：原始字节 + C1 字节标志） */
export class DetectorInput {
  readonly bytes: Uint8Array;
  readonly length: number;
  readonly c1Bytes: boolean;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
    this.length = bytes.length;
    let c1: boolean = false;
    for (let i = 0; i < bytes.length; i++) {
      const b: number = bytes[i];
      if (b >= 0x80 && b <= 0x9F) {
        c1 = true;
        break;
      }
    }
    this.c1Bytes = c1;
  }
}

/** ICU CharsetMatch：字符集名 + 置信度(0..100) + 语言（可空） */
export class CharsetMatch {
  readonly name: string;
  readonly confidence: number;
  readonly language: string | null;

  constructor(name: string, confidence: number, language: string | null) {
    this.name = name;
    this.confidence = confidence;
    this.language = language;
  }
}

export abstract class CharsetRecognizer {
  abstract match(det: DetectorInput): CharsetMatch | null;
}

export function binarySearch(table: number[], value: number): boolean {
  let lo: number = 0;
  let hi: number = table.length - 1;
  while (lo <= hi) {
    const mid: number = (lo + hi) >>> 1;
    const v: number = table[mid];
    if (v === value) {
      return true;
    }
    if (v < value) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return false;
}

// =============================================================================================
// Unicode
// =============================================================================================

export class RecogUtf8 extends CharsetRecognizer {
  match(det: DetectorInput): CharsetMatch | null {
    const input: Uint8Array = det.bytes;
    const len: number = det.length;
    const hasBOM: boolean = len >= 3 && input[0] === 0xEF && input[1] === 0xBB && input[2] === 0xBF;
    let numValid: number = 0;
    let numInvalid: number = 0;
    let trailBytes: number = 0;
    for (let i = 0; i < len; i++) {
      let b: number = input[i];
      if ((b & 0x80) === 0) {
        continue; // ASCII
      }
      if ((b & 0xE0) === 0xC0) {
        trailBytes = 1;
      } else if ((b & 0xF0) === 0xE0) {
        trailBytes = 2;
      } else if ((b & 0xF8) === 0xF0) {
        trailBytes = 3;
      } else {
        numInvalid++;
        continue;
      }
      // Verify that we've got the right number of trail bytes in the sequence
      while (true) {
        i++;
        if (i >= len) {
          break;
        }
        b = input[i];
        if ((b & 0xC0) !== 0x80) {
          numInvalid++;
          break;
        }
        if (--trailBytes === 0) {
          numValid++;
          break;
        }
      }
    }
    let confidence: number = 0;
    if (hasBOM && numInvalid === 0) {
      confidence = 100;
    } else if (hasBOM && numValid > numInvalid * 10) {
      confidence = 80;
    } else if (numValid > 3 && numInvalid === 0) {
      confidence = 100;
    } else if (numValid > 0 && numInvalid === 0) {
      confidence = 80;
    } else if (numValid === 0 && numInvalid === 0) {
      confidence = 15; // Plain ASCII
    } else if (numValid > numInvalid * 10) {
      confidence = 25; // Probably UTF-8 with a few encoding errors
    }
    return confidence === 0 ? null : new CharsetMatch('UTF-8', confidence, null);
  }
}

export function adjustUtf16Confidence(codeUnit: number, confidence: number): number {
  let c: number = confidence;
  if (codeUnit === 0) {
    c -= 10;
  } else if ((codeUnit >= 0x20 && codeUnit <= 0xFF) || codeUnit === 0x0A) {
    c += 10;
  }
  return c < 0 ? 0 : (c > 100 ? 100 : c);
}

export class RecogUtf16 extends CharsetRecognizer {
  private readonly littleEndian: boolean;

  constructor(littleEndian: boolean) {
    super();
    this.littleEndian = littleEndian;
  }

  match(det: DetectorInput): CharsetMatch | null {
    const input: Uint8Array = det.bytes;
    let confidence: number = 10;
    const bytesToCheck: number = Math.min(det.length, 30);
    for (let charIndex = 0; charIndex < bytesToCheck - 1; charIndex += 2) {
      const codeUnit: number = this.littleEndian ? ((input[charIndex + 1] << 8) | input[charIndex]) :
        ((input[charIndex] << 8) | input[charIndex + 1]);
      if (charIndex === 0 && codeUnit === 0xFEFF) {
        confidence = 100;
        break;
      }
      confidence = adjustUtf16Confidence(codeUnit, confidence);
      if (confidence === 0 || confidence === 100) {
        break;
      }
    }
    if (bytesToCheck < 4 && confidence < 100) {
      confidence = 0;
    }
    return confidence > 0 ? new CharsetMatch(this.littleEndian ? 'UTF-16LE' : 'UTF-16BE', confidence, null) : null;
  }
}

export class RecogUtf32 extends CharsetRecognizer {
  private readonly littleEndian: boolean;

  constructor(littleEndian: boolean) {
    super();
    this.littleEndian = littleEndian;
  }

  private getChar(input: Uint8Array, i: number): number {
    // Java int 语义：最高字节 ≥0x80 时为负数（视为非法）
    if (this.littleEndian) {
      return (input[i + 3] << 24) | (input[i + 2] << 16) | (input[i + 1] << 8) | input[i];
    }
    return (input[i] << 24) | (input[i + 1] << 16) | (input[i + 2] << 8) | input[i + 3];
  }

  match(det: DetectorInput): CharsetMatch | null {
    const input: Uint8Array = det.bytes;
    const limit: number = Math.floor(det.length / 4) * 4;
    if (limit === 0) {
      return null;
    }
    const hasBOM: boolean = this.getChar(input, 0) === 0x0000FEFF;
    let numValid: number = 0;
    let numInvalid: number = 0;
    for (let i = 0; i < limit; i += 4) {
      const ch: number = this.getChar(input, i);
      if (ch < 0 || ch >= 0x10FFFF || (ch >= 0xD800 && ch <= 0xDFFF)) {
        numInvalid++;
      } else {
        numValid++;
      }
    }
    let confidence: number = 0;
    if (hasBOM && numInvalid === 0) {
      confidence = 100;
    } else if (hasBOM && numValid > numInvalid * 10) {
      confidence = 80;
    } else if (numValid > 3 && numInvalid === 0) {
      confidence = 100;
    } else if (numValid > 0 && numInvalid === 0) {
      confidence = 80;
    } else if (numValid > numInvalid * 10) {
      confidence = 25;
    }
    return confidence === 0 ? null : new CharsetMatch(this.littleEndian ? 'UTF-32LE' : 'UTF-32BE', confidence, null);
  }
}

// =============================================================================================
// ISO-2022
// =============================================================================================

export const ESC_2022_JP: number[][] = [
  [0x1b, 0x24, 0x28, 0x43], [0x1b, 0x24, 0x28, 0x44], [0x1b, 0x24, 0x40], [0x1b, 0x24, 0x41], [0x1b, 0x24, 0x42],
  [0x1b, 0x26, 0x40], [0x1b, 0x28, 0x42], [0x1b, 0x28, 0x48], [0x1b, 0x28, 0x49], [0x1b, 0x28, 0x4a],
  [0x1b, 0x2e, 0x41], [0x1b, 0x2e, 0x46]
];
export const ESC_2022_KR: number[][] = [[0x1b, 0x24, 0x29, 0x43]];
export const ESC_2022_CN: number[][] = [
  [0x1b, 0x24, 0x29, 0x41], [0x1b, 0x24, 0x29, 0x47], [0x1b, 0x24, 0x2A, 0x48], [0x1b, 0x24, 0x29, 0x45],
  [0x1b, 0x24, 0x2B, 0x49], [0x1b, 0x24, 0x2B, 0x4A], [0x1b, 0x24, 0x2B, 0x4B], [0x1b, 0x24, 0x2B, 0x4C],
  [0x1b, 0x24, 0x2B, 0x4D], [0x1b, 0x4e], [0x1b, 0x4f]
];

export function escapeSequenceAt(text: Uint8Array, textLen: number, i: number, seq: number[]): boolean {
  if (textLen - i < seq.length) {
    return false;
  }
  for (let j = 1; j < seq.length; j++) {
    if (seq[j] !== text[i + j]) {
      return false;
    }
  }
  return true;
}

export class Recog2022 extends CharsetRecognizer {
  private readonly charsetName: string;
  private readonly escapeSequences: number[][];

  constructor(charsetName: string, escapeSequences: number[][]) {
    super();
    this.charsetName = charsetName;
    this.escapeSequences = escapeSequences;
  }

  match(det: DetectorInput): CharsetMatch | null {
    const text: Uint8Array = det.bytes;
    const textLen: number = det.length;
    let hits: number = 0;
    let misses: number = 0;
    let shifts: number = 0;
    for (let i = 0; i < textLen; i++) {
      if (text[i] === 0x1b) {
        let matched: boolean = false;
        for (let escN = 0; escN < this.escapeSequences.length; escN++) {
          const seq: number[] = this.escapeSequences[escN];
          if (escapeSequenceAt(text, textLen, i, seq)) {
            hits++;
            i += seq.length - 1;
            matched = true;
            break;
          }
        }
        if (matched) {
          continue;
        }
        misses++;
      }
      if (text[i] === 0x0e || text[i] === 0x0f) {
        // Shift in/out
        shifts++;
      }
    }
    if (hits === 0) {
      return null;
    }
    // Initial quality is based on relative proportion of recongized vs. unrecognized escape sequences.
    let quality: number = Math.trunc((100 * hits - 100 * misses) / (hits + misses));
    // Back off quality if there were too few escape sequences seen.
    if (hits + shifts < 5) {
      quality -= (5 - (hits + shifts)) * 10;
    }
    if (quality < 0) {
      quality = 0;
    }
    return quality === 0 ? null : new CharsetMatch(this.charsetName, quality, null);
  }
}
