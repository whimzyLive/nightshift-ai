---
id: new-rule-must-check-existing-instruction-for-textual-overlap
agent: [ai-enablement-engineer]
trigger: [code-comments-policy vs agent Conventions line, new rule narrows an existing standing instruction]
rule: When a new rule you're introducing narrows or reframes an existing standing instruction, check the existing instruction for direct textual overlap with your rule's own Forbidden/Allowed examples.
evidence: [NA-48]
uses: 0
status: active
---

## Why

The story's grounding scoped the "no informative comments" rule narrowly to 3 project override
files, but the identical "informative comment" rule was already copy-pasted 5 times in the generic
`plugins/sdlc/agents/*.md` Conventions lines, explicitly endorsing commenting "a subtle invariant, a
workaround and its reason" — exactly what the new policy's Forbidden list names as informative. The
first-pass reasoning ("aren't in hard conflict") was wrong, caught by review. Fixed by deferring all
5 agent-definition Conventions lines to the policy doc instead of restating/contradicting it.
