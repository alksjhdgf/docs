import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { units } from './units.mjs';
const sec = {};
for (const f of readdirSync('cards')) { let h = ''; const d = f.replace(/\.md$/, '');
  for (const l of readFileSync('cards/' + f, 'utf8').split('\n')) { if (/^## /.test(l)) h = l.slice(3).trim(); const m = l.match(/^\s*[-*]\s+([A-Z][A-Z0-9]*-A\d+[A-Za-z0-9]*)\s+\[/); if (m && !sec[m[1]]) sec[m[1]] = { domain: d, heading: h }; } }
const feats = JSON.parse(readFileSync('features-batch.json', 'utf8'));
const owner = {}, orphan = [], multi = [];
for (const ft of feats) { const s = sec[ft.id] || { domain: ft.domain, heading: '' };
  const hits = units.filter(u => u.own.some(([d, re]) => d === s.domain && re.test(s.heading)));
  if (!hits.length) orphan.push(`${ft.id} ${s.domain} / ${s.heading}`); else { if (hits.length > 1) multi.push(`${ft.id} → ${hits.map(h => h.id)}`); owner[ft.id] = hits[0].id; } }
const per = {}; for (const [k, v] of Object.entries(owner)) (per[v] ||= []).push(k);
writeFileSync('plan/assignment.json', JSON.stringify({ owner, per }, null, 1));
console.log('orphans', orphan.length, orphan.slice(0, 20)); console.log('multi', multi.length, multi.slice(0, 20));
for (const u of units) console.log(u.id.padEnd(30), (per[u.id] || []).length);
