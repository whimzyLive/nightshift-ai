---
status: accepted
agents: [web-engineer, qa-engineer]
source-stories: [NA-16, NA-30, NA-32, NA-33, NA-34, NA-35, NA-36]
---

# 0006. Post-mount effect resolution of matchMedia reads

## Status

Accepted

## Decision

We will implement every reduced-motion / animation-preference gate so that the actual
`matchMedia` read happens inside a post-mount effect (`useState` + `useEffect`), never
directly in a component's render body, so the deterministic SSR/first-hydration frame
never mismatches the client's real preference.

## Context

Client-rendered marketing pages with entrance/ambient animation need to branch
behavior on the user's `prefers-reduced-motion` preference. Reading `matchMedia`
directly during render (rather than inside an effect) produces different JSX between
the server render (`window` undefined, always resolves false) and the client's first
hydration render (`window` defined, real preference) — a hydration mismatch. This shape
was shipped as a real, review-caught defect before the post-mount-effect pattern
hardened into every subsequent motion component in the codebase.

## Alternatives Considered

### Read matchMedia synchronously in the component body, accept the hydration mismatch

- Pros: avoids the one-JS-tick delay before the real preference applies.
- Cons: produces a genuine SSR/client render mismatch, which React either warns about or
  silently reconciles incorrectly; the established, working alternative (latch via
  effect) has a known, accepted, and far smaller cost (one tick of non-reduced motion on
  a true reduced-motion user's very first paint).

## Consequences

- A true reduced-motion user still experiences one JS tick of non-reduced motion on
  first paint before the effect resolves — an accepted, already-baked-in tradeoff, not
  something this decision introduces.
- Every future animation/motion component in this codebase follows one settled pattern
  instead of re-deriving SSR/hydration-safe matchMedia reads per component.
- Revisit if the codebase's global `prefers-reduced-motion` CSS guard (already present)
  is ever judged sufficient on its own for JS-driven state — it currently is not,
  since it can't stop a `useEffect` from attaching a listener or mutating state in the
  first place.
