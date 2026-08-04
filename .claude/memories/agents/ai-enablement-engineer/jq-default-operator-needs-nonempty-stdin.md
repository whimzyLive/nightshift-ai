---
id: jq-default-operator-needs-nonempty-stdin
agent: [ai-enablement-engineer]
trigger: [testing a PreToolUse hook passthrough path, jq -r default operator on hook stdout, bash hook test asserting "(none)"]
rule: A hook that emits nothing on passthrough breaks `jq -r '... // "default"'` — empty stdin yields zero output lines, not the default. Normalise empty stdout to a valid JSON value first.
evidence: [NA-89]
uses: 1
status: active
---

## Why

`.claude/hooks/rtk-line-scan.sh` emits nothing (exit 0, empty stdout) on every passthrough case,
per spec ("emit nothing, exit 0"). Piping that empty stdout straight into
`jq -r '.hookSpecificOutput.updatedInput.command // "(none)"'` does not trigger the `//` default —
jq processes zero JSON values from empty input, so it also produces zero lines of output, and the
test's command substitution captures `""`, not `"(none)"`. Every assertion built this way failed
even though the hook was behaving exactly as intended. Fix: wrap the hook invocation in a helper
that substitutes `{}` for empty stdout before any downstream `jq` filter runs.
