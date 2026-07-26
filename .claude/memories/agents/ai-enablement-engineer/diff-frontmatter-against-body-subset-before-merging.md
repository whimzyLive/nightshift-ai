---
id: diff-frontmatter-against-body-subset-before-merging
agent: [ai-enablement-engineer]
trigger: [merging frontmatter skills into a body Required-skills section, existing section lists only a subset]
rule: Before merging a frontmatter `skills:` list into an agent body's existing "Required skills" section, diff the two explicitly.
evidence: [NA-25]
uses: 0
status: active
---

## Why

Different body-structure families need different merge strategies: a byte-identical shared section
across several agents should be extended in place (not given a second "load FIRST" block above it,
since "merge into an existing section" outranks "place prominently near the top" when the two
conflict); a per-step invocation table (answers WHEN to apply a skill) is orthogonal to a load-first
list (answers WHEN to load it) — keep the table but prepend a numbered load-first list, since this
is a genuine merge of two different questions about the same skill set, not a duplicate.
