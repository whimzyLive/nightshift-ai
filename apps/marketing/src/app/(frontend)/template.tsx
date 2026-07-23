import type { ReactNode } from 'react';

/**
 * D3 — per-route enter transition (opacity fade), replayed by App Router on
 * every navigation via `template.tsx`. CSS-driven (`.ns-route-enter` /
 * `@keyframes ns-route-enter` in `global.css`) rather than a `motion.div` —
 * opacity only, no transform, no JS reduced-motion state.
 */
export default function Template({ children }: { children: ReactNode }) {
  return <div className="ns-route-enter">{children}</div>;
}
