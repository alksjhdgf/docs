/**
 * HtmlDocument.ets —— 文档根（≙ Jsoup Document）。parseHtml 产出必含 html/head/body。
 */
import { HtmlNode } from './HtmlNode';
import { NODE_DOCUMENT, appendNormalisedWhitespace, javaTrim } from './HtmlChars';

/** 文档根（≙ Jsoup Document）。parseHtml 产出必含 html/head/body */
export class HtmlDocument extends HtmlNode {
  constructor(location: string) {
    super(NODE_DOCUMENT, '#document');
    this.docLocation = location;
  }

  /** 文档 baseUri（≙ Jsoup Document.location / baseUri；`<base href>` 会更新它） */
  get location(): string {
    return this.docLocation;
  }

  set location(value: string) {
    this.docLocation = value;
  }

  documentElement(): HtmlNode | null {
    for (let i = 0; i < this.children.length; i++) {
      if (this.children[i].nameIs('html')) {
        return this.children[i];
      }
    }
    return null;
  }

  private findChildOfRoot(tag: string): HtmlNode | null {
    const root: HtmlNode | null = this.documentElement();
    if (root === null) {
      return null;
    }
    for (let i = 0; i < root.children.length; i++) {
      if (root.children[i].nameIs(tag)) {
        return root.children[i];
      }
    }
    return null;
  }

  head(): HtmlNode | null {
    return this.findChildOfRoot('head');
  }

  body(): HtmlNode | null {
    return this.findChildOfRoot('body');
  }

  title(): string {
    const ts: HtmlNode[] = this.getElementsByTag('title');
    return ts.length > 0 ? javaTrim(appendNormalisedWhitespace('', ts[0].text(), false)) : '';
  }

  createElement(tag: string): HtmlNode {
    return HtmlNode.element(tag);
  }
}
