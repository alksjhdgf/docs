/**
 * SyncEngine.test.ets —— fnd-sync-engine 向量门：
 *  - 源 app/src/test/.../model/ArticleFilterRulesTest.kt 全部用例（断言原样）；
 *  - 源 app/src/test/.../model/RssLocalSyncThumbnailPolicyTest.kt 全部用例；
 *  - resolveThumbnailImage（源 RssLocalSync.resolveThumbnailImage）注入抓取器的补充用例。
 */
import { describe, it, expect } from '@ohos/hypium';
import {
  ArticleFilterPolicy,
  ArticleFilterRules,
  ArticleRule,
  ArticleRuleError,
  ArticleRuleField,
  ArticleRuleSet,
  EmptyPattern,
  InvalidRegex,
  MissingSeparator,
  TooManyRules,
  UnknownField
} from '../main/ets/core/sync/ArticleFilterRules';
import { ImageFromHTML, MediaImage, ThumbnailImage, thumbnailEquals } from '../main/ets/core/model/Thumbnail';
import { ParsedArticle, ParsedAuthor } from '../main/ets/core/model/Parsed';
import { ThumbnailImagePolicy, resolveThumbnailImage } from '../main/ets/core/sync/Thumbnails';

class ArticleArgs {
  title: string | null = null;
  url: string | null = null;
  author: string | null = null;
  tags: string[] | null = null;
  contentText: string | null = null;
  contentHtml: string | null = null;
  summary: string | null = null;
}

function article(a: ArticleArgs = new ArticleArgs()): ParsedArticle {
  const p: ParsedArticle = new ParsedArticle('id');
  p.url = a.url;
  p.title = a.title;
  p.content_html = a.contentHtml;
  p.content_text = a.contentText;
  p.summary = a.summary;
  p.author = a.author !== null ? new ParsedAuthor(a.author) : null;
  p.tags = a.tags;
  return p;
}

function withTitle(title: string): ParsedArticle {
  const a: ArticleArgs = new ArticleArgs();
  a.title = title;
  return article(a);
}

function withTags(tags: string[] | null, title: string | null = null): ParsedArticle {
  const a: ArticleArgs = new ArticleArgs();
  a.tags = tags;
  a.title = title;
  return article(a);
}

function withContent(contentText: string | null, contentHtml: string | null = null,
  summary: string | null = null): ParsedArticle {
  const a: ArticleArgs = new ArticleArgs();
  a.contentText = contentText;
  a.contentHtml = contentHtml;
  a.summary = summary;
  return article(a);
}

function rulesEqual(a: ArticleRule[], b: ArticleRule[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (!a[i].equals(b[i])) {
      return false;
    }
  }
  return true;
}

function errorsEqual(a: ArticleRuleError[], b: ArticleRuleError[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (!a[i].equals(b[i])) {
      return false;
    }
  }
  return true;
}

function repeatX(n: number): string {
  let s: string = '';
  const chunk: string = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  while (s.length + chunk.length <= n) {
    s += chunk;
  }
  while (s.length < n) {
    s += 'x';
  }
  return s;
}

