/**
 * CharsetDetector.ets —— 源 FullTextParser.detectCharset 所用 ICU4J `com.ibm.icu.text.CharsetDetector` 的纯 ArkTS 实现。
 *
 * 鸿蒙无 ICU 统计探测 API，这里按 ICU 的识别器结构与置信度公式移植（setText(bytes) + detectAll()，不剥标签——
 * 与源一致，源未调用 enableInputFilter）：
 *  - UTF-8 / UTF-16BE / UTF-16LE / UTF-32BE / UTF-32LE（BOM + 合法性统计）
 *  - ISO-2022-JP / ISO-2022-CN / ISO-2022-KR（转义序列命中统计）
 *  - Shift_JIS / GB18030 / EUC-JP / EUC-KR / Big5（多字节合法性 + 高频字命中，ICU mbcs 置信度公式）
 *  - ISO-8859-1/2/5/6/7/8(-I)/9、windows-1251/1256、KOI8-R（字母三元组命中率，ICU sbcs 公式；
 *    出现 0x80..0x9F 字节时 8859-1/2/7/8/9 报告为 windows-1252/1250/1253/1255/1254）
 * 结果按置信度降序（同分时后注册的识别器在前，同 ICU 的 sort + reverse）。
 * 统计表（高频字/三元组）见 CharsetDetectorData.ets：由本工程离线生成，并非 ICU 原表，置信度数值与 ICU 近似而非逐字节一致。
 */
import {
  BYTE_MAP_1251, BYTE_MAP_1256, BYTE_MAP_8859_1, BYTE_MAP_8859_2, BYTE_MAP_8859_5, BYTE_MAP_8859_6, BYTE_MAP_8859_7,
  BYTE_MAP_8859_8_I, BYTE_MAP_8859_9, BYTE_MAP_KOI8_R, NGRAMS_1251_RU, NGRAMS_1256_AR, NGRAMS_8859_1_DA, NGRAMS_8859_1_DE,
  NGRAMS_8859_1_EN, NGRAMS_8859_1_ES, NGRAMS_8859_1_FR, NGRAMS_8859_1_IT, NGRAMS_8859_1_NL, NGRAMS_8859_1_NO,
  NGRAMS_8859_1_PT, NGRAMS_8859_1_SV, NGRAMS_8859_2_CS, NGRAMS_8859_2_HU, NGRAMS_8859_2_PL, NGRAMS_8859_2_RO,
  NGRAMS_8859_5_RU, NGRAMS_8859_6_AR, NGRAMS_8859_7_EL, NGRAMS_8859_8_HE_VISUAL, NGRAMS_8859_8_I_HE, NGRAMS_8859_9_TR,
  NGRAMS_KOI8_R_RU
} from './CharsetDetectorData';
import {
  CharsetMatch, CharsetRecognizer, DetectorInput, ESC_2022_CN, ESC_2022_JP, ESC_2022_KR, Recog2022, RecogUtf16, RecogUtf32,
  RecogUtf8
} from './CharsetRecognizers';
import {
  NGramLanguage, RecogBig5, RecogEucJp, RecogEucKr, RecogGb18030, RecogSbcs, RecogSjis
} from './CharsetRecognizersLegacy';

export { CharsetMatch } from './CharsetRecognizers';

// =============================================================================================
// 探测器
// =============================================================================================

