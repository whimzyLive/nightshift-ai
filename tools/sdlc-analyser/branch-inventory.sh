#!/usr/bin/env bash
# branch-inventory.sh — see tools/sdlc-analyser/README.md for the counting rule.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"

file=""
base_ref=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      [ $# -ge 2 ] || { echo "branch-inventory: --base requires a git ref" >&2; exit 1; }
      base_ref="$2"
      shift 2
      ;;
    *)
      [ -z "$file" ] || { echo "branch-inventory: unexpected argument: $1" >&2; exit 1; }
      file="$1"
      shift
      ;;
  esac
done

[ -n "$file" ] || { echo "branch-inventory: usage: branch-inventory.sh <file> [--base <git-ref>]" >&2; exit 1; }

if [ -n "$base_ref" ]; then
  if ! git -C "$repo_root" rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
    echo "branch-inventory: unknown git ref: $base_ref" >&2
    exit 1
  fi
fi

count_outcomes() { # reads content on stdin, prints a single integer
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    BEGIN { total = 0; row_idx = 0 }
    {
      t = trim($0)
      if (t ~ /^\|.*\|$/) {
        row_idx++
        if (row_idx > 2) total++
        next
      }
      row_idx = 0
      if (t ~ /^(if|elif|else)\b/) { total++; next }
      semis = gsub(/;;/, "&", t)
      asserts = gsub(/ASSERT/, "&", t)
      total += semis + asserts
      if (semis == 0 && asserts == 0) {
        if (t ~ /(^|[^A-Za-z])STOP([^A-Za-z]|$)/ || t ~ /blocked/) total++
      }
    }
    END { print total }
  '
}

abs_path="$repo_root/$file"
if [ ! -f "$abs_path" ] || [ ! -r "$abs_path" ]; then
  echo "FILE=$file"
  echo "OUTCOMES_HEAD=-1"
  echo "REASON=file not found or unreadable: $file"
  exit 2
fi

outcomes_head="$(count_outcomes < "$abs_path")"

if [ -n "$base_ref" ]; then
  outcomes_base="$(git -C "$repo_root" show "${base_ref}:${file}" 2>/dev/null | count_outcomes)"
  [ -n "$outcomes_base" ] || outcomes_base=0
else
  outcomes_base="$outcomes_head"
fi

if [ "$outcomes_base" -eq "$outcomes_head" ]; then
  outcomes_match="true"
else
  outcomes_match="false"
fi

echo "FILE=$file"
echo "OUTCOMES_BASE=$outcomes_base"
echo "OUTCOMES_HEAD=$outcomes_head"
echo "OUTCOMES_MATCH=$outcomes_match"

[ "$outcomes_match" = "true" ] || exit 1
