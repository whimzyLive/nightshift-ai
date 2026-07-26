---
id: load-first-instruction-must-not-override-earlier-gate
agent: [ai-enablement-engineer]
trigger: [blanket FIRST action instruction, agent already has an earlier step-0 STOP gate]
rule: A blanket "load these FIRST, before any other work" instruction is too strong when the agent body already has an earlier, load-bearing gate (a step-0 branch-verify STOP) that must run first and.
evidence: [NA-25]
uses: 0
status: active
---

## Why

This still satisfies the underlying workaround (skills load in the same first turn that also runs
the pre-flight checks — turn granularity, not instruction ordinality, is what matters) while no
longer overriding a higher-priority STOP gate.
