# UI 布局语义差异（仅 UI 单元必读；2b 拷入 spec/ 并写进各 UI 单元 SECTION 首行）

这里列的缺陷共同特征：**语法合法、编译通过、构建绿灯，逐属性对照还会被确认成"翻译正确"**——
因为它们源于两个平台对同一概念的**默认值/定义不同**，而不是译者把值写错了。
实测（一次全量迁移的产出统计）：Column 110 处只有 37 处显式写了对齐、Row 119 处只有 45 处，
其余全部落在"两端默认值相反"的射程内，对错取决于运气而非翻译。

## 1. 对齐默认值两端相反（最高频）

| 容器 | ArkUI 默认 | Android 对应容器默认 | 迁移结论 |
|---|---|---|---|
| `Column`（水平=交叉轴） | `.alignItems(HorizontalAlign.Center)` **居中** | LinearLayout(vertical) 未写 gravity = **start（左）** | 源没写 gravity → 必须显式 `.alignItems(HorizontalAlign.Start)` |
| `Row`（垂直=交叉轴） | `.alignItems(VerticalAlign.Center)` **居中** | LinearLayout(horizontal) 未写 gravity = **top（顶）** | 源没写 gravity → 必须显式 `.alignItems(VerticalAlign.Top)`（源是 center_vertical 时 Center 才对） |
| `Column`/`Row` 主轴 | `.justifyContent(FlexAlign.Start)` 起始 | 同为 start/top | 主轴默认恰好一致；但 **Row 的水平位置由主轴决定**，见硬规则② |
| `Stack` | `alignContent: Alignment.Center` **正中** | FrameLayout 未写 layout_gravity = **top\|start（左上）** | 必须显式 `Stack({ alignContent: Alignment.TopStart })`（子级差异用 `.align()`/`alignRules`） |
| `Image` | `.objectFit(ImageFit.Cover)` **居中裁剪** | ImageView 未写 scaleType = **fitCenter（完整等比显示）** | 必须显式 `.objectFit(ImageFit.Contain)`（或按源 scaleType 译，见 §3） |

出处（devecocli docs read 可复核）：Column/Row/Stack 默认值见官方 API 参考
`ts-container-column` / `ts-container-row` / `ts-container-stack`；Image 默认居中裁剪见官方 FAQ `faqs-arkui-1386`。

**八条硬规则：**

1. **Android 侧"没写 gravity"是有语义的（= start/top），不等于 ArkUI 侧可以"没写 alignItems"。**
   每个 Column/Row/Stack/Image 都显式写上表五类属性；值从源 XML 译出，源没写就写 Start/Top/TopStart/Contain。
   居中确为本意时（空态插图、按钮内图标）写 Center 并在该行注明依据即可。
2. **决定水平位置的属性在两种容器上不同名，禁止混淆**：`Column` 的水平方向是交叉轴 →
   `.alignItems(HorizontalAlign.*)`；`Row` 的水平方向是**主轴** → `.justifyContent(FlexAlign.*)`。
   一个 Row 写了完全正确的 `.alignItems(VerticalAlign.Center)`（对应源的 `center_vertical`），
   对"内容靠左还是居中"仍然什么都没说——正确的纵轴设置最容易被当成"对齐已处理"而放过。
   判据：宽度撑满的 Row 里有收缩宽度的 Text 时，必须能指出是哪个属性把它定在了左边。
3. **修存量代码禁止盲改**（如把所有没写 alignItems 的 Column 批量补 Start）：源 XML 写了
   `gravity="center"` 的容器，ArkUI 的居中默认值恰好"碰对"，批量补 Start 反而把对的改错。
   逐容器以**源 XML 为地面真值**核对（流程见 §4）。
4. **底/右锚定禁放普通流**：源为 `layout_constraint(Bottom|End|Right)_to*`、`alignParent(Bottom|End)`、
   `layout_gravity` 含 bottom/end 的元素，必须用 `Stack({ alignContent })`/`alignRules()`/
   主轴 `FlexAlign.End`（或前置 `layoutWeight(1)` 占位）表达锚定——放进普通 Column/Row 流里
   内容一变长就被挤出屏（短内容时看不出错）。内容高度可变的页面外层套 `Scroll`。
   **子元素自己的 `.align(Alignment.BottomEnd)` 不是定位**（官方通用属性文档：`align` "设置当前组件绘制区域内的
   子组件的对齐方式"，适用 Stack/Button/Text/Scroll 等，不含 Row/Column）——它不改变该组件在父 `Stack` 里的位置
   （Stack 的 `alignContent` 对全部子元素生效；绝对定位用 `position`，`alignRules` 只在 RelativeContainer 内）。右下 FAB 之类的角锚定
   用独立的 `Stack({ alignContent: Alignment.BottomEnd })` 覆盖层、`RelativeContainer + alignRules`
   或 `.position()`；真机核对：`walk.mjs dump` 的 `geometry` 行给出每个节点中心的归一化坐标（0=左/上，1=右/下），右下角锚定应接近 (1,1)。
