'use client';

import { useEffect, useState } from 'react';
import { motion } from 'motion/react';

import { useScrollProgress } from './scroll-progress';

const ALL_PASSED_COPY =
  '✓ ✓ ✓ ✓ ✓ — all five gates passed. The argument survived your review.';

// Verbatim from the design handoff (why-sdlc.dc.html L403-406, `gateNote`).
function buildAheadCopy(reached: number): string {
  const n = Math.min(reached + 1, 5);
  return `⊘ ${n} of 5 gates ahead — the rail lights as you read`;
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

// Matches the retired `--ease-out` token (cubic-bezier(.22,1,.36,1)).
const EASE_OUT: [number, number, number, number] = [0.22, 1, 0.36, 1];

/**
 * The single kicker line above the page CTA heading. Reads
 * `useScrollProgress()` — shares the same `{ reached }` source of truth as
 * the argument rail's gate glyphs, so the two can never desync. A small
 * Motion reveal (fade + rise) plays once on mount; the color swap between
 * "ahead" (dim) and "all passed" (green) stays a plain CSS transition,
 * since Motion doesn't reliably tween `var(--*)` custom-property colors.
 */
export function CtaKicker() {
  const { reached } = useScrollProgress();
  const allPassed = reached >= 5;
  const [reduced, setReduced] = useState(false);

  useEffect(() => setReduced(prefersReducedMotion()), []);

  return (
    <motion.p
      className="font-mono transition-colors motion-reduce:transition-none"
      initial={reduced ? false : { opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reduced ? 0 : 0.35, ease: EASE_OUT }}
      style={{
        fontSize: 13,
        color: allPassed ? 'var(--green-400)' : 'var(--text-dim)',
        margin: '0 0 16px',
      }}
    >
      {allPassed ? ALL_PASSED_COPY : buildAheadCopy(reached)}
    </motion.p>
  );
}
