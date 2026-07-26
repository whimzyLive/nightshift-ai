---
id: config-value-secret-vs-token-classification
agent: [platform-engineer]
trigger: [splitting an env-var-only rule by sensitivity, backend URL vs API key, config token resolution ladder]
rule: 'When a review reclassifies one of two "env-var only" values as a persisted config token, grep the shared blanket-rule token repo-wide and state the new precedence rule everywhere.'
evidence: [NA-3]
uses: 0
status: active
---

## Why

A single "only env-var names, never values" rule applied uniformly to both `POSTIZ_API_URL` and
`POSTIZ_API_KEY` needed independent treatment once split by sensitivity — touched 7 files (refs,
command, agent, README, spec, plan) since the old uniform framing had leaked into schema tables,
error-handling tables, "Decided" bullets, checklist prose, and a downstream agent's own paragraph.
A CLI reading a value from its process env doesn't dictate where that value is _sourced_ from
upstream — don't conflate "the CLI's contract requires an env var" with "the value must be
secret/env-only"; those are separable design choices. When a review says "let the user choose
between two named options at init," model it as an explicit `AskUserQuestion` with exactly those two
labeled options, matching this repo's other init flows' either/or gate pattern.
