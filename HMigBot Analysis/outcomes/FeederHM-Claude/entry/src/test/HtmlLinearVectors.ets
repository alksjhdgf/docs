/**
 * HtmlLinearVectors.ets —— fnd-html-linear 向量（机械提取自源单测
 * app/src/test/java/com/nononsenseapps/feeder/model/html/HtmlLinearizerTest.kt 的输入 HTML 与 baseUrl；
 * 期望在 HtmlLinear.test.ets 中逐例照源断言）。纯数据。
 */

export interface LinearHtmlVector {
  name: string;
  html: string;
  baseUrl: string;
}

export const LINEAR_HTML_VECTORS: LinearHtmlVector[] = [
  {
    name: "should return empty list when input is empty",
    html: "<html><body></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearText when input is simple text",
    html: "<html><body>Hello, world!</body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "spaces inside headers are kept",
    html: "<html><body><h2><a href=\"http://example.com\">Link</a> <small>small</small></h2></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return annotations with bold, italic, and underline",
    html: "<html><body><b><i><u>Hello, world!</u></i></b></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return annotations with bold, italic, and underline interleaving",
    html: "<html><body><b><i><u>Hell</u>o</i>, wor</b>ld!</body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return own item for header",
    html: "<html><body><h1>Header 1</h1>Hello, world!</body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single item for nested divs",
    html: "<html><body><div><div>Hello, world!</div></div></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return ordered LinearList for ol",
    html: "<html><body><ol><li>Item 1</li><li>Item 2</li></ol></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return unordered LinearList for ul",
    html: "<html><body><ul><li>Item 1</li><li>Item 2</li></ul></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "surrounding span is preserved with list in middle",
    html: "<html><body><b>Before it<ul><li>Item 1</li><li>Item 22</li></ul>After</b></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image with alt text should return single Image",
    html: "<html><body><img src=\"https://example.com/image.jpg\" alt=\"Alt text\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image with bold alt text should return no formatting",
    html: "<html><body><img src=\"https://example.com/image.jpg\" alt=\"<b>Bold</b> text\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image inside a link",
    html: "<html><body><a href=\"https://example.com/link\"><img src=\"https://example.com/image.jpg\" alt=\"Alt text\"/></a></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image with defined size",
    html: "<html><body><img src=\"https://example.com/image.jpg\" width=\"100\" height=\"200\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "srcset image with pixel density and screenwidth versions available",
    html: "<html><body>\n<img srcset=\"https://example.com/image.jpg 1x, https://example.com/image-2x.jpg 2x, https://example.com/image-700w.jpg 700w, https://example.com/image-fallback.jpg\"/>\n</body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image with dataImgUrl",
    html: "<html><body><img data-img-url=\"https://example.com/image.jpg\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image with relative url",
    html: "<html><body><img src=\"/image.jpg\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple image with inline data image",
    html: "<html><body><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\"></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "simple figure image with figcaption",
    html: "<html><body><figure><img src=\"https://example.com/image.jpg\"/><figcaption>Alt <b>t</b>ext</figcaption></figure></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "figure inside a link",
    html: "<html><body><a href=\"https://example.com/link\">\n<figure><img src=\"https://example.com/image.jpg\"/><figcaption>Alt text</figcaption></figure>\n</a></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "p in a blockquote does not add newlines at end and cite is null",
    html: "<html><body><blockquote><p>Quote</p></blockquote></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "figure with two img tags one with srcset and one with dataImgUrl - only distinct results",
    html: "<html><body><figure>\n<img srcset=\"https://example.com/image.jpg 1x, https://example.com/image-2x.jpg 2x\"/>\n<img data-img-url=\"https://example.com/image.jpg\"/>\n</figure></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "figure with two img tags one with srcset and one with dataImgUrl all urls different",
    html: "<html><body><figure>\n<img srcset=\"https://example.com/image.jpg 1x, https://example.com/image-2x.jpg 2x\"/>\n<img data-img-url=\"https://example.com/image-3x.jpg\"/>\n</figure></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "pre block with code tag",
    html: "<html><body><pre><code>\nCode\n  block\n</code></pre></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "pre block",
    html: "<html><body><pre>\nCode\n  block\n</pre></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "pre block without code tag",
    html: "<html><body><pre>Not a code block</pre></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "audio with no sources is ignored",
    html: "<html><body><audio controls></audio></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "audio with two sources",
    html: "<html><body>\n<audio controls><source src=\"audio.mp3\" type=\"audio/mpeg\">\n<source src=\"https://example.com/audio.ogg\" type=\"audio/ogg\"></audio></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "content inside blockquote",
    html: "<p><a class=\"tumblr_blog\" href=\"https://everydaylouie.tumblr.com/post/716429042034802688/challenge\">everydaylouie</a>:</p>\n<blockquote>\n<div class=\"npf_row\">\n<figure class=\"tmblr-full\" data-orig-height=\"624\" data-orig-width=\"1200\">\n<img src=\"https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s640x960/75e2a17fad52257ac5c7326e123d125be18ecd14.png\" data-orig-height=\"624\" data-orig-width=\"1200\" srcset=\"https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s75x75_c1/48387a66ca77d9e8af781b47efb733f8e5abe553.png 75w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s100x200/9387531174b8be87ae89fd6f967e274336b7f5a4.png 100w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s250x400/435ce8fba2aa5f75a548a497f1157f563245dd93.png 250w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s400x600/3fc4822b65cab32e05ed0611b6721ab3ab0ba5c8.png 400w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s500x750/f86d4df43eb0de4695d3261cca41739278c9e6bc.png 500w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s540x810/64c4028177a81a99d416b8994b07b8d228b25ea5.png 540w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s640x960/75e2a17fad52257ac5c7326e123d125be18ecd14.png 640w, https://64.media.tumblr.com/55359709d06eb4309538800b64745d40/5149f25c974a1479-f7/s1280x1920/258a6c4e80c6403aa4163c73cf39c09183dd4b4a.png 1200w\" sizes=\"(max-width: 1200px) 100vw, 1200px\"/>\n</figure></div><p>CHALLENGE!</p></blockquote>",
    baseUrl: "https://example.com"
  },
  {
    name: "video with no sources is ignored",
    html: "<html><body><video controls></video></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "video with two sources",
    html: "<html><body>\n<video controls>\n<source src=\"video.mp4\" type=\"video/mp4\">\n<source src=\"https://example.com/video.webm\" type=\"video/webm\"></video></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "video with 1 source and negative width",
    html: "<html><body><video controls width=\"-1\"><source src=\"video.mp4\" type=\"video/mp4\"></video></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "image with negative heightPx",
    html: "<html><body><img src=\"https://example.com/image.jpg\" height=\"-1\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "iframe with youtube video",
    html: "<html><body><iframe src=\"https://www.youtube.com/embed/cjxnVO9RpaQ\"></iframe></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "iframe inside figure with youtube video",
    html: "<html><body>\n<figure class=\"wp-block-embed is-type-video is-provider-youtube wp-block-embed-youtube wp-embed-aspect-16-9 wp-has-aspect-ratio\"><div class=\"wp-block-embed__wrapper\">\n<iframe title=\"Därför är el-lastbilar bättre än diesel-lastbilar\" width=\"1170\" height=\"658\" src=\"https://www.youtube.com/embed/x_m02bUxfvE?feature=oembed\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen=\"\"></iframe>\n</div></figure>\n</body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "table block 2x2",
    html: "<html><body><table><tr><th>1</th><td>2</td></tr><tr><td>3</td><th>4</th></tr></table></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "table block 2x2 rtl",
    html: "<html dir=\"rtl\"><body><table><tr><th>1</th><td>2</td></tr><tr><td>3</td><th>4</th></tr></table></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "table with colspan, rowspan, and a double span",
    html: "<html><body>\n<table>\n<tr>\n    <th>Name</th>\n    <th>Age</th>\n    <th colspan=\"2\">Money Money</th>\n</tr>\n<tr>\n    <td rowspan=\"2\" colspan=\"2\">Bob</td>\n    <td>$300</td>\n    <td>0</td>\n</tr>\n<tr>\n    <td>$400</td>\n    <td>1</td>\n</tr>\n</table></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "table with zero colspan spans entire row",
    html: "<html><body>\n<table>\n<tr>\n    <th>Name</th>\n    <th>Age</th>\n    <th>Money</th>\n</tr>\n<tr>\n    <td colspan=\"0\">Bob</td>\n</tr>\n</table></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "cowboy table",
    html: "    <html><body>\n<table>\n<caption>\n<p>Table 1.\n</p><p>This table demonstrates the table rendering capabilities of Feeder's Reader view. This caption\nis by the spec allowed to contain most objects, except other tables. See\n<a href=\"https://www.w3.org/TR/2014/REC-html5-20141028/dom.html#flow-content-1\">flow content</a>.\n</p></caption>\n<thead>\n<tr>\n<th>Name\n</th><th>Number\n</th><th>Money\n</th></tr><tr>\n<th>First and Last name\n</th><th>What number human are you?\n</th><th>How much money have you collected?\n</th></tr></thead><tfoot>\n<tr>\n<th>No Comment\n</th><th>Early!\n</th><th>Sad\n</th></tr></tfoot><tbody>\n<tr>\n<td>Bob\n</td><td>66\n</td><td>$3\n</td></tr><tr>\n<td>Alice\n</td><td>999\n</td><td>$999999\n</td></tr><tr>\n<td>:O\n</td><td colspan=\"2\">OMG Col span 2\n</td></tr><tr>\n<td colspan=\"3\">WHAAAT. Triple span?!\n</td></tr><tr>\n<td colspan=\"0\">Firefox special zero span means to the end!\n</td></tr></tbody>\n</table></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "table with thead, tbody, and tfoot",
    html: "<html><body>\n<table>\n    <thead>\n        <tr><th>Name<th>Number<th>Money\n    <tbody>\n        <tr><td>Bob<td>66<td>$3\n        <tr><td>Alice<td>999<td>$999999\n    <tfoot>\n        <tr><td>No Comment<td>Early!<td>Sad\n</table>\n</body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "arctechnica list items are actually images readability4j",
    html: "<ul>\n <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01.jpeg 2560\" data-sub-html=\"#caption-2025663\">\n  <figure>\n   <figcaption id=\"caption-2025663\">\n    <span></span>\n    <p> Microsoft's Surface Pro 11 comes with Arm chips and an optional OLED display panel. </p>\n    <p> <span></span> Microsoft </p>\n   </figcaption>\n  </figure> </li>\n <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02.jpeg 2560\" data-sub-html=\"#caption-2025664\">\n  <figure>\n   <figcaption id=\"caption-2025664\">\n    <span></span>\n    <p> The Surface Pro 11's design is near-identical to the Surface Pro 8 and Surface Pro 9, and they're compatible with the same accessories. </p>\n    <p> <span></span> Microsoft </p>\n   </figcaption>\n  </figure> </li>\n <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03.jpeg 2560\" data-sub-html=\"#caption-2025665\">\n  <figure>\n   <figcaption id=\"caption-2025665\">\n    <span></span>\n    <p> Two USB-C ports, no headphone jack. A Smart Connect port is on the other side. </p>\n    <p> <span></span> Microsoft </p>\n   </figcaption>\n  </figure> </li>\n <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01.jpeg 2560\" data-sub-html=\"#caption-2025667\">\n  <figure>\n   <figcaption id=\"caption-2025667\">\n    <span></span>\n    <p> The new Surface Laptop 7, available in 13.8- and 15-inch models. </p>\n    <p> <span></span> Microsoft </p>\n   </figcaption>\n  </figure> </li>\n <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02.jpeg 2560\" data-sub-html=\"#caption-2025668\">\n  <figure>\n   <figcaption id=\"caption-2025668\">\n    <span></span>\n    <p> The keyboard, complete with Copilot key. </p>\n    <p> <span></span> Microsoft </p>\n   </figcaption>\n  </figure> </li>\n <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03.jpeg 2560\" data-sub-html=\"#caption-2025669\">\n  <figure>\n   <figcaption id=\"caption-2025669\">\n    <span></span>\n    <p> You get one more USB-C port than you did before. USB-A, Smart Connect, and the headphone jack are also present and accounted for. </p>\n    <p> <span></span> Microsoft </p>\n   </figcaption>\n  </figure> </li>\n</ul>",
    baseUrl: "https://example.com"
  },
  {
    name: "arstechnica list items are actually images",
    html: "<div class=\"gallery shortcode-gallery gallery-wide\">\n  <ul>\n            <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01.jpeg 2560\" data-sub-html=\"#caption-2025663\">\n        <figure style=\"height:735px;\">\n          <div class=\"image\" style=\"background-image:url('https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-01-980x735.jpeg'); background-color:#000\"></div>\n                        <figcaption id=\"caption-2025663\">\n              <span class=\"icon caption-arrow icon-drop-indicator\"></span>\n                                <div class=\"caption\">\n                  Microsoft's Surface Pro 11 comes with Arm chips and an optional OLED display panel.                  </div>\n                                                <div class=\"credit\">\n                  <span class=\"icon icon-camera\"></span>\n                                        Microsoft                                      </div>\n                            </figcaption>\n                    </figure>\n      </li>\n            <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02.jpeg 2560\" data-sub-html=\"#caption-2025664\">\n        <figure style=\"height:735px;\">\n          <div class=\"image\" style=\"background-image:url('https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-02-980x735.jpeg'); background-color:#000\"></div>\n                        <figcaption id=\"caption-2025664\">\n              <span class=\"icon caption-arrow icon-drop-indicator\"></span>\n                                <div class=\"caption\">\n                  The Surface Pro 11's design is near-identical to the Surface Pro 8 and Surface Pro 9, and they're compatible with the same accessories.                  </div>\n                                                <div class=\"credit\">\n                  <span class=\"icon icon-camera\"></span>\n                                        Microsoft                                      </div>\n                            </figcaption>\n                    </figure>\n      </li>\n            <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03.jpeg 2560\" data-sub-html=\"#caption-2025665\">\n        <figure style=\"height:735px;\">\n          <div class=\"image\" style=\"background-image:url('https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-11-03-980x735.jpeg'); background-color:#000\"></div>\n                        <figcaption id=\"caption-2025665\">\n              <span class=\"icon caption-arrow icon-drop-indicator\"></span>\n                                <div class=\"caption\">\n                  Two USB-C ports, no headphone jack. A Smart Connect port is on the other side.                  </div>\n                                                <div class=\"credit\">\n                  <span class=\"icon icon-camera\"></span>\n                                        Microsoft                                      </div>\n                            </figcaption>\n                    </figure>\n      </li>\n            <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01.jpeg 2560\" data-sub-html=\"#caption-2025667\">\n        <figure style=\"height:735px;\">\n          <div class=\"image\" style=\"background-image:url('https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-01-980x735.jpeg'); background-color:#000\"></div>\n                        <figcaption id=\"caption-2025667\">\n              <span class=\"icon caption-arrow icon-drop-indicator\"></span>\n                                <div class=\"caption\">\n                  The new Surface Laptop 7, available in 13.8- and 15-inch models.                  </div>\n                                                <div class=\"credit\">\n                  <span class=\"icon icon-camera\"></span>\n                                        Microsoft                                      </div>\n                            </figcaption>\n                    </figure>\n      </li>\n            <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02.jpeg 2560\" data-sub-html=\"#caption-2025668\">\n        <figure style=\"height:735px;\">\n          <div class=\"image\" style=\"background-image:url('https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-02-980x735.jpeg'); background-color:#000\"></div>\n                        <figcaption id=\"caption-2025668\">\n              <span class=\"icon caption-arrow icon-drop-indicator\"></span>\n                                <div class=\"caption\">\n                  The keyboard, complete with Copilot key.                  </div>\n                                                <div class=\"credit\">\n                  <span class=\"icon icon-camera\"></span>\n                                        Microsoft                                      </div>\n                            </figcaption>\n                    </figure>\n      </li>\n            <li data-thumb=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03-150x150.jpeg\" data-src=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03.jpeg\" data-responsive=\"https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03-980x735.jpeg 1080, https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03.jpeg 2560\" data-sub-html=\"#caption-2025669\">\n        <figure style=\"height:735px;\">\n          <div class=\"image\" style=\"background-image:url('https://cdn.arstechnica.net/wp-content/uploads/2024/05/surface-laptop-03-980x735.jpeg'); background-color:#000\"></div>\n                        <figcaption id=\"caption-2025669\">\n              <span class=\"icon caption-arrow icon-drop-indicator\"></span>\n                                <div class=\"caption\">\n                  You get one more USB-C port than you did before. USB-A, Smart Connect, and the headphone jack are also present and accounted for.                  </div>\n                                                <div class=\"credit\">\n                  <span class=\"icon icon-camera\"></span>\n                                        Microsoft                                      </div>\n                            </figcaption>\n                    </figure>\n      </li>\n        </ul>\n</div>",
    baseUrl: "https://arstechnica.com"
  },
  {
    name: "test with feeder news changelog",
    html: "<p>Aitor Salaberria (1):</p>\n<ul>\n<li>[d719ced2] Translated using Weblate (Basque)</li>\n</ul>\n<p>Belmar BegiÄ‡ (1):</p>\n<ul>\n<li>[42e567d5] Updated Bosnian translation using Weblate</li>\n</ul>\n<p>Jonas Kalderstam (7):</p>\n<ul>\n<li>[f2486f3c] Upgraded some dependency versions</li>\n<li>[e69ed180] Fixed sync indicator: should now stay on screen as long as\nsync is running</li>\n<li>[10358f20] Fixed deprecation warnings</li>\n<li>[05e1066c] Removed unused proguard rule</li>\n<li>[8d87a2a1] Fixed broken navigation after version upgrade</li>\n<li>[cd1d3df0] Fixed foreground service changes in Android 14</li>\n<li>[7939495a] Fixed Saved Articles count only showing unread instead of\ntotal</li>\n</ul>\n<p>Vitor Henrique (1):</p>\n<ul>\n<li>[67ab5429] Updated Portuguese (Brazil) translation using Weblate</li>\n</ul>\n<p>bowornsin (1):</p>\n<ul>\n<li>[e699f62a] Updated Thai translation using Weblate</li>\n</ul>\n<p>ngocanhtve (1):</p>\n<ul>\n<li>[fa7eb98a] Translated using Weblate (Vietnamese)</li>\n</ul>\n<p>zmni (1):</p>\n<ul>\n<li>[b56e987b] Updated Indonesian translation using Weblate</li>\n</ul>",
    baseUrl: "https://news.nononsenseapps.com"
  },
  {
    name: "cowboyprogrammer transmission",
    html: "\n\n<p>Quick post to immortilize the configuration to get transmission-daemon working with a\nwireguard tunnel.</p>\n\n<p>If you don&rsquo;t have a wireguard tunnel, head to <a\n    href=\"https://mullvad.net/en/\">https://mullvad.net/en/</a> and get one.</p>\n\n<h2\n    id=\"transmission-config\">Transmission config</h2>\n\n<p>First, the transmission config is\nreally simple:</p>\n\n<pre><code>#/etc/transmission-daemon/settings.json\n{\n  [...]\n\n  &quot;bind-address-ipv4&quot;: &quot;X.X.X.X&quot;,\n  &quot;bind-address-ipv6&quot;: &quot;xxxx:xxxx:xxxx:xxxx::xxxx&quot;,\n  &quot;peer-port&quot;: 24328,\n  &quot;rpc-bind-address&quot;: &quot;0.0.0.0&quot;,\n\n  [...]\n}\n</code></pre>\n\n\n<p>I also run the daemon using the following service for good measure:</p>\n\n\n<pre><code># /etc/systemd/system/transmission-daemon.service\n[Unit]\nDescription=Transmission BitTorrent Daemon Under VPN\nAfter=network-online.target\nAfter=wg-quick@wgtorrents.service\nRequires=wg-quick@wgtorrents.service\n\n[Service]\nUser=debian-transmission\nExecStart=/usr/bin/transmission-daemon -f --log-error --bind-address-ipv4 X.X.X.X --bind-address-ipv6 xxxx:xxxx:xxxx:xxxx::xxxx --rpc-bind-address 0.0.0.0\n\n[Install]\nWantedBy=multi-user.target\n\n</code></pre>\n\n\n<h2 id=\"wireguard-config\">Wireguard config</h2>\n\n<p>All the magic happens in the PostUp rule where\n    a routing rule is added for any traffic originating from the wireguard IP addresses.</p>\n\n\n<pre><code>#/etc/wireguard/wgtorrents.conf\n[Interface]\nPrivateKey=\nAddress=X.X.X.X/32,xxxx:xxxx:xxxx:xxxx::xxxx/128\n# Inhibit default table creation\nTable=off\n# But do create a default route for the specific ip addresses\nPostUp = systemd-resolve -i %i --set-dns=193.138.218.74 --set-domain=~.; ip rule add from X.X.X.X table 42; ip route add default dev %i table 42; ip -6 rule add from xxxx:xxxx:xxxx:xxxx::xxxx table 42\nPostDown = ip rule del from X.X.X.X table 42; ip -6 rule del from xxxx:xxxx:xxxx:xxxx::xxxx table 42\n\n[Peer]\nPersistentKeepalive=25\nPublicKey=m4jnogFbACz7LByjo++8z5+1WV0BuR1T7E1OWA+n8h0=\nEndpoint=se4-wireguard.mullvad.net:51820\nAllowedIPs=0.0.0.0/0,::/0\n</code></pre>\n\n\n<p>Enable it all by doing</p>\n\n\n<pre><code>systemctl enable --now wg-quick@wgtorrents.timer\nsystemctl enable --now transmission-daemon.service\n</code></pre>",
    baseUrl: "https://cowboyprogrammer.org"
  },
  {
    name: "cowboyprogrammer exhaustive",
    html: "<p>Just a placeholder so far. Needed a known blog to test a few things with.</p> <h2\n        id=\"animated-images\">Animated images!</h2> <p><img\n        src=\"https://cowboyprogrammer.org/images/2021/06/animated-webp-supported.webp\"\n        alt=\"Animated Webp image\"/></p> <p><img\n        src=\"https://cowboyprogrammer.org/images/2021/06/rotating_earth.gif\" alt=\"Animated Gif\"/>\n</p> <p>And at long last animated in the reader itself!</p> <p><img\n        src=\"https://cowboyprogrammer.org/images/2021/06/reader_animated.gif\"\n        alt=\"Animated reader\"/></p> <h2 id=\"text-formatting\">Text formatting</h2> <p>A <a\n        href=\"https://gitlab.com/spacecowboy/Feeder/-/merge_requests/318\">link</a> to Gitlab.</p>\n<p>Some <code>inline code formatting</code>.</p> <p>And then</p>\n<pre><code>A code block with some lines of code should be scrollable if one very very long line with many sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss </code></pre>\n<p>A table!</p>\n<table>\n    <caption><p>Table 1.\n        <p>This table demonstrates the table rendering capabilities of Feeder's Reader view. This\n            caption is by the spec allowed to contain most objects, except other tables. See <a\n                    href=\"https://www.w3.org/TR/2014/REC-html5-20141028/dom.html#flow-content-1\">flow\n                content</a>.</caption>\n    <thead>\n    <tr>\n        <th>Name\n        <th>Number\n        <th>Money\n    <tr>\n        <th>First and Last name\n        <th>What number human are you?\n        <th>How much money have you collected?\n    <tfoot>\n    <tr>\n        <th>No Comment\n        <th>Early!\n        <th>Sad\n            <tbody>\n    <tr>\n        <td>Bob\n        <td>66\n        <td>$3\n    <tr>\n        <td>Alice\n        <td>999\n        <td>$999999\n    <tr>\n        <td>:O\n        <td colspan=\"2\">OMG Col span 2\n    <tr>\n        <td colspan=\"3\">WHAAAT. Triple span?!\n    <tr>\n        <td colspan=\"0\">Firefox special zero span means to the end!\n</table> <p>And this is a table with an image in it</p>\n<table>\n    <tbody>\n    <tr>\n        <td><img src=\"https://cowboyprogrammer.org/images/Ardebian_logo_512_0.png\"\n                 alt=\"Debian logo\"></td>\n    </tr>\n    <tr>\n        <td> Should be a debian logo above</td>\n    </tr>\n    </tbody>\n</table> <p>And this is a link with an image inside</p> <p><a\n        href=\"https://cowboyprogrammer.org/2016/08/zopfli_all_the_things/\"> <img\n        src=\"https://cowboyprogrammer.org/images/2017/10/zopfli_all_the_things_32.png\" alt=\"A meme\">\n</a></p> <p>Here is a blockquote with a nested quote in it:</p>\n<blockquote><p>Once upon a time</p>\n    <p>A dev coded compose it was written:</p>\n    <blockquote><p>@Composable fun FunctionFuns()</p></blockquote>\n    <p>And there was code</p></blockquote> <p>Here comes some headers</p> <h1 id=\"header-1\">Header\n    1</h1> <h2 id=\"header-2\">Header 2</h2> <h3 id=\"header-3\">Header 3</h3> <h4 id=\"header-4\">Header\n    4</h4> <h5 id=\"header-5\">Header 5</h5> <h6 id=\"header-6\">Header 6</h6> <h2 id=\"lists\">Lists</h2>\n<p>Here are some lists</p>\n<ul>\n    <li>Bullet</li>\n    <li>Point</li>\n    <li>List</li>\n</ul> <p>and</p>\n<ol>\n    <li>Numbered</li>\n    <li>List</li>\n    <li>Here</li>\n</ol> <h2 id=\"videos\">Videos</h2> <p>Here&rsquo;s an embedded youtube video</p>\n<iframe width=\"560\" height=\"315\" src=\"https://www.youtube.com/embed/1OfxlSG6q5Y\"\n        title=\"YouTube video player\" frameborder=\"0\"\n        allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\"\n        allowfullscreen></iframe> <p>Here&rsquo;s an HTML5 video</p>\n<video width=\"320\" height=\"240\" controls>\n    <source src=\"https://www.w3schools.com/html/mov_bbb.mp4\" type=\"video/mp4\">\n    <source src=\"https://www.w3schools.com/html/mov_bbb.ogg\" type=\"video/ogg\">\n    Your browser does not support the video tag.\n</video>\n<hr/> <p>Other posts in the <b>Rewriting Feeder in Compose</b> series:</p>\n<ul class=\"series\">\n    <li>2021-06-09 &mdash; The biggest update to Feeder so far</li>\n</ul>",
    baseUrl: "https://cowboyprogrammer.org"
  },
  {
    name: "table with single column is optimized out",
    html: "<table>\n    <tbody>\n        <tr>\n            <td>Single column table</td>\n        </tr>\n        <tr>\n            <td>Second row</td>\n        </tr>\n    </tbody>\n</table>",
    baseUrl: "https://example.com"
  },
  {
    name: "insane nested table",
    html: "      <table class=\"body\"\nstyle=\"-ms-text-size-adjust: 100%; border-spacing: 0; border-collapse: collapse; vertical-align: top; margin-bottom: 0; background: #f3f3f3; height: 100%; width: 100%; color: #0a0a0a; font-family: Helvetica,Arial,sans-serif; font-weight: 400; margin: 0; text-align: left; font-size: 16px; line-height: 1.3; mso-table-lspace: 0; mso-table-rspace: 0;\">\n        <tbody style=\"-ms-text-size-adjust: 100%; border: 0 solid transparent;\">\n          <tr style=\"-ms-text-size-adjust: 100%; vertical-align: top; text-align: left;\">\n            <td align=\"center\" class=\"center acym__wysid__template__content\" valign=\"top\"\n              style=\"-ms-text-size-adjust: 100%; word-wrap: break-word; -webkit-hyphens: auto; -moz-hyphens: auto; hyphens: auto; vertical-align: top; color: #0a0a0a; font-family: Helvetica,Arial,sans-serif; font-weight: 400; margin: 0; text-align: left; font-size: 16px; line-height: 1.3; background-color: rgb(239, 239, 239); padding: 40px 0 120px 0; border-collapse: collapse; mso-table-lspace: 0; mso-table-rspace: 0;\">\n              <center style=\"-ms-text-size-adjust: 100%; width: 100%; min-width: 580px;\">\n                <table align=\"center\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\"\n                  style=\"-ms-text-size-adjust: 100%; border-spacing: 0; border-collapse: collapse; vertical-align: top; text-align: left; margin-bottom: 0; max-width: 580px; mso-table-lspace: 0; mso-table-rspace: 0;\">\n                  <tbody style=\"-ms-text-size-adjust: 100%; border: 0 solid transparent;\">\n                    <tr style=\"-ms-text-size-adjust: 100%; vertical-align: top; text-align: left;\">\n                      <td class=\"acym__wysid__row ui-droppable ui-sortable\"\n                        style=\"-ms-text-size-adjust: 100%; word-wrap: break-word; -webkit-hyphens: auto; -moz-hyphens: auto; hyphens: auto; vertical-align: top; color: #0a0a0a; font-family: Helvetica,Arial,sans-serif; font-weight: 400; margin: 0; text-align: left; font-size: 16px; line-height: 1.3; background-color: #fff; min-height: 0px; display: table-cell; border-collapse: collapse; mso-table-lspace: 0; mso-table-rspace: 0;\">\n                        <table class=\"row acym__wysid__row__element\" bgcolor=\"#ffffff\" border=\"0\" cellpadding=\"0\"\n                          cellspacing=\"0\"\n                          style=\"-ms-text-size-adjust: 100%; border-spacing: 0; vertical-align: top; text-align: left; margin-bottom: 0; background-color: #fff; width: 100%; position: relative; padding: 10px; z-index: 100; padding-left: 25px; border-radius: 4px; border-width: 0px; border-style: solid; padding-right: 25px; mso-table-lspace: 0; mso-table-rspace: 0; border-collapse: initial;\">\n                          <tbody bgcolor=\"#ffffff\"\n                            style=\"-ms-text-size-adjust: 100%; border: 0 solid transparent; background-color: transparent;\">\n                            <tr style=\"-ms-text-size-adjust: 100%; vertical-align: top; text-align: left;\">\n                              <th class=\"small-12 medium-12 large-12 columns\" height=\"268.1999969482422\"\n                                style=\"-ms-text-size-adjust: 100%; color: #0a0a0a; font-family: Helvetica,Arial,sans-serif; font-weight: 400; text-align: left; font-size: 16px; line-height: 1.3; margin: 0 auto; width: 580px; height: 268.2px;\">\n                                <table class=\"acym__wysid__column\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\"\n                                  style=\"-ms-text-size-adjust: 100%; border-spacing: 0; border-collapse: collapse; vertical-align: top; text-align: left; margin-bottom: 0; width: 100%; min-height: 0px; display: table; mso-table-lspace: 0; mso-table-rspace: 0;\">\n                                  <tbody class=\"ui-sortable\"\n                                    style=\"-ms-text-size-adjust: 100%; border: 0 solid transparent; min-height: 0px; display: table-row-group;\">\n                                    <tr class=\"acym__wysid__column__element ui-draggable\"\n                                      style=\"-ms-text-size-adjust: 100%; vertical-align: top; text-align: left; position: relative; inset: inherit; height: auto;\">\n                                      <td class=\"large-12 acym__wysid__column__element__td\"\n                                        style=\"-ms-text-size-adjust: 100%; word-wrap: break-word; -webkit-hyphens: auto; -moz-hyphens: auto; hyphens: auto; vertical-align: top; color: #0a0a0a; font-family: Helvetica,Arial,sans-serif; font-weight: 400; margin: 0; text-align: left; font-size: 16px; line-height: 1.3; width: 100%; outline: rgb(0, 163, 254) dashed 0px; outline-offset: -1px; mso-table-lspace: 0; mso-table-rspace: 0; border-collapse: collapse;\">\n                                        <div class=\"acym__wysid__tinymce--text mce-content-body\" spellcheck=\"false\"\n                                          contenteditable=\"false\" id=\"mce_12\"\n                                          style=\"-ms-text-size-adjust: 100%; height: 100%; position: relative;\">\n                                          <h3\n                                            style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; margin: 0; text-align: left; word-wrap: normal; margin-bottom: 10px; font-size: 28px; font-family: Helvetica; font-weight: normal; line-height: inherit; font-style: normal; color: #000000;\">\n                                            &nbsp;\n                                          </h3>\n                                          <h3\n                                            style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; margin: 0; text-align: left; word-wrap: normal; margin-bottom: 10px; font-size: 28px; font-family: Helvetica; font-weight: normal; line-height: inherit; font-style: normal; color: #000000;\">\n                                            Dear E S Znqiiwuyp Sjpv,\n                                          </h3>\n                                          <p\n                                            style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; margin: 0; text-align: left; margin-bottom: 0; word-break: break-word; font-family: Helvetica; font-size: 12px; line-height: inherit; font-weight: normal; font-style: normal; color: #000000;\">\n                                            <span\n                                              style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; color: inherit; font-size: 18px;\">You&apos;\n                                              ve subscribed to the OpenSciences.org newsletter. Please confirm this was\n                                              your intention:</span><br style=\"-ms-text-size-adjust: 100%;\"></p>\n                                          <p\n                                            style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; margin: 0; text-align: left; margin-bottom: 0; word-break: break-word; font-family: Helvetica; font-size: 12px; line-height: inherit; font-weight: normal; font-style: normal; color: #000000;\">\n                                            &nbsp;\n                                          </p>\n                                          <h1\n                                            style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; margin: 0; word-wrap: normal; word-break: break-word; font-family: Helvetica; font-size: 34px; line-height: inherit; font-weight: normal; font-style: normal; color: #000000; text-align: left; margin-bottom: 10px;\">\n                                            &nbsp;\n                                            <a target=\"_blank\"\n                                              href=\"https://www.opensciences.org/component/acym/frontusers/confirm?userId=3513&userKey=oqyAhMH5J0BOL4\"\n                                              style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; font-weight: 400; margin: 0; text-align: left; line-height: 1.3; text-decoration: none; color: #2199e8; font-family: Helvetica;\"><span\n                                                class=\"acym_confirm acym_link\"\n                                                style=\"-ms-text-size-adjust: 100%; color: #0000f1; font-size: 12px; font-weight: 400; font-style: normal; font-family: Helvetica;\">Click\n                                                here to confirm your subscription</span></a>&zwj;\n                                            <br style=\"-ms-text-size-adjust: 100%;\">\n                                          </h1>\n                                          <p\n                                            style=\"-ms-text-size-adjust: 100%; mso-line-height-rule: exactly; margin: 0; margin-bottom: 0; word-break: break-word; font-family: Helvetica; font-size: 12px; line-height: inherit; font-weight: normal; font-style: normal; color: #000000; text-align: left;\">\n                                            &nbsp;\n                                            <br style=\"-ms-text-size-adjust: 100%;\">\n                                          </p>\n                                        </div>\n                                      </td>\n                                    </tr>\n                                  </tbody>\n                                </table>\n                              </th>\n                            </tr>\n                          </tbody>\n                        </table>\n                      </td>\n                    </tr>\n                  </tbody>\n                </table>\n              </center>\n            </td>\n          </tr>\n        </tbody>\n      </table>",
    baseUrl: "https://kill-the-newsletter.com"
  },
  {
    name: "two divs enclosing a paragraph of text should return single LinearText with combined ids",
    html: "<html><body><div id=\"div1\"><div id=\"div2\"><p>Hello, world!</p></div></div></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearImage with correct ids when input is an image",
    html: "<html><body><img id=\"img1\" src=\"https://example.com/image.jpg\" alt=\"Alt text\"/></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearList with correct ids when input is an unordered list",
    html: "<html><body><ul id=\"list1\"><li id=\"item1\">Item 1</li><li id=\"item2\">Item 2</li></ul></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearBlockQuote with correct ids when input is a blockquote",
    html: "<html><body><blockquote id=\"quote1\"><p id=\"para1\">Quote</p></blockquote></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearAudio with correct ids when input is an audio element",
    html: "<html><body><audio id=\"audio1\" controls><source src=\"audio.mp3\" type=\"audio/mpeg\"></audio></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearTable with correct ids when input is a 2x2 table",
    html: "<html><body><table id=\"table1\"><tr><td id=\"cell1\">Cell 1</td><td id=\"cell2\">Cell 2</td></tr><tr><td id=\"cell3\">Cell 3</td><td id=\"cell4\">Cell 4</td></tr></table></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "should return single LinearVideo with correct ids when input is a video element",
    html: "<html><body><video id=\"video1\" controls><source src=\"video.mp4\" type=\"video/mp4\"></video></body></html>",
    baseUrl: "https://example.com"
  },
  {
    name: "paragraph section followed by link will have space between",
    html: "<p style=\"display: inline;\" class=\"readability-styled\">The SystemV file-system that implements Xenix FS, SystemV/386 FS, and Coherent FS is set to be removed from the Linux kernel. The SystemV file-system was</p><a href=\"https://www.phoronix.com/news/Linux-SysV-File-System-Orphan\">orphaned back in 2023</a>",
    baseUrl: "https://example.com"
  }
];

