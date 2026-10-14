/**
 * ArticleFilterRules.ets —— 源 model/ArticleFilterRules.kt（每源 block/allow 规则，仿 Miniflux）。
 *
 * - 规则文本每行一条 `Field=regex`，只在第一个 `=` 处切分；字段名大小写不敏感（FS-A36）。
 * - 无效行记录错误后跳过：MissingSeparator / UnknownField / EmptyPattern / InvalidRegex；
 *   第 101 条起 TooManyRules，该行及其后全部忽略（FS-A37）。
 * - 判定：屏蔽优先；无允许规则则保留；有则只让适用的允许规则投票（FS-A38）。
 * - 匹配为正则"包含匹配"，缺失字段按 "" 匹配；超过 100000 字只搜前 100000 字，`$` 不在截断处命中（FS-A39）。
 *
 * Java regex → JS RegExp 方言兼容（JavaRegexDialect）：前导内联标志 `(?imsdu U)`、`\A` `\z` `\Z`、
 * Java 非 MULTILINE 的 `$`（行尾终止符之前）、`\Q..\E`、占有量词/原子组（近似为贪婪/非捕获组）、`\p{..}`（启用 u 标志）。
 * 不支持的写法（模式中部的内联标志、COMMENTS 标志 x、Java 专有 \p{javaXxx}/\p{Alpha} 等）编译失败 → InvalidRegex。
 */
import { ParsedArticle } from '../model/Parsed';

export enum ArticleRuleField {
  TITLE = 'Title',
  URL = 'URL',
  AUTHOR = 'Author',
  TAG = 'Tag',
  CONTENT = 'Content',
}

const ALL_FIELDS: ArticleRuleField[] = [
  ArticleRuleField.TITLE, ArticleRuleField.URL, ArticleRuleField.AUTHOR, ArticleRuleField.TAG, ArticleRuleField.CONTENT,
];

/** 源 ArticleRuleField.fromFieldName：大小写不敏感 */
export function articleRuleFieldFromName(fieldName: string): ArticleRuleField | null {
  const lower: string = fieldName.toLowerCase();
  for (let i = 0; i < ALL_FIELDS.length; i++) {
    if ((ALL_FIELDS[i] as string).toLowerCase() === lower) {
      return ALL_FIELDS[i];
    }
  }
  return null;
}

/** Kotlin CharSequence.isBlank() */
function isBlankText(s: string): boolean {
  return s.trim().length === 0;
}

// ============================================================ Java regex 方言

/** 编译失败（≙ PatternSyntaxException） */
export class PatternSyntaxError extends Error {
  readonly description: string;

  constructor(description: string) {
    super(description);
    this.name = 'PatternSyntaxError';
    this.description = description;
  }
}

/** Java 非 MULTILINE 的 `$` / `\Z`：输入末尾，或末尾单个行终止符之前 */
const END_BEFORE_FINAL_TERMINATOR: string = '(?=(?:\\r\\n|[\\n\\r\\u0085\\u2028\\u2029])?(?![\\s\\S]))';
const ABSOLUTE_END: string = '(?![\\s\\S])';
const ABSOLUTE_START: string = '(?<![\\s\\S])';
const REGEX_META: string = '\\^$.|?*+()[]{}';

function escapeLiteral(s: string): string {
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const c: string = s.charAt(i);
    out += REGEX_META.indexOf(c) >= 0 ? '\\' + c : c;
  }
  return out;
}

/** 翻译结果 */
export class JavaRegexTranslation {
  source: string = '';
  flags: string = '';
}

/**
 * 把 Java Pattern 语法翻译为 JS RegExp 源串与标志。无法翻译的写法抛 PatternSyntaxError。
 */
