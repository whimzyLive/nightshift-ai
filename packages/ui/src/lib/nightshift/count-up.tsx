'use client';

import { useEffect, useRef, useState } from 'react';
import { animate } from 'motion/react';

import { useInViewOnce } from './use-in-view-once';

export interface CountUpProps {
  /** Target integer to count to. */
  value: number;
  /** Rendered before the number (e.g. ''). Default: ''. */
  prefix?: string;
  /** Rendered after the number (e.g. ' seconds'). Default: ''. */
  suffix?: string;
  /** Animation duration in ms. Default: ~1200. */
  durationMs?: number;
  className?: string;
}

const DEFAULT_DURATION_MS = 1200;

/**
 * Animates 0 → `value` once, the first time the element scrolls into view,
 * using Motion's `animate`. Deterministic server frame renders `0` so
 * hydration matches. Degrades to the final value immediately under reduced
 * motion or when IntersectionObserver is unsupported — both delivered by the
 * shared {@link useInViewOnce} hook, not re-implemented here.
 */
export function CountUp({
  value,
  prefix = '',
  suffix = '',
  durationMs = DEFAULT_DURATION_MS,
  className = '',
}: CountUpProps) {
  const [display, setDisplay] = useState(0);
  const { ref, inView, immediate } = useInViewOnce<HTMLSpanElement>({
    threshold: 0.3,
  });
  const started = useRef(false);

  useEffect(() => {
    if (!inView || started.current) return;
    started.current = true;

    if (immediate) {
      setDisplay(value);
      return;
    }

    const controls = animate(0, value, {
      duration: durationMs / 1000,
      ease: 'easeOut',
      onUpdate: (v) => setDisplay(Math.round(v)),
    });
    return () => controls.stop();
  }, [inView, immediate, value, durationMs]);

  return (
    <span ref={ref} className={className}>
      {prefix}
      {display}
      {suffix}
    </span>
  );
}