export function linearHtml(name: string): LinearHtmlVector {
  for (let i = 0; i < LINEAR_HTML_VECTORS.length; i++) {
    if (LINEAR_HTML_VECTORS[i].name === name) {
      return LINEAR_HTML_VECTORS[i];
    }
  }
  throw new Error('No linear html vector: ' + name);
}

/** FullTextParserKtTest 资源前缀（截至首个 charset 声明之后；状态机顺序处理，截断不影响结果） */
export const GB2312_HTML_PREFIX: string =
  '<!DOCTYPE html>\n<html>\n<head>\n<meta http-equiv="Content-Type" content="text/html; charset=gb2312">\n<title>';
export const MUHASEBETRE_ARTICLE_PREFIX: string =
  '\n<meta charset="windows-1254">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n';

/**
 * FullTextParserKtTest `guesses gb from html` 资源原样：input/Feeder/app/src/test/resources/com/nononsenseapps/feeder/model/gb2312.html
 * （24982 字节 GB2312/GB18030 真实字节，base64；用 TextCodec.base64DecodeStrict 还原）。
 */
export const GB2312_HTML_B64: string =
  'PCFET0NUWVBFIGh0bWw+CjxodG1sPgo8aGVhZD4KPG1ldGEgaHR0cC1lcXVpdj0iQ29udGVudC1UeXBlIiBjb250ZW50PSJ0ZXh0L2h0bWw7IG' +
  'NoYXJzZXQ9Z2IyMzEyIj4KPHRpdGxlPjEw1Koyxr+7xrXGwf3Asb23vbQrsdvKvdGq0bnSxyvE0MWuwM+1+dCsK7Plt+bSwiuyucuuxefO7Su7' +
  'pLeiy9ggLSBRUdK1zvHA1tSwPC90aXRsZT4KPG1ldGEgbmFtZT0ia2V5d29yZHMiIGNvbnRlbnQ9IjEw1Koyxr+7xrXGwf3Asb23vbQrsdvKvd' +
  'Gq0bnSxyvE0MWuwM+1+dCsK7Plt+bSwiuyucuuxefO7Su7pLeiy9giIC8+CjxtZXRhIG5hbWU9ImRlc2NyaXB0aW9uIiBjb250ZW50PSIxMNSq' +
  'Msa/u8a1xsH9wLG9t720K7Hbyr3RqtG50scrxNDFrsDPtfnQrCuz5bfm0sIrsrnLrsXnzu0ru6S3osvYICxRUdK1zvHA1tSwIiAvPgo8bWV0YS' +
  'BuYW1lPSJ2aWV3cG9ydCIgY29udGVudD0id2lkdGg9ZGV2aWNlLXdpZHRoLCBpbml0aWFsLXNjYWxlPTEuMCwgbWF4aW11bS1zY2FsZT0xLjAs' +
  'IHVzZXItc2NhbGFibGU9bm8iPgo8bGluayByZWw9ImNhbm9uaWNhbCIgaHJlZj0iaHR0cDovL3d3dy5xcXlld3UuY29tL2FydGljbGUvZHMvMj' +
  'AyNS8yMDI1MDIwOTIwMTkxNi5odG1sIj4KPGxpbmsgaHJlZj0iL3NraW5zL2RlZmF1bHQvYm9vdHN0cmFwLm1pbi5jc3MiIHJlbD0ic3R5bGVz' +
  'aGVldCI+CjxsaW5rIGhyZWY9Ii9za2lucy9kZWZhdWx0L3N0eWxlMi5jc3MiIHJlbD0ic3R5bGVzaGVldCI+CjwvaGVhZD4KPGJvZHk+CjxoZW' +
  'FkZXI+CjxhIGhyZWY9Ii8iPjxpbWcgc3JjPSIvc2tpbnMvZGVmYXVsdC9sb2dvLmdpZiIgaWQ9ImxvZ28iPjwvYT4KPC9oZWFkZXI+CjxuYXY+' +
  'Cjx1bD4KPGxpPjxhIGhyZWY9Ii8iIHRhcmdldD0iX2JsYW5rIj48c3Bhbj7K19KzPC9zcGFuPjwvYT48L2xpPgo8bGk+PGEgaHJlZj0iL3NvZn' +
  'QvMi9pbmRleC5odG1sIiB0YXJnZXQ9Il9ibGFuayI+PHNwYW4+UVG9zLPMPC9zcGFuPjwvYT48L2xpPgo8bGk+PGEgaHJlZj0iL3NvZnQvMS9p' +
  'bmRleC5odG1sIiB0YXJnZXQ9Il9ibGFuayI+PHNwYW4+UVHI7bz+PC9zcGFuPjwvYT48L2xpPgo8bGk+PGEgaHJlZj0iL2FydGljbGUvMy9pbm' +
  'RleC5odG1sIiB0YXJnZXQ9Il9ibGFuayI+PHNwYW4+UVHQws7FPC9zcGFuPjwvYT48L2xpPgo8bGk+PGEgaHJlZj0iL2FydGljbGUvNC9pbmRl' +
  'eC5odG1sIiB0YXJnZXQ9Il9ibGFuayI+PHNwYW4+UVG49tDUPC9zcGFuPjwvYT48L2xpPgo8bGk+PGEgaHJlZj0iL2FydGljbGUvNS9pbmRleC' +
  '5odG1sIiB0YXJnZXQ9Il9ibGFuayI+PHNwYW4+zbzGrMvYssQ8L3NwYW4+PC9hPjwvbGk+CjxsaT48YSBocmVmPSIvZ29uZ2x1ZS8iIHRhcmdl' +
  'dD0iX2JsYW5rIj48c3Bhbj7Tzs+3uaXC1Dwvc3Bhbj48L2E+PC9saT4KPGxpPjxhIGhyZWY9Ii9rZWppLyIgdGFyZ2V0PSJfYmxhbmsiPjxzcG' +
  'FuPr/GvLzA1tSwPC9zcGFuPjwvYT48L2xpPgo8bGk+PGEgaHJlZj0iL3FpdGEvIiB0YXJnZXQ9Il9ibGFuayI+PHNwYW4+1NPG39TTsMs8L3Nw' +
  'YW4+PC9hPjwvbGk+CjxsaT48YSBocmVmPSIvYXJ0aWNsZS9kcy8iIHRhcmdldD0iX2JsYW5rIj48c3Bhbj6258rWtbM8L3NwYW4+PC9hPjwvbG' +
  'k+CjwvdWw+CjxkaXYgY2xhc3M9ImNsZWFyZml4Ij48L2Rpdj4KPC9uYXY+CjxkaXYgY2xhc3M9InlocyI+PHNjcmlwdCBzcmM9Ii9qcy90b25n' +
  'eW9uZy5qcyIgbGFuZ3VhZ2U9ImphdmFzY3JpcHQiPjwvc2NyaXB0PjwvZGl2PgoKPGRpdiBjbGFzcz0iY29udGFpbmVyIj4KPGgzPjEw1Koyxr' +
  '+7xrXGwf3Asb23vbQrsdvKvdGq0bnSxyvE0MWuwM+1+dCsK7Plt+bSwiuyucuuxefO7Su7pLeiy9g8L2gzPgo8ZGl2IGNsYXNzPSJjb250ZW50' +
  'Ij4KPGRpdiBjbGFzcz0iY29udGVudC1sZWZ0LWluZm8iPgo8YSBocmVmPSIvIj5RUdK1zvHA1tSwPC9hPiCh+iA8YSBocmVmPSIvYXJ0aWNsZS' +
  '8iPs7E1cLW0NDEPC9hPiCh+iA8YSBocmVmPSIvYXJ0aWNsZS9kcy9pbmRleC5odG1sIj7M7MzstufK1rzbPC9hPgo8L2Rpdj4KPGRpdiBjbGFz' +
  'cz0ieWhzIj48c2NyaXB0IHNyYz0iL2pzL3d6eWgzLmpzIiBsYW5ndWFnZT0iamF2YXNjcmlwdCI+PC9zY3JpcHQ+PC9kaXY+CjxwPjxzcGFuIH' +
  'N0eWxlPSJjb2xvcjogIzAwMDBmZiI+PHN0cm9uZz7P1tTaw7/M7M3GtcS2q873trzKx7K7zay1xKGjtPO80tTa0rPD5rXXsr/X7r38N8zstcTN' +
  'xrz2tqvO96Gj09DQqbu5yse/ydLUwvK1xDwvc3Ryb25nPjwvc3Bhbj48L3A+CjxwPjxzcGFuIHN0eWxlPSJjb2xvcjogI2ZmMDAwMCI+PHN0cm' +
  '9uZz7I58O/yNXNxrz2w7vPsru2tcSho7/J0tS1vTxzcGFuIHN0eWxlPSJjb2xvcjogI2ZmMDBmZiI+yK/N+Lm6PC9zcGFuPqO6PGEgaHJlZj0i' +
  'aHR0cHM6Ly93d3cucXVhbndnLmNvbS8iPmh0dHBzOi8vd3d3LnF1YW53Zy5jb20vPC9hPjwvc3Ryb25nPjwvc3Bhbj48c3BhbiBzdHlsZT0iY2' +
  '9sb3I6ICNmZjAwMDAiPjxzdHJvbmc+IL34yKXL0cv3PC9zdHJvbmc+PC9zcGFuPjwvcD4KPHA+PGEgaHJlZj0iaHR0cHM6Ly9qcS5xcS5jb20v' +
  'P193dj0xMDI3Jms9NWFZaThPdiI+PHN0cm9uZz6hvrbnytYyyLqjujkzMjQ4NzQ5ob88L3N0cm9uZz48c3BhbiBzdHlsZT0iY29sb3I6IHJnYi' +
  'gyNTUsMCwwKSI+PGI+teO797/sy9m808jro6E8L2I+PC9zcGFuPjwvYT48c3Ryb25nPsO/zOzK1ravt6KjrM/7z6Kyu7bgo6zKyrrPsLK+srXE' +
  'tufK1qOhPC9zdHJvbmc+PC9wPgo8ZGl2PjxzcGFuIHN0eWxlPSJjb2xvcjogIzAwMDBmZiI+w7/M7M3GtcS2q873trzKx8L0vNLLos/6wb+6zb' +
  'rDxsC1xLarzvejrLKisrvKx7Hj0su+zcrH1srBv7K7usO78tT10fksv7TJz77NvqG/7M/CtaUhPC9zcGFuPjwvZGl2Pgo8ZGl2Pj09PT09PT09' +
  'PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT08L2Rpdj4KPGRpdj48Zm9udCBjb2xvcj0iI2' +
  'ZmMDAwMCIgc3R5bGU9ImZvbnQtc2l6ZTogMThweCI+PHN0cm9uZz7QobHgw7/M7M3GvPa1xLarzve2vMrH1+67rsvjtcQs09DSu9CpyrHQp8iv' +
  'u+HU2si6wO+3oqOhPC9zdHJvbmc+PC9mb250PjwvZGl2Pgo8ZGl2Pj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT' +
  '09PT09PT09PT09PT09PT09PT09PT08YnIvPgo8c3BhbiBzdHlsZT0iYmFja2dyb3VuZC1jb2xvcjogIzAwMDAwMCI+PHNwYW4gc3R5bGU9ImNv' +
  'bG9yOiAjMDBmZmZmIj48c3Bhbj48c3Ryb25nPqG2obahtqG2obahtqG2obahtqG2MS0xMNSq16jH+KG3obeht6G3obeht6G3obeht6G3obehtz' +
  'wvc3Ryb25nPjwvc3Bhbj48L3NwYW4+PC9zcGFuPjwvZGl2Pgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9p' +
  'NC8yNzc0NzY0NTI4LypvMSpjKm4wMXB2KmQqbTUyMWoqanMqZCphMSplankqeV8hITI3NzQ3NjQ1MjguanBnIiB3aWR0aD0iNDMwIiBoZWlnaH' +
  'Q9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7' +
  'IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+tLq54sqzxre7xrXGwf3Asb23vbQxMDBnKj' +
  'I8YnIvPgqhvtStvNuhvzEyLjUx1Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IHJnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzEwLjUx1Ko8' +
  'YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS91ZnRic3FzIiB0YXJnZX' +
  'Q9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vdWZ0YnNxczwvYT48YnIvPgqhvszUv9rB7qG/NjIoIENaMzQ1NyBPeDlHZVRs' +
  'Wjc0UigvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pbWdleHRyYS9pMi' +
  '82NTkyNzgzNjQvKm8xKmMqbjAxOWM1dipsKmsyKmJlbGkqcCpnbypnKnE1XyEhNjU5Mjc4MzY0LmpwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0' +
  'MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb2' +
  '5jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPrCutcLJ2bb51tC5+rnKs8nT77nKysK75rG+PGJy' +
  'Lz4Kob7Urbzbob8xMS441Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IHJnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzUuONSqPGJyLz4KPC' +
  '9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vYUxKYnNxcyIgdGFyZ2V0PSJfYmxh' +
  'bmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL2FMSmJzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzQwKCBDWjM0NTcgVlhpVWVUUHlRbDgoLz' +
  'wvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48aW1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaW1nZXh0cmEvaTEvNzA1MTQ5' +
  'MDAzLypvMSpjKm4wMSpjcmk4emkyKmcqbipxKmpnKnJuKmIqZ2dfISE3MDUxNDkwMDMuanBnIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYW' +
  'x0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNr' +
  'PSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+ob7O5LfyyMuhv76xvOfR/M3Iuce1+LTyy/DJy8rmve677s' +
  'Ln0808YnIvPgqhvtStvNuhvzQ5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/OS451Ko8' +
  'YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9hc2lic3FzIiB0YXJnZX' +
  'Q9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vYXNpYnNxczwvYT48YnIvPgqhvszUv9rB7qG/NTgoIENaMzQ1NyBvMnA0ZVRs' +
  'WlNRQygvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pMy8yMjE5MDQ0NT' +
  'QyMTI4LypvMSpjKm4wMSp4bSpzKnphYjEqcmFmcjQqbGJmNjZfISE0NjExNjg2MDE4NDI3Mzg1NTIwLTAtaXRlbV9waWMuanBnIiB3aWR0aD0i' +
  'NDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc2' +
  '9yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+yKu55rjxzbPSu7zbo6HR' +
  'p8n6vNLTw7Ll1/my5cXFPGJyLz4Kob7Urbzbob80Mi45OdSqPGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMjU1LCAwLCAwKTsiPqG+yK' +
  '+687zbob85Ljk51Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9a' +
  'bDZRdXBzIiB0YXJnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vWmw2UXVwczwvYT48YnIvPgqhvszUv9rB7qG/NjEoIE' +
  'NaMzQ1NyBYWlIwZVRkTnlDSSgvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5j' +
  'bi9pMy8yMTA4MzQ3NzM4LypvMSpjKm4wMWh6NCphKnAqdTI3MjNsKnMxeXZwYV8hITIxMDgzNDc3MzguanBnIiB3aWR0aD0iNDMwIiBoZWlnaH' +
  'Q9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7' +
  'IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+ob7W2taqzMPG7L2iteqhv7i7ufOw/L6x17' +
  'XM+TEwzPk8YnIvPgqhvtStvNuhvzM5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/OS45' +
  '1Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS80YzVuZXBzIiB0YX' +
  'JnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vNGM1bmVwczwvYT48YnIvPgqhvszUv9rB7qG/NzgoIENaMzQ1NyBpNk16' +
  'ZVRQQTk5RCgvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pbWdleHRyYS' +
  '9pMS8yODI1OTg5ODIzLypvMSpjKm4wMSpmKmwqdSp1KmsqZjIqbSpxemEqYSp2Nip4MjJfISEyODI1OTg5ODIzLmpwZyIgd2lkdGg9IjQzMCIg' +
  'aGVpZ2h0PSI0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2' +
  'ludGVyOyIgb25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPjIw1rvD+8H3s6yxobKjxPLL4bHc' +
  '1NDM1zxici8+CqG+1K2826G/MjYwLjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/Ni451K' +
  'o8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9CdWdsZXBzIiB0YXJn' +
  'ZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vQnVnbGVwczwvYT48YnIvPgqhvszUv9rB7qG/MTYoIENaMzQ1NyBqanhNZV' +
  'RQQWwxRCgvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pMy8yMjE4NjMz' +
  'OTg1MjEyLypvMSpjKm4wMSpqKnkqcGMqbTkxbypuOSppKmVwYWwqb2FfISEyMjE4NjMzOTg1MjEyLmpwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PS' +
  'I0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIg' +
  'b25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPqG+MjDWu6G/s6yxoTAwMcTQ08O99LHBs9a+w8' +
  'fpyKSwssirzNc8YnIvPgqhvtStvNuhvzEzLjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/' +
  'NS451Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9rb2FtZXBzIi' +
  'B0YXJnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20va29hbWVwczwvYT48YnIvPgqhvszUv9rB7qG/NDgoIENaMzQ1NyBK' +
  'U2dwZVRQQTB6RigvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pMi8yMj' +
  'EzNDUwOTA2NDczLypvMSpjKm4wMWFlKmg5OG8xeGdnaXcqdHkqYXAqeV8hITIyMTM0NTA5MDY0NzMucG5nIiB3aWR0aD0iNDMwIiBoZWlnaHQ9' +
  'IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7Ii' +
  'BvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+yte1pTAwM7KjxPLL4cLjuNCx3NTQzNcyNNa7' +
  '17A8YnIvPgqhvtStvNuhvzE5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/OS451Ko8Yn' +
  'IvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9RczVtZXBzIiB0YXJnZXQ9' +
  'Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vUXM1bWVwczwvYT48YnIvPgqhvszUv9rB7qG/NTcoIENaMzQ1NyBJRVc2ZVRQej' +
  'UyaigvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pbWdleHRyYS9pMy80' +
  'MDMzNTkyNDcxLypvMSpjKm4wMSpjcCprZjN3MSp1N2xobCpzeG43KmVfISE0MDMzNTkyNDcxLmpwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0Mz' +
  'AiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25j' +
  'bGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPqG+M7rQob/QxbK9vNLNpdewvq215LOsz7jRwM/fPG' +
  'JyLz4Kob7Urbzbob8xNi451Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IHJnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzkuOdSqPGJyLz4K' +
  'PC9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vbGxjYXNxcyIgdGFyZ2V0PSJfYm' +
  'xhbmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL2xsY2FzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzE0KCBDWjM0NTcgQk9kSmVUbFo4cTco' +
  'Lzwvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48aW1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vYmFvL3VwbG9hZGVkL2kyLz' +
  'M3NDU5NzMwOS8qbzEqYypuMDEzKnR1dCpnKnEyM3IqenM5ZTd5KmMqaV8hITQ2MTE2ODYwMTg0MjczODE0MzctMC1pdGVtX3BpYy5qcGciIHdp' +
  'ZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbHQ9IiIgYm9yZGVyPSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPS' +
  'JjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9ImphdmFzY3JpcHQ6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPjwvZGl2Pgo8cD4yMDI1tLrQwrDm' +
  'o6HN9bOvz7y1pdSqu+7Ss77tob4xLTbE6ry2ob88YnIvPgqhvtStvNuhvzkuOdSqPGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMjU1LC' +
  'AwLCAwKTsiPqG+yK+687zbob80LjnUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8vcy5jbGljay50' +
  'YW9iYW8uY29tL0lsWm1lcHMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9JbFptZXBzPC9hPjxici8+CqG+zN' +
  'S/2sHuob82NyggQ1ozNDU3IHN5V0JlVFB6cklTKC88L3N0cm9uZz48L3A+Cjxoci8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5s' +
  'aW5qaWFiYW5nLmNuL2k0LzIwNzQ3MzQ5MTQvKm8xKmMqbjAxKnYwYm9vZjFtKmFmNCpyKmFvd2QqZF8hITIwNzQ3MzQ5MTQuanBnIiB3aWR0aD' +
  '0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vy' +
  'c29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+ob7K17WlK8eptb2hv7' +
  'y0yrPWpcLpuqPMpsvpMjUwZzxici8+CqG+1K2826G/Ny45MdSqPGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMjU1LCAwLCAwKTsiPqG+' +
  'yK+687zbob81Ljkx1Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS' +
  '9FNnZrZXBzIiB0YXJnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vRTZ2a2VwczwvYT48YnIvPgqhvszUv9rB7qG/MzEo' +
  'IENaMzQ1NyBtcmRUZVRsMWd5cigvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy' +
  '5jbi9pMi8yMjEyMjg5ODYxODc4LypvMSpjKm4wMSpxKmxoKnF6MDEqcGsqYXAqb2hlKnd1dV8hITIyMTIyODk4NjE4NzgtMC1zY21pdGVtMTc2' +
  'MDAwLmpwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NT' +
  'ApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+Cjxw' +
  'PqG+v6rRp7y+ob9NYXJjb8Ltv8mx+8+pwu2/y7HKMjTJqzxici8+CqG+1K2826G/MTkuOdSqPGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2' +
  'IoMjU1LCAwLCAwKTsiPqG+yK+687zbob85LjnUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8vcy5j' +
  'bGljay50YW9iYW8uY29tL2Nyc1pzcXMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9jcnNac3FzPC9hPjxici' +
  '8+CqG+zNS/2sHuob84MyggQ1ozNDU3IDkwQlVlVGxiR012KC88L3N0cm9uZz48L3A+CjxkaXY+PHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMCwg' +
  'MjU1LCAyNTUpOyI+PHNwYW4gc3R5bGU9ImJhY2tncm91bmQtY29sb3I6IHJnYigwLCAwLCAwKTsiPjxzdHJvbmc+obahtqG2obahtqG2obahtq' +
  'G2obYxMC03MNSq16jH+KG3obeht6G3obeht6G3obeht6G3obehtzwvc3Ryb25nPjwvc3Bhbj48L3NwYW4+PC9kaXY+CjxkaXY+CjxkaXY+Cjxk' +
  'aXY+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2kzLzQwNjUyOTg0MDgvKm8xKmMqbjAxZ3Q2KmhpKmsyKm' +
  'J5djkqdzd2ZmcqZ18hITQwNjUyOTg0MDgucG5nIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJy' +
  'ZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKH' +
  'RoaXMuc3JjKTsiLz48L2Rpdj4KPHA+1tDBuMO3wdbTxdGhzueyzcjiud7NtzE5OGcqMzxici8+CqG+1K2826G/MjYwLjnUqjxici8+CjxzcGFu' +
  'IHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MjQuOdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PG' +
  'EgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vSUQ1aHNxcyIgdGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8u' +
  'Y29tL0lENWhzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzgzKCBDWjM0NTcgVXFwNGVUUHZQY04oLzwvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48aW' +
  '1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaTMvMjIxNDU4OTkzMTc1NC8qbzEqYypuMDEqbCpucjAzZDEqb3AqbmIqaipx' +
  'eDl4KmNfISEyMjE0NTg5OTMxNzU0LnBuZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dX' +
  'JuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlz' +
  'LnNyYyk7Ii8+PC9kaXY+CjxwPrbgtM63tbOho6HQwr2usKK/y8vVsfnMx9DENC41ve88YnIvPgqhvtStvNuhvzQ5LjnUqjxici8+CjxzcGFuIH' +
  'N0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MjkuOdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PGEg' +
  'aHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vcnY0aHNxcyIgdGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8uY2' +
  '9tL3J2NGhzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzk1KCBDWjM0NTcgelM1c2VUUHhBTnQoLzwvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48aW1n' +
  'IHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaTQvNDc1MzI1NzA0LypvMSpjKm4wMWoqam0qdWtsMXMwKnU2KmtqKm4qbmcxXy' +
  'EhMC1pdGVtX3BpYy5qcGciIHdpZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbHQ9IiIgYm9yZGVyPSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29t' +
  'KHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9ImphdmFzY3JpcHQ6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPj' +
  'wvZGl2Pgo8cD7FxM7lo6HWqs62udu44rXjurzW3czYsvrB48qz0KGz1Dxici8+CqG+1K2826G/NjXUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xv' +
  'cjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MznUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi' +
  '8vcy5jbGljay50YW9iYW8uY29tL2hrZmZzcXMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9oa2Zmc3FzPC9h' +
  'Pjxici8+CqG+zNS/2sHuob84MiggQ1ozNDU3IENQMUdlVFBDdElWKC88L3N0cm9uZz48L3A+Cjxoci8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly' +
  '9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2ltZ2V4dHJhL2kzLzEwMTUzODM5NTkvKm8xKmMqbjAxKmEqbjIqc3gqcjFmNypneipjZypieCp3Zl8h' +
  'ITEwMTUzODM5NTkucG5nIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbS' +
  'h0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48' +
  'L2Rpdj4KPHA+v7W297G0tvnNr7jGzPrQv7/at/7SujMw1qc8YnIvPgqhvtStvNuhvzI2MC401Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IH' +
  'JnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzM4LjTUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8v' +
  'cy5jbGljay50YW9iYW8uY29tLzFJaHFlcHMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS8xSWhxZXBzPC9hPj' +
  'xici8+CqG+zNS/2sHuob83NyggQ1ozNDU3IGJuQWxlVFBCb3BYKC88L3N0cm9uZz48L3A+Cjxoci8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9p' +
  'bWdwcm94eS5saW5qaWFiYW5nLmNuL2kzLzE4NTQ5MjE5ODAvKm8xKmMqbjAxZHQ4ZSpsNTEqcSp1c3QqdG0qaCpmNmtfISExODU0OTIxOTgwLm' +
  'pwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIg' +
  'c3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPqG+xc' +
  'vP6bzHz8q7qLH9ob/M2MmrwePKs8DxutA0zrYyMMO2PGJyLz4Kob7Urbzbob81Ny441Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IHJnYigy' +
  'NTUsIDAsIDApOyI+ob7Ir7rzvNuhvzI5LjjUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8vcy5jbG' +
  'ljay50YW9iYW8uY29tL2RIQ3FlcHMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9kSENxZXBzPC9hPjxici8+' +
  'CqG+zNS/2sHuob81NCggQ1ozNDU3IDdGeDdlVFBDTTZ4KC88L3N0cm9uZz48L3A+Cjxoci8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm' +
  '94eS5saW5qaWFiYW5nLmNuL2ltZ2V4dHJhL2kyLzIyMDA1ODM2OTY4NzkvKm8xKmMqbjAxeHMqbypzaCprMjBnZCp4KmQqamxobnFfISEyMjAw' +
  'NTgzNjk2ODc5LnBuZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odG' +
  'hpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9k' +
  'aXY+CjxwPrGsv+63tbOho6HVtcjns/XU57LN06rR+NHgztHW4Dxici8+CqG+1K2826G/MTk5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcj' +
  'ogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MzkuOdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6' +
  'Ly9zLmNsaWNrLnRhb2Jhby5jb20vMzhhZXNxcyIgdGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tLzM4YWVzcXM8L2' +
  'E+PGJyLz4Kob7M1L/awe6hvzU1KCBDWjM0NTcgcm5vYWVUUHh5VXIoLzwvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48aW1nIHNyYz0iaHR0cDov' +
  'L2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaW1nZXh0cmEvaTMvMjIxNjA5MTUwODM5NC8qbzEqYypuMDEqcHhsOCpjZDIqYnMqdip6djB5KncqeS' +
  'pwXyEhMjIxNjA5MTUwODM5NC5qcGciIHdpZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbHQ9IiIgYm9yZGVyPSIwIiBvbmxvYWQ9InJldHVybiBp' +
  'bWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9ImphdmFzY3JpcHQ6d2luZG93Lm9wZW4odGhpcy5zcm' +
  'MpOyIvPjwvZGl2Pgo8cD6yqcrAv7Wjob6r0aG4ysvgu8bczsfQxqwyNTBnPGJyLz4Kob7Urbzbob8zOS451Ko8YnIvPgo8c3BhbiBzdHlsZT0i' +
  'Y29sb3I6IHJnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzI1LjnUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Im' +
  'h0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL3JyWG9lcHMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9yclhv' +
  'ZXBzPC9hPjxici8+CqG+zNS/2sHuob85NyggQ1ozNDU3IDFZYU5lVFBCaGw2KC88L3N0cm9uZz48L3A+Cjxoci8+CjxkaXY+PGltZyBzcmM9Im' +
  'h0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2ltZ2V4dHJhL2k0LzIyMTIzNDUwMTM5NDgvKm8xKmMqbjAxKnAqbypsKnMqb3YxZjIqZWdz' +
  'c3UqcCppZ18hITIyMTIzNDUwMTM5NDguanBnIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZX' +
  'R1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRo' +
  'aXMuc3JjKTsiLz48L2Rpdj4KPHA+ob7Uqs/8wPG60KG/08XA1sPAxMyy6MDxutC5sjE1sa08YnIvPgqhvtStvNuhvzc5LjnUqjxici8+CjxzcG' +
  'FuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MzkuOdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/' +
  'PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vQkpBZHNxcyIgdGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW' +
  '8uY29tL0JKQWRzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzE5KCBDWjM0NTcgSEJ2c2VUUHkxbEEoLzwvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48' +
  'aW1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaW1nZXh0cmEvaTQvMjY3MTg1MDEyNC8qbzEqYypuMDE0cmwqcip0djEqY2' +
  '1wemp2KnAqc2gqY18hITI2NzE4NTAxMjQuanBnIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJy' +
  'ZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKH' +
  'RoaXMuc3JjKTsiLz48L2Rpdj4KPHA+ob64x9bQuMehv7CxzMfI7bnHy9i4xsasNDLGrDxici8+CqG+1K2826G/MzIuOdSqPGJyLz4KPHNwYW4g' +
  'c3R5bGU9ImNvbG9yOiByZ2IoMjU1LCAwLCAwKTsiPqG+yK+687zbob8xOS451Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YS' +
  'BocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9kNE1wZXBzIiB0YXJnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5j' +
  'b20vZDRNcGVwczwvYT48YnIvPgqhvszUv9rB7qG/MTAoIENaMzQ1NyAyc3ZoZVRQQm96MigvPC9zdHJvbmc+PC9wPgo8aHIvPgo8ZGl2PjxpbW' +
  'cgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pbWdleHRyYS9pMS8yMjE2OTM2MjQ5Mzg0LypvMSpjKm4wMSp5bSp6ZXNoMipq' +
  'KmJ2aSpnNSpzKmgqYmFfISEyMjE2OTM2MjQ5Mzg0LmpwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0MzAiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG' +
  '9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25jbGljaz0iamF2YXNjcmlwdDp3aW5kb3cu' +
  'b3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPqG+zMCzvLG2vaGhv72hwaa24LjGzqzJ+svYRMasNjDGrCoyxr88YnIvPgqhvtStvNuhvzI2MC' +
  '451Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IHJnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzM5LjnUqjxici8+Cjwvc3Bhbj48c3Ryb25n' +
  'PqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL1RsamRzcXMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3' +
  'MuY2xpY2sudGFvYmFvLmNvbS9UbGpkc3FzPC9hPjxici8+CqG+zNS/2sHuob8yMyggQ1ozNDU3IENrdGZlVFBCZVFNKC88L3N0cm9uZz48L3A+' +
  'Cjxoci8+Cjxici8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2k0LzIyMTM0NTA5MDY0NzMvKm8xKmMqbj' +
  'Axdm8qdyplYip1MXhnZ2V0Nip3bnR4XyEhMjIxMzQ1MDkwNjQ3My5qcGciIHdpZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbHQ9IiIgYm9yZGVy' +
  'PSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9ImphdmFzY3JpcH' +
  'Q6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPjwvZGl2Pgo8cD6hvr/CzKnSvcHGob+80tPDsdvKvbXn19PRqtG50sc8YnIvPgqhvtStvNuhvzE2' +
  'OdSqPGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMjU1LCAwLCAwKTsiPqG+yK+687zbob82OdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob' +
  '7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vSkE0ZnNxcyIgdGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5j' +
  'bGljay50YW9iYW8uY29tL0pBNGZzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzM4KCBDWjM0NTcgYXF4WmVUUERqUVQoLzwvc3Ryb25nPjwvcD4KPG' +
  'hyLz4KPC9kaXY+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2kzLzIyMTg3OTY2ODAzNzgvKm8xKmMqbjAx' +
  'MSplNXh3bDEqZWYqYWkqcjcqaCpyKmVtXyEhMjIxODc5NjY4MDM3OC5qcGciIHdpZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbHQ9IiIgYm9yZG' +
  'VyPSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9ImphdmFzY3Jp' +
  'cHQ6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPjwvZGl2Pgo8cD6hvrT3ya3NrL/uob+7qse/sbHO3tK2tLW357v6PGJyLz4Kob7Urbzbob8yMD' +
  'nUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/NTnUqjxici8+Cjwvc3Bhbj48c3Ryb25nPqG+' +
  'wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL3h1TnNlcHMiIHRhcmdldD0iX2JsYW5rIj5odHRwczovL3MuY2' +
  'xpY2sudGFvYmFvLmNvbS94dU5zZXBzPC9hPjxici8+CqG+zNS/2sHuob8zNiggQ1ozNDU3IGQwdU9lVFB4aUVmKC88L3N0cm9uZz48L3A+Cjxo' +
  'ci8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2kzLzIyMTMyMTc2MDE3NjYvKm8xKmMqbjAxYnFrMDQqej' +
  'Eqb3VzKmsqYXJ5KmlhaF8hITIyMTMyMTc2MDE3NjYuanBnIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25s' +
  'b2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy' +
  '5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+MTE1MG1sK7LNvt+joejzyqkzMDSyu9DiuNaxo87Ct7m60Dxici8+CqG+1K2826G/NDguONSq' +
  'PGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMjU1LCAwLCAwKTsiPqG+yK+687zbob8yOS441Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvs' +
  'HsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS9icndyZXBzIiB0YXJnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNs' +
  'aWNrLnRhb2Jhby5jb20vYnJ3cmVwczwvYT48YnIvPgqhvszUv9rB7qG/MjgoIENaMzQ1NyBHT1JDZVRQRVRaNigvPC9zdHJvbmc+PC9wPgo8aH' +
  'IvPgo8YnIvPgo8ZGl2PjxpbWcgc3JjPSJodHRwOi8vaW1ncHJveHkubGluamlhYmFuZy5jbi9pMi8yOTg3NjA0Njk5LypvMSpjKm4wMTcqc3Zz' +
  'KmpvMWthKmJ6aCpwKmsqdCp1a18hITI5ODc2MDQ2OTkuanBnIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb2' +
  '5sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRv' +
  'dy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+ob66w7XPob/K187autrBwbeixKS7pLeiy9g1MDBnKjI8YnIvPgqhvtStvNuhvzI5LjnUqj' +
  'xici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MTkuOdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob7B' +
  '7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vRkxJc2VwcyIgdGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5jbG' +
  'ljay50YW9iYW8uY29tL0ZMSXNlcHM8L2E+PGJyLz4Kob7M1L/awe6hvzYwKCBDWjM0NTcga3Q0ZGVUUHhjeWUoLzwvc3Ryb25nPjwvcD4KPGhy' +
  'Lz4KPGRpdj48aW1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vYmFvL3VwbG9hZGVkLypvMSpjKm4wMWYqaCptKnY5ajEqay' +
  'p0YyptKm4qZnUyKmwqaF8hITYwMDAwMDAwMDExNjUtMC15aW5oZS5qcGciIHdpZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbHQ9IiIgYm9yZGVy' +
  'PSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9ImphdmFzY3JpcH' +
  'Q6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPjwvZGl2Pgo8cD6hvsWmzvfWrsPVob+9utSttbCw17K5y67F587tMzAwbWw8YnIvPgqhvtStvNuh' +
  'vzI2MC451Ko8YnIvPgo8c3BhbiBzdHlsZT0iY29sb3I6IHJnYigyNTUsIDAsIDApOyI+ob7Ir7rzvNuhvzE5LjnUqjxici8+Cjwvc3Bhbj48c3' +
  'Ryb25nPqG+wezIr7XY1rehvzxhIGhyZWY9Imh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL1BXQWZzcXMiIHRhcmdldD0iX2JsYW5rIj5odHRw' +
  'czovL3MuY2xpY2sudGFvYmFvLmNvbS9QV0Fmc3FzPC9hPjxici8+CqG+zNS/2sHuob83MCggQ1ozNDU3IHhFTVhlVFB6YU9DKC88L3N0cm9uZz' +
  '48L3A+Cjxoci8+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2ltZ2V4dHJhL2k0LzIyMDA3Mjc0MTE2NTYv' +
  'Km8xKmMqbjAxKmQqbSpwKmMzKnUxKm82KnVnKmlpKnJtYSpiXyEhMC1pdGVtX3BpYy5qcGciIHdpZHRoPSI0MzAiIGhlaWdodD0iNDMwIiBhbH' +
  'Q9IiIgYm9yZGVyPSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsiIG9uY2xpY2s9' +
  'ImphdmFzY3JpcHQ6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPjwvZGl2Pgo8cD6yzrDr6K3osr3Ny9jQocvVtPLRwLjgyv6/2suu0cDLotHAz9' +
  '+/2se7PGJyLz4Kob7Urbzbob8yNTkuOdSqPGJyLz4KPHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMjU1LCAwLCAwKTsiPqG+yK+687zbob8yOS45' +
  '1Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS95QkhvZXBzIiB0YX' +
  'JnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20veUJIb2VwczwvYT48YnIvPgqhvszUv9rB7qG/MjMoIENaMzQ1NyBLWE5o' +
  'ZVRQekdscigvPC9zdHJvbmc+PC9wPgo8aHIvPgo8L2Rpdj4KPGRpdj48aW1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaT' +
  'IvMjIxNTg4MzI0NjQ2NC8qbzEqYypuMDEqaXNyMmJqMXhjKnoxKmkqbCpnKmRxMV8hITIyMTU4ODMyNDY0NjQuanBnIiB3aWR0aD0iNDMwIiBo' +
  'ZWlnaHQ9IjQzMCIgYWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW' +
  '50ZXI7IiBvbmNsaWNrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+U0lLRlVRRU1TL7nZt73V/ca3xNDF' +
  'rsDPtfnQrDxici8+CqG+1K2826G/MzQ5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/Nj' +
  'kuOdSqPGJyLz4KPC9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vOXd4dGVwcyIg' +
  'dGFyZ2V0PSJfYmxhbmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tLzl3eHRlcHM8L2E+PGJyLz4Kob7M1L/awe6hvzc2KCBDWjM0NTcgel' +
  'hlTWVUUHhSMUkoLzwvc3Ryb25nPjwvcD4KPGhyLz4KPGRpdj48aW1nIHNyYz0iaHR0cDovL2ltZ3Byb3h5LmxpbmppYWJhbmcuY24vaTMvMzg4' +
  'Nzg0MTU0MS8qbzEqYypuMDFrKm41NypzZDEqbipmcCpnKmIqczV6bTdfISEzODg3ODQxNTQxLmpwZyIgd2lkdGg9IjQzMCIgaGVpZ2h0PSI0Mz' +
  'AiIGFsdD0iIiBib3JkZXI9IjAiIG9ubG9hZD0icmV0dXJuIGltZ3pvb20odGhpcyw1NTApOyIgc3R5bGU9ImN1cnNvcjpwb2ludGVyOyIgb25j' +
  'bGljaz0iamF2YXNjcmlwdDp3aW5kb3cub3Blbih0aGlzLnNyYyk7Ii8+PC9kaXY+CjxwPtLD5rO0ury+0MK/7rfJ1q/Q3c/Q0Kw8YnIvPgqhvt' +
  'StvNuhvzc5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/MzkuOdSqPGJyLz4KPC9zcGFu' +
  'PjxzdHJvbmc+ob7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vZU9XaHNxcyIgdGFyZ2V0PSJfYmxhbmsiPm' +
  'h0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL2VPV2hzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzczKCBDWjM0NTcgWDE5dWVUUHZ5aHYoLzwvc3Ry' +
  'b25nPjwvcD4KPGhyLz4KPC9kaXY+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2kzLzIyMTg2NTQyNDk0OD' +
  'AvKm8xKmMqbjAxYippeip4KnNqMipqdHRoKmtrKmsqZ2wqaV8hITIyMTg2NTQyNDk0ODAuanBnIiB3aWR0aD0iNDMwIiBoZWlnaHQ9IjQzMCIg' +
  'YWx0PSIiIGJvcmRlcj0iMCIgb25sb2FkPSJyZXR1cm4gaW1nem9vbSh0aGlzLDU1MCk7IiBzdHlsZT0iY3Vyc29yOnBvaW50ZXI7IiBvbmNsaW' +
  'NrPSJqYXZhc2NyaXB0OndpbmRvdy5vcGVuKHRoaXMuc3JjKTsiLz48L2Rpdj4KPHA+wvO/y8u5zNLQxLnZxuyjodDCv+6/7cvJzsDSwjxici8+' +
  'CqG+1K2826G/MzU5LjnUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/NTguOdSqPGJyLz4KPC' +
  '9zcGFuPjxzdHJvbmc+ob7B7MivtdjWt6G/PGEgaHJlZj0iaHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vVmxSaHNxcyIgdGFyZ2V0PSJfYmxh' +
  'bmsiPmh0dHBzOi8vcy5jbGljay50YW9iYW8uY29tL1ZsUmhzcXM8L2E+PGJyLz4Kob7M1L/awe6hvzMzKCBDWjM0NTcgY1pLUmVUUHVvNVooLz' +
  'wvc3Ryb25nPjwvcD4KPHA+PHNwYW4gc3R5bGU9ImNvbG9yOiByZ2IoMCwgMjU1LCAyNTUpOyI+PHNwYW4gc3R5bGU9ImJhY2tncm91bmQtY29s' +
  'b3I6IHJnYigwLCAwLCAwKTsiPjxzdHJvbmc+obahtqG2obahtqG2obahtqG2oba0887vvP7XqMf4obeht6G3obeht6G3obeht6G3obeht6G3PC' +
  '9zdHJvbmc+PC9zcGFuPjwvc3Bhbj48L3A+CjxkaXY+PGltZyBzcmM9Imh0dHA6Ly9pbWdwcm94eS5saW5qaWFiYW5nLmNuL2ltZ2V4dHJhL2kx' +
  'LzIyNzg1MzM1OTEvKm8xKmMqbjAxKmUqanYqamIyMWMqb2oqZzhtKmwqZ2MyXyEhMjI3ODUzMzU5MS5wbmciIHdpZHRoPSI0MzAiIGhlaWdodD' +
  '0iNDMwIiBhbHQ9IiIgYm9yZGVyPSIwIiBvbmxvYWQ9InJldHVybiBpbWd6b29tKHRoaXMsNTUwKTsiIHN0eWxlPSJjdXJzb3I6cG9pbnRlcjsi' +
  'IG9uY2xpY2s9ImphdmFzY3JpcHQ6d2luZG93Lm9wZW4odGhpcy5zcmMpOyIvPjwvZGl2Pgo8cD6hvsm90NChv7Kuz6O6zbunzeKz5bfm0sLE0M' +
  'WuyP26z9K7PGJyLz4Kob7Urbzbob81NzPUqjxici8+CjxzcGFuIHN0eWxlPSJjb2xvcjogcmdiKDI1NSwgMCwgMCk7Ij6hvsivuvO826G/NDI5' +
  '1Ko8YnIvPgo8L3NwYW4+PHN0cm9uZz6hvsHsyK+12Na3ob88YSBocmVmPSJodHRwczovL3MuY2xpY2sudGFvYmFvLmNvbS93WkFqc3FzIiB0YX' +
  'JnZXQ9Il9ibGFuayI+aHR0cHM6Ly9zLmNsaWNrLnRhb2Jhby5jb20vd1pBanNxczwvYT48YnIvPgqhvszUv9rB7qG/ODkoIENaMzQ1NyA3V1Z0' +
  'ZVRQRkVWRigvPC9zdHJvbmc+PC9wPgo8aHIvPgoKPHA+1+69/DfM7LXEzca89qO6PGJyLz4KMtTCOMjVzca89qO6PGEgaHJlZj0iaHR0cDovL3' +
  'd3dy5xcXlld3UuY29tL2FydGljbGUvZHMvMjAyNS8yMDI1MDIwODIwMTkxMi5odG1sIj5odHRwOi8vd3d3LnFxeWV3dS5jb20vYXJ0aWNsZS9k' +
  'cy8yMDI1LzIwMjUwMjA4MjAxOTEyLmh0bWw8L2E+PGJyLz4KMtTCN8jVzca89qO6PGEgaHJlZj0iaHR0cDovL3d3dy5xcXlld3UuY29tL2FydG' +
  'ljbGUvZHMvMjAyNS8yMDI1MDIwNzIwMTkwNi5odG1sIj5odHRwOi8vd3d3LnFxeWV3dS5jb20vYXJ0aWNsZS9kcy8yMDI1LzIwMjUwMjA3MjAx' +
  'OTA2Lmh0bWw8L2E+PGJyLz4KMtTCNsjVzca89qO6PGEgaHJlZj0iaHR0cDovL3d3dy5xcXlld3UuY29tL2FydGljbGUvZHMvMjAyNS8yMDI1MD' +
  'IwNjIwMTg5OS5odG1sIj5odHRwOi8vd3d3LnFxeWV3dS5jb20vYXJ0aWNsZS9kcy8yMDI1LzIwMjUwMjA2MjAxODk5Lmh0bWw8L2E+PGJyLz4K' +
  'MtTCNcjVzca89qO6PGEgaHJlZj0iaHR0cDovL3d3dy5xcXlld3UuY29tL2FydGljbGUvZHMvMjAyNS8yMDI1MDIwNTIwMTg5NC5odG1sIj5odH' +
  'RwOi8vd3d3LnFxeWV3dS5jb20vYXJ0aWNsZS9kcy8yMDI1LzIwMjUwMjA1MjAxODk0Lmh0bWw8L2E+PGJyLz4KMtTCNMjVzca89qO6PGEgaHJl' +
  'Zj0iaHR0cDovL3d3dy5xcXlld3UuY29tL2FydGljbGUvZHMvMjAyNS8yMDI1MDIwNDIwMTg5MC5odG1sIj5odHRwOi8vd3d3LnFxeWV3dS5jb2' +
  '0vYXJ0aWNsZS9kcy8yMDI1LzIwMjUwMjA0MjAxODkwLmh0bWw8L2E+PGJyLz4KMtTCMsjVzca89qO6PGEgaHJlZj0iaHR0cDovL3d3dy5xcXll' +
  'd3UuY29tL2FydGljbGUvZHMvMjAyNS8yMDI1MDIwMjIwMTg4Mi5odG1sIj5odHRwOi8vd3d3LnFxeWV3dS5jb20vYXJ0aWNsZS9kcy8yMDI1Lz' +
  'IwMjUwMjAyMjAxODgyLmh0bWw8L2E+PGJyLz4KMdTCMjjI1c3GvPajujxhIGhyZWY9Imh0dHA6Ly93d3cucXF5ZXd1LmNvbS9hcnRpY2xlL2Rz' +
  'LzIwMjUvMjAyNTAxMjgyMDE4NjUuaHRtbCI+aHR0cDovL3d3dy5xcXlld3UuY29tL2FydGljbGUvZHMvMjAyNS8yMDI1MDEyODIwMTg2NS5odG' +
  '1sPC9hPjwvcD4KPGRpdiBjbGFzcz0icm93IGNvbnRlbnQtZm9vdGVyIj4KPGRpdiBjbGFzcz0iY29sLXhzLTEyIHIiIHN0eWxlPSJtYXJnaW4t' +
  'Ym90dG9tOjEwcHgiPrj80MLKsbzko7oyMDI1LTAyLTA5IDEwOjI4OjQyfCA8c3BhbiBpZD0iTmV3QXNwX0hpdHMiPjxzY3JpcHQgbGFuZ3VhZ2' +
  'U9IkphdmFTY3JpcHQiIHNyYz0iL2FydGljbGUvaGl0cy5hc3A/aWQ9MjAxOTE2JnR5cGU9MCI+PC9zY3JpcHQ+PC9zcGFuPjwvZGl2Pgo8ZGl2' +
  'IGNsYXNzPSJjbGVhcmZpeCI+PC9kaXY+CjxkaXYgY2xhc3M9InlocyI+PHNjcmlwdCBzcmM9Ii9qcy93enloMS5qcyIgbGFuZ3VhZ2U9Imphdm' +
  'FzY3JpcHQiPjwvc2NyaXB0PjwvZGl2Pgo8ZGl2IGNsYXNzPSJwcmUtbmV4dC1idG4iPgrJz9K7xqrOxNXCo7o8YSBocmVmPSIvYXJ0aWNsZS8z' +
  'LzIwMjUvMjAyNTAyMDkyMDE5MTUuaHRtbCI+zNSxptSqz/yywrXGw9XDv8zsMTIvMTYvMjC147PpuPfW1sq1zu+hvri9tPCwuKG/PC9hPjxicj' +
  '4Kz8LSu8aqzsTVwqO60tG+rcO709DByzwvZGl2Pgo8ZGl2IGNsYXNzPSJjbGVhcmZpeCI+PC9kaXY+CjxkaXYgY2xhc3M9ImNvbnRhaW5lciI+' +
  'CjxoND7P4LnYxNrI3TwvaDQ+Cjx1bCBjbGFzcz0iYXJ0aWNsZS1pdGVtIGFydGljbGUtaXRlbS1yb3ciPgo8bGkgY2xhc3M9Imxpc3QxIj48YS' +
  'BocmVmPSIvYXJ0aWNsZS9kcy8yMDI1LzIwMjUwMjA5MjAxOTE2Lmh0bWwiIHRpdGxlPSIxMNSqMsa/u8a1xsH9wLG9t720K7Hbyr3RqtG50scr' +
  'xNDFrsDPtfnQrCuz5bfm0sIrsrnLrsXnzu0ru6S3osvYIj48Zm9udCBjb2xvcj0iIzk5ODU2NiI+MTDUqjLGv7vGtcbB/cCxvbe9tCux28q90a' +
  'rRudLHK8TQxa7Az7X50Kwrs+W35tLCK7K5y67F587tK7ukMTwvZm9udD48L2E+PC9saT4KPGxpIGNsYXNzPSJsaXN0MiI+PGEgaHJlZj0iL2Fy' +
  'dGljbGUvZHMvMjAyMi8yMDIyMTEyMDE5MTE5OC5odG1sIiB0aXRsZT0iMTDUqjIwy6vN4NfTK7Hj0suz1r7DsdzU0MzXK8+0tdi7+rTztu7Iry' +
  'vB2cbatPPFxsfJv8vBpivSubniwLrH8rGzsPwiPjxmb250IGNvbG9yPSIjOTk4NTY2Ij4xMNSqMjDLq83g19MrsePSy7PWvsOx3NTQzNcrz7S1' +
  '2Lv6tPO27sivK8HZxtq088XGx8m/y8GmK9K5ueIxPC9mb250PjwvYT48L2xpPgo8L3VsPgo8ZGl2IGNsYXNzPSJjbGVhcmZpeCI+PC9kaXY+Cj' +
  'xkaXYgY2xhc3M9InlocyI+PHNjcmlwdCBzcmM9Ii9qcy93enloMi5qcyIgbGFuZ3VhZ2U9ImphdmFzY3JpcHQiPjwvc2NyaXB0PjwvZGl2Pgo8' +
  'aDQ+1+7QwsbAwts8L2g0Pgo8dWwgY2xhc3M9ImFydGljbGUtaXRlbSBhcnRpY2xlLWl0ZW0tcm93Ij4KPGRpdiBjbGFzcz0iY2xlYXJmaXgiPj' +
  'wvZGl2PgrU3c2jxsDC27mmxNwKPC9kaXY+CjwvZGl2Pgo8L2Rpdj4KPC9kaXY+Cjxmb290ZXI+CjxkaXYgYWxpZ249ImNlbnRlciI+CkNvcHly' +
  'aWdodCAyMDA4LTIwMjUgUVFZZVd1LkNvbSBBbGwgUmlnaHRzIFJlc2VydmVkLgo8YnI+PGEgdGFyZ2V0PSJfYmxhbmsiIGhyZWY9Imh0dHBzOi' +
  '8vd3d3Lnljd3hiLmNuLyI+1Muzx8rQu6XBqs34vtmxqNbQ0MQ8L2E+CjxwPgpRUdK1zvHA1tSwob48YSBocmVmPSJodHRwOi8vbS5xcXlld3Uu' +
  'Y29tLyIgPsrWu/qw5jwvYT58PGEgaHJlZj0iaHR0cDovL3d3dy5xcXlld3UuY29tLyIgPrXnxNSw5jwvYT6hvwo8L3A+CjxhIGNsYXNzPSJidG' +
  '5fdG9wIiBocmVmPSIjdG9wIj48aW1nIHNyYz0iL2ltYWdlcy90b3AuZ2lmIiAvPjwvYT4KPC9kaXY+CjxzY3JpcHQgbGFuZ3VhZ2U9ImphdmFz' +
  'Y3JpcHQiIHNyYz0iL2pzL3Rvbmd5b25nMy5KcyI+PC9zY3JpcHQ+CjwvZm9vdGVyPgo8L2JvZHk+CQo8L2h0bWw+Cg==';
