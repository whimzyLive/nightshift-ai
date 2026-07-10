import { execFileSync } from 'node:child_process';
import path from 'node:path';

describe('design-system token parity', () => {
  it('vendored tokens match the canonical skill source', () => {
    const script = path.resolve(__dirname, '../../scripts/check-tokens.mjs');
    expect(() =>
      execFileSync('node', [script], { stdio: 'pipe' }),
    ).not.toThrow();
  });
});
