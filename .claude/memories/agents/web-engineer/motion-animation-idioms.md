---
id: motion-animation-idioms
agent: [web-engineer]
trigger: [continuous decorative loop migration, one-shot entrance keyframes, repeated entrance props across call sites]
rule: "For a continuous decorative Motion loop, pass a shared object to `animate` with `transition={{ repeat: Infinity }}`, swapped to `undefined` under reduced motion as Motion's simplest off-switch."
evidence: [e165158]
uses: 0
status: active
---