/** 与 ICU ALL_CS_RECOGNIZERS 默认启用项同序（IBM420/IBM424 默认禁用，不列） */
function allRecognizers(): CharsetRecognizer[] {
  return [
    new RecogUtf8(),
    new RecogUtf16(false),
    new RecogUtf16(true),
    new RecogUtf32(false),
    new RecogUtf32(true),
    new RecogSjis(),
    new Recog2022('ISO-2022-JP', ESC_2022_JP),
    new Recog2022('ISO-2022-CN', ESC_2022_CN),
    new Recog2022('ISO-2022-KR', ESC_2022_KR),
    new RecogGb18030(),
    new RecogEucJp(),
    new RecogEucKr(),
    new RecogBig5(),
    new RecogSbcs('ISO-8859-1', 'windows-1252', BYTE_MAP_8859_1, [
      new NGramLanguage('en', NGRAMS_8859_1_EN), new NGramLanguage('da', NGRAMS_8859_1_DA),
      new NGramLanguage('de', NGRAMS_8859_1_DE), new NGramLanguage('es', NGRAMS_8859_1_ES),
      new NGramLanguage('fr', NGRAMS_8859_1_FR), new NGramLanguage('it', NGRAMS_8859_1_IT),
      new NGramLanguage('nl', NGRAMS_8859_1_NL), new NGramLanguage('no', NGRAMS_8859_1_NO),
      new NGramLanguage('pt', NGRAMS_8859_1_PT), new NGramLanguage('sv', NGRAMS_8859_1_SV)
    ]),
    new RecogSbcs('ISO-8859-2', 'windows-1250', BYTE_MAP_8859_2, [
      new NGramLanguage('cs', NGRAMS_8859_2_CS), new NGramLanguage('hu', NGRAMS_8859_2_HU),
      new NGramLanguage('pl', NGRAMS_8859_2_PL), new NGramLanguage('ro', NGRAMS_8859_2_RO)
    ]),
    new RecogSbcs('ISO-8859-5', null, BYTE_MAP_8859_5, [new NGramLanguage('ru', NGRAMS_8859_5_RU)]),
    new RecogSbcs('ISO-8859-6', null, BYTE_MAP_8859_6, [new NGramLanguage('ar', NGRAMS_8859_6_AR)]),
    new RecogSbcs('ISO-8859-7', 'windows-1253', BYTE_MAP_8859_7, [new NGramLanguage('el', NGRAMS_8859_7_EL)]),
    new RecogSbcs('ISO-8859-8-I', 'windows-1255', BYTE_MAP_8859_8_I, [new NGramLanguage('he', NGRAMS_8859_8_I_HE)]),
    new RecogSbcs('ISO-8859-8', 'windows-1255', BYTE_MAP_8859_8_I, [new NGramLanguage('he', NGRAMS_8859_8_HE_VISUAL)]),
    new RecogSbcs('windows-1251', null, BYTE_MAP_1251, [new NGramLanguage('ru', NGRAMS_1251_RU)]),
    new RecogSbcs('windows-1256', null, BYTE_MAP_1256, [new NGramLanguage('ar', NGRAMS_1256_AR)]),
    new RecogSbcs('KOI8-R', null, BYTE_MAP_KOI8_R, [new NGramLanguage('ru', NGRAMS_KOI8_R_RU)]),
    new RecogSbcs('ISO-8859-9', 'windows-1254', BYTE_MAP_8859_9, [new NGramLanguage('tr', NGRAMS_8859_9_TR)])
  ];
}

/** ICU CharsetDetector.setText(bytes).detectAll()：全部候选，按置信度降序（同分时注册靠后者在前） */
export function detectAllCharsets(bytes: Uint8Array): CharsetMatch[] {
  const det: DetectorInput = new DetectorInput(bytes);
  const recognizers: CharsetRecognizer[] = allRecognizers();
  const matches: CharsetMatch[] = [];
  for (let i = 0; i < recognizers.length; i++) {
    const m: CharsetMatch | null = recognizers[i].match(det);
    if (m !== null) {
      matches.push(m);
    }
  }
  // Collections.sort（稳定升序）+ Collections.reverse
  const indexed: number[] = [];
  for (let i = 0; i < matches.length; i++) {
    indexed.push(i);
  }
  indexed.sort((a: number, b: number): number => {
    const d: number = matches[a].confidence - matches[b].confidence;
    return d !== 0 ? d : a - b;
  });
  const result: CharsetMatch[] = [];
  for (let i = indexed.length - 1; i >= 0; i--) {
    result.push(matches[indexed[i]]);
  }
  return result;
}
