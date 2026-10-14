/**
 * TextLanguageDetector.ets —— 源 model/ReadAloudStateHolder.kt `Context.detectLocaleFromText`（:399）与
 * `Context.getLocales`（:390）的鸿蒙实现。
 *
 * 源用 Android TextClassificationManager.textClassifier.detectLanguage（置信度×100，过滤 < minConfidence）。
 * 鸿蒙 SDK 无文本语言识别 API（NaturalLanguageKit textProcessing 只有分词/实体），此处以纯 ArkTS 启发式实现：
 *  1) 按 Unicode 文字系统统计字母（汉字/假名/谚文/西里尔/希腊/阿拉伯/希伯来/泰/天城文…）；
 *  2) 拉丁字母部分按常用功能词（stopword）命中数在常见欧洲语言间分配；
 * 每个假设的置信度 = 该语言占全部字母的比例 ×100（与源量纲一致，0..100），按置信度降序由调用方排序。
 * 系统语言列表（源 resources.configuration.locales）→ i18n.System.getPreferredLanguageList()。
 */
import { i18n, intl } from '@kit.LocalizationKit';

/** 源 data class LocaleWithConfidence(locale, confidence)；locale 用 BCP-47 语言标签 */
export class LocaleWithConfidence {
  readonly locale: string;
  readonly confidence: number;

  constructor(locale: string, confidence: number) {
    this.locale = locale;
    this.confidence = confidence;
  }
}

/** 文字系统编号（计数数组下标） */
const SC_HAN: number = 0;
const SC_KANA: number = 1;
const SC_HANGUL: number = 2;
const SC_CYRILLIC: number = 3;
const SC_GREEK: number = 4;
const SC_ARABIC: number = 5;
const SC_HEBREW: number = 6;
const SC_THAI: number = 7;
const SC_DEVANAGARI: number = 8;
const SC_LATIN: number = 9;
const SC_OTHER: number = 10;

const SCRIPT_COUNT: number = 11;

function scriptOf(cp: number): number {
  if ((cp >= 0x41 && cp <= 0x5A) || (cp >= 0x61 && cp <= 0x7A) || (cp >= 0xC0 && cp <= 0x24F && cp !== 0xD7 &&
    cp !== 0xF7) || (cp >= 0x1E00 && cp <= 0x1EFF)) {
    return SC_LATIN;
  }
  if ((cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF) || (cp >= 0x20000 && cp <= 0x2A6DF) ||
    (cp >= 0xF900 && cp <= 0xFAFF)) {
    return SC_HAN;
  }
  if ((cp >= 0x3040 && cp <= 0x30FF) || (cp >= 0x31F0 && cp <= 0x31FF) || (cp >= 0xFF66 && cp <= 0xFF9F)) {
    return SC_KANA;
  }
  if ((cp >= 0xAC00 && cp <= 0xD7AF) || (cp >= 0x1100 && cp <= 0x11FF) || (cp >= 0x3130 && cp <= 0x318F)) {
    return SC_HANGUL;
  }
  if (cp >= 0x0400 && cp <= 0x052F) {
    return SC_CYRILLIC;
  }
  if ((cp >= 0x0370 && cp <= 0x03FF) || (cp >= 0x1F00 && cp <= 0x1FFF)) {
    return SC_GREEK;
  }
  if ((cp >= 0x0600 && cp <= 0x06FF) || (cp >= 0x0750 && cp <= 0x077F) || (cp >= 0xFB50 && cp <= 0xFDFF) ||
    (cp >= 0xFE70 && cp <= 0xFEFF)) {
    return SC_ARABIC;
  }
  if (cp >= 0x0590 && cp <= 0x05FF) {
    return SC_HEBREW;
  }
  if (cp >= 0x0E00 && cp <= 0x0E7F) {
    return SC_THAI;
  }
  if (cp >= 0x0900 && cp <= 0x097F) {
    return SC_DEVANAGARI;
  }
  return SC_OTHER;
}

/** 文字系统内的二次判定用到的特征字符 */
const UKRAINIAN_MARKERS: string = 'іїєґІЇЄҐ';
const PERSIAN_MARKERS: string = 'پچژگکی';

class StopwordLanguage {
  readonly tag: string;
  readonly words: Set<string>;

  constructor(tag: string, words: string) {
    this.tag = tag;
    this.words = new Set<string>(words.split(' '));
  }
}

