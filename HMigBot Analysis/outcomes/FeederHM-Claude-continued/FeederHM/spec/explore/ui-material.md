# 探索：ui-material（自定义 Material3 组件域，前缀 UM）

源目录：`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/material3/`（含 `tokens/`），共 12 个文件、约 2100 行。
本质：从 AOSP androidx.compose.material3（2021 版，Apache-2.0 头）**复制并改造**的 NavigationDrawer + 旧版 Swipeable 实现，
唯一的 Feeder 定制点是抽屉宽度计算（折叠屏折痕感知，`tokens/NavigationDrawerTokens.kt:52-71`）。
其余（ColorScheme/Shapes/tokens）只是给抽屉组件取主题色/形状的私有辅助，**不是 App 主题本身**（App 主题在 `ui/compose/theme/`，非本区）。

## 1. 文件清单
| 文件 | 行数 | 内容 |
|---|---|---|
| material3/NavigationDrawer.kt | 930 | DrawerValue/DrawerState/rememberDrawerState；Modal/Dismissible/Permanent NavigationDrawer；三种 DrawerSheet；DrawerDefaults；NavigationDrawerItem(+Colors/Defaults)；Scrim；内部 Strings |
| material3/SwipeableState.kt | 905 | 旧版 Material `SwipeableState` + `Modifier.swipeable`、阈值（Fixed/Fractional）、ResistanceConfig、computeTarget、NestedScrollConnection |
| material3/ColorScheme.kt | 51 | `ColorScheme.fromToken(ColorSchemeKeyTokens)` / `ColorSchemeKeyTokens.toColor()` |
| material3/Shapes.kt | 42 | `Shapes.fromToken(ShapeKeyTokens)`、`CornerBasedShape.top()/end()` |
| material3/Lerp.kt | 8 | `lerp(start,end,fraction)`（FractionalThreshold 用） |
| material3/SystemBarsDefaultInsets.kt | 9 | `WindowInsets.systemBarsForVisualComponents = systemBars` |
| tokens/NavigationDrawerTokens.kt | 72 | 抽屉颜色/尺寸 token + `getContainerWidth()`（折叠屏定制） |
| tokens/ColorSchemeKeyTokens.kt / ShapeKeyTokens.kt / TypographyKeyTokens.kt | 33/15/19 | 枚举 |
| tokens/ElevationTokens.kt | 12 | Level0..5 = 0/1/3/6/8/12dp |
| tokens/ScrimTokens.kt | 6 | Scrim 色 = colorScheme.scrim，不透明度 0.32 |

## 2. 外部使用面（全仓 grep `ui.compose.material3`）
仅 2 个调用方：
- `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/feed/FeedScreen.kt:137-139` 导入 `DrawerState`、`DrawerValue`、`rememberDrawerState`。
  - `:249` `rememberDrawerState(initialValue = DrawerValue.Closed)`
  - `:254-263` `BackHandler(enabled = drawerState.isOpen)` → `close()`（已入 feed-screen 卡 FD-A05）
  - `:589-596`、`:1050-1057`、`:1079-1086` 顶栏导航按钮：`if (isOpen) close() else open()`（已入 FD-A04）
  - FAB + `pref_open_drawer_on_fab` 时打开抽屉（FD-A36）
- `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/navdrawer/NavDrawer.kt:69-71` 导入 `DismissibleDrawerSheet`、`DismissibleNavigationDrawer`、`DrawerState`。
  - `ScreenWithNavDrawer`（:77-124）：`LaunchedEffect(drawerState.isOpen)` 打开即 `focusRequester.requestFocus()`（:90-94）；
    `DismissibleNavigationDrawer(modifier.onKeyEventLikeEscape { close() })`（:96-102）；
    `drawerContent = DismissibleDrawerSheet { ListOfFeedsAndTags(...) }`，项点击 → `onDrawerItemSelect(id, tag)` 后 `close()`（:106-120）。
  - `onKeyEventLikeEscape`（`input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/Focusable.kt:15`）匹配 `Key.Escape`、`Key.Back`、`Key.NavigateOut`。

**未被使用（死代码）**：`ModalNavigationDrawer`、`PermanentNavigationDrawer`、`ModalDrawerSheet`、`PermanentDrawerSheet`、
`NavigationDrawerItem`/`NavigationDrawerItemColors`/`NavigationDrawerItemDefaults`、`Scrim`（仅 Modal 用）、`rememberSwipeableState(For)`、
`PreUpPostDownNestedScrollConnection`、`ResistanceConfig` 的实际阻尼（抽屉传 `resistance = null`）。迁移无需复刻。
`gesturesEnabled` 调用方未传 → 默认 true。

