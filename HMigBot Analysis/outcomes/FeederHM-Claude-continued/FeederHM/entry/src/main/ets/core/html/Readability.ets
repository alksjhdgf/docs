/**
 * Readability.ets —— readability4j（Readability4JExtended 1.0.8）正文抽取算法移植于 core/html 自研 DOM。
 *
 * 流程（照 readability4j/Readability.js）：parseHtml → Preprocessor（去脚本/样式/注释、br→p、font→span）
 * → 元数据（标题/作者/摘要）→ grabArticle（候选打分、顶级候选、兄弟合并、prepArticle 清理；
 * 正文 < 500 字符时依次关闭 STRIP_UNLIKELYS / WEIGHT_CLASSES / CLEAN_CONDITIONALLY 重试，最后取最长尝试）
 * → Postprocessor（相对 URL 绝对化、只保留 readability-styled/page 两个 class）。
 * 输出 ReadabilityArticle：content（readability-page-1 外层 div 的 HTML）、contentWithUtf8Encoding、dir、title…
 * 与 Android 输出不保证逐字节一致（Jsoup 漂亮打印缩进等）；台账未登记，见降级候选 deg-acc-readability（spec/plan/ledger-recover/acc-deg.json，待裁决）。
 */
import { HtmlNode } from './HtmlNode';
import { HtmlDocument } from './HtmlDocument';
import { parseHtml } from './HtmlParser';
import { ReadabilityArticle, getArticleTitle, getMetaContent } from './ReadabilityMetadata';
import {
  ALTER_TO_DIV_EXCEPTIONS, DEFAULT_TAGS_TO_SCORE, FLAG_CLEAN_CONDITIONALLY, FLAG_STRIP_UNLIKELYS,
  FLAG_WEIGHT_CLASSES, READABILITY_STYLED, RE_BYLINE, RE_NEGATIVE, RE_OK_MAYBE_CANDIDATE, RE_POSITIVE,
  RE_UNLIKELY_CANDIDATES, RE_VIDEOS, cleanClasses, cleanShareNodes, cleanStyles, cleanTag, descendantsByTag,
  fixRelativeUris, getCharCount, getInnerText, getLinkDensity, getNextNode, getNodeAncestors, hasAncestorTag,
  hasChildBlockElement, hasSingleTagInsideElement, isElementWithoutContent, isProbablyVisible, markDataTables,
  prepareDocument, removeAndGetNext, removeExtraParagraphs, removeNodes
} from './ReadabilityCleaner';
export { ReadabilityArticle } from './ReadabilityMetadata';

const DEFAULT_N_TOP_CANDIDATES: number = 5;
const DEFAULT_CHAR_THRESHOLD: number = 500;
const MINIMUM_TOPCANDIDATES: number = 3;

class Attempt {
  articleContent: HtmlNode;
  textLength: number;

  constructor(articleContent: HtmlNode, textLength: number) {
    this.articleContent = articleContent;
    this.textLength = textLength;
  }
}

/** readability4j Readability4J(uri, html).parse() */
export class Readability {
  private readonly uri: string;
  private readonly html: string;
  private flags: number = FLAG_STRIP_UNLIKELYS | FLAG_WEIGHT_CLASSES | FLAG_CLEAN_CONDITIONALLY;
  private scores: Map<HtmlNode, number> = new Map<HtmlNode, number>();
  private dataTables: Set<HtmlNode> = new Set<HtmlNode>();
  private articleByline: string | null = null;
  private articleDir: string | null = null;
  private articleTitle: string = '';

  constructor(uri: string, html: string) {
    this.uri = uri;
    this.html = html;
  }

  parse(): ReadabilityArticle {
    const doc: HtmlDocument = parseHtml(this.html, this.uri);
    const article: ReadabilityArticle = new ReadabilityArticle(this.uri);
    prepareDocument(doc);
    this.articleTitle = getArticleTitle(doc);
    const metaByline: string | null = getMetaContent(doc, ['author', 'dc:creator', 'twitter:creator']);
    const articleContent: HtmlNode | null = this.grabArticle(doc);
    if (articleContent !== null) {
      fixRelativeUris(articleContent, doc.location.length > 0 ? doc.location : this.uri);
      cleanClasses(articleContent);
      article.articleContent = articleContent;
    }
    article.title = this.articleTitle;
    article.byline = metaByline !== null ? metaByline : this.articleByline;
    article.dir = this.articleDir;
    let excerpt: string | null = getMetaContent(doc, ['description', 'og:description', 'twitter:description']);
    if (excerpt === null && articleContent !== null) {
      const ps: HtmlNode[] = articleContent.getElementsByTag('p');
      if (ps.length > 0) {
        excerpt = ps[0].text().trim();
      }
    }
    article.excerpt = excerpt;
    return article;
  }

