#!/usr/bin/env bash
# loop-decision-budget.test.sh — NA-93 guard for the loop-decision byte budget and the
# stdout contract.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/loop-decision-budget.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — this guard is authored by the same story that authors the text under test.
# A pass proves the author wrote what the author intended and that every assertion is wired to
# something that can move. Assertions (a)/(b) are a SMOKE TEST. Only (c)/(d)/(e) are real gates,
# and they gate the BUDGET CLAIM, not the decision's correctness — that is loop-decide.test.sh's
# H-Gate-2, against a golden this story's author did not write.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../../.."
plug="$root/plugins/sdlc"
loop="$plug/commands/loop.md"
modes="$plug/refs/loop-modes.md"
qa="$plug/refs/qa-engineer-playbook.md"
pe="$plug/refs/principal-engineer-playbook.md"
handoff="$plug/refs/domain-agent-handoff.md"
decide="$plug/scripts/loop-decide.sh"
fail=0

ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

section_bytes() { awk -v h="$2" '$0==h{f=1} f&&/^## /&&$0!=h{exit} f' "$1" | wc -c | tr -d ' '; }

# --- (a) the script exists and is executable ---------------------------------------
[ -s "$decide" ] && [ -x "$decide" ] && ok "(a) loop-decide.sh exists and is executable" \
  || bad "(a) loop-decide.sh exists and is executable" "missing, empty, or not +x: $decide"

# --- (b) SMOKE: each of the NINE contract keys, ONE KEY PER ASSERTION, parsed out of a
#         REAL invocation's stdout. Never grep the source — a key present in a comment
#         but never emitted would pass, and that is a dead assertion.
out="$(bash "$decide" --from-status 'loop-status: copilot-reviewed-head=1 copilot-changes-requested=0 copilot-pending=0 unresolved-copilot=0 checks-pending=0 checks-failing=0 checks-passing=1 copilot-reviewed-any=1' 2>/dev/null)"
for k in DECISION RULE REVIEW_PATH HEAD UNRESOLVED FIELDS GRACE RE_REQUEST BLOCKED_BY; do
  printf '%s\n' "$out" | grep -q "^${k}=" && ok "(b) stdout carries key $k" \
    || bad "(b) stdout carries key $k" "key absent from a real invocation's stdout"
done

# --- (c) GATE: the fast path's own byte cap ----------------------------------------
lb="$(wc -c < "$loop" | tr -d ' ')"
[ "$lb" -le 13500 ] && ok "(c) commands/loop.md $lb <= 13500" \
  || bad "(c) commands/loop.md <= 13500" "actual $lb — NEVER raise this constant"

# --- (d) GATE: the combined per-pass surface on this repo's claude-inline path ------
mb="$(wc -c < "$modes" | tr -d ' ')"
tot=$((lb + mb))
[ "$tot" -le 27000 ] && ok "(d) loop.md + loop-modes.md $tot <= 27000" \
  || bad "(d) loop.md + loop-modes.md <= 27000" "actual $tot (loop=$lb modes=$mb) — NEVER raise this"

# --- (e) GATE: G's playbook pair is UNCHANGED. Its 318 B of slack is not H's -------
qb="$(wc -c < "$qa" | tr -d ' ')"; pb="$(wc -c < "$pe" | tr -d ' ')"
[ $((qb + pb)) -le 73704 ] && ok "(e) combined playbooks $((qb + pb)) <= 73704" \
  || bad "(e) combined playbooks <= 73704" "actual $((qb + pb)) (qa=$qb pe=$pb)"
cr="$(section_bytes "$handoff" '## Context reuse')"
br="$(section_bytes "$handoff" '## Bounded reads')"
[ "$cr" -eq 868 ]  && ok "(e) ## Context reuse pinned at 868" \
  || bad "(e) ## Context reuse == 868 (NA-88, hard equality)" "actual $cr"
[ "$br" -le 1005 ] && ok "(e) ## Bounded reads <= 1005" \
  || bad "(e) ## Bounded reads <= 1005 (NA-90)" "actual $br"

# --- (f) the moved mechanics are ABSENT, not duplicated; and the stub names the script
# Tokens verified unique at 46d59d5, each living entirely inside a section that MOVES.
for t in 'loop-copilot.json' 'copilot-reviewed-any'; do
  grep -qF -- "$t" "$loop" && bad "(f) loop.md no longer contains '$t'" "moved probe/table still inline" \
    || ok "(f) loop.md no longer contains '$t'"
done
for t in 'LAST_REVIEWED_HEAD' 'loop-checks.json'; do
  grep -qF -- "$t" "$modes" && bad "(f) loop-modes.md no longer contains '$t'" "moved probe/table still inline" \
    || ok "(f) loop-modes.md no longer contains '$t'"
done
grep -qF -- 'scripts/loop-decide.sh' "$loop" && ok "(f) loop.md names the decision script" \
  || bad "(f) loop.md names the decision script" "commands/loop.md does not reference scripts/loop-decide.sh"

exit "$fail"
