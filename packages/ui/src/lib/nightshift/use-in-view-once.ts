'use client';

import { useEffect, useRef, useState } from 'react';
import type { RefObject } from 'react';

import { prefersReducedMotion } from './prefers-reduced-motion';

export interface UseInViewOnceResult<T extends Element> {
  /** Attach to the element whose viewport entry should trigger the reveal. */
  ref: RefObject<T | null>;
  /** True once the element has entered the viewport (or immediately under the degrade path below). */
  inView: boolean;
  /**
   * True when `inView` was set without a real viewport entry — reduced
   * motion or an unsupported `IntersectionObserver`. Consumers should skip
   * any entrance animation and render their final state immediately.
   */
  immediate: boolean;
}

/**
 * Shared viewport-once trigger: fires `inView` true exactly once, the first
 * time the ref'd element enters the viewport. Under `prefers-reduced-motion`
 * or when `IntersectionObserver` is unsupported, `inView` (and `immediate`)
 * are `true` from the first post-mount effect — consumers render their final
 * state right away instead of animating. Single source of this guard so
 * per-component viewport-trigger primitives (`CountUp`, `RollingNumber`,
 * etc.) don't each re-implement it.
 */
export function useInViewOnce<T extends Element = HTMLElement>(
  options?: IntersectionObserverInit,
): UseInViewOnceResult<T> {
  const ref = useRef<T>(null);
  const [inView, setInView] = useState(false);
  const [immediate, setImmediate] = useState(false);
  const fired = useRef(false);

  useEffect(() => {
    const supportsIO =
      typeof window !== 'undefined' &&
      typeof window.IntersectionObserver === 'function';

    if (prefersReducedMotion() || !supportsIO) {
      setImmediate(true);
      setInView(true);
      return;
    }

    const el = ref.current;
    if (!el) return;

    const observer = new window.IntersectionObserver((entries) => {
      if (fired.current) return;
      if (entries.some((entry) => entry.isIntersecting)) {
        fired.current = true;
        setInView(true);
        observer.disconnect();
      }
    }, options);
    observer.observe(el);
    return () => observer.disconnect();
    // Mount-once trigger — deliberately ignores `options` identity churn.
  }, []);

  return { ref, inView, immediate };
}
