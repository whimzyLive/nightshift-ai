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

has "$r/qa-gate-runner.md" 'gate-parallel-design.sh' "gate runner reads the parallel switch by script"
has "$r/qa-gate-runner.md" 'wait "$DESIGN_PID"' "gate runner waits for the backgrounded design check"
has "$r/qa-gate-runner.md" 'gate-design.log' "design check writes its own log"
has "$r/qa-gate-runner.md" 'every command EXCEPT the test command first' "fast checks stay before the combined call"
has "$r/project-context-template.md" '| Gate parallel design check |' "template table carries the parallel row"
has "$r/project-context-template.md" '**Gate parallel design check**' "template documents the parallel row"

has "$r/qa-review-rounds.md" '## Round 1 — design check already red' "rounds ref has the red-design section"
has "$r/qa-review-rounds.md" '`design check: fail — ... report <path>`' "trigger text is the documented hand-back part"
has "$r/qa-review-rounds.md" 'design-check-red.sh' "trigger is confirmed by script"
has "$r/qa-review-rounds.md" 'The gate is NOT dispatched' "round 1 skips the gate"
has "$r/qa-review-rounds.md" 'This round counts as round 1' "skipped-gate round still counts"
has "$r/qa-review-rounds.md" 'A clean exit still needs a passing gate on the final HEAD' "clean still needs a green gate"
has "$r/qa-engineer-playbook.md" 'Round 1 — design check already red' "QA playbook points at the red-design rule"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q

# parallel <tooling rows|NOFILE> <want_rc> <want output>
parallel() {
  local rows="$1" want_rc="$2" want="$3" out rc
  rm -rf "$repo/.claude"
  if [ "$rows" != NOFILE ]; then
    mkdir -p "$repo/.claude/project"
    printf '# Project Context\n\n## Memory\n\n| Token | Value |\n| --- | --- |\n| Gate parallel design check | `off` |\n\n## Tooling\n\n| Token | Value |\n| --- | --- |\n| Test | `t` |\n%b\n' "$rows" > "$repo/.claude/project/project-context.md"
  fi
  out="$(cd "$repo" && CLAUDE_PROJECT_DIR= bash "$plug/scripts/gate-parallel-design.sh" 2>/dev/null)"; rc=$?
  [ "$rc" -eq "$want_rc" ] && [ "$out" = "$want" ] && ok "gate-parallel-design: $4" || bad "gate-parallel-design: $4 (rc=$rc out '$out')"
}
parallel NOFILE 0 "GATE_PARALLEL_DESIGN=on" "no project-context -> on"
parallel '' 0 "GATE_PARALLEL_DESIGN=on" "row absent -> on (an off row in another section is ignored)"
parallel '| Gate parallel design check | `on` |' 0 "GATE_PARALLEL_DESIGN=on" "on -> on"
parallel '| Gate parallel design check | `off` |' 0 "GATE_PARALLEL_DESIGN=off" "off -> off"
parallel '| Gate parallel design check | OFF |' 0 "GATE_PARALLEL_DESIGN=off" "OFF, no backticks -> off"
parallel '| Gate parallel design check |  |' 0 "GATE_PARALLEL_DESIGN=on" "empty value -> on"
parallel '| Gate parallel design check | `maybe` |' 1 "" "invalid value -> exit 1, no output"

# red <report body|NOFILE> <want output on one line> <name>
red() {
  local f="$work/report.txt" out
  if [ "$1" = NOFILE ]; then rm -f "$f"; else printf '%b' "$1" > "$f"; fi
  out="$(bash "$plug/scripts/design-check-red.sh" "$f" | tr '\n' ' ')"; out="${out% }"
  [ "$out" = "$2" ] && ok "design-check-red: $3" || bad "design-check-red: $3 (out '$out')"
}
red 'design-check: fail sha=abc dirty=false\ndocs/design/x/pages/a.html fail NA-1\ndocs/design/x/pages/b.html pass NA-1\n' "DESIGN_RED=yes FAILING=docs/design/x/pages/a.html fail NA-1" "full run, verdict fail"
red 'design-check: partial result=fail sha=abc\ndocs/design/x/pages/a.html fail NA-1\ndocs/design/x/pages/c.html fail NA-2\n' "DESIGN_RED=yes FAILING=docs/design/x/pages/a.html fail NA-1 FAILING=docs/design/x/pages/c.html fail NA-2" "scoped run with result=fail"
red 'design-check: partial sha=abc\ndocs/design/x/pages/a.html pass NA-1\n' "DESIGN_RED=no" "scoped run without a fail result"
red 'design-check: pass sha=abc\n' "DESIGN_RED=no" "pass"
red 'design-check: partial result=pass sha=abc\n' "DESIGN_RED=no" "scoped result=pass"
red 'something else\n' "DESIGN_RED=no" "unparseable line 1"
red NOFILE "DESIGN_RED=no" "missing report"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
