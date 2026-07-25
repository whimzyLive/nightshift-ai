---
id: revert-motion-feature-use-pre-feature-commit-as-reference
agent: [web-engineer]
trigger: [reverting a shipped Motion feature, layoutId morph removal, git show pre-feature-commit]
rule: Reverting an already-shipped Motion feature cleanly is mostly the inverse of the original diff (drop the added props/wrappers/imports, delete panel-only blocks that didn't exist pre-feature).
evidence: [NA-69]
uses: 0
status: active
---
