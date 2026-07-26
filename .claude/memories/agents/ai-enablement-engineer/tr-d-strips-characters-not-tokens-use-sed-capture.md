---
id: tr-d-strips-characters-not-tokens-use-sed-capture
agent: [ai-enablement-engineer]
trigger: [tr -d stripping framing characters, finding ID extraction pipeline, hyphens inside a parsed token]
rule: '`tr -d` deletes every occurrence of each character in its argument set, not just leading/trailing framing.'
evidence: [NA-7]
uses: 0
status: active
---

## Why

Using `tr -d` to strip the `- `, backticks, and space framing a parsed finding ID also stripped
every hyphen inside the ID (already in the delete set for the list-marker separator), silently
turning `readme-missing-h1-keyword` into `readmemissingh1keyword` and breaking every future
idempotency match.
