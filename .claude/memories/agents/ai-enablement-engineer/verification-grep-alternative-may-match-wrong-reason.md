---
id: verification-grep-alternative-may-match-wrong-reason
agent: [ai-enablement-engineer]
trigger: [multi-alternative verification grep, disjunctive stub-language check, true-positive for the wrong reason]
rule: When a plan's own multi-alternative verification grep fires, check which alternative matched and whether that alternative's INTENT (not just its literal string) actually applies to the hit befor.
evidence: [NA-55]
uses: 0
status: active
---

## Why

A grep intending to catch a surviving "not yet implemented" stub claim had a third alternative
(a fixed backtick-slash-backtick substring) that also matched a legitimate, correct enumeration line
unrelated to the stub-claim the check exists to catch. Confirmed with a narrower, intent-scoped grep
that zero genuine stale claims survived.
