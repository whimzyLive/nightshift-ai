---
id: branch-inventory-assert-keyword-inflates-outcomes-on-flat-checklist
agent: [ai-enablement-engineer]
trigger: [pseudocoding a flat non-branching checklist, branch-inventory.sh OUTCOMES_MATCH, ASSERT keyword count mismatch]
rule: Pseudocoding a flat checklist with literal `ASSERT` per item adds one counted outcome per item in branch-inventory.sh — use a `:=`/`->` list instead when the task needs `OUTCOMES_MATCH=true`.
evidence: [NA-87]
uses: 0
status: active
---

## Why

`branch-inventory.sh`'s `count_outcomes` counts literal occurrences of `ASSERT`, `;;`, leading
`if/elif/else`, `STOP`/`blocked`, and in-fence table rows as a step-outcome proxy. A checklist
originally written as plain `- [ ]` bullets contributes zero to that count. Converting each bullet
to `ASSERT <condition>` is faithful pseudocode but adds N new counted outcomes where N is the
bullet count, since the base file had none — tripping `OUTCOMES_MATCH=false` even though no
content was gained or lost. A `gate := [...]` / `self_review := [...]` list, or a small number of
`->` outcome lines, encodes the same assertions without the keyword-count side effect. Only use
literal `ASSERT` per item when a task explicitly calls for "ASSERT-form guards" and is not gated
on `branch-inventory.sh` staying unchanged for that file.
