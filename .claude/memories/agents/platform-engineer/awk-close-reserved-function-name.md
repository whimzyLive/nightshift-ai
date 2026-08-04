---
id: awk-close-reserved-function-name
agent: [platform-engineer]
trigger: [awk local variable name, awk function parameter list, awk syntax error at source line, one-true-awk builtin collision]
rule: When naming an awk function's local variable, never use `close` (or another builtin function name) — nawk/one-true-awk rejects it as a syntax error at the function definition, not the call site.
evidence: [NA-88]
uses: 0
status: active
---

## Why

Adding a `regex_of()` helper to `tools/sdlc-analyser/artifact-contract.sh`'s `compare_awk` with a
local named `close` produced `awk: syntax error ... function is (    result, i, n, close, ...)` on
macOS's shipped `awk` (one-true-awk). The fix was a one-word rename (`closeat`). Worth remembering
because the error points at the whole function signature line, not the offending identifier, so it
reads like a generic parse failure rather than a name collision.
