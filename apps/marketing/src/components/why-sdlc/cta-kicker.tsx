'use client';

import { useScrollProgress } from './scroll-progress';

const ALL_PASSED_COPY =
  '✓ ✓ ✓ ✓ ✓ — all five gates passed. The argument survived your review.';

// Verbatim from the design handoff (why-sdlc.dc.html L403-406, `gateNote`).
function buildAheadCopy(reached: number): string {
  const n = Math.min(reached + 1, 5);
  return `⊘ ${n} of 5 gates ahead — the rail lights as you read`;
}

/**
 * The single kicker line above the page CTA heading. Reads
 * `useScrollProgress()` — shares the same `{ reached }` source of truth as
 * the argument rail's gate glyphs, so the two can never desync.
 */
export function CtaKicker() {
  const { reached } = useScrollProgress();
  const allPassed = reached >= 5;

  return (
    <p
      className="font-mono transition-colors motion-reduce:transition-none"
      style={{
        fontSize: 13,
        color: allPassed ? 'var(--green-400)' : 'var(--text-dim)',
        margin: '0 0 16px',
      }}
    >
      {allPassed ? ALL_PASSED_COPY : buildAheadCopy(reached)}
    </p>
  );
}
