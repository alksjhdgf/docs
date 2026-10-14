/*
 * LanguageDetector — Context.detectLocaleFromText(text, minConfidence) 的鸿蒙替代。
 * 源：model/LocaleDetection（android.view.textclassifier.TextClassifier.detectLanguage → TextLanguage，按置信度降序）。
 * 鸿蒙 SDK 无文本语种识别 API（@kit.LocalizationKit/@hms.ai.nlp.textProcessing 均无），此处为纯 ArkTS 启发式：
 *   1) 非拉丁文字按字符区段判定（日/中/韩/俄乌保白/希腊/希伯来/阿拉伯波斯/泰/天城…）；
 *   2) 拉丁文字按各语言高频功能词命中计分（每个词按其所属语言数均分权重），置信度 = 首位得分 / 总得分 × 覆盖修正。
 * 置信度量纲与源一致（0..100），供 95%（"已是目标语言"）与 60%（本地翻译源语言）门槛使用。
 */

export class DetectedLocale {
  languageTag: string;
  /** 0..100 */
  confidence: number;

  constructor(languageTag: string, confidence: number) {
    this.languageTag = languageTag;
    this.confidence = confidence;
  }
}

class ScriptCounts {
  latin: number = 0;
  cyrillic: number = 0;
  greek: number = 0;
  hebrew: number = 0;
  arabic: number = 0;
  persianOnly: number = 0;
  urduOnly: number = 0;
  devanagari: number = 0;
  thai: number = 0;
  hangul: number = 0;
  kana: number = 0;
  han: number = 0;
  bengali: number = 0;
  tamil: number = 0;
  other: number = 0;
  ukOnly: number = 0;
  beOnly: number = 0;
  ruOnly: number = 0;
  bgHard: number = 0;
  srOnly: number = 0;
}

const STOPWORDS: Map<string, string> = new Map<string, string>([
  ['en', 'the a and of to is in that it for was with on as are be this have from by at not but or an they which you he she we has been were their will would there what about'],
  ['de', 'der die das und in ist nicht ein eine zu den mit sich des auf für im dem von auch es sind wird werden bei nach aus wie oder aber wir ich sie hat noch über'],
  ['fr', 'le la les et est des un une du en que qui dans pour pas sur au avec il elle sont ce cette par plus ne se nous vous mais ont être été aux leur'],
  ['es', 'el la los las y a es de que en un una del por para con no se su al lo como más pero sus le ya está son fue han este esta muy también'],
  ['pt', 'o a os as e é de que em um uma do da dos das para com não se por mais como mas foi são ao ele ela seu sua isso também está pelo pela'],
  ['it', 'il la le e a in è di che un una del della per con non si sono gli dei delle al nel alla ma come più anche questo questa lo ha suo sua essere'],
  ['nl', 'de het een en is van dat in te op niet zijn met voor die er aan ook als maar bij om dit ze hij wordt worden naar heeft nog door over'],
  ['sv', 'och att det är en ett som på av för med till inte den har de om var jag men ska kan sig från eller vid när detta också här'],
  ['da', 'og at det er en et som på af for med til ikke den har de om var jeg men skal kan sig fra eller ved når dette også her være'],
  ['nb', 'og at det er en et som på av for med til ikke den har de om var jeg men skal kan seg fra eller ved når dette også her være ble'],
  ['fi', 'ja on ei se että oli ovat mutta kun myös tai hän joka sen ole niin vain kuin jo nyt tämä ovat olla mukaan sekä'],
  ['pl', 'i w na nie się z do jest to że jak o po co ale od za tak jego przez są dla już tylko może być było jako oraz które'],
  ['cs', 'a v na je se z do že to s o jak ale by jsou pro od jeho který která které tak jsem také byl bylo jako podle již'],
  ['sk', 'a v na je sa z do že to s o ako ale by sú pre od jeho ktorý ktorá ktoré tak som tiež bol bolo podľa už'],
  ['ro', 'și în de la a cu că nu este un o pe din pentru care sunt mai ce se lui al ale prin fost această acest sau'],
  ['hu', 'a az és hogy nem is egy van meg de ez azt csak már volt mint még el kell lesz vagy ha minden után pedig'],
  ['tr', 've bir bu da de için ile ne çok daha gibi ama olan olarak kadar sonra en mı mi değil var ise ya her şey'],
  ['id', 'dan yang di ini itu dengan untuk tidak dari dalam akan pada juga ke ada oleh karena adalah mereka kami kita sudah bisa'],
  ['ca', 'i el la els les de que en un una per amb no es del al com més però són va ha aquest aquesta també seu'],
  ['hr', 'i je u na se da za su od kao ali što bio bila sam iz ne to koji koja koje ili biti će'],
  ['sl', 'in je v na se da za so od kot ali ki bil bila sem iz ne to tudi pa še bo'],
  ['lt', 'ir yra kad ne su į iš o bet tai jis ji buvo kaip taip pat jo jų'],
  ['lv', 'un ir ka ne ar uz no bet tas viņš viņa bija kā arī par to'],
  ['et', 'ja on ei et see oli mis kui ka aga nii või tema mida veel'],
  ['is', 'og að er í á sem ekki við um það til með var hann hún fyrir'],
  ['vi', 'và của là có không trong được cho các những một người này với đã đến khi']
]);

