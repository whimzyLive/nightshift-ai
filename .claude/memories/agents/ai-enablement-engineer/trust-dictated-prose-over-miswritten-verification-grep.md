---
id: trust-dictated-prose-over-miswritten-verification-grep
agent: [ai-enablement-engineer]
trigger: [plan's literal verification grep disagrees with plan's own dictated verbatim prose]
rule: When a plan's own dictated prose (spec-derived content) and its own literal verification grep disagree, trust the dictated prose and flag the grep as wrong, rather than rewriting mandated verbat.
evidence: [NA-54]
uses: 0
status: active
---

## Why

A plan asserted `grep -c "docs-pipeline.md` **§§15–19**"`expecting two tokens adjacent, but the same
plan's own dictated sentence had a full independent clause between them — the assertion could never
pass no matter how faithfully the template text was transcribed. Confirmed correctness by grepping
for`§§15` alone at the right location instead of rewriting the correct prose.
