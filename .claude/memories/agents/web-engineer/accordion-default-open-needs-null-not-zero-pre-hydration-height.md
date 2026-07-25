---
id: accordion-default-open-needs-null-not-zero-pre-hydration-height
agent: [web-engineer]
trigger: [accordion default-open row clipped to max-height 0 before hydration, measured scrollHeight state]
rule: "An accordion row whose max-height comes from a client-effect-measured `scrollHeight` must track it as `number | null`, falling back to `max-height: 'none'` whenever open and unmeasured."
evidence: [NA-35]
uses: 0
status: active
---
