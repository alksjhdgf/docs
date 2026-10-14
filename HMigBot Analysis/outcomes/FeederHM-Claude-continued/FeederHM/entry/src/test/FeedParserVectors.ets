/**
 * FeedParserVectors.ets —— FeedParser.test.ets 用的内嵌 XML 常量，逐字摘自源
 * androidTest/.../model/FeedParserTest.kt:1218-1416（Kotlin 原始字符串，含开头换行）。
 */

export const rssBleepingComputer: string = `
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<rss version="2.0">
  <channel>
    <title>BleepingComputer</title>
    <link>https://www.bleepingcomputer.com/</link>
    <description>BleepingComputer - All Stories</description>
    <pubDate>Thu, 14 Mar 2024 14:13:50 EDT</pubDate>
    <generator>https://www.bleepingcomputer.com/</generator>
    <language>en</language>
    <atom:link href="https://www.bleepingcomputer.com/feed/" rel="self" type="application/rss+xml" />

    <item>
        <title>SIM swappers now stealing phone numbers from eSIMs</title>
        <link>https://www.bleepingcomputer.com/news/security/sim-swappers-now-stealing-phone-numbers-from-esims/</link>
        <pubDate>Thu, 14 Mar 2024 14:08:43 -0400</pubDate>
        <dc:creator>Bill Toulas</dc:creator>
        <category><![CDATA[Security]]></category>
        <guid>https://www.bleepingcomputer.com/news/security/sim-swappers-now-stealing-phone-numbers-from-esims/</guid>
	    <description><![CDATA[SIM swappers have adapted their attacks to steal a target's phone number from an eSIM card, a rewritable SIM chip present on many recent smartphone models. [...]]]></description>
    </item>
  </channel>
</rss>
`;

export const atomRelative: string = `
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns='http://www.w3.org/2005/Atom' xml:base='http://cowboyprogrammer.org'>
  <id>http://cowboyprogrammer.org</id>
  <title>Relative links</title>
  <updated>2003-12-13T18:30:02Z</updated>
  <link rel="self" href="/feed.atom"/>
</feed>
`;

export const atomRelativeNoBase: string = `
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns='http://www.w3.org/2005/Atom'>
  <id>http://cowboyprogrammer.org</id>
  <title>Relative links</title>
  <updated>2003-12-13T18:30:02Z</updated>
  <link rel="self" href="/feed.atom"/>
</feed>
`;

export const atomWithInvalidSelfLink: string = `
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns='http://www.w3.org/2005/Atom'>
  <id>http://cowboyprogrammer.org</id>
  <title>Relative links</title>
  <updated>2003-12-13T18:30:02Z</updated>
  <link rel="self" href="https://example.com/notvalid"/>
  <link rel="alternate" type="text/html" href="http://localhost:1313/" />
  <link rel="alternate" type="application/rss" href="http://localhost:1313/index.xml" />
  <link rel="alternate" type="application/json" href="http://localhost:1313/feed.json" />
</feed>
`;

export const atomWithHtmlEscapedContents: string = `
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns='http://www.w3.org/2005/Atom'>
  <id>http://cowboyprogrammer.org</id>
  <title>escaping test</title>
  <updated>2003-12-13T18:30:02Z</updated>
  <link rel="self" href="/feed.atom"/>
  <entry>
    <id>http://cowboyprogrammer.org/1</id>
    <title>text</title>
    <link href="http://cowboyprogrammer.org/1"/>
    <updated>2020-10-12T21:26:03Z</updated>
    <content type="text">&lt;img src=&quot;hello.jpg&amp;amp;cached=true&quot;&gt;</content>
  </entry>
  <entry>
    <id>http://cowboyprogrammer.org/2</id>
    <title>html</title>
    <link href="http://cowboyprogrammer.org/2"/>
    <updated>2020-10-12T21:26:03Z</updated>
    <content type="html">&lt;img src=&quot;hello.jpg&amp;amp;cached=true&quot;&gt;</content>
  </entry>
  <entry>
    <id>http://cowboyprogrammer.org/3</id>
    <title>xhtml</title>
    <link href="http://cowboyprogrammer.org/3"/>
    <updated>2020-10-12T21:26:03Z</updated>
    <content type="xhtml">
       <div xmlns="http://www.w3.org/1999/xhtml">
         <img src="hello.jpg&amp;cached=true"/>
      </div>
    </content>
  </entry>
</feed>
`;

export const rssWithHtmlEscapedDescription: string = `
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<rss version="2.0">
  <channel>
    <title>Cowboy Programmer</title>
    <link>https://cowboyprogrammer.org/</link>
    <description>Recent content in Cowboy Programmer on Cowboy Programmer</description>
    <language>en-us</language>
    <lastBuildDate>Sun, 01 Sep 2019 23:21:00 +0200</lastBuildDate>

    <item>
      <title>description</title>
      <link>http://cowboyprogrammer.org/4</link>
      <pubDate>Sun, 01 Sep 2019 23:21:00 +0200</pubDate>
      <author>jonas@cowboyprogrammer.org (Space Cowboy)</author>
      <guid>http://cowboyprogrammer.org/4</guid>
      <description>&lt;img src=&quot;hello.jpg&amp;amp;cached=true&quot;&gt;</description>
    </item>
  </channel>
</rss>
`;

export const atomWithUnknownProtocol: string = `
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns="http://www.w3.org/2005/Atom">
<id>gemini://gemini.circumlunar.space/news/</id>
<title>Official Project Gemini news feed</title>
<updated>2023-03-01T18:34:36.714818+00:00</updated>
<author>
<name>Solderpunk</name>
<email>solderpunk@posteo.net</email>
</author>
<link href="gemini://gemini.circumlunar.space/news/atom.xml" rel="self"/>
<link href="gemini://gemini.circumlunar.space/news/" rel="alternate"/>
<generator uri="https://lkiesow.github.io/python-feedgen" version="0.9.0">python-feedgen</generator>
<entry>
<id>gemini://gemini.circumlunar.space/news/2022_01_16.gmi</id>
<title>2022-01-16 - Mailing list downtime, official news feed</title>
<updated>2022-01-16T16:10:48.445244+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2022_01_16.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2022_01_22.gmi</id>
<title>2022-01-22 - Mailing list archives, Atom feed for official news</title>
<updated>2022-01-22T18:44:56.495170+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2022_01_22.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2022_01_30.gmi</id>
<title>2022-01-30 - Minor specification update (0.16.1)</title>
<updated>2022-01-30T14:38:04.738832+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2022_01_30.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2022_06_20.gmi</id>
<title>2022-06-20 - Three years of Gemini!</title>
<updated>2022-06-20T17:48:06.479966+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2022_06_20.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2023_01_08.gmi</id>
<title>2023-01-08 - Changing DNS server</title>
<updated>2023-01-08T14:12:22.568187+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2023_01_08.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2023_01_14.gmi</id>
<title>2023-01-14 - Tidying up gemini.circumlunar.space user capsules</title>
<updated>2023-01-14T15:58:26.933828+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2023_01_14.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2023_02_14.gmi</id>
<title>2023-02-14 - Empty user capsules removed</title>
<updated>2023-02-14T08:45:03.559039+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2023_02_14.gmi" rel="alternate"/>
</entry>
<entry>
<id>gemini://gemini.circumlunar.space/news/2023_03_01.gmi</id>
<title>2023-03-01 - Molly Brown upgrade</title>
<updated>2023-03-01T18:34:36.714818+00:00</updated>
<link href="gemini://gemini.circumlunar.space/news/2023_03_01.gmi" rel="alternate"/>
</entry>
</feed>
`;

