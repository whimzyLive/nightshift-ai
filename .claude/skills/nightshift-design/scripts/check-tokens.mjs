#!/usr/bin/env node
/* Token-drift gate.
 * tokens/colors.css is the single source of truth. Every hex that appears in
 * the agent-facing docs (and in _ds_manifest.json) must trace back to it.
 * Any hex with no canonical token = drift or typo = fail. */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const hexes = s => (s.match(/#[0-9a-fA-F]{6}\b/g) || []).map(h => h.toLowerCase());

const css = readFileSync(join(root, 'tokens/colors.css'), 'utf8');
const canonical = new Set(hexes(css));

let fail = 0;

// 1. manifest mirror must match the CSS
const manifest = JSON.parse(readFileSync(join(root, '_ds_manifest.json'), 'utf8'));
for (const t of (manifest.tokens || [])) {
  if (t.kind === 'color' && /^#[0-9a-fA-F]{6}$/.test(t.value) && !canonical.has(t.value.toLowerCase())) {
    console.error(`✗ _ds_manifest.json: ${t.name}=${t.value} not in tokens/colors.css`);
    fail++;
  }
}

// 2. every hex quoted in the docs must exist as a real token
const docs = [
  'SKILL.md', 'README.md',
  'references/tokens.md', 'references/components.md', 'references/patterns.md',
];
for (const f of docs) {
  let txt;
  try { txt = readFileSync(join(root, f), 'utf8'); } catch { continue; }
  for (const h of new Set(hexes(txt))) {
    if (!canonical.has(h)) {
      console.error(`✗ ${f}: hex ${h} has no token in tokens/colors.css (drift or typo)`);
      fail++;
    }
  }
}

if (fail) { console.error(`\n${fail} token-drift violation(s).`); process.exit(1); }
console.log('✓ tokens: every doc/manifest hex traces to tokens/colors.css');
