'use client';

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react';

import { useMotionValueEvent, useScroll } from 'motion/react';

export interface ScrollProgressState {
  reached: number;
  active: number;
}

const INITIAL_STATE: ScrollProgressState = { reached: 0, active: 0 };

const ScrollProgressContext = createContext<ScrollProgressState>(INITIAL_STATE);

export function useScrollProgress(): ScrollProgressState {
  return useContext(ScrollProgressContext);
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

/**
 * Recomputes `{ reached, active }` from the five `[data-why-sec]` nodes'
 * viewport position. A section counts as passed once its top crosses 70%
 * of the viewport height (the last section sets `reached` to the full
 * section count); `active` is the highest-indexed section whose top has
 * crossed 50% of the viewport height. Returns `null` when the sections
 * aren't mounted yet (nothing to derive).
 */
function deriveProgress(prevReached: number): ScrollProgressState | null {
  const sections = Array.from(
    document.querySelectorAll<HTMLElement>('[data-why-sec]'),
  );
  if (sections.length === 0) return null;

  const passLimit = window.innerHeight * 0.7;
  const activeLimit = window.innerHeight * 0.5;
  const lastIndex = sections.length - 1;
  let reached = 0;
  let active = 0;

  sections.forEach((sec) => {
    const i = Number(sec.dataset.whySec);
    const top = sec.getBoundingClientRect().top;
    if (top < passLimit) {
      reached = Math.max(reached, i === lastIndex ? sections.length : i);
    }
    if (top < activeLimit) active = i;
  });

  return { reached: Math.max(prevReached, reached), active };
}

/**
 * Client context island owning the `{ reached, active }` gate-rail state
 * shared by the argument rail, the sticky visual pane, and the CTA kicker
 * (see spec Open Question 1). Scroll tracking runs through Motion's
 * `useScroll`/`useMotionValueEvent` (window scroll progress) rather than a
 * hand-rolled `scroll` listener; a plain `resize` listener stays alongside
 * it, since the viewport-height thresholds shift on resize independent of
 * scroll position — something `useScroll` doesn't itself surface.
 *
 * A section counts as passed once its top crosses 70% of the viewport
 * height (the last section sets `reached` to the full section count);
 * `reached` only ever increases so a fast/jump scroll never un-lights a
 * passed gate. `active` is the highest-indexed section whose top has
 * crossed 50% of the viewport height. Under prefers-reduced-motion,
 * `reached` initialises to 5 immediately and the derived-progress path is a
 * no-op — Motion's scroll tracking still exists internally (hooks can't be
 * called conditionally) but never feeds back into state.
 */
export function ScrollProgressProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<ScrollProgressState>(INITIAL_STATE);
  const reducedRef = useRef(false);
  const { scrollY } = useScroll();

  useEffect(() => {
    if (prefersReducedMotion()) {
      reducedRef.current = true;
      setState({ reached: 5, active: 0 });
    }
  }, []);

  useMotionValueEvent(scrollY, 'change', () => {
    if (reducedRef.current) return;
    setState((prev) => deriveProgress(prev.reached) ?? prev);
  });

  useEffect(() => {
    if (reducedRef.current) return;

    const onResize = () => {
      setState((prev) => deriveProgress(prev.reached) ?? prev);
    };

    window.addEventListener('resize', onResize, { passive: true });
    onResize();

    return () => {
      window.removeEventListener('resize', onResize);
    };
  }, []);

  return (
    <ScrollProgressContext.Provider value={state}>
      {children}
    </ScrollProgressContext.Provider>
  );
}
