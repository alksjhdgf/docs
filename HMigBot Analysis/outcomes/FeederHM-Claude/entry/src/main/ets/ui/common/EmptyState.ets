/*
 * EmptyState — 源 ui/compose/empty/NothingToRead.kt。
 * 三段居中文案（headlineMedium + Light）：empty_feed_top；可点块 empty_feed_open → onOpenOtherFeed（打开抽屉）；
 * 可点块 empty_feed_add → onAddFeed（SearchFeed）。源用 <annotation style="link"> 标出链接词，鸿蒙资源无注解：
 * 用 hm_empty_feed_open_link / hm_empty_feed_add_link 在整句中定位链接词，以 LinkTextStyle（primary + 下划线）突出；
 * 定位不到（翻译中链接词不同）则整句按普通样式显示。
 */
import { FeederTheme } from './Theme';
import { textStyle, M3Type, WEIGHT_LIGHT, TextStyleSpec } from './Typography';

const TEXT_FIELD_MIN_HEIGHT: number = 56;

/** 把 full 按 link 首次出现位置切成 [前, 链接, 后]；找不到 → [full, '', ''] */
export function splitLinkText(full: string, link: string): string[] {
  if (link === '') {
    return [full, '', ''];
  }
  const i = full.indexOf(link);
  if (i < 0) {
    return [full, '', ''];
  }
  return [full.substring(0, i), link, full.substring(i + link.length)];
}

@ComponentV2
export struct NothingToRead {
  @Event onOpenOtherFeed: () => void = () => {
    console.info('TODO:openOtherFeed:NothingToRead');
  };
  @Event onAddFeed: () => void = () => {
    console.info('TODO:addFeed:NothingToRead');
  };
  @Local openParts: string[] = ['', '', ''];
  @Local addParts: string[] = ['', '', ''];

  aboutToAppear(): void {
    this.openParts = this.resolveParts('empty_feed_open', 'hm_empty_feed_open_link');
    this.addParts = this.resolveParts('empty_feed_add', 'hm_empty_feed_add_link');
  }

  private resolveParts(fullKey: string, linkKey: string): string[] {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return ['', '', ''];
      }
      const rm = ctx.resourceManager;
      return splitLinkText(rm.getStringByNameSync(fullKey), rm.getStringByNameSync(linkKey));
    } catch (e) {
      console.error(`NothingToRead: resolve strings failed: ${JSON.stringify(e)}`);
      return ['', '', ''];
    }
  }

  private headline(): TextStyleSpec {
    return M3Type.headlineMedium.withWeight(WEIGHT_LIGHT);
  }

  @Builder
  linkLine(parts: string[], fallback: Resource) {
    if (parts[0] === '' && parts[1] === '' && parts[2] === '') {
      Text(fallback)
        .attributeModifier(textStyle(this.headline(), false, FeederTheme.colors.onBackground))
        .textAlign(TextAlign.Center)
    } else {
      Text() {
        Span(parts[0])
        Span(parts[1])
          .fontColor(FeederTheme.colors.primary)
          .decoration({ type: TextDecorationType.Underline, color: FeederTheme.colors.primary })
        Span(parts[2])
      }
      .attributeModifier(textStyle(this.headline(), false, FeederTheme.colors.onBackground))
      .textAlign(TextAlign.Center)
    }
  }

  build() {
    // 源 Box(contentAlignment = Center) + Column(Center, CenterHorizontally)：居中为源本意
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text($r('app.string.empty_feed_top'))
          .attributeModifier(textStyle(this.headline(), false, FeederTheme.colors.onBackground))
          .textAlign(TextAlign.Center)
        Column().height(16)
        Stack({ alignContent: Alignment.Center }) {
          this.linkLine(this.openParts, $r('app.string.empty_feed_open'))
        }
        .width('100%')
        .constraintSize({ minHeight: TEXT_FIELD_MIN_HEIGHT })
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .onClick(() => {
          this.onOpenOtherFeed();
        })
        Column().height(16)
        Stack({ alignContent: Alignment.Center }) {
          this.linkLine(this.addParts, $r('app.string.empty_feed_add'))
        }
        .width('100%')
        .constraintSize({ minHeight: TEXT_FIELD_MIN_HEIGHT })
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .onClick(() => {
          this.onAddFeed();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: FeederTheme.dimens.margin, right: FeederTheme.dimens.margin })
  }
}
