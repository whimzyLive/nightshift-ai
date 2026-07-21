#!/usr/bin/env bash
# docs-sync-fixtures.test.sh — dispatch-and-snapshot regression test for the activation-gated,
# family-resolved /sdlc:docs reference-doc pipeline (NA-65).
#
# The real /sdlc:docs sync algorithm (refs/docs-pipeline.md §3) is prose executed inline by the
# knowledge-engineer agent — there is no committed generator script to unit-test. This harness
# instead runs docs_sync_fixture_gen.py (a minimal, deterministic stand-in for the same resolver
# ladder: contract -> source -> scan -> skip) against each of the three fixture repos under
# fixtures/{A,B,C}/, diffs the produced docs/reference/** + llms.txt tree against the fixture's
# own committed expected/ snapshot, and asserts the run is byte-identical on a second pass
# (idempotence, AC3 generalized to all three fixtures).
#
# Fixture shapes (see spec docs/superpowers/specs/NA-65.md "Testing"):
#   A — product repo: openapi.json, no Claude artifacts, no reference-roots configured.
#       Expected: an api-reference page + Source link, zero Nightshift strings, inactive
#       artifact rows (command-reference is enabled in the manifest but generates nothing).
#   B — plain repo: no contracts, no artifacts, nothing configured on any row.
#       Expected: no reference pages, no empty stubs; llms.txt still regenerates (the lone
#       `always` reference-family row) with zero entries.
#   C — artifact repo shaped like Nightshift (a reference-roots-scoped testplugin/ tree).
#       Expected: the four artifact rows generate from the scan, plus a family-resolved
#       config-reference from a configured `source:` template glob; cli/error rows stay inactive
#       (no `source:` configured for either), never invented.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/docs-sync-fixtures.test.sh
# Exit 0 = PASS (all fixtures + idempotence), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
gen="$here/docs_sync_fixture_gen.py"
fixtures_dir="$here/fixtures"

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 not available — docs_sync_fixture_gen.py requires it" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

failures=0

run_fixture() {
  local name="$1"
  local fixture="$fixtures_dir/$name"
  local expected="$fixture/expected"
  local out1="$workdir/$name-run1"
  local out2="$workdir/$name-run2"

  if [ ! -d "$fixture" ] || [ ! -f "$fixture/.claude/project/docs-manifest.md" ]; then
    echo "FAIL: fixture $name — missing fixture dir or manifest at $fixture"
    failures=$((failures + 1))
    return
  fi

  if ! python3 "$gen" "$fixture" "$out1" 2>"$workdir/$name-run1.err"; then
    echo "FAIL: fixture $name — generator run 1 errored"
    cat "$workdir/$name-run1.err"
    failures=$((failures + 1))
    return
  fi

  if ! diff -rq "$expected" "$out1" >"$workdir/$name-diff1.log" 2>&1; then
    echo "FAIL: fixture $name — generated output does not match committed expected/ snapshot"
    cat "$workdir/$name-diff1.log"
    failures=$((failures + 1))
    return
  fi
  echo "PASS: fixture $name — generated output matches committed expected/ snapshot"

  if ! python3 "$gen" "$fixture" "$out2" 2>"$workdir/$name-run2.err"; then
    echo "FAIL: fixture $name — generator run 2 (idempotence re-run) errored"
    cat "$workdir/$name-run2.err"
    failures=$((failures + 1))
    return
  fi
  if ! diff -rq "$out1" "$out2" >"$workdir/$name-diff2.log" 2>&1; then
    echo "FAIL: fixture $name — re-run is NOT byte-identical to the first run (idempotence broken)"
    cat "$workdir/$name-diff2.log"
    failures=$((failures + 1))
    return
  fi
  echo "PASS: fixture $name — re-run is byte-identical (idempotent)"
}

for fixture_name in A B C; do
  run_fixture "$fixture_name"
done

if grep -rlE 'plugins/\{?sdlc|plugins/\{?gtm' "$workdir/A-run1" >/dev/null 2>&1; then
  echo "FAIL: fixture A — generated output leaked a plugins/{sdlc,gtm} string"
  failures=$((failures + 1))
else
  echo "PASS: fixture A — generated output carries zero plugins/{sdlc,gtm} strings"
fi

if [ -d "$workdir/B-run1/docs" ]; then
  echo "FAIL: fixture B — a docs/reference/** tree was generated; expected none (skip, not an empty stub)"
  failures=$((failures + 1))
else
  echo "PASS: fixture B — no docs/reference/** tree generated (skip, not an empty stub)"
fi
if [ ! -f "$workdir/B-run1/llms.txt" ]; then
  echo "FAIL: fixture B — llms.txt did not regenerate (must stay the lone always-keyed row)"
  failures=$((failures + 1))
else
  echo "PASS: fixture B — llms.txt still regenerates with zero reference entries"
fi

if [ -d "$workdir/C-run1/docs/reference/cli" ] || [ -d "$workdir/C-run1/docs/reference/errors" ]; then
  echo "FAIL: fixture C — cli-reference/error-reference generated a page despite no configured source:"
  failures=$((failures + 1))
else
  echo "PASS: fixture C — cli-reference/error-reference stay inactive with no configured source:"
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all docs-sync fixture cases passed (A/B/C snapshot + idempotence)"
  exit 0
else
  echo "FAIL: $failures docs-sync fixture case(s) failed"
  exit 1
fi
