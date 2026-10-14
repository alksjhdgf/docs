import { describe, it, expect } from '@ohos/hypium';
import { encodeUtf8Buffer } from '../main/ets/core/util/TextCodec';
import { HtmlDocument, HtmlNode, parseHtml, unescapeEntities } from '../main/ets/core/html/HtmlParser';
import { select, selectFirst } from '../main/ets/core/html/HtmlSelector';
import {
  IOException,
  OgHttpResponse,
  extractOgImage,
  fetchOgImage,
  findFirstImageInHtml,
  isHtmlContentType,
  streamHeadContent
} from '../main/ets/core/html/HtmlUtils';
import { HtmlToPlainTextConverter, plainContentOf, repeated } from '../main/ets/core/html/HtmlToPlainText';
import { MarkdownToHtmlConverter, escapeHtml } from '../main/ets/core/html/MarkdownToHtml';
import { ImageFromHTML, MediaImage } from '../main/ets/core/model/Thumbnail';
import {
  DOM_TEXT_VECTORS,
  FIRST_IMAGE_VECTORS,
  MARKDOWN_CONTAINS_VECTORS,
  MARKDOWN_EXACT_VECTORS,
  OG_IMAGE_VECTORS,
  PLAIN_TEXT_VECTORS,
  SELECTOR_VECTORS
} from './HtmlVectors';

function bodyOf(doc: HtmlDocument): HtmlNode {
  const b: HtmlNode | null = doc.body();
  return b !== null ? b : doc;
}

function utf8(s: string): ArrayBuffer {
  return encodeUtf8Buffer(s);
}

