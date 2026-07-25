---
id: grep-qx-needs-fixed-string-flag
agent: [ai-enablement-engineer]
trigger: [grep -qx controlled vocabulary token, matching a value against a fixed set]
rule: '`grep -qx "$var"` treats a value as an unanchored-content regex, not a literal string.'
evidence: [NA-73]
uses: 0
status: active
---

## Why

`test.gap` (the `.` matching any char) silently matched the real vocabulary entry `test-gap`, and a
token starting with `-` would have been parsed as a grep option. Fixed with `grep -qxF -- "$token"`.