  // ------------------------------------------------------------------------------------- 打分

  private flagIsActive(flag: number): boolean {
    return (this.flags & flag) > 0;
  }

  private removeFlag(flag: number): void {
    this.flags = this.flags & ~flag;
  }

  private getClassWeight(e: HtmlNode): number {
    if (!this.flagIsActive(FLAG_WEIGHT_CLASSES)) {
      return 0;
    }
    let weight: number = 0;
    const cls: string = e.attr('class');
    if (cls.length > 0) {
      if (RE_NEGATIVE.test(cls)) {
        weight -= 25;
      }
      if (RE_POSITIVE.test(cls)) {
        weight += 25;
      }
    }
    const id: string = e.attr('id');
    if (id.length > 0) {
      if (RE_NEGATIVE.test(id)) {
        weight -= 25;
      }
      if (RE_POSITIVE.test(id)) {
        weight += 25;
      }
    }
    return weight;
  }

  private initializeNode(node: HtmlNode): void {
    let score: number = 0;
    switch (node.tagName()) {
      case 'div':
        score += 5;
        break;
      case 'pre':
      case 'td':
      case 'blockquote':
        score += 3;
        break;
      case 'address':
      case 'ol':
      case 'ul':
      case 'dl':
      case 'dd':
      case 'dt':
      case 'li':
      case 'form':
        score -= 3;
        break;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'th':
        score -= 5;
        break;
      default:
        break;
    }
    this.scores.set(node, score + this.getClassWeight(node));
  }

  private scoreOf(node: HtmlNode): number {
    const s: number | undefined = this.scores.get(node);
    return s !== undefined ? s : 0;
  }

