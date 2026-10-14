// 2b 向量提取：源 androidTest/FeedParserTest 读取的 feed 样例 → ArkTS 测试数据模块（≤150KB 的样例；纯数据）
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
const SRC = 'input/Feeder/app/src/androidTest/resources';
const test = readFileSync('input/Feeder/app/src/androidTest/java/com/nononsenseapps/feeder/model/FeedParserTest.kt', 'utf8');
const used = [...new Set([...test.matchAll(/"([a-z0-9_.-]+\.(?:xml|json|html))"/gi)].map(m => m[1]))].sort();
const all = []; const walk = d => { for (const e of readdirSync(d)) { const p = join(d, e); statSync(p).isDirectory() ? walk(p) : all.push(p); } }; walk(SRC);
const inc = [], exc = [];
for (const f of used) { const p = all.find(x => x.endsWith('/' + f)); if (!p) { exc.push(f + '(missing)'); continue; } const s = statSync(p).size; (s <= 150000 ? inc : exc).push(s <= 150000 ? [f, p] : `${f}(${s}B)`); }
let out = '/**\n * FeedFixtures.ets —— 由 output/FeederHM/spec/plan/gen-fixtures.mjs 从源 androidTest/resources 机械生成（纯数据，勿手改）。\n' +
  ' * 仅含 FeedParserTest 用到且 ≤150KB 的样例；超限样例：' + exc.join(', ') + '\n */\n' +
  'export const FEED_FIXTURE_NAMES: string[] = ' + JSON.stringify(inc.map(x => x[0])) + ';\n\n' +
  'export function feedFixture(name: string): string {\n  switch (name) {\n';
for (const [f, p] of inc) out += `    case ${JSON.stringify(f)}:\n      return ${JSON.stringify(readFileSync(p, 'utf8'))};\n`;
out += "    default:\n      return '';\n  }\n}\n";
writeFileSync('output/FeederHM/entry/src/test/FeedFixtures.ets', out);
console.log('included', inc.length, 'excluded', exc.length, (out.length / 1024 | 0) + 'KB');