## 3. 实际生效的组件行为（Dismissible 路径）
### 3.1 DrawerState（NavigationDrawer.kt:96-246）
- `DrawerValue { Closed, Open }`。
- 内部持有 `SwipeableState(initialValue, animationSpec = TweenSpec(256ms), confirmStateChange)`（:120-125, :908）。
- `isOpen/isClosed` = `currentValue == Open/Closed`（:131-138）；`currentValue` 只在 snap/动画/甩动结束后更新（SwipeableState.kt:336-371 finally 块；以 0.5px 内锚点定值，否则保留旧值）。
  → **动画进行中 isOpen 仍为旧值**：开启动画中再按导航按钮会再次调用 `open()`（中断并重启同向动画），不会反向关闭。迁移时如用平台 SideBar 的布尔状态，行为可能不同（风险低）。
- `open()`/`close()` = `animateTo(..., TweenSpec 256ms)`；`snapTo`；`targetValue`；`offset: State<Float>`（像素，Closed=-宽度px，Open=0）。
- `saver` 存 `currentValue`；`rememberDrawerState` 用 `rememberSaveable` → 配置变更/进程重建后恢复开关态（:240-246）。

### 3.2 DismissibleNavigationDrawer（:361-424）
- 宽度 `getContainerWidth()`；锚点 `{-widthPx: Closed, 0: Open}`。
- `Modifier.swipeable(orientation=Horizontal, thresholds=FractionalThreshold(0.5f), velocityThreshold=400.dp, resistance=null, reverseDirection=isRtl, enabled=gesturesEnabled)`（:378-388）。
- 自定义 `Layout`：先放 drawer（x = offset），再放 content（x = sheetWidth + offset）。即 **推挤式**：内容随抽屉平移、无遮罩、无点击外部关闭（:390-422）。
  布局整体尺寸取 content 的宽高；抽屉在 Closed 时位于屏外左侧（-width）。
- 抽屉 Box 语义：`paneTitle = androidx.compose.ui.R.string.navigation_menu`（英文 "Navigation menu"）；打开时 `dismiss {}` 动作调用 close（:391-405）。
- 抽屉 content 外的主内容在抽屉打开时**仍可交互**（无 scrim）——与 Modal 抽屉不同；但由于被推出屏幕可视部分减少（手机 360vp 宽时主内容几乎全部被推出屏）。

### 3.3 SwipeableState 拖动/甩动算法（SwipeableState.kt）
- 拖动：`draggableState` 累加 absoluteOffset，夹在 [minBound,maxBound]，溢出部分按 resistance（此处 null → 无回弹阻尼）（:202-211）。
- `startDragImmediately = isAnimationRunning`：动画中可直接抓住抽屉（:617）。
- 松手：`performFling(velocity)` → `computeTarget`（:773-807）：在相邻两锚点间，若朝上锚速度 ≥ 阈值(400dp/s 转 px) 直达；否则以 `lerp(from,to,0.5)` 中点判定；若 `confirmStateChange(target)` 为 false 回弹原锚点（:373-394）。
- 锚点变化（如旋转导致宽度变化）：`processNewAnchors` 动画迁移到新锚点（被打断则 snap），并重设 currentValue（:145-195）。
- `ensureInit` 首帧同步把 offset 置为初始值锚点（:133-143）。
- `snapTo/animateTo` 等待首个非空 anchors（`latestNonEmptyAnchorsFlow`）后执行（:318-371）——即在抽屉首次布局前调用 open() 会挂起到布局完成。

### 3.4 DismissibleDrawerSheet / DrawerSheet（:512-610）
- 默认 shape `RectangleShape`（Dismissible），容器色 `colorScheme.surface`，内容色 `contentColorFor(surface)`，tonalElevation = `StandardContainerElevation` = 0dp。
- `Surface.sizeIn(minWidth=240dp, maxWidth=getContainerWidth()).fillMaxHeight()`；内部 `Column.windowInsetsPadding(DrawerDefaults.windowInsets)`。
- `DrawerDefaults.windowInsets = systemBars.only(Vertical + Start)`（:647-653）→ 抽屉内容避让状态栏、导航栏与起始侧系统栏（edge-to-edge 下必须）。

### 3.5 抽屉宽度（Feeder 定制，tokens/NavigationDrawerTokens.kt:52-71）
```
screenWidth = LocalConfiguration.screenWidthDp
if (LocalFoldableHinge != null && hinge.isTopToBottom /*bounds.top==0*/):
   width = (LTR ? hinge.bounds.left.toDp() : screenWidth - hinge.bounds.right.toDp()) - LocalDimens.gutter/2
else width = 360.dp
return width.coerceAtMost(screenWidth)
```
- `LocalFoldableHinge` 由 `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/Foldables.kt:23-38`（accompanist-adaptive `calculateDisplayFeatures` + Jetpack WindowManager `FoldingFeature`）提供，在 `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/utils/ComposeProviders.kt:30` 包裹全应用。
- gutter 值来自 `input/Feeder/app/src/main/java/com/nononsenseapps/feeder/ui/compose/theme/Dimensions.kt`（手机 16dp，较宽屏 32dp）。
- 注意：未定义折痕时 compositionLocal 默认值抛错（`error("Missing FoldableHinge container!")`），因此必须在 provider 内使用。

