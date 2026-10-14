/**
 * HtmlLinear.test.ets —— fnd-html-linear 向量门（suite HtmlLinearGate）。
 * 移植源 HtmlLinearizerTest（56 例）、LinearStuffKtTest（2 例）、FullTextParserKtTest（charset 4 例 + 降级说明）
 * 并补充台账 HM-A03/A04/A06/A07/A13/A14/A16/A44 的边界用例。相等比较 = 规范化 toString()（≙ data class equals）。
 */
import { describe, it, expect } from '@ohos/hypium';
import { base64DecodeStrict, encodeUtf8 } from '../main/ets/core/util/TextCodec';
import { HtmlLinearizer } from '../main/ets/core/html/HtmlLinearizer';
import {
  LinearArticle, LinearAudio, LinearAudioSource, LinearBlockQuote, LinearElement, LinearImage, LinearImageSource,
  LinearListItem, LinearTable, LinearTableBuilder, LinearTableCellItem, LinearTableCellItemType, LinearText,
  LinearTextAnnotation, LinearTextAnnotationBold, LinearTextAnnotationCode, LinearTextAnnotationData,
  LinearTextAnnotationFont, LinearTextAnnotationH1, LinearTextAnnotationH2, LinearTextAnnotationItalic,
  LinearTextAnnotationLink, LinearTextAnnotationMonospace, LinearTextAnnotationUnderline, LinearTextBlockStyle,
  LinearVideo, LinearVideoSource, shouldSoftWrap
} from '../main/ets/core/html/LinearArticle';
import {
  detectCharset, findMetaCharset, parseFullArticle, toJavaCharset
} from '../main/ets/core/html/FullTextExtract';
import { GB2312_HTML_B64, GB2312_HTML_PREFIX, LinearHtmlVector, MUHASEBETRE_ARTICLE_PREFIX, linearHtml } from './HtmlLinearVectors';

const TEXT: LinearTextBlockStyle = LinearTextBlockStyle.TEXT;

function ids(values: string[] = []): Set<string> {
  return new Set<string>(values);
}

function ann(data: LinearTextAnnotationData, start: number, end: number): LinearTextAnnotation {
  return new LinearTextAnnotation(data, start, end);
}

function txt(text: string, anns: LinearTextAnnotation[] = [], style: LinearTextBlockStyle = TEXT): LinearText {
  return new LinearText(ids(), text, style, anns);
}

function src(uri: string, w: number | null = null, h: number | null = null, d: number | null = null,
  sw: number | null = null): LinearImageSource {
  return new LinearImageSource(uri, w, h, d, sw);
}

function cell(type: LinearTableCellItemType, colSpan: number, rowSpan: number, text: string): LinearTableCellItem {
  return new LinearTableCellItem(type, colSpan, rowSpan, [txt(text)]);
}

function linearizeHtml(html: string, baseUrl: string = 'https://example.com'): LinearElement[] {
  return new HtmlLinearizer('', '', '').linearize(html, baseUrl).elements;
}

function run(name: string): LinearElement[] {
  const v: LinearHtmlVector = linearHtml(name);
  return linearizeHtml(v.html, v.baseUrl);
}

function str(items: LinearElement[]): string {
  return items.map((e: LinearElement): string => e.toString()).join('\n');
}

function expectSame(actual: LinearElement[], expected: LinearElement[]): void {
  expect(str(actual)).assertEqual(str(expected));
}

function sortedJoin(values: Set<string>): string {
  const arr: string[] = [];
  values.forEach((v: string) => {
    arr.push(v);
  });
  return arr.sort().join(',');
}

function bytesOf(s: string): Uint8Array {
  return encodeUtf8(s);
}

const H: LinearTableCellItemType = LinearTableCellItemType.HEADER;
const D: LinearTableCellItemType = LinearTableCellItemType.DATA;

