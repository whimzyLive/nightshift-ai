#!/usr/bin/env bash
# Epic dependency-ordered queue builder for /auto epic orchestration.
# Usage: epic-queue.sh <EPIC-KEY>
#   e.g. epic-queue.sh <EPIC-KEY>
#
# Lists the epic's child stories, derives each story's BLOCKERS by the same
# sibling-inversion rule dep-gate.sh uses (acli link list only exposes
# outwardIssueKey = the issue a story BLOCKS, so a sibling S blocks STORY iff
# S's links contain outwardIssueKey == STORY with typeName == "Blocks"), then
# emits a stable topological order: a story appears only after every story that
# blocks it. Ties among mutually-independent stories are broken by Jira
# `created ASC` (oldest first), so the order is deterministic across runs.
#
# All command substitution / loops / jq live INSIDE this script so the caller
# issues one statically-analyzable invocation (allowlisted
# Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)).
#
# Output (greppable, deterministic):
#   EPIC=<key>
#   ORDER=<k1 k2 …>             (dependency-ordered, ties by created ASC)
#   <key> BLOCKERS=<…>          (one line per story; empty value = no blockers)
#   GATE=PASS                   -> exit 0, safe to drive the epic
#   GATE=STOP                   -> exit 1, with REASON= line(s)
#
# acli is the only source of truth — any acli query error => GATE=STOP
# (cannot build a trustworthy queue). A dependency cycle => GATE=STOP.
set -uo pipefail

epic="${1:?usage: epic-queue.sh <EPIC-KEY>}"

fail() { echo "REASON=$1"; echo "GATE=STOP"; exit 1; }

echo "EPIC=$epic"

# 1. Children = all stories whose parent is the epic, ordered by created ASC so
#    the natural input order already encodes the tie-break. JQL ORDER BY makes
#    the oldest-first ordering authoritative regardless of acli's default sort.
#    NB: do NOT pass `--fields key` — some acli versions emit an array of nulls
#    when --fields is set, which would make every child key resolve to "null".
#    Reading `.key` off the full work-item objects is version-stable.
children="$(acli jira workitem search --jql "parent = $epic ORDER BY created ASC" --json 2>/dev/null \
              | jq -r '.[].key')"
[ -z "$children" ] && fail "could not list children of $epic (no stories, or acli query failed — cannot build queue)"

# 2. Build the blocker set per child by sibling inversion (same rule as
#    dep-gate.sh). A sibling S blocks child C iff S's links contain
#    outwardIssueKey == C with typeName == "Blocks". Restrict to siblings that
#    are themselves children of this epic — a Blocks link to an out-of-epic
#    issue does not gate intra-epic ordering.
#
# O(N), not O(N²): fetch each child S's outward-Blocks set ONCE (N acli calls
# total, not one per (child × sibling) pair), then derive blockers by inversion
# — S blocks T iff T ∈ outwardBlocks(S) AND T is a child of this epic, so
# blockers(T) = { S : T ∈ outwardBlocks(S) }.
#
# Each acli call's exit status is checked explicitly: a non-zero/error result
# (distinct from a successful-but-empty link set) is a hard STOP per this
# script's contract — acli is the only source of truth, so a flaky query must
# never be silently read as "no blocker" and corrupt the dependency order.
#
# We store the result as newline-delimited records "C\t<b1 b2 …>" looked up with
# awk — Bash 3.2 (macOS default) has no associative arrays. Outward sets are
# accumulated the same way.
outward_table=""   # "S\t<t1 t2 …>" : in-epic keys S Blocks (S's outward-Blocks)
while IFS= read -r s; do
  [ -z "$s" ] && continue
  links_json="$(acli jira workitem link list --key "$s" --json 2>/dev/null)"
  acli_status=$?
  if [ "$acli_status" -ne 0 ]; then
    fail "acli error resolving blocker links for $s: link list exited $acli_status"
  fi
  # outwardIssueKey of every typeName=="Blocks" link, restricted to in-epic keys.
  outward="$(printf '%s' "$links_json" \
               | jq -r '.issueLinks[]? | select(.typeName=="Blocks") | .outwardIssueKey // empty' 2>/dev/null)"
  jq_status=$?
  if [ "$jq_status" -ne 0 ]; then
    fail "acli error resolving blocker links for $s: malformed link JSON (jq exited $jq_status)"
  fi
  oset=""
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    [ "$t" = "$s" ] && continue
    # keep only in-epic targets (siblings of this epic)
    case "
$children
" in
      *"
$t
"*) oset="${oset:+$oset }$t" ;;
      *) : ;;
    esac
  done <<< "$outward"
  outward_table="${outward_table}${s}	${oset}
"
done <<< "$children"

# Invert: blockers(C) = { S : C ∈ outwardBlocks(S) }, preserving children's
# created-ASC order for both the outer (C) and inner (S) scans so the blocker
# lists — and thus the tie-break — stay deterministic.
blockers_table=""
while IFS= read -r c; do
  [ -z "$c" ] && continue
  bset=""
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    [ "$s" = "$c" ] && continue
    oset="$(printf '%s' "$outward_table" | awk -F'\t' -v key="$s" '$1==key {print $2; exit}')"
    for t in $oset; do
      if [ "$t" = "$c" ]; then
        bset="${bset:+$bset }$s"
        break
      fi
    done
  done <<< "$children"
  blockers_table="${blockers_table}${c}	${bset}
"
  echo "$c BLOCKERS=$bset"
done <<< "$children"

# 3. Stable topological sort (Kahn). Remaining = children in created-ASC order.
#    Repeatedly emit, in that stable order, every story whose blockers have all
#    already been emitted. The stable scan over the created-ASC remainder makes
#    `created ASC` the tie-break among independent (ready) stories.
remaining="$children"
order=""
emitted=" "   # space-padded membership set: " K1 K2 "

lookup_blockers() {
  # echo the blocker set for $1 from blockers_table (tab-separated).
  printf '%s' "$blockers_table" | awk -F'\t' -v key="$1" '$1==key {print $2; exit}'
}

progress=1
while [ -n "$remaining" ] && [ "$progress" -eq 1 ]; do
  progress=0
  next_remaining=""
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    bset="$(lookup_blockers "$c")"
    ready=1
    for b in $bset; do
      # A blocker only gates if it is itself an in-epic story still pending.
      case "$emitted" in
        *" $b "*) : ;;                      # already emitted — satisfied
        *)
          case "
$children
" in
            *"
$b
"*) ready=0; break ;;                       # in-epic + not yet emitted -> wait
            *) : ;;                          # out-of-epic blocker -> ignore
          esac ;;
      esac
    done
    if [ "$ready" -eq 1 ]; then
      order="${order:+$order }$c"
      emitted="${emitted}$c "
      progress=1
    else
      next_remaining="${next_remaining:+$next_remaining
}$c"
    fi
  done <<< "$remaining"
  remaining="$next_remaining"
done

# 4. Anything left in `remaining` is part of a dependency cycle (no story in it
#    became ready). Cycle-safe: STOP rather than emit a bogus order.
if [ -n "$remaining" ]; then
  cycle_keys="$(printf '%s' "$remaining" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
  fail "dependency cycle detected: $cycle_keys"
fi

echo "ORDER=$order"
echo "GATE=PASS"