function filterRulesTests(): void {
  // ---------------------------------------------------------------- parsing
  it('blankTextParsesToEmptyRuleSet', 0, () => {
    expect(ArticleRuleSet.EMPTY.equals(ArticleRuleSet.parse(''))).assertTrue();
    expect(ArticleRuleSet.EMPTY.equals(ArticleRuleSet.parse('   \n  \n'))).assertTrue();
  });
  it('parsesOneValidLine', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('Title=spam');
    expect(rulesEqual([new ArticleRule(ArticleRuleField.TITLE, 'spam')], result.rules)).assertTrue();
    expect(result.errors.length).assertEqual(0);
  });
  it('fieldNameIsMatchedCaseInsensitively', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('title=spam');
    expect(rulesEqual([new ArticleRule(ArticleRuleField.TITLE, 'spam')], result.rules)).assertTrue();
  });
  it('linesAreTrimmed', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('   Title = spam   ');
    expect(rulesEqual([new ArticleRule(ArticleRuleField.TITLE, 'spam')], result.rules)).assertTrue();
  });
  it('splitsOnFirstEqualsOnlySoPatternsMayContainEquals', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('URL=a=b');
    expect(rulesEqual([new ArticleRule(ArticleRuleField.URL, 'a=b')], result.rules)).assertTrue();
  });
  it('blankLinesAreSkippedWithoutShiftingLaterLineNumbers', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('Title=a\n\n\nnonsense');
    expect(rulesEqual([new ArticleRule(ArticleRuleField.TITLE, 'a')], result.rules)).assertTrue();
    expect(errorsEqual([new MissingSeparator(4)], result.errors)).assertTrue();
  });
  it('crlfParsesIdenticallyToLf', 0, () => {
    expect(ArticleRuleSet.parse('Title=a\nURL=b').equals(ArticleRuleSet.parse('Title=a\r\nURL=b'))).assertTrue();
  });
  it('unknownFieldIsReportedAndSiblingsSurvive', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('Foo=a\nTitle=b');
    expect(rulesEqual([new ArticleRule(ArticleRuleField.TITLE, 'b')], result.rules)).assertTrue();
    expect(errorsEqual([new UnknownField(1, 'Foo')], result.errors)).assertTrue();
  });
  it('missingSeparatorIsReported', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('Title');
    expect(result.rules.length).assertEqual(0);
    expect(errorsEqual([new MissingSeparator(1)], result.errors)).assertTrue();
  });
  it('emptyPatternIsRejectedAndIsNotAMatchEverythingRule', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('Title=');
    expect(result.rules.length).assertEqual(0);
    expect(errorsEqual([new EmptyPattern(1)], result.errors)).assertTrue();
  });
  it('invalidRegexIsReportedAndNoExceptionEscapes', 0, () => {
    const result: ArticleRuleSet = ArticleRuleSet.parse('Title=(unclosed');
    expect(result.rules.length).assertEqual(0);
    expect(result.errors.length).assertEqual(1);
    expect(result.errors[0] instanceof InvalidRegex).assertTrue();
    expect(result.errors[0].lineNumber).assertEqual(1);
  });
  it('duplicateRulesAreBothParsed', 0, () => {
    expect(ArticleRuleSet.parse('Title=a\nTitle=a').rules.length).assertEqual(2);
  });
  it('ruleCountIsCappedWithoutCrashing', 0, () => {
    const lines: string[] = [];
    for (let i = 1; i <= ArticleRuleSet.MAX_RULES + 50; i++) {
      lines.push(`Title=a${i}`);
    }
    const result: ArticleRuleSet = ArticleRuleSet.parse(lines.join('\n'));
    expect(result.rules.length).assertEqual(ArticleRuleSet.MAX_RULES);
    expect(errorsEqual([new TooManyRules(ArticleRuleSet.MAX_RULES + 1, ArticleRuleSet.MAX_RULES)], result.errors))
      .assertTrue();
  });

  // --------------------------------------------------------------- matching
  it('patternsMatchAnywhereAndAreNotAnchored', 0, () => {
    expect(new ArticleRule(ArticleRuleField.TITLE, 'spam').matches(withTitle('Delicious spam recipes'))).assertTrue();
  });
  it('matchingIsCaseSensitiveByDefault', 0, () => {
    expect(new ArticleRule(ArticleRuleField.TITLE, 'spam').matches(withTitle('SPAM'))).assertFalse();
  });
  it('inlineCaseInsensitiveFlagWorks', 0, () => {
    expect(new ArticleRule(ArticleRuleField.TITLE, '(?i)spam').matches(withTitle('SPAM'))).assertTrue();
  });
  it('urlRuleReadsUrlAndNeverExternalUrl', 0, () => {
    const rule: ArticleRule = new ArticleRule(ArticleRuleField.URL, 'marker');
    const a: ArticleArgs = new ArticleArgs();
    a.url = 'https://example.com/a';
    const withExternalOnly: ParsedArticle = article(a);
    withExternalOnly.external_url = 'https://example.com/marker';
    expect(rule.matches(withExternalOnly)).assertFalse();
    const b: ArticleArgs = new ArticleArgs();
    b.url = 'https://example.com/marker';
    expect(rule.matches(article(b))).assertTrue();
  });
  it('authorRuleReadsAuthorName', 0, () => {
    const a: ArticleArgs = new ArticleArgs();
    a.author = 'Bob Smith';
    expect(new ArticleRule(ArticleRuleField.AUTHOR, 'Bob').matches(article(a))).assertTrue();
  });
  it('missingAuthorMatchesEmptyStringButNotText', 0, () => {
    expect(new ArticleRule(ArticleRuleField.AUTHOR, '^$').matches(article())).assertTrue();
    expect(new ArticleRule(ArticleRuleField.AUTHOR, 'x').matches(article())).assertFalse();
  });
  it('tagRuleMatchesIfAnyTagMatches', 0, () => {
    const rule: ArticleRule = new ArticleRule(ArticleRuleField.TAG, 'linux');
    expect(rule.matches(withTags(['android', 'linux']))).assertTrue();
    expect(rule.matches(withTags(['android', 'windows']))).assertFalse();
  });
  it('untaggedArticleMatchesNoTagRuleNotEvenMatchAll', 0, () => {
    const matchAll: ArticleRule = new ArticleRule(ArticleRuleField.TAG, '.*');
    expect(matchAll.matches(withTags(null))).assertFalse();
    expect(matchAll.matches(withTags([]))).assertFalse();
  });
  it('contentRuleReadsContentText', 0, () => {
    expect(new ArticleRule(ArticleRuleField.CONTENT, 'marker').matches(withContent('a marker here', '<p>nope</p>')))
      .assertTrue();
  });
  it('contentRuleFallsBackToContentHtml', 0, () => {
    expect(new ArticleRule(ArticleRuleField.CONTENT, 'marker').matches(withContent(null, '<p>a marker here</p>')))
      .assertTrue();
  });
  it('contentRuleFallsBackToContentHtmlWhenContentTextIsBlank', 0, () => {
    const rule: ArticleRule = new ArticleRule(ArticleRuleField.CONTENT, 'sponsor\\.example');
    expect(rule.matches(withContent('', '<a href="https://sponsor.example/promo">here</a>'))).assertTrue();
  });
  it('contentRuleNeverReadsSummary', 0, () => {
    expect(new ArticleRule(ArticleRuleField.CONTENT, 'uniquemarker').matches(withContent('body', null, 'uniquemarker')))
      .assertFalse();
  });
  it('anchorsApplyToTheWholeFieldValue', 0, () => {
    expect(new ArticleRule(ArticleRuleField.TITLE, '^Ad: ').matches(withTitle('Ad: buy now'))).assertTrue();
    expect(new ArticleRule(ArticleRuleField.TITLE, '^Ad: ').matches(withTitle('An Ad: buy now'))).assertFalse();
    expect(new ArticleRule(ArticleRuleField.TITLE, 'sponsored$').matches(withTitle('This is sponsored'))).assertTrue();
  });
  it('endAnchorDoesNotBindToTheTruncationPointOfLongValues', 0, () => {
    const padding: string = repeatX(ArticleRule.MAX_MATCHED_LENGTH + 50000);
    expect(new ArticleRule(ArticleRuleField.CONTENT, 'x$').matches(withContent(padding))).assertFalse();
    expect(new ArticleRule(ArticleRuleField.CONTENT, '^x').matches(withContent(padding))).assertTrue();
    expect(new ArticleRule(ArticleRuleField.CONTENT, 'marker').matches(withContent('marker' + padding))).assertTrue();
  });
  it('contentBeyondTheLengthCapIsNotSearched', 0, () => {
    const text: string = repeatX(ArticleRule.MAX_MATCHED_LENGTH + 10) + 'marker';
    expect(new ArticleRule(ArticleRuleField.CONTENT, 'marker').matches(withContent(text))).assertFalse();
  });

  // ----------------------------------------------------------------- policy
  it('compilingEmptyTextsGivesNone', 0, () => {
    expect(ArticleFilterRules.compile('', '') === ArticleFilterRules.NONE).assertTrue();
    expect(ArticleFilterRules.NONE.isNoOp).assertTrue();
  });
  it('blockedItemIsDropped', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('Title=spam', '');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('spam here'), rules)).assertFalse();
  });
  it('itemIsKeptWhenNothingBlocksAndNothingIsRequired', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('Title=spam', '');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('good stuff'), rules)).assertTrue();
  });
  it('allowRuleKeepsMatchingItem', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('', 'Title=keep');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('please keep me'), rules)).assertTrue();
  });
  it('allowRuleDropsNonMatchingItem', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('', 'Title=keep');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('something else'), rules)).assertFalse();
  });
  it('tagAllowRuleIsSkippedForUntaggedArticles', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('', 'Tag=(?i)linux');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('no tags here'), rules)).assertTrue();
    expect(ArticleFilterPolicy.shouldKeep(withTags([], 'no tags here'), rules)).assertTrue();
  });
  it('tagAllowRuleStillFiltersTaggedArticles', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('', 'Tag=(?i)linux');
    expect(ArticleFilterPolicy.shouldKeep(withTags(['Linux', 'kernel']), rules)).assertTrue();
    expect(ArticleFilterPolicy.shouldKeep(withTags(['windows']), rules)).assertFalse();
  });
  it('otherAllowRulesStillApplyToUntaggedArticles', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('', 'Tag=(?i)linux\nTitle=(?i)kernel');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('New kernel released'), rules)).assertTrue();
    expect(ArticleFilterPolicy.shouldKeep(withTitle('Unrelated news'), rules)).assertFalse();
  });
  it('tagBlockRuleStillDoesNotBlockUntaggedArticles', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('Tag=.*', '');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('no tags here'), rules)).assertTrue();
    expect(ArticleFilterPolicy.shouldKeep(withTags(['anything']), rules)).assertFalse();
  });
  it('blockRuleWinsOverAllowRule', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('Title=spam', 'Title=spam');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('spam'), rules)).assertFalse();
  });
  it('oneInvalidBlockRuleDoesNotDisableTheValidOne', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('Title=(unclosed\nTitle=spam', '');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('spam'), rules)).assertFalse();
  });
  it('allBlockRulesInvalidBlocksNothing', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('Title=(unclosed', '');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('anything'), rules)).assertTrue();
  });
  it('allAllowRulesInvalidKeepsEverythingRatherThanDroppingEverything', 0, () => {
    const rules: ArticleFilterRules = ArticleFilterRules.compile('', 'Title=(unclosed');
    expect(ArticleFilterPolicy.shouldKeep(withTitle('anything'), rules)).assertTrue();
  });
}

