---
id: eval-command-substitution-swallows-exit-status
agent: [ai-enablement-engineer]
trigger: [wiring a new script->eval consumer, eval "$(cmd)" || STOP pattern, checking a script's exit code after eval, script contract with an ERROR= failure key]
rule: When `eval "$(cmd)" || handler` is used, command substitution discards cmd exit status before || sees it - capture stdout, test the status, then eval.
evidence: [NA-81]
uses: 0
status: active
---

## Why

`out=$(bash script.sh …); eval "$out"` and the shorthand `eval "$(bash script.sh …)" || STOP` look
equivalent but are not: `$(...)` runs in a subshell whose own exit status is discarded once command
substitution completes — `||` after `eval "$(...)"` tests **`eval`'s** status (the last assignment
line's, almost always 0), never the child script's. A script contract like `plan-slice.sh`'s
(exit 2 + `ERROR=plan-not-found`, no `SLICE=` key, on failure) becomes silently invisible under the
shorthand form: the caller's `|| STOP` never fires, and a phase gets dispatched with no slice at
all. The correct form captures stdout first, tests `$?` from the capture, and only then `eval`s:
`out=$(cmd); st=$?; [ "$st" -eq 0 ] || handler; eval "$out"`. This is the second distinct `eval`
hazard found on this epic, after the unquoted-value one — see
[[eval-boundary-value-must-be-single-quoted]] — quoting protects the _values_ inside an `eval`
payload; this rule protects the _exit status_ of the command that produced the payload. Both must
hold at every script→`eval` boundary.
