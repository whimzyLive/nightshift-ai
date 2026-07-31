---
id: dispatch-locked-decisions-outrank-stale-plan-checks
agent: [platform-engineer]
trigger: [plan verify command conflicts with dispatch instruction, locked decision vs plan's stale check]
rule: When a dispatch prompt's "locked decisions" conflict with a plan's own verify command, follow the dispatch instruction and treat the plan's check as stale.
evidence: [NA-3, NA-90]
uses: 1
status: active
---

## Why

NA-3's plan checked `plugin.json` dependencies as flat strings, but the dispatch instruction (and
the only other existing plugin.json in the repo) used an object `{name, marketplace}` shape.
Followed the dispatch instruction and verified with a jq expression matching the real object shape
instead of the plan's stale string-array assumption.
