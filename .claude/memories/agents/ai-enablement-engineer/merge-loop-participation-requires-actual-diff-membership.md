---
id: merge-loop-participation-requires-actual-diff-membership
agent: [ai-enablement-engineer]
trigger: [prompt claims to participate in Step 0 Merge-new-findings loop, schema-backfill diff step]
rule: A prompt that "participates in a merge/backfill loop" is a false claim unless the field is actually a token that loop's own diff step iterates over.
evidence: [NA-51]
uses: 0
status: active
---

## Why

Step 0's Merge-new-findings loop explicitly diffs against `project-context-template.md`'s
token/section set — a prompt whose write target is a different file is structurally invisible to
that loop no matter how the prose describes it. A cross-reference/description change alone cannot
make an unreachable branch reachable; the field needs its own explicit step that checks the
artifact's existence directly and re-asks the same question.
