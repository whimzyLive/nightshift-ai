---
id: bash32-case-inside-command-substitution-corrupts-parse
agent: [ai-enablement-engineer]
trigger: [writing a bash test helper with case inside $(...), unexplained syntax error near a case pattern inside a subshell, portable shell script targeting macOS bash]
rule: Never nest a `case`/`esac` inside `$(...)`  — bash 3.2 (macOS's shipped /bin/bash) can misparse a case-arm's closing `)` as ending the substitution. Use a real `( ... ) > file` subshell instead.
evidence: [e02d9a1b06]
uses: 0
status: active
---

## Why

`result="$( ... case "$x" in *'pattern')* echo ok ;; esac )"` produced "syntax error near
unexpected token `newline'" pointing at the case-arm's own pattern line, with statements before
the case appearing to execute out of order in `bash -x`traces.`bash -n`(static syntax check)
reported the file as valid — the corruption is a bash-3.2-specific runtime scanning defect in`$(...)`'s legacy paren-matching, not a real syntax error, and only reproduces on that shell
(confirmed via `bash --version`: 3.2.57, macOS's Apple-licensed ceiling). Fix: redirect a real
`( ... )` subshell to a temp file and read the file back, instead of wrapping the case statement
in `$(...)`.
