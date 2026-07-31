---
id: branch-inventory-mismatch-expected-on-deliberate-relocation
agent: [ai-enablement-engineer]
trigger: ['branch-inventory.sh OUTCOMES_MATCH=false', 'ref split moves content to a sibling file', 'extracting bash into a new script', 'AC-7 gate on an A2/A3-converted file']
rule: When branch-inventory.sh reports OUTCOMES_MATCH=false because content was deliberately relocated (not edited) to a sibling ref file or a new script, reconcile by summing the same outcome-class metric (decision-table rows, then if/elif/case lines) across every destination and require an exact match on at least one high-signal subclass before treating the mismatch as safe.
evidence: [NA-86]
uses: 0
status: active
---

## Why

`branch-inventory.sh` counts outcomes per single file path, so any split that moves a decision
table, if/elif chain, or STOP/blocked prose line out of (or into) a file guarantees a same-file
mismatch even when nothing was actually lost — the tool has no cross-file view. Eyeballing the
before/after prose to "look about right" is not a defensible reconciliation. Recompute the SAME
counting rule (decision-table rows are the highest-signal subclass, since they're least ambiguous)
summed across the base file plus every file/script the content moved to, and require it to equal
the base count exactly. An exact match on that one subclass, plus preserved-or-increased counts on
`if`/`elif`/`case` and `STOP`/`blocked` prose lines, is strong, writable-into-the-PR-body evidence
that the split lost nothing — per the tool's own escalation rule, this manual reconciliation is
authoritative over the raw per-file numbers.
