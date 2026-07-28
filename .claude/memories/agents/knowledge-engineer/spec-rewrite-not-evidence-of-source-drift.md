---
id: spec-rewrite-not-evidence-of-source-drift
agent: [knowledge-engineer]
trigger: [pipeline spec rewrite between audit runs, re-derive resolved source content, audit re-run]
rule: "When a pipeline spec is heavily rewritten between audit runs, check whether the rewrite actually changed a row's resolved source content before assuming a re-regen is needed."
evidence: [PR#155, NA-79]
uses: 1
status: active
---

## Why

NA-65 landed a large spec rewrite (`doc-types.md`/`docs-manifest-template.md`/`docs-pipeline.md`,
hundreds of lines) between two audit runs, but zero bytes changed under any `auto` row's actual
source-of-truth (`plugins/{sdlc,gtm}/{commands,agents,skills,hooks}/**`). A spec rewrite is not
itself evidence of drift — always check whether the rewrite changed a row's resolved source content
before assuming a re-regen is needed.
