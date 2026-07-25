---
id: closed-pr-idempotency-guard-gap
agent: [ai-enablement-engineer]
trigger: [idempotency guard scoped to open PRs only, PR closed without merging, branch name collision]
rule: An idempotency guard scoped to OPEN PRs only is blind to a PR closed WITHOUT merging.
evidence: [NA-7]
uses: 0
status: active
---

## Why

Probing before pushing is cheap and turns a hard push-rejection failure into a handled case. A
different agent/tool might reasonably choose the opposite re-proposal policy — state the choice
explicitly rather than leaving the behavior implicit (chosen here: re-proposing is correct, since
closing without merging doesn't retract the underlying issue).
