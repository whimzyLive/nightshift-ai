#!/usr/bin/env bash
set -uo pipefail
# story-sizing.sh — the story-size bounds the scrum master slices against (rules: refs/story-sizing.md).
#
# Reads the `Min story size` and `Max story size` rows of the `## Story sizing` section of
# project-context.md and prints, in order:
#   MIN_STORY_SIZE=<n|none>     none = no floor (row absent, empty, `none` or `unset`)
#   MAX_STORY_SIZE=<n>          default 8
# Allowed values: 1 2 3 5 8 13. An invalid value or min > max exits 1 with a message on stderr and
# prints neither line: a bound is never guessed.

DEFAULT_MAX=8
ALLOWED="1 2 3 5 8 13"

die() { echo "story-sizing.sh: $*" >&2; exit 1; }

# project-context.md: this checkout first, then the primary checkout (a linked worktree of a repo
# whose context file is untracked does not have its own copy), then the session's project dir.
find_ctx() {
  local top common cand
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || common="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P || true)"
  for cand in "$top" "${common%/.git}" "${CLAUDE_PROJECT_DIR:-}" "$PWD"; do
    [ -n "$cand" ] && [ -r "$cand/.claude/project/project-context.md" ] \
      && { printf '%s' "$cand/.claude/project/project-context.md"; return 0; }
  done
  return 1
}

# <context file> <lowercase row-label regex> -> the value cell, empty when the row is absent
row_value() {
  awk -F'|' -v label="$2" '
    /^##[ \t]/ { insec = ($0 ~ /^##[ \t]+Story sizing[ \t]*$/); next }
    insec && tolower($2) ~ label {
      v = $3; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print v; exit
    }' "$1"
}

in_set() { local x; for x in $ALLOWED; do [ "$x" = "$1" ] && return 0; done; return 1; }

MIN=""; MAX=""
if ctx="$(find_ctx)"; then
  MIN="$(row_value "$ctx" '^[ \t]*min story size')"
  MAX="$(row_value "$ctx" '^[ \t]*max story size')"
fi

case "$(printf '%s' "$MIN" | tr '[:upper:]' '[:lower:]')" in "" | none | unset) MIN="" ;; esac
[ -n "$MAX" ] || MAX="$DEFAULT_MAX"

if [ -n "$MIN" ]; then
  in_set "$MIN" || die "Min story size '$MIN' in project-context.md is not one of: $ALLOWED (leave the row out for no floor)"
fi
in_set "$MAX" || die "Max story size '$MAX' in project-context.md is not one of: $ALLOWED"
if [ -n "$MIN" ] && [ "$MIN" -gt "$MAX" ]; then
  die "Min story size $MIN is greater than Max story size $MAX in project-context.md"
fi

echo "MIN_STORY_SIZE=${MIN:-none}"
echo "MAX_STORY_SIZE=$MAX"
