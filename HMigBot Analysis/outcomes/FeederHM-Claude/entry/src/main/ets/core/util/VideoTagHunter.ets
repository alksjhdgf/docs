/**
 * VideoTagHunter.ets —— 源 ui/text/VideoTagHunter.kt：识别 YouTube 嵌入视频。
 * 示例：
 *   www.youtube.com/embed/cjxnVO9RpaQ
 *   www.youtube.com/embed/cjxnVO9RpaQ?feature=oembed
 *   www.youtube.com/embed/cjxnVO9RpaQ/theoretical_crap
 *   www.youtube.com/embed/cjxnVO9RpaQ/crap?feature=oembed
 * 注意：照源保留正则中未转义的 '.'（匹配任意字符）且不锚定；youtube-nocookie.com 不识别。
 */

export const YOUTUBE_ID_PATTERN: string = 'youtube.com/embed/([^?/]*)';

export class Video {
  src: string = '';
  imageUrl: string = '';
  /** YouTube 需要与 embed 不同的观看链接 */
  link: string = '';

  get width(): number {
    return 480;
  }

  get height(): number {
    return 360;
  }
}

export function getVideo(src: string | null): Video | null {
  if (src === null) {
    return null;
  }
  const re = new RegExp(YOUTUBE_ID_PATTERN);
  const match = re.exec(src);
  if (match === null) {
    return null;
  }
  const videoId: string = match[1];
  const v = new Video();
  v.src = src;
  v.imageUrl = 'http://img.youtube.com/vi/' + videoId + '/hqdefault.jpg';
  v.link = 'https://www.youtube.com/watch?v=' + videoId;
  return v;
}
