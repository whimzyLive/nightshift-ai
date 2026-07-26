---
id: check-shared-component-source-before-trusting-plan-jsx-snippet
agent: [web-engineer]
trigger: [Eyebrow component prepends its own glyph, plan's inline JSX writes the glyph again]
rule: A shared wrapper component (e.g. `Eyebrow` in `packages/ui`) may already prepend its own chrome (a mono `//` glyph).
evidence: [NA-34]
uses: 0
status: active
---
