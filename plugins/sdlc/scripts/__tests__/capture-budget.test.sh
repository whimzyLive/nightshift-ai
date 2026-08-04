#!/usr/bin/env bash
# capture-budget.test.sh — NA-98 / NA-76 budget guard. Asserts the capture contract REPLACED prose
# in the two instruction surfaces rather than adding to them, and that the D8 collection read hands
# over paths, never pasted rule text.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/capture-budget.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
refs="$here/../../refs"
handoff="$refs/domain-agent-handoff.md"
qa="$refs/qa-engineer-playbook.md"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

hb="$(wc -c < "$handoff" | tr -d ' ')"
qb="$(wc -c < "$qa" | tr -d ' ')"
tot=$((hb + qb))
[ "$tot" -le 41214 ] && ok "(B1) combined surfaces $tot <= 41214" \
  || bad "(B1) combined surfaces <= 41214" "actual $tot (handoff=$hb qa=$qb) — NEVER raise this constant"

grep -qF 'git add .claude/memories/' "$qa" \
  && bad "(B2) QA Step 5 no longer stages .claude/memories/" "the git add block survives" \
  || ok "(B2) QA Step 5 no longer stages .claude/memories/"

grep -qF 'capture-learning.sh' "$handoff" \
  && ok "(B3) handoff names capture-learning.sh" || bad "(B3) handoff names capture-learning.sh" "not found"

grep -qE '^[^#]*\.claude/memories/agents/<' "$handoff" \
  && bad "(B4) handoff no longer instructs a direct agents/ write" "a direct write target survives" \
  || ok "(B4) handoff no longer instructs a direct agents/ write"

block="$(grep -F 'list-captured.sh' "$handoff")"
printf '%s' "$block" | grep -qF -- '--story <STORY-KEY>' \
  && ok "(B5a) collection read passes --story" || bad "(B5a) collection read passes --story" "flag missing"
printf '%s' "$block" | grep -qF -- '--agent <your-agent-name>' \
  && ok "(B5b) collection read passes --agent" || bad "(B5b) collection read passes --agent" "flag missing"
grep -qiF 'never paste rule text' "$handoff" \
  && ok "(B5c) path-not-content contract stated" || bad "(B5c) path-not-content contract" "sentence missing"

exit "$fail"
