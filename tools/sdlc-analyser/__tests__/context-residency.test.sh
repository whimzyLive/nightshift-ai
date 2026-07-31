#!/usr/bin/env bash
# context-residency.test.sh — NA-91 Gate-2 falsifiability harness for context-residency.py.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash tools/sdlc-analyser/__tests__/context-residency.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — these fixtures are authored by the same story that authors the tool. A pass
# proves the tool does what its author intended; it is a SMOKE TEST, never a gate on session
# behaviour. Gate 3 (a pilot on an independent story) is the only evidence about the boundary
# itself. Falsifiability: the metric must return 0.0, 0.5 and 1.0 over the three fixed corpora
# — a tool returning one number against all three would be incapable of measuring anything.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../context-residency.py"
fixtures="$here/fixtures/context-residency"
fail=0

assert_contains() {
  case "$2" in
    *"$1"*) printf 'ok   %s\n' "$3" ;;
    *) printf 'FAIL %s\n     expected to contain: %s\n     got: %s\n' "$3" "$1" "$2"; fail=1 ;;
  esac
}

# --- Gate 2: the metric must reach BOTH ends AND a middle value --------------------
out="$(python3 "$tool" no-boundary --corpus-list "$fixtures/list-no-boundary.txt" --json 2>/dev/null)"
assert_contains '"assistantTurns": 4'      "$out" "no-boundary: four assistant turns counted"
assert_contains '"toolResultExposure": 12' "$out" "no-boundary: byte-turn exposure summed"
assert_contains '"boundaryTurn": null'     "$out" "no-boundary: no PR raise -> null boundary"
assert_contains '"inheritedShare": 0.0'    "$out" "no-boundary: inheritedShare reaches 0.0"
assert_contains '"cacheReadRatio": 0.9'    "$out" "no-boundary: cache-read ratio computed"

out="$(python3 "$tool" full-inherit --corpus-list "$fixtures/list-full-inherit.txt" --json 2>/dev/null)"
assert_contains '"boundaryTurn": 1'         "$out" "full-inherit: gh pr create detected at turn 1"
assert_contains '"inheritedExposure": 12'   "$out" "full-inherit: all exposure is inherited"
assert_contains '"inheritedShare": 1.0'     "$out" "full-inherit: inheritedShare reaches 1.0"

out="$(python3 "$tool" partial --corpus-list "$fixtures/list-partial.txt" --json 2>/dev/null)"
assert_contains '"boundaryTurn": 2'          "$out" "partial: raise-pr.sh detected at turn 2"
assert_contains '"toolResultExposure": 400'  "$out" "partial: total exposure 400 byte-turns"
assert_contains '"inheritedExposure": 200'   "$out" "partial: 200 byte-turns inherited"
assert_contains '"inheritedShare": 0.5'      "$out" "partial: inheritedShare reaches a middle value"
assert_contains 'raise-pr.sh'                "$out" "partial: the matched boundary command is reported"

# --- The control arm: --boundary none forces the boundary off ---------------------
out="$(python3 "$tool" partial-none --corpus-list "$fixtures/list-partial.txt" --boundary none --json 2>/dev/null)"
assert_contains '"boundaryTurn": null'    "$out" "--boundary none: boundary forced off"
assert_contains '"inheritedShare": 0.0'   "$out" "--boundary none: nothing is inherited"

# --- The corpus partition is always printed, both counts, always ------------------
out="$(python3 "$tool" partition --corpus-list "$fixtures/list-partial.txt" --json 2>/dev/null)"
assert_contains '"topLevelTranscripts": 1' "$out" "corpus: top-level partition count emitted"
assert_contains '"subagentTranscripts": 0' "$out" "corpus: subagent partition count emitted"

err="$(python3 "$tool" sub --corpus-list "$fixtures/list-subagent.txt" --json 2>&1 >/dev/null)"
assert_contains 'subagent' "$err" "a subagent transcript prints the loud population WARNING"

# --- Error handling: every row of the spec's table, exercised --------------------
out="$(python3 "$tool" edge --corpus-list "$fixtures/list-edge-cases.txt" --json 2>/dev/null)"
assert_contains '"skippedLines": 1'        "$out" "unparseable line is skipped and counted"
assert_contains '"toolResultExposure": 2'  "$out" "a tool_use with no result adds no exposure"

python3 "$tool" nope /nonexistent/does-not-exist.jsonl >/dev/null 2>&1
[ "$?" -eq 1 ] && printf 'ok   %s\n' "unresolvable corpus exits 1" \
  || { printf 'FAIL %s\n' "unresolvable corpus must exit 1"; fail=1; }

python3 "$tool" bad --corpus-list "$fixtures/list-partial.txt" --boundary bogus >/dev/null 2>&1
[ "$?" -eq 2 ] && printf 'ok   %s\n' "invalid --boundary exits 2" \
  || { printf 'FAIL %s\n' "invalid --boundary must exit 2"; fail=1; }

exit "$fail"
