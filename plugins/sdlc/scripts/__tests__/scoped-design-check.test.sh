#!/usr/bin/env bash
# scoped-design-check.test.sh — the optional `Design check (scoped)` Tooling row, the by-name dispatch rule,
# the fresh-fix-round override read and the deferred Design pass stay in the refs.
#   bash plugins/sdlc/scripts/__tests__/scoped-design-check.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
plug="$here/../.."
r="$plug/refs"
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
has() { grep -qF -- "$2" "$1" && ok "$3" || bad "$3"; }

dr="$r/design-references.md"
has "$dr" 'Design check (scoped) := project-context Tooling row' "design-references defines the scoped row"
has "$dr" "takes the story's Design row board paths" "scoped row takes the story's board paths"
has "$dr" 'never run `Design check`; the QA gate alone runs `Design check`, once per gate' "set: agents never run the full row, gate alone does"
has "$dr" 'unset -> agents run `Design check` as above; nothing else changes' "unset: behaviour unchanged"
has "$dr" '`partial` is never a pass' "partial is never a pass"
has "$dr" 'name the Tooling row, never paste a design-check command' "dispatch names the row, never pastes a command"
has "$dr" 'the row name governs which command runs' "row name governs over Dev Notes"
has "$dr" 'Design check (scoped)` set -> run that row on the story' "domain agent duties use the scoped row"
has "$dr" 'the `Design check (scoped)` row on the story' "fidelity-first uses the scoped row"

has "$r/project-context-template.md" '| Design check (scoped) |' "template table carries the row"
has "$r/project-context-template.md" '**Design check (scoped)**' "template documents the row"
has "$plug/commands/init.md" 'Design check (scoped)' "init never scaffolds the row from a guess"
has "$r/domain-agent-handoff.md" 'never the full one' "handoff points at the scoped row"
has "$r/qa-gate-runner.md" 'never `Design check (scoped)`' "gate runs the full row only"

has "$r/principal-engineer-playbook.md" 'never a pasted command' "PE dispatch rule"
has "$r/qa-engineer-playbook.md" 'never a pasted command' "QA fix-round dispatch rule"
has "$r/qa-engineer-playbook.md" 'FRESH dispatch only' "fresh fix-round reads the override"
has "$r/qa-engineer-playbook.md" '`.claude/project/agents/<agent-name>.md`' "fix-round names the override file"

has "$r/ac-verification.md" 'DESIGN_REPORT' "verifier takes DESIGN_REPORT"
has "$r/ac-verification.md" '`pending gate` := NOT `met`, NOT `unmet`' "pending gate is never unmet"
has "$r/ac-verification.md" 'stale | dirty | `partial` | missing -> `Design <n>: pending gate`' "stale, dirty, partial report is pending gate"
has "$r/qa-review-rounds.md" '`DESIGN_REPORT=defer`' "round dispatches the verifier deferred"
has "$r/qa-review-rounds.md" 'ONE short verifier pass' "round resolves Design lines after the gate"
has "$r/qa-review-rounds.md" 'no Design row | `Design check` unset -> no second pass' "no second pass without a design check"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
