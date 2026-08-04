#!/usr/bin/env bash
# plan-slice.sh — NA-81. Deterministic plan-doc slicer / task-checklist extractor.
#
# usage:
#   plan-slice.sh <plan-path> phase <agent-name>
#   plan-slice.sh <plan-path> checklist
#
# stdout on success — exactly five lines, every value single-quoted for eval safety:
#   MODE=phase|checklist
#   SLICE=<absolute path to the slice file, OR the resolved plan path itself on fallback>
#   TASKS=<integer — count of task lines inside SLICE>
#   PHASES=<integer — phase headings matched in the whole doc; 0 in checklist mode>
#   GRAMMAR=matched|unmatched
#
# stdout on failure — exit 2, and NO SLICE= key is emitted:
#   ERROR=plan-not-found|bad-mode|bad-args
#
# Fail-safe direction: always widen, never empty. Every usable output (including every fallback)
# is exit 0 with the full five-key block; SLICE is never empty and never a valid empty file. An
# unrecognised grammar or an agent with no matching phase degrades to "hand back the whole plan
# path" — today's behaviour, never worse.
#
# $WORKTREE resolution (amendment A1) — lives HERE, not in the calling playbook, because script
# bytes are +0 resident while playbook bytes are capped. On /auto Workflow A the plan doc is
# committed onto feat/<STORY-KEY> and does not exist in the primary checkout (the orchestrator's
# CWD for the whole run) — only under $WORKTREE. Without this, every /auto story dispatch would
# see ERROR=plan-not-found. Order, first hit wins:
#   resolve(p) := p                       WHEN [ -r "$p" ]
#                 "$WORKTREE/$p"          WHEN WORKTREE is set AND [ -r "$WORKTREE/$p" ]
#                 ERROR=plan-not-found    otherwise (exit 2)
# On the fallback path (doc has no matching phase / no phase headings at all), SLICE is the
# resolved value UNCHANGED — never re-absolutised — so it string-equals the caller's own path
# when no $WORKTREE indirection was needed. Only a genuinely GENERATED slice/checklist file is
# reported as an absolute path.
#
# eval safety — every value is single-quoted at emission via shq() (embedded ' escaped as '\''),
# reused verbatim from loop-decide.sh. No contract key shadows a shell variable (NA-93 A8's PATH=
# precedent: MODE/SLICE/TASKS/PHASES/GRAMMAR are not standard shell variables). The consumer MUST
# capture this script's stdout and test $? BEFORE eval'ing:
#   eval "$(bash plan-slice.sh ...)" || STOP     <-- WRONG. Command substitution swallows the
#                                                     child's exit status; `||` tests eval's own
#                                                     status (always 0, from the last assignment).
#                                                     The exit-2 contract becomes invisible.
#   out=$(bash plan-slice.sh "$PLAN" phase "$AGENT") || STOP
#   unset MODE SLICE TASKS PHASES GRAMMAR
#   eval "$out"
#   [ "${TASKS:-0}" -gt 0 ] || STOP
#
# Grammar — widened past agents/tech-lead.md:138's bracket-only, ordinal-required form (measured
# 11/41 matched real plans; five delimiter forms exist in the live corpus, including this epic's
# own NA-86..NA-89, which write the owner as `· \`agent\`` rather than `[agent]`):
#   AGENT_SET     := database-administrator platform-engineer ai-enablement-engineer sync-engineer
#                    web-engineer mobile-engineer knowledge-engineer
#                    (principal-engineer is DELIBERATELY EXCLUDED — an orchestrator phase such as
#                    NA-88.md / NA-89.md's `## Phase 4 - ... orchestrator (\`principal-engineer\`)`
#                    is no domain agent's to receive, and excluding it also drops NA-26.md's
#                    `## Phase verification (...)` false-positive opener)
#   PHASE_HEADING := ^##[ ]+Phase\b AND the line contains >= 1 AGENT_SET token, decoration- and
#                    ordinal-insensitive: [x], `x`, (x), `[x]`, and `· \`x\`` all match — the test
#                    is a plain substring search for the token text, so no heading shape is special
#   SECTION_END   := next line matching ^##[^#], or EOF
#   TASK_LINE     := ^[ \t]*[-*] \[[ xX]\][ \t]
#   FENCE_RULE    := a ^## line inside a ``` or ~~~ fence is NOT a heading. Toggle fence state on
#                    any line whose left-trimmed form starts with ``` or ~~~; count toggles, never
#                    try to match opening to closing fence lengths. Real plans quote the tech-lead
#                    template inside fenced examples — a fence-blind scanner truncates the slice at
#                    a fake heading and miscounts tasks.
#
# Multiple phases per agent are normal (6 of 41 real plans give one agent more than one phase) and
# are ALL concatenated, in document order, separated by a single blank line. Returning only the
# first match is silent data loss.
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."

