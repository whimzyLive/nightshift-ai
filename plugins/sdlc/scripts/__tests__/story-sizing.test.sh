#!/usr/bin/env bash
# story-sizing.test.sh — story-sizing.sh bounds (defaults, both rows, 13, invalid, min > max)
# in a temp git repo.
#   bash plugins/sdlc/scripts/__tests__/story-sizing.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../story-sizing.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q

# write_ctx <rows|NONE|NOFILE>: a Story sizing section placed after decoy rows in another section.
write_ctx() {
  rm -rf "$repo/.claude"
  [ "$1" = NOFILE ] && return 0
  mkdir -p "$repo/.claude/project"
  {
    printf '# Project Context\n\n## Memory\n\n| Token | Value |\n| --- | --- |\n| Min story size | `13` |\n| Max story size | `1` |\n\n'
    [ "$1" = NONE ] || printf '## Story sizing\n\n| Token | Value |\n| --- | --- |\n%b\n\n## CI\n\n| Token | Value |\n| --- | --- |\n| Max attempts | `5` |\n' "$1"
  } > "$repo/.claude/project/project-context.md"
}

pass=0 fail=0
check() { # <name> <want_rc> <want output on one line>
  local name="$1" want_rc="$2" want="$3" out rc
  out="$(cd "$repo" && CLAUDE_PROJECT_DIR= bash "$src" 2>/dev/null)"; rc=$?
  out="$(printf '%s' "$out" | tr '\n' ' ')"; out="${out% }"
  if [ "$rc" -eq "$want_rc" ] && [ "$out" = "$want" ]; then
    pass=$((pass + 1)); echo "ok   $name"
  else
    fail=$((fail + 1)); echo "FAIL $name (rc=$rc, want $want_rc, out '$out', want '$want')"
  fi
}

write_ctx NONE
check "no section -> no floor, ceiling 8 (decoy rows elsewhere ignored)" 0 "MIN_STORY_SIZE=none MAX_STORY_SIZE=8"
write_ctx NOFILE
check "no context file -> defaults" 0 "MIN_STORY_SIZE=none MAX_STORY_SIZE=8"
write_ctx '| Max story size | 5 |'
check "only max set" 0 "MIN_STORY_SIZE=none MAX_STORY_SIZE=5"
write_ctx '| Min story size | `3` |'
check "only min set, max stays 8" 0 "MIN_STORY_SIZE=3 MAX_STORY_SIZE=8"
write_ctx '| Min story size | `3` |\n| Max story size | `8` |'
check "both rows set" 0 "MIN_STORY_SIZE=3 MAX_STORY_SIZE=8"
write_ctx '| Min story size | 5 |\n| Max story size | 13 |'
check "13 allowed as max" 0 "MIN_STORY_SIZE=5 MAX_STORY_SIZE=13"
write_ctx '| Min story size | 13 |\n| Max story size | 13 |'
check "min equal to max allowed" 0 "MIN_STORY_SIZE=13 MAX_STORY_SIZE=13"
write_ctx '| Min story size | none |'
check "min none -> no floor" 0 "MIN_STORY_SIZE=none MAX_STORY_SIZE=8"
write_ctx '| Min story size |  |'
check "min empty -> no floor" 0 "MIN_STORY_SIZE=none MAX_STORY_SIZE=8"
write_ctx '| Max story size | 4 |'
check "max outside the Fibonacci set -> non-zero, no output" 1 ""
write_ctx '| Max story size | 21 |'
check "max above 13 -> non-zero" 1 ""
write_ctx '| Min story size | 4 |'
check "min outside the set -> non-zero" 1 ""
write_ctx '| Max story size | lots |'
check "max not a number -> non-zero" 1 ""
write_ctx '| Min story size | 13 |'
check "min above the default max -> non-zero" 1 ""
write_ctx '| Min story size | 8 |\n| Max story size | 5 |'
check "min > max -> non-zero" 1 ""

msg="$(cd "$repo" && bash "$src" 2>&1 >/dev/null)"
case "$msg" in
  *"greater than Max story size"*) pass=$((pass + 1)); echo "ok   min > max message is clear" ;;
  *) fail=$((fail + 1)); echo "FAIL min > max message: '$msg'" ;;
esac

echo "story-sizing: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
