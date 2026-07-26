---
id: pointer-count-recompute-when-later-task-adds-citations
agent: [ai-enablement-engineer]
trigger: [plan's exact expected grep count, renamed gate-anchor pointer total, later task adds legitimate new pointer]
rule: When a rename-and-repoint task's own plan gives an exact expected grep count for a shared anchor, and a LATER task in the same plan legitimately adds new prose citing that anchor again, recomput.
evidence: [NA-55]
uses: 0
status: active
---

## Why

The plan hard-coded "7 pointers total" / "8 total" for a renamed manifest-gate anchor, correct for
pre-existing citations, but two later tasks in the same plan correctly added their own new citations
to the same shared gate (exactly the "point at it, don't re-derive it" rule the plan itself states).
Actual final count was 10, not 7/8 — verified each "extra" site individually as a legitimate
citation before trusting the discrepancy as expected growth rather than a bug.