export function translateJavaRegex(pattern: string): JavaRegexTranslation {
  let rest: string = pattern;
  let flagI: boolean = false;
  let flagM: boolean = false;
  let flagS: boolean = false;
  // 前导内联标志组，可多个：(?i)(?s)
  const leading: RegExp = new RegExp('^\\(\\?([a-zA-Z]+)\\)');
  let m: RegExpMatchArray | null = rest.match(leading);
  while (m !== null) {
    const fl: string = m[1];
    for (let i = 0; i < fl.length; i++) {
      const c: string = fl.charAt(i);
      if (c === 'i') {
        flagI = true;
      } else if (c === 'm') {
        flagM = true;
      } else if (c === 's') {
        flagS = true;
      } else if (c === 'd' || c === 'u' || c === 'U') {
        // UNIX_LINES / UNICODE_CASE / UNICODE_CHARACTER_CLASS：JS 无直接等价，忽略
      } else {
        throw new PatternSyntaxError(`Unsupported inline flag '${c}' near index ${i + 2}`);
      }
    }
    rest = rest.substring(m[0].length);
    m = rest.match(leading);
  }

  let out: string = '';
  let inClass: boolean = false;
  let needUnicode: boolean = false;
  let i: number = 0;
  while (i < rest.length) {
    const c: string = rest.charAt(i);
    if (c === '\\') {
      if (i + 1 >= rest.length) {
        throw new PatternSyntaxError(`Unexpected internal error near index ${pattern.length}`);
      }
      const n: string = rest.charAt(i + 1);
      if (n === 'Q') {
        const end: number = rest.indexOf('\\E', i + 2);
        const lit: string = end < 0 ? rest.substring(i + 2) : rest.substring(i + 2, end);
        out += escapeLiteral(lit);
        i = end < 0 ? rest.length : end + 2;
        continue;
      }
      if (!inClass && n === 'A') {
        out += ABSOLUTE_START;
      } else if (!inClass && n === 'z') {
        out += ABSOLUTE_END;
      } else if (!inClass && n === 'Z') {
        out += END_BEFORE_FINAL_TERMINATOR;
      } else {
        if (n === 'p' || n === 'P') {
          needUnicode = true;
        }
        out += c + n;
      }
      i += 2;
      continue;
    }
    if (inClass) {
      if (c === ']') {
        inClass = false;
      }
      out += c;
      i++;
      continue;
    }
    if (c === '[') {
      inClass = true;
      out += c;
      i++;
      // 紧随的 ^ 与 ] 属于字符类字面量
      if (i < rest.length && rest.charAt(i) === '^') {
        out += '^';
        i++;
      }
      if (i < rest.length && rest.charAt(i) === ']') {
        out += '\\]';
        i++;
      }
      continue;
    }
    if (c === '$') {
      out += flagM ? '$' : END_BEFORE_FINAL_TERMINATOR;
      i++;
      continue;
    }
    if (c === '(' && rest.startsWith('(?>', i)) {
      // 原子组 → 非捕获组（近似）
      out += '(?:';
      i += 3;
      continue;
    }
    if (c === '+' && i > 0 && out.length > 0) {
      const prev: string = rest.charAt(i - 1);
      const prevEscaped: boolean = i >= 2 && rest.charAt(i - 2) === '\\';
      if (!prevEscaped && (prev === '*' || prev === '+' || prev === '?' || prev === '}')) {
        // 占有量词 → 贪婪量词（近似）
        i++;
        continue;
      }
    }
    out += c;
    i++;
  }
  const t: JavaRegexTranslation = new JavaRegexTranslation();
  t.source = out;
  t.flags = (flagI ? 'i' : '') + (flagM ? 'm' : '') + (flagS ? 's' : '') + (needUnicode ? 'u' : '');
  return t;
}

function compileOrThrow(source: string, flags: string): RegExp {
  try {
    return new RegExp(source, flags);
  } catch (e) {
    const msg: string = (e as Error).message;
    throw new PatternSyntaxError(msg);
  }
}

// ============================================================ ArticleRule

/**
 * A single `FieldName=regex` rule.
 * equals 只比较 (field, pattern)。构造时正则非法会抛 PatternSyntaxError；请经 ArticleRuleSet.parse 构建。
 */
export class ArticleRule {
  /**
   * Bounds worst-case backtracking on large article bodies. Values longer than
   * this are searched only up to this length.
   */
  static readonly MAX_MATCHED_LENGTH: number = 100000;
  /** 截断搜索时保留在窗口之后、供环视"透明边界"看到的上下文长度 */
  private static readonly TRANSPARENT_CONTEXT: number = 1024;

  readonly field: ArticleRuleField;
  readonly pattern: string;
  private readonly regex: RegExp;
  private readonly translation: JavaRegexTranslation;
  private boundedRegex: RegExp | null = null;
  private boundedContext: number = -1;

  constructor(field: ArticleRuleField, pattern: string) {
    this.field = field;
    this.pattern = pattern;
    this.translation = translateJavaRegex(pattern);
    this.regex = compileOrThrow(this.translation.source, this.translation.flags);
  }

  equals(other: ArticleRule | null): boolean {
    return other !== null && other.field === this.field && other.pattern === this.pattern;
  }

  toString(): string {
    return `ArticleRule(field=${this.field}, pattern=${this.pattern})`;
  }

