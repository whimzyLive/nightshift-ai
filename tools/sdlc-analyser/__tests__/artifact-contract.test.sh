#!/usr/bin/env bash
# artifact-contract.test.sh — NA-88 C7 regression proof for tools/sdlc-analyser/artifact-contract.sh's
# ordered-subsequence + placeholder-normalised matching. Author-run, deliberately NOT CI-wired (D7,
# reaffirmed by NA-88): a CI job would need a produced artifact to diff against, and none exists at
# CI time for every template this tool measures.
#
# Self-runnable, no test harness/framework dependency:
#   bash tools/sdlc-analyser/__tests__/artifact-contract.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# tools/sdlc-analyser/__tests__ -> repo root is three levels up.
repo_root="$(cd "$here/../../.." && pwd)"
cd "$repo_root" || {
  echo "artifact-contract.test.sh: FAILED — cannot cd to repo root ($here/../../..)" >&2
  exit 1
}

A="tools/sdlc-analyser/artifact-contract.sh"
F="tools/sdlc-analyser/__tests__/fixtures"
failures=0

run() { # $1=description $2..=args to artifact-contract.sh; sets OUT and STATUS
  OUT="$(bash "$A" "${@:2}" 2>&1)"
  STATUS=$?
}

# --- Assertion 1: all five NA-87 tier-1 reference rows still report CONTRACT_MATCH=true ----------
# Ordinals as corrected in docs/superpowers/plans/NA-87-measurements/contract-diff.txt.
tier1_cases=(
  "plugins/sdlc/skills/writing-specs/SKILL.md|## Spec Template|1|docs/superpowers/plans/NA-87-measurements/ref-spec.md"
  "plugins/sdlc/agents/tech-lead.md|## Output: implementation plan|3|docs/superpowers/plans/NA-87-measurements/ref-plan.md"
  "plugins/sdlc/skills/writing-adrs/SKILL.md|## Template|1|docs/superpowers/plans/NA-87-measurements/ref-adr.md"
  "plugins/sdlc/refs/qa-engineer-playbook.md|## Step 5 — Write learnings to memory|3,4|docs/superpowers/plans/NA-87-measurements/ref-review-round.md"
  "plugins/sdlc/refs/domain-agent-handoff.md|## Memory write (before committing)|2|docs/superpowers/plans/NA-87-measurements/ref-rule-entry.md"
)
tier1_ok=1
for c in "${tier1_cases[@]}"; do
  IFS='|' read -r tpl section fence artifact <<< "$c"
  run "tier1" --template "$tpl" --section "$section" --fence "$fence" --artifact "$artifact"
  if ! printf '%s' "$OUT" | grep -q '^CONTRACT_MATCH=true$'; then
    echo "FAIL: assertion 1 — tier-1 row regressed: $tpl / $artifact" >&2
    printf '%s\n' "$OUT" | sed 's/^/    /' >&2
    tier1_ok=0
  fi
done
if [ "$tier1_ok" -eq 1 ]; then
  echo "PASS: assertion 1 — all five NA-87 tier-1 reference rows report CONTRACT_MATCH=true"
else
  failures=$((failures + 1))
fi

# --- Assertion 2: a deliberately dropped template heading is still caught ------------------------
run "dropped heading" --template "$F/subsequence-template.md" --artifact "$F/subsequence-artifact-dropped-heading.md"
if printf '%s' "$OUT" | grep -q '^CONTRACT_MATCH=false$' \
  && printf '%s' "$OUT" | grep -q 'CONTRACT_MISSING=.*heading:## Beta'; then
  echo "PASS: assertion 2 — dropped heading still reports CONTRACT_MATCH=false and names it in CONTRACT_MISSING"
else
  echo "FAIL: assertion 2 — dropped heading not detected as expected" >&2
  printf '%s\n' "$OUT" | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

# --- Assertion 3: interleaved extra headings the template does not name still match --------------
run "interleaved extras" --template "$F/subsequence-template.md" --artifact "$F/subsequence-artifact-interleaved.md"
if printf '%s' "$OUT" | grep -q '^CONTRACT_MATCH=true$'; then
  echo "PASS: assertion 3 — artifact-side headings the template does not name resynchronise, not mismatch"
else
  echo "FAIL: assertion 3 — resynchronisation across interleaved extra headings failed" >&2
  printf '%s\n' "$OUT" | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

# --- Assertion 4: placeholder normalisation across a whole heading + a whole literal --------------
# Real, independently-produced artifact (this story's own plan doc) — not a self-confirming fixture.
run "placeholder heading + literal" --template "$F/placeholder-heading-template.md" --artifact "docs/superpowers/plans/NA-88.md"
if printf '%s' "$OUT" | grep -q '^CONTRACT_MATCH=true$'; then
  echo "PASS: assertion 4 — \`## Phase N — [Domain] [agent-name]\` matches the real Phase 1 heading, and \`feat/<STORY-KEY>\` matches \`feat/NA-88\`"
else
  echo "FAIL: assertion 4 — placeholder-normalised whole-string match failed" >&2
  printf '%s\n' "$OUT" | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

# --- Assertion 5: the bare-N rule must not turn an ALL-CAPS token into a wildcard -----------------
run "bare-N no wildcard" --template "$F/bare-n-template.md" --artifact "$F/bare-n-artifact-nomatch.md"
if printf '%s' "$OUT" | grep -q '^CONTRACT_MATCH=false$'; then
  echo "PASS: assertion 5 — \`LEDGER_PHASE\` does not match \`LEDGER_AGENT\` (bare N did not wildcard the token)"
else
  echo "FAIL: assertion 5 — bare-N rule incorrectly wildcarded an ALL-CAPS token" >&2
  printf '%s\n' "$OUT" | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo
  echo "artifact-contract.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "artifact-contract.test.sh: PASS — all assertions passed"
exit 0
