#!/usr/bin/env bash
# branch-inventory.test.sh — regression proof for tools/sdlc-analyser/branch-inventory.sh's
# `if`/`elif`/`else` outcome counting. `\b` is a backspace, not a word boundary, in POSIX ERE
# awk (BWK awk) — the fixed regex must use an explicit non-letter-or-end boundary instead.
#
# Self-runnable, no test harness/framework dependency:
#   bash tools/sdlc-analyser/__tests__/branch-inventory.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# tools/sdlc-analyser/__tests__ -> repo root is three levels up.
repo_root="$(cd "$here/../../.." && pwd)"
cd "$repo_root" || {
  echo "branch-inventory.test.sh: FAILED — cannot cd to repo root ($here/../../..)" >&2
  exit 1
}

TOOL="tools/sdlc-analyser/branch-inventory.sh"
FIXTURE="tools/sdlc-analyser/__tests__/fixtures/branch-inventory/if-elif-else.md"
failures=0

OUT="$(bash "$TOOL" "$FIXTURE" 2>&1)"

# --- Assertion 1: exactly the three keyword lines (if/elif/else) count as outcomes ---------------
# `elsewhere` and `ifxyz` share the `if`/`else` prefix but must NOT match — that is the
# false-positive half of the same defect class.
if printf '%s\n' "$OUT" | grep -q '^OUTCOMES_HEAD=3$'; then
  echo "PASS: assertion 1 — if/elif/else lines counted (3), elsewhere/ifxyz excluded"
else
  echo "FAIL: assertion 1 — expected OUTCOMES_HEAD=3, got:" >&2
  printf '%s\n' "$OUT" | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo
  echo "branch-inventory.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "branch-inventory.test.sh: PASS — all assertions passed"
exit 0
