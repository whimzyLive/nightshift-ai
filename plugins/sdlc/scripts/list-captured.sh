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
# shellcheck source=/dev/null
. "$here/memory-root.sh"

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

# Root list, newline-delimited, in precedence order. SDLC_CAPTURE_ROOT stays FIRST and unmodified:
# when it is set it is the only root, exactly as before.
roots=""
if [ -n "${SDLC_CAPTURE_ROOT:-}" ]; then
  roots="$SDLC_CAPTURE_ROOT"
else
  # A hasher on the success path can write to stderr while still exiting 0 (e.g. macOS
  # /usr/bin/shasum is Perl and warns on a locale mismatch) — 2>&1 on the success call would
  # contaminate $resolved with that warning text. Only re-invoke with 2>&1 to capture the reason
  # AFTER a plain 2>/dev/null call has already established failure; the resolver is side-effect
  # free on --print-root, so a second call is safe.
  resolver_err=""
  if ! resolved="$(sdlc_memory_root 2>/dev/null)" || [ -z "$resolved" ]; then
    resolver_err="$(sdlc_memory_root 2>&1 >/dev/null)"
    resolved=""
  fi
  # NA-101 transition shim: capture-learning.sh wrote into the PRIMARY checkout before this story,
  # and those files are untracked + gitignored, so a `git rev-parse --show-toplevel` probe from a
  # linked worktree would make every already-staged capture invisible. Use sdlc_primary_worktree,
  # never git-toplevel. NA-102 removes this fallback with the corpus move.
  legacy=""
  primary="$(sdlc_primary_worktree 2>/dev/null)" || primary=""
  [ -n "$primary" ] && legacy="$primary/.claude/memories/captured"
  if [ -z "$resolved" ]; then
    if [ -n "$legacy" ] && [ -d "$legacy" ]; then
      printf 'list-captured.sh: WARNING — %s; listing the legacy in-repo staging root only\n' \
        "${resolver_err:-cannot resolve the memory root}" >&2
    else
      printf 'list-captured.sh: cannot resolve the staging root — %s\n' \
        "${resolver_err:-memory-root.sh could not resolve a root}" >&2
      exit 1
    fi
  fi
  [ -n "$resolved" ] && [ -d "$resolved/captured" ] && roots="$resolved/captured"
  [ -n "$legacy" ] && [ -d "$legacy" ] && roots="$roots${roots:+
}$legacy"
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

seen=""
seen_has() { printf '%s' "$seen" | grep -qxF "$1"; }
seen_add() { seen="$seen$1
"; }

scan() { # $1 = rule|review, $2 = root
  local d="$2/$1s" file p id story cap promote summary agents dedupe_key
  [ -d "$d" ] || return 0
  for file in "$d"/*.md; do
    dedupe_key="$1/$(basename "$file")"
    seen_has "$dedupe_key" && continue
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
    seen_add "$dedupe_key"
    emit "$file" "$1" "$id" "$story" "$cap" "$promote" "$summary" "$agents"
  done
}

if [ -n "$roots" ]; then
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ "$f_kind" = "review" ] || scan rule "$r"
    [ "$f_kind" = "rule" ]   || scan review "$r"
  done <<< "$roots"
fi
[ "$as_json" -eq 1 ] && printf '{"entries":[%s],"count":%s}\n' "$entries" "$count"
exit 0
