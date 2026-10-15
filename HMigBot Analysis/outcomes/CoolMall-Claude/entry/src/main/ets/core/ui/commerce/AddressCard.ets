/**
 * Address card (source: core/ui/component/address/AddressCard.kt, AddressSkeleton.kt).
 *
 * Exports:
 *  - AddressCard: address present → `province city district` (titleLarge) + detail (secondary) + right slot
 *    (actionSlot | arrow when addressSelected) and optional bottom bar (contact, phone, `默认` tag);
 *    address null → `您还没有选择收货地址` + arrow / `点击添加收货地址`.
 *  - AddressActionButton: 32vp circular surfaceVariant icon button (address list edit/delete).
 *  - AddressCardSkeleton: skeleton of the card (showActionButtons / addressSelected / showBottomBar).
 *
 * Action slot usage (arrow-wrapped form):
 *   AddressCard({ address: a, hasActionSlot: true, actionSlot: (): void => { this.actions(a) },
 *                 onCardClick: () => {...} })
 */
import { Address } from '../../model/Market';
import { Dimens } from '../../designsystem/Dimens';
import { WeDivider } from '../widget/AppCard';
import { Tag, TagType, TagSize } from '../widget/Tags';
import { AppTextStyles, AppTextSize, AppTextType } from '../widget/Texts';
import { SkeletonTextLine, SkeletonCircle, SkeletonBlock } from '../base/Skeleton';

@Builder
function emptyAddressSlot() {
}

/** ArrowRightIcon (Icon.kt): ic_right 24vp, RightArrowGray */
@Builder
function arrowRightIcon() {
  Image($r('app.media.ic_right'))
    .width(24)
    .height(24)
    .objectFit(ImageFit.Contain)
    .fillColor($r('app.color.right_arrow_gray'))
}

@ComponentV2
export struct AddressCard {
  /** null → "select address" layout */
  @Param address: Address | null = null;
  /** source actionSlot != null */
  @Param hasActionSlot: boolean = false;
  @BuilderParam actionSlot: () => void = emptyAddressSlot;
  @Param showBottomBar: boolean = true;
  /** Order confirm: show the arrow on the right */
  @Param addressSelected: boolean = false;
  @Event onCardClick: () => void = () => {
  };

  @Builder
  bottomRow(addr: Address) {
    Row() {
      Text(addr.contact)
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
      Text(addr.phone)
        .margin({ left: Dimens.spaceHorizontalLarge })
        .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
        .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
        .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
      Blank()
        .layoutWeight(1)
      if (addr.isDefault) {
        Tag({
          tagText: $r('app.string.address_default'),
          tagType: TagType.PRIMARY,
          tagSize: TagSize.SMALL,
          tagRadius: Dimens.radiusMedium
        })
      }
    }
    .width('100%')
    .padding({
      left: Dimens.spaceHorizontalLarge,
      right: Dimens.spaceHorizontalLarge,
      top: Dimens.spaceVerticalMedium,
      bottom: Dimens.spaceVerticalMedium
    })
    // source: verticalAlignment = CenterVertically; horizontal start (Spacer weight pushes the tag to the end)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      if (this.address !== null) {
        // SpaceBetweenRow(padding 12)
        Row() {
          Column() {
            Text((this.address as Address).province + (this.address as Address).city +
              (this.address as Address).district)
              .fontSize(AppTextStyles.fontSize(AppTextSize.TITLE_LARGE))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.TITLE_LARGE))
              .fontWeight(AppTextStyles.fontWeight(AppTextSize.TITLE_LARGE))
              .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
            Text((this.address as Address).address)
              .margin({ top: 4 })
              .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
              .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
              .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
          }
          .layoutWeight(1)
          // source: Column without alignment = start
          .alignItems(HorizontalAlign.Start)

