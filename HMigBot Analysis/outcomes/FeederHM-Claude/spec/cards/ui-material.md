# ui-material 自定义 Material3 组件域断言卡

## 域: NavigationDrawer（Feed 页侧边抽屉容器）
- UM-A01 [ui] Feed 页侧边抽屉为"推挤式"（Dismissible）抽屉：打开时抽屉从起始边滑入，主内容整体被推向末端（平移量=抽屉宽度），无遮罩层；关闭时主内容回到原位并恢复可交互。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:416
- UM-A02 [ui] 抽屉初始为关闭（`DrawerValue.Closed`）；冷启动进入 Feed 页时抽屉不可见。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:249
- UM-A03 [ui] 抽屉支持水平拖动手势开/关（Feed 页未禁用手势）：松手时位移越过两锚点中点（50%）或甩动速度 ≥400dp/s 则落到对应端，否则回弹到原状态。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:379
- UM-A04 [ui] RTL 布局下抽屉从右侧出现，拖动方向随之镜像。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:377
- UM-A05 [ui] 抽屉宽度 = min(360vp, 屏幕宽度)；抽屉最小宽度 240vp。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/tokens/NavigationDrawerTokens.kt:53
- UM-A06 [ui] 折叠屏存在竖直折痕（hinge 顶边 y=0）时，抽屉宽度改为从起始边到折痕（LTR=hinge.left，RTL=屏宽−hinge.right）再减去 gutter/2，且不超过屏宽，使抽屉止于折痕一侧。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/tokens/NavigationDrawerTokens.kt:58
- UM-A07 [ui] 抽屉内容避让系统栏：顶部避让状态栏、底部避让导航栏、起始边避让侧边系统栏，不与状态栏重叠。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:652
- UM-A08 [ui] 抽屉打开时 Escape/Back/NavigateOut 按键事件到达抽屉容器即关闭抽屉。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:98
- UM-A09 [ui] 抽屉变为打开后，键盘焦点移入抽屉内订阅源列表。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:90
- UM-A10 [ui] 无障碍：抽屉容器的窗格标题为系统字符串 "Navigation menu"；抽屉打开时提供"关闭(dismiss)"无障碍动作，执行后抽屉关闭。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:393
- UM-A11 [ui] 抽屉开/关状态在配置变更（旋转、深浅色切换等 Activity 重建）后保持：打开中的抽屉重建后仍为打开。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:244
- UM-A12 [backend] DrawerState 契约：`isOpen`/`isClosed` 由 `currentValue` 决定，`currentValue` 仅在动画/拖动结束落到锚点后才更新；`open()`/`close()` 为挂起动画，可被新的动画中断（中断时按最近锚点(<0.5px)定值，否则保留原值）。锚点：input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/NavigationDrawer.kt:131
