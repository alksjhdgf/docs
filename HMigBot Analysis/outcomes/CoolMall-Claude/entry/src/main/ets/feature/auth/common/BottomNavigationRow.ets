/**
 * BottomNavigationRow (source: feature/auth/component/BottomNavigationRow.kt).
 * CenterRow (top padding 32):
 *  - withDivider = false: plain gray `messageText` + TextButton(`actionText`, brand Primary)
 *    e.g. `短信不可用？` `使用三方登录`
 *  - withDivider = true: TextButton(`messageText`, gray) `|` TextButton(`actionText`, theme primary)
 *    e.g. `去注册` | `忘记密码`
 * TextButton = M3 text button (12/8 content padding, 40vp min height).
 */
import { ThemeManager } from '../../../core/designsystem/ThemeManager';

@ComponentV2
export struct BottomNavigationRow {
  @Param messageText: ResourceStr = '';
  @Param actionText: ResourceStr = '';
  @Param withDivider: boolean = false;
  @Event onCancelClick: () => void = () => {
  };
  @Event onActionClick: () => void = () => {
  };

  build() {
    Row() {
      if (!this.withDivider) {
        Text(this.messageText)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.Gray)
      } else {
        Row() {
          Text(this.messageText)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.Gray)
        }
        .height(40)
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.onCancelClick();
        })

        Text('|')
          .fontSize(14)
          .fontColor(Color.Gray)
          .padding({ left: 8, right: 8 })
      }

      Row() {
        Text(this.actionText)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.withDivider ? ThemeManager.instance.primary : $r('app.color.primary_default'))
      }
      .height(40)
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onActionClick();
      })
    }
    .width('100%')
    .padding({ top: 32 })
    .justifyContent(FlexAlign.Center) // CenterRow
    .alignItems(VerticalAlign.Center)
  }
}
