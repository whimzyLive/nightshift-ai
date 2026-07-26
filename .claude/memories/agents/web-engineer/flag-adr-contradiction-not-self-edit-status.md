---
id: flag-adr-contradiction-not-self-edit-status
agent: [web-engineer]
trigger: [diff contradicts an accepted ADR's stated convention, docs/adr outside write scope]
rule: "When a story's diff directly reverses conventions codified in an accepted ADR, flag it in the dispatch return rather than hand-editing `docs/adr/**`, outside this agent's ownership."
evidence: [NA-71]
uses: 0
status: active
---
