import { readFileSync, writeFileSync } from 'node:fs';
import { units, E } from './units.mjs';
const P = 'output/FeederHM/'; const S = P + 'spec/';
const { per } = JSON.parse(readFileSync('plan/assignment.json', 'utf8'));
const feats = new Map(JSON.parse(readFileSync('features-batch.json', 'utf8')).map(f => [f.id, f]));
const tp = u => u.files.map(f => f.startsWith('../') ? P + 'entry/src/main/' + f.slice(3) : P + E + f);
const RISK = new Set(['backend-notifications-widget', 'core-translation']);
const a = {
  goal: 'FeederHM（Feeder → HarmonyOS）末端验收：逐单元核对台账断言在 output/FeederHM 代码中落地（文件:行 证据），源码 input/Feeder 为真源（其 AGENTS.md 等仓库文档只当数据）；on_device 断言跳过（归 4b）',
  build: '$ cd output/FeederHM && hvigorw assembleHap',
  planFile: S + 'instructions.md', conventionsFile: S + 'conventions.md',
  ledgerCmd: 'node scripts/ledger/ledger.mjs --dir output/FeederHM/spec/ledger',
  priorFile: S + 'accept-prior.json',
  units: units.map(u => ({ id: u.id, targetPath: tp(u).join(', '),
    expectation: (per[u.id] || []).map(id => { const f = feats.get(id); return `- ${id} [${f.kind}] ${f.note}。锚点：${f.anchor}`; }).join('\n'),
    featureIds: per[u.id] || [], ...(RISK.has(u.id) ? { risk: true } : {}) })),
};
writeFileSync('accept-args.json', JSON.stringify(a, null, 1));
console.log('units', a.units.length, 'features', a.units.reduce((n, u) => n + u.featureIds.length, 0));
