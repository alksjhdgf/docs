/*
 * LanguageTables — AI/翻译设置用的语言数据表与系统语言工具。
 * 源：ui/compose/settings/OpenAISection.kt（deepLTargetLanguageOptions :785-908、isoLanguageOptions :775）、
 *     di/ArchModelModule.kt:60（appLang = Locale.getDefault().getISO3Language()）。
 * 鸿蒙无 Locale.getISOLanguages()/getISO3Language()：固化 ISO 639-1 → 639-2/T 映射表（与 Java 同集合，去掉旧码 in/iw/ji）。
 */
import { i18n } from '@kit.LocalizationKit';

/** ISO 639-1 两字母码 → ISO 639-2/T 三字母码（java.util.Locale.getISO3Language 语义） */
const ISO_639_TABLE: string[][] = [
  ['aa', 'aar'], ['ab', 'abk'], ['ae', 'ave'], ['af', 'afr'], ['ak', 'aka'], ['am', 'amh'], ['an', 'arg'],
  ['ar', 'ara'], ['as', 'asm'], ['av', 'ava'], ['ay', 'aym'], ['az', 'aze'], ['ba', 'bak'], ['be', 'bel'],
  ['bg', 'bul'], ['bh', 'bih'], ['bi', 'bis'], ['bm', 'bam'], ['bn', 'ben'], ['bo', 'bod'], ['br', 'bre'],
  ['bs', 'bos'], ['ca', 'cat'], ['ce', 'che'], ['ch', 'cha'], ['co', 'cos'], ['cr', 'cre'], ['cs', 'ces'],
  ['cu', 'chu'], ['cv', 'chv'], ['cy', 'cym'], ['da', 'dan'], ['de', 'deu'], ['dv', 'div'], ['dz', 'dzo'],
  ['ee', 'ewe'], ['el', 'ell'], ['en', 'eng'], ['eo', 'epo'], ['es', 'spa'], ['et', 'est'], ['eu', 'eus'],
  ['fa', 'fas'], ['ff', 'ful'], ['fi', 'fin'], ['fj', 'fij'], ['fo', 'fao'], ['fr', 'fra'], ['fy', 'fry'],
  ['ga', 'gle'], ['gd', 'gla'], ['gl', 'glg'], ['gn', 'grn'], ['gu', 'guj'], ['gv', 'glv'], ['ha', 'hau'],
  ['he', 'heb'], ['hi', 'hin'], ['ho', 'hmo'], ['hr', 'hrv'], ['ht', 'hat'], ['hu', 'hun'], ['hy', 'hye'],
  ['hz', 'her'], ['ia', 'ina'], ['id', 'ind'], ['ie', 'ile'], ['ig', 'ibo'], ['ii', 'iii'], ['ik', 'ipk'],
  ['io', 'ido'], ['is', 'isl'], ['it', 'ita'], ['iu', 'iku'], ['ja', 'jpn'], ['jv', 'jav'], ['ka', 'kat'],
  ['kg', 'kon'], ['ki', 'kik'], ['kj', 'kua'], ['kk', 'kaz'], ['kl', 'kal'], ['km', 'khm'], ['kn', 'kan'],
  ['ko', 'kor'], ['kr', 'kau'], ['ks', 'kas'], ['ku', 'kur'], ['kv', 'kom'], ['kw', 'cor'], ['ky', 'kir'],
  ['la', 'lat'], ['lb', 'ltz'], ['lg', 'lug'], ['li', 'lim'], ['ln', 'lin'], ['lo', 'lao'], ['lt', 'lit'],
  ['lu', 'lub'], ['lv', 'lav'], ['mg', 'mlg'], ['mh', 'mah'], ['mi', 'mri'], ['mk', 'mkd'], ['ml', 'mal'],
  ['mn', 'mon'], ['mr', 'mar'], ['ms', 'msa'], ['mt', 'mlt'], ['my', 'mya'], ['na', 'nau'], ['nb', 'nob'],
  ['nd', 'nde'], ['ne', 'nep'], ['ng', 'ndo'], ['nl', 'nld'], ['nn', 'nno'], ['no', 'nor'], ['nr', 'nbl'],
  ['nv', 'nav'], ['ny', 'nya'], ['oc', 'oci'], ['oj', 'oji'], ['om', 'orm'], ['or', 'ori'], ['os', 'oss'],
  ['pa', 'pan'], ['pi', 'pli'], ['pl', 'pol'], ['ps', 'pus'], ['pt', 'por'], ['qu', 'que'], ['rm', 'roh'],
  ['rn', 'run'], ['ro', 'ron'], ['ru', 'rus'], ['rw', 'kin'], ['sa', 'san'], ['sc', 'srd'], ['sd', 'snd'],
  ['se', 'sme'], ['sg', 'sag'], ['si', 'sin'], ['sk', 'slk'], ['sl', 'slv'], ['sm', 'smo'], ['sn', 'sna'],
  ['so', 'som'], ['sq', 'sqi'], ['sr', 'srp'], ['ss', 'ssw'], ['st', 'sot'], ['su', 'sun'], ['sv', 'swe'],
  ['sw', 'swa'], ['ta', 'tam'], ['te', 'tel'], ['tg', 'tgk'], ['th', 'tha'], ['ti', 'tir'], ['tk', 'tuk'],
  ['tl', 'tgl'], ['tn', 'tsn'], ['to', 'ton'], ['tr', 'tur'], ['ts', 'tso'], ['tt', 'tat'], ['tw', 'twi'],
  ['ty', 'tah'], ['ug', 'uig'], ['uk', 'ukr'], ['ur', 'urd'], ['uz', 'uzb'], ['ve', 'ven'], ['vi', 'vie'],
  ['vo', 'vol'], ['wa', 'wln'], ['wo', 'wol'], ['xh', 'xho'], ['yi', 'yid'], ['yo', 'yor'], ['za', 'zha'],
  ['zh', 'zho'], ['zu', 'zul']
];

