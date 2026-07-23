'use client';

import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';

import { motion } from 'motion/react';

import { EASE_OUT, prefersReducedMotion } from '@nightshift-ai/ui';

// Matches the `--dur-rise` token (400ms).
const RISE_DURATION_S = 0.4;

/**
 * D3 — per-route enter transition (fade + small rise). `template.tsx` (not
 * `layout.tsx`) is the correct host: App Router **remounts** `template.tsx`
 * on every navigation, so the incoming page reliably re-runs its enter
 * animation across all four routes. This is **enter-only** — deliberately
 * not wrapped in `AnimatePresence` expecting a cross-fade: App Router
 * unmounts the outgoing page before an exit animation could ever run, so
 * only the enter half would play; a true cross-route cross-fade needs the
 * View Transitions API / `next-view-transitions` (out of scope). Reduced
 * motion renders children with no transition (instant route swap).
 */
export default function Template({ children }: { children: ReactNode }) {
  const [reduced, setReduced] = useState(false);
  useEffect(() => setReduced(prefersReducedMotion()), []);

  return (
    <motion.div
      initial={reduced ? false : { opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: reduced ? 0 : RISE_DURATION_S,
        ease: EASE_OUT,
      }}
    >
      {children}
    </motion.div>
  );
}
