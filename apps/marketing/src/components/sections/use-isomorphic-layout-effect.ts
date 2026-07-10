import { useEffect, useLayoutEffect } from 'react';

// useLayoutEffect warns when it runs during SSR (no DOM to measure against);
// fall back to useEffect on the server so GSAP's initial styles/timelines
// apply before paint in the browser, avoiding a flash of the final state.
// Mirrors the hero's established pattern (hero-client.tsx, NA-16).
export const useIsomorphicLayoutEffect =
  typeof window !== 'undefined' ? useLayoutEffect : useEffect;
