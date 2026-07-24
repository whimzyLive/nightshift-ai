// Single canonical export for the post-mount `matchMedia` reduced-motion
// read. Every component that needs to branch on `prefers-reduced-motion`
// calls this instead of re-declaring the same function locally — always from
// inside a post-mount effect (never render body), so the deterministic
// server/first-hydration frame never mismatches the client's real
// preference.
export function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}
