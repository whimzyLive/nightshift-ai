---
id: split-conflated-clauses-when-garbled-not-preserve-wording
agent: [ai-enablement-engineer]
trigger: [review flags a parenthetical as garbled, conflated two distinct concepts into one clause]
rule: When a review flags a parenthetical as "garbled" rather than "wrong," the fix is usually to name the two conflated things separately rather than trying to preserve the original single clause's w.
evidence: [NA-58]
uses: 0
status: active
---

## Why

A parenthetical conflated whether `docs/adr/index.md` exists with whether some other unspecified
"pipeline output" is available — splitting into "check the index if the repo has one" plus an
explicit "skip this check entirely if the repo has no `docs/adr/` directory" was both clearer and a
strict improvement (the original silently had no answer for the no-ADR-pipeline case at all).
