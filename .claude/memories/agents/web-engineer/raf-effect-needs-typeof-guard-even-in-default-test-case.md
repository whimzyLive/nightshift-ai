---
id: raf-effect-needs-typeof-guard-even-in-default-test-case
agent: [web-engineer]
trigger: [ambient idle-drift effect throws in jsdom, requestAnimationFrame not defined, non-reduced-motion default test]
rule: A reduced-motion self-guard only needs one `matchMedia` check in an effect before wiring listeners.
evidence: [NA-32]
uses: 0
status: active
---
