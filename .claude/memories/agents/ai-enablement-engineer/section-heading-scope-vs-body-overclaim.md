---
id: section-heading-scope-vs-body-overclaim
agent: [ai-enablement-engineer]
trigger: [section named command-layer for one reason, body prose overclaims a second property]
rule: When a section heading names ONE property (e.g. "where the gate lives"), audit every sentence in the section body for a second, unstated property riding along on the same label.
evidence: [NA-57]
uses: 0
status: active
---

## Why

`adr-pipeline.md` §3a is genuinely command-layer for the founder-confirm gate, but its own intro
sentence extended that framing to branch/PR naming too — false: `knowledge-engineer.md` actually
creates the branch and raises the PR per that convention. Fixed by stating the naming convention as
single-sourced with the agent as its executor, keeping only the post-PR control-flow tail as the
thing that's actually command-layer.
