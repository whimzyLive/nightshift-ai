'use client';

import { motion } from 'motion/react';

import { EASE_OUT } from './motion-tokens';

// Matches the `--dur-slow` token (360ms).
const DRAW_DURATION_S = 0.36;

export interface GateCheckProps {
  /** Square SVG box size in px. Default: 16. */
  size?: number;
  /** Stroke colour. Default: `var(--success)`. */
  color?: string;
  /**
   * Parent's already-latched `prefers-reduced-motion` state — GateCheck
   * takes this as a prop rather than reading `prefersReducedMotion()` itself
   * so both call sites (ControlSection, ArgumentRail) keep a single latch
   * read per component tree.
   */
  reduced?: boolean;
  className?: string;
  /**
   * Accessible label. When set, the SVG exposes `role="img"` with this
   * label instead of `aria-hidden`, so assistive tech announces the passed
   * state the glyph it replaces used to convey as plain text.
   */
  label?: string;
}

/**
 * Shared inline check-mark SVG that draws itself in (`pathLength` 0 → 1)
 * when it mounts — i.e. the moment a gate transitions to passed, since both
 * call sites only render `GateCheck` conditionally on that state. Renders
 * fully drawn immediately under reduced motion. `pathLength` animates
 * `stroke-dashoffset` — GPU-safe, no layout; the SVG box is fixed-size in
 * place of the plain glyph it replaces, so CLS stays 0.
 */
export function GateCheck({
  size = 16,
  color = 'var(--success)',
  reduced = false,
  className = '',
  label,
}: GateCheckProps) {
  return (
    <motion.svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      aria-hidden={label ? undefined : true}
      role={label ? 'img' : undefined}
      aria-label={label}
      className={className}
    >
      <motion.path
        d="M5 13l4.2 4.2L19 7"
        stroke={color}
        strokeWidth={2.5}
        strokeLinecap="round"
        strokeLinejoin="round"
        initial={reduced ? false : { pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={
          reduced
            ? { duration: 0 }
            : { duration: DRAW_DURATION_S, ease: EASE_OUT }
        }
      />
    </motion.svg>
  );
}
