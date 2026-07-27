---
id: awk-rs-paragraph-proximity-for-colocation-assertions
agent: [ai-enablement-engineer]
trigger: [tightening a text-presence test into a proximity test, prompt-document regression test, STOP instruction co-located with a token]
rule: When a regression test must prove two phrases are co-located in a prose/prompt document (not just present anywhere in the file), split on blank lines with `awk -v RS=""` and require all phrases match within one paragraph record, instead of a same-line or arbitrary N-line-window heuristic.
evidence: [NA-78]
uses: 0
status: active
---

## Why

A bare `grep -qi A file && grep -qi B file` proves presence-anywhere, which can't tell a
well-placed clause from two unrelated mentions elsewhere in the doc. A same-line or fixed N-line
window is brittle against prose reflow (wrapped sentences span several physical lines). Markdown's
own paragraph boundary (blank line) is the natural unit of "these sentences belong together" and
survives reflow, so `awk -v RS=""` paragraph mode is a more robust proximity check than either
alternative — confirmed by mutation-testing both a deletion (case fails) and a restore (case
passes) against `plugins/sdlc/commands/refine-feature.md`'s STOP clause.
