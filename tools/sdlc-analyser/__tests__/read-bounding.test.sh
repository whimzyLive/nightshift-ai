#!/usr/bin/env bash
# read-bounding.test.sh — NA-90 Gate-2 falsifiability harness for read-bounding.py.
#
# AUTHOR-RUN, ALSO CI-WIRED (orchestrator decision on NA-90's plan Open item #3):
#   bash tools/sdlc-analyser/__tests__/read-bounding.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — these fixtures are authored by the same story that authors the tool.
# A pass proves the tool does what its author intended; it is a SMOKE TEST, never a gate
# on agent behaviour. Gate 3 (a pilot on an independent story) is the only evidence
# about the contract itself.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../read-bounding.py"
fixtures="$here/fixtures/read-bounding"
fail=0

assert_contains() {
  case "$2" in
    *"$1"*) printf 'ok   %s\n' "$3" ;;
    *) printf 'FAIL %s\n     expected to contain: %s\n     got: %s\n' "$3" "$1" "$2"; fail=1 ;;
  esac
}

# --- Gate 2: the metric must reach BOTH ends, or it measures nothing ---------------
out="$(python3 "$tool" all-windowed --corpus-list "$fixtures/list-all-windowed.txt" --json 2>&1)"
assert_contains '"totalReads": 2'     "$out" "all-windowed: both Read calls counted"
assert_contains '"windowedReads": 2'  "$out" "all-windowed: both calls detected as windowed"
assert_contains '"windowedShare": 1.0' "$out" "all-windowed: windowedShare reaches 1.0"

out="$(python3 "$tool" all-whole --corpus-list "$fixtures/list-all-whole.txt" --json 2>&1)"
assert_contains '"totalReads": 2'      "$out" "all-whole: both Read calls counted"
assert_contains '"windowedReads": 0'   "$out" "all-whole: no call detected as windowed"
assert_contains '"windowedShare": 0.0' "$out" "all-whole: windowedShare reaches 0.0"

# --- The corpus partition is always printed, both counts, always ------------------
assert_contains '"topLevelTranscripts": 1' "$out" "corpus: top-level partition count emitted"
assert_contains '"subagentTranscripts": 0' "$out" "corpus: subagent partition count emitted"

# --- The carve-out is load-bearing: 68.7% of addressable reads are under the cap ---
out="$(python3 "$tool" carve-out --corpus-list "$fixtures/list-carve-out.txt" --json 2>&1)"
assert_contains '"windowLines": 400'          "$out" "carve-out: window cap defaults to 400 lines"
assert_contains '"carveOutEligibleReads": 2'  "$out" "carve-out: both under-cap reads are eligible"
assert_contains '"carveOutHits": 1'           "$out" "carve-out: the whole under-cap read is a hit"
assert_contains '"carveOutMisses": 1'         "$out" "carve-out: the windowed under-cap read is a miss"
assert_contains '"carveOutHitRate": 0.5'      "$out" "carve-out: hit rate is hits / eligible"
assert_contains '"unmatchedCalls": 0'         "$out" "carve-out: every call matched a result"
assert_contains '"storiesObserved": 1'        "$out" "per-story: one story key observed"

out="$(python3 "$tool" carve-out --corpus-list "$fixtures/list-carve-out.txt" --window-lines 1000 --json 2>&1)"
assert_contains '"carveOutEligibleReads": 4'  "$out" "--window-lines widens the eligible set"

# --- Error handling: every row of the spec's table, exercised --------------------
out="$(python3 "$tool" edge --corpus-list "$fixtures/list-edge-cases.txt" --json 2>&1)"
assert_contains '"skippedLines": 1'  "$out" "unparseable line is skipped and counted"
assert_contains '"unmatchedCalls": 1' "$out" "a Read with no tool_result is excluded from volume"
assert_contains '"totalReads": 1'    "$out" "non-Read tool_use is ignored"

python3 "$tool" nope /nonexistent/does-not-exist.jsonl >/dev/null 2>&1
[ "$?" -eq 1 ] && printf 'ok   %s\n' "unresolvable corpus exits 1" \
  || { printf 'FAIL %s\n' "unresolvable corpus must exit 1"; fail=1; }

python3 "$tool" bad --corpus-list "$fixtures/list-all-whole.txt" --threshold abc >/dev/null 2>&1
[ "$?" -eq 2 ] && printf 'ok   %s\n' "non-numeric --threshold exits 2" \
  || { printf 'FAIL %s\n' "non-numeric --threshold must exit 2"; fail=1; }

err="$(python3 "$tool" nosub --corpus-list "$fixtures/list-all-whole.txt" --json 2>&1 >/dev/null)"
assert_contains 'subagents' "$err" "zero subagent transcripts prints the loud glob WARNING"

exit "$fail"