5. **NavDestination 必须显式声明标题栏**：ArkUI 默认带系统标题栏+左上返回键，Android NoActionBar
   页面默认没有——源无标题栏 → `.hideTitleBar(true)`；源有 → `.title()` 照源。
   设置位置在**壳层路由的 `NavDestination()`**（如统一的 PageMap builder），不在各页面内。
6. **封装视觉的自定义组件，内部根必须撑满组件框**：调用侧加在组件上的 `.width/.height/.padding`
   只作用于**外框**，不进内部视觉根——背景/渐变/圆角画在内部容器上时，内部必须
   `.width('100%').height('100%')`（或把尺寸/内边距作为参数在内部应用），否则视觉只有内容大小、
   浮在正确尺寸的空槽里（Android 的 padding+background 在 view 边界内，语义相反）。
7. **Scroll 内容短于视口时默认居中排布**（官方 FAQ faqs-arkui-725）：源为 ScrollView/NestedScrollView
   （顶对齐）必须显式 `.align(Alignment.TopStart)`；受 `layoutWeight`/固定高约束的 Scroll 尤其如此。
8. **层叠中撑满的子组件吞点击**：`Stack` 里排位靠后（更上层）的 `width/height('100%')` 容器会拦截
   其下全部点击且无任何报错。纯装饰/锚定载体层必须 `.hitTestBehavior(HitTestMode.None)`；
   每个可点元素确认其上无未设透传的撑满兄弟。

## 2. 间距与尺寸语义

| 误译 | 为什么会发生 | 后果 | 怎么写对 |
|---|---|---|---|
| 容器 `space` 与子组件同轴 `margin` 叠加 | space 译自源的固定间距，margin 又逐子照搬 | 间隙加倍（"空隙过大"的主因之一） | **二选一**：等距用 `space`，不等距全用 margin；同轴不并存 |
| `.width('100%')` + 左右 `margin` | 直觉认为 100% 会自动扣掉 margin | 实际宽度 = 父宽 + 左右 margin，**右侧溢出**、圆角被裁 | 父容器 `.padding({left,right})` + 子 `.width('100%')`，或子 `.layoutWeight(1)` |
| "N dp 图标 + P dp padding" 直译成 `.width(N).padding(P)` | Android `wrap_content` 视图最终尺寸 = 内容 + padding；ArkUI `.width(N)` 是外框，padding 从 N 里**扣** | 内容区压成 N−2P（P≥N/2 时为 0：**照常占位、完全不可见**） | 源为 wrap_content 时 ArkUI 声明尺寸 = 内容 + 2×padding（`.width(N+2P).padding(P)`）；源显式 `layout_width="48dp"` 时按 48 直译即可 |
| 负 margin 被当笔误丢弃 | 负值看起来像错误 | 内容整体下移（常见于贴合状态栏的头图） | 在源里 grep `margin.*="-` 逐个确认已译出 |
| 右/下锚定写成常量 `.position()` 坐标 | 参考 view tree 只给出**参考设备上的绝对解** | 更窄屏幕上元素移出可视区被裁 | 源是 `gravity="end"`/`constraintEnd_toEndOf`/`alignParentBottom` 的，用对齐属性/`alignRules()`/父尺寸表达式，不写死坐标 |
| `.margin(N)` Length 简写 | 以为只是"间距" | 四向全含左右——与 `width('100%')` 并存同样右溢 | 全宽子组件的水平间距一律沉到父 `.padding`，简写只用于四向确实相等且非全宽的场合 |
| `calc()` 写法 | `calc(100%-32vp)` 无空格 | 运行期解析失败（API10+ 才支持 calc） | 运算符两侧必须空格：`calc(100% - 32vp)` |

## 3. 其他高频属性差异（速查）

