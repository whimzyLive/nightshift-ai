---
id: detached-head-abbrev-ref-returns-head-not-empty
agent: [ai-enablement-engineer]
trigger: [git rev-parse --abbrev-ref HEAD, detached HEAD guard, branch-name derivation script]
rule: '`git rev-parse --abbrev-ref HEAD` returns the literal string `"HEAD"` for a detached checkout.'
evidence: [NA-27]
uses: 0
status: active
---
