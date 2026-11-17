// Phase A verification-gate check (mechanical portion).
// Checks the three example BRDs against the flutter-pipeline/v1 schema
// constraints documented in docs/brd-schema.md, and sanity-checks the
// JSON schema + doc consistency. Phase B's Dart validator supersedes
// this throwaway script.
import { readFileSync } from 'node:fs';

const root = 'packages/cell_flutter/pipeline';
const fails = [];
const ok = (name) => console.log('  PASS ' + name);
const bad = (name, msg) => { fails.push(name + ': ' + msg); console.log('  FAIL ' + name + ' — ' + msg); };

// --- JSON schema sanity ---
const schema = JSON.parse(readFileSync(`${root}/docs/brd-schema.json`, 'utf8'));
if (schema.$schema === 'https://json-schema.org/draft/2020-12/schema') ok('brd-schema.json is draft 2020-12');
else bad('brd-schema.json $schema', schema.$schema);
if (schema.properties.schema.const === 'flutter-pipeline/v1') ok('schema const pinned');
else bad('schema const', JSON.stringify(schema.properties?.schema));
const reqProps = Object.keys(schema.$defs.requirement.properties);
if (['id','sentence','screen','trigger','outcome','type'].every(k => reqProps.includes(k)))
  ok('requirement fields match docs');
else bad('requirement fields', reqProps.join(','));
const typeEnum = schema.$defs.requirement.properties.type.enum;
if (['display','interaction','recovery','atomic'].every(t => typeEnum.includes(t)))
  ok('Type enum complete');
else bad('Type enum', typeEnum.join(','));

// --- BRD structural checks ---
const stems = ['form_heavy', 'list_heavy', 'async_heavy'];
const requiredSections = ['## Requirements', '## Screens', '## State'];
const colSets = {
  '## Requirements': ['ID','Sentence','Screen','Trigger','Outcome','Type'],
  '## Screens': ['Name','Route','Widgets'],
  '## Forms': ['Name','Fields','Validator'],
  '## State': ['Name','Type','Initial','Restorable','AppLevel'],
};

for (const stem of stems) {
  const raw = readFileSync(`${root}/example/brds/${stem}.bfd.md`, 'utf8');
  const text = raw.replace(/\r\n/g, '\n');
  const lines = text.split('\n');
  const ctx = `${stem}.bfd.md`;

  // frontmatter
  if (/^---\n/.test(text)) ok(`${ctx} frontmatter present`); else bad(ctx, 'frontmatter');
  if (/^schema: flutter-pipeline\/v1$/m.test(text)) ok(`${ctx} schema pinned`); else bad(ctx, 'schema pin');
  if (/^title: \S/m.test(text)) ok(`${ctx} title present`); else bad(ctx, 'title');
  if (/^version: 1$/m.test(text)) ok(`${ctx} version 1`); else bad(ctx, 'version');

  // sections
  for (const s of requiredSections) {
    if (text.includes(s + '\n')) ok(`${ctx} has ${s}`); else bad(ctx, `missing ${s}`);
  }

  // tables: header column sets
  const headers = {};
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(## \w+)/);
    if (m && ['## Requirements','## Screens','## Forms','## State'].includes(m[1])) {
      const h = lines[i + 2]; // blank line after heading, then header row
      if (h && h.startsWith('|')) {
        headers[m[1]] = h.split('|').map(c => c.trim()).filter(Boolean);
      }
    }
  }
  for (const [sec, expected] of Object.entries(colSets)) {
    if (sec === '## Forms' && !headers[sec]) continue; // optional
    if (!headers[sec]) { bad(ctx, `no ${sec} table`); continue; }
    if (JSON.stringify(headers[sec]) === JSON.stringify(expected)) ok(`${ctx} ${sec} columns fixed`);
    else bad(ctx, `${sec} columns ${JSON.stringify(headers[sec])} != ${JSON.stringify(expected)}`);
  }

  // row-level checks: requirements
  const reqRows = extractRows(text, '## Requirements', '## Screens').map(cells);
  const ids = new Set();
  const screens = new Set(extractRows(text, '## Screens', text.includes('## Forms') ? '## Forms' : '## State').map(cells).map(r => r[0]));
  const states = extractRows(text, '## State', '## Context').map(cells);
  const stateNames = new Set(states.map(r => r[0]));
  for (const [i, r] of reqRows.entries()) {
    const [id, sentence, screen, trigger, outcome, type] = r;
    if (!/^REQ-\d{3,}$/.test(id)) bad(ctx, `req row ${i + 1} bad id ${id}`);
    if (ids.has(id)) bad(ctx, `duplicate id ${id}`); ids.add(id);
    if (!screens.has(screen)) bad(ctx, `${id} unresolved screen ${screen}`);
    if (!['display','interaction','recovery','atomic'].includes(type)) bad(ctx, `${id} invalid type ${type}`);
    if ((type === 'interaction' || type === 'recovery') && !trigger) bad(ctx, `${id} missing trigger`);
  }
  for (const r of states) {
    if (!/^[a-z][A-Za-z0-9]*$/.test(r[0])) bad(ctx, `state bad name ${r[0]}`);
    if (!['yes','no'].includes(r[3]) || !['yes','no'].includes(r[4])) bad(ctx, `state ${r[0]} bad yes/no`);
  }
  if (headers['## Forms']) {
    const forms = extractRows(text, '## Forms', '## State');
    for (const f of forms.map(cells)) {
      for (const field of f[1].split(',').map(s => s.trim())) {
        if (!stateNames.has(field)) bad(ctx, `form field ${field} unresolved in State`);
      }
    }
  }
  console.log(`  ${ctx}: ${reqRows.length} requirements, ${screens.size} screens, ${states.length} state rows`);
}

console.log(fails.length === 0 ? '\nGATE: ALL CHECKS PASS' : `\nGATE: ${fails.length} CHECK(S) FAILED`);
process.exit(fails.length === 0 ? 0 : 1);

function cells(line) {
  // Keep inner empty cells (e.g. an empty Trigger column) intact.
  return line.split('|').slice(1, -1).map(c => c.trim());
}

function extractRows(text, from, until) {
  const start = text.indexOf(from) + from.length;
  const end = text.indexOf(until, start);
  const slice = text.slice(start, end < start ? undefined : end);
  return slice.split('\n').filter(l => {
    const t = l.trim();
    return t.startsWith('|') &&
           !t.includes('---') &&
           !/^\|\s*(ID|Name)\s*\|/.test(t); // drop the header row
  });
}
