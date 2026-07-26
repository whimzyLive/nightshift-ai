---
id: worked-example-alternatives-must-both-be-verified
agent: [ai-enablement-engineer]
trigger: ["X or Y instead" remediation example, spec bullet worked example]
rule: When a spec bullet's own worked example offers "X or Y instead" as alternative fixes for one stated scenario, verify each alternative is actually correct for that SAME input.
evidence: [NA-68]
uses: 0
status: active
---

## Why

"needs `foo.md` or `../foo.md` instead" read as two interchangeable fixes for the same stated
scenario ("a page already inside `docs/`"), but `../foo.md` from a page directly inside `docs/`
resolves to `<repo-root>/foo.md`, itself dangling. Fixed by splitting into two depth-tagged cases
instead of presenting two answers as options for one scenario.