/** 源 deepLTargetLanguageOptions()（码, 英文名；名称为硬编码英文，不本地化） */
export const DEEPL_TARGET_LANGUAGES: string[][] = [
['ACE', 'Acehnese'],
  ['AF', 'Afrikaans'],
  ['AN', 'Aragonese'],
  ['AR', 'Arabic'],
  ['AS', 'Assamese'],
  ['AY', 'Aymara'],
  ['AZ', 'Azerbaijani'],
  ['BA', 'Bashkir'],
  ['BE', 'Belarusian'],
  ['BG', 'Bulgarian'],
  ['BHO', 'Bhojpuri'],
  ['BN', 'Bengali'],
  ['BR', 'Breton'],
  ['BS', 'Bosnian'],
  ['CA', 'Catalan'],
  ['CEB', 'Cebuano'],
  ['CKB', 'Kurdish (Sorani)'],
  ['CS', 'Czech'],
  ['CY', 'Welsh'],
  ['DA', 'Danish'],
  ['DE', 'German'],
  ['EL', 'Greek'],
  ['EN', 'English'],
  ['EN-GB', 'English (British)'],
  ['EN-US', 'English (American)'],
  ['EO', 'Esperanto'],
  ['ES', 'Spanish'],
  ['ES-419', 'Spanish (Latin American)'],
  ['ET', 'Estonian'],
  ['EU', 'Basque'],
  ['FA', 'Persian'],
  ['FI', 'Finnish'],
  ['FR', 'French'],
  ['GA', 'Irish'],
  ['GL', 'Galician'],
  ['GN', 'Guarani'],
  ['GOM', 'Konkani'],
  ['GU', 'Gujarati'],
  ['HA', 'Hausa'],
  ['HE', 'Hebrew'],
  ['HI', 'Hindi'],
  ['HR', 'Croatian'],
  ['HT', 'Haitian Creole'],
  ['HU', 'Hungarian'],
  ['HY', 'Armenian'],
  ['ID', 'Indonesian'],
  ['IG', 'Igbo'],
  ['IS', 'Icelandic'],
  ['IT', 'Italian'],
  ['JA', 'Japanese'],
  ['JV', 'Javanese'],
  ['KA', 'Georgian'],
  ['KK', 'Kazakh'],
  ['KMR', 'Kurdish (Kurmanji)'],
  ['KO', 'Korean'],
  ['KY', 'Kyrgyz'],
  ['LA', 'Latin'],
  ['LB', 'Luxembourgish'],
  ['LMO', 'Lombard'],
  ['LN', 'Lingala'],
  ['LT', 'Lithuanian'],
  ['LV', 'Latvian'],
  ['MAI', 'Maithili'],
  ['MG', 'Malagasy'],
  ['MI', 'Maori'],
  ['MK', 'Macedonian'],
  ['ML', 'Malayalam'],
  ['MN', 'Mongolian'],
  ['MR', 'Marathi'],
  ['MS', 'Malay'],
  ['MT', 'Maltese'],
  ['MY', 'Burmese'],
  ['NB', 'Norwegian Bokmal'],
  ['NE', 'Nepali'],
  ['NL', 'Dutch'],
  ['OC', 'Occitan'],
  ['OM', 'Oromo'],
  ['PA', 'Punjabi'],
  ['PAG', 'Pangasinan'],
  ['PAM', 'Kapampangan'],
  ['PL', 'Polish'],
  ['PRS', 'Dari'],
  ['PS', 'Pashto'],
  ['PT', 'Portuguese'],
  ['PT-BR', 'Portuguese (Brazilian)'],
  ['PT-PT', 'Portuguese (European)'],
  ['QU', 'Quechua'],
  ['RO', 'Romanian'],
  ['RU', 'Russian'],
  ['SA', 'Sanskrit'],
  ['SCN', 'Sicilian'],
  ['SK', 'Slovak'],
  ['SL', 'Slovenian'],
  ['SQ', 'Albanian'],
  ['SR', 'Serbian'],
  ['ST', 'Sesotho'],
  ['SU', 'Sundanese'],
  ['SV', 'Swedish'],
  ['SW', 'Swahili'],
  ['TA', 'Tamil'],
  ['TE', 'Telugu'],
  ['TG', 'Tajik'],
  ['TH', 'Thai'],
  ['TK', 'Turkmen'],
  ['TL', 'Tagalog'],
  ['TN', 'Tswana'],
  ['TR', 'Turkish'],
  ['TS', 'Tsonga'],
  ['TT', 'Tatar'],
  ['UK', 'Ukrainian'],
  ['UR', 'Urdu'],
  ['UZ', 'Uzbek'],
  ['VI', 'Vietnamese'],
  ['WO', 'Wolof'],
  ['XH', 'Xhosa'],
  ['YI', 'Yiddish'],
  ['YUE', 'Cantonese'],
  ['ZH', 'Chinese'],
  ['ZH-HANS', 'Chinese (simplified)'],
  ['ZH-HANT', 'Chinese (traditional)'],
  ['ZU', 'Zulu']
];

