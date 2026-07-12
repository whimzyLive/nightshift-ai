'use client';

import { useEffect, useRef, useState } from 'react';

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
 * Animates 0 → `value` once, the first time the element scrolls into view.
 * Deterministic server frame renders `0` so hydration matches. Degrades to
 * the final value immediately under reduced motion or when
 * IntersectionObserver is unsupported.
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

    const animate = () => {
      if (started.current) return;
      started.current = true;

      if (typeof window.requestAnimationFrame !== 'function') {
        setDisplay(value);
        return;
      }

      const start = performance.now();
      const step = (now: number) => {
        const progress = Math.min(1, (now - start) / durationMs);
        setDisplay(Math.round(progress * value));
        if (progress < 1) window.requestAnimationFrame(step);
      };
      window.requestAnimationFrame(step);
    };

    const observer = new window.IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          animate();
          observer.disconnect();
        }
      },
      { threshold: 0.3 },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [value, durationMs]);

  return (
    <span ref={ref} className={className}>
      {prefix}
      {display}
      {suffix}
    </span>
  );
}
