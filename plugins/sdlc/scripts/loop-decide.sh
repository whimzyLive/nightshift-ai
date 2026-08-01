#!/usr/bin/env bash
# loop-decide.sh — NA-93. The sdlc:loop probe-and-decide body, as a script.
#
# usage: loop-decide.sh <PR> <copilot|in-session> <DIR> [REVIEW_MARK]
#        loop-decide.sh --from-status "<loop-status line>"       # table only, no probe (TEST SURFACE)
#        loop-decide.sh --from-fields "<in-session field line>"  # table only, no probe (TEST SURFACE)
#
# stdout — exactly NINE lines, first-match-wins, cap 600 B. Every value is single-quoted so the
# caller's `eval` is safe; an embedded ' is escaped as '\'':
#   DECISION='wait|fix|review|clean|halt'
#   RULE='1|2a|2b|3|4|5|6|7|CI-a|CI-b|CI-c|CI-c2|CI-d|CI-e|CI-f|unresolvable'
#   REVIEW_PATH='copilot|in-session'
#   HEAD='<head oid | ->'
#   UNRESOLVED='<N | ->'
#   FIELDS='<the probe's own integers, verbatim k=v, space-separated — NEVER re-derived>'
#   GRACE='yes|no'
#   RE_REQUEST='yes|no'
#   BLOCKED_BY='<one line | none>'
#
# exit 0 ALWAYS. The script never halts the loop; commands/loop.md owns the consequence.
#
# FAIL SAFE: an unresolvable probe resolves toward WAIT — never toward `clean`, never toward
# `halt`. `wait` is the only decision with no irreversible effect AND a bound: loop-budget.sh
# stops a wait-looping pass at 1200 s idle or 30 passes, so an unresolvable probe degrades to a
# bounded stall with a printed reason. A resolved-but-unmatched tuple still selects RULE=7 ->
# halt: that is the TABLE's own catch-all, not a fail-safe path, and it is unchanged.
#
# `review-clean=-` is a LEGITIMATE value, not a parse failure (CI-1 sets it when the marker is
# absent or half-written). The non-numeric fail-safe MUST exempt it. (reviewed-head=1,
# review-clean=-) is enumerable but production-unreachable and selects CI-f.
#
# TEST SURFACE, documented so nobody re-implements the table in a harness (the dead-code failure
# H-Gate-2b exists to catch):
#   --from-status / --from-fields  bypass the probe and call decide() directly
#   SDLC_LOOP_PROBE_DIR   dir to resolve pr-loop-status.sh / pr-unresolved-comments.sh from
#                         (default: this script's own dir)
#   SDLC_LOOP_GH          the gh binary                               (default: gh)
# DIAGNOSTIC, changes no decision: SDLC_LOOP_DECIDE_TRACE=1 prints the matched rule's condition
# to STDERR.
#
# H does NOT change any decision-table row. Ported verbatim in meaning from commands/loop.md
# Step 3 + Step 4 and refs/loop-modes.md CI-1 + CI-2 at 46d59d5. tools/sdlc-analyser/
# __tests__/fixtures/loop-decision-golden.json pins all 1,458 cases against the PRE-change text.
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
PROBE_DIR="${SDLC_LOOP_PROBE_DIR:-$here}"
GH="${SDLC_LOOP_GH:-gh}"
TRACE="${SDLC_LOOP_DECIDE_TRACE:-0}"

trace() { [ "$TRACE" = "1" ] && printf 'TRACE: %s\n' "$1" >&2; return 0; }

# shq <value> -> single-quoted, embedded ' escaped as '\''
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# emit <decision> <rule> <path> <head> <unresolved> <fields> <grace> <re_request> <blocked_by>
emit() {
  local block n
  block="$(printf 'DECISION=%s\nRULE=%s\nREVIEW_PATH=%s\nHEAD=%s\nUNRESOLVED=%s\nFIELDS=%s\nGRACE=%s\nRE_REQUEST=%s\nBLOCKED_BY=%s\n' \
    "$(shq "$1")" "$(shq "$2")" "$(shq "$3")" "$(shq "$4")" "$(shq "$5")" \
    "$(shq "$6")" "$(shq "$7")" "$(shq "$8")" "$(shq "$9")")"
  n="$(printf '%s' "$block" | wc -c | tr -d ' ')"
  if [ "$n" -gt 600 ]; then
    # Truncate BLOCKED_BY first — never FIELDS, never a key. Never drop a line.
    block="$(printf 'DECISION=%s\nRULE=%s\nREVIEW_PATH=%s\nHEAD=%s\nUNRESOLVED=%s\nFIELDS=%s\nGRACE=%s\nRE_REQUEST=%s\nBLOCKED_BY=%s\n' \
      "$(shq "$1")" "$(shq "$2")" "$(shq "$3")" "$(shq "$4")" "$(shq "$5")" \
      "$(shq "$6")" "$(shq "$7")" "$(shq "$8")" "$(shq "${9:0:40}...[truncated]")")"
  fi
  printf '%s' "$block"
  exit 0
}

