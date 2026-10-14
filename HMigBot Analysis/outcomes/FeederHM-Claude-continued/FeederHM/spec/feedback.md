# feedback.md — Feeder 迁移回流候选（只产候选，不改套件）

## 环境 / 宿主（沿用 Tusky 一轮结论）
- devecocli 缺失→手工 scaffold；签名由用户在 DevEco Studio 开启自动签名。
- Workflow 引擎无 check/readSection/argsFile → `.deveco/adapter/` 适配层（模板正文不改）。

## 阶段一
- wire-routes Compose 轨未识别 sealed class 形式的目的地（`NavigationDestination` 子类 data object + `path=`），只抓到壳 Activity 的字符串 startDestination（search/import）；主 NavHost 8 个目的地经 2b 页面账 + 2c `--from-ledger` 补漏。建议 Compose 轨支持 `startDestination = X.route` 解引用与 sealed destination 清点。
- `--launcher Feed` 重跑不重写 Index（冻结件），冷启仍推 Main；按"壳页转发首目的地"语义由 Main 片实现 replace→Feed。

## 2b 向量
- FeedParserTest 用到 36 份样例共 7.1MB；ArkTS Local Test 无法读宿主文件，只能内嵌为测试侧字符串模块。取 ≤150KB 的 24 份（约 1MB）进 entry/src/test/FeedFixtures.ets（plan/gen-fixtures.mjs 机械生成），其余 12 份大样例未纳入向量门——建议套件支持 Local Test 读取 test/resources 原始文件。
- convert-resources 未搬 res/raw（feeds_mapped.json 5.7MB、feed_source.txt），主会话补拷到 resources/rawfile。建议转换器把 res/raw 映射到 rawfile。

## 阶段三·地基波
- 清理工作区时删掉了适配层执行器的 out 目录，run.sh 的 mktemp 失败→所有门 exit 127（"/bin/sh: : No such file"）。已修 run.sh 自建目录。建议：适配层/套件对临时目录自愈。
- 网络 TLS 自签证书错误（DEPTH_ZERO_SELF_SIGNED_CERT）导致一轮 27 个子代理失败；resumeFromRunId 续跑恢复。
- **主机侧 Local Test 运行时把 util.Base64Helper / TextEncoder / TextDecoder / xml.XmlPullParser 实现为空桩**（探针实证），16 个向量用例因此假失败。已以纯 ArkTS TextCodec 替代。建议写入套件 arkts-vector-gate.md：向量门涉及的逻辑禁止依赖这些 API，或提供替身。

## 4a 回流
- ledger.mjs verify 对 status=rejected 的 no_equiv 降级仍做 SDK 符号检查；且 add 拒绝同 id 不同 note、status 不能改 symbols、无删除命令——误登 symbols 的条目（deg-acc-process-text，列了作为证据的 TextMenuItemId）无法经工具更正，verify 永久残留 1 条。已以 deg-acc-process-text-v2 正确登记、原条目 rejected。建议：verify 跳过 rejected；或提供 amend/supersede 子命令。
- 冒烟立案抓到真缺陷：冷启直达（小组件/深链）页面在 AppBootstrap 就绪前订阅数据导致空白——已入 conventions §J。
- ledger render 打印的是登记时的 disposition 文案（含"·待裁决"），不反映裁决后的 status，验收裁判据此误判已 open 的降级为 pending。建议 render 显示 status 字段。
- closure dead-files 不认 form_config.json 的卡片 src（ArkTS 卡片 UI 文件必然无 import），final 记 dead_file 硬违规且不可豁免；本轮以"卡片文件导出动作常量、FormExtensionAbility 引用"的去重方式消解。建议门把 form_config src 纳入入口集。