export default function htmlTest() {
  describe('fndHtmlDom', () => {
    it('parse_alwaysHasHtmlHeadBody', 0, () => {
      const doc: HtmlDocument = parseHtml('', '');
      expect(doc.head() !== null).assertTrue();
      expect(doc.body() !== null).assertTrue();
    });

    it('parse_bodyTextVectors', 0, () => {
      for (let i = 0; i < DOM_TEXT_VECTORS.length; i++) {
        const v = DOM_TEXT_VECTORS[i];
        expect(bodyOf(parseHtml(v.html, '')).text()).assertEqual(v.bodyText);
      }
    });

    it('parse_scriptIsRawData', 0, () => {
      const doc: HtmlDocument = parseHtml('<script>a<b && "</p>"</script>', '');
      const s: HtmlNode | null = selectFirst(doc, 'script');
      expect(s !== null ? s.children.length : -1).assertEqual(1);
      expect(s !== null ? s.children[0].isData() : false).assertTrue();
      expect(s !== null ? s.children[0].data : '').assertEqual('a<b && "</p>"');
    });

    it('parse_ownTextAndAbsAttr', 0, () => {
      const doc: HtmlDocument = parseHtml('<p>own <b>child</b> text<br>more<a href="../x?a=1&amp;b=2">l</a></p>',
        'https://h.com/dir/sub/page.html');
      const p: HtmlNode | null = selectFirst(doc, 'p');
      expect(p !== null ? p.ownText() : '').assertEqual('own text more');
      const a: HtmlNode | null = selectFirst(doc, 'a');
      expect(a !== null ? a.attr('href') : '').assertEqual('../x?a=1&b=2');
      expect(a !== null ? a.attr('abs:href') : '').assertEqual('https://h.com/dir/x?a=1&b=2');
      expect(a !== null ? a.attr('abs:missing') : 'x').assertEqual('');
    });

    it('parse_baseHrefUpdatesLocation', 0, () => {
      const doc: HtmlDocument = parseHtml('<head><base href="https://cdn.com/a/"></head><img src="i.png">',
        'https://h.com/');
      const img: HtmlNode | null = selectFirst(doc, 'img');
      expect(img !== null ? img.attr('abs:src') : '').assertEqual('https://cdn.com/a/i.png');
    });

    it('parse_attrsLowercaseFirstWins', 0, () => {
      const doc: HtmlDocument = parseHtml('<IMG SRC="a.png" src="b.png" Alt=x checked/>', '');
      const img: HtmlNode | null = selectFirst(doc, 'img');
      expect(img !== null ? img.attr('src') : '').assertEqual('a.png');
      expect(img !== null ? img.attr('alt') : '').assertEqual('x');
      expect(img !== null ? img.hasAttr('checked') : false).assertTrue();
    });

    it('unescape_attributeRules', 0, () => {
      expect(unescapeEntities('&lt;img&gt; &amp; &copy;', false)).assertEqual('<img> & ©');
      expect(unescapeEntities('?a=1&copy=2', true)).assertEqual('?a=1&copy=2');
      expect(unescapeEntities('?a=1&copy=2', false)).assertEqual('?a=1©=2');
    });

    it('selector_vectors', 0, () => {
      for (let i = 0; i < SELECTOR_VECTORS.length; i++) {
        const v = SELECTOR_VECTORS[i];
        const found: HtmlNode[] = select(parseHtml(v.html, ''), v.query);
        const texts: string[] = [];
        for (let k = 0; k < found.length; k++) {
          texts.push(found[k].text());
        }
        expect(v.query + '=' + texts.join('|')).assertEqual(v.query + '=' + v.texts.join('|'));
      }
    });
  });

  describe('fndHtmlToPlainText', () => {
    it('repeated', 0, () => {
      expect(repeated('*', 0)).assertEqual('');
      expect(repeated('*', -1)).assertEqual('');
      expect(repeated('*', 1)).assertEqual('*');
      expect(repeated('*', 4)).assertEqual('****');
    });

    it('HM_A48_A52_vectors', 0, () => {
      for (let i = 0; i < PLAIN_TEXT_VECTORS.length; i++) {
        const v = PLAIN_TEXT_VECTORS[i];
        expect(new HtmlToPlainTextConverter().convert(v.input)).assertEqual(v.expected);
      }
    });

    it('HM_A53_plainContent', 0, () => {
      expect(plainContentOf('<p>hello</p>')).assertEqual('hello');
      expect(plainContentOf('<p> </p><!-- img -->')).assertEqual('<image>');
      expect(plainContentOf('<img src="a.png">')).assertEqual('[IMG]');
    });
  });

  describe('fndHtmlUtils', () => {
    it('UT_A14_A16_firstImageVectors', 0, () => {
      for (let i = 0; i < FIRST_IMAGE_VECTORS.length; i++) {
        const v = FIRST_IMAGE_VECTORS[i];
        const img: ImageFromHTML | null = findFirstImageInHtml(v.html, v.baseUrl);
        expect(v.name + ':' + (img !== null ? img.url : 'null')).assertEqual(v.name + ':' +
          (v.expectedUrl !== null ? v.expectedUrl : 'null'));
        if (img !== null) {
          expect(img.width).assertEqual(v.expectedWidth);
          expect(img.height).assertEqual(v.expectedHeight);
          expect(img.fromBody).assertTrue();
        }
      }
    });

    it('UT_A17_A19_ogImageVectors', 0, () => {
      for (let i = 0; i < OG_IMAGE_VECTORS.length; i++) {
        const v = OG_IMAGE_VECTORS[i];
        const img: MediaImage | null = extractOgImage(v.html, v.baseUrl);
        expect(v.name + ':' + (img !== null ? img.url : 'null')).assertEqual(v.name + ':' +
          (v.expected !== null ? v.expected : 'null'));
      }
    });

    it('UT_A19_returnedImageIsNotFromBody', 0, () => {
      const img: MediaImage | null = extractOgImage(
        '<html><head><meta property="og:image" content="https://example.com/image.jpg"></head></html>',
        'https://example.com/');
      expect(img !== null).assertTrue();
      if (img !== null) {
        expect(img.width).assertNull();
        expect(img.height).assertNull();
        expect(img.fromBody).assertFalse();
      }
    });

    it('UT_A21_streamHeadContent', 0, () => {
      expect(streamHeadContent('<html><HEAD><title>t</title></Head><body>x</body>'))
        .assertEqual('<html><HEAD><title>t</title></Head>');
      let big: string = '';
      for (let i = 0; i < 40000; i++) {
        big += 'ab';
      }
      const cut: string = streamHeadContent(big);
      expect(cut.length > 65536 && cut.length <= 65536 + 2048).assertTrue();
      expect(isHtmlContentType('text/html; charset=utf-8')).assertTrue();
      expect(isHtmlContentType('application/xhtml+xml')).assertTrue();
      expect(isHtmlContentType('image/png')).assertFalse();
    });

    it('UT_A20_fetchOgImageUsesFinalUrl', 0, async () => {
      let accept: string = '';
      const img: MediaImage | null = await fetchOgImage(
        (url: string, headers: Map<string, string>): Promise<OgHttpResponse> => {
          const h: string | undefined = headers.get('Accept');
          accept = h !== undefined ? h : '';
          const r: OgHttpResponse = {
            code: 200,
            contentType: 'text/html',
            finalUrl: 'https://dest.example.com/articles/final',
            body: utf8('<html><head>\n<meta property="og:image" content="/images/hero.jpg">\n</head><body></body></html>')
          };
          return Promise.resolve(r);
        }, 'https://origin.example.com/start');
      expect(accept).assertEqual('text/html');
      expect(img !== null ? img.url : '').assertEqual('https://dest.example.com/images/hero.jpg');
    });

    it('UT_A21_fetchOgImageErrorsAndNonHtml', 0, async () => {
      let threw: boolean = false;
      try {
        await fetchOgImage((url: string, headers: Map<string, string>): Promise<OgHttpResponse> => {
          const r: OgHttpResponse = { code: 404, contentType: null, finalUrl: url, body: utf8('') };
          return Promise.resolve(r);
        }, 'https://x.com/');
      } catch (e) {
        threw = e instanceof IOException;
      }
      expect(threw).assertTrue();
      const none: MediaImage | null = await fetchOgImage(
        (url: string, headers: Map<string, string>): Promise<OgHttpResponse> => {
          const r: OgHttpResponse = {
            code: 200, contentType: 'image/png', finalUrl: url,
            body: utf8('<meta property="og:image" content="/a.png">')
          };
          return Promise.resolve(r);
        }, 'https://x.com/');
      expect(none).assertNull();
    });
  });

  describe('fndMarkdownToHtml', () => {
    it('HM_A54_containsVectors', 0, () => {
      const conv: MarkdownToHtmlConverter = new MarkdownToHtmlConverter();
      for (let i = 0; i < MARKDOWN_CONTAINS_VECTORS.length; i++) {
        const v = MARKDOWN_CONTAINS_VECTORS[i];
        const html: string = conv.convertToHtml(v.markdown);
        for (let k = 0; k < v.contains.length; k++) {
          expect(v.name + ':' + v.contains[k] + ':' + (html.indexOf(v.contains[k]) >= 0))
            .assertEqual(v.name + ':' + v.contains[k] + ':true');
        }
      }
    });

    it('HM_A54_exactVectors', 0, () => {
      const conv: MarkdownToHtmlConverter = new MarkdownToHtmlConverter();
      for (let i = 0; i < MARKDOWN_EXACT_VECTORS.length; i++) {
        const v = MARKDOWN_EXACT_VECTORS[i];
        expect(conv.convertToHtml(v.input)).assertEqual(v.expected);
      }
    });

    it('HM_A54_emptyInput', 0, () => {
      const conv: MarkdownToHtmlConverter = new MarkdownToHtmlConverter();
      expect(conv.convertToHtml('')).assertEqual('');
      expect(conv.convertToHtml('  \n ')).assertEqual('');
      expect(conv.convertToPlainText('')).assertEqual('');
    });

    it('HM_A55_plainTextAndEscape', 0, () => {
      const plain: string = new MarkdownToHtmlConverter().convertToPlainText('This is **bold** and this is *italic*');
      expect(plain.indexOf('*') < 0).assertTrue();
      expect(plain.indexOf('bold') >= 0).assertTrue();
      expect(plain.indexOf('italic') >= 0).assertTrue();
      expect(escapeHtml('& < > " \'')).assertEqual('&amp; &lt; &gt; &quot; &#39;');
    });
  });
}