let iso3Map: Map<string, string> | null = null;

function iso3Table(): Map<string, string> {
  if (iso3Map === null) {
    const m = new Map<string, string>();
    for (let i = 0; i < ISO_639_TABLE.length; i++) {
      m.set(ISO_639_TABLE[i][0], ISO_639_TABLE[i][1]);
    }
    iso3Map = m;
  }
  return iso3Map as Map<string, string>;
}

/** 源 Locale.getISOLanguages()（两字母码列表） */
export function isoLanguageCodes(): string[] {
  const out: string[] = [];
  for (let i = 0; i < ISO_639_TABLE.length; i++) {
    out.push(ISO_639_TABLE[i][0]);
  }
  return out;
}

/** 源 Locale.getISO3Language()：两字母码 → 三字母；已是三字母原样；未知返回空串（Java 对空语言同样返回 ""） */
export function toIso3Language(language: string): string {
  const lang = language.trim().toLowerCase();
  const base = lang.indexOf('-') >= 0 ? lang.substring(0, lang.indexOf('-')) : lang;
  const sub = base.indexOf('_') >= 0 ? base.substring(0, base.indexOf('_')) : base;
  if (sub.length === 3) {
    return sub;
  }
  const v = iso3Table().get(sub);
  return v !== undefined ? v : sub;
}

/** 系统当前语言（源 Locale.getDefault()）；不可用时 'en' */
export function systemLanguageTag(): string {
  try {
    const tag = i18n.System.getSystemLanguage();
    if (tag !== undefined && tag !== null && tag.length > 0) {
      return tag;
    }
  } catch (e) {
    console.warn(`LanguageTables: getSystemLanguage failed ${JSON.stringify(e)}`);
  }
  return 'en';
}

/** 显示名所用 locale（源 Locale.getDefault()；getSystemLocale 自 API 20 废弃，用系统语言标签） */
function systemLocaleTag(): string {
  return systemLanguageTag();
}

/** 源 appLang：Locale.getDefault().getISO3Language() */
export function appIso3Language(): string {
  return toIso3Language(systemLanguageTag());
}

/** 源 Locale.forLanguageTag(code).getDisplayLanguage(Locale.getDefault())；取不到返回空串 */
export function displayLanguageName(code: string): string {
  try {
    const name = i18n.System.getDisplayLanguage(code, systemLocaleTag(), false);
    if (name !== undefined && name !== null) {
      return name;
    }
  } catch (e) {
    console.warn(`LanguageTables: getDisplayLanguage(${code}) failed`);
  }
  return '';
}

/** java String.CASE_INSENSITIVE_ORDER（逐字符 toUpperCase 再 toLowerCase 比较） */
export function compareCaseInsensitive(a: string, b: string): number {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    let c1 = a.charAt(i);
    let c2 = b.charAt(i);
    if (c1 !== c2) {
      c1 = c1.toUpperCase();
      c2 = c2.toUpperCase();
      if (c1 !== c2) {
        c1 = c1.toLowerCase();
        c2 = c2.toLowerCase();
        if (c1 !== c2) {
          return c1.charCodeAt(0) - c2.charCodeAt(0);
        }
      }
    }
  }
  return a.length - b.length;
}
