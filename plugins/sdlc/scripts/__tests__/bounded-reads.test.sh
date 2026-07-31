#!/usr/bin/env bash
# bounded-reads.test.sh — NA-90 CI guard for the E `## Bounded reads` clause, its two
# prompt-contract pointers, and the load-bearing under-threshold carve-out.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/bounded-reads.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
#
# NA-88 D11: this story authors both the clause and this test, so a PASS proves only that
# the author wrote what the author intended. It is a presence check on text — it cannot
# detect whether any agent obeys the clause. That is Gate 3's job, not this file's.
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# plugins/sdlc/scripts/__tests__ -> repo root is four levels up.
repo_root="$(cd "$here/../../../.." && pwd)"
cd "$repo_root" || {
  echo "bounded-reads.test.sh: FAILED — cannot cd to repo root ($here/../../../..)" >&2
  exit 1
}

failures=0

handoff="plugins/sdlc/refs/domain-agent-handoff.md"
pe_playbook="plugins/sdlc/refs/principal-engineer-playbook.md"
qa_playbook="plugins/sdlc/refs/qa-engineer-playbook.md"

section() { awk '/^## Bounded reads$/{f=1} f&&/^## /&&!/^## Bounded reads$/{exit} f' "$1"; }

# --- Assertion (a): exactly one '## Bounded reads' heading -------------------------
if [ ! -f "$handoff" ]; then
  echo "FAIL: assertion a — file not found: $handoff" >&2
  failures=$((failures + 1))
else
  count="$(grep -c '^## Bounded reads$' "$handoff")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion a — $handoff carries exactly one '## Bounded reads' heading"
  else
    echo "FAIL: assertion a — $handoff carries $count '## Bounded reads' heading(s), expected exactly 1" >&2
    failures=$((failures + 1))
  fi
fi

# --- Assertion (b): exactly one pointer line per playbook --------------------------
for f in "$pe_playbook" "$qa_playbook"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: assertion b — file not found: $f" >&2
    failures=$((failures + 1))
    continue
  fi
  count="$(grep -Fc -- '## Bounded reads' "$f")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion b — $f carries exactly one pointer line naming '## Bounded reads'"
  else
    echo "FAIL: assertion b — $f carries $count reference(s) to '## Bounded reads', expected exactly 1" >&2
    failures=$((failures + 1))
  fi
done

# --- Assertion (c): the section is at most 1,200 bytes -----------------------------
if [ -f "$handoff" ]; then
  size="$(section "$handoff" | wc -c | tr -d ' ')"
  if [ "$size" -le 1200 ]; then
    echo "PASS: assertion c — '## Bounded reads' section is $size bytes (<= 1200)"
  else
    echo "FAIL: assertion c — '## Bounded reads' section is $size bytes, exceeds the 1200-byte limit" >&2
    failures=$((failures + 1))
  fi
fi

# --- Assertion (d): no ```bash fence in the section (ADR 0017) ---------------------
if [ -f "$handoff" ]; then
  if section "$handoff" | grep -q '```bash'; then
    echo "FAIL: assertion d — '## Bounded reads' contains a \`\`\`bash fence; pseudocode must never be executable (ADR 0017)" >&2
    failures=$((failures + 1))
  else
    echo "PASS: assertion d — '## Bounded reads' contains no \`\`\`bash fence"
  fi
fi

# --- Assertion (e): C1 regression guard — E must not erode or absorb C -------------
# NA-88's '## Context reuse' section was 868 bytes at 71d9ea8 and must stay byte-identical.
# CROSS-STORY COUPLING: if a legitimate NA-88-owner edit to '## Context reuse' trips this
# assertion, that is NOT automatically an NA-90 regression — update the 868 constant below
# deliberately once the edit is confirmed intentional, rather than treating this as a bug
# in the new edit.
if [ -f "$handoff" ]; then
  c_count="$(grep -c '^## Context reuse$' "$handoff")"
  c_size="$(awk '/^## Context reuse$/{f=1} f&&/^## /&&!/^## Context reuse$/{exit} f' "$handoff" | wc -c | tr -d ' ')"
  if [ "$c_count" -eq 1 ] && [ "$c_size" -eq 868 ]; then
    echo "PASS: assertion e — '## Context reuse' still appears once and is unchanged ($c_size bytes)"
  else
    echo "FAIL: assertion e — '## Context reuse' appears $c_count time(s) at $c_size bytes, expected 1 at 868. This pin exists to catch NA-90 quietly editing NA-88's clause. If you are NA-88's owner deliberately changing '## Context reuse', that is legitimate — update the 868 constant in this file's assertion (e) to match, deliberately, rather than treating this failure as an NA-90 regression." >&2
    failures=$((failures + 1))
  fi
fi

# --- Assertion (f): the under-threshold carve-out survives (LOAD-BEARING) ----------
# 468 of 681 addressable reads (68.7%) are at or under the 400-line cap, where a windowed
# read returns the whole file anyway and the Grep is pure overhead. A contract without this
# carve-out INCREASES tokens across two-thirds of its own target set. Deleting or weakening
# the line must fail CI.
if [ -f "$handoff" ]; then
  body="$(section "$handoff")"
  carve_ok=0
  printf '%s\n' "$body" | grep -Eqi 'under (the )?threshold.*read whole|read whole.*under (the )?threshold' || carve_ok=1
  printf '%s\n' "$body" | grep -Fq -- '400' || carve_ok=1
  if [ "$carve_ok" -eq 0 ]; then
    echo "PASS: assertion f — the under-threshold carve-out and its 400-line bound are both present"
  else
    echo "FAIL: assertion f — '## Bounded reads' must state the under-threshold carve-out ('under the threshold -> read whole') AND name the 400-line bound; without it Grep-first is a net LOSS on 68.7% of addressable reads" >&2
    failures=$((failures + 1))
  fi
fi

if [ "$failures" -ne 0 ]; then
  echo
  echo "bounded-reads.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "bounded-reads.test.sh: PASS — all 6 assertions passed"
exit 0