  matches(article: ParsedArticle): boolean {
    switch (this.field) {
      case ArticleRuleField.TITLE:
        return this.matchesValue(article.title);
      case ArticleRuleField.URL:
        return this.matchesValue(article.url);
      case ArticleRuleField.AUTHOR:
        return this.matchesValue(article.author !== null ? article.author.name : null);
      case ArticleRuleField.CONTENT: {
        // content_text is never null for parsed feeds ("" at worst), so the fallback tests blankness.
        const text: string | null = article.content_text;
        return this.matchesValue(text !== null && !isBlankText(text) ? text : article.content_html);
      }
      case ArticleRuleField.TAG: {
        // An article with no tags matches no Tag rule at all — not even ".*".
        const tags: string[] | null = article.tags;
        if (tags === null) {
          return false;
        }
        for (let i = 0; i < tags.length; i++) {
          if (this.matchesValue(tags[i])) {
            return true;
          }
        }
        return false;
      }
      default:
        return false;
    }
  }

  /** Only Tag can be inapplicable: an untagged article is judged only by the allow rules that can be evaluated. */
  appliesTo(article: ParsedArticle): boolean {
    if (this.field === ArticleRuleField.TAG) {
      return article.tags !== null && article.tags.length > 0;
    }
    return true;
  }

  /** Missing scalars match as "", mirroring Go's zero-value strings. */
  private matchesValue(value: string | null): boolean {
    const text: string = value !== null ? value : '';
    const max: number = ArticleRule.MAX_MATCHED_LENGTH;
    if (text.length <= max) {
      this.regex.lastIndex = 0;
      return this.regex.test(text);
    }
    // 只搜索前 max 个字符，但截断点不得冒充文本末尾（Java region + transparent + 非 anchoring bounds）：
    // 保留窗口之后的一段上下文供环视观察，并要求匹配结束位置 ≤ max（其后仍剩 context 个字符）。
    const context: number = Math.min(text.length - max, ArticleRule.TRANSPARENT_CONTEXT);
    const window: string = text.substring(0, max + context);
    return this.boundedFor(context).test(window);
  }

  private boundedFor(context: number): RegExp {
    if (this.boundedRegex === null || this.boundedContext !== context) {
      this.boundedRegex = new RegExp(`(?:${this.translation.source})(?=[\\s\\S]{${context}})`, this.translation.flags);
      this.boundedContext = context;
    }
    const r: RegExp = this.boundedRegex as RegExp;
    r.lastIndex = 0;
    return r;
  }
}

// ============================================================ 错误

/** Why one line was rejected. lineNumber is 1-based over the raw text. */
export abstract class ArticleRuleError {
  /** 源类名（判别）：MissingSeparator / UnknownField / EmptyPattern / InvalidRegex / TooManyRules */
  readonly kind: string;
  readonly lineNumber: number;

  protected constructor(kind: string, lineNumber: number) {
    this.kind = kind;
    this.lineNumber = lineNumber;
  }

  abstract equals(other: ArticleRuleError | null): boolean;
}

export class MissingSeparator extends ArticleRuleError {
  constructor(lineNumber: number) {
    super('MissingSeparator', lineNumber);
  }

  equals(other: ArticleRuleError | null): boolean {
    return other instanceof MissingSeparator && other.lineNumber === this.lineNumber;
  }
}

export class UnknownField extends ArticleRuleError {
  readonly fieldName: string;

  constructor(lineNumber: number, fieldName: string) {
    super('UnknownField', lineNumber);
    this.fieldName = fieldName;
  }

  equals(other: ArticleRuleError | null): boolean {
    return other instanceof UnknownField && other.lineNumber === this.lineNumber &&
      (other as UnknownField).fieldName === this.fieldName;
  }
}

export class EmptyPattern extends ArticleRuleError {
  constructor(lineNumber: number) {
    super('EmptyPattern', lineNumber);
  }

  equals(other: ArticleRuleError | null): boolean {
    return other instanceof EmptyPattern && other.lineNumber === this.lineNumber;
  }
}

export class InvalidRegex extends ArticleRuleError {
  readonly reason: string;

  constructor(lineNumber: number, reason: string) {
    super('InvalidRegex', lineNumber);
    this.reason = reason;
  }

  equals(other: ArticleRuleError | null): boolean {
    return other instanceof InvalidRegex && other.lineNumber === this.lineNumber &&
      (other as InvalidRegex).reason === this.reason;
  }
}

/** The line is valid but exceeds MAX_RULES; it and every later line are ignored. */
export class TooManyRules extends ArticleRuleError {
  readonly maxRules: number;

  constructor(lineNumber: number, maxRules: number) {
    super('TooManyRules', lineNumber);
    this.maxRules = maxRules;
  }

  equals(other: ArticleRuleError | null): boolean {
    return other instanceof TooManyRules && other.lineNumber === this.lineNumber &&
      (other as TooManyRules).maxRules === this.maxRules;
  }
}

// ============================================================ 规则集

export class ArticleRuleSet {
  static readonly MAX_RULES: number = 100;
  static readonly EMPTY: ArticleRuleSet = new ArticleRuleSet([], []);

