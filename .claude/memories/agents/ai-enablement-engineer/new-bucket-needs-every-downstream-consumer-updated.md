---
id: new-bucket-needs-every-downstream-consumer-updated
agent: [ai-enablement-engineer]
trigger: [adding a new outcome/bucket/branch to a classification table, a report-line enum template consumed by another step, one step produces a value another step's template must also accept]
rule: Adding a bucket to a classification table isn't done until every downstream consumer of its output vocabulary is updated too — grep for the value the bucket emits, not just the table.
evidence: [NA-79]
uses: 0
status: active
---

## Why

NA-79's Step 6.5 change-size gate added a fifth outcome bucket and its own mandated `Docs sync:`
report string, but Step 8's report contract — read by the same inline orchestrator, a few hundred
lines later in the same playbook file — still enumerated only four options and still said "the two
no-op-or-success paths." An orchestrator following Step 8 literally had no valid token for the new
bucket and would have picked the nearest wrong one (`skipped (no docs manifest)`), mislabeling a
healthy skip as an opt-out. Caught by code review, not by the original author. The fix pattern:
after adding a new classification bucket, grep the whole file (or plugin) for the enum/template
that renders that classification's output — a table row alone is not the contract; every place that
consumes the table's vocabulary is.
