#!/usr/bin/env bash
# work-placement.test.sh — NA-92 falsifiability harness for work-placement.py.
#
# AUTHOR-RUN AND CI-WIRED (orchestrator resolution 5; an author-run instrument is not a guard):
#   bash tools/sdlc-analyser/__tests__/work-placement.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — these fixtures are authored by the same story that authors the tool.
# A pass proves the tool does what its author intended; it is a SMOKE TEST, never a gate
# on agent behaviour. The pilot (a story NA-92 does not author) is the only evidence
# about the contract itself.
#
# Falsifiability: subagentShare must reach 0.0, 0.5 AND 1.0, and returnCapExceeded must reach
# BOTH true and false. A metric that can only report one value is not evidence.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../work-placement.py"
fixtures="$here/fixtures/work-placement"
fail=0

assert_contains() {
  case "$2" in
    *"$1"*) printf 'ok   %s\n' "$3" ;;
    *) printf 'FAIL %s\n     expected to contain: %s\n     got: %s\n' "$3" "$1" "$2"; fail=1 ;;
  esac
}

# --- The metric must reach 0.0 -------------------------------------------------------
out="$(python3 "$tool" all-top --corpus-list "$fixtures/list-all-top-level.txt" --json 2>&1)"
for u in G1 G2 G3; do assert_contains '"subagentShare": 0.0' "$out" "all-top-level: $u share 0.0"; done
assert_contains '"returnCapExceeded": false' "$out" "all-top-level: cap not exceeded"

# --- ...and 1.0, including the T3 tier a non-recursive glob would miss ---------------
out="$(python3 "$tool" all-sub --corpus-list "$fixtures/list-all-subagent.txt" --json 2>&1)"
assert_contains '"subagentShare": 1.0' "$out" "all-subagent: share reaches 1.0"
assert_contains '"id": "G3"' "$out" "all-subagent: the T3-only G3 signature is resolved (rglob)"

# --- ...and a middle value ----------------------------------------------------------
out="$(python3 "$tool" mixed --corpus-list "$fixtures/list-mixed.txt" --json 2>&1)"
assert_contains '"subagentShare": 0.5' "$out" "mixed: share reaches 0.5"

# --- The round-trip detector must reach BOTH values ---------------------------------
out="$(python3 "$tool" over --corpus-list "$fixtures/list-oversize-return.txt" --json 2>&1)"
assert_contains '"returnCapExceeded": true' "$out" "oversize: the round-trip detector fires"
assert_contains '"returnCapBytes": 2000' "$out" "oversize: G1 cap is 2000"

# --- The corpus partition is always printed, both counts, always --------------------
assert_contains '"topLevelTranscripts"' "$out" "corpus: top-level partition count emitted"
assert_contains '"subagentTranscripts"' "$out" "corpus: subagent partition count emitted"

# --- Error handling: every row of the spec's table, exercised -----------------------
out="$(python3 "$tool" edge --corpus-list "$fixtures/list-edge-cases.txt" --json 2>&1)"
assert_contains '"skippedLines": 1' "$out" "unparseable line is skipped and counted"

python3 "$tool" nope /nonexistent/does-not-exist.jsonl >/dev/null 2>&1
[ "$?" -eq 1 ] && printf 'ok   %s\n' "unresolvable corpus exits 1" \
  || { printf 'FAIL %s\n' "unresolvable corpus must exit 1"; fail=1; }

err="$(python3 "$tool" not3 --corpus-list "$fixtures/list-all-top-level.txt" --json 2>&1 >/dev/null)"
assert_contains 'workflows' "$err" "zero T3 transcripts prints the loud rglob WARNING"

exit "$fail"