## 4. Token 值（供视觉对齐参考，未入卡）
- 容器宽 360dp、最小 240dp、项高 56dp、项指示器全圆角、项内边距 start16/end24、图标与文本间距 12dp、ItemPadding 水平 12dp。
- Modal 抽屉：shape = `CornerLargeEnd`（large 圆角只保留末端两角）、elevation 1dp、scrim = colorScheme.scrim @ 0.32。
- 动画：TweenSpec 256ms（默认 easing FastOutSlowIn）。
- ColorSchemeKeyTokens 29 项 → 对应 M3 ColorScheme 同名字段（ColorScheme.kt:15-46）；ShapeKeyTokens 11 项 → Shapes（Shapes.kt:25-38）。

## 5. 鸿蒙映射建议
- ArkUI `SideBarContainer`：`SideBarContainerType.Embed` 近似 Dismissible（内容被挤压/并排而非平移推出屏外）；`Overlay` 近似 Modal。
  Feeder 语义是"推挤平移"（主内容整体平移 = 抽屉宽度，不是缩窄）。若要逐像素等价，可自绘：`Stack` + 两个子组件 `translate({x})` + `PanGesture(direction: Horizontal)` + `animateTo({duration:256})`。
- 状态保存：DrawerState 用 rememberSaveable → 鸿蒙可用 `@StorageLink`/`PersistentStorage` 或页面状态在横竖屏切换时天然保留（ArkUI 横竖屏不重建页面，差异小）。
- 返回键关闭抽屉：`onBackPress()`（Navigation/NavDestination `onBackPressed`）中判断抽屉开则关闭并返回 true。
- 物理键 Escape：`onKeyEvent` 处理 `KeyCode.KEYCODE_ESCAPE`。
- 打开后焦点进入列表：`focusControl.requestFocus(id)`。
- 无障碍：`accessibilityText('Navigation menu')`；dismiss 动作在 ArkUI 无直接等价（降级：提供可聚焦的关闭按钮/依赖返回键）。
- 系统栏避让：`expandSafeArea` 不对抽屉内容展开，或通过 `window.getWindowAvoidArea(TYPE_SYSTEM)` 取 topRect/bottomRect 做 padding。
- 折叠屏折痕：`@ohos.display` `display.getCurrentFoldCreaseRegion()` / `display.isFoldable()` / `on('foldStatusChange')` 获取折痕矩形；竖直折痕 = creaseRects[0] 高 ≈ 屏高。

## 6. 平台差异 / 结果契约
- 结果契约：抽屉开关态在配置变更后保持；鸿蒙实现：ArkUI 旋转不销毁组件，`@State` 即保持，若需进程级恢复用 `AppStorage`；差异：Android 依赖 Saver，鸿蒙无需。
- 结果契约：手势拖动/甩动半程判定；鸿蒙实现：PanGesture.onActionEnd 读 `event.velocityX` 与 offset，阈值 0.5 × 宽度、400vp/s；差异：SideBarContainer 自带手势规则不可配置阈值，需自绘才能完全一致。
- Compose `ExperimentalMaterial3Api` 复制代码 → 鸿蒙无需移植 SwipeableState 通用引擎，只实现两锚点抽屉即可。

## 7. 降级候选
- 无障碍 `dismiss` 自定义动作（ArkUI 无 semantics dismiss 等价）→ 以返回键/关闭按钮替代。
- 折叠屏折痕对齐的抽屉宽度：非折叠设备无影响；若 display 折痕 API 在目标设备不可用 → 退回 min(360vp, 屏宽)。
- "推挤平移"精确视觉：若用 SideBarContainer(Embed) 则变为挤压并排，视觉不同但功能等价。

## 8. 风险
1. 动画中 `isOpen` 取 currentValue（未完成前为旧值）——切换按钮/返回键行为在动画中途与"目标值"语义不同；用平台组件时注意别产生"连点反向"差异（低）。
2. 抽屉在手机上宽度 360vp 夹到屏宽 → 打开时主内容几乎被推出屏幕；SideBarContainer Embed 在窄屏会把内容压到 0 宽或改为 Overlay（据 ArkUI 文档 `minContentWidth` 默认 360vp，可能触发自动切换，需实测），需显式配置。
3. 拖动手势与 Feed 列表条目的横向滑动标记已读（swipe-to-dismiss，非本区）存在手势冲突：Android 版两者共存（抽屉 draggable 位于外层容器），鸿蒙需用 `parallelGesture`/手势优先级或边缘触发区处理。
4. 折痕宽度依赖 `LocalDimens.gutter`、WindowManager FoldingFeature —— 鸿蒙需另行获取折痕区域与断点。
5. 系统字符串 `androidx.compose.ui.R.string.navigation_menu`（"Navigation menu"）与 `close_drawer`（仅 Modal Scrim 用，未生效）来自 androidx.compose.ui 资源（非 app strings.xml），需在鸿蒙 resources 中自建。