# field_of <line> <key> -> the value of key=value in a space-separated k=v line, or empty
field_of() {
  printf '%s\n' "$1" | grep -oE "(^| )$2=[^ ]*" | tail -1 | sed "s/^ *$2=//"
}

is_numeric() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

# --- decide_copilot rh cr cp ra un pend fail pass -> "rule decision grace re_request"
# Ported verbatim in meaning from commands/loop.md Step 4, rules 1-7, first-match-wins.
# `pass` (checks-passing) is accepted but read by NO rule (F-3's invariance property).
decide_copilot() {
  local rh="$1" cr="$2" cp="$3" ra="$4" un="$5" pend="$6" fail="$7"
  if [ "$cp" -eq 1 ]; then trace "rule 1: copilot-pending==1"; printf '1 wait no no\n'; return; fi
  if [ "$rh" -eq 0 ] && [ "$cp" -eq 0 ] && [ "$ra" -eq 0 ]; then
    trace "rule 2a: reviewed-head==0 && pending==0 && reviewed-any==0"; printf '2a wait no yes\n'; return
  fi
  if [ "$rh" -eq 0 ] && [ "$cp" -eq 0 ] && [ "$ra" -eq 1 ]; then
    trace "rule 2b: reviewed-head==0 && pending==0 && reviewed-any==1"; printf '2b wait yes yes\n'; return
  fi
  if [ "$rh" -eq 1 ] && { [ "$un" -gt 0 ] || [ "$cr" -eq 1 ]; }; then
    trace "rule 3: reviewed-head==1 && (unresolved>0 || changes-requested==1)"; printf '3 fix no no\n'; return
  fi
  if [ "$rh" -eq 1 ] && [ "$cr" -eq 0 ] && [ "$un" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pend" -eq 0 ]; then
    trace "rule 4: GENUINE CLEAN"; printf '4 clean no no\n'; return
  fi
  if [ "$pend" -gt 0 ]; then trace "rule 5: checks-pending>0"; printf '5 wait no no\n'; return; fi
  if [ "$rh" -eq 1 ] && [ "$cr" -eq 0 ] && [ "$un" -eq 0 ] && [ "$fail" -gt 0 ] && [ "$pend" -eq 0 ]; then
    trace "rule 6: FAILING CHECKS"; printf '6 halt no no\n'; return
  fi
  trace "rule 7: catch-all"; printf '7 halt no no\n'
}

blocked_by_copilot() { # <rule> <head> <cp> <un> <pend>
  case "$1" in
    1)  printf 'copilot-review-pending (copilot-pending=1, head=%s)' "$2" ;;
    2a) printf 'Copilot has not started the initial review of %s' "$2" ;;
    2b) printf 'Copilot has not queued a re-review of HEAD %s (it reviewed an earlier head) - review-on-push may be limited; merge/resolve manually or re-trigger' "$2" ;;
    5)  printf 'checks still pending: P=%s' "$5" ;;
    *)  printf 'none' ;;
  esac
}

# --- decide_insession rh rc un pend fail -> "rule decision grace re_request"
# Ported verbatim in meaning from refs/loop-modes.md CI-2, rules CI-a..CI-f, first-match-wins.
# `rc` (review-clean) may be '-' — a LEGITIMATE value, never treated as a parse failure here;
# it simply matches no CI-c/c2/d/e branch and falls to CI-f, exactly as the table specifies.
decide_insession() {
  local rh="$1" rc="$2" un="$3" pend="$4" fail="$5"
  if [ "$pend" -gt 0 ]; then trace "CI-a: checks-pending>0"; printf 'CI-a wait no no\n'; return; fi
  if [ "$rh" -eq 0 ]; then trace "CI-b: reviewed-head==0"; printf 'CI-b review no no\n'; return; fi
  if [ "$rc" = "0" ]; then trace "CI-c: reviewed-head==1 && review-clean==0"; printf 'CI-c fix no no\n'; return; fi
  if [ "$rc" = "1" ] && [ "$un" -gt 0 ]; then
    trace "CI-c2: review-clean==1 && unresolved>0"; printf 'CI-c2 halt no no\n'; return
  fi
  if [ "$rc" = "1" ] && [ "$un" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pend" -eq 0 ]; then
    trace "CI-d: GENUINE CLEAN"; printf 'CI-d clean no no\n'; return
  fi
  if [ "$rc" = "1" ] && [ "$un" -eq 0 ] && [ "$fail" -gt 0 ]; then
    trace "CI-e: FAILING CHECKS"; printf 'CI-e halt no no\n'; return
  fi
  trace "CI-f: catch-all (includes review-clean=-)"; printf 'CI-f halt no no\n'
}

blocked_by_insession() { # <rule> <pend>
  case "$1" in
    CI-a) printf 'checks still pending: P=%s' "$2" ;;
    *)    printf 'none' ;;
  esac
}

