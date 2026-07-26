---
id: redispatch-verify-only-must-be-exempted-from-zero-commit-stop
agent: [ai-enablement-engineer]
trigger: [STOP-and-redispatch on Skills-loaded failure, zero new commits since pre-dispatch HEAD]
rule: A "STOP-and-redispatch on Skills-loaded failure" rule silently collides with a sibling "zero new commits = silent failure" rule when the redispatch only needs to verify already-committed work an.
evidence: [NA-26]
uses: 0
status: active
---