/** 拉丁字母语言的高频功能词（区分度高、彼此少重叠） */
const LATIN_LANGUAGES: StopwordLanguage[] = [
  new StopwordLanguage('en', 'the and of to is in that it was for with as on are this be by have from not at which ' +
    'but they you he she we his her has had were been would there their what about will can'),
  new StopwordLanguage('de', 'der die und das ist nicht ein eine zu den von mit sich des auf für im dem auch es ' +
    'wird sind wie oder aber bei nach noch wenn nur über ich sie wir'),
  new StopwordLanguage('fr', 'le la les et des est un une du que qui dans pour pas sur au avec ce il elle sont ' +
    'par plus nous vous ont mais ou être cette aux'),
  new StopwordLanguage('es', 'el los las y es un una que del en por con para no se su al lo como más pero sus ' +
    'fue ha son está muy también hay entre'),
  new StopwordLanguage('it', 'il lo gli e è un una che di del della per con non si sono alla nel anche come più ' +
    'ma ha questo sua dei delle degli'),
  new StopwordLanguage('pt', 'o os as e é um uma que do da dos das em no na para com não se por mais ao foi são ' +
    'como mas também seu sua'),
  new StopwordLanguage('nl', 'de het een en van is dat niet te zijn op voor met als ook er maar bij aan om ze ' +
    'wordt nog door naar hij dit'),
  new StopwordLanguage('sv', 'och att det är som en på av för med till den har inte om ett men var jag sig ' +
    'från vi så kan eller'),
  new StopwordLanguage('da', 'og at det er som en på af for med til den har ikke om et men var jeg sig fra ' +
    'vi så kan eller blev'),
  new StopwordLanguage('nb', 'og at det er som en på av for med til den har ikke om et men var jeg seg fra ' +
    'vi så kan eller ble'),
  new StopwordLanguage('fi', 'ja on ei että se oli ovat mutta kun myös tai hän joka sen ovat ole kanssa ' +
    'vain niin mukaan'),
  new StopwordLanguage('pl', 'i w nie na się z że do to jest jak o po ale tak od za co przez dla są jego ' +
    'jej już było'),
  new StopwordLanguage('cs', 'a v je se na že to s z do o jako ale by jsou pro jeho tak jsem po není ' +
    'které který'),
  new StopwordLanguage('tr', 've bir bu da de için ile çok daha ne gibi olan ama en kadar sonra değil ' +
    'olarak her'),
  new StopwordLanguage('id', 'dan yang di ini itu dengan untuk dari tidak ke akan pada adalah juga dalam ' +
    'karena oleh ada saya')
];

function isWordCodePoint(cp: number): boolean {
  return scriptOf(cp) === SC_LATIN || cp === 0x27;
}

/** 拉丁部分各语言功能词命中数 */
function latinStopwordHits(text: string): number[] {
  const hits: number[] = [];
  for (let i = 0; i < LATIN_LANGUAGES.length; i++) {
    hits.push(0);
  }
  const lower: string = text.toLowerCase();
  let word: string = '';
  let i: number = 0;
  const flush = (): void => {
    if (word.length > 0) {
      for (let l = 0; l < LATIN_LANGUAGES.length; l++) {
        if (LATIN_LANGUAGES[l].words.has(word)) {
          hits[l] = hits[l] + 1;
        }
      }
      word = '';
    }
  };
  while (i < lower.length) {
    const cp: number = lower.codePointAt(i) as number;
    const ch: string = String.fromCodePoint(cp);
    i += cp > 0xFFFF ? 2 : 1;
    if (isWordCodePoint(cp)) {
      word += ch;
    } else {
      flush();
    }
  }
  flush();
  return hits;
}

function containsAny(text: string, markers: string): boolean {
  for (let i = 0; i < markers.length; i++) {
    if (text.indexOf(markers.charAt(i)) >= 0) {
      return true;
    }
  }
  return false;
}

/**
 * 源 Context.detectLocaleFromText(text, minConfidence = 80f)：返回置信度（0..100）≥ minConfidence 的语言假设。
 * 顺序不保证（源由调用方 sortedByDescending）。
 */
