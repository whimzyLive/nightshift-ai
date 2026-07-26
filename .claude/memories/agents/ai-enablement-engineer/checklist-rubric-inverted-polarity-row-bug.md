---
id: checklist-rubric-inverted-polarity-row-bug
agent: [ai-enablement-engineer]
trigger: [rubric row phrased as failure condition instead of pass condition, checklist polarity]
rule: When a rubric or checklist-style table states most rows in one polarity ("the PASS condition"), grep the whole table for any row that reads as the opposite ("the FAILURE condition") before shipp.
evidence: [NA-7]
uses: 0
status: active
---

## Why

A 21-PASS-phrased-row rubric had one row (META-4) phrased as the failure condition — the odd-one-out
still read as sensible English in isolation, which is why it's easy to miss in review.
