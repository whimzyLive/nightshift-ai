#!/usr/bin/env bash
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
scripts_dir="$here/.."
fixtures_dir="$here/fixtures/memory-v2"
valid_dir="$fixtures_dir/valid"
invalid_dir="$fixtures_dir/invalid"
legacy_dir="$fixtures_dir/legacy"

check_frontmatter="$scripts_dir/check-frontmatter.sh"
collect_memory="$scripts_dir/collect-memory.sh"

failures=0

echo "=== check-frontmatter.sh <valid> ==="
valid_out="$(bash "$check_frontmatter" "$valid_dir" 2>&1)"
valid_exit=$?
if [ "$valid_exit" -eq 0 ]; then
  echo "PASS: check-frontmatter.sh valid fixture exits 0"
else
  echo "FAIL: check-frontmatter.sh valid fixture — expected exit 0, got $valid_exit"
  printf '%s\n' "$valid_out"
  failures=$((failures + 1))
fi

echo "=== check-frontmatter.sh <invalid> ==="
invalid_out="$(bash "$check_frontmatter" "$invalid_dir" 2>&1)"
invalid_exit=$?
if [ "$invalid_exit" -eq 1 ]; then
  echo "PASS: check-frontmatter.sh invalid fixture exits 1"
else
  echo "FAIL: check-frontmatter.sh invalid fixture — expected exit 1, got $invalid_exit"
  failures=$((failures + 1))
fi

for needle in \
  "id-mismatch.md" \
  "duplicate id 'duplicate-rule-id'" \
  "omits-self.md" \
  "single-agent-shared.md" \
  "root_causes token 'not-a-real-token'" \
  "2026-07-25-NA-81.md"; do
  if printf '%s' "$invalid_out" | grep -qF "$needle"; then
    echo "PASS: invalid fixture output names offender matching '$needle'"
  else
    echo "FAIL: invalid fixture output missing offender matching '$needle'"
    failures=$((failures + 1))
  fi
done

echo "=== check-frontmatter.sh <legacy> ==="
legacy_out="$(bash "$check_frontmatter" "$legacy_dir" 2>&1)"
legacy_exit=$?
if [ "$legacy_exit" -eq 0 ]; then
  echo "PASS: check-frontmatter.sh legacy fixture exits 0"
else
  echo "FAIL: check-frontmatter.sh legacy fixture — expected exit 0, got $legacy_exit"
  failures=$((failures + 1))
fi
if printf '%s' "$legacy_out" | grep -qF "WARNING"; then
  echo "PASS: check-frontmatter.sh legacy fixture warns on stderr"
else
  echo "FAIL: check-frontmatter.sh legacy fixture produced no WARNING"
  failures=$((failures + 1))
fi

echo "=== collect-memory.sh web-engineer <valid> ==="
collect_out="$(bash "$collect_memory" web-engineer "$valid_dir" 2>&1)"
collect_exit=$?
if [ "$collect_exit" -eq 0 ]; then
  echo "PASS: collect-memory.sh valid fixture exits 0"
else
  echo "FAIL: collect-memory.sh valid fixture — expected exit 0, got $collect_exit"
  failures=$((failures + 1))
fi
for needle in \
  "RULE prefer-server-component" \
  "RULE stage-explicit-paths" \
  "ADR 0001"; do
  if printf '%s' "$collect_out" | grep -qF "$needle"; then
    echo "PASS: collect-memory.sh valid fixture emits '$needle'"
  else
    echo "FAIL: collect-memory.sh valid fixture missing '$needle'"
    failures=$((failures + 1))
  fi
done
if printf '%s' "$collect_out" | grep -q "reviews"; then
  echo "FAIL: collect-memory.sh valid fixture emitted a reviews/ reference — reviews are never collected"
  failures=$((failures + 1))
else
  echo "PASS: collect-memory.sh valid fixture never emits review files"
fi

echo "=== collect-memory.sh web-engineer <legacy> ==="
legacy_collect_out="$(bash "$collect_memory" web-engineer "$legacy_dir" 2>&1)"
legacy_collect_exit=$?
if [ "$legacy_collect_exit" -eq 0 ]; then
  echo "PASS: collect-memory.sh legacy fixture exits 0"
else
  echo "FAIL: collect-memory.sh legacy fixture — expected exit 0, got $legacy_collect_exit"
  failures=$((failures + 1))
fi
if printf '%s' "$legacy_collect_out" | grep -qF "LEGACY"; then
  echo "PASS: collect-memory.sh legacy fixture emits the LEGACY banner"
else
  echo "FAIL: collect-memory.sh legacy fixture missing the LEGACY banner"
  failures=$((failures + 1))
fi

echo "=== collect-memory.sh with no argument ==="
noarg_out="$(bash "$collect_memory" 2>&1)"
noarg_exit=$?
if [ "$noarg_exit" -eq 1 ]; then
  echo "PASS: collect-memory.sh with no argument exits 1"
else
  echo "FAIL: collect-memory.sh with no argument — expected exit 1, got $noarg_exit"
  failures=$((failures + 1))
fi
if printf '%s' "$noarg_out" | grep -qF "usage:"; then
  echo "PASS: collect-memory.sh with no argument prints a usage line"
else
  echo "FAIL: collect-memory.sh with no argument printed no usage line"
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo
  echo "memory-frontmatter.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "memory-frontmatter.test.sh: PASS — all assertions passed"
exit 0
