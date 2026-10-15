/**
 * GuidePageData / GuidePageProvider (source: feature/launch/model/GuidePageData.kt).
 * Copy comes from string resources (guide_page_N_title / guide_page_N_desc), images from the converted media.
 */
export class GuidePageData {
  /** Page title */
  title: ResourceStr = '';
  /** Page description (multi-line) */
  description: ResourceStr = '';
  /** Illustration resource */
  image: Resource = $r('app.media.ic_book_writer');

  constructor(title: ResourceStr, description: ResourceStr, image: Resource) {
    this.title = title;
    this.description = description;
    this.image = image;
  }
}

export class GuidePageProvider {
  /** GuidePageProvider.getGuidePages: the 4 guide pages in source order */
  static getGuidePages(): GuidePageData[] {
    return [
      new GuidePageData($r('app.string.guide_page_1_title'), $r('app.string.guide_page_1_desc'),
        $r('app.media.ic_book_writer')),
      new GuidePageData($r('app.string.guide_page_2_title'), $r('app.string.guide_page_2_desc'),
        $r('app.media.ic_home_screen')),
      new GuidePageData($r('app.string.guide_page_3_title'), $r('app.string.guide_page_3_desc'),
        $r('app.media.ic_add_to_cart')),
      new GuidePageData($r('app.string.guide_page_4_title'), $r('app.string.guide_page_4_desc'),
        $r('app.media.ic_dev_productivity'))
    ];
  }
}