function thumbnailPolicyTests(): void {
  it('keepsFeedProvidedThumbnailEvenWhenOgExists', 0, () => {
    const feedImage: MediaImage = new MediaImage('https://feed.example.com/feed.jpg');
    const ogImage: MediaImage = new MediaImage('https://site.example.com/og.jpg');
    expect(thumbnailEquals(feedImage, ThumbnailImagePolicy.applyOgImage(feedImage, ogImage))).assertTrue();
  });
  it('upgradesBodyDerivedThumbnailToOgImageWhenAvailable', 0, () => {
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    const ogImage: MediaImage = new MediaImage('https://site.example.com/og.jpg');
    expect(thumbnailEquals(ogImage, ThumbnailImagePolicy.applyOgImage(bodyImage, ogImage))).assertTrue();
  });
  it('keepsBodyDerivedThumbnailWhenNoOgImage', 0, () => {
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    expect(thumbnailEquals(bodyImage, ThumbnailImagePolicy.applyOgImage(bodyImage, null))).assertTrue();
  });
  it('usesOgImageWhenCurrentIsMissing', 0, () => {
    const ogImage: MediaImage = new MediaImage('https://site.example.com/og.jpg');
    expect(thumbnailEquals(ogImage, ThumbnailImagePolicy.applyOgImage(null, ogImage))).assertTrue();
  });
  it('returnsNullWhenBothCurrentAndOgAreMissing', 0, () => {
    expect(ThumbnailImagePolicy.applyOgImage(null, null) === null).assertTrue();
  });
  it('keepsExistingNonBodyImageWhenParsedEntryOnlyHasBodyImage', 0, () => {
    const existingImage: MediaImage = new MediaImage('https://site.example.com/og.jpg');
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    expect(thumbnailEquals(existingImage, ThumbnailImagePolicy.applyParsedEntryImage(existingImage, bodyImage)))
      .assertTrue();
  });
  it('takesIncomingFeedProvidedImageOverExistingNonBodyImage', 0, () => {
    const existingImage: MediaImage = new MediaImage('https://site.example.com/old-og.jpg');
    const feedImage: MediaImage = new MediaImage('https://feed.example.com/feed.jpg');
    expect(thumbnailEquals(feedImage, ThumbnailImagePolicy.applyParsedEntryImage(existingImage, feedImage)))
      .assertTrue();
  });
  it('onlyFetchesOgImageForMissingOrBodyDerivedThumbnailsWithoutFeedImage', 0, () => {
    const feedImage: MediaImage = new MediaImage('https://feed.example.com/feed.jpg');
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    expect(ThumbnailImagePolicy.shouldFetchOgImage(feedImage, 'https://example.com/article', false)).assertFalse();
    expect(ThumbnailImagePolicy.shouldFetchOgImage(bodyImage, 'https://example.com/article', false)).assertTrue();
    expect(ThumbnailImagePolicy.shouldFetchOgImage(null, 'https://example.com/article', false)).assertTrue();
    expect(ThumbnailImagePolicy.shouldFetchOgImage(bodyImage, null, false)).assertFalse();
  });
  it('skipsOgImageWhenFeedAlreadyProvidedAnyThumbnailCandidate', 0, () => {
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    expect(ThumbnailImagePolicy.shouldFetchOgImage(bodyImage, 'https://example.com/article', true)).assertFalse();
    expect(ThumbnailImagePolicy.shouldFetchOgImage(null, 'https://example.com/article', true)).assertFalse();
  });

  // 补充：resolveThumbnailImage（FS-A42）
  it('resolveKeepsCurrentWhenFetchFails', 0, async () => {
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    const r: ThumbnailImage | null = await resolveThumbnailImage(bodyImage, 'https://example.com/a', false,
      async (u: string): Promise<ThumbnailImage | null> => {
        throw new Error(`boom ${u}`);
      });
    expect(thumbnailEquals(bodyImage, r)).assertTrue();
  });
  it('resolveUsesOgImageForBodyThumbnail', 0, async () => {
    const bodyImage: ImageFromHTML = new ImageFromHTML('https://site.example.com/body.jpg');
    const og: MediaImage = new MediaImage('https://site.example.com/og.jpg');
    const r: ThumbnailImage | null = await resolveThumbnailImage(bodyImage, ' https://example.com/a ', false,
      async (u: string): Promise<ThumbnailImage | null> => og);
    expect(thumbnailEquals(og, r)).assertTrue();
  });
  it('resolveDoesNotFetchWithoutUrl', 0, async () => {
    let called: boolean = false;
    const r: ThumbnailImage | null = await resolveThumbnailImage(null, '  ', false,
      async (u: string): Promise<ThumbnailImage | null> => {
        called = true;
        return null;
      });
    expect(r === null).assertTrue();
    expect(called).assertFalse();
  });
}

export default function syncEngineTest() {
  describe('SyncEngineGate', () => {
    filterRulesTests();
    thumbnailPolicyTests();
  });
}