  private checkByline(node: HtmlNode, matchString: string): boolean {
    if (this.articleByline !== null) {
      return false;
    }
    if (node.attr('rel') === 'author' || RE_BYLINE.test(matchString)) {
      const text: string = node.text().trim();
      if (text.length > 0 && text.length < 100) {
        this.articleByline = text;
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------------------------------- 抽取

  private grabArticle(doc: HtmlDocument): HtmlNode | null {
    const page: HtmlNode | null = doc.body();
    if (page === null) {
      return null;
    }
    const pageCache: HtmlNode[] = page.children.map((c: HtmlNode): HtmlNode => c.clone());
    const attempts: Attempt[] = [];

    while (true) {
      this.scores = new Map<HtmlNode, number>();
      this.dataTables = new Set<HtmlNode>();
      const elementsToScore: HtmlNode[] = this.collectElementsToScore(doc);
      const candidates: HtmlNode[] = this.scoreElements(elementsToScore);
      const topCandidates: HtmlNode[] = this.selectTopCandidates(candidates);

      let topCandidate: HtmlNode | null = topCandidates.length > 0 ? topCandidates[0] : null;
      let neededToCreateTopCandidate: boolean = false;
      if (topCandidate === null || topCandidate.tagName() === 'body') {
        // Move everything (not just elements, also text nodes etc.) into the container so we even include text
        // directly in the body
        const created: HtmlNode = HtmlNode.element('div');
        neededToCreateTopCandidate = true;
        const kids: HtmlNode[] = page.children.slice();
        for (let i = 0; i < kids.length; i++) {
          created.appendChild(kids[i]);
        }
        page.appendChild(created);
        this.initializeNode(created);
        topCandidate = created;
      } else {
        topCandidate = this.refineTopCandidate(topCandidate, topCandidates);
      }

      const articleContent: HtmlNode = HtmlNode.element('div');
      const parentOfTopCandidate: HtmlNode | null = topCandidate.parent;
      this.collectSiblings(articleContent, topCandidate, parentOfTopCandidate);
      this.prepArticle(articleContent);

      if (neededToCreateTopCandidate) {
        topCandidate.setAttr('id', 'readability-page-1');
        topCandidate.setAttr('class', 'page');
      } else {
        const div: HtmlNode = HtmlNode.element('div');
        div.setAttr('id', 'readability-page-1');
        div.setAttr('class', 'page');
        const kids: HtmlNode[] = articleContent.children.slice();
        for (let i = 0; i < kids.length; i++) {
          div.appendChild(kids[i]);
        }
        articleContent.appendChild(div);
      }

      let result: HtmlNode | null = articleContent;
      const textLength: number = getInnerText(articleContent, true).length;
      if (textLength < DEFAULT_CHAR_THRESHOLD) {
        result = null;
        page.empty();
        for (let i = 0; i < pageCache.length; i++) {
          page.appendChild(pageCache[i].clone());
        }
        attempts.push(new Attempt(articleContent, textLength));
        if (this.flagIsActive(FLAG_STRIP_UNLIKELYS)) {
          this.removeFlag(FLAG_STRIP_UNLIKELYS);
        } else if (this.flagIsActive(FLAG_WEIGHT_CLASSES)) {
          this.removeFlag(FLAG_WEIGHT_CLASSES);
        } else if (this.flagIsActive(FLAG_CLEAN_CONDITIONALLY)) {
          this.removeFlag(FLAG_CLEAN_CONDITIONALLY);
        } else {
          // No luck after removing flags, just return the longest text we found during the different loops
          attempts.sort((a: Attempt, b: Attempt): number => b.textLength - a.textLength);
          if (attempts[0].textLength === 0) {
            return null;
          }
          result = attempts[0].articleContent;
        }
      }
      if (result !== null) {
        // Find out text direction from ancestors of final top candidate.
        const ancestors: HtmlNode[] = [];
        if (parentOfTopCandidate !== null) {
          ancestors.push(parentOfTopCandidate);
        }
        ancestors.push(topCandidate);
        if (parentOfTopCandidate !== null) {
          getNodeAncestors(parentOfTopCandidate).forEach((a: HtmlNode) => {
            ancestors.push(a);
          });
        }
        for (let i = 0; i < ancestors.length; i++) {
          const dir: string = ancestors[i].isElement() ? ancestors[i].attr('dir') : '';
          if (dir.length > 0) {
            this.articleDir = dir;
            break;
          }
        }
        return result;
      }
    }
  }

  /** 第一遍：去掉不可能的节点，div→p 规整，收集要打分的元素 */
  private collectElementsToScore(doc: HtmlDocument): HtmlNode[] {
    const elementsToScore: HtmlNode[] = [];
    const stripUnlikelyCandidates: boolean = this.flagIsActive(FLAG_STRIP_UNLIKELYS);
    let node: HtmlNode | null = doc.documentElement();
    while (node !== null) {
      const tag: string = node.tagName();
      const matchString: string = node.attr('class') + ' ' + node.attr('id');
      if (!isProbablyVisible(node)) {
        node = removeAndGetNext(node);
        continue;
      }
      // Check to see if this node is a byline, and remove it if it is.
      if (this.checkByline(node, matchString)) {
        node = removeAndGetNext(node);
        continue;
      }
      // Remove unlikely candidates
      if (stripUnlikelyCandidates && RE_UNLIKELY_CANDIDATES.test(matchString) &&
        !RE_OK_MAYBE_CANDIDATE.test(matchString) && tag !== 'body' && tag !== 'a') {
        node = removeAndGetNext(node);
        continue;
      }
      // Remove DIV, SECTION, and HEADER nodes without any content(e.g. text, image, video, or iframe).
      if ((tag === 'div' || tag === 'section' || tag === 'header' || tag === 'h1' || tag === 'h2' || tag === 'h3' ||
        tag === 'h4' || tag === 'h5' || tag === 'h6') && isElementWithoutContent(node)) {
        node = removeAndGetNext(node);
        continue;
      }
      if (DEFAULT_TAGS_TO_SCORE.has(tag)) {
        elementsToScore.push(node);
      }
      // Turn all divs that don't have children block level elements into p's
      if (tag === 'div') {
        if (hasSingleTagInsideElement(node, 'p') && getLinkDensity(node) < 0.25) {
          const newNode: HtmlNode = node.elementChildren()[0];
          node.replaceWith(newNode);
          node = newNode;
          elementsToScore.push(node);
        } else if (!hasChildBlockElement(node)) {
          node.renameTag('p');
          elementsToScore.push(node);
        } else {
          // EXPERIMENTAL
          const kids: HtmlNode[] = node.children.slice();
          for (let i = 0; i < kids.length; i++) {
            const childNode: HtmlNode = kids[i];
            if (childNode.isText() && childNode.data.trim().length > 0) {
              const p: HtmlNode = HtmlNode.element('p');
              p.setAttr('style', 'display: inline;');
              p.setAttr('class', READABILITY_STYLED);
              childNode.replaceWith(p);
              p.appendChild(HtmlNode.textNode(childNode.data));
            }
          }
        }
      }
      node = getNextNode(node);
    }
    return elementsToScore;
  }

  /** 给段落打分并把分数累加到祖先（父 1、祖父 1/2、更上层 1/(3*level)） */
  private scoreElements(elementsToScore: HtmlNode[]): HtmlNode[] {
    const candidates: HtmlNode[] = [];
    for (let i = 0; i < elementsToScore.length; i++) {
      const elementToScore: HtmlNode = elementsToScore[i];
      if (elementToScore.parent === null || !elementToScore.parent.isElement()) {
        continue;
      }
      const innerText: string = getInnerText(elementToScore);
      if (innerText.length < 25) {
        continue;
      }
      const ancestors: HtmlNode[] = getNodeAncestors(elementToScore, 3);
      if (ancestors.length === 0) {
        continue;
      }
      let contentScore: number = 1;
      contentScore += innerText.split(',').length;
      contentScore += Math.min(Math.floor(innerText.length / 100), 3);
      for (let level = 0; level < ancestors.length; level++) {
        const ancestor: HtmlNode = ancestors[level];
        if (!this.scores.has(ancestor)) {
          this.initializeNode(ancestor);
          candidates.push(ancestor);
        }
        const scoreDivider: number = level === 0 ? 1 : (level === 1 ? 2 : level * 3);
        this.scores.set(ancestor, this.scoreOf(ancestor) + contentScore / scoreDivider);
      }
    }
    return candidates;
  }

  private selectTopCandidates(candidates: HtmlNode[]): HtmlNode[] {
    const topCandidates: HtmlNode[] = [];
    for (let c = 0; c < candidates.length; c++) {
      const candidate: HtmlNode = candidates[c];
      // Scale the final candidates score based on link density.
      const candidateScore: number = this.scoreOf(candidate) * (1 - getLinkDensity(candidate));
      this.scores.set(candidate, candidateScore);
      for (let t = 0; t < DEFAULT_N_TOP_CANDIDATES; t++) {
        const aTopCandidate: HtmlNode | undefined = topCandidates[t];
        if (aTopCandidate === undefined || candidateScore > this.scoreOf(aTopCandidate)) {
          topCandidates.splice(t, 0, candidate);
          if (topCandidates.length > DEFAULT_N_TOP_CANDIDATES) {
            topCandidates.pop();
          }
          break;
        }
      }
    }
    return topCandidates;
  }

  private refineTopCandidate(initial: HtmlNode, topCandidates: HtmlNode[]): HtmlNode {
    let topCandidate: HtmlNode = initial;
    // Find a better top candidate node if it contains (at least three) nodes which belong to `topCandidates` array
    // and whose scores are quite closed with current `topCandidate` node.
    const alternativeCandidateAncestors: HtmlNode[][] = [];
    for (let i = 1; i < topCandidates.length; i++) {
      if (this.scoreOf(topCandidates[i]) / this.scoreOf(topCandidate) >= 0.75) {
        alternativeCandidateAncestors.push(getNodeAncestors(topCandidates[i]));
      }
    }
    if (alternativeCandidateAncestors.length >= MINIMUM_TOPCANDIDATES) {
      let parentOfTopCandidate: HtmlNode | null = topCandidate.parent;
      while (parentOfTopCandidate !== null && parentOfTopCandidate.isElement() &&
        parentOfTopCandidate.tagName() !== 'body') {
        let listsContainingThisAncestor: number = 0;
        for (let a = 0; a < alternativeCandidateAncestors.length && listsContainingThisAncestor < MINIMUM_TOPCANDIDATES;
          a++) {
          if (alternativeCandidateAncestors[a].indexOf(parentOfTopCandidate) >= 0) {
            listsContainingThisAncestor++;
          }
        }
        if (listsContainingThisAncestor >= MINIMUM_TOPCANDIDATES) {
          topCandidate = parentOfTopCandidate;
          break;
        }
        parentOfTopCandidate = parentOfTopCandidate.parent;
      }
    }
    if (!this.scores.has(topCandidate)) {
      this.initializeNode(topCandidate);
    }

    // Because of our bonus system, parents of candidates might have scores themselves. If we see the score going
    // *up* in the first few steps up the tree, that's a decent sign that there might be more content lurking in
    // other places that we want to unify in.
    let parent: HtmlNode | null = topCandidate.parent;
    let lastScore: number = this.scoreOf(topCandidate);
    const scoreThreshold: number = lastScore / 3;
    while (parent !== null && parent.isElement() && parent.tagName() !== 'body') {
      if (!this.scores.has(parent)) {
        parent = parent.parent;
        continue;
      }
      const parentScore: number = this.scoreOf(parent);
      if (parentScore < scoreThreshold) {
        break;
      }
      if (parentScore > lastScore) {
        // Alright! We found a better parent to use.
        topCandidate = parent;
        break;
      }
      lastScore = parentScore;
      parent = parent.parent;
    }

    // If the top candidate is the only child, use parent instead.
    parent = topCandidate.parent;
    while (parent !== null && parent.isElement() && parent.tagName() !== 'body' && parent.elementChildren().length === 1) {
      topCandidate = parent;
      parent = topCandidate.parent;
    }
    if (!this.scores.has(topCandidate)) {
      this.initializeNode(topCandidate);
    }
    return topCandidate;
  }

  /** 顶级候选的兄弟中足够相关的一并收入 articleContent */
  private collectSiblings(articleContent: HtmlNode, topCandidate: HtmlNode, parentOfTopCandidate: HtmlNode | null): void {
    if (parentOfTopCandidate === null) {
      articleContent.appendChild(topCandidate);
      return;
    }
    const siblingScoreThreshold: number = Math.max(10, this.scoreOf(topCandidate) * 0.2);
    const topClass: string = topCandidate.attr('class');
    const siblings: HtmlNode[] = parentOfTopCandidate.elementChildren();
    for (let s = 0; s < siblings.length; s++) {
      const sibling: HtmlNode = siblings[s];
      let append: boolean = false;
      if (sibling === topCandidate) {
        append = true;
      } else {
        let contentBonus: number = 0;
        // Give a bonus if sibling nodes and top candidates have the example same classname
        if (sibling.attr('class') === topClass && topClass !== '') {
          contentBonus += this.scoreOf(topCandidate) * 0.2;
        }
        if (this.scores.has(sibling) && this.scoreOf(sibling) + contentBonus >= siblingScoreThreshold) {
          append = true;
        } else if (sibling.tagName() === 'p') {
          const linkDensity: number = getLinkDensity(sibling);
          const nodeContent: string = getInnerText(sibling);
          const nodeLength: number = nodeContent.length;
          if (nodeLength > 80 && linkDensity < 0.25) {
            append = true;
          } else if (nodeLength < 80 && nodeLength > 0 && linkDensity === 0 &&
            nodeContent.search(new RegExp('\\.( |$)')) !== -1) {
            append = true;
          }
        }
      }
      if (append) {
        if (!ALTER_TO_DIV_EXCEPTIONS.has(sibling.tagName())) {
          // We have a node that isn't a common block level element, like a form or td tag. Turn it into a div so
          // it doesn't get filtered out later by accident.
          sibling.renameTag('div');
        }
        articleContent.appendChild(sibling);
      }
    }
  }

  // ------------------------------------------------------------------------------------- 清理

  private prepArticle(articleContent: HtmlNode): void {
    cleanStyles(articleContent);
    // Check for data tables before we continue, to avoid removing items in those tables
    markDataTables(articleContent, this.dataTables);
    this.cleanConditionally(articleContent, 'form');
    this.cleanConditionally(articleContent, 'fieldset');
    cleanTag(articleContent, 'object');
    cleanTag(articleContent, 'embed');
    cleanTag(articleContent, 'h1');
    cleanTag(articleContent, 'footer');
    cleanTag(articleContent, 'link');
    cleanTag(articleContent, 'aside');
    // Clean out elements have "share" in their id/class combinations from final top candidates
    cleanShareNodes(articleContent);
    // If there is only one h2 and its text content substantially equals article title, they are probably using it
    // as a header and not a subheader, so remove it since we already extract the title separately.
    const h2: HtmlNode[] = descendantsByTag(articleContent, 'h2');
    if (h2.length === 1 && this.articleTitle.length > 0) {
      const h2Text: string = h2[0].text();
      const lengthSimilarRate: number = (h2Text.length - this.articleTitle.length) / this.articleTitle.length;
      if (Math.abs(lengthSimilarRate) < 0.5) {
        const titlesMatch: boolean = lengthSimilarRate > 0 ? h2Text.indexOf(this.articleTitle) >= 0 :
          this.articleTitle.indexOf(h2Text) >= 0;
        if (titlesMatch) {
          cleanTag(articleContent, 'h2');
        }
      }
    }
    cleanTag(articleContent, 'iframe');
    cleanTag(articleContent, 'input');
    cleanTag(articleContent, 'textarea');
    cleanTag(articleContent, 'select');
    cleanTag(articleContent, 'button');
    this.cleanHeaders(articleContent);
    // Do these last as the previous stuff may have removed junk that will affect these
    this.cleanConditionally(articleContent, 'table');
    this.cleanConditionally(articleContent, 'ul');
    this.cleanConditionally(articleContent, 'div');
    removeExtraParagraphs(articleContent);
  }

  private cleanHeaders(e: HtmlNode): void {
    const tags: string[] = ['h1', 'h2'];
    for (let i = 0; i < tags.length; i++) {
      removeNodes(e, tags[i], (header: HtmlNode): boolean => this.getClassWeight(header) < 0);
    }
  }

  /** Readability _cleanConditionally：按权重/逗号数/图片段落比/链接密度等启发式移除 */
  private cleanConditionally(e: HtmlNode, tag: string): void {
    if (!this.flagIsActive(FLAG_CLEAN_CONDITIONALLY)) {
      return;
    }
    const isList: boolean = tag === 'ul' || tag === 'ol';
    removeNodes(e, tag, (node: HtmlNode): boolean => {
      // First check if we're in a data table, in which case don't remove us.
      if (hasAncestorTag(node, 'table', -1, (t: HtmlNode): boolean => this.dataTables.has(t))) {
        return false;
      }
      const weight: number = this.getClassWeight(node);
      const contentScore: number = 0;
      if (weight + contentScore < 0) {
        return true;
      }
      if (getCharCount(node, ',') >= 10) {
        return false;
      }
      // If there are not very many commas, and the number of non-paragraph elements is more than paragraphs or
      // other ominous signs, remove the element.
      const p: number = node.getElementsByTag('p').length;
      const img: number = node.getElementsByTag('img').length;
      const li: number = node.getElementsByTag('li').length - 100;
      const input: number = node.getElementsByTag('input').length;
      let embedCount: number = 0;
      const embeds: HtmlNode[] = node.getElementsByTag('embed');
      for (let ei = 0; ei < embeds.length; ei++) {
        if (!RE_VIDEOS.test(embeds[ei].attr('src'))) {
          embedCount += 1;
        }
      }
      const linkDensity: number = getLinkDensity(node);
      const contentLength: number = getInnerText(node).length;
      return (img > 1 && p / img < 0.5 && !hasAncestorTag(node, 'figure')) ||
        (!isList && li > p) ||
        (input > Math.floor(p / 3)) ||
        (!isList && contentLength < 25 && (img === 0 || img > 2) && !hasAncestorTag(node, 'figure')) ||
        (!isList && weight < 25 && linkDensity > 0.2) ||
        (weight >= 25 && linkDensity > 0.5) ||
        ((embedCount === 1 && contentLength < 75) || embedCount > 1);
    });
  }
}

/** 便捷：Readability4JExtended(uri, html).parse() */
export function parseReadability(uri: string, html: string): ReadabilityArticle {
  return new Readability(uri, html).parse();
}
