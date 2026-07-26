---
id: one-source-of-truth-plus-pointers-pattern
agent: [ai-enablement-engineer]
trigger: [shared mechanical rule restated in N places, contradiction between two restatements, Skills-loaded semantics]
rule: 'When a shared mechanical rule is independently restated in multiple files, designate one file as the source of truth and make every other site a one-line pointer, never a full re-derivation.'
evidence: [NA-26, NA-43, NA-52]
uses: 0
status: active
---

## Why

A single Skills-loaded semantic rule was independently restated in up to 5 places; a reviewer
finding a contradiction between two of them isn't fixed by patching just those two — grep every
restatement site (`Skills loaded`, `pass iff`, etc.) across the whole plugin, since a phrase can
drift independently in a site nobody flagged directly. Also: a hardcoded reference to a literal
section-heading string (e.g. "`## Project skills`") breaks the moment a real consumer override
renames that heading for the same concept — describe the section by its ROLE ("the override's
skills section — whatever heading it uses"), not a literal heading string other repos are free to
rename. And: a condensed prose mirror is the right level of fidelity for a file whose own header
already says "playbook is source of truth" — don't duplicate every bash snippet, creating a second
copy to keep in sync.
