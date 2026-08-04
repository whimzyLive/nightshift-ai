#!/usr/bin/env bash
# list-captured.sh — NA-98. Enumerate the learning-capture corpus.
#
# usage: list-captured.sh [--json] [--story <STORY-KEY>] [--kind rule|review] [--agent <agent-name>]
#
# Default output: one TAB-separated line per entry — path, kind, id, story, promoteTarget, summary.
# Reads exactly one environment variable, SDLC_CAPTURE_ROOT. Never reads stdin.
set -uo pipefail
shopt -s nullglob

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/frontmatter-lib.sh"

as_json=0; f_story=""; f_kind=""; f_agent=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json)   as_json=1 ;;
    --story)  shift; f_story="${1:-}" ;;
    --kind)   shift; f_kind="${1:-}" ;;
    --agent)  shift; f_agent="${1:-}" ;;
    *) printf 'list-captured.sh: unknown argument %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done
case "$f_kind" in ""|rule|review) : ;; *) printf 'list-captured.sh: --kind must be rule or review\n' >&2; exit 1 ;; esac

if [ -n "${SDLC_CAPTURE_ROOT:-}" ]; then
  root="$SDLC_CAPTURE_ROOT"
else
  porcelain="$(git worktree list --porcelain 2>/dev/null)" || {
    printf "list-captured.sh: 'git worktree list --porcelain' failed — cannot resolve the staging root\n" >&2
    exit 1
  }
  printf '%s\n' "$porcelain" | head -3 | grep -q '^bare$' && {
    printf 'list-captured.sh: main repository is bare — no primary checkout to enumerate\n' >&2
    exit 1
  }
  main="$(printf '%s\n' "$porcelain" | sed -n 's/^worktree //p' | head -1)"
  [ -n "$main" ] || {
    printf "list-captured.sh: no 'worktree ' entry in git worktree list output — cannot resolve the staging root\n" >&2
    exit 1
  }
  root="$main/.claude/memories/captured"
fi

json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
json_arr() { local o="" i; [ -z "$1" ] && { printf '[]'; return; }
  IFS=',' read -r -a xs <<< "$1"; for i in "${xs[@]}"; do o="$o${o:+,}\"$(json_esc "$i")\""; done; printf '[%s]' "$o"; }

entries=""; count=0
emit() { # path kind id story captured promote summary agents
  if [ "$as_json" -eq 1 ]; then
    entries="$entries${entries:+,}{\"kind\":\"$2\",\"path\":\"$(json_esc "$1")\",\"id\":\"$(json_esc "$3")\",\"story\":\"$(json_esc "$4")\",\"captured\":\"$(json_esc "$5")\",\"promoteTarget\":\"$(json_esc "$6")\",\"summary\":\"$(json_esc "$7")\",\"agents\":$(json_arr "$8")}"
  else
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$6" "$7"
  fi
  count=$((count + 1))
}

scan() { # $1 = rule|review
  local d="$root/$1s" file p id story cap promote summary agents
  [ -d "$d" ] || return 0
  for file in "$d"/*.md; do
    p="$(extract_fm "$file" | parse_frontmatter)"
    if [ -z "$p" ]; then printf 'list-captured.sh: skipping malformed capture %s\n' "$file" >&2; continue; fi
    story="$(field_value "$p" story)"; cap="$(field_value "$p" captured)"
    promote="$(field_value "$p" promote-target)"
    if [ "$1" = "rule" ]; then
      id="$(field_value "$p" id)"; agents="$(field_value "$p" agent)"; summary="$(field_value "$p" rule)"
    else
      id="$(basename "$file" .md)"; agents="$(field_value "$p" domains)"
      summary="$(field_value "$p" issue_count) findings — $(printf '%s' "$(field_value "$p" root_causes)" | sed 's/,/, /g')"
    fi
    if [ -z "$story" ] || [ -z "$promote" ]; then
      printf 'list-captured.sh: skipping malformed capture %s\n' "$file" >&2; continue
    fi
    [ -n "$f_story" ] && [ "$f_story" != "$story" ] && continue
    if [ -n "$f_agent" ]; then
      [ -z "$agents" ] && continue
      list_contains "$agents" "$f_agent" || continue
    fi
    emit "$file" "$1" "$id" "$story" "$cap" "$promote" "$summary" "$agents"
  done
}

if [ -n "$root" ]; then
  [ "$f_kind" = "review" ] || scan rule
  [ "$f_kind" = "rule" ]   || scan review
fi
[ "$as_json" -eq 1 ] && printf '{"entries":[%s],"count":%s}\n' "$entries" "$count"
exit 0
