# 宿主能力实测（阶段一第 2 步，Claude Code 桌面版会话）
| 能力 | 实测 | 走法 |
|---|---|---|
| 工程创建 devecocli create | 缺失 | 手工 scaffold（纯 ArkTS Stage 工程，bundleName=com.nononsenseapps.feeder） |
| 构建 | 无 build_project 工具 | `hvigorw assembleHap` 退出码 |
| 签名 | devecocli 缺失；用户在 DevEco Studio 开启自动签名 | signingConfigs 已配置，真机装机实测成功 |
| 设备 | 模拟器 127.0.0.1:5555 + 真机 77UYD26331000973 | hdc / walk.mjs |
| workflow 引擎 | 无 check()/readSection()/argsFile | `.deveco/adapter/`（模板正文不改；内嵌 args；check 经子代理执行 shell；临时文件分块写拦截为明文 Write） |
| 官方文档检索 | 缺失 | grep 本机 SDK .d.ts |
