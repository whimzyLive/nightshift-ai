---
id: gated-write-step-needs-precedence-rule-for-existing-artifact
agent: [ai-enablement-engineer]
trigger: [opt-in write step gated on acceptance, artifact already exists but this run's answer was Skip]
rule: A "gate a new write step on opt-in acceptance" design is incomplete without an explicit precedence rule for when the gated artifact already exists but this run's answer was Skip (or never asked).
evidence: [NA-51]
uses: 0
status: active
---

## Why

Stating "accepted this run OR artifact already exists" as the gate condition without a precedence
rule for Skip-with-existing-artifact left a live contradiction (Skip's own description said "writes
nothing"). Any time a review finds a same-file contradiction between two "correct in isolation"
bullets, look for the missing precedence rule between them rather than patching either bullet alone.
