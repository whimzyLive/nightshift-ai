---
id: yaml-colon-space-plain-scalar-hazard
agent: [ai-enablement-engineer]
trigger: [skill frontmatter description YAML, colon followed by space in unquoted scalar, mapping values are not allowed here]
rule: 'A colon immediately followed by a space inside an unquoted YAML plain scalar breaks the parse — validate frontmatter with a real YAML loader, not by eyeballing.'
evidence: [NA-58, NA-61]
uses: 0
status: active
---

## Why

Recurred twice: a description referencing `(https://diataxis.fr/): every document` broke this way
(fixed by rephrasing with an em dash instead); a reviewer's own suggested replacement
(`TODO: one line …`) reintroduced the exact same hazard (fixed with `TODO(fill)` — no colon, no
em-dash). Always validate a reviewer's suggested text against known landmines in this file's
history before adopting it verbatim, not just the original draft.
