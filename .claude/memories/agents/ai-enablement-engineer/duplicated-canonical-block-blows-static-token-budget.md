---
id: duplicated-canonical-block-blows-static-token-budget
agent: [ai-enablement-engineer]
trigger: [static instruction-load budget, instruction-inventory.sh --base, adding a canonical wire-form block to a playbook prompt contract, D8-style token cap]
rule: When a field-shape block is needed at multiple prompt-contract sites, write it once and cross-reference it elsewhere — restating it per site blows a tight token-delta budget.
evidence: [NA-88]
uses: 0
status: active
---

## Why

NA-88's C3 needed the `LEDGER_*` wire form in the PE Step-4 prompt-contract item, PE Step 5
(computation), PE Step 6 (hand-off), and QA Step 3 (consumption) — writing the full 7-line
commented block in more than one of these pushed `instruction-inventory.sh --base <ref>`'s
`deltaEstTokens` to 1223, over the ≤1,000 budget, even though each individual addition looked
reasonable in isolation. Compressing the non-computing sites down to a one-line cross-reference
(field names inline, "shape computed in Step 5") recovered the budget without dropping any
required token (`LEDGER_AGENT` etc. still had to appear literally for `context-reuse.test.sh`
assertion (c) — a bare mention in prose satisfies a `grep -F` presence check just as well as a
fenced block does).
