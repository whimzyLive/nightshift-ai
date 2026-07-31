---
id: ansi-c-quote-for-literal-multiline-fixtures
agent: [ai-enablement-engineer]
trigger: [building a two-line bash test fixture, backslash-continuation test case, command substitution collapses a multi-line string]
rule: When constructing a literal multi-line string for a test fixture, use ANSI-C quoting ($'...\n...') — `$(...)` strips trailing newlines and silently collapses a two-line construction into one line.
evidence: [NA-89]
uses: 1
status: active
---

## Why

`.claude/hooks/__tests__/rtk-line-scan.test.sh`'s G2 case built its continuation fixture as
`"$(printf 'foo \\\n')git status"`. Command substitution strips the trailing newline `printf`
produced, so the two intended lines concatenate into one (`foo \git status`), and the test stopped
exercising the continuation guard entirely — it degenerated into an unrelated single-line check.
The RED failure this produced looked like a guard-logic bug but was a fixture-construction bug.
Building the same string via `$'foo \\\ngit status'` preserves the embedded newline because no
command substitution is involved.
