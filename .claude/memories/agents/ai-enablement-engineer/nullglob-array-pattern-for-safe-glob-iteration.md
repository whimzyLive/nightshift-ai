---
id: nullglob-array-pattern-for-safe-glob-iteration
agent: [ai-enablement-engineer]
trigger: [bare for f in dir/*.ext idiom, glob vacuously passes on missing/empty directory, check-agent-skill-preloads.sh]
rule: 'Replace the bare `for f in "$dir"/*.ext` idiom with an explicit `[ -d "$dir" ]` check plus `nullglob` + an array, since the bare idiom is silently vacuous on a missing/empty dir.'
evidence: [NA-25]
uses: 0
status: active
---

## Why

A `cd "$dir" && pwd` inside a command substitution with a failed `cd`, under `set -uo pipefail`
(no `-e`), silently makes the resolved dir var an empty string, degrading a subsequent glob to the
repo root or an unexpanded literal — both paths fall through to a false "OK" exit 0. Test both
directions independently in a scratch temp-dir copy (never the real tree): delete the marker line
from one file → guard must fail on marker-missing; re-add the old mechanism to a different file →
guard must fail on that, and both failure classes should be reportable together in one run (two
independent offender-accumulator variables + a shared fail flag), not have the second mask the first.
