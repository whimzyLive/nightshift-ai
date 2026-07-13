'use client';

import { useEffect, useRef, useState } from 'react';
import { animate } from 'motion/react';

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

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

/**
 * Animates 0 → `value` once, the first time the element scrolls into view,
 * using Motion's `animate`. Deterministic server frame renders `0` so
 * hydration matches. Degrades to the final value immediately under reduced
 * motion or when IntersectionObserver is unsupported.
 */
export function CountUp({
  value,
  prefix = '',
  suffix = '',
  durationMs = DEFAULT_DURATION_MS,
  className = '',
}: CountUpProps) {
  const [display, setDisplay] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const started = useRef(false);

  useEffect(() => {
    const supportsIO =
      typeof window !== 'undefined' &&
      typeof window.IntersectionObserver === 'function';

    if (prefersReducedMotion() || !supportsIO) {
      setDisplay(value);
      return;
    }

    const el = ref.current;
    if (!el) return;

    let controls: ReturnType<typeof animate> | null = null;
    const run = () => {
      if (started.current) return;
      started.current = true;
      controls = animate(0, value, {
        duration: durationMs / 1000,
        ease: 'easeOut',
        onUpdate: (v) => setDisplay(Math.round(v)),
      });
    };

    const observer = new window.IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          run();
          observer.disconnect();
        }
      },
      { threshold: 0.3 },
    );
    observer.observe(el);
    return () => {
      observer.disconnect();
      controls?.stop();
    };
  }, [value, durationMs]);

  return (
    <span ref={ref} className={className}>
      {prefix}
      {display}
      {suffix}
    </span>
  );
}
