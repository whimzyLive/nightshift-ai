'use client';

import { useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent, ReactNode } from 'react';

import { motion, useMotionValue, useSpring } from 'motion/react';

import { prefersReducedMotion } from './prefers-reduced-motion';

export interface MagneticCtaProps {
  children: ReactNode;
  className?: string;
}

// Spring config from the AC — exempt from EASE_OUT (spring-driven).
const SPRING_CONFIG = { stiffness: 300, damping: 20 };
// Half the max 4–6px pull amplitude; pointer offset is normalised to -1..1,
// so the resulting translate range is -MAX_PULL_PX..MAX_PULL_PX.
const MAX_PULL_PX = 5;

/**
 * Thin client wrapper that pulls its child (a `CtaButton`) 4–6px toward the
 * pointer on hover, releasing to rest on pointer-leave. Purely presentational
 * — does not touch the wrapped button's own markup, box, or CSS hover/glow
 * treatment. `transform`-only (no layout box change, CLS = 0). Under
 * `prefers-reduced-motion`, renders statically with no pointer-follow — CSS
 * hover states on the child still apply.
 */
export function MagneticCta({ children, className = '' }: MagneticCtaProps) {
  const ref = useRef<HTMLSpanElement>(null);
  const [reduced, setReduced] = useState(false);
  useEffect(() => setReduced(prefersReducedMotion()), []);

  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const springX = useSpring(x, SPRING_CONFIG);
  const springY = useSpring(y, SPRING_CONFIG);

  const handlePointerMove = (event: ReactPointerEvent<HTMLSpanElement>) => {
    if (reduced) return;
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    const px = (event.clientX - rect.left) / rect.width - 0.5;
    const py = (event.clientY - rect.top) / rect.height - 0.5;
    x.set(px * MAX_PULL_PX * 2);
    y.set(py * MAX_PULL_PX * 2);
  };

  const handlePointerLeave = () => {
    x.set(0);
    y.set(0);
  };

  return (
    <motion.span
      ref={ref}
      className={`inline-block ${className}`}
      style={{ x: springX, y: springY }}
      onPointerMove={handlePointerMove}
      onPointerLeave={handlePointerLeave}
    >
      {children}
    </motion.span>
  );
}