# --- parse_copilot_fields <line> -> sets G_RH G_CR G_CP G_UN G_PEND G_FAIL G_PASS G_RA, or
# G_ERR on failure. Called DIRECTLY (never via `$(...)`) so its variable assignments land in
# THIS shell, not a subshell. Never a whole-cell string match — each field is extracted and
# validated individually.
parse_copilot_fields() {
  local line="$1"
  G_ERR=""
  case "$line" in *'loop-status:'*) : ;; *) G_ERR='no loop-status: line'; return 1 ;; esac
  G_RH="$(field_of "$line" copilot-reviewed-head)"
  G_CR="$(field_of "$line" copilot-changes-requested)"
  G_CP="$(field_of "$line" copilot-pending)"
  G_UN="$(field_of "$line" unresolved-copilot)"
  G_PEND="$(field_of "$line" checks-pending)"
  G_FAIL="$(field_of "$line" checks-failing)"
  G_PASS="$(field_of "$line" checks-passing)"
  G_RA="$(field_of "$line" copilot-reviewed-any)"
  for v in "$G_RH" "$G_CR" "$G_CP" "$G_UN" "$G_PEND" "$G_FAIL" "$G_PASS" "$G_RA"; do
    is_numeric "$v" || { G_ERR='a named field is missing or non-numeric'; return 1; }
  done
  return 0
}

# --- parse_insession_fields <line> -> sets G_RH G_RC G_UN G_PEND G_FAIL, or G_ERR on failure.
# Called DIRECTLY (never via `$(...)`), same reason as parse_copilot_fields. review-clean
# ('-' is legitimate) is the ONE field exempt from the non-numeric fail-safe.
parse_insession_fields() {
  local line="$1"
  G_ERR=""
  case "$line" in *'reviewed-head='*) : ;; *) G_ERR='no in-session field line'; return 1 ;; esac
  G_RH="$(field_of "$line" reviewed-head)"
  G_RC="$(field_of "$line" review-clean)"
  G_UN="$(field_of "$line" unresolved)"
  G_PEND="$(field_of "$line" checks-pending)"
  G_FAIL="$(field_of "$line" checks-failing)"
  is_numeric "$G_RH" || { G_ERR='reviewed-head is missing or non-numeric'; return 1; }
  case "$G_RC" in '-') : ;; *) is_numeric "$G_RC" || { G_ERR='review-clean is missing or non-numeric (and not the legitimate "-")'; return 1; } ;; esac
  for v in "$G_UN" "$G_PEND" "$G_FAIL"; do
    is_numeric "$v" || { G_ERR='a named field is missing or non-numeric'; return 1; }
  done
  return 0
}

# --- probe_copilot <PR> <DIR> -> emits and exits
probe_copilot() {
  local pr="$1" dir="$2" out line head result rule decision grace re_request fields
  out="$("$PROBE_DIR/pr-loop-status.sh" "$pr" "$dir/loop-copilot.json" 2>/dev/null)"
  line="$(printf '%s\n' "$out" | grep '^loop-status:' | tail -1)"
  if [ -z "$line" ]; then
    emit wait unresolvable copilot - - - no no "pr-loop-status.sh emitted no loop-status: line"
  fi
  if ! parse_copilot_fields "$line"; then
    emit wait unresolvable copilot - - - no no "$G_ERR"
  fi
  head="$("$GH" pr view "$pr" --json headRefOid -q .headRefOid 2>/dev/null)"; [ -n "$head" ] || head="-"
  result="$(decide_copilot "$G_RH" "$G_CR" "$G_CP" "$G_RA" "$G_UN" "$G_PEND" "$G_FAIL" "$G_PASS")"
  read -r rule decision grace re_request <<<"$result"
  fields="copilot-reviewed-head=$G_RH copilot-changes-requested=$G_CR copilot-pending=$G_CP unresolved-copilot=$G_UN checks-pending=$G_PEND checks-failing=$G_FAIL checks-passing=$G_PASS copilot-reviewed-any=$G_RA"
  emit "$decision" "$rule" copilot "$head" "$G_UN" "$fields" "$grace" "$re_request" \
    "$(blocked_by_copilot "$rule" "$head" "$G_CP" "$G_UN" "$G_PEND")"
}

