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
#
# JSON fields are read via python3 extraction, never a whole-blob substring grep — a substring
# check like `assert_contains '"totalReads": 2'` also passes for `"totalReads": 22` (2 is a
# literal prefix of 22), so it cannot catch a wrong value, only a missing one. Ported from the
# top_field()/unit_field() pattern in work-placement.test.sh (NA-92).
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../read-bounding.py"
fixtures="$here/fixtures/read-bounding"
fail=0

field() { # <json> <dotted-field>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
cur = d
for p in '$2'.split('.'):
    cur = cur[p]
print(cur)
"
}

assert_eq() { # <label> <actual> <expected>
  [ "$2" = "$3" ] && printf 'ok   %s\n' "$1" \
    || { printf 'FAIL %s\n     expected: %s\n     got:      %s\n' "$1" "$3" "$2"; fail=1; }
}

assert_contains() {
  case "$2" in
    *"$1"*) printf 'ok   %s\n' "$3" ;;
    *) printf 'FAIL %s\n     expected to contain: %s\n     got: %s\n' "$3" "$1" "$2"; fail=1 ;;
  esac
}

# --- Gate 2: the metric must reach BOTH ends, or it measures nothing ---------------
out="$(python3 "$tool" all-windowed --corpus-list "$fixtures/list-all-windowed.txt" --json 2>/dev/null)"
assert_eq "all-windowed: both Read calls counted"           "$(field "$out" totalReads)"    "2"
assert_eq "all-windowed: both calls detected as windowed"   "$(field "$out" windowedReads)" "2"
assert_eq "all-windowed: windowedShare reaches 1.0"          "$(field "$out" windowedShare)" "1.0"

out="$(python3 "$tool" all-whole --corpus-list "$fixtures/list-all-whole.txt" --json 2>/dev/null)"
assert_eq "all-whole: both Read calls counted"      "$(field "$out" totalReads)"    "2"
assert_eq "all-whole: no call detected as windowed" "$(field "$out" windowedReads)" "0"
assert_eq "all-whole: windowedShare reaches 0.0"    "$(field "$out" windowedShare)" "0.0"

# --- The corpus partition is always printed, both counts, always ------------------
assert_eq "corpus: top-level partition count emitted" "$(field "$out" corpus.topLevelTranscripts)" "1"
assert_eq "corpus: subagent partition count emitted"  "$(field "$out" corpus.subagentTranscripts)" "0"

# --- The carve-out is load-bearing: 68.7% of addressable reads are under the cap ---
out="$(python3 "$tool" carve-out --corpus-list "$fixtures/list-carve-out.txt" --json 2>/dev/null)"
assert_eq "carve-out: window cap defaults to 400 lines"           "$(field "$out" windowLines)"            "400"
assert_eq "carve-out: both under-cap reads are eligible"          "$(field "$out" carveOutEligibleReads)"  "2"
assert_eq "carve-out: the whole under-cap read is a hit"          "$(field "$out" carveOutHits)"            "1"
assert_eq "carve-out: the windowed under-cap read is a miss"      "$(field "$out" carveOutMisses)"          "1"
assert_eq "carve-out: hit rate is hits / eligible"                "$(field "$out" carveOutHitRate)"         "0.5"
assert_eq "carve-out: every call matched a result"                "$(field "$out" unmatchedCalls)"          "0"
assert_eq "per-story: one story key observed"                     "$(field "$out" storiesObserved)"         "1"

out="$(python3 "$tool" carve-out --corpus-list "$fixtures/list-carve-out.txt" --window-lines 1000 --json 2>/dev/null)"
assert_eq "--window-lines widens the eligible set" "$(field "$out" carveOutEligibleReads)" "4"

# --- Error handling: every row of the spec's table, exercised --------------------
out="$(python3 "$tool" edge --corpus-list "$fixtures/list-edge-cases.txt" --json 2>/dev/null)"
assert_eq "unparseable line is skipped and counted"                 "$(field "$out" skippedLines)"    "1"
assert_eq "a Read with no tool_result is excluded from volume"      "$(field "$out" unmatchedCalls)"  "1"
assert_eq "non-Read tool_use is ignored"                            "$(field "$out" totalReads)"      "1"

python3 "$tool" nope /nonexistent/does-not-exist.jsonl >/dev/null 2>&1
[ "$?" -eq 1 ] && printf 'ok   %s\n' "unresolvable corpus exits 1" \
  || { printf 'FAIL %s\n' "unresolvable corpus must exit 1"; fail=1; }

python3 "$tool" bad --corpus-list "$fixtures/list-all-whole.txt" --threshold abc >/dev/null 2>&1
[ "$?" -eq 2 ] && printf 'ok   %s\n' "non-numeric --threshold exits 2" \
  || { printf 'FAIL %s\n' "non-numeric --threshold must exit 2"; fail=1; }

err="$(python3 "$tool" nosub --corpus-list "$fixtures/list-all-whole.txt" --json 2>&1 >/dev/null)"
assert_contains 'subagents' "$err" "zero subagent transcripts prints the loud glob WARNING"

exit "$fail"
