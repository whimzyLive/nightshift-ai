---
id: fix-at-always-loaded-layer-not-by-expanding-skill-loading
agent: [ai-enablement-engineer]
trigger: [rule enforced only by an authoring-time skill, deterministic regen path never loads that skill, audit dispatch skips writing-docs]
rule: 'A rule stated correctly inside one authoring-time skill can still be a live bug against a deterministic regen path that never loads that skill by design — fix at the always-in-effect layer instead.'
evidence: [PR#154]
uses: 0
status: active
---

## Why

The "no em-dash in title/description" rule lived only inside `writing-docs`'s Self-Review checklist;
`audit` never loads it, so 30 `llms.txt` entries broke silently. Moved the rule into
`docs-pipeline.md` §3 (the regen algorithm itself) instead. For any defect reported against
generated output in a "spec prose is the generator" pipeline (no deterministic script backing the
step), trace back to (a) which spec file's prose governs the step, and (b) which dispatch-mode's
skill-loading branch was active — a correct rule in one skill can still be a live bug on a path that
never loads it.
