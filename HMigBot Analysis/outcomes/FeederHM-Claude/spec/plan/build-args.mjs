import { readFileSync, writeFileSync } from 'node:fs';
import { units, E } from './units.mjs';
const P = 'output/FeederHM/'; const S = P + 'spec/';
const { per } = JSON.parse(readFileSync('plan/assignment.json', 'utf8'));
const feats = new Map(JSON.parse(readFileSync('features-batch.json', 'utf8')).map(f => [f.id, f]));
const tp = u => u.files.map(f => f.startsWith('../') ? P + 'entry/src/main/' + f.slice(3) : P + E + f);
const expect = u => (per[u.id] || []).map(id => { const f = feats.get(id); return `- ${id} [${f.kind}] ${f.note}。锚点：${f.anchor}`; }).join('\n');
writeFileSync('slices-batch.json', JSON.stringify(units.map(u => ({ id: u.id, title: u.id, targetPath: tp(u), deps: u.deps, route: u.route, expectation: expect(u).slice(0, 4000), featureIds: per[u.id] || [], status: 'planned' })), null, 1));
const fnd = units.filter(u => u.kind === 'fnd');
writeFileSync('fnd-args.json', JSON.stringify({
  goal: 'FeederHM（Feeder RSS 阅读器 → HarmonyOS ArkTS V2）地基波：模型/工具/设置/数据库/网络/HTML DOM 与线性化/Feed 解析器/OPML/仓储/同步引擎/平台/主题组件/抽屉/正文渲染/条目卡片/应用初始化',
  instructionsFile: S + 'instructions.md', conventionsFile: S + 'conventions.md',
  sharedFiles: [P + 'entry/src/test/List.test.ets'],
  waveGate: '$ cd output/FeederHM && hvigorw assembleHap --no-daemon',
  gate: ['$ cd output/FeederHM && hvigorw assembleHap --no-daemon', '$ node scripts/closure/closure-suite.mjs --project output/FeederHM --stage slice', '$ node scripts/vectors/run-arkts-vectors.mjs --project output/FeederHM --module entry'],
  units: fnd.map(u => ({ id: u.id, title: u.id, section: 'SECTION: ' + u.id, wave: u.wave, targetPath: tp(u).join(', '), detail: '本单元必须满足的台账断言（逐条实现；做不到写 deviations）：\n' + expect(u) })),
}, null, 1));
writeFileSync('slices-args.json', JSON.stringify({
  goal: 'FeederHM 切片流水（Feeder → HarmonyOS）', dst: P,
  build: '$ cd output/FeederHM && hvigorw assembleHap',
  closureSlice: '$ node scripts/closure/closure-suite.mjs --project output/FeederHM --stage slice --manifest output/FeederHM/spec/interface-manifest.json',
  closureIntegration: '$ node scripts/closure/closure-suite.mjs --project output/FeederHM --stage integration --manifest output/FeederHM/spec/interface-manifest.json',
  ledgerCmd: 'node scripts/ledger/ledger.mjs --dir output/FeederHM/spec/ledger',
  instructionsFile: S + 'instructions.md', conventionsFile: S + 'conventions.md',
  smoke: '$ node scripts/smoke/smoke.mjs --project output/FeederHM --device 127.0.0.1:5555 --out output/FeederHM/spec/smoke',
  unownedRoutes: [],
  slices: units.map(u => ({ id: u.id, targetPath: tp(u), deps: u.deps, ...(u.route ? { route: u.route } : {}), expectation: u.kind === 'fnd' ? `地基单元（已由地基波完成，本轮不执行）：${u.id}` : expect(u), featureIds: per[u.id] || [] })),
}, null, 1));
console.log('units', units.length, 'fnd', fnd.length);