# --- probe_insession <PR> <DIR> <REVIEW_MARK> -> emits and exits
# Ported verbatim in meaning from refs/loop-modes.md CI-1.
probe_insession() {
  local pr="$1" dir="$2" mark="$3" last_head last_clean cur_head cur_unresolved
  local checks_out checks_line checks_pending checks_failing
  local reviewed_head result rule decision grace re_request fields
  [ -n "$mark" ] || mark="$dir/loop-review-mark"
  read -r last_head last_clean < "$mark" 2>/dev/null || { last_head=-; last_clean=-; }
  [ -n "${last_head:-}" ] || last_head=-
  case "${last_clean:-}" in 0|1) ;; *) last_clean=-; last_head=- ;; esac
  cur_head="$("$GH" pr view "$pr" --json headRefOid -q .headRefOid 2>/dev/null)"; [ -n "$cur_head" ] || cur_head="-"
  reviewed_head=0
  [ "$cur_head" = "$last_head" ] && reviewed_head=1
  cur_unresolved="$("$PROBE_DIR/pr-unresolved-comments.sh" "$pr" 2>/dev/null | grep -c . || true)"
  cur_unresolved="${cur_unresolved:-0}"
  is_numeric "$cur_unresolved" || cur_unresolved=0
  checks_out="$("$PROBE_DIR/pr-loop-status.sh" "$pr" "$dir/loop-checks.json" 2>/dev/null)"
  checks_line="$(printf '%s\n' "$checks_out" | grep '^loop-status:' | tail -1)"
  checks_pending="$(field_of "$checks_line" checks-pending)"
  checks_failing="$(field_of "$checks_line" checks-failing)"
  if ! is_numeric "$checks_pending" || ! is_numeric "$checks_failing"; then
    emit wait unresolvable in-session "$cur_head" "$cur_unresolved" - no no \
      "checks-pending/checks-failing missing or non-numeric from the CI probe"
  fi
  result="$(decide_insession "$reviewed_head" "$last_clean" "$cur_unresolved" "$checks_pending" "$checks_failing")"
  read -r rule decision grace re_request <<<"$result"
  fields="reviewed-head=$reviewed_head review-clean=$last_clean unresolved=$cur_unresolved checks-pending=$checks_pending checks-failing=$checks_failing"
  emit "$decision" "$rule" in-session "$cur_head" "$cur_unresolved" "$fields" "$grace" "$re_request" \
    "$(blocked_by_insession "$rule" "$checks_pending")"
}

# --- entry point dispatch ------------------------------------------------------------
case "${1:-}" in
  --from-status)
    line="${2:-}"
    if parse_copilot_fields "$line"; then
      result="$(decide_copilot "$G_RH" "$G_CR" "$G_CP" "$G_RA" "$G_UN" "$G_PEND" "$G_FAIL" "$G_PASS")"
      read -r rule decision grace re_request <<<"$result"
      fields="copilot-reviewed-head=$G_RH copilot-changes-requested=$G_CR copilot-pending=$G_CP unresolved-copilot=$G_UN checks-pending=$G_PEND checks-failing=$G_FAIL checks-passing=$G_PASS copilot-reviewed-any=$G_RA"
      emit "$decision" "$rule" copilot - "$G_UN" "$fields" "$grace" "$re_request" \
        "$(blocked_by_copilot "$rule" - "$G_CP" "$G_UN" "$G_PEND")"
    else
      emit wait unresolvable copilot - - - no no "$G_ERR"
    fi
    ;;
  --from-fields)
    line="${2:-}"
    if parse_insession_fields "$line"; then
      result="$(decide_insession "$G_RH" "$G_RC" "$G_UN" "$G_PEND" "$G_FAIL")"
      read -r rule decision grace re_request <<<"$result"
      fields="reviewed-head=$G_RH review-clean=$G_RC unresolved=$G_UN checks-pending=$G_PEND checks-failing=$G_FAIL"
      emit "$decision" "$rule" in-session - "$G_UN" "$fields" "$grace" "$re_request" \
        "$(blocked_by_insession "$rule" "$G_PEND")"
    else
      emit wait unresolvable in-session - - - no no "$G_ERR"
    fi
    ;;
  '')
    emit wait unresolvable - - - - no no "no arguments provided"
    ;;
  *)
    pr="$1"; path="${2:-}"; dir="${3:-}"; mark="${4:-}"
    case "$path" in
      copilot)    probe_copilot "$pr" "$dir" ;;
      in-session) probe_insession "$pr" "$dir" "$mark" ;;
      *)          emit wait unresolvable - - - - no no "unrecognised REVIEW_PATH argument '$path'" ;;
    esac
    ;;
esac
