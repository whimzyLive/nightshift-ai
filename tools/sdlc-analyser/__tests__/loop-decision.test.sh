#!/usr/bin/env bash
# loop-decision.test.sh — NA-93 falsifiability harness for loop-decision.py.
#
# AUTHOR-RUN AND CI-WIRED (founder decision 4; an author-run instrument is not a guard):
#   bash tools/sdlc-analyser/__tests__/loop-decision.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — these fixtures are authored by the same story that authors the tool.
# A pass proves the tool does what its author intended; it is a SMOKE TEST, never a gate
# on the correctness of the decision table itself. Rules 1, 5, 6 and 7 have ZERO production
# evidence: enumeration proves the port matches the table, never that the table was right.
#
# Falsifiability: --extract must read PER FIELD (the perturbed-tables fixture proves it),
# the domain must be exactly 1296/162/1458, rule selection must be invariant in checks-passing,
# the T3 tier must be reached (rglob), and skippedLines must count.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../.."
tool="$here/../loop-decision.py"
fixtures="$here/fixtures/loop-decision"
fail=0

ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# The extractor's job is to parse the PRE-change decision tables (H removed them from the
# live files in Phase 2), so every --extract / --enumerate call below reads the sha-pinned
# content the golden itself was extracted from — never the live plugins/sdlc/** files, which
# no longer contain a table to parse.
sourceSha="433120dafa2929048a740f427a5e82fe7f802760"
loop="$scratch/loop.md"
modes="$scratch/loop-modes.md"
git -C "$root" show "$sourceSha:plugins/sdlc/commands/loop.md" > "$loop"
git -C "$root" show "$sourceSha:plugins/sdlc/refs/loop-modes.md" > "$modes"
loop_bytes="$(wc -c < "$loop" | tr -d ' ')"
modes_bytes="$(wc -c < "$modes" | tr -d ' ')"
[ "$loop_bytes" = "17544" ] && ok "(provenance) pinned loop.md@$sourceSha is 17544 B" \
  || bad "(provenance) pinned loop.md@$sourceSha is 17544 B" "got $loop_bytes"
[ "$modes_bytes" = "18851" ] && ok "(provenance) pinned loop-modes.md@$sourceSha is 18851 B" \
  || bad "(provenance) pinned loop-modes.md@$sourceSha is 18851 B" "got $modes_bytes"

rule_conditions() { # <json> <rule-id>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
r = next((x for x in d['rules'] if x['id'] == '$2' and x['path'] == 'copilot'), None)
print('MISSING-RULE' if r is None else json.dumps(r['conditions'], sort_keys=True))
"
}

top_field() { # <json> <field>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(json.dumps(d['$2']))
"
}

observed_field() { # <json> <field>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(json.dumps(d['observed']['$2']))
"
}

# --- (F-1) --extract reads PER FIELD, not as a whole-cell string --------------------
clean_extract="$(python3 "$tool" --extract "$loop" "$modes" --json 2>/dev/null)"
perturbed_extract="$(python3 "$tool" --extract "$fixtures/tables-perturbed/loop.md" "$fixtures/tables-perturbed/loop-modes.md" --json 2>/dev/null)"
clean_rule4="$(rule_conditions "$clean_extract" 4)"
perturbed_rule4="$(rule_conditions "$perturbed_extract" 4)"
if [ "$clean_rule4" != "$perturbed_rule4" ]; then
  ok "(F-1) rule 4 conditions differ between clean and perturbed tables (per-field parse)"
else
  bad "(F-1) rule 4 conditions differ between clean and perturbed tables" \
      "identical conditions extracted from a perturbed table — extractor is echoing the rule id, not parsing fields"
fi

