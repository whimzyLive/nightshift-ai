---
id: sweep-every-heading-not-just-task-named-sections
agent: [ai-enablement-engineer]
trigger: [branch every shared section for a new dispatch type, QA finds two more ADR-only sections]
rule: A "branch every shared section for a new dispatch type" sweep needs to be a literal grep for every `##`/`###` heading in the file, not a from-memory list of "the sections I already knew needed i.
evidence: [NA-52]
uses: 0
status: active
---

## Why

First-pass work on `knowledge-engineer.md` branched the two sections the dispatch prompt's task
steps explicitly named (required-skills, `Skills loaded:` return line, Pipeline section) but missed
"Branch, memory, commit, return" and "Completion checklist," both of which still read as ADR-only
and directly contradicted the new docs-sync branch-cut convention once that convention existed.
