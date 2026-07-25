---
id: dont-claim-persistence-without-actual-storage
agent: [ai-enablement-engineer]
trigger: ["prompted once" claim, "already declined" wording, decision persistence claim]
rule: Before writing "prompted once" / "already declined" / any claim implying persisted memory of a past answer, verify a concrete field/file/comment convention actually stores that answer between ru.
evidence: [NA-51]
uses: 0
status: active
---

## Why

A "Re-init semantics" bullet implied a decline state is tracked for the opt-in ITSELF, when nothing
in the design persists that (only per-row declines inside an already-existing manifest are
persisted, via a `<!-- declined: <type> -->` comment — a genuinely different, correctly-designed
mechanism that must NOT be touched when fixing this).
