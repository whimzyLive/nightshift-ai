---
status: accepted
agents: [web-engineer, qa-engineer]
source-stories: [NA-16, NA-30, NA-32, NA-33, NA-34, NA-35, NA-36]
---

# 0004. Reduced-motion gates must register complementary matchMedia conditions and resolve post-mount

## Status

Accepted

## Decision

We will implement every reduced-motion / animation-preference gate (whether via GSAP's
`matchMedia`, Motion's `animate` prop, or a raw `window.matchMedia` check) so that: (1)
any named-condition media-query registration always pairs the target condition with its
logical complement (e.g. `reduceMotion: '(prefers-reduced-motion: reduce)'` paired with
`allowMotion: '(prefers-reduced-motion: no-preference)'`) so the handler is guaranteed
to fire for every user, not just the reduced-motion cohort; and (2) the actual
`matchMedia` read happens inside a post-mount effect (`useState` + `useEffect`), never
directly in a component's render body, so the deterministic SSR/first-hydration frame
never mismatches the client's real preference.

## Context

Client-rendered marketing pages with entrance/ambient animation need to branch
behavior on the user's `prefers-reduced-motion` preference. Two independent,
genuinely distinct failure modes recur here: a third-party animation library's
`matchMedia` helper only invokes its callback when _at least one_ registered named
condition's query actually matches — registering only the reduced-motion condition
means the default "no preference" user (the common case) matches nothing, so the
handler silently never fires and the animation never runs for anyone without an
explicit reduced-motion setting. Separately, reading `matchMedia` directly during
render (rather than inside an effect) produces different JSX between the server render
(`window` undefined, always resolves false) and the client's first hydration render
(`window` defined, real preference) — a hydration mismatch. Both shapes were shipped
as real, review-caught defects (one flagged Critical) before this pattern hardened
into every subsequent motion component in the codebase.

## Alternatives Considered

### Register only the condition actually being branched on (e.g. just `reduceMotion`)

- Pros: less boilerplate, reads as "obviously correct" at a glance.
- Cons: this is the exact shape of the shipped Critical bug — the animation library's
  contract requires at least one condition to match for the handler to fire at all;
  registering one condition alone silently breaks the majority (no-preference) case.

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
- Test coverage for this shape should mock `window.matchMedia` per query and compute
  `conditions` the way the real library does (any-condition-matches), not just capture
  and manually invoke a handler with a hand-picked object — a mock that fabricates its
  own contract can pass even when the underlying registration bug is present.
- Every future animation/motion component in this codebase follows one settled pattern
  instead of re-deriving matchMedia semantics per component.
- Revisit if the codebase's global `prefers-reduced-motion` CSS guard (already present)
  is ever judged sufficient on its own for JS-driven state — it currently is not,
  since it can't stop a `useEffect` from attaching a listener or mutating state in the
  first place.
