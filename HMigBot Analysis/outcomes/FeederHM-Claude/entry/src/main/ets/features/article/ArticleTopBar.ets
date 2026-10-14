/**
 * ArticleTopBar —— 源 ArticleScreen.kt:286-480 的 SensibleTopAppBar：
 *  标题 = feedDisplayTitle；导航图标 ArrowBack（cd `Go back`）；actions 自左向右：
 *  `Fetch full article`（Article 图标）→ `Open in Web view`（OpenInBrowser）→ `Open menu`（MoreVert，DropdownMenu）（AR-A05/A07）。
 * 溢出菜单（AR-A08..A11）逐项照源：Share、[Summarize]、[Translate article / Show original (<lang>)]、Mark as unread、
 *  Save article / Stop saving article、Read aloud，以及高度 0 的无障碍 `Close menu` 项；任一项先关菜单再执行动作。
 * 菜单开闭由 ViewModel 持有（SavedState toolbarMenuVisible），bindMenu(isShow) 受控显示。
 * 顶栏顶部内边距 = 状态栏避让（AR-A01）。没有上一篇/下一篇按钮（AR-A50）。
 */
import { FeederTheme, isRtlText } from '../../ui/common/Theme';
import { M3Type, textStyle } from '../../ui/common/Typography';
import { ArticleViewModel } from './ArticleViewModel';
import { onKeyEventLikeEscape } from '../../core/platform/LayoutAdapt';

/** 源 TopAppBar 高度 64dp */
export const ARTICLE_TOP_BAR_HEIGHT: number = 64;

@ComponentV2
export struct ArticleTopBar {
  @Param vm: ArticleViewModel = new ArticleViewModel();
  @Param topInset: number = 0;
  /** 内容已滚动（源 scrolledContainerColor） */
  @Param scrolled: boolean = false;
  @Event onNavigateUp: () => void = () => {
    console.info('TODO:navigateUp:ArticleTopBar');
  };
  @Event onShare: () => void = () => {
    console.info('TODO:share:ArticleTopBar');
  };

  private closeMenuThen(action: () => void): void {
    this.vm.setToolbarMenuVisible(false);
    action();
  }

  @Builder
  iconGlyph(icon: Resource) {
    SymbolGlyph(icon)
      .fontSize(24)
      .fontColor([FeederTheme.colors.onSurfaceVariant])
  }

  @Builder
  menuRow(icon: Resource, label: ResourceStr, action: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([FeederTheme.colors.onSurfaceVariant])
      Text(label)
        .attributeModifier(textStyle(M3Type.labelLarge, false, FeederTheme.colors.onSurface))
        .margin({ left: 12 })
    }
    .width('100%')
    .constraintSize({ minWidth: 112, minHeight: 48 })
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.closeMenuThen(action);
    })
  }

  @Builder
  toolbarMenuBuilder() {
    Column() {
      this.menuRow($r('sys.symbol.share'), $r('app.string.share'), () => {
        this.onShare();
      })
      if (this.vm.showSummarize) {
        this.menuRow($r('sys.symbol.wand_and_stars'), $r('app.string.summarize'), () => {
          this.vm.summarize();
        })
      }
      if (this.vm.showTranslate) {
        this.menuRow($r('sys.symbol.translate'), this.vm.translateMenuLabel, () => {
          this.vm.translate();
        })
      }
      this.menuRow($r('sys.symbol.eye_slash'), $r('app.string.mark_as_unread'), () => {
        this.vm.markAsUnread();
      })
      this.menuRow($r('sys.symbol.star_fill'),
        this.vm.isBookmarked ? $r('app.string.unsave_article') : $r('app.string.save_article'), () => {
          this.vm.toggleBookmark();
        })
      this.menuRow($r('sys.symbol.speaker_wave_2'), $r('app.string.read_article'), () => {
        this.vm.ttsPlay();
      })
      // Hidden button for TalkBack（源高度 0 的 Close menu 项）
      Row()
        .width('100%')
        .height(0)
        .accessibilityText($r('app.string.close_menu'))
        .onClick(() => {
          this.vm.setToolbarMenuVisible(false);
        })
    }
    .constraintSize({ minWidth: 112 })
    .padding({ top: 8, bottom: 8 })
    // UT-A44：源 ArticleScreen.kt:342 DropdownMenu.onKeyEventLikeEscape（Escape/Back 关闭菜单）
    .onKeyEvent((event: KeyEvent): boolean => onKeyEventLikeEscape(event, () => {
      this.vm.setToolbarMenuVisible(false);
    }))
  }

  @Builder
  actionButton(icon: Resource, label: Resource, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      this.iconGlyph(icon)
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .onClick(() => {
      action();
    })
  }

  build() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(24)
          .fontColor([FeederTheme.colors.onSurface])
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.go_back'))
      .onClick(() => {
        this.onNavigateUp();
      })

      Text(this.vm.feedDisplayTitle)
        .attributeModifier(textStyle(M3Type.titleLarge, false, FeederTheme.colors.onSurface))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .direction(isRtlText(this.vm.feedDisplayTitle) ? Direction.Rtl : Direction.Ltr)
        .textAlign(TextAlign.Start)
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })

      Row() {
        this.actionButton($r('sys.symbol.doc_plaintext'), $r('app.string.fetch_full_article'), () => {
          this.vm.toggleFullText();
        })
        this.actionButton($r('sys.symbol.compass'), $r('app.string.open_in_web_view'), () => {
          this.vm.openInCustomTab();
        })
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          this.iconGlyph($r('sys.symbol.dot_grid_1x2'))
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.open_menu'))
        .onClick(() => {
          this.vm.setToolbarMenuVisible(true);
        })
        .bindMenu(this.vm.showToolbarMenu, (): void => {
          this.toolbarMenuBuilder()
        }, {
          onDisappear: () => {
            this.vm.setToolbarMenuVisible(false);
          }
        })
      }
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(ARTICLE_TOP_BAR_HEIGHT + this.topInset)
    .padding({ top: this.topInset, left: 4, right: 4 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.scrolled ? FeederTheme.scrolledBarColor : FeederTheme.colors.background)
  }
}
