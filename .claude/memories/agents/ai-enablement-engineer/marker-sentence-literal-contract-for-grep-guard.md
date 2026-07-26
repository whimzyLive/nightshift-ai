---
id: marker-sentence-literal-contract-for-grep-guard
agent: [ai-enablement-engineer]
trigger: [consistent marker string for a machine-checkable guard, grep -F marker across 12 agent files]
rule: When a "consistent marker string" requirement backs a `grep -F` guard, treat the marker sentence as a literal contract, not just matching prose.
evidence: [NA-25]
uses: 0
status: active
---

## Why

Confirmed via a real test loop across all 12 agent files with `grep -qF "$marker" "$f"`, and
confirmed this repo's Prettier `proseWrap: preserve` does not re-wrap long unwrapped lines, so
writing the marker as one long physical line is stable across a real `prettier --write`.
