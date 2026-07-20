---
status: accepted
agents: [web-engineer, qa-engineer]
source-stories: [NA-16, NA-30, NA-32, NA-33, NA-34, NA-35, NA-36]
---

# 0005. Complementary matchMedia conditions for reduced-motion gates

## Status

Accepted

## Decision

We will implement every reduced-motion / animation-preference gate (whether via GSAP's
`matchMedia`, Motion's `animate` prop, or a raw `window.matchMedia` check) so that any
named-condition media-query registration always pairs the target condition with its
logical complement (e.g. `reduceMotion: '(prefers-reduced-motion: reduce)'` paired with
`allowMotion: '(prefers-reduced-motion: no-preference)'`), so the handler is guaranteed
to fire for every user, not just the reduced-motion cohort.

## Context

Client-rendered marketing pages with entrance/ambient animation need to branch
behavior on the user's `prefers-reduced-motion` preference. A third-party animation
library's `matchMedia` helper only invokes its callback when _at least one_ registered
named condition's query actually matches — registering only the reduced-motion
condition means the default "no preference" user (the common case) matches nothing, so
the handler silently never fires and the animation never runs for anyone without an
explicit reduced-motion setting. This shape was shipped as a real, review-caught
Critical defect before the complementary-pairing pattern hardened into every subsequent
motion component in the codebase.

## Alternatives Considered

### Register only the condition actually being branched on (e.g. just `reduceMotion`)

- Pros: less boilerplate, reads as "obviously correct" at a glance.
- Cons: this is the exact shape of the shipped Critical bug — the animation library's
  contract requires at least one condition to match for the handler to fire at all;
  registering one condition alone silently breaks the majority (no-preference) case.

## Consequences

- Test coverage for this shape should mock `window.matchMedia` per query and compute
  `conditions` the way the real library does (any-condition-matches), not just capture
  and manually invoke a handler with a hand-picked object — a mock that fabricates its
  own contract can pass even when the underlying registration bug is present.
- jsdom unit tests are structurally unable to detect an "animation never runs"
  regression of this shape even with a correct per-query `matchMedia` mock in place —
  the mock proves the handler _would_ fire given the right conditions object, not that a
  real browser's `matchMedia` implementation actually invokes it. A real-browser smoke
  test (not just the jsdom unit suite) is required for motion work to catch this class
  of defect before it ships.
- Every future animation/motion component in this codebase follows one settled pattern
  instead of re-deriving matchMedia condition-pairing semantics per component.
- Revisit if the underlying animation library's `matchMedia` contract changes such that
  a handler fires even when zero registered conditions match — at that point
  complement-pairing becomes unnecessary defensive boilerplate rather than a
  correctness requirement.
