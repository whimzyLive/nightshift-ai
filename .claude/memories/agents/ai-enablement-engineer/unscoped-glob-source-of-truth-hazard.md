---
id: unscoped-glob-source-of-truth-hazard
agent: [ai-enablement-engineer]
trigger: [bare **/SKILL.md glob, agents/** glob could match nx-generated mirror dir, hooks-contract reading local settings]
rule: Every `auto` reference-doc row's source-of-truth must be explicitly scoped to `plugins/{sdlc,gtm}/**` only.
evidence: [PR#157]
uses: 0
status: active
---
