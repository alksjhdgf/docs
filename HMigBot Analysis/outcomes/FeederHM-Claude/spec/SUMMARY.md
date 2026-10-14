# FeederHM 迁移总结（2026-10-12）

## 统计（环境就绪后开始计时；相邻事件间隔 >10 分钟的空闲段已扣除）
- 起止：2026-10-12T09:35:00.057Z → 2026-10-12T17:16:29.380Z（墙钟 7h41m29s）
- **活跃时长：6h18m8s**（扣除空闲 1 段，共 1h23m20s）
- **Token 总计：759.0M**（cache 读 735.1M · cache 写 23.5M · 输出 454K · 非缓存输入 10.6K；5327 次模型调用，含全部子代理与工作流）

## ⚠ 置顶：未解决的严重缺陷（4b 走查发现）
- **全应用 bindMenu(isShow) 菜单不弹出**（模拟器+真机复现 ≥4 次）：Feed 溢出/过滤菜单、设置下拉、文章菜单等。阻断应用内入口：添加/编辑/删除订阅源、OPML 导入导出、文章分享/朗读。按工作流"一次定向修+一次复验"已修一次未果（已回滚），记 failed 交本报告，未继续改代码。
- 滑动标记已读在走查流内不复现（手动可成功 1 次），未定性。
- 授权通知后源码会弹出的"按订阅源通知设置"对话框未出现（ST-A10 留 untested）。

## 结果
- 切片：31/31 accepted（17 地基 + 14 切片）
- 断言 1014：{"passed":961,"untested":49,"failed":4}；passed 中真机 2、静态 959
- 真机 failed：FP-A52：选择"导出 OPML"后系统文件保存器默认文件名为 `feeder-export-<yyyy-MM-dd>-<当日秒数>；FP-A62：选择"导入 OPML"打开系统文件选择器（接受 xml/opml/json/octet-stream/任意类型），选中合；FP-A67：导出收藏时系统保存器默认文件名为 `feeder-saved-articles-<yyyy-MM-dd>-<当日秒数>.；UC-A22：主题、深色偏好、动态取色、字体设置在冷重启应用后仍保持
- 门：fnd-wave ✅ · slices-3b ✅ · acceptance-4a ✅ · closure-final ✅（含一次更正记录）· **runtime-4b ❌**
- 降级：open 56，rejected 11（全量见 REPORT.md）
- ledger verify：1 条残留违规（套件缺陷：rejected 的 no_equiv 条目仍被符号检查，工具无法更正 symbols；正确条目为 deg-acc-process-text-v2）；静态证据可定位 958/959（UC-A10 已带文件:行仍被判不可定位，原因未查明）

## 未验到（untested 49 条 on_device）
需菜单入口的项（分享/朗读/OPML/编辑删除）、需真机的项（TTS 发声、同步后真弹通知）、后台周期同步（workScheduler 时间盒内不可观测）、小组件添加与刷新。

## 交付物
- 工程：output/FeederHM（签名 HAP：entry/build/default/outputs/default/entry-default-signed.hap）
- 台账投影：spec/REPORT.md；走查证据：spec/4b/*.report.json、spec/screenshots/
- 回流候选：spec/feedback.md、spec/lib-adjudications.json
