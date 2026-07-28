---
id: mock-cli-must-validate-downstream-consumption
agent: [ai-enablement-engineer]
trigger: [mocked CLI regression test, auto-merge-pr.sh test hardening, resolve-then-act mock chain]
rule: When a mock stands in for a multi-step CLI contract (resolve → act), every downstream mock step that consumes the resolved value must also validate it.
evidence: [NA-45, NA-77]
uses: 1
status: active
---

## Why

A mock CLI hardcoding its "resolved" output never exercised the real script's `jq` expression —
deliberately breaking the script's jq (line 67) still left the test PASSING. Fixed by piping a
realistic JSON payload through the REAL `jq` binary with the script's exact expression, plus making
the downstream mock (`gh pr merge`) validate the method arg is one of the real allowed values,
rejecting anything else the way real `gh` does. A reviewer's own prescribed verification step
(temporarily break the real logic, confirm RED, restore, confirm GREEN) is the right adversarial
check to run on your own mock before trusting it — apply it to test infrastructure itself, not just
as an initial-authoring step.
