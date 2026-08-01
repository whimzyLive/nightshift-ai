---
id: eval-boundary-value-must-be-single-quoted
agent: [ai-enablement-engineer]
trigger: [script emits KEY=value for a caller to eval, printf into eval contract, review-derived text crossing an eval boundary, adding a new script->eval call site]
rule: When a script emits KEY=value contract lines a caller consumes via eval, single-quote every value at emission (never bare) - an unquoted multi-word value silently breaks the caller.
evidence: [NA-93, bc40593]
uses: 0
status: active
---

## Why

The pattern `printf 'KEY=%s\n' "$VALUE"`, consumed by a caller's `eval "$(script)"`, is used at
multiple call sites in this plugin and is systemic, not a one-off: `read-review-config.sh:152-154`
emits `REVIEW_AGENT=`/`REVIEW_MODE=`/`REVIEW_GATE=` unquoted (it already hand-strips backticks at
line 127 — evidence someone already hit adjacent breakage); `resolve-ai-workflow-mode.sh:117`
emits `MODE=%s` unquoted, and `MODE=Full Auto` is a **live** bug — under `eval`, only `MODE=Full`
persists (`Auto` runs as a bare command and fails), silently leaving `MODE` empty and dropping the
caller to its human-merge default. Reproduced live: `eval "$(printf 'MODE=%s\n' 'Full Auto')"`
prints `Auto: command not found` and leaves `MODE` unset. `loop-decide.sh` (NA-93) carries
review-derived text into an `eval` alongside live shell state and would have been a third
unquoted site had its `shq()` single-quoting helper not shipped. Before adding a new
script→`eval` contract line, single-quote the value at emission (`'%s'` with `'\''`-escaping for
embedded quotes) and check the existing call sites above rather than assuming they are already
safe.
