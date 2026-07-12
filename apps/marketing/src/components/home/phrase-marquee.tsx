'use client';

import { useEffect, useState } from 'react';

import { motion } from 'motion/react';

// Verbatim from the design handoff (nightshift Landing.dc.html L190-195) —
// the duplicated-track phrase set. Two copies of the same line let the
// Motion `x: ['0%', '-50%']` loop translate seamlessly.
const PHRASE_LINE =
  'you sleep, it ships ✦ spec before plan ✦ plan before code ✦ review before merge ✦ tests as the gate ✦ a team, not a megaprompt ✦ generic agents, per-repo config ✦ ';

// Matches the retired `--dur-marquee` token (34s).
const MARQUEE_DURATION_S = 34;

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

/**
 * Decorative looping mono ticker dividing Hero from the Proof bar. Purely
 * illustrative — hidden from assistive tech. A single Motion `animate()`
 * loop (`x: ['0%', '-50%']`, linear, infinite) drives the translate; the
 * deterministic server/first-hydration frame renders static (matches the
 * `night-sky.tsx`/`terminal.tsx` pattern), then a direct `matchMedia`
 * check in an effect gates the loop off entirely under reduced motion —
 * checked directly rather than via Motion's `useReducedMotion` so specs
 * that mock `window.matchMedia` are honored (see NA-29 hard rules).
 */
export function PhraseMarquee() {
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => {
    setReducedMotion(prefersReducedMotion());
  }, []);

  return (
    <div
      aria-hidden="true"
      className="relative left-1/2 right-1/2 z-[1] -mx-[50vw] w-screen overflow-hidden border-t"
      style={{
        background: 'var(--surface-terminal)',
        borderColor: 'var(--border-default)',
      }}
    >
      <motion.div
        className="flex w-max"
        animate={reducedMotion ? undefined : { x: ['0%', '-50%'] }}
        transition={
          reducedMotion
            ? undefined
            : {
                duration: MARQUEE_DURATION_S,
                ease: 'linear',
                repeat: Infinity,
              }
        }
      >
        {[0, 1].map((copy) => (
          <span
            key={copy}
            className="font-mono whitespace-pre uppercase"
            style={{
              fontSize: 13,
              letterSpacing: '0.16em',
              color: 'var(--text-dim)',
              padding: '12px 0',
            }}
          >
            {PHRASE_LINE}
          </span>
        ))}
      </motion.div>
    </div>
  );
}
