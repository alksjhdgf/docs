/**
 * ToastWarnLayout —— 由 transpile-layout 生成（源：res/layout/toast_warn.xml）。
 * 结构与数值由程序搬运；⚓ 为源锚点；TODO(transpile/attrs) 为未转译项，切片阶段按源补齐。
 * 行为（点击/数据绑定/可见性逻辑）一律由切片实现，本骨架不含任何业务逻辑。
 */
@ComponentV2
export struct ToastWarnLayout {
  build() {
    // ⚓ toast_warn.xml:2
    Row() {
      // ⚓ toast_warn.xml:14
      Image($r('app.media.ic_warning'))
        .width(24)
        .height(24)
        .margin({ right: 8 })
        .margin({ right: 8 })
      // ⚓ toast_warn.xml:21 #@android:id/message
      // TODO(attrs): lineSpacingExtra="5dp"
      Text()
        .fontSize(15)
        .fontColor(/* android:white */ '#00000000')
    }
      .padding({ left: 20 })
      .padding({ right: 20 })
      .padding({ top: 12 })
      .padding({ bottom: 12 })
      .backgroundColor('#FFB703')
.borderRadius(8)
      .alignItems(VerticalAlign.Center)
  }
}