# --- (F-2) domain counts are exactly 1296 / 162 / 1458 -------------------------------
enum="$(python3 "$tool" --enumerate --extract-from "$loop" "$modes" --json 2>/dev/null)"
enum_domain="$(printf '%s' "$enum" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['domain']['copilotCases'], d['domain']['inSessionCases'], d['domain']['totalCases'])
")"
read -r cc ic tc <<<"$enum_domain"
[ "$cc" = "1296" ] && ok "(F-2) domain.copilotCases == 1296" || bad "(F-2) domain.copilotCases == 1296" "got $cc"
[ "$ic" = "162" ]  && ok "(F-2) domain.inSessionCases == 162" || bad "(F-2) domain.inSessionCases == 162" "got $ic"
[ "$tc" = "1458" ] && ok "(F-2) domain.totalCases == 1458" || bad "(F-2) domain.totalCases == 1458" "got $tc"

# --- (F-3) rule selection is invariant in checks-passing -----------------------------
invariant="$(printf '%s' "$enum" | python3 -c "
import json, sys
d = json.load(sys.stdin)
by_key = {}
for c in d['cases']:
    if c['path'] != 'copilot':
        continue
    f = c['fields']
    key = (f['copilot-reviewed-head'], f['copilot-changes-requested'], f['copilot-pending'],
           f['copilot-reviewed-any'], f['unresolved-copilot'], f['checks-pending'], f['checks-failing'])
    by_key.setdefault(key, set()).add(c['rule'])
bad_keys = [k for k, rules in by_key.items() if len(rules) != 1]
print(len(bad_keys))
")"
[ "$invariant" = "0" ] && ok "(F-3) rule selection invariant in checks-passing across all copilot cases" \
  || bad "(F-3) rule selection invariant in checks-passing" "$invariant tuple(s) select different rules across pass values"

# --- (F-4) --replay reaches the T3 tier (distinct count needs rglob) -----------------
replay="$(python3 "$tool" --replay t1t2t3 --corpus-list "$fixtures/list-observed.txt" --json 2>/dev/null)"
distinct="$(observed_field "$replay" distinct)"
snapshots="$(observed_field "$replay" snapshots)"
[ "$snapshots" = "5" ] && ok "(F-4) observed.snapshots == 5 (T1+T2+T3)" || bad "(F-4) observed.snapshots == 5" "got $snapshots"
[ "$distinct" = "5" ]  && ok "(F-4) observed.distinct == 5, reached only via rglob (T3-only tuple counted)" \
  || bad "(F-4) observed.distinct == 5" "got $distinct — the T3-only tuple was missed (NA-90's shipped bug shape)"

# --- (F-5) observed.rulesWithZeroEvidence matches the fixture's known-unexercised rules ---
zero_evidence="$(observed_field "$replay" rulesWithZeroEvidence)"
[ "$zero_evidence" = '["1", "5", "6", "7"]' ] && ok "(F-5) rulesWithZeroEvidence == [\"1\", \"5\", \"6\", \"7\"]" \
  || bad "(F-5) rulesWithZeroEvidence == [\"1\", \"5\", \"6\", \"7\"]" "got $zero_evidence"

# --- (F-6) skippedLines counts the one unparseable JSONL line ------------------------
skipped="$(top_field "$replay" skippedLines)"
[ "$skipped" = "1" ] && ok "(F-6) skippedLines == 1" || bad "(F-6) skippedLines == 1" "got $skipped"

# --- Corpus-completeness: a bogus --corpus-list entry is reported and exits non-zero --
printf '%s\n' "does-not-exist" > "$scratch/bogus-list.txt"
python3 "$tool" --replay bogus --corpus-list "$scratch/bogus-list.txt" >/dev/null 2>"$scratch/bogus-err.txt"
bogus_exit=$?
grep -q 'no transcript files found' "$scratch/bogus-err.txt" && ok "(corpus) unresolvable --corpus-list root is reported, not silent" \
  || bad "(corpus) unresolvable --corpus-list root is reported, not silent" "$(cat "$scratch/bogus-err.txt")"
[ "$bogus_exit" -eq 1 ] && ok "(corpus) --corpus-list with a missing root exits 1" \
  || bad "(corpus) --corpus-list with a missing root exits 1" "got exit=$bogus_exit"

exit "$fail"
