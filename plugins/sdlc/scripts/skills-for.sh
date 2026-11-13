#!/usr/bin/env bash
# skills-for.sh <agent> [--mode <m>] [--paths <glob,glob,...>] [--manifest <path>] [--contract <path>] [--print-prompt]
#
# Resolves which skills a dispatch should name, from the plugin contract rows (refs/skills-contract.json)
# merged under the repo manifest (.claude/project/skills.json). Rows merge by `name`; the repo row
# replaces the contract row entirely.
#
# Prints one line per matching row:
#   SKILL=<name> REQUIRED=yes|no STEP=<phrase or ->
# or, with --print-prompt, the block a playbook pastes into a dispatch prompt. Prints nothing when no
# row matches. Exit 2 on a malformed manifest or contract (bad JSON, version not 1 or 2, unknown agent
# name), an unknown <agent>, or a bad argument; the reason goes to stderr.
#
# A row matches when the agent is in `agents` and every present `when` filter passes:
#   paths  any dispatch path (--paths) overlaps any glob; no --paths given => matches
#   mode   --mode is listed; no --mode given => no match
#   step   never a filter, only the phrase shown to the agent
# A v1 manifest is tracked-only: its rows are never injected, and a warning goes to stderr.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
agents_dir="$here/../agents"

AGENT=""; MODE=""; PATHS=""; MANIFEST=".claude/project/skills.json"; CONTRACT=""; PRINT_PROMPT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)         MODE="${2:-}"; shift 2 ;;
    --paths)        PATHS="${2:-}"; shift 2 ;;
    --manifest)     MANIFEST="${2:-}"; shift 2 ;;
    --contract)     CONTRACT="${2:-}"; shift 2 ;;
    --print-prompt) PRINT_PROMPT=1; shift ;;
    -*) echo "skills-for.sh: unknown argument '$1'" >&2; exit 2 ;;
    *)  if [ -z "$AGENT" ]; then AGENT="$1"; shift; else echo "skills-for.sh: unexpected argument '$1'" >&2; exit 2; fi ;;
  esac
done
[ -n "$AGENT" ] || { echo "skills-for.sh: usage: skills-for.sh <agent> [--mode <m>] [--paths <globs>] [--manifest <path>] [--contract <path>] [--print-prompt]" >&2; exit 2; }
[ -n "$CONTRACT" ] || CONTRACT="${CLAUDE_PLUGIN_ROOT:-$here/..}/refs/skills-contract.json"

command -v jq >/dev/null 2>&1 || { echo "skills-for.sh: jq is required" >&2; exit 2; }

known_agents="qa-reviewer"
for f in "$agents_dir"/*.md; do
  [ -f "$f" ] && known_agents="$known_agents $(basename "$f" .md)"
done
is_known() { case " $known_agents " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

is_known "$AGENT" || { echo "skills-for.sh: unknown agent '$AGENT'" >&2; exit 2; }

# validate_file <file> <label> — exits 2 on a malformed file; sets LOADED_VERSION.
validate_file() {
  local file="$1" label="$2" version a
  jq -e . "$file" >/dev/null 2>&1 || { echo "skills-for.sh: $label is not valid JSON: $file" >&2; exit 2; }
  version="$(jq -r '.version // empty' "$file")"
  case "$version" in
    1|2) ;;
    *) echo "skills-for.sh: $label has unsupported version '$version' (expected 1 or 2): $file" >&2; exit 2 ;;
  esac
  jq -e '.skills | type == "array"' "$file" >/dev/null 2>&1 || { echo "skills-for.sh: $label has no skills array: $file" >&2; exit 2; }
  LOADED_VERSION="$version"
  [ "$version" = "2" ] || return 0
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    is_known "$a" || { echo "skills-for.sh: $label names unknown agent '$a': $file" >&2; exit 2; }
  done < <(jq -r '.skills[] | (.agents // [])[]' "$file")
}

[ -f "$CONTRACT" ] || { echo "skills-for.sh: contract not found: $CONTRACT" >&2; exit 2; }
validate_file "$CONTRACT" "contract"
[ "$LOADED_VERSION" = "2" ] || { echo "skills-for.sh: the contract must be version 2: $CONTRACT" >&2; exit 2; }
contract_rows="$(jq -c '.skills[]' "$CONTRACT")"

repo_rows=""
if [ -f "$MANIFEST" ]; then
  validate_file "$MANIFEST" "manifest"
  if [ "$LOADED_VERSION" = "1" ]; then
    echo "WARN: skills.json is v1 — run /sdlc:init to upgrade" >&2
  else
    repo_rows="$(jq -c '.skills[]' "$MANIFEST")"
  fi
fi

merged="$(printf '%s\n%s\n' "$contract_rows" "$repo_rows" | jq -c -s '
  map(select(. != null))
  | reduce .[] as $row ([]; (map(.name) | index($row.name)) as $i
      | if $i == null then . + [$row] else .[$i] = $row end)
  | .[]')"

# glob_hits <dispatch-path> <glob> — a dispatch path overlaps a glob when it matches the glob, or
# is a directory containing the glob's literal prefix.
glob_hits() {
  local p="${1%/}" g="$2" lit
  g="${g//\*\*/*}"
  # shellcheck disable=SC2053
  [[ "$p" == $g ]] && return 0
  # shellcheck disable=SC2053
  [[ "$p/x" == $g ]] && return 0
  lit="${g%%[*?[]*}"
  [ "$lit" != "$g" ] && case "$lit" in "$p"/*) return 0 ;; esac
  return 1
}

paths_match() {
  local globs="$1" g p
  [ -z "$PATHS" ] && return 0
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      glob_hits "$p" "$g" && return 0
    done < <(printf '%s\n' "$PATHS" | tr ',' '\n')
  done <<<"$globs"
  return 1
}

out=""
while IFS= read -r row; do
  [ -z "$row" ] && continue
  jq -e --arg a "$AGENT" '(.agents // []) | index($a) != null' <<<"$row" >/dev/null || continue

  modes="$(jq -r '(.when.mode // [])[]' <<<"$row")"
  if [ -n "$modes" ]; then
    [ -n "$MODE" ] || continue
    printf '%s\n' "$modes" | grep -qxF -- "$MODE" || continue
  fi

  globs="$(jq -r '(.when.paths // [])[]' <<<"$row")"
  if [ -n "$globs" ]; then
    paths_match "$globs" || continue
  fi

  name="$(jq -r '.name' <<<"$row")"
  required="$(jq -r 'if .required == false then "no" else "yes" end' <<<"$row")"
  step="$(jq -r '.when.step // "-"' <<<"$row")"
  [ -n "$step" ] || step="-"
  out+="$name"$'\t'"$required"$'\t'"$step"$'\n'
done <<<"$merged"

[ -n "$out" ] || exit 0

if [ "$PRINT_PROMPT" -eq 1 ]; then
  echo "Skills for this dispatch (invoke each with the Skill tool at the step named, never earlier):"
  while IFS=$'\t' read -r name required step; do
    [ -z "$name" ] && continue
    if [ "$required" = "yes" ]; then
      [ "$step" = "-" ] && phrase="required: before starting work" || phrase="required: before ${step#before }"
    else
      [ "$step" = "-" ] && phrase="optional: if it applies" || phrase="optional: if ${step#when } applies"
    fi
    echo "- $name — $phrase"
  done <<<"$out"
else
  while IFS=$'\t' read -r name required step; do
    [ -z "$name" ] && continue
    echo "SKILL=$name REQUIRED=$required STEP=$step"
  done <<<"$out"
fi
