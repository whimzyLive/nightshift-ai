---
id: latch-reduced-motion-once-in-parent-thread-as-prop
agent: [web-engineer]
trigger: [helper called from a child component reading matchMedia directly, GateNode pulse calc]
rule: 'For a helper called from a child component, latch the reduced-motion boolean once in the parent via the established post-mount-effect pattern and thread it down as an explicit prop.'
evidence: [PR#97]
uses: 0
status: active
---
