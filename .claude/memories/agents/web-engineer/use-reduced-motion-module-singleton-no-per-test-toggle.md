---
id: use-reduced-motion-module-singleton-no-per-test-toggle
agent: [web-engineer]
trigger: [Framer Motion useReducedMotion(), night-sky.tsx reduced-motion test, module-level singleton]
rule: Framer Motion's `useReducedMotion()` hook (as opposed to this codebase's own `prefersReducedMotion()` function) is backed by a module-level singleton in `motion-dom`.
evidence: [NA-69]
uses: 0
status: active
---
