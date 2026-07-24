'use client';

import { AnimatePresence, motion } from 'motion/react';

import { EASE_OUT } from './motion-tokens';
import { useInViewOnce } from './use-in-view-once';

export interface RollingNumberProps {
  /** Target integer to roll to. */
  value: number;
  /** Rendered before the digits (e.g. ''). Default: ''. */
  prefix?: string;
  /** Rendered after the digits (e.g. ' seconds'). Default: ''. */
  suffix?: string;
  className?: string;
}

// Matches the `--dur-base` token (200ms).
const DIGIT_TRANSITION = { duration: 0.2, ease: EASE_OUT };

function Digit({
  finalChar,
  revealed,
}: {
  finalChar: string;
  revealed: boolean;
}) {
  return (
    <span
      className="inline-block overflow-hidden text-center align-bottom"
      style={{ width: '1ch' }}
    >
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.span
          key={revealed ? finalChar : 'placeholder'}
          className="block"
          initial={{ y: 16, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -16, opacity: 0 }}
          transition={DIGIT_TRANSITION}
        >
          {revealed ? finalChar : '0'}
        </motion.span>
      </AnimatePresence>
    </span>
  );
}

/**
 * Rolls each digit of `value` into place, one column at a time, the first
 * time the element scrolls into view — a per-digit `AnimatePresence`
 * vertical slide rather than `CountUp`'s continuous numeric tween. Viewport
 * trigger and the reduced-motion / no-`IntersectionObserver` degrade both
 * come from the shared {@link useInViewOnce} hook, not re-implemented here.
 * Under that degrade path, renders the final digits immediately with no
 * roll. Each digit column reserves its own fixed `1ch` width — CLS = 0.
 */
export function RollingNumber({
  value,
  prefix = '',
  suffix = '',
  className = '',
}: RollingNumberProps) {
  const { ref, inView, immediate } = useInViewOnce<HTMLSpanElement>({
    threshold: 0.3,
  });

  if (immediate) {
    return (
      <span ref={ref} className={className}>
        {prefix}
        {value}
        {suffix}
      </span>
    );
  }

  const chars = String(value).split('');

  return (
    <span ref={ref} className={className}>
      {prefix}
      {chars.map((char, i) => (
        <Digit key={i} finalChar={char} revealed={inView} />
      ))}
      {suffix}
    </span>
  );
}
