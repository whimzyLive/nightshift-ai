---
id: indented-paragraph-becomes-code-block-vs-siblings
agent: [ai-enablement-engineer]
trigger: [nested list paragraph indentation mismatch, 6-space indent renders as code block]
rule: A paragraph indented 6 spaces where its sibling paragraphs at the same nesting level/parent bullet sit at 2 spaces renders as an indented code block, not continued list-item prose.
evidence: [NA-51]
uses: 0
status: active
---

## Why

This is a silent, unflagged-by-Prettier defect — `proseWrap: preserve` doesn't touch indentation,
and Prettier does not reformat indentation levels within nested list content, so the only way to
catch it is manual comparison against true siblings.
