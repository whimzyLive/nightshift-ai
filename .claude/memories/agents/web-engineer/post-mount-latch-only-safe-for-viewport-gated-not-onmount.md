---
id: post-mount-latch-only-safe-for-viewport-gated-not-onmount
agent: [web-engineer]
trigger: [reduced-motion post-mount effect latch, animation plays for reduced-motion users on every nav, SSR hydration mismatch]
rule: 'The post-mount effect reduced-motion latch is only safe for a component dormant until a later trigger — an always-live on-mount animation needs a CSS-class approach instead, not a JS latch variant.'
evidence: [NA-69]
uses: 0
status: active
---

## Why

This was a two-round correction: round 1 fixed the "plays for reduced users" symptom with a lazy
`useState` initializer, which round 2's review caught as a NEW hydration-mismatch bug. Generalize:
any new always-live (non-viewport-gated) enter animation in this kit needs the CSS-class form, not
either JS latch variant; the post-mount-effect form remains correct for every dormant-until-triggered
case already in the codebase. When migrating a component to Motion, grep the whole tree for the bare
`const reduced = prefersReducedMotion()` shape called directly in a render body (not inside
`useEffect`) — it's an SSR/hydration risk on every branch it feeds, and the same author pattern
tends to repeat within one PR/kit migration.
