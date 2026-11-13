#!/usr/bin/env bash
# check-commits.sh <rev-range> [<repo-dir>] — checks that every non-merge commit in the range has a
# conventional subject: `type(scope)!?: subject`, type one of feat fix docs style refactor perf test
# build ci chore revert, scope optional.
#
#   exit 0  OK (an empty range is OK)
#   exit 1  one `BAD=<short-sha> <subject>` line per offending commit
#   exit 2  bad arguments or an unresolvable range

set -uo pipefail

range="${1:-}"
repo="${2:-.}"
[ -n "$range" ] || { echo "check-commits.sh: usage: check-commits.sh <rev-range> [<repo-dir>]" >&2; exit 2; }

log="$(git -C "$repo" log --no-merges --format='%h%x09%s' "$range" 2>/dev/null)" \
  || { echo "check-commits.sh: cannot resolve range '$range' in $repo" >&2; exit 2; }

pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9._/-]+\))?!?: .+'
bad=""
while IFS=$'\t' read -r sha subject; do
  [ -z "$sha" ] && continue
  printf '%s\n' "$subject" | grep -qE "$pattern" || bad+="BAD=$sha $subject"$'\n'
done <<<"$log"

if [ -n "$bad" ]; then
  printf '%s' "$bad"
  exit 1
fi
echo "check-commits: OK"
