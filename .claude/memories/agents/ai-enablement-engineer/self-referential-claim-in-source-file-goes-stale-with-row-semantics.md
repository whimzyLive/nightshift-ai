---
id: self-referential-claim-in-source-file-goes-stale-with-row-semantics
agent: [ai-enablement-engineer]
trigger: [command file's self-referential claim about its own doc-type row, generation-mode semantics change]
rule: When changing a doc-type row's generation-mode semantics (e.g. mirror → transform), grep every GOVERNING file (not just the two primary spec files) for the doc-type name being changed.
evidence: [PR#154]
uses: 0
status: active
---
