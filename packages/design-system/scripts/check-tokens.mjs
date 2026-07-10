import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const CANON = path.resolve(
  here,
  '../../../.claude/skills/nightshift-design/tokens',
);
const VENDOR = path.resolve(here, '../src/tokens');
const FILES = [
  'colors.css',
  'fonts.css',
  'typography.css',
  'spacing.css',
  'base.css',
];

// canonical fonts.css currently ships only the Google Fonts @import line and no
// --font-* declarations (loading moved to next/font — see Decided Items). The
// vendored fonts.css legitimately adds --font-sans/--font-mono token declarations
// that don't exist in the canonical file, so it is exempt from the
// missing/extra declaration assertions below. Keep it in FILES so a future
// canonical --font-* addition is still visible if this exemption is removed.
const DECLARATION_EXEMPT = new Set(['fonts.css']);

const decls = (src) =>
  src
    .split('\n')
    .filter((l) => /^\s*--[\w-]+\s*:/.test(l))
    .map((l) => l.trim().replace(/\s+/g, ' '))
    .sort();

let failed = false;
for (const f of FILES) {
  if (DECLARATION_EXEMPT.has(f)) continue;
  const a = decls(readFileSync(path.join(CANON, f), 'utf8'));
  const b = decls(readFileSync(path.join(VENDOR, f), 'utf8'));
  const missing = a.filter((d) => !b.includes(d)); // in canonical, not vendored
  const extra = b.filter((d) => !a.includes(d)); // vendored, not in canonical
  if (missing.length || extra.length) {
    failed = true;
    console.error(`DRIFT in ${f}:`);
    missing.forEach((d) => console.error(`  - canonical only: ${d}`));
    extra.forEach((d) => console.error(`  + vendor only:    ${d}`));
  }
}
if (failed) {
  console.error('Token parity check FAILED.');
  process.exit(1);
}
console.log('Token parity check passed.');