  readonly rules: ArticleRule[];
  readonly errors: ArticleRuleError[];

  constructor(rules: ArticleRule[], errors: ArticleRuleError[]) {
    this.rules = rules;
    this.errors = errors;
  }

  equals(other: ArticleRuleSet | null): boolean {
    if (other === null || other.rules.length !== this.rules.length || other.errors.length !== this.errors.length) {
      return false;
    }
    for (let i = 0; i < this.rules.length; i++) {
      if (!this.rules[i].equals(other.rules[i])) {
        return false;
      }
    }
    for (let i = 0; i < this.errors.length; i++) {
      if (!this.errors[i].equals(other.errors[i])) {
        return false;
      }
    }
    return true;
  }

  /**
   * Parses one `FieldName=regex` rule per line. Blank lines are skipped without
   * shifting the line numbers of later lines. Invalid lines produce an ArticleRuleError instead of throwing.
   */
  static parse(text: string): ArticleRuleSet {
    if (isBlankText(text)) {
      return ArticleRuleSet.EMPTY;
    }
    const rules: ArticleRule[] = [];
    const errors: ArticleRuleError[] = [];
    // Kotlin lineSequence：\r\n、\n、\r 均为行分隔
    const lines: string[] = text.split(new RegExp('\\r\\n|\\n|\\r'));
    for (let index = 0; index < lines.length; index++) {
      const lineNumber: number = index + 1;
      const line: string = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      const separatorIndex: number = line.indexOf('=');
      if (separatorIndex < 0) {
        errors.push(new MissingSeparator(lineNumber));
        continue;
      }
      const fieldName: string = line.substring(0, separatorIndex).trim();
      // Split on the first '=' only, so patterns may contain '='.
      const pattern: string = line.substring(separatorIndex + 1).trim();
      const field: ArticleRuleField | null = articleRuleFieldFromName(fieldName);
      if (field === null) {
        errors.push(new UnknownField(lineNumber, fieldName));
        continue;
      }
      // An empty pattern would match everything and silently swallow an entire feed.
      if (pattern.length === 0) {
        errors.push(new EmptyPattern(lineNumber));
        continue;
      }
      if (rules.length >= ArticleRuleSet.MAX_RULES) {
        errors.push(new TooManyRules(lineNumber, ArticleRuleSet.MAX_RULES));
        break;
      }
      try {
        rules.push(new ArticleRule(field, pattern));
      } catch (e) {
        const reason: string = e instanceof PatternSyntaxError ? (e as PatternSyntaxError).description :
          (e instanceof Error ? (e as Error).message : '');
        errors.push(new InvalidRegex(lineNumber, reason));
      }
    }
    return new ArticleRuleSet(rules, errors);
  }
}

export class ArticleFilterRules {
  static readonly NONE: ArticleFilterRules = new ArticleFilterRules([], []);

  readonly blockRules: ArticleRule[];
  readonly allowRules: ArticleRule[];

  constructor(blockRules: ArticleRule[], allowRules: ArticleRule[]) {
    this.blockRules = blockRules;
    this.allowRules = allowRules;
  }

  get isNoOp(): boolean {
    return this.blockRules.length === 0 && this.allowRules.length === 0;
  }

  static compile(blockRulesText: string, allowRulesText: string): ArticleFilterRules {
    const blockRules: ArticleRule[] = ArticleRuleSet.parse(blockRulesText).rules;
    const allowRules: ArticleRule[] = ArticleRuleSet.parse(allowRulesText).rules;
    if (blockRules.length === 0 && allowRules.length === 0) {
      return ArticleFilterRules.NONE;
    }
    return new ArticleFilterRules(blockRules, allowRules);
  }
}

export class ArticleFilterPolicy {
  /**
   * Block rules are evaluated first and the first match drops the item. Then, if any allow rules exist,
   * the item must match at least one of the allow rules that apply to it (none applicable → keep).
   * Invalid rules are dropped at parse time, so a feed whose rules are all invalid fails open.
   */
  static shouldKeep(article: ParsedArticle, rules: ArticleFilterRules): boolean {
    if (rules.isNoOp) {
      return true;
    }
    for (let i = 0; i < rules.blockRules.length; i++) {
      if (rules.blockRules[i].matches(article)) {
        return false;
      }
    }
    if (rules.allowRules.length === 0) {
      return true;
    }
    const applicable: ArticleRule[] =
      rules.allowRules.filter((r: ArticleRule): boolean => r.appliesTo(article));
    if (applicable.length === 0) {
      return true;
    }
    for (let i = 0; i < applicable.length; i++) {
      if (applicable[i].matches(article)) {
        return true;
      }
    }
    return false;
  }
}
