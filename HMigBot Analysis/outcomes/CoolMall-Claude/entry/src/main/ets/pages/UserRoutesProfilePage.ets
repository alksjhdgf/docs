/**
 * UserRoutesProfilePage — 个人中心 (source: feature/user/view/ProfileScreen.kt + ProfileViewModel.kt).
 *
 * AppScaffold(title = profile_title, useLargeTopBar = true): the top bar pads itself by the status bar
 * (USER-A02). Content = VerticalList(spacedBy 12, padding 12).verticalScroll:
 *  - Card: 头像 (SmallAvatar, read-only) / 昵称 (nickName ?: 未设置)                      USER-A03
 *  - TitleWithLine 账号信息 + Card: 手机号 (phone ?: 未绑定) / 账号 (id ?: 未设置)          USER-A04
 *  - TitleWithLine 社交账号 + Card: 微信 → 去绑定 / QQ → 已绑定 (static)                     USER-A05
 *  - TitleWithLine 安全 + Card: 修改密码 / 注销账户 (arrow rows, source onClick = {} no-op)  USER-A05
 *  - Card(clickable) 退出登录 → vm.logout()                                                 USER-A06
 * Login wall (USER-A01) is applied by AppNavigator.navigate (USER_ROUTES_PROFILE is login-required).
 */
import { Dimens } from '../core/designsystem/Dimens';
import { User } from '../core/model/User';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { TitleWithLine } from '../core/ui/widget/AppCard';
import { SmallAvatar } from '../core/ui/widget/Images';
import { AppListItem } from '../core/ui/widget/ListItem';
import { AppTextSize, AppTextStyles, AppTextType } from '../core/ui/widget/Texts';
import { ProfileViewModel } from '../feature/user/profile/ProfileViewModel';

/** Trailing AppText(type = TERTIARY, size = BODY_LARGE) */
@Extend(Text)
function tertiaryText() {
  .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
  .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
  .fontColor(AppTextStyles.color(AppTextType.TERTIARY))
}

@Builder
export function UserRoutesProfilePageBuilder() {
  UserRoutesProfilePage()
}

@ComponentV2
struct UserRoutesProfilePage {
  private vm: ProfileViewModel = new ProfileViewModel();

  @Builder
  avatarTrailing() {
    // A2.7: read dynamic state through `this.` inside the builder
    SmallAvatar({ avatarUrl: this.vm.userInfo?.avatarUrl ?? null })
  }

  @Builder
  nicknameTrailing() {
    Text(this.nickNameText() ?? $r('app.string.not_set'))
      .tertiaryText()
  }

  @Builder
  phoneTrailing() {
    Text(this.phoneText() ?? $r('app.string.not_bound'))
      .tertiaryText()
  }

  @Builder
  accountTrailing() {
    Text(this.accountText() ?? $r('app.string.not_set'))
      .tertiaryText()
  }

  @Builder
  goBindTrailing() {
    Text($r('app.string.go_bind'))
      .tertiaryText()
  }

  @Builder
  boundTrailing() {
    Text($r('app.string.bound'))
      .tertiaryText()
  }

  /** source userInfo?.nickName (J2: undefined from JSON treated as null) */
  private nickNameText(): string | null {
    const user: User | null = this.vm.userInfo;
    const v: string | null | undefined = user?.nickName;
    return (v === undefined || v === null) ? null : v;
  }

  /** source userInfo?.phone */
  private phoneText(): string | null {
    const user: User | null = this.vm.userInfo;
    const v: string | null | undefined = user?.phone;
    return (v === undefined || v === null) ? null : v;
  }

  /** source userInfo?.id?.toString() */
  private accountText(): string | null {
    const user: User | null = this.vm.userInfo;
    const v: number | null | undefined = user?.id;
    return (v === undefined || v === null) ? null : v.toString();
  }

  /** TitleWithLine(modifier = padding(top = SpaceVerticalSmall)) */
  @Builder
  sectionTitle(text: ResourceStr) {
    Column() {
      TitleWithLine({ titleText: text })
    }
    .padding({ top: Dimens.spaceVerticalSmall })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  profileContent() {
    // VerticalList(spacedBy(SpaceVerticalMedium), padding SpacePaddingMedium, Alignment.Start).verticalScroll
    Scroll() {
      Column({ space: Dimens.spaceVerticalMedium }) {
        // Card: 头像 / 昵称
        Column() {
          AppListItem({
            itemTitle: $r('app.string.avatar'),
            showArrow: false,
            verticalPadding: Dimens.spaceVerticalSmall,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.avatarTrailing()
            }
          })
          AppListItem({
            itemTitle: $r('app.string.nickname'),
            showArrow: false,
            showDivider: false,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.nicknameTrailing()
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(Dimens.radiusMedium)
        .clip(true)

        this.sectionTitle($r('app.string.account_info'))

        // Card: 手机号 / 账号
        Column() {
          AppListItem({
            itemTitle: $r('app.string.phone'),
            showArrow: false,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.phoneTrailing()
            }
          })
          AppListItem({
            itemTitle: $r('app.string.account'),
            showArrow: false,
            showDivider: false,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.accountTrailing()
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(Dimens.radiusMedium)
        .clip(true)

        this.sectionTitle($r('app.string.social_account'))

        // Card: 微信 / QQ (static)
        Column() {
          AppListItem({
            itemTitle: $r('app.string.wechat'),
            showArrow: false,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.goBindTrailing()
            }
          })
          AppListItem({
            itemTitle: $r('app.string.qq'),
            showArrow: false,
            showDivider: false,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge,
            hasTrailingContent: true,
            trailingContent: (): void => {
              this.boundTrailing()
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(Dimens.radiusMedium)
        .clip(true)

        this.sectionTitle($r('app.string.security'))

        // Card: 修改密码 / 注销账户 (arrow rows; source onClick defaults to {} → no behavior)
        Column() {
          AppListItem({
            itemTitle: $r('app.string.change_password'),
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge
          })
          AppListItem({
            itemTitle: $r('app.string.delete_account'),
            showDivider: false,
            horizontalPadding: Dimens.spaceHorizontalLarge,
            verticalPadding: Dimens.spaceVerticalLarge
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(Dimens.radiusMedium)
        .clip(true)

        // Card(clickable { onLogoutClick() }) { CenterBox(padding = 16, fillMaxWidth) { 退出登录 (ERROR) } }
        Stack({ alignContent: Alignment.Center }) { // source CenterBox: contentAlignment = Center
          Text($r('app.string.logout'))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
            .fontColor(AppTextStyles.color(AppTextType.ERROR))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(Dimens.spaceVerticalLarge)
        .borderRadius(Dimens.radiusMedium)
        .clip(true)
        .stateStyles({
          normal: {
            .backgroundColor($r('app.color.bg_card'))
          },
          pressed: {
            .backgroundColor($r('app.color.press'))
          }
        })
        .onClick(() => {
          this.vm.logout();
        })
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      .alignItems(HorizontalAlign.Start) // source VerticalList horizontalAlignment = Start
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart) // source verticalScroll content is top aligned
    .scrollBar(BarState.Off)
    // Large top bar collapse (source scaffold nestedScroll(scrollBehavior.nestedScrollConnection))
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: $r('app.string.profile_title'),
        useLargeTopBar: true,
        content: (): void => {
          this.profileContent()
        }
      })
    }
    .hideTitleBar(true)
  }
}
