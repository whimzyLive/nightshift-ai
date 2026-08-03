#!/usr/bin/env bash
set -uo pipefail
# loop-budget.sh — `init` / `check` subcommands for the sdlc:loop global loop budget,
# moved out of commands/loop.md's "Global loop budget" section (NA-86 A5) so a WAIT or
# clean-exit pass never has to load the full bash block to decide whether to keep going.
#
# Invocation:
#   bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-budget.sh init
#   bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-budget.sh check <head> <unresolved> [--grace]
#
# `check` exit 0 means budget not exceeded (BUDGET_DECISION=CONTINUE); exit 1 means a
# bound tripped (BUDGET_DECISION=STOP_IDLE|STOP_PASSES) — the caller's decision table
# still owns WAIT vs fix vs exit (D8); this script only owns the budget math. `init`
# always exits 0.
#
# `check` stdout — one KEY=value per line, eval-able (LoopBudgetResult):
#   BUDGET_DECISION    in {CONTINUE, STOP_IDLE, STOP_PASSES}
#   BUDGET_PASS_COUNT  number, POST-increment
#   BUDGET_IDLE_SECS   number, clamped to >= 0 on clock skew
#   BUDGET_PROGRESS    in {'true', 'false'} — head oid or unresolved count changed since last pass
#   BUDGET_REASON      one line, human-readable; empty string when CONTINUE
#
# Defaults — env-overridable, exactly today's names/values (unchanged by this split):
#   BUDGET_SECS=1200          20 min of NO PROGRESS (idle timeout — reset on progress, NOT total runtime)
#   REREVIEW_GRACE_SECS=600   rule 2b's shorter grace bound for a stalled re-review
#   BUDGET_PASSES=30          absolute runaway backstop — NOT reset on progress
# Rule 2b selects the grace bound over the full idle budget by passing `--grace`.

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."

# shq <value> -> single-quoted, embedded ' escaped as '\'' . Mirrors scripts/loop-decide.sh
# so the plugin has one quoting convention, not two. BUDGET_REASON contains spaces and
# parens/`>=` (e.g. "1200s idle (no progress) >= budget 1200s") — unquoted, the caller's
# documented `eval "$(...)"` pattern would split it into a syntax error on `(` / a redirect on
# `>=`, exactly the class of bug fixed in 3bd10b0 for resolve-ai-workflow-mode.sh's `Full Auto`.
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

SUBCOMMAND="${1:-}"
shift || true

dir="$(bash "$here/tmp-dir.sh")"
BUDGET_FILE="$dir/loop-budget"

BUDGET_SECS="${BUDGET_SECS:-1200}"
REREVIEW_GRACE_SECS="${REREVIEW_GRACE_SECS:-600}"
BUDGET_PASSES="${BUDGET_PASSES:-30}"

init_budget() {
  if [ ! -f "$BUDGET_FILE" ]; then
    # First pass: record the progress epoch (now), pass counter 0, and an empty progress
    # marker (head oid + unresolved count). Format: "<progress_epoch> <pass_count> <head> <unresolved>".
    progress_epoch=$(date +%s)
    printf '%s 0 - -\n' "$progress_epoch" > "$BUDGET_FILE"
  fi
}

case "$SUBCOMMAND" in
  init)
    init_budget
    exit 0
    ;;
  check)
    CUR_HEAD="${1:--}"
    CUR_UNRESOLVED="${2:--}"
    GRACE_FLAG="${3:-}"
    [ -n "$CUR_HEAD" ] || CUR_HEAD=-
    [ -n "$CUR_UNRESOLVED" ] || CUR_UNRESOLVED=-

    if [ "$GRACE_FLAG" = "--grace" ]; then
      EFFECTIVE_BUDGET_SECS="$REREVIEW_GRACE_SECS"
    else
      EFFECTIVE_BUDGET_SECS="$BUDGET_SECS"
    fi

    # Error row: budget file missing on check -> re-initialise (today's tolerant
    # behaviour) instead of failing; the first check after that lands on pass 1, CONTINUE.
    [ -f "$BUDGET_FILE" ] || init_budget

    read progress_epoch pass_count last_head last_unresolved < "$BUDGET_FILE"

    # Error row: empty/non-numeric numerics -> re-initialise those fields, never let an
    # empty field coerce to a huge elapsed and trip on pass 1.
    case "$progress_epoch" in (''|*[!0-9]*) progress_epoch=$(date +%s) ;; esac
    case "$pass_count"     in (''|*[!0-9]*) pass_count=0 ;; esac
    [ -n "$last_head" ] || last_head=-
    [ -n "$last_unresolved" ] || last_unresolved=-

    pass_count=$(( pass_count + 1 ))
    now=$(date +%s)

    # Reset the idle window on PROGRESS: a new reviewed head (Copilot reviewed a new oid,
    # or a /review-fix push moved HEAD) or a changed unresolved-comment count.
    BUDGET_PROGRESS=false
    if [ "$CUR_HEAD" != "$last_head" ] || [ "$CUR_UNRESOLVED" != "$last_unresolved" ]; then
      progress_epoch=$now
      BUDGET_PROGRESS=true
    fi

    elapsed=$(( now - progress_epoch ))

    # Error row: progress_epoch in the future (NTP step-back) -> clamp elapsed to 0 and
    # reset the epoch, instead of a negative elapsed silently disabling the bound.
    if [ "$elapsed" -lt 0 ]; then
      elapsed=0
      progress_epoch=$now
    fi

    printf '%s %s %s %s\n' "$progress_epoch" "$pass_count" "$CUR_HEAD" "$CUR_UNRESOLVED" > "$BUDGET_FILE"

    BUDGET_DECISION=CONTINUE
    BUDGET_REASON=""
    if [ "$elapsed" -ge "$EFFECTIVE_BUDGET_SECS" ]; then
      BUDGET_DECISION=STOP_IDLE
      BUDGET_REASON="${elapsed}s idle (no progress) >= budget ${EFFECTIVE_BUDGET_SECS}s"
    elif [ "$pass_count" -ge "$BUDGET_PASSES" ]; then
      BUDGET_DECISION=STOP_PASSES
      BUDGET_REASON="${pass_count} passes >= backstop ${BUDGET_PASSES}"
    fi

    printf 'BUDGET_DECISION=%s\n' "$(shq "$BUDGET_DECISION")"
    printf 'BUDGET_PASS_COUNT=%s\n' "$(shq "$pass_count")"
    printf 'BUDGET_IDLE_SECS=%s\n' "$(shq "$elapsed")"
    printf 'BUDGET_PROGRESS=%s\n' "$(shq "$BUDGET_PROGRESS")"
    printf 'BUDGET_REASON=%s\n' "$(shq "$BUDGET_REASON")"

    [ "$BUDGET_DECISION" = "CONTINUE" ] && exit 0
    exit 1
    ;;
  *)
    echo "usage: loop-budget.sh init | check <head> <unresolved> [--grace]" >&2
    exit 1
    ;;
esac
