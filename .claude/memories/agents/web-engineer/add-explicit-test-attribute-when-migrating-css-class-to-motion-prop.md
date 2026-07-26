---
id: add-explicit-test-attribute-when-migrating-css-class-to-motion-prop
agent: [web-engineer]
trigger: [test asserted a Tailwind class marker for gating, moving animation to Motion's animate prop drops the class]
rule: When a test's only way to verify an animation is reduced-motion-gated is a Tailwind class marker (`el.querySelector('[class*="motion-safe:animate"]')`), and the component migrates that animation.
evidence: [e165158]
uses: 0
status: active
---
