'use client';

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';

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
 * Client context island owning the `{ reached, active }` gate-rail state
 * shared by the argument rail, the sticky visual pane, and the CTA kicker
 * (see spec Open Question 1). Wraps a passive scroll/resize listener over
 * the five `[data-why-sec]` nodes, ported from the design handoff's own
 * `_setup`/`renderVals` script (why-sdlc.dc.html L315-348).
 *
 * A section counts as passed once its top crosses 70% of the viewport
 * height (the last section sets `reached` to the full section count);
 * `reached` only ever increases so a fast/jump scroll never un-lights a
 * passed gate. `active` is the highest-indexed section whose top has
 * crossed 50% of the viewport height. Under prefers-reduced-motion,
 * `reached` initialises to 5 immediately and no listeners are attached.
 */
export function ScrollProgressProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<ScrollProgressState>(INITIAL_STATE);

  useEffect(() => {
    if (prefersReducedMotion()) {
      setState({ reached: 5, active: 0 });
      return;
    }

    const onScroll = () => {
      const sections = Array.from(
        document.querySelectorAll<HTMLElement>('[data-why-sec]'),
      );
      if (sections.length === 0) return;

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

      setState((prev) => ({
        reached: Math.max(prev.reached, reached),
        active,
      }));
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll, { passive: true });
    onScroll();

    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
    };
  }, []);

  return (
    <ScrollProgressContext.Provider value={state}>
      {children}
    </ScrollProgressContext.Provider>
  );
}
