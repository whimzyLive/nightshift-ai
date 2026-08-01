#!/usr/bin/env bash
# docs-sync-gate.sh — NA-92. The Step-6.5 manifest + change-size gate, as a script.
#
# Usage: docs-sync-gate.sh <STORY-KEY> <BRANCH_PREFIX> <BASE-BRANCH>
#
# stdout — exactly two lines, first-match-wins, cap 200 B:
#   DOCS_GATE=skip-no-manifest | skip-no-tracked-files | dispatch | dispatch-unresolvable
#   REASON=<one line>
# exit 0 ALWAYS. The gate never halts the run; the orchestrator owns the consequence.
#
# FAIL SAFE, verbatim from the playbook this replaces: an unreadable probe resolves toward
# DISPATCHING, never toward skipping. A gate that silently skipped docs regeneration on an
# unreadable probe would be a worse defect than the overhead it exists to close.
#
# This script carries NO judgment — three deterministic set operations. It decides `skip` only
# when it can FULLY resolve both sides; anything it cannot resolve is `dispatch-unresolvable`.
set -uo pipefail

key="${1:-}"; prefix="${2:-}"; base="${3:-}"
emit() { printf 'DOCS_GATE=%s\nREASON=%s\n' "$1" "$2"; exit 0; }
[ -n "$key" ] && [ -n "$prefix" ] && [ -n "$base" ] \
  || emit dispatch-unresolvable "usage: docs-sync-gate.sh <STORY-KEY> <BRANCH_PREFIX> <BASE-BRANCH>"

# expand_token <token> — flat, non-nested {a,b,...} brace alternation only. Repeats until no
# brace remains, so multiple SEPARATE groups in one token (e.g. plugins/{a,b}/{c,d}/x) each
# expand — the cartesian product of both groups. Prints one expanded token per line and returns
# 0 on success. Returns 1 (prints nothing) on anything it cannot fully resolve — a nested brace,
# an unmatched brace, or a brace with no comma inside — the caller reads that as unresolvable.
# NEVER guess: an ambiguous shape stays unresolvable, per this script's fail-safe contract.
expand_token() {
  local results
  results="$1"
  local pass=0
  while :; do
    pass=$((pass + 1))
    [ "$pass" -gt 8 ] && return 1
    local any=0
    local next=""
    local cand
    while IFS= read -r cand; do
      [ -z "$cand" ] && continue
      case "$cand" in
        *'{'*)
          any=1
          case "$cand" in *'{'*'}'*) : ;; *) return 1 ;; esac
          pre="${cand%%\{*}"
          rest="${cand#*\{}"
          group="${rest%%\}*}"
          suf="${rest#*\}}"
          case "$group" in *'{'*) return 1 ;; esac
          case "$group" in *,*) : ;; *) return 1 ;; esac
          local old_ifs="$IFS"
          IFS=','
          local alt
          for alt in $group; do
            next="${next}${pre}${alt}${suf}
"
          done
          IFS="$old_ifs"
          ;;
        *)
          next="${next}${cand}
"
          ;;
      esac
    done <<BRACEEOF
$results
BRACEEOF
    results="$next"
    [ "$any" -eq 0 ] && break
  done
  printf '%s' "$results"
  return 0
}

# 1. Manifest, resolved checkout-independently from the base branch.
manifest="$(git show "origin/$base:.claude/project/docs-manifest.md" 2>/dev/null)" \
  || emit skip-no-manifest "no .claude/project/docs-manifest.md at origin/$base — repo opted out of docs"
[ -n "$manifest" ] \
  || emit skip-no-manifest "empty .claude/project/docs-manifest.md at origin/$base"

# 2. Changed-file set, story-branch-vs-base.
git fetch origin --quiet 2>/dev/null
changed="$(git diff --name-only "origin/$base...$prefix/$key" 2>/dev/null)" \
  || emit dispatch-unresolvable "cannot resolve origin/$base...$prefix/$key — dispatching (fail safe)"
[ -n "$changed" ] \
  || emit dispatch-unresolvable "empty diff for $prefix/$key — cannot confirm a skip (fail safe)"

# 3. Activated row scopes. A scope this script cannot fully expand is UNRESOLVABLE, not ignored.
#    Row form: | type | enabled | target-path | source | contract |
scopes=""
enabled_ref=0
while IFS= read -r line; do
  case "$line" in \|*)
    t="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')"
    en="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
    src="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$5); print $5}')"
    con="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$6); print $6}')"
    case "$t" in type|---*|'') continue ;; esac
    [ "$en" = "true" ] || continue
    case "$t" in *-reference|llms-txt) enabled_ref=1 ;; esac
    for s in $src $con; do
      case "$s" in scan:) continue ;; esac
      case "$s" in
        *'{'*)
          expanded="$(expand_token "$s")" || \
            emit dispatch-unresolvable "unexpandable scope '$s' on row '$t' — dispatching (fail safe)"
          while IFS= read -r ex; do
            [ -n "$ex" ] && scopes="${scopes:+$scopes }$ex"
          done <<EXPEOF
$expanded
EXPEOF
          ;;
        *) scopes="${scopes:+$scopes }$s" ;;
      esac
    done
  ;; esac
done <<EOF
$manifest
EOF

# reference-roots apply when any reference-* / llms-txt row is enabled.
if [ "$enabled_ref" -eq 1 ]; then
  roots="$(printf '%s\n' "$manifest" | sed -n 's/^reference-roots:[[:space:]]*//p' | head -1 | tr ',' ' ')"
  [ -n "$roots" ] || emit dispatch-unresolvable "reference rows enabled but no reference-roots: line — dispatching (fail safe)"
  scopes="${scopes:+$scopes }$roots"
fi
[ -n "$scopes" ] || emit dispatch-unresolvable "no resolvable activated scopes — dispatching (fail safe)"

# 4. Intersect. A single hit is enough.
for f in $changed; do
  for s in $scopes; do
    s="${s%/}"
    case "$f" in
      "$s"|"$s"/*) emit dispatch "$f falls inside activated scope $s" ;;
      $s)          emit dispatch "$f matches activated glob $s" ;;
    esac
  done
done

emit skip-no-tracked-files "none of the $(printf '%s\n' "$changed" | wc -l | tr -d ' ') changed files fall in an activated scope"