export default function htmlLinearTest() {
  describe('HtmlLinearGate', () => {
    // ---------------------------------------------------------------- 基础
    it('emptyBody', 0, () => {
      expect(run('should return empty list when input is empty').length).assertEqual(0);
    });
    it('simpleText', 0, () => {
      expectSame(run('should return single LinearText when input is simple text'), [txt('Hello, world!')]);
    });
    it('spacesInsideHeadersKept', 0, () => {
      expectSame(run('spaces inside headers are kept'), [txt('Link small', [ann(LinearTextAnnotationH2, 0, 9)])]);
    });
    it('boldItalicUnderline', 0, () => {
      expectSame(run('should return annotations with bold, italic, and underline'), [txt('Hello, world!', [
        ann(LinearTextAnnotationBold, 0, 12), ann(LinearTextAnnotationItalic, 0, 12),
        ann(LinearTextAnnotationUnderline, 0, 12)])]);
    });
    it('boldItalicUnderlineInterleaving', 0, () => {
      expectSame(run('should return annotations with bold, italic, and underline interleaving'), [txt('Hello, world!', [
        ann(LinearTextAnnotationBold, 0, 9), ann(LinearTextAnnotationItalic, 0, 4),
        ann(LinearTextAnnotationUnderline, 0, 3)])]);
    });
    it('ownItemForHeader', 0, () => {
      expectSame(run('should return own item for header'),
        [txt('Header 1', [ann(LinearTextAnnotationH1, 0, 7)]), txt('Hello, world!')]);
    });
    it('nestedDivsSingleItem', 0, () => {
      expectSame(run('should return single item for nested divs'), [txt('Hello, world!')]);
    });
    // ---------------------------------------------------------------- 列表
    it('orderedList', 0, () => {
      expectSame(run('should return ordered LinearList for ol'), [
        new LinearListItem(ids(), 1, [txt('Item 1')]), new LinearListItem(ids(), 2, [txt('Item 2')])]);
    });
    it('unorderedList', 0, () => {
      expectSame(run('should return unordered LinearList for ul'), [
        new LinearListItem(ids(), null, [txt('Item 1')]), new LinearListItem(ids(), null, [txt('Item 2')])]);
    });
    it('surroundingSpanPreservedWithList', 0, () => {
      expectSame(run('surrounding span is preserved with list in middle'), [
        txt('Before it', [ann(LinearTextAnnotationBold, 0, 8)]),
        new LinearListItem(ids(), null, [txt('Item 1', [ann(LinearTextAnnotationBold, 0, 5)])]),
        new LinearListItem(ids(), null, [txt('Item 22', [ann(LinearTextAnnotationBold, 0, 6)])]),
        txt('After', [ann(LinearTextAnnotationBold, 0, 4)])]);
    });
    // ---------------------------------------------------------------- 图片
    it('imageAltText', 0, () => {
      expectSame(run('simple image with alt text should return single Image'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg')], txt('Alt text'), null)]);
    });
    it('imageBoldAltTextNoFormatting', 0, () => {
      expectSame(run('simple image with bold alt text should return no formatting'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg')], txt('Bold text'), null)]);
    });
    it('imageInsideLink', 0, () => {
      expectSame(run('simple image inside a link'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg')], txt('Alt text'), 'https://example.com/link')]);
    });
    it('imageDefinedSize', 0, () => {
      expectSame(run('simple image with defined size'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg', 100, 200)], null, null)]);
    });
    it('srcsetDensityAndWidth', 0, () => {
      expectSame(run('srcset image with pixel density and screenwidth versions available'), [
        new LinearImage(ids(), [
          src('https://example.com/image.jpg', null, null, 1),
          src('https://example.com/image-2x.jpg', null, null, 2),
          src('https://example.com/image-700w.jpg', null, null, null, 700),
          src('https://example.com/image-fallback.jpg')], null, null)]);
    });
    it('imageDataImgUrl', 0, () => {
      expectSame(run('simple image with dataImgUrl'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg')], null, null)]);
    });
    it('imageRelativeUrl', 0, () => {
      expectSame(run('simple image with relative url'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg')], null, null)]);
    });
    it('imageInlineData', 0, () => {
      expectSame(run('simple image with inline data image'), [new LinearImage(ids(), [src(
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==')],
        txt('Red dot'), null)]);
    });
    it('figureWithFigcaption', 0, () => {
      expectSame(run('simple figure image with figcaption'), [new LinearImage(ids(),
        [src('https://example.com/image.jpg')], txt('Alt text', [ann(LinearTextAnnotationBold, 4, 4)]), null)]);
    });
    it('figureInsideLink', 0, () => {
      expectSame(run('figure inside a link'), [new LinearImage(ids(), [src('https://example.com/image.jpg')],
        txt('Alt text', [ann(new LinearTextAnnotationLink('https://example.com/link'), 0, 7)]),
        'https://example.com/link')]);
    });
    it('figureTwoImgsDistinct', 0, () => {
      expectSame(run('figure with two img tags one with srcset and one with dataImgUrl - only distinct results'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg', null, null, 1),
          src('https://example.com/image-2x.jpg', null, null, 2)], null, null)]);
    });
    it('figureTwoImgsAllDifferent', 0, () => {
      expectSame(run('figure with two img tags one with srcset and one with dataImgUrl all urls different'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg', null, null, 1),
          src('https://example.com/image-2x.jpg', null, null, 2), src('https://example.com/image-3x.jpg')], null, null)]);
    });
    it('imageNegativeHeight', 0, () => {
      expectSame(run('image with negative heightPx'), [
        new LinearImage(ids(), [src('https://example.com/image.jpg')], null, null)]);
    });
    // ---------------------------------------------------------------- 引用 / pre
    it('pInBlockquote', 0, () => {
      expectSame(run('p in a blockquote does not add newlines at end and cite is null'), [
        new LinearBlockQuote(ids(), null, [txt('Quote')])]);
    });
    it('contentInsideBlockquote', 0, () => {
      const result: LinearElement[] = run('content inside blockquote');
      expect(result.length).assertEqual(3);
      expect(result[1] instanceof LinearImage).assertTrue();
    });
    it('preWithCode', 0, () => {
      expectSame(run('pre block with code tag'), [txt('\nCode\n  block', [ann(LinearTextAnnotationMonospace, 0, 12),
        ann(LinearTextAnnotationCode, 0, 12)], LinearTextBlockStyle.CODE_BLOCK)]);
    });
    it('preBlock', 0, () => {
      expectSame(run('pre block'),
        [txt('Code\n  block', [ann(LinearTextAnnotationMonospace, 0, 11)], LinearTextBlockStyle.PRE_FORMATTED)]);
    });
    it('preWithoutCode', 0, () => {
      expectSame(run('pre block without code tag'), [txt('Not a code block',
        [ann(LinearTextAnnotationMonospace, 0, 15)], LinearTextBlockStyle.PRE_FORMATTED)]);
    });
    // ---------------------------------------------------------------- 音视频
    it('audioNoSources', 0, () => {
      expect(run('audio with no sources is ignored').length).assertEqual(0);
    });
    it('audioTwoSources', 0, () => {
      expectSame(run('audio with two sources'), [new LinearAudio(ids(), [
        new LinearAudioSource('https://example.com/audio.mp3', 'audio/mpeg'),
        new LinearAudioSource('https://example.com/audio.ogg', 'audio/ogg')])]);
    });
    it('videoNoSources', 0, () => {
      expect(run('video with no sources is ignored').length).assertEqual(0);
    });
    it('videoTwoSources', 0, () => {
      expectSame(run('video with two sources'), [new LinearVideo(ids(), [
        new LinearVideoSource('https://example.com/video.mp4', 'https://example.com/video.mp4', null, null, null,
          'video/mp4'),
        new LinearVideoSource('https://example.com/video.webm', 'https://example.com/video.webm', null, null, null,
          'video/webm')])]);
    });
    it('videoNegativeWidth', 0, () => {
      expectSame(run('video with 1 source and negative width'), [new LinearVideo(ids(), [
        new LinearVideoSource('https://example.com/video.mp4', 'https://example.com/video.mp4', null, null, null,
          'video/mp4')])]);
    });
    it('iframeYoutube', 0, () => {
      expectSame(run('iframe with youtube video'), [new LinearVideo(ids(), [new LinearVideoSource(
        'https://www.youtube.com/embed/cjxnVO9RpaQ', 'https://www.youtube.com/watch?v=cjxnVO9RpaQ',
        'http://img.youtube.com/vi/cjxnVO9RpaQ/hqdefault.jpg', 480, 360, null)])]);
    });
    it('iframeInsideFigureYoutube', 0, () => {
      expectSame(run('iframe inside figure with youtube video'), [new LinearVideo(ids(), [new LinearVideoSource(
        'https://www.youtube.com/embed/x_m02bUxfvE?feature=oembed', 'https://www.youtube.com/watch?v=x_m02bUxfvE',
        'http://img.youtube.com/vi/x_m02bUxfvE/hqdefault.jpg', 1170, 658, null)])]);
    });
    // ---------------------------------------------------------------- 表格
    it('table2x2', 0, () => {
      expectSame(run('table block 2x2'), [LinearTable.build(ids(), true, (b: LinearTableBuilder) => {
        b.newRow();
        b.add(cell(H, 1, 1, '1'));
        b.add(cell(D, 1, 1, '2'));
        b.newRow();
        b.add(cell(D, 1, 1, '3'));
        b.add(cell(H, 1, 1, '4'));
      })]);
    });
    it('table2x2Rtl', 0, () => {
      expectSame(run('table block 2x2 rtl'), [LinearTable.build(ids(), true, (b: LinearTableBuilder) => {
        b.newRow();
        b.add(cell(D, 1, 1, '2'));
        b.add(cell(H, 1, 1, '1'));
        b.newRow();
        b.add(cell(H, 1, 1, '4'));
        b.add(cell(D, 1, 1, '3'));
      })]);
    });
    it('tableColspanRowspan', 0, () => {
      const result: LinearElement[] = run('table with colspan, rowspan, and a double span');
      expectSame(result, [LinearTable.build(ids(), true, (b: LinearTableBuilder) => {
        b.newRow();
        b.add(cell(H, 1, 1, 'Name'));
        b.add(cell(H, 1, 1, 'Age'));
        b.add(cell(H, 2, 1, 'Money Money'));
        b.newRow();
        b.add(cell(D, 2, 2, 'Bob'));
        b.add(cell(D, 1, 1, '$300'));
        b.add(cell(D, 1, 1, '0'));
        b.newRow();
        b.add(cell(D, 1, 1, '$400'));
        b.add(cell(D, 1, 1, '1'));
      })]);
      const table: LinearTable = result[0] as LinearTable;
      expect(table.colCount).assertEqual(4);
      expect(table.rowCount).assertEqual(3);
    });
    it('tableZeroColspan', 0, () => {
      const result: LinearElement[] = run('table with zero colspan spans entire row');
      expectSame(result, [LinearTable.build(ids(), true, (b: LinearTableBuilder) => {
        b.newRow();
        b.add(cell(H, 1, 1, 'Name'));
        b.add(cell(H, 1, 1, 'Age'));
        b.add(cell(H, 1, 1, 'Money'));
        b.newRow();
        b.add(cell(D, 0, 1, 'Bob'));
      })]);
      const table: LinearTable = result[0] as LinearTable;
      expect(table.colCount).assertEqual(3);
      expect(table.rowCount).assertEqual(2);
    });
    it('cowboyTable', 0, () => {
      const result: LinearElement[] = run('cowboy table');
      expect(result.length).assertEqual(1);
      // 源断言 table.cells.size - 3 == toTableData().cells.size（toTableData 丢弃 filler，属 fnd-html-render）→ filler 数 = 3
      let fillers: number = 0;
      (result[0] as LinearTable).cells.forEach((c: LinearTableCellItem, _k: string) => {
        if (c.isFiller) {
          fillers++;
        }
      });
      expect(fillers).assertEqual(3);
    });
    it('tableTheadTbodyTfoot', 0, () => {
      expectSame(run('table with thead, tbody, and tfoot'), [LinearTable.build(ids(), true, (b: LinearTableBuilder) => {
        b.newRow();
        b.add(cell(H, 1, 1, 'Name'));
        b.add(cell(H, 1, 1, 'Number'));
        b.add(cell(H, 1, 1, 'Money'));
        b.newRow();
        b.add(cell(D, 1, 1, 'Bob'));
        b.add(cell(D, 1, 1, '66'));
        b.add(cell(D, 1, 1, '$3'));
        b.newRow();
        b.add(cell(D, 1, 1, 'Alice'));
        b.add(cell(D, 1, 1, '999'));
        b.add(cell(D, 1, 1, '$999999'));
        b.newRow();
        b.add(cell(D, 1, 1, 'No Comment'));
        b.add(cell(D, 1, 1, 'Early!'));
        b.add(cell(D, 1, 1, 'Sad'));
      })]);
    });
    it('tableSingleColumnOptimizedOut', 0, () => {
      const result: LinearElement[] = run('table with single column is optimized out');
      expect(result.length).assertEqual(2);
      expect(result.every((e: LinearElement): boolean => e instanceof LinearText)).assertTrue();
    });
    it('insaneNestedTable', 0, () => {
      const result: LinearElement[] = run('insane nested table');
      expect(result.length).assertEqual(4);
      expect(result.every((e: LinearElement): boolean => e instanceof LinearText)).assertTrue();
    });
    it('cowboyprogrammerExhaustive', 0, () => {
      const tables: LinearElement[] = run('cowboyprogrammer exhaustive')
        .filter((e: LinearElement): boolean => e instanceof LinearTable);
      expect(tables.length).assertEqual(1);
      expect((tables[0] as LinearTable).rowCount).assertEqual(8);
    });
    // ---------------------------------------------------------------- 真实页面
    it('arstechnicaReadability4j', 0, () => {
      checkArstechnica(run('arctechnica list items are actually images readability4j'));
    });
    it('arstechnica', 0, () => {
      checkArstechnica(run('arstechnica list items are actually images'));
    });
    it('feederNewsChangelog', 0, () => {
      expect(run('test with feeder news changelog').length).assertEqual(20);
    });
    it('cowboyprogrammerTransmission', 0, () => {
      expect(run('cowboyprogrammer transmission').length).assertEqual(12);
    });
    // ---------------------------------------------------------------- ids
    it('idsTwoDivs', 0, () => {
      const result: LinearElement[] =
        run('two divs enclosing a paragraph of text should return single LinearText with combined ids');
      expect(result.length).assertEqual(1);
      expect((result[0] as LinearText).text).assertEqual('Hello, world!');
      expect(sortedJoin(result[0].ids)).assertEqual('div1,div2');
    });
    it('idsImage', 0, () => {
      const result: LinearElement[] = run('should return single LinearImage with correct ids when input is an image');
      expect(result.length).assertEqual(1);
      expect(sortedJoin(result[0].ids)).assertEqual('img1');
    });
    it('idsList', 0, () => {
      const result: LinearElement[] =
        run('should return single LinearList with correct ids when input is an unordered list');
      expect(result.length).assertEqual(2);
      expect(sortedJoin(result[0].ids)).assertEqual('item1');
      expect(sortedJoin(result[1].ids)).assertEqual('item2');
    });
    it('idsBlockQuote', 0, () => {
      const result: LinearElement[] =
        run('should return single LinearBlockQuote with correct ids when input is a blockquote');
      expect(result.length).assertEqual(1);
      expect(result[0] instanceof LinearBlockQuote).assertTrue();
      expect(sortedJoin(result[0].ids)).assertEqual('para1,quote1');
    });
    it('idsAudio', 0, () => {
      const result: LinearElement[] =
        run('should return single LinearAudio with correct ids when input is an audio element');
      expect(result.length).assertEqual(1);
      expect(sortedJoin(result[0].ids)).assertEqual('audio1');
    });
    it('idsTable', 0, () => {
      const result: LinearElement[] = run('should return single LinearTable with correct ids when input is a 2x2 table');
      expect(result.length).assertEqual(1);
      expect(sortedJoin(result[0].ids)).assertEqual('cell1,cell2,cell3,cell4,table1');
    });
    it('idsVideo', 0, () => {
      const result: LinearElement[] =
        run('should return single LinearVideo with correct ids when input is a video element');
      expect(result.length).assertEqual(1);
      expect(sortedJoin(result[0].ids)).assertEqual('video1');
    });
    it('idToIndex', 0, () => {
      const article: LinearArticle = new HtmlLinearizer('', '', '')
        .linearize('<p id="a">A</p><p>B</p><div id="c"><p>C</p></div>', 'https://example.com');
      expect(article.idToIndex.get('a')).assertEqual(0);
      expect(article.idToIndex.get('c')).assertEqual(2);
    });
    it('readabilityStyledParagraphSpace', 0, () => {
      const result: LinearElement[] = run('paragraph section followed by link will have space between');
      expect(result.length).assertEqual(1);
      expect((result[0] as LinearText).text).assertEqual(
        'The SystemV file-system that implements Xenix FS, SystemV/386 FS, and Coherent FS is set to be removed ' +
          'from the Linux kernel. The SystemV file-system was orphaned back in 2023');
    });
    // ---------------------------------------------------------------- 台账补充
    it('truncatedByChars_appendsTooLargeAndOpenInBrowser', 0, () => {
      const big: string = 'a'.repeat(HtmlLinearizer.MAX_CHARS + 1);
      const article: LinearArticle = new HtmlLinearizer('too large', 'Open in Web view', 'https://example.com/a')
        .linearize('<p>' + big + '</p><p>after</p>', 'https://example.com');
      expectSame(article.elements, [txt('too large'), txt('Open in Web view',
        [ann(new LinearTextAnnotationLink('https://example.com/a'), 0, 15)])]);
    });
    it('truncatedByElements', 0, () => {
      let html: string = '';
      for (let i = 0; i < HtmlLinearizer.MAX_ELEMENTS + 5; i++) {
        html += '<p>p' + i + '</p>';
      }
      const elements: LinearElement[] = new HtmlLinearizer('T', 'O', 'L').linearize(html, 'https://example.com').elements;
      expect(elements.length).assertEqual(HtmlLinearizer.MAX_ELEMENTS + 2);
      expect((elements[HtmlLinearizer.MAX_ELEMENTS] as LinearText).text).assertEqual('T');
    });
    it('hiddenByCss', 0, () => {
      expectSame(linearizeHtml('<div style="display:none">hidden</div><p>shown</p>'), [txt('shown')]);
    });
    it('whitespaceCollapsedZwnjKept', 0, () => {
      expectSame(linearizeHtml('<p>a \t\n b‌c</p>'), [txt('a b‌c')]);
    });
    it('inlineTagMapping', 0, () => {
      expectSame(linearizeHtml('<p><span style="font-weight: bold; font-style: oblique">x</span>' +
        '<font face="serif">y</font><span style="color:red">z</span></p>'), [txt('xyz', [
        ann(LinearTextAnnotationBold, 0, 0), ann(LinearTextAnnotationItalic, 0, 0),
        ann(new LinearTextAnnotationFont('serif'), 1, 1)])]);
    });
    it('mailtoLinkKeepsRawHref', 0, () => {
      expectSame(linearizeHtml('<a href="mailto:x@example.com">mail</a>'),
        [txt('mail', [ann(new LinearTextAnnotationLink('mailto:x@example.com'), 0, 3)])]);
    });
    it('rubyAndOrphanFigcaptionDropped', 0, () => {
      expectSame(linearizeHtml('<ruby>漢<rp>(</rp><rt>kan</rt><rp>)</rp></ruby><div><figcaption>x</figcaption></div>'),
        [txt('漢')]);
    });
    it('softWrapOnlyText', 0, () => {
      expect(shouldSoftWrap(LinearTextBlockStyle.TEXT)).assertTrue();
      expect(shouldSoftWrap(LinearTextBlockStyle.PRE_FORMATTED)).assertFalse();
      expect(shouldSoftWrap(LinearTextBlockStyle.CODE_BLOCK)).assertFalse();
    });
    it('parseErrorReturnsEmpty', 0, () => {
      // rowspan filler 与下一行 colspan 冲突 → 源 LinearTable.Builder check() 抛错 → 整篇空列表（HM-A02，照源）
      const html: string = '<p>before</p><table><tr><td>a</td><td rowspan="2">b</td></tr>' +
        '<tr><td colspan="2">c</td></tr></table>';
      expect(linearizeHtml(html).length).assertEqual(0);
    });
    // ---------------------------------------------------------------- LinearStuffKtTest
    it('imageUrlsIncludesNested', 0, () => {
      const direct: LinearImage = new LinearImage(ids(), [src('https://example.com/direct.jpg', 1200, 800),
        src('https://example.com/direct-600.jpg', 600, 400)], null, null);
      const nested: LinearImage = new LinearImage(ids(), [src('https://example.com/nested.jpg', 900, 600)], null, null);
      const tableImage: LinearImage =
        new LinearImage(ids(), [src('https://example.com/table.jpg', 700, 500)], null, null);
      const article: LinearArticle = new LinearArticle([direct, new LinearListItem(ids(), null, [nested]),
        LinearTable.fromCellList(ids(), 1, 1, [new LinearTableCellItem(D, 1, 1, [tableImage])], true)]);
      expect(sortedJoin(article.imageUrls)).assertEqual(
        'https://example.com/direct-600.jpg,https://example.com/direct.jpg,https://example.com/nested.jpg,' +
          'https://example.com/table.jpg');
    });
    it('containsImageUrlNested', 0, () => {
      const article: LinearArticle = new LinearArticle([new LinearBlockQuote(ids(), null, [
        new LinearImage(ids(), [src('https://example.com/hero.jpg', 1200, 800)], null, null)])]);
      expect(article.containsImageUrl('https://example.com/hero.jpg')).assertTrue();
      expect(article.containsImageUrl('https://example.com/unknown.jpg')).assertFalse();
    });
    // ---------------------------------------------------------------- FullTextParserKtTest
    it('metaCharsetFromContentGb2312', 0, () => {
      expect(findMetaCharset(bytesOf(GB2312_HTML_PREFIX))).assertEqual('gb2312');
    });
    it('metaCharsetGbk', 0, () => {
      expect(findMetaCharset(bytesOf('<html><head><meta charset="gbk"></head><body></body></html>')))
        .assertEqual('gbk');
    });
    it('metaCharsetContentSemicolon', 0, () => {
      expect(findMetaCharset(bytesOf('<html><head><meta content="charset=gbk; text/html"></head><body></body></html>')))
        .assertEqual('gbk');
    });
    it('metaCharsetWeirdTurkish', 0, () => {
      expect(findMetaCharset(bytesOf(MUHASEBETRE_ARTICLE_PREFIX))).assertEqual('windows-1254');
    });
    it('detectCharsetGuessesGb', 0, () => {
      // 源 FullTextParserKtTest `guesses gb from html`：ICU CharsetDetector 对 gb2312.html 真实字节首个置信度>50 的为
      // GB18030；此处跑工程 ICU 移植探测器（CharsetRecognizers）于同一资源字节（HM-A42）
      const raw: Uint8Array | null = base64DecodeStrict(GB2312_HTML_B64);
      expect(raw !== null).assertTrue();
      if (raw !== null) {
        expect(detectCharset(raw)).assertEqual('GB18030');
      }
      // 纯 ASCII 前缀无多字节证据：无候选置信度 > 50 → null（UTF-8 兜底）
      expect(detectCharset(bytesOf(GB2312_HTML_PREFIX)) === null).assertTrue();
      expect(toJavaCharset('GB2312')).assertEqual('gbk');
    });
    it('parseFullArticleReadability', 0, () => {
      let paras: string = '';
      for (let i = 0; i < 6; i++) {
        paras += '<p>This is paragraph number ' + i + ' of the article, with enough words, commas, and length to be ' +
          'scored as real content by the readability algorithm. It keeps going for a while.</p>';
      }
      const html: string = '<html dir="rtl"><head><title>Some article title here</title></head><body>' +
        '<div class="menu"><a href="/a">Home</a></div><div id="content" class="article">' + paras + '</div>' +
        '<div class="footer">Copyright footer</div></body></html>';
      const full: string | null = parseFullArticle('https://example.com/post', html);
      expect(full !== null).assertTrue();
      const s: string = full !== null ? full : '';
      expect(s.indexOf('<html dir="rtl"') === 0).assertTrue();
      expect(s.indexOf('<meta charset="utf-8">') >= 0).assertTrue();
      expect(s.indexOf('paragraph number 5') >= 0).assertTrue();
      expect(s.indexOf('Copyright footer') < 0).assertTrue();
      expect(s.indexOf('readability-page-1') >= 0).assertTrue();
    });
  });
}

function checkArstechnica(result: LinearElement[]): void {
  expect(result.length).assertEqual(6);
  const items: LinearElement[] = result.filter((e: LinearElement): boolean => e instanceof LinearListItem);
  expect(items.length).assertEqual(6);
  for (let i = 0; i < items.length; i++) {
    const item: LinearListItem = items[i] as LinearListItem;
    expect(item.content.length).assertEqual(1);
    const image: LinearImage = item.content[0] as LinearImage;
    expect(image.sources[0].imgUri.startsWith('https://cdn.arstechnica.net/wp-content/uploads/2024/05/')).assertTrue();
    expect(image.sources[0].imgUri.endsWith('.jpeg')).assertTrue();
  }
}
