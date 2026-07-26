---
id: check-tokens-script-scope-gap-app-source-unchecked
agent: [web-engineer]
trigger: [npm run validate token-drift gate, check-tokens.mjs, custom rgba alpha not caught]
rule: "`.claude/skills/nightshift-design/scripts/check-tokens.mjs` (the `npm run validate` token-drift gate) only scans the skill's own docs/manifest."
evidence: [NA-69]
uses: 0
status: active
---
