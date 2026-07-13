'use client';

import { useEffect, useState } from 'react';
import { motion, useScroll, useSpring } from 'motion/react';

const SPRING = { stiffness: 120, damping: 30, mass: 0.4 } as const;

/**
 * Thin page-scroll progress bar pinned to the very top of the viewport,
 * filling left→right as the document scrolls — a lightweight "how much is
 * left" indicator shown on every page. Spring-smoothed `scaleX` on a
 * GPU-cheap transform; purely decorative, hidden from assistive tech.
 * Under `prefers-reduced-motion`, binds directly to the raw scroll
 * progress instead of the spring so the bar doesn't animate.
 */
export function ScrollProgress() {
  const { scrollYProgress } = useScroll();
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    setReduced(
      typeof window !== 'undefined' && typeof window.matchMedia === 'function'
        ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
        : false,
    );
  }, []);

  const smooth = useSpring(scrollYProgress, SPRING);
  const scaleX = reduced ? scrollYProgress : smooth;

  return (
    <motion.div
      aria-hidden="true"
      className="pointer-events-none fixed inset-x-0 top-0 z-[100] h-[2px] origin-left"
      style={{
        scaleX,
        background: 'linear-gradient(90deg, var(--accent), var(--indigo-400))',
        boxShadow: '0 0 8px var(--accent)',
      }}
    />
  );
}
