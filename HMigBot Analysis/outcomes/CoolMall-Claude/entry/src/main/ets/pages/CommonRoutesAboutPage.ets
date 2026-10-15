/**
 * CommonRoutesAboutPage — About us (source: feature/common/view/AboutScreen.kt AboutRoute / AboutScreen,
 * viewmodel/AboutViewModel.kt, component/DependencyModal.kt).
 *
 * FullScreenBox (bg_page, edge to edge) — Stack(TopStart):
 *  1. AuroraBackground (full screen, alpha = contentAlpha * entranceAlpha)                         COM-A14
 *  2. Header: Spacer 130 · logo card 120 (ShapeExtraLarge, surfaceVariant@0.4, logo 100) · 24 · app name
 *     (displayLarge bold) · 8 · `Version <versionName>` (bodyMedium tertiary); alpha = contentAlpha *
 *     entranceAlpha, scale = 1 - 0.1 * scrollFraction, entrance translateY 30 → 0                      COM-A13/A14
 *  3. Scroll(padding h 16): Spacer 360 · info card (应用名称 / 版本号 / 版本代码 from PackageUtils) ·
 *     开发者 (avatar Joker.X joker.x.dev@gmail.com → Web github.com/Joker-x-dev; 贡献者 → Contributors) ·
 *     项目地址 · 相关资源 · 讨论 (QQ / 微信 rows: empty handlers) · 支持与帮助 · 其他 (引用 → sheet,
 *     用户协议, 隐私政策, 开源许可) · copyright                                                     COM-A15..A18
 *  4. Animated toolbar: back button + `关于我们` title, title alpha & background (bg_page) alpha =
 *     scrollFraction (scrollFraction = clamp(scrollY / 220vp, 0, 1))                                COM-A14
 *  `引用致谢` sheet: bindSheet → DependencyModal (21 dependencies)                                  COM-A19
 */
import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { Dimens } from '../core/designsystem/Dimens';
import { ThemeManager } from '../core/designsystem/ThemeManager';
import { AppNavigator } from '../core/navigation/AppNavigator';
import { AvoidArea } from '../core/ui/base/AvoidArea';
import { TOP_APP_BAR_HEIGHT } from '../core/ui/base/TopAppBars';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { SheetDefaults } from '../core/ui/widget/BottomSheet';
import { AppListItem } from '../core/ui/widget/ListItem';
import { PackageUtils } from '../core/util/PackageUtils';
import { AboutViewModel } from '../feature/common/about/AboutViewModel';
import { AuroraBackground } from '../feature/common/about/AuroraBackground';
import { CommonNavigator } from '../feature/common/about/CommonNavigator';
import { Dependency } from '../feature/common/about/Dependency';
import { DependencyModal } from '../feature/common/about/DependencyModal';

/** Scroll distance over which the header fades out / the toolbar fades in (source 220.dp) */
const SCROLL_FADE_THRESHOLD: number = 220;
/** Entrance start delay (source delay(100)) */
const ENTRANCE_DELAY_MS: number = 100;
/** Toolbar nav icon button size (M3 IconButton 48) / arrow icon (ArrowLeftIcon 28) */
const NAV_BUTTON_SIZE: number = 48;
const NAV_ICON_SIZE: number = 28;

@Builder
export function CommonRoutesAboutPageBuilder() {
  CommonRoutesAboutPage()
}

@ComponentV2
struct CommonRoutesAboutPage {
  @Local vm: AboutViewModel = new AboutViewModel();
  @Local avoidArea: AvoidArea = AvoidArea.get();
  /** Vertical scroll offset of the content (vp) */
  @Local scrollY: number = 0;
  /** Entrance animation values (source entranceAlpha / entranceTranslationY) */
  @Local entranceAlpha: number = 0;
  @Local entranceTranslationY: number = 30;
  /** Page height (vp), bounds the dependency list inside the sheet */
  @Local pageHeight: number = 0;
  /** Package info (PackageUtils) */
  @Local appName: string = '';
  @Local versionName: string = '';
  @Local versionCode: string = '';

  private scroller: Scroller = new Scroller();
  private entranceTimer: number = -1;
  private disappeared: boolean = false;

