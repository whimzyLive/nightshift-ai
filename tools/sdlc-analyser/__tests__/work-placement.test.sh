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
#
# Per-unit fields are read via python3 JSON extraction, never a whole-blob substring grep —
# a substring check like `assert_contains '"subagentShare": 1.0'` passes as long as ANY unit
# reports 1.0, so it cannot catch a regression isolated to one unit (e.g. G3 resolving via a
# non-recursive glob while G1/G2 still resolve via a shallower pattern). This was caught while
# authoring this harness: the original substring form stayed green under the F-11 perturbation.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../work-placement.py"
fixtures="$here/fixtures/work-placement"
fail=0

unit_field() { # <json> <unit-id> <field>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
u = next((x for x in d['units'] if x['id'] == '$2'), None)
print('MISSING-UNIT' if u is None else u['$3'])
"
}

top_field() { # <json> <field>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['$2'])
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

# --- The metric must reach 0.0, per unit -------------------------------------------
out="$(python3 "$tool" all-top --corpus-list "$fixtures/list-all-top-level.txt" --json 2>/dev/null)"
for u in G1 G2 G3; do
  assert_eq "all-top-level: $u share == 0.0" "$(unit_field "$out" "$u" subagentShare)" "0.0"
  assert_eq "all-top-level: $u returnCapExceeded == False" "$(unit_field "$out" "$u" returnCapExceeded)" "False"
done

# --- ...and 1.0, per unit, including the T3-only G3 signature -----------------------
out="$(python3 "$tool" all-sub --corpus-list "$fixtures/list-all-subagent.txt" --json 2>/dev/null)"
for u in G1 G2 G3; do
  assert_eq "all-subagent: $u share == 1.0" "$(unit_field "$out" "$u" subagentShare)" "1.0"
done

# --- ...and a middle value, per unit -------------------------------------------------
out="$(python3 "$tool" mixed --corpus-list "$fixtures/list-mixed.txt" --json 2>/dev/null)"
for u in G1 G2 G3; do
  assert_eq "mixed: $u share == 0.5" "$(unit_field "$out" "$u" subagentShare)" "0.5"
done

# --- The round-trip detector must reach BOTH values, per unit -----------------------
out="$(python3 "$tool" over --corpus-list "$fixtures/list-oversize-return.txt" --json 2>/dev/null)"
assert_eq "oversize: G1 returnCapExceeded == True" "$(unit_field "$out" G1 returnCapExceeded)" "True"
assert_eq "oversize: G1 returnCapBytes == 2000" "$(unit_field "$out" G1 returnCapBytes)" "2000"
assert_eq "oversize: G2 returnCapExceeded == False" "$(unit_field "$out" G2 returnCapExceeded)" "False"
assert_eq "oversize: G3 returnCapExceeded == False" "$(unit_field "$out" G3 returnCapExceeded)" "False"

# --- The corpus partition is always printed, both counts, always --------------------
assert_contains '"topLevelTranscripts"' "$out" "corpus: top-level partition count emitted"
assert_contains '"subagentTranscripts"' "$out" "corpus: subagent partition count emitted"

# --- Error handling: every row of the spec's table, exercised -----------------------
out="$(python3 "$tool" edge --corpus-list "$fixtures/list-edge-cases.txt" --json 2>/dev/null)"
assert_eq "edge-cases: skippedLines == 1 (unparseable line skipped and counted)" \
  "$(top_field "$out" skippedLines)" "1"

python3 "$tool" nope /nonexistent/does-not-exist.jsonl >/dev/null 2>&1
[ "$?" -eq 1 ] && printf 'ok   %s\n' "unresolvable corpus exits 1" \
  || { printf 'FAIL %s\n' "unresolvable corpus must exit 1"; fail=1; }

err="$(python3 "$tool" not3 --corpus-list "$fixtures/list-all-top-level.txt" --json 2>&1 >/dev/null)"
assert_contains 'workflows' "$err" "zero T3 transcripts prints the loud rglob WARNING"

# --- NA-81: unit P1 plan-slice fires on its own, isolated from G1/G2/G3 -------------
out="$(python3 "$tool" p1only --corpus-list "$fixtures/list-p1-only.txt" --json 2>/dev/null)"
assert_eq "p1-only: P1 orchestratorBytes non-zero" \
  "$([ "$(unit_field "$out" P1 orchestratorBytes)" -gt 0 ] && echo yes || echo no)" "yes"
assert_eq "p1-only: G1 never fired (subagentShare null)" "$(unit_field "$out" G1 subagentShare)" "None"
assert_eq "p1-only: G2 never fired (subagentShare null)" "$(unit_field "$out" G2 subagentShare)" "None"
assert_eq "p1-only: G3 never fired (subagentShare null)" "$(unit_field "$out" G3 subagentShare)" "None"

# --- NA-81: the same probe event in message.content AND toolUseResult.stdout is -----
# --- counted once, never twice (NA-93's own shipped bug: 97 -> reported 186) --------
out="$(python3 "$tool" dcount --corpus-list "$fixtures/list-double-count.txt" --json 2>/dev/null)"
assert_eq "double-count: P1 orchestratorBytes counted once, not twice" \
  "$(unit_field "$out" P1 orchestratorBytes)" "36"

exit "$fail"
