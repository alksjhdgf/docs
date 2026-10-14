import { readFileSync, writeFileSync } from 'node:fs';
import { units } from './units.mjs';
const [out, onlyArg, doneArg = ''] = process.argv.slice(2);
const done = doneArg.split(',').filter(Boolean);
const a = JSON.parse(readFileSync('slices-args.json', 'utf8'));
a.only = onlyArg === 'REST' ? units.filter(u => u.kind === 'slice' && !done.includes(u.id)).map(u => u.id) : onlyArg.split(',');
for (const s of a.slices) if (done.includes(s.id)) s.expectation = '已完成（checked），本轮不执行：' + s.id;
writeFileSync(out, JSON.stringify(a, null, 1)); console.log(a.only.length, a.only.join(' '));
