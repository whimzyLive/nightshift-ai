---
id: cross-step-exception-needs-breadcrumb-at-both-ends
agent: [ai-enablement-engineer]
trigger: [unconditional loop step, sibling step carves out an exception, cross-step conditional]
rule: When one step's instruction is phrased as an unconditional loop but a sibling step already carves out an exception for the same case, add a short forward-pointing clause at the unconditional step.
evidence: [NA-4]
uses: 0
status: active
---

## Why

A Merge path's own carve-out (only prompt genuinely new items) needs to be visible from the
unconditional "for each channel, prompt..." step too — cross-step conditionals need an explicit
breadcrumb at both ends.
