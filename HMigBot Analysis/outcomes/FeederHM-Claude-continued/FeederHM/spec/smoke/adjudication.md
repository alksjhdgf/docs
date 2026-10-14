# 冒烟立案裁决（4a 验收前清账）
| 报告 | 路由 | 立案 | 裁决 | 理由 |
|---|---|---|---|---|
| wave-0.json（w1 run） | Import | hollow | waive（系统选择器覆盖） | 进页即调起系统 DocumentViewPicker（截图 smoke-Import.png 为系统 Recent/Browse 面板），页面子树被系统窗口覆盖属预期；源 OPML 导入屏同样直接拉起 SAF |
| wave-0.json（w1 run） | FeedWidgetSettings | hollow | **真缺陷→已修** | 冷启直达时页面在 AppBootstrap 就绪前订阅抽屉数据→落空不再刷新（正常冷启后数据存在，直达空白，复现 2 次）；修：pages/FeedWidgetSettingsPage.ets aboutToAppear 先 await AppBootstrap.ready()；复验冷启直达 2/2 出现 `All feeds`；规则入 conventions §J |
| wave-1.json | Article/Settings/AddFeedFromShare | blocked(hap 过期) | 已补跑 | wave-1-rerun.json 全绿 |