| Android | ArkUI | 注意 |
|---|---|---|
| `View.GONE` / `View.INVISIBLE` | `.visibility(Visibility.None)` / `.visibility(Visibility.Hidden)` | None 不占位（GONE）、Hidden 占位不显示（INVISIBLE），别混 |
| `scaleType`：fitCenter / centerCrop / fitXY / center | `ImageFit`：Contain / Cover / Fill / None | 逐值对译，**别落到两端默认值上**（见 §1 表） |
| `ellipsize="end"` + `maxLines` | `.textOverflow({ overflow: TextOverflow.Ellipsis })` **必须配** `.maxLines(n)` | 只写 textOverflow 不写 maxLines 不生效 |
| `layout_weight` | `.layoutWeight(n)` | 参与分配的**所有兄弟**都要设；设了 layoutWeight 的方向不再写固定尺寸 |
| `lineSpacingExtra` N + textSize S | `.lineHeight(S+N)`（近似） | ArkUI 无"行间距"概念只有行高；Android TextView 默认还含字体内边距（includeFontPadding），文本块高度略高于 ArkUI，对不上时以此解释，不要用 margin 硬凑 |
| 背景 `<shape>` 圆角 | `.borderRadius(r)` | 子内容（图片等）要跟着圆角裁剪需加 `.clip(true)` |
| `elevation` | `.shadow({ radius, color, offsetX, offsetY })` | 无一比一换算，按视觉近似 |
| `dp` / `sp` | `vp` / `fp` | 数值 1:1；view tree bounds 是 px，只用于算比例不直接当 vp |
| Compose `alignByBaseline` / XML `layout_alignBaseline` | `Flex({...}).alignItems(ItemAlign.Baseline)`（Row 的 `VerticalAlign` 只有 Top/Center/Bottom） | 金额"¥ 99.00"这类混字号基线对齐用 Flex 或单 Text 多 Span；别写成"ArkUI 无基线对齐"登降级 |
| `FlowRow(horizontalArrangement/verticalArrangement = spacedBy)` | `Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(4) } })`（API 12） | 有 space 参数，不用逐子项 margin 近似 |
| `LazyVerticalStaggeredGrid` + `span = FullLine` 整行头/混排 | `WaterFlow({ sections })` 分段：整行头一段 `crossCount:1`，商品一段 `crossCount:2`（API 12 `WaterFlowSections`） | 不要退化成 List 两两成行；FlowItem 本身不跨列但分段可以 |
| `ScrollState.value` / `NestedScrollConnection` 读滚动量 | `List/WaterFlow/Grid.onDidScroll((offset, state) => …)`（API 12，`ScrollableCommonMethod`）；`Scroll.onDidScroll((xOffset, yOffset, state) => …)` 签名不同 | 要"先吃掉位移再滚"用 `onScrollFrameBegin`；别写"Scroll 不支持 onDidScroll" |

## 4. 写 UI 单元前的轻量 XML 对照（三步，每单元约两分钟）

开写一个页面/组件前，对它的源 layout XML 跑一遍：

```bash
grep -nE 'gravity|orientation|layout_weight|scaleType|visibility|margin|padding|ellipsize|maxLines|constraint(Bottom|End|Right|Baseline)_to|alignParent(Bottom|End|Right)' <源 layout 及其 include>.xml
```

1. **提取**：整理成"容器 → 对齐/间距声明"清单；**没写 gravity 的容器也要列**，标注"未写 = start/top"。
2. **翻译**：写 ArkTS 时逐容器对照清单，显式写出 §1 的五类属性；间距按 §2 第一行决定 space 还是 margin。
3. **自查**：写完跑 §5 机械门，数量对不上就回头补。

## 5. 机械自查门（单元自查与 verify 抽查通用）

```bash
E=<单元产出目录>
# ① 裸容器差值：声明数 − 显式对齐数 = 待核对数（不是缺陷数，逐个回源 XML 核对）
grep -rno "Column(" $E --include='*.ets' | wc -l ; grep -rno "alignItems(HorizontalAlign\." $E --include='*.ets' | wc -l
grep -rno "Row("    $E --include='*.ets' | wc -l ; grep -rnoE "alignItems\(VerticalAlign\.|justifyContent\(FlexAlign\." $E --include='*.ets' | wc -l
# ② Stack 未显式 alignContent
grep -rn "Stack(" $E --include='*.ets' | grep -v alignContent
# ③ Image 未显式 objectFit（Image( 与 .objectFit 通常不同行，按文件数差值核对）
grep -rln "Image(" $E --include='*.ets' | xargs grep -Ln "objectFit" 2>/dev/null
# ④ 同元素 width('100%') + 左右 margin（溢出）
grep -rn -A4 "width('100%')" $E --include='*.ets' | grep -E "margin.*(left|right)"
# ⑤ 带 space 的容器：其直接子组件是否又写了同轴 margin（双计，人工抽查命中处）
grep -rn "space:" $E --include='*.ets'
# ⑥ 锚定对账：源底/右锚数 vs 产物锚定表达数，差值大 = 锚定被摊进了普通流（硬规则④）
grep -rEc 'constraint(Bottom|End|Right)_to|alignParent(Bottom|End|Right)' <源 layout 目录>
grep -rEo 'alignRules|Alignment\.(Bottom|BottomStart|BottomEnd|End)|FlexAlign\.End' $E --include='*.ets' | wc -l
# ⑧ 误把 .align 当定位（硬规则④）：Stack 子元素上出现 .align(Alignment.Bottom*/End*) 逐个核对——要的是父 Stack alignContent / alignRules / position
grep -rnE "\.align\(Alignment\.(Bottom|BottomEnd|BottomStart|End|TopEnd)\)" $E --include='*.ets'
# ⑦ 撑满层叠子组件候选（硬规则⑧）：含 Stack 且有 100% 尺寸的文件，逐个确认可交互或已设 HitTestMode.None
grep -rlnE "\.(width|height)\('100%'\)" $E --include='*.ets' | xargs grep -ln 'Stack(' 2>/dev/null
```

①③⑤输出的是**待核对清单**而非缺陷清单——回源 XML 确认；居中/裁剪确为源本意的，注明依据即通过。

---
出处：默认值均引官方文档（§1 表下方 doc id 可用 devecocli docs read 复核）。
