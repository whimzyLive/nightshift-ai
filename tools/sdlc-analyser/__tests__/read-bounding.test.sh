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

exit "$fail"
