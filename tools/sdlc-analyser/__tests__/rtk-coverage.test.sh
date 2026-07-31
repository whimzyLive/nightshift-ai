#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../rtk-coverage.py"
fixtures="$here/fixtures/rtk-coverage"
fail=0

assert_contains() {
  case "$2" in
    *"$1"*) printf 'ok   %s\n' "$3" ;;
    *) printf 'FAIL %s\n     expected to contain: %s\n     got: %s\n' "$3" "$1" "$2"; fail=1 ;;
  esac
}

out="$(python3 "$tool" --engine --corpus-list "$fixtures/list.txt" --json 2>&1)"
assert_contains '"bashCalls": 5' "$out" "loads 5 Bash commands, skips non-Bash tool_use"

out="$(python3 "$tool" --engine --corpus-list "$fixtures/list.txt" --json 2>&1)"
assert_contains '"multiLine": 3'            "$out" "counts multi-line calls"
assert_contains '"guardHeredoc": 1'         "$out" "subtracts the heredoc-guarded rewrite"
assert_contains '"guardExclude": 1'         "$out" "subtracts the EXCLUDE-guarded rewrite"
assert_contains '"achievablePermitted": 3'  "$out" "permitted = raw - heredoc - EXCLUDE"
assert_contains '"rewrites": 1'             "$out" "engine mode scans line 1 only"

exit "$fail"
