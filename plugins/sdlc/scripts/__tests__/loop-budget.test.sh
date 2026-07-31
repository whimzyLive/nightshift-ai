#!/usr/bin/env bash
# loop-budget.test.sh — contract + error-row coverage for loop-budget.sh (NA-86 A5).
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/loop-budget.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
scripts_dir="$(cd "$here/.." && pwd)"
script="$scripts_dir/loop-budget.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }
pass() { echo "PASS: $1"; }

get_field() { # $1=output $2=key
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

# Run loop-budget.sh in an isolated scratch dir (own ./.tmp) so cases never collide.
# Unset both session-key env vars so tmp-dir.sh always resolves the bare "./.tmp" dir
# this test seeds directly — a live SDLC_SESSION_KEY/CLAUDE_CODE_SESSION_ID in the
# runner's own environment would otherwise scope the budget file under a subdirectory
# this test never seeds.
run_in() { # $1=case-dir; remaining args passed to loop-budget.sh
  local dir="$1"; shift
  ( cd "$dir" && env -u SDLC_SESSION_KEY -u CLAUDE_CODE_SESSION_ID bash "$script" "$@" )
}

# Path to the budget file for a given case dir (mirrors tmp-dir.sh with both session-key
# env vars unset).
budget_file() { # $1=case-dir
  printf '%s/.tmp/loop-budget\n' "$1"
}

# --- Case 1: init then check happy path ---------------------------------------------
c1="$work/c1"; mkdir -p "$c1"
run_in "$c1" init >/dev/null
out="$(run_in "$c1" check headA 0)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
count="$(get_field "$out" BUDGET_PASS_COUNT)"
if [ "$rc" -eq 0 ] && [ "$decision" = "CONTINUE" ] && [ "$count" = "1" ]; then
  pass "init then check happy path (CONTINUE, pass 1, exit 0)"
else
  fail "init then check happy path — got rc=$rc decision=$decision count=$count"
fi

# --- Case 2: BUDGET_PASS_COUNT post-increment ----------------------------------------
c2="$work/c2"; mkdir -p "$c2"
run_in "$c2" init >/dev/null
run_in "$c2" check headA 0 >/dev/null
out="$(run_in "$c2" check headA 0)"
count="$(get_field "$out" BUDGET_PASS_COUNT)"
[ "$count" = "2" ] && pass "BUDGET_PASS_COUNT post-increment (2nd check -> 2)" \
  || fail "BUDGET_PASS_COUNT post-increment — got $count, want 2"

# --- Case 3: STOP_IDLE at BUDGET_SECS -------------------------------------------------
c3="$work/c3"; mkdir -p "$c3"
run_in "$c3" init >/dev/null
now="$(date +%s)"
past=$(( now - 1300 ))
printf '%s 0 headA 0\n' "$past" > "$c3/.tmp/loop-budget"
out="$(BUDGET_SECS=1200 run_in "$c3" check headA 0)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
if [ "$rc" -eq 1 ] && [ "$decision" = "STOP_IDLE" ]; then
  pass "STOP_IDLE at BUDGET_SECS (exit 1)"
else
  fail "STOP_IDLE at BUDGET_SECS — got rc=$rc decision=$decision"
fi

# --- Case 4: STOP_IDLE at REREVIEW_GRACE_SECS with --grace ---------------------------
c4="$work/c4"; mkdir -p "$c4"
run_in "$c4" init >/dev/null
now="$(date +%s)"
past=$(( now - 700 ))
printf '%s 0 headA 0\n' "$past" > "$c4/.tmp/loop-budget"
out="$(REREVIEW_GRACE_SECS=600 run_in "$c4" check headA 0 --grace)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
if [ "$rc" -eq 1 ] && [ "$decision" = "STOP_IDLE" ]; then
  pass "STOP_IDLE at REREVIEW_GRACE_SECS with --grace (700s idle > 600s grace)"
else
  fail "STOP_IDLE at REREVIEW_GRACE_SECS — got rc=$rc decision=$decision"
fi
# Same 700s-idle state must NOT trip without --grace (full 1200s budget still open).
out2="$(BUDGET_SECS=1200 run_in "$c4" check headA 0)"
decision2="$(get_field "$out2" BUDGET_DECISION)"
[ "$decision2" = "CONTINUE" ] && pass "--grace bound does not leak into the non-grace check" \
  || fail "--grace bound leaked — got $decision2, want CONTINUE"

# --- Case 5: STOP_PASSES at BUDGET_PASSES ---------------------------------------------
c5="$work/c5"; mkdir -p "$c5"
run_in "$c5" init >/dev/null
now="$(date +%s)"
printf '%s 4 - -\n' "$now" > "$c5/.tmp/loop-budget"
out="$(BUDGET_PASSES=5 run_in "$c5" check headA 0)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
count="$(get_field "$out" BUDGET_PASS_COUNT)"
if [ "$rc" -eq 1 ] && [ "$decision" = "STOP_PASSES" ] && [ "$count" = "5" ]; then
  pass "STOP_PASSES at BUDGET_PASSES (pass 5, exit 1)"
else
  fail "STOP_PASSES at BUDGET_PASSES — got rc=$rc decision=$decision count=$count"
fi

# --- Case 6: progress reset when head or unresolved count changes --------------------
c6="$work/c6"; mkdir -p "$c6"
run_in "$c6" init >/dev/null
now="$(date +%s)"
past=$(( now - 1300 ))
printf '%s 0 headA 0\n' "$past" > "$c6/.tmp/loop-budget"
out="$(BUDGET_SECS=1200 run_in "$c6" check headB 0)"
decision="$(get_field "$out" BUDGET_DECISION)"
progress="$(get_field "$out" BUDGET_PROGRESS)"
idle="$(get_field "$out" BUDGET_IDLE_SECS)"
if [ "$decision" = "CONTINUE" ] && [ "$progress" = "true" ] && [ "$idle" -lt 5 ]; then
  pass "progress reset on changed head (idle window re-armed, CONTINUE)"
else
  fail "progress reset on changed head — got decision=$decision progress=$progress idle=$idle"
fi

c6b="$work/c6b"; mkdir -p "$c6b"
run_in "$c6b" init >/dev/null
now="$(date +%s)"
past=$(( now - 1300 ))
printf '%s 0 headA 0\n' "$past" > "$c6b/.tmp/loop-budget"
out="$(BUDGET_SECS=1200 run_in "$c6b" check headA 3)"
decision="$(get_field "$out" BUDGET_DECISION)"
progress="$(get_field "$out" BUDGET_PROGRESS)"
if [ "$decision" = "CONTINUE" ] && [ "$progress" = "true" ]; then
  pass "progress reset on changed unresolved count (CONTINUE)"
else
  fail "progress reset on changed unresolved count — got decision=$decision progress=$progress"
fi

# --- Error row 1: budget file missing on check ----------------------------------------
c7="$work/c7"; mkdir -p "$c7"
out="$(run_in "$c7" check headA 0)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
count="$(get_field "$out" BUDGET_PASS_COUNT)"
if [ "$rc" -eq 0 ] && [ "$decision" = "CONTINUE" ] && [ "$count" = "1" ]; then
  pass "error row: budget file missing on check -> re-initialise, CONTINUE, pass 1"
else
  fail "error row: budget file missing on check — got rc=$rc decision=$decision count=$count"
fi

# --- Error row 2: empty/non-numeric fields never coerce to a huge elapsed ------------
c8="$work/c8"; mkdir -p "$c8/.tmp"
printf ' - - -\n' > "$c8/.tmp/loop-budget"
out="$(BUDGET_SECS=1200 run_in "$c8" check headA 0)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
idle="$(get_field "$out" BUDGET_IDLE_SECS)"
if [ "$rc" -eq 0 ] && [ "$decision" = "CONTINUE" ] && [ "$idle" -lt 5 ]; then
  pass "error row: empty/non-numeric fields re-initialise instead of tripping on pass 1"
else
  fail "error row: empty/non-numeric fields — got rc=$rc decision=$decision idle=$idle"
fi

# --- Error row 3: progress_epoch in the future (NTP step-back) clamps to 0 -----------
c9="$work/c9"; mkdir -p "$c9/.tmp"
future=$(( $(date +%s) + 5000 ))
printf '%s 0 - -\n' "$future" > "$c9/.tmp/loop-budget"
out="$(BUDGET_SECS=1200 run_in "$c9" check headA 0)"; rc=$?
decision="$(get_field "$out" BUDGET_DECISION)"
idle="$(get_field "$out" BUDGET_IDLE_SECS)"
if [ "$rc" -eq 0 ] && [ "$decision" = "CONTINUE" ] && [ "$idle" -ge 0 ] && [ "$idle" -lt 5 ]; then
  pass "error row: future progress_epoch clamps elapsed to >= 0, CONTINUE"
else
  fail "error row: future progress_epoch — got rc=$rc decision=$decision idle=$idle"
fi

echo
if [ "$failures" -ne 0 ]; then
  echo "loop-budget.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi
echo "loop-budget.test.sh: PASS — all assertions passed"
exit 0