export function detectLocaleFromText(text: string, minConfidence: number = 80.0): LocaleWithConfidence[] {
  const counts: number[] = [];
  for (let s = 0; s < SCRIPT_COUNT; s++) {
    counts.push(0);
  }
  let total: number = 0;
  let i: number = 0;
  while (i < text.length) {
    const cp: number = text.codePointAt(i) as number;
    i += cp > 0xFFFF ? 2 : 1;
    const sc: number = scriptOf(cp);
    if (sc === SC_OTHER) {
      continue;
    }
    counts[sc] = counts[sc] + 1;
    total++;
  }
  const out: LocaleWithConfidence[] = [];
  if (total === 0) {
    return out;
  }
  const push = (tag: string, share: number): void => {
    const confidence: number = share * 100.0;
    if (share > 0 && confidence >= minConfidence) {
      out.push(new LocaleWithConfidence(tag, confidence));
    }
  };
  // 日文文本混用汉字与假名：假名占 CJK 的 ≥5% 即整体视为日文
  const cjk: number = counts[SC_HAN] + counts[SC_KANA];
  if (cjk > 0) {
    if (counts[SC_KANA] >= cjk * 0.05) {
      push('ja', cjk / total);
    } else {
      push('zh', cjk / total);
    }
  }
  push('ko', counts[SC_HANGUL] / total);
  if (counts[SC_CYRILLIC] > 0) {
    push(containsAny(text, UKRAINIAN_MARKERS) ? 'uk' : 'ru', counts[SC_CYRILLIC] / total);
  }
  push('el', counts[SC_GREEK] / total);
  if (counts[SC_ARABIC] > 0) {
    push(containsAny(text, PERSIAN_MARKERS) ? 'fa' : 'ar', counts[SC_ARABIC] / total);
  }
  push('he', counts[SC_HEBREW] / total);
  push('th', counts[SC_THAI] / total);
  push('hi', counts[SC_DEVANAGARI] / total);
  if (counts[SC_LATIN] > 0) {
    const latinShare: number = counts[SC_LATIN] / total;
    const hits: number[] = latinStopwordHits(text);
    let hitSum: number = 0;
    for (let l = 0; l < hits.length; l++) {
      hitSum += hits[l];
    }
    if (hitSum > 0) {
      for (let l = 0; l < hits.length; l++) {
        push(LATIN_LANGUAGES[l].tag, latinShare * hits[l] / hitSum);
      }
    }
  }
  return out;
}

/** 按置信度降序（稳定）后取语言标签（源 .sortedByDescending { it.confidence }.map { it.locale }） */
export function sortedLocales(found: LocaleWithConfidence[]): string[] {
  const copy: LocaleWithConfidence[] = found.slice();
  // 插入排序保持稳定（Kotlin sortedByDescending 稳定）
  const sorted: LocaleWithConfidence[] = [];
  for (let i = 0; i < copy.length; i++) {
    let pos: number = sorted.length;
    while (pos > 0 && sorted[pos - 1].confidence < copy[i].confidence) {
      pos--;
    }
    sorted.splice(pos, 0, copy[i]);
  }
  const tags: string[] = [];
  for (let i = 0; i < sorted.length; i++) {
    tags.push(sorted[i].locale);
  }
  return tags;
}

/** 源 Context.getLocales()：系统首选语言列表（configuration.locales） */
export function getSystemLocales(): string[] {
  try {
    const list: string[] = i18n.System.getPreferredLanguageList();
    if (list.length > 0) {
      return list;
    }
  } catch (e) {
    console.warn('FEEDER_TTS', `getPreferredLanguageList failed: ${JSON.stringify(e)}`);
  }
  try {
    return [i18n.System.getSystemLocale()];
  } catch (e) {
    console.warn('FEEDER_TTS', `getSystemLocale failed: ${JSON.stringify(e)}`);
  }
  return [];
}

/** 源 Locale.language：主语言子标签（小写） */
export function languageOf(tag: string): string {
  try {
    const loc: intl.Locale = new intl.Locale(tag);
    if (loc.language.length > 0) {
      return loc.language.toLowerCase();
    }
  } catch (e) {
    console.warn('FEEDER_TTS', `bad locale ${tag}`);
  }
  const dash: number = tag.search(new RegExp('[-_]'));
  return (dash < 0 ? tag : tag.substring(0, dash)).toLowerCase();
}

/** 源 Locale.toLanguageTag()：规范化（'_' → '-'），用于去重 */
export function normalizeTag(tag: string): string {
  const t: string = tag.split('_').join('-');
  try {
    const loc: intl.Locale = new intl.Locale(t);
    const s: string = loc.toString();
    if (s.length > 0) {
      return s;
    }
  } catch (e) {
    console.warn('FEEDER_TTS', `bad locale ${tag}`);
  }
  return t;
}

/** 源 locale.getDisplayName(locale)：以该语言自身显示名，如 "English (United Kingdom)" / "中文 (中国)" */
export function localeDisplayName(tag: string): string {
  const t: string = normalizeTag(tag);
  try {
    let name: string = i18n.System.getDisplayLanguage(t, t, true);
    let region: string = '';
    try {
      const loc: intl.Locale = new intl.Locale(t);
      region = loc.region;
    } catch (e) {
      region = '';
    }
    if (region.length > 0) {
      name = name + ' (' + i18n.System.getDisplayCountry(region, t, true) + ')';
    }
    if (name.length > 0) {
      return name;
    }
  } catch (e) {
    console.warn('FEEDER_TTS', `display name failed for ${tag}`);
  }
  return t;
}

/** 源 `it.getDisplayName(it).lowercase(it)` 排序键 */
export function displaySortKey(tag: string): string {
  return localeDisplayName(tag).toLowerCase();
}
