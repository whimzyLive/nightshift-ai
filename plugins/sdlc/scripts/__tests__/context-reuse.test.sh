#!/usr/bin/env bash
# context-reuse.test.sh — NA-88 CI guard for the C1 context-reuse clause, its C2 prompt-contract
# pointers, the C3 phase ledger tokens, and the C4 reuse-observability verdict line.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/context-reuse.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# plugins/sdlc/scripts/__tests__ -> repo root is four levels up.
repo_root="$(cd "$here/../../../.." && pwd)"
cd "$repo_root" || {
  echo "context-reuse.test.sh: FAILED — cannot cd to repo root ($here/../../../..)" >&2
  exit 1
}

failures=0

handoff="plugins/sdlc/refs/domain-agent-handoff.md"
pe_playbook="plugins/sdlc/refs/principal-engineer-playbook.md"
qa_playbook="plugins/sdlc/refs/qa-engineer-playbook.md"

# --- Assertion (a): domain-agent-handoff.md carries exactly one ## Context reuse heading ----
if [ ! -f "$handoff" ]; then
  echo "FAIL: assertion a — file not found: $handoff" >&2
  failures=$((failures + 1))
else
  count="$(grep -c '^## Context reuse$' "$handoff")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion a — $handoff carries exactly one '## Context reuse' heading"
  else
    echo "FAIL: assertion a — $handoff carries $count '## Context reuse' heading(s), expected exactly 1 ($handoff)" >&2
    failures=$((failures + 1))
  fi
fi

# --- Assertion (b): each playbook carries exactly one pointer line naming the section ------
for f in "$pe_playbook" "$qa_playbook"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: assertion b — file not found: $f" >&2
    failures=$((failures + 1))
    continue
  fi
  count="$(grep -Fc -- '## Context reuse' "$f")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion b — $f carries exactly one pointer line naming '## Context reuse'"
  else
    echo "FAIL: assertion b — $f carries $count reference(s) to '## Context reuse', expected exactly 1 ($f)" >&2
    failures=$((failures + 1))
  fi
done

# --- Assertion (c): both playbooks carry LEDGER_AGENT; qa playbook carries "Fix dispatch:" ---
for f in "$pe_playbook" "$qa_playbook"; do
  if [ ! -f "$f" ] || ! grep -Fq -- 'LEDGER_AGENT' "$f"; then
    echo "FAIL: assertion c — LEDGER_AGENT token missing in: $f" >&2
    failures=$((failures + 1))
  else
    echo "PASS: assertion c — $f carries the LEDGER_AGENT token"
  fi
done
if [ ! -f "$qa_playbook" ] || ! grep -Fq -- 'Fix dispatch:' "$qa_playbook"; then
  echo "FAIL: assertion c — 'Fix dispatch:' literal missing in: $qa_playbook" >&2
  failures=$((failures + 1))
else
  echo "PASS: assertion c — $qa_playbook carries the 'Fix dispatch:' literal"
fi

# --- Assertion (d): ## Context reuse section is at most 900 bytes --------------------------
if [ -f "$handoff" ]; then
  size="$(awk '/^## Context reuse$/{f=1} f&&/^## /&&!/^## Context reuse$/{exit} f' "$handoff" | wc -c | tr -d ' ')"
  if [ "$size" -le 900 ]; then
    echo "PASS: assertion d — '## Context reuse' section is $size bytes (<= 900)"
  else
    echo "FAIL: assertion d — '## Context reuse' section is $size bytes, exceeds the 900-byte limit" >&2
    failures=$((failures + 1))
  fi
fi

if [ "$failures" -ne 0 ]; then
  echo
  echo "context-reuse.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "context-reuse.test.sh: PASS — all assertions passed"
exit 0