let stopwordIndex: Map<string, string[]> | null = null;

function index(): Map<string, string[]> {
  if (stopwordIndex !== null) {
    return stopwordIndex;
  }
  const idx = new Map<string, string[]>();
  STOPWORDS.forEach((words: string, lang: string) => {
    const list = words.split(' ');
    for (let i = 0; i < list.length; i++) {
      const w = list[i];
      if (w.length === 0) {
        continue;
      }
      const langs = idx.get(w);
      if (langs === undefined) {
        idx.set(w, [lang]);
      } else if (langs.indexOf(lang) < 0) {
        langs.push(lang);
      }
    }
  });
  stopwordIndex = idx;
  return idx;
}

function countScripts(text: string): ScriptCounts {
  const c = new ScriptCounts();
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if ((code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a) || (code >= 0xc0 && code <= 0x24f && code !== 0xd7 &&
      code !== 0xf7) || (code >= 0x1e00 && code <= 0x1eff)) {
      c.latin++;
    } else if (code >= 0x0400 && code <= 0x04ff) {
      c.cyrillic++;
      if (code === 0x0456 || code === 0x0457 || code === 0x0454 || code === 0x0491 || code === 0x0406 || code === 0x0407 ||
        code === 0x0404 || code === 0x0490) {
        c.ukOnly++;
      }
      if (code === 0x045e || code === 0x040e) {
        c.beOnly++;
      }
      if (code === 0x044b || code === 0x044d || code === 0x0451 || code === 0x042b || code === 0x042d) {
        c.ruOnly++;
      }
      if (code === 0x044a) {
        c.bgHard++;
      }
      if (code === 0x0458 || code === 0x0459 || code === 0x045a || code === 0x045b || code === 0x045f || code === 0x0452) {
        c.srOnly++;
      }
    } else if (code >= 0x0370 && code <= 0x03ff) {
      c.greek++;
    } else if (code >= 0x0590 && code <= 0x05ff) {
      c.hebrew++;
    } else if (code >= 0x0600 && code <= 0x06ff) {
      c.arabic++;
      if (code === 0x067e || code === 0x0686 || code === 0x0698 || code === 0x06af || code === 0x06cc) {
        c.persianOnly++;
      }
      if (code === 0x0679 || code === 0x0688 || code === 0x0691 || code === 0x06ba || code === 0x06be || code === 0x06d2) {
        c.urduOnly++;
      }
    } else if (code >= 0x0900 && code <= 0x097f) {
      c.devanagari++;
    } else if (code >= 0x0980 && code <= 0x09ff) {
      c.bengali++;
    } else if (code >= 0x0b80 && code <= 0x0bff) {
      c.tamil++;
    } else if (code >= 0x0e00 && code <= 0x0e7f) {
      c.thai++;
    } else if ((code >= 0xac00 && code <= 0xd7a3) || (code >= 0x1100 && code <= 0x11ff) || (code >= 0x3130 && code <= 0x318f)) {
      c.hangul++;
    } else if (code >= 0x3040 && code <= 0x30ff) {
      c.kana++;
    } else if ((code >= 0x4e00 && code <= 0x9fff) || (code >= 0x3400 && code <= 0x4dbf)) {
      c.han++;
    } else if (code > 0x7f && code < 0xd800) {
      const ch = text.charAt(i);
      if (ch.toLowerCase() !== ch.toUpperCase()) {
        c.other++;
      }
    }
  }
  return c;
}

function tokenize(text: string): string[] {
  const out: string[] = [];
  let cur = '';
  const lower = text.toLowerCase();
  for (let i = 0; i < lower.length; i++) {
    const ch = lower.charAt(i);
    const code = lower.charCodeAt(i);
    const isWordChar = (code >= 0x61 && code <= 0x7a) || (code >= 0xc0 && code <= 0x24f && code !== 0xd7 && code !== 0xf7) ||
      (code >= 0x1e00 && code <= 0x1eff) || code === 0x27;
    if (isWordChar) {
      cur += ch;
    } else if (cur.length > 0) {
      out.push(cur);
      cur = '';
    }
  }
  if (cur.length > 0) {
    out.push(cur);
  }
  return out;
}