AGENT_SET="database-administrator platform-engineer ai-enablement-engineer sync-engineer web-engineer mobile-engineer knowledge-engineer"

# shq <value> -> single-quoted, embedded ' escaped as '\'' (verbatim from loop-decide.sh)
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# emit <mode> <slice> <tasks> <phases> <grammar> -> the five-key block, exit 0
emit() {
  printf 'MODE=%s\nSLICE=%s\nTASKS=%s\nPHASES=%s\nGRAMMAR=%s\n' \
    "$(shq "$1")" "$(shq "$2")" "$(shq "$3")" "$(shq "$4")" "$(shq "$5")"
  exit 0
}
# err <code> -> ERROR=<code>, exit 2. No SLICE= key is ever emitted on this path.
err() { printf 'ERROR=%s\n' "$1"; exit 2; }

# abspath <path> -> an absolute path, without requiring realpath/readlink -f (portability)
abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$(cd "$(dirname "$1")" 2>/dev/null && pwd)" "$(basename "$1")" ;;
  esac
}

# --- args ---------------------------------------------------------------------------
[ "$#" -eq 0 ] && err bad-args

plan="${1:-}"; mode="${2:-}"; agent="${3:-}"

case "$mode" in
  phase)
    [ "$#" -eq 3 ] || err bad-args
    ;;
  checklist)
    [ "$#" -eq 2 ] || err bad-args
    ;;
  *)
    err bad-mode
    ;;
esac
[ -n "$plan" ] || err bad-args

# `phase` mode interpolates $agent into the content-file name below (line ~135) — validate it
# against AGENT_SET first so an unrecognised/hostile agent string never reaches that
# interpolation (path-safety, not just correctness: AGENT_SET tokens are the only values this
# script's callers ever pass).
if [ "$mode" = "phase" ]; then
  case " $AGENT_SET " in
    *" $agent "*) : ;;
    *) err bad-args ;;
  esac
fi

# --- resolution -----------------------------------------------------------------------
if [ -r "$plan" ]; then
  resolved="$plan"
elif [ -n "${WORKTREE:-}" ] && [ -r "$WORKTREE/$plan" ]; then
  resolved="$WORKTREE/$plan"
else
  err plan-not-found
fi

tmpdir="$(bash "$here/tmp-dir.sh" 2>/dev/null || true)"
[ -n "$tmpdir" ] || tmpdir="./.tmp"
mkdir -p "$tmpdir" 2>/dev/null || true
key="$(basename "$tmpdir")"

if [ "$mode" = "checklist" ]; then
  content_file="$tmpdir/plan-checklist.$key.$$.md"
else
  content_file="$tmpdir/plan-slice.$key.$agent.$$.md"
fi
: > "$content_file"

