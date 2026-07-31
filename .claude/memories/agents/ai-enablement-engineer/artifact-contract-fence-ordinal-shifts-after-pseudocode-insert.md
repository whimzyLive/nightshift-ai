---
id: artifact-contract-fence-ordinal-shifts-after-pseudocode-insert
agent: [ai-enablement-engineer]
trigger: [artifact-contract.sh --fence, re-encoding a section that adds a new pseudocode fence, tier-1 content-contract gate]
rule: Inserting a new fence into a section shifts every later `--fence` ordinal — recompute each via `--extract` against the post-change file before trusting a plan's pre-conversion number.
evidence: [NA-87]
uses: 0
status: active
---

## Why

NA-87's plan pre-computed `--fence` ordinals from the pre-conversion templates. Two of five
target sections (tech-lead.md's plan-format fence, qa-engineer-playbook.md's 5-field/body-schema
fences) each gained a new leading pseudocode fence during the same task, silently shifting the
downstream fence(s) by one position. Running `--extract ... --fence <old-N>` against the
post-change file either returned an empty/wrong item set or picked up the wrong fence entirely.
The fix is mechanical: re-run `--extract` with each candidate ordinal against the file as it
stands right before Task 2.10/2.10-equivalent runs, not the number a plan wrote down earlier in
the same story.