function detectLatin(text: string): DetectedLocale[] {
  const tokens = tokenize(text);
  if (tokens.length === 0) {
    return [];
  }
  const idx = index();
  const scores = new Map<string, number>();
  const supportCount = new Map<string, number>();
  const rank = new Map<string, number>();
  let hitTokens = 0;
  for (let i = 0; i < tokens.length; i++) {
    const langs = idx.get(tokens[i]);
    if (langs === undefined) {
      continue;
    }
    hitTokens++;
    const weight = 1 / langs.length;
    for (let j = 0; j < langs.length; j++) {
      const prev = scores.get(langs[j]);
      scores.set(langs[j], (prev !== undefined ? prev : 0) + weight);
      const sc = supportCount.get(langs[j]);
      supportCount.set(langs[j], (sc !== undefined ? sc : 0) + 1);
    }
  }
  if (hitTokens === 0) {
    return [];
  }
  // 覆盖修正：功能词占比过低（< 15%）时整体降权（例如专有名词堆砌、代码片段）
  const coverage = hitTokens / tokens.length;
  const coverageFactor = Math.min(1, coverage / 0.15);
  // 样本过短时降权（少于 4 个命中词不足以给出高置信度）
  const sizeFactor = Math.min(1, hitTokens / 4);
  const out: DetectedLocale[] = [];
  scores.forEach((v: number, lang: string) => {
    // 置信度：命中的功能词中可归属该语言的比例（排序仍按独占加权得分）
    const support = supportCount.get(lang);
    const ratio = (support !== undefined ? support : 0) / hitTokens;
    const d = new DetectedLocale(lang, ratio * 100 * coverageFactor * sizeFactor);
    rank.set(lang, v);
    out.push(d);
  });
  out.sort((a: DetectedLocale, b: DetectedLocale) => {
    const ra = rank.get(a.languageTag);
    const rb = rank.get(b.languageTag);
    return (rb !== undefined ? rb : 0) - (ra !== undefined ? ra : 0);
  });
  return out;
}

function detectCyrillic(c: ScriptCounts, share: number): DetectedLocale {
  let lang = 'ru';
  if (c.ukOnly > 0 && c.ukOnly >= c.ruOnly) {
    lang = 'uk';
  } else if (c.beOnly > 0 && c.beOnly >= c.ruOnly) {
    lang = 'be';
  } else if (c.srOnly > 0 && c.srOnly >= c.ruOnly) {
    lang = 'sr';
  } else if (c.ruOnly === 0 && c.bgHard * 50 >= c.cyrillic) {
    lang = 'bg';
  }
  return new DetectedLocale(lang, share * 100);
}

function scriptResult(c: ScriptCounts, letters: number): DetectedLocale | null {
  const pick = (count: number): number => count / letters;
  if (c.kana > 0 && (c.kana + c.han) / letters >= 0.5) {
    return new DetectedLocale('ja', pick(c.kana + c.han) * 100);
  }
  if (c.hangul / letters >= 0.5) {
    return new DetectedLocale('ko', pick(c.hangul + c.han) * 100);
  }
  if (c.han / letters >= 0.5) {
    return new DetectedLocale('zh', pick(c.han) * 100);
  }
  if (c.cyrillic / letters >= 0.5) {
    return detectCyrillic(c, pick(c.cyrillic));
  }
  if (c.greek / letters >= 0.5) {
    return new DetectedLocale('el', pick(c.greek) * 100);
  }
  if (c.hebrew / letters >= 0.5) {
    return new DetectedLocale('he', pick(c.hebrew) * 100);
  }
  if (c.arabic / letters >= 0.5) {
    const lang = c.urduOnly > 0 && c.urduOnly >= c.persianOnly ? 'ur' : (c.persianOnly > 0 ? 'fa' : 'ar');
    return new DetectedLocale(lang, pick(c.arabic) * 100);
  }
  if (c.devanagari / letters >= 0.5) {
    return new DetectedLocale('hi', pick(c.devanagari) * 100);
  }
  if (c.bengali / letters >= 0.5) {
    return new DetectedLocale('bn', pick(c.bengali) * 100);
  }
  if (c.tamil / letters >= 0.5) {
    return new DetectedLocale('ta', pick(c.tamil) * 100);
  }
  if (c.thai / letters >= 0.5) {
    return new DetectedLocale('th', pick(c.thai) * 100);
  }
  return null;
}

/**
 * 源 Context.detectLocaleFromText(text, minConfidence)：返回置信度 ≥ minConfidence 的候选（降序）。
 * 无法判定时返回空表。
 */
export function detectLocaleFromText(text: string, minConfidence: number): DetectedLocale[] {
  const c = countScripts(text);
  const letters = c.latin + c.cyrillic + c.greek + c.hebrew + c.arabic + c.devanagari + c.thai + c.hangul + c.kana + c.han +
    c.bengali + c.tamil + c.other;
  if (letters === 0) {
    return [];
  }
  let results: DetectedLocale[] = [];
  const script = scriptResult(c, letters);
  if (script !== null) {
    results = [script];
  } else if (c.latin / letters >= 0.5) {
    const latinShare = c.latin / letters;
    results = detectLatin(text).map((d: DetectedLocale) => new DetectedLocale(d.languageTag, d.confidence * latinShare));
  }
  return results.filter((d: DetectedLocale) => d.confidence >= minConfidence);
}