          if (this.hasActionSlot) {
            Row() {
              this.actionSlot()
            }
            .alignItems(VerticalAlign.Center)
          } else if (this.addressSelected) {
            arrowRightIcon()
          }
        }
        .width('100%')
        .padding(Dimens.spacePaddingMedium)
        // source SpaceBetweenRow: SpaceBetween + CenterVertically
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)

        if (this.showBottomBar) {
          WeDivider()
          this.bottomRow(this.address as Address)
        }
      } else {
        Row() {
          Text($r('app.string.address_not_selected'))
            .layoutWeight(1)
            .fontSize(AppTextStyles.fontSize(AppTextSize.TITLE_LARGE))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.TITLE_LARGE))
            .fontWeight(AppTextStyles.fontWeight(AppTextSize.TITLE_LARGE))
            .fontColor(AppTextStyles.color(AppTextType.PRIMARY))
          arrowRightIcon()
        }
        .width('100%')
        .padding(Dimens.spacePaddingMedium)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)

        WeDivider()
        Row() {
          Text($r('app.string.address_add_hint'))
            .fontSize(AppTextStyles.fontSize(AppTextSize.BODY_LARGE))
            .lineHeight(AppTextStyles.lineHeight(AppTextSize.BODY_LARGE))
            .fontColor(AppTextStyles.color(AppTextType.SECONDARY))
        }
        .width('100%')
        .padding({
          left: Dimens.spaceHorizontalLarge,
          right: Dimens.spaceHorizontalLarge,
          top: Dimens.spaceVerticalMedium,
          bottom: Dimens.spaceVerticalMedium
        })
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
      }
    }
    .width('100%')
    // source: Card ColumnScope / Column without alignment = start
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
    .onClick(() => {
      this.onCardClick();
    })
  }
}

/** AddressActionButton: 32vp circle (surfaceVariant), 18vp icon tinted onSurface @ 0.5. */
@ComponentV2
export struct AddressActionButton {
  @Param iconRes: Resource = $r('app.media.ic_edit_fill');
  @Event onActionClick: () => void = () => {
  };

  build() {
    Row() {
      Image(this.iconRes)
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.text_primary'))
        .opacity(0.5)
    }
    .width(32)
    .height(32)
    // source: Box(contentAlignment = Center)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(16)
    .clip(true)
    .backgroundColor($r('app.color.bg_content'))
    .onClick(() => {
      this.onActionClick();
    })
  }
}

/** AddressCardSkeleton (AddressSkeleton.kt). */
@ComponentV2
export struct AddressCardSkeleton {
  @Param showActionButtons: boolean = false;
  @Param addressSelected: boolean = false;
  @Param showBottomBar: boolean = true;

  build() {
    Column() {
      Row() {
        Column({ space: 8 }) {
          SkeletonTextLine({ widthFraction: 0.54 })
          SkeletonTextLine({ widthFraction: 0.92 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.showActionButtons) {
          Row({ space: 8 }) {
            SkeletonCircle({ skSize: 32 })
            SkeletonCircle({ skSize: 32 })
          }
          .margin({ left: Dimens.spaceHorizontalLarge })
          .alignItems(VerticalAlign.Top)
        } else if (this.addressSelected) {
          Row() {
            SkeletonBlock({ skWidth: 18, skHeight: 18, skRadius: Dimens.radiusMedium })
          }
          .margin({ left: Dimens.spaceHorizontalLarge })
          .alignItems(VerticalAlign.Top)
        }
      }
      .width('100%')
      .padding(Dimens.spacePaddingMedium)
      // source: Row without verticalAlignment = top
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)

      if (this.showBottomBar) {
        WeDivider()
        Row() {
          Row() {
            SkeletonTextLine({ widthFraction: 0.42 })
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)
          Row() {
            SkeletonTextLine({ widthFraction: 0.64 })
          }
          .layoutWeight(1)
          .margin({ left: Dimens.spaceHorizontalLarge })
          .alignItems(VerticalAlign.Top)
          // Spacer(weight 1)
          Blank()
            .layoutWeight(1)
          Row() {
            SkeletonBlock({ skWidth: 52, skHeight: 22, skRadius: Dimens.radiusMedium })
          }
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .padding({
          left: Dimens.spaceHorizontalLarge,
          right: Dimens.spaceHorizontalLarge,
          top: Dimens.spaceVerticalMedium,
          bottom: Dimens.spaceVerticalMedium
        })
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(Dimens.radiusMedium)
    .clip(true)
  }
}
