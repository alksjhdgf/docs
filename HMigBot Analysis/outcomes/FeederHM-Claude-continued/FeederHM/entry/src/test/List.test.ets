import localUnitTest from './LocalUnit.test';
import modelConvertersTest from './ModelConverters.test';
import utilTest from './Util.test';
import netTest from './Net.test';
import htmlTest from './Html.test';
import htmlLinearTest from './HtmlLinear.test';
import feedParserTest from './FeedParser.test';
import opmlTest from './Opml.test';
import syncEngineTest from './SyncEngine.test';

export default function testsuite() {
  localUnitTest();
  modelConvertersTest();
  utilTest();
  netTest();
  htmlTest();
  htmlLinearTest();
  feedParserTest();
  opmlTest();
  syncEngineTest();
}