# --- the fence-aware, single-pass scan -------------------------------------------------
# Emits, on its own stdout (never the eval-contract stream), four control lines the caller
# parses with sed — kept separate from emit()'s five-key block so the two layers never mix.
scan_awk='
BEGIN {
  ntok = split(agentset, AG, " ")
  in_fence = 0; open = 0; own_match = 0
  phases = 0; doc_tasks = 0; slice_tasks = 0; wrote_any = 0
}
{
  line = $0
  trimmed = line
  sub(/^[ \t]+/, "", trimmed)
  if (trimmed ~ /^(```|~~~)/) {
    if (open && mode == "phase" && own_match) print line > outfile
    in_fence = 1 - in_fence
    next
  }
  if (in_fence) {
    if (open && mode == "phase" && own_match) print line > outfile
    next
  }
  is_heading2 = (line ~ /^##[^#]/)
  is_phase = 0
  owners = ""
  if (line ~ /^##[ ]+Phase($|[^A-Za-z])/) {
    for (i = 1; i <= ntok; i++) {
      if (index(line, AG[i]) > 0) owners = owners AG[i] " "
    }
    if (owners != "") is_phase = 1
  }
  if (is_heading2) open = 0
  if (is_phase) {
    phases++
    if (mode == "phase") {
      padded = " " owners
      if (index(padded, " " agent " ") > 0) {
        if (wrote_any) print "" > outfile
        wrote_any = 1
        own_match = 1
        print line > outfile
      } else {
        own_match = 0
      }
    }
    open = 1
    next
  }
  is_task = (line ~ /^[ \t]*[-*] \[[ xX]\][ \t]/)
  if (is_task) doc_tasks++
  if (mode == "checklist" && is_task) print line > outfile
  if (mode == "phase" && open && own_match) {
    print line > outfile
    if (is_task) slice_tasks++
  }
}
END {
  close(outfile)
  printf("PHASES_CTL=%d\nDOC_TASKS_CTL=%d\nWROTE_ANY_CTL=%d\nSLICE_TASKS_CTL=%d\n", phases, doc_tasks, wrote_any, slice_tasks)
}
'

if ! ctl="$(awk -v mode="$mode" -v agent="$agent" -v outfile="$content_file" -v agentset="$AGENT_SET" "$scan_awk" "$resolved")"; then
  # awk itself failed (crash / unsupported syntax on some awk implementation) — its output, if
  # any, is not trustworthy control data. Fail-safe direction from the top of this file: always
  # widen, never empty. Widen to the WHOLE resolved plan, with TASKS counted independently of
  # awk (plain grep) so a total awk failure can never silently degrade to TASKS=0 and trip the
  # documented consumer contract `[ "$TASKS" -gt 0 ] || STOP`.
  fallback_tasks="$(grep -cE '^[[:space:]]*[-*] \[[ xX]\][[:space:]]' "$resolved" 2>/dev/null || true)"
  fallback_tasks="${fallback_tasks:-0}"
  emit "$mode" "$resolved" "$fallback_tasks" 0 unmatched
fi

phases_n="$(printf '%s\n' "$ctl" | sed -n 's/^PHASES_CTL=//p')"
doc_tasks_n="$(printf '%s\n' "$ctl" | sed -n 's/^DOC_TASKS_CTL=//p')"
wrote_any_n="$(printf '%s\n' "$ctl" | sed -n 's/^WROTE_ANY_CTL=//p')"
slice_tasks_n="$(printf '%s\n' "$ctl" | sed -n 's/^SLICE_TASKS_CTL=//p')"
: "${phases_n:=0}" "${doc_tasks_n:=0}" "${wrote_any_n:=0}" "${slice_tasks_n:=0}"

# --- assemble the contract -------------------------------------------------------------
case "$mode" in
  phase)
    if [ "$wrote_any_n" -eq 1 ]; then
      emit phase "$(abspath "$content_file")" "$slice_tasks_n" "$phases_n" matched
    elif [ "$phases_n" -gt 0 ]; then
      emit phase "$resolved" "$doc_tasks_n" "$phases_n" matched
    else
      emit phase "$resolved" "$doc_tasks_n" "$phases_n" unmatched
    fi
    ;;
  checklist)
    if [ "$doc_tasks_n" -gt 0 ]; then
      grammar=unmatched
      [ "$phases_n" -gt 0 ] && grammar=matched
      emit checklist "$(abspath "$content_file")" "$doc_tasks_n" 0 "$grammar"
    else
      emit checklist "$resolved" 0 0 unmatched
    fi
    ;;
esac
