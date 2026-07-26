---
id: deterministic-check-spec-needs-explicit-step-order
agent: [ai-enablement-engineer]
trigger: [multi-step deterministic check spec, dangling-link check ordering, fragment-strip vs extension test]
rule: For a multi-check spec bullet describing several tests applied to the same input in sequence, number the steps explicitly (or explicitly state a failure-mode example).
evidence: [NA-68]
uses: 0
status: active
---

## Why

Stating the ".md/.mdx extension test" and "fragment is stripped first" as two separate facts in
prose order (without saying which runs first) let a reader legitimately apply the extension test to
the raw target before the fragment strip, silently exempting every fragmented dangling link
(`broken.md#intro`) from the check's own coverage claim. Fixed by making the bullet an explicit
numbered pipeline `(1) strip → (2) classify/skip → (3) extension test → (4) existence check` and
naming the wrong order's failure mode explicitly, not just stating the right order.
