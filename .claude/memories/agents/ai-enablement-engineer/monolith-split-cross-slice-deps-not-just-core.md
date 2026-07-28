---
id: monolith-split-cross-slice-deps-not-just-core
agent: [ai-enablement-engineer]
trigger: [splitting a monolithic reference file into section-scoped slices, verifying slice self-sufficiency, mechanical file split with preserved section numbers]
rule: When splitting a monolith ref file into slices, audit cross-refs — a non-core slice can depend on a different non-core slice; qualify pointers with the filename, report it, don't duplicate.
evidence: [NA-79]
uses: 0
status: active
---

## Why

Splitting `docs-pipeline.md` (§1–26) into five files on its existing section boundaries surfaced
three pre-existing cross-references that the pre-split monolith's single-file shape had been
hiding: `docs-pipeline-audit.md` (§20–24) cited `release`'s §13 and `seed`'s §18 for its
local-branch precondition shape; `docs-pipeline-postqa.md` (§25–26) cited `release`'s §10 for the
story-key regex; and `docs-pipeline-core.md` itself (§1–9, `sync`'s own home) cited the
merged-commit diff-source selection rule that only lives in `docs-pipeline-postqa.md` §26. None of
these were introduced by the split — they were real, load-bearing prose dependencies the monolith's
single-file shape made free to write and easy to miss auditing. Each was fixed by qualifying the
in-prose pointer with its target slice's filename (never a bare "§N") and flagged in the
destination slice's own header as an inherited cross-mode dependency, rather than copying the
referenced rule's text into the dependent slice (which would create two sources of truth for the
same rule).
