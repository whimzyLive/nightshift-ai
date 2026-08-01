#!/usr/bin/env bash
# docs-sync-gate.test.sh — NA-92 falsifiability harness for docs-sync-gate.sh.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/docs-sync-gate.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — same story authors the script and these fixtures. SMOKE TEST on the artifact.
# Falsifiability: all FOUR DOCS_GATE values must be reachable. A four-way enum with four
# fixtures cannot be satisfied by a constant — that is the whole point of the fourth fixture.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/../docs-sync-gate.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

# mkrepo <name> <manifest-content|-> <changed-file>
mkrepo() {
  r="$tmp/$1"; mkdir -p "$r/.claude/project" "$r/src"
  git -C "$r" init -q -b develop
  git -C "$r" config user.email t@t; git -C "$r" config user.name t
  echo base > "$r/README.md"
  [ "$2" = "-" ] || printf '%s\n' "$2" > "$r/.claude/project/docs-manifest.md"
  git -C "$r" add -A >/dev/null; git -C "$r" commit -qm base
  git -C "$r" remote add origin "$r"; git -C "$r" fetch origin -q
  git -C "$r" checkout -qb feat/NA-1
  mkdir -p "$(dirname "$r/$3")"; echo change > "$r/$3"
  git -C "$r" add -A >/dev/null; git -C "$r" commit -qm change
  git -C "$r" fetch origin -q
  printf '%s' "$r"
}

MANIFEST='| type | enabled | target-path | source | contract |
| --- | --- | --- | --- | --- |
| how-to | true | docs/how-to/ | src | |'
BADMANIFEST='| type | enabled | target-path | source | contract |
| --- | --- | --- | --- | --- |
| config-reference | true | docs/reference/config/ | plugins/{a,b}/refs/x.md | |'

check() { # <label> <repo> <expected-gate>
  out="$(cd "$2" && bash "$gate" NA-1 feat develop 2>&1)"; rc=$?
  got="$(printf '%s' "$out" | sed -n 's/^DOCS_GATE=//p')"
  lines="$(printf '%s\n' "$out" | grep -c .)"
  [ "$got" = "$3" ] && printf 'ok   %s -> %s\n' "$1" "$got" \
    || { printf 'FAIL %s\n     expected DOCS_GATE=%s, got: %s\n' "$1" "$3" "$out"; fail=1; }
  [ "$rc" -eq 0 ] || { printf 'FAIL %s exits 0 (got %s)\n' "$1" "$rc"; fail=1; }
  [ "$lines" -eq 2 ] || { printf 'FAIL %s emits exactly 2 lines (got %s)\n' "$1" "$lines"; fail=1; }
}

check "no manifest"          "$(mkrepo nomani "-"           src/a.ts)"  skip-no-manifest
check "manifest, no tracked" "$(mkrepo untrk  "$MANIFEST"   README2.md)" skip-no-tracked-files
check "manifest, tracked"    "$(mkrepo trk    "$MANIFEST"   src/a.ts)"  dispatch
check "unexpandable scope"   "$(mkrepo unres  "$BADMANIFEST" src/a.ts)" dispatch-unresolvable

# A nonexistent branch is unresolvable — and must NEVER resolve to a skip.
out="$(cd "$(mkrepo nobr "$MANIFEST" src/a.ts)" && bash "$gate" NA-9 feat develop 2>&1)"
case "$(printf '%s' "$out" | sed -n 's/^DOCS_GATE=//p')" in
  skip-*) printf 'FAIL unresolvable branch must not skip: %s\n' "$out"; fail=1 ;;
  dispatch*) printf 'ok   unresolvable branch -> dispatch (fail safe)\n' ;;
  *) printf 'FAIL unresolvable branch emitted no known value: %s\n' "$out"; fail=1 ;;
esac

# Missing arguments are unresolvable, still exit 0, still two lines.
out="$(bash "$gate" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s' "$out" | sed -n 's/^DOCS_GATE=//p')" = "dispatch-unresolvable" ] \
  && printf 'ok   no arguments -> dispatch-unresolvable, exit 0\n' \
  || { printf 'FAIL no arguments: rc=%s out=%s\n' "$rc" "$out"; fail=1; }

exit "$fail"