  aboutToAppear(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    this.appName = PackageUtils.getCurrentAppName(ctx);
    this.versionName = PackageUtils.getCurrentVersionName();
    this.versionCode = PackageUtils.getCurrentVersionCode().toString();
    this.entranceTimer = setTimeout(() => {
      this.entranceTimer = -1;
      if (this.disappeared) {
        return;
      }
      // source: alpha tween(800), translationY tween(1000, EaseOutCubic)
      this.getUIContext().animateTo({ duration: 800, curve: Curve.EaseInOut }, () => {
        this.entranceAlpha = 1;
      });
      this.getUIContext().animateTo({ duration: 1000, curve: curves.cubicBezierCurve(0.33, 1, 0.68, 1) }, () => {
        this.entranceTranslationY = 0;
      });
    }, ENTRANCE_DELAY_MS);
  }

  aboutToDisappear(): void {
    this.disappeared = true;
    if (this.entranceTimer >= 0) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = -1;
    }
  }

  /** clamp(scrollY / 220, 0, 1) */
  private scrollFraction(): number {
    return Math.min(1, Math.max(0, this.scrollY / SCROLL_FADE_THRESHOLD));
  }

  private contentAlpha(): number {
    return 1 - this.scrollFraction();
  }

  private contentScale(): number {
    return 1 - this.scrollFraction() * 0.1;
  }

  /** Toolbar background: colorScheme.background @ toolbarAlpha */
  private toolbarBackground(): string {
    const bg: string = ThemeManager.instance.isDark ? '#111111' : '#F1F4FA';
    return ThemeManager.withAlpha(bg, this.scrollFraction());
  }

  /** Logo card container: surfaceVariant @ 0.4 */
  private logoCardColor(): string {
    const sv: string = ThemeManager.instance.isDark ? '#222222' : '#F8F8F8';
    return ThemeManager.withAlpha(sv, 0.4);
  }

  /** Max height of the dependency list inside the sheet (sheet chrome ≈ 100vp) */
  private dependencyListMaxHeight(): number {
    const h: number = this.pageHeight > 0 ? this.pageHeight : 800;
    return Math.max(200, h * 0.9 - this.avoidArea.top - 100);
  }

  // ------------------------------------------------------------------ header

  @Builder
  topSection() {
    Column() {
      // Spacer(130)
      Row()
        .width('100%')
        .height(130)

      // Logo card
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_logo'))
          .width(100)
          .height(100)
          .objectFit(ImageFit.Contain)
          .draggable(false)
      }
      .width(120)
      .height(120)
      .backgroundColor(this.logoCardColor())
      .borderRadius(Dimens.radiusExtraLarge)
      .clip(true)

      // SpaceVerticalXLarge
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalXLarge)

      Text(this.appName)
        .fontSize(Dimens.fontDisplayLarge)
        .lineHeight(Dimens.lineDisplayLarge)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      // SpaceVerticalSmall
      Row()
        .width('100%')
        .height(Dimens.spaceVerticalSmall)

      Text('Version ' + this.versionName)
        .fontSize(Dimens.fontBodyMedium)
        .lineHeight(Dimens.lineBodyMedium)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    // source CenterColumn: centerHorizontally, Arrangement.Center
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  // ------------------------------------------------------------------ scroll content

  @Builder
  sectionTitle(titleText: ResourceStr) {
    Column() {
      TitleWithLine({ titleText: titleText })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: Dimens.spaceVerticalXLarge, bottom: Dimens.spaceVerticalMedium })
  }

  @Builder
  developerLeading() {
    Row() {
      Image($r('app.media.avatar'))
        .width(36)
        .height(36)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
        .clip(true)
        .accessibilityText($r('app.string.about_developer_name'))
      Column() {
        Text($r('app.string.about_developer_name'))
          .fontSize(Dimens.fontTitleLarge)
          .lineHeight(Dimens.lineTitleLarge)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.about_developer_email'))
          .fontSize(Dimens.fontBodyMedium)
          .lineHeight(Dimens.lineBodyMedium)
          .fontColor($r('app.color.text_tertiary'))
      }
      .margin({ left: Dimens.spaceHorizontalMedium })
      // source Column without alignment = start
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  infoCard() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.about_app_name'),
        trailingText: this.appName,
        showArrow: false,
        showDivider: true,
        clickable: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge
      })
      AppListItem({
        itemTitle: $r('app.string.about_version'),
        trailingText: this.versionName,
        showArrow: false,
        showDivider: true,
        clickable: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge
      })
      AppListItem({
        itemTitle: $r('app.string.about_version_code'),
        trailingText: this.versionCode,
        showArrow: false,
        showDivider: false,
        clickable: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  developerCard() {
    Column() {
      // Developer: title "" + leading avatar / name / email (default vertical padding)
      AppListItem({
        itemTitle: '',
        hasLeadingContent: true,
        leadingContent: (): void => {
          this.developerLeading()
        },
        showArrow: true,
        showDivider: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        onItemClick: () => {
          CommonNavigator.toWeb('https://github.com/Joker-x-dev', 'Joker.X');
        }
      })
      AppListItem({
        itemTitle: $r('app.string.contributors_title'),
        showArrow: true,
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          CommonNavigator.toContributors();
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  /** A link row: title + description → Web(url, webTitle) */
  @Builder
  linkRow(rowTitle: ResourceStr, rowDesc: ResourceStr | undefined, url: string, webTitle: string, divider: boolean) {
    AppListItem({
      itemTitle: rowTitle,
      description: rowDesc,
      showArrow: true,
      showDivider: divider,
      horizontalPadding: Dimens.spaceHorizontalLarge,
      verticalPadding: Dimens.spaceVerticalLarge,
      onItemClick: () => {
        CommonNavigator.toWeb(url, webTitle);
      }
    })
  }

  @Builder
  projectCard() {
    Column() {
      this.linkRow($r('app.string.about_github'), $r('app.string.about_github_url'),
        'https://github.com/Joker-x-dev/CoolMallKotlin', 'GitHub', true)
      this.linkRow($r('app.string.about_gitee'), $r('app.string.about_gitee_url'),
        'https://gitee.com/Joker-x-dev/CoolMallKotlin', 'Gitee', false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  resourcesCard() {
    Column() {
      this.linkRow($r('app.string.about_api_doc'), $r('app.string.about_api_doc_desc'),
        'https://coolmall.apifox.cn', 'API 文档', true)
      this.linkRow($r('app.string.about_demo_download'), $r('app.string.about_demo_download_desc'),
        'https://www.pgyer.com/CoolMallKotlinProdRelease', 'Demo 下载', true)
      this.linkRow($r('app.string.about_icon_source'), $r('app.string.about_icon_source_desc'),
        'https://github.com/tuniaoTech', '图标来源', false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  discussionCard() {
    Column() {
      this.linkRow($r('app.string.about_github_discussion'), $r('app.string.about_github_discussion_desc'),
        'https://github.com/Joker-x-dev/CoolMallKotlin/discussions', 'GitHub 讨论区', true)
      // QQ 交流群: source onClick = {} (row is clickable, does nothing)
      AppListItem({
        itemTitle: $r('app.string.about_qq_group'),
        showArrow: true,
        showDivider: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          console.info('TODO:noop-as-source:about_qq_group');
        }
      })
      // 微信交流群: source onClick = {} (row is clickable, does nothing)
      AppListItem({
        itemTitle: $r('app.string.about_wechat_group'),
        showArrow: true,
        showDivider: false,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          console.info('TODO:noop-as-source:about_wechat_group');
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  supportCard() {
    Column() {
      this.linkRow($r('app.string.about_translation'), $r('app.string.about_translation_desc'),
        'https://github.com/Joker-x-dev/CoolMallKotlin/issues', '翻译', true)
      this.linkRow($r('app.string.about_support'), $r('app.string.about_support_desc'),
        'https://github.com/Joker-x-dev/CoolMallKotlin', '支持', true)
      this.linkRow($r('app.string.about_help'), $r('app.string.about_help_desc'),
        'https://github.com/Joker-x-dev/CoolMallKotlin/issues', '帮助', false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  otherCard() {
    Column() {
      AppListItem({
        itemTitle: $r('app.string.about_citation'),
        description: $r('app.string.about_citation_desc'),
        showArrow: true,
        showDivider: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          this.vm.onCitationClick();
        }
      })
      AppListItem({
        itemTitle: $r('app.string.about_user_agreement'),
        showArrow: true,
        showDivider: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          CommonNavigator.toUserAgreement();
        }
      })
      AppListItem({
        itemTitle: $r('app.string.about_privacy_policy'),
        showArrow: true,
        showDivider: true,
        horizontalPadding: Dimens.spaceHorizontalLarge,
        verticalPadding: Dimens.spaceVerticalLarge,
        onItemClick: () => {
          CommonNavigator.toPrivacyPolicy();
        }
      })
      this.linkRow($r('app.string.about_open_source_license'), undefined,
        'https://github.com/Joker-x-dev/CoolMallKotlin/blob/main/LICENSE', '开源许可', false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }

  @Builder
  bottomScrollableContent() {
    Scroll(this.scroller) {
      Column() {
        // Spacer(360): content starts below the animated header
        Row()
          .width('100%')
          .height(360)
        this.infoCard()
        this.sectionTitle($r('app.string.about_developer'))
        this.developerCard()
        this.sectionTitle($r('app.string.about_section_project'))
        this.projectCard()
        this.sectionTitle($r('app.string.about_section_resources'))
        this.resourcesCard()
        this.sectionTitle($r('app.string.about_section_discussion'))
        this.discussionCard()
        this.sectionTitle($r('app.string.about_section_support'))
        this.supportCard()
        this.sectionTitle($r('app.string.about_section_other'))
        this.otherCard()
        Text($r('app.string.about_copyright'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(Dimens.fontBodyMedium)
          .lineHeight(Dimens.lineBodyMedium)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: Dimens.spaceVerticalXLarge })
          .padding({ bottom: Dimens.spacePaddingLarge })
      }
      .width('100%')
      .padding({ left: Dimens.spacePaddingLarge, right: Dimens.spacePaddingLarge })
      // source Column without alignment = start
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onDidScroll(() => {
      this.scrollY = Math.max(0, this.scroller.currentOffset().yOffset);
    })
  }

  // ------------------------------------------------------------------ toolbar

  @Builder
  animatedToolbar() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Image($r('app.media.ic_left'))
              .width(NAV_ICON_SIZE)
              .height(NAV_ICON_SIZE)
              .objectFit(ImageFit.Contain)
              .fillColor($r('app.color.text_primary'))
          }
          .width(NAV_BUTTON_SIZE)
          .height(NAV_BUTTON_SIZE)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            AppNavigator.back();
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 4, right: 4 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        Text($r('app.string.about_title'))
          .fontSize(Dimens.fontTitleLarge)
          .lineHeight(Dimens.lineTitleLarge)
          .fontWeight(Dimens.weightBold)
          .fontColor($r('app.color.text_primary'))
          .opacity(this.scrollFraction())
          .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .height(TOP_APP_BAR_HEIGHT)
    }
    .width('100%')
    .padding({ top: this.avoidArea.top })
    .backgroundColor(this.toolbarBackground())
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  dependencySheet() {
    DependencyModal({
      dependencies: this.vm.dependencies,
      listMaxHeight: this.dependencyListMaxHeight(),
      onDependencyClick: (d: Dependency) => {
        this.vm.onDependencyClick(d);
      }
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // 1. Aurora background (fades out on scroll, fades in on entrance)
        Stack({ alignContent: Alignment.TopStart }) {
          AuroraBackground()
        }
        .width('100%')
        .height('100%')
        .opacity(this.contentAlpha() * this.entranceAlpha)
        .hitTestBehavior(HitTestMode.None)

        // 2. Header (fade + shrink on scroll; entrance fade + slide up)
        Column() {
          Column() {
            this.topSection()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .opacity(this.contentAlpha())
          .scale({ x: this.contentScale(), y: this.contentScale() })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .opacity(this.entranceAlpha)
        .translate({ y: this.entranceTranslationY })
        .hitTestBehavior(HitTestMode.None)

        // 3. Scrollable content
        this.bottomScrollableContent()

        // 4. Animated toolbar (top only)
        this.animatedToolbar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.pageHeight = Number(newArea.height);
      })
      .bindSheet(this.vm.showDependencyModal, this.dependencySheet(),
        SheetDefaults.options((): void => {
          this.vm.onDismissDependencyModal();
        }, $r('app.color.bg_page')))
    }
    .hideTitleBar(true)
  }
}
