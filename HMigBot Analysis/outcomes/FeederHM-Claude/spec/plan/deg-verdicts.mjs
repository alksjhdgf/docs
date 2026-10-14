import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const rows = readFileSync('plan/deg-review.tsv', 'utf8').trim().split('\n').map(l => l.split('\t'));
const NOT_DEG = {
  9: 'request.agent 下载等价 OkHttp 流式下载（进度事件、落 .download 临时文件），结果契约不变',
  11: '快照替换天然满足"同步中无动画"契约；非同步位移动画属视觉近似归 M3 批次',
  14: '生命周期回调等价映射（applicationStateChange），触发时机契约不变',
  17: '按断言意图修正源码怪癖（源码"No feeds"不可达），记 feedback',
  18: '已修复：收口时去除转换器残留引号（base/tr 6 处），不再是降级',
  24: '单 Ability 导航模型下等价路由映射（goHome），可见行为一致',
  41: 'URL 显式拼接等价 Ktor defaultRequest 相对路径解析，结果一致',
  45: '错误文案取 JSON error.message 同源；非 JSON 兜底不减信息',
};
let o = 0, n = 0;
rows.forEach(([id, kind], i) => {
  const ln = i + 1; let to, reason;
  if (NOT_DEG[ln]) { to = 'rejected'; reason = '不构成降级（无需回片）：' + NOT_DEG[ln]; n++; }
  else { to = 'open'; reason = kind === 'no_equiv' ? 'no_equiv 成立：probe 已 grep SDK d.ts 0 命中，ledger verify --sdk 未报符号存在' : kind === 'policy' ? 'policy 成立：平台策略/能力限制（见 note/probe）' : 'approx 成立：视觉/动画/平台交互形态近似或已实施缓解，行为契约不变'; o++; }
  execFileSync('node', ['../../../scripts/ledger/ledger.mjs', 'status', '--dir', 'ledger', '--type', 'degradations', '--id', id, '--to', to, '--reason', reason], { stdio: 'pipe' });
});
console.log({ open: o, notDegradation: n });
