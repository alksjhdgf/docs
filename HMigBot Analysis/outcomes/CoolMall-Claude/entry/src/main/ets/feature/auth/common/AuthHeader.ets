/**
 * AuthHeader — the two-line page title of AnimatedAuthPage (source AnimatedAuthPage.kt: Text(title, 28sp SemiBold)
 * followed by a 64dp spacer). `你好，\n欢迎登录青商城` / `你好，\n欢迎注册青商城` / `重置密码`.
 */
@ComponentV2
export struct AuthHeader {
  @Param headerText: ResourceStr = '';

  build() {
    Column() {
      Text(this.headerText)
        .fontSize(28)
        .fontWeight(600) // SemiBold
        .fontColor($r('app.color.text_primary'))
      // Spacer(height = 64.dp)
      Row()
        .width('100%')
        .height(64)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start) // source TopColumn: start aligned
  }
}
