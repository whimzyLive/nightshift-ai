---
id: plan-next-free-step-letter-can-go-stale
agent: [ai-enablement-engineer]
trigger: [plan names a specific next-free sub-step letter, init.md step lettering]
rule: When a plan names a specific "next free" sub-step letter/number, grep the live file for that exact marker before writing.
evidence: [NA-73]
uses: 0
status: active
---

## Why

NA-73's plan said `commands/init.md` Step 4's next free sub-step letter was `4g`, but by execution
time `4g` was ALSO already taken by a later-landed story. Followed the plan's underlying intent
(find the actual next free letter) rather than its literal letter, since blindly writing a second
`**4g.**` heading would have silently shadowed the existing one.
