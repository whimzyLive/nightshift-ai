---
id: grep-i-defeats-uppercase-literal-detection
agent: [ai-enablement-engineer]
trigger: [regex uses [A-Z] to detect a genuinely-uppercase literal, grep -qi applied to that regex, false negative from case folding]
rule: A regex using [A-Z] to detect a genuinely-uppercase literal must be matched case-sensitively — grep -qi silently makes [A-Z] match lowercase too, defeating the check.
evidence: [NA-78]
uses: 0
status: active
---

## Why

Widening `no-hardcoded-project-key.test.sh`'s Case 2 `literal_default_re` to also catch the phrase
"fall back to ET" added the literal words "fall back to" as a trigger — which is a substring of
the paragraph's own legitimate, required text ("do not fall back to any literal project key"). Under
`grep -qiE` (case-insensitive, matching the sibling `no_fallback_re` check), the class `[A-Z]{2,10}`
stopped meaning "uppercase" and matched the following lowercase word "any" too, so the guard's own
required paragraph tripped its own forbidden-fallback detector. Fix: match `literal_default_re` with
plain `grep -qE` (case-sensitive) — `[A-Z]` only means what it says without `-i`.
