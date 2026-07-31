#!/usr/bin/env bash
# session-boundary.test.sh — NA-91 CI guard for the F session-boundary contract: the canonical
# block in commands/auto.md, its three gate rows, the three standalone-command pointers, the
# always-loaded byte cap, and the two byte-pinned sections F must never touch.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/session-boundary.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
#
# NA-88 D11: this story authors both the contract text and this test, so a PASS proves only that
# the author wrote what the author intended. It is a presence-and-size check on text — it cannot
# detect whether any session honours the boundary. That is Gate 3's job, not this file's.
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# plugins/sdlc/scripts/__tests__ -> repo root is four levels up.
repo_root="$(cd "$here/../../../.." && pwd)"
cd "$repo_root" || {
  echo "session-boundary.test.sh: FAILED — cannot cd to repo root ($here/../../../..)" >&2
  exit 1
}

failures=0

auto="plugins/sdlc/commands/auto.md"
standalone="plugins/sdlc/commands/spec.md plugins/sdlc/commands/plan.md plugins/sdlc/commands/impl.md"
handoff="plugins/sdlc/refs/domain-agent-handoff.md"
CAP_BYTES=49571

# Body of the canonical block: everything after its heading, up to the next heading of any level.
# Plain '^#' (never an awk interval expression) — mawk on the CI runner does not reliably
# support {n,m}.
block() { awk '/^### Session boundary at PR raise$/{f=1;next} f&&/^#/{exit} f' "$1"; }

# --- Assertion (a): exactly one canonical block ------------------------------------
if [ ! -f "$auto" ]; then
  echo "FAIL: assertion a — file not found: $auto" >&2
  failures=$((failures + 1))
else
  count="$(grep -c '^### Session boundary at PR raise$' "$auto")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion a — $auto carries exactly one canonical session-boundary block"
  else
    echo "FAIL: assertion a — $auto carries $count '### Session boundary at PR raise' heading(s), expected exactly 1" >&2
    failures=$((failures + 1))
  fi
fi

# --- Assertion (b): all three gate rows survive ------------------------------------
# Deleting a row silently changes WHICH sessions take the boundary. SDLC_BOUNDARY_OFF is the
# revert lever AC-2 demands; without it a cache regression needs a code revert + re-release.
if [ -f "$auto" ]; then
  body="$(block "$auto")"
  rows_ok=0
  # Match the ROW text, not the bare token — the block's trailing prose also names
  # SDLC_BOUNDARY_OFF (the "set SDLC_BOUNDARY_OFF until it does not" sentence), so a bare-token
  # grep would still pass after the row itself is deleted (proven by F-6's perturbation).
  printf '%s\n' "$body" | grep -Fq -- 'SDLC_BOUNDARY_OFF set' || rows_ok=1
  printf '%s\n' "$body" | grep -Fq -- 'SDLC_SESSION_KEY set' || rows_ok=1
  printf '%s\n' "$body" | grep -Fq -- 'SDLC_SESSION_KEY unset' || rows_ok=1
  if [ "$rows_ok" -eq 0 ]; then
    echo "PASS: assertion b — all three gate rows present (OFF / harness / interactive)"
  else
    echo "FAIL: assertion b — the block must carry all three rows: SDLC_BOUNDARY_OFF, SDLC_SESSION_KEY set, SDLC_SESSION_KEY unset" >&2
    failures=$((failures + 1))
  fi
fi

# --- Assertion (c): no ```bash fence in the block (ADR 0017) -----------------------
if [ -f "$auto" ]; then
  if block "$auto" | grep -q '```bash'; then
    echo "FAIL: assertion c — the session-boundary block contains a \`\`\`bash fence; pseudocode must never be executable (ADR 0017)" >&2
    failures=$((failures + 1))
  else
    echo "PASS: assertion c — the session-boundary block contains no \`\`\`bash fence"
  fi
fi

# --- Assertion (d): exactly one pointer per standalone command ---------------------
for f in $standalone; do
  if [ ! -f "$f" ]; then
    echo "FAIL: assertion d — file not found: $f" >&2
    failures=$((failures + 1))
    continue
  fi
  count="$(grep -Fc -- 'Session boundary at PR raise' "$f")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion d — $f carries exactly one pointer to the canonical block"
  else
    echo "FAIL: assertion d — $f carries $count reference(s) to 'Session boundary at PR raise', expected exactly 1" >&2
    failures=$((failures + 1))
  fi
done

# --- Assertion (e): always-loaded surface must not grow (NON-POSITIVE) -------------
# The four command files totalled 49,571 bytes at 4c3ad88. F is required to land non-positive
# on always-loaded surface. If this fails, COMPRESS the prose — never raise the constant.
total=0
for f in "$auto" $standalone; do
  [ -f "$f" ] || continue
  size="$(wc -c < "$f" | tr -d ' ')"
  total=$((total + size))
done
if [ "$total" -le "$CAP_BYTES" ]; then
  echo "PASS: assertion e — the four commands total $total bytes (<= $CAP_BYTES)"
else
  echo "FAIL: assertion e — the four commands total $total bytes, over the $CAP_BYTES cap pinned at 4c3ad88. F must land NON-POSITIVE on always-loaded surface: compress the prose, do not raise this constant." >&2
  failures=$((failures + 1))
fi

# --- Assertion (f): F must not touch either byte-pinned section --------------------
# Deliberately duplicates bounded-reads.test.sh (c)/(e): F's OWN guard must fail if F edits
# NA-88's or NA-90's clause. CROSS-STORY COUPLING: if NA-88's or NA-90's owner legitimately
# changes those sections, update BOTH files' constants deliberately.
if [ -f "$handoff" ]; then
  c_size="$(awk '/^## Context reuse$/{f=1} f&&/^## /&&!/^## Context reuse$/{exit} f' "$handoff" | wc -c | tr -d ' ')"
  b_size="$(awk '/^## Bounded reads$/{f=1} f&&/^## /&&!/^## Bounded reads$/{exit} f' "$handoff" | wc -c | tr -d ' ')"
  if [ "$c_size" -eq 868 ] && [ "$b_size" -le 1200 ]; then
    echo "PASS: assertion f — byte pins intact ('## Context reuse' $c_size = 868, '## Bounded reads' $b_size <= 1200)"
  else
    echo "FAIL: assertion f — '## Context reuse' is $c_size bytes (expected exactly 868) and '## Bounded reads' is $b_size bytes (cap 1200). NA-91 must not edit either section — both are owned by other stories and pinned by bounded-reads.test.sh." >&2
    failures=$((failures + 1))
  fi
else
  echo "FAIL: assertion f — file not found: $handoff" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo
  echo "session-boundary.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "session-boundary.test.sh: PASS — all 6 assertions passed"
exit 0
