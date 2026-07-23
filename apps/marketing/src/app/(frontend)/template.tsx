'use client';

import { useState } from 'react';
import type { ReactNode } from 'react';

import { motion } from 'motion/react';

import { EASE_OUT, prefersReducedMotion } from '@nightshift-ai/ui';

// Matches the `--dur-rise` token (400ms).
const RISE_DURATION_S = 0.4;

/**
 * D3 — per-route enter transition (fade + small rise), replayed by App
 * Router on every navigation via `template.tsx`. Enter-only — no
 * `AnimatePresence`/exit half.
 */
export default function Template({ children }: { children: ReactNode }) {
  const [reduced] = useState(() => prefersReducedMotion());

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
