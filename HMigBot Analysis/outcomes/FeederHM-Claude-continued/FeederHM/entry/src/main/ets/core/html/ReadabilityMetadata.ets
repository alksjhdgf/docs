/**
 * ReadabilityMetadata.ets —— readability4j Article 结果对象 + 元数据（标题 _getArticleTitle、meta 作者/摘要）。
 * 从 Readability.ets 拆出以满足单文件 ≤600 行。
 */
import { HtmlNode } from './HtmlNode';
import { HtmlDocument } from './HtmlDocument';
import { getInnerText } from './ReadabilityCleaner';

/** readability4j Article */
export class ReadabilityArticle {
  readonly uri: string;
  title: string | null = null;
  byline: string | null = null;
  excerpt: string | null = null;
  dir: string | null = null;
  articleContent: HtmlNode | null = null;

  constructor(uri: string) {
    this.uri = uri;
  }

  /** 正文 HTML（articleContent.html()，即 readability-page-1 外层 div） */
  get content(): string | null {
    return this.articleContent !== null ? this.articleContent.html() : null;
  }

  get textContent(): string | null {
    return this.articleContent !== null ? this.articleContent.text() : null;
  }

  get length(): number {
    const t: string | null = this.textContent;
    return t !== null ? t.length : -1;
  }

  /** readability4j getContentWithEncoding("utf-8")：包成带 meta charset 的完整 HTML 文档 */
  get contentWithUtf8Encoding(): string | null {
    return this.getContentWithEncoding('utf-8');
  }

  getContentWithEncoding(encoding: string): string | null {
    const c: string | null = this.content;
    if (c === null) {
      return null;
    }
    return '<html>\n  <head>\n    <meta charset="' + encoding + '">\n  </head>\n  <body>\n    ' + c +
      '\n  </body>\n</html>';
  }
}

export function getMetaContent(doc: HtmlDocument, names: string[]): string | null {
  const metas: HtmlNode[] = doc.getElementsByTag('meta');
  for (let n = 0; n < names.length; n++) {
    for (let i = 0; i < metas.length; i++) {
      const key: string = (metas[i].attr('name') + ' ' + metas[i].attr('property')).toLowerCase();
      if (key.split(' ').indexOf(names[n]) >= 0) {
        const c: string = metas[i].attr('content').trim();
        if (c.length > 0) {
          return c;
        }
      }
    }
  }
  return null;
}

function wordCount(s: string): number {
  return s.split(new RegExp('\\s+')).length;
}

/** Readability _getArticleTitle */
export function getArticleTitle(doc: HtmlDocument): string {
  const origTitle: string = doc.title().trim();
  let curTitle: string = origTitle;
  let titleHadHierarchicalSeparators: boolean = false;
  if (new RegExp(' [\\|\\-\\\\\\/>»] ').test(curTitle)) {
    titleHadHierarchicalSeparators = new RegExp(' [\\\\\\/>»] ').test(curTitle);
    curTitle = origTitle.replace(new RegExp('(.*)[\\|\\-\\\\\\/>»] .*', 'gi'), '$1');
    if (wordCount(curTitle) < 3) {
      curTitle = origTitle.replace(new RegExp('[^\\|\\-\\\\\\/>»]*[\\|\\-\\\\\\/>»](.*)', 'gi'), '$1');
    }
  } else if (curTitle.indexOf(': ') !== -1) {
    const headings: HtmlNode[] = doc.getElementsByTag('h1').concat(doc.getElementsByTag('h2'));
    const trimmed: string = curTitle.trim();
    const match: boolean = headings.some((h: HtmlNode): boolean => h.text().trim() === trimmed);
    if (!match) {
      curTitle = origTitle.substring(origTitle.lastIndexOf(':') + 1);
      if (wordCount(curTitle) < 3) {
        curTitle = origTitle.substring(origTitle.indexOf(':') + 1);
      } else if (wordCount(origTitle.substring(0, origTitle.indexOf(':'))) > 5) {
        curTitle = origTitle;
      }
    }
  } else if (curTitle.length > 150 || curTitle.length < 15) {
    const hOnes: HtmlNode[] = doc.getElementsByTag('h1');
    if (hOnes.length === 1) {
      curTitle = getInnerText(hOnes[0]);
    }
  }
  curTitle = curTitle.trim().replace(new RegExp('\\s{2,}', 'g'), ' ');
  const curTitleWordCount: number = wordCount(curTitle);
  if (curTitleWordCount <= 4 && (!titleHadHierarchicalSeparators ||
    curTitleWordCount !== wordCount(origTitle.replace(new RegExp('[\\|\\-\\\\\\/>»]+', 'g'), '')) - 1)) {
    curTitle = origTitle;
  }
  return curTitle;
}
