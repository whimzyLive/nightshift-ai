#!/usr/bin/env bash
# design-kind.test.sh — pins scripts/design-kind.sh for the three sources: an ingested index.md,
# a canvas.json and a page.html.
#   bash plugins/sdlc/scripts/__tests__/design-kind.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/design-kind.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
kind() { bash "$script" "$@" 2>/dev/null | paste -sd' ' -; }

cat >"$work/index.md" <<'MD'
# Design — Demo

| Kind | Title | File | Render | Description |
|---|---|---|---|---|
| screen | Home | pages/home.html | - | Home screen |
| screen | Sketch | pages/sketch.html | - | Wireframe |
| screen | Legacy | pages/legacy.html | - | No kind |

## Boards

| File | Board kind | Template |
|---|---|---|
| pages/home.html | final | AppShell |
| pages/sketch.html | draft | - |
MD
check "index: by file"            "KIND=final TEMPLATE=AppShell" "$(kind "$work/index.md" pages/home.html)"
check "index: by title"           "KIND=final TEMPLATE=AppShell" "$(kind "$work/index.md" Home)"
check "index: by basename"        "KIND=final TEMPLATE=AppShell" "$(kind "$work/index.md" home.html)"
check "index: draft, no template" "KIND=draft" "$(kind "$work/index.md" Sketch)"
check "index: unlisted board"     "KIND=unknown" "$(kind "$work/index.md" Legacy)"
check "index: missing board"      "KIND=unknown" "$(kind "$work/index.md" nothing)"
check "index: board required"     2 "$(bash "$script" "$work/index.md" >/dev/null 2>&1; echo $?)"

echo '{"boards":[{"id":"b1","name":"Home","kind":"final","template":"AppShell"},{"id":"b2","name":"Sketch","kind":"draft"},{"id":"b3","name":"Odd","kind":"wip"}]}' >"$work/canvas.json"
check "canvas: by name"           "KIND=final TEMPLATE=AppShell" "$(kind "$work/canvas.json" Home)"
check "canvas: by id"             "KIND=draft" "$(kind "$work/canvas.json" b2)"
check "canvas: other value"       "KIND=unknown" "$(kind "$work/canvas.json" Odd)"
check "canvas: missing"           "KIND=unknown" "$(kind "$work/canvas.json" zzz)"
echo '[{"name":"Top","kind":"draft"}]' >"$work/arr.json"
check "canvas: top-level array"   "KIND=draft" "$(kind "$work/arr.json" Top)"
echo '{"Keyed":{"kind":"final","template":"Page"},"Plain":"draft"}' >"$work/map.json"
check "canvas: object keyed by name" "KIND=final TEMPLATE=Page" "$(kind "$work/map.json" Keyed)"
check "canvas: name -> kind string"  "KIND=draft" "$(kind "$work/map.json" Plain)"

printf '<html><head><meta name="board-kind" content="draft"></head></html>' >"$work/d.html"
printf '<html><head><meta content="AppShell" name="board-template"><meta name="board-kind" content="final"></head></html>' >"$work/f.html"
printf '<html><head></head></html>' >"$work/n.html"
check "html: draft"               "KIND=draft" "$(kind "$work/d.html")"
check "html: final + template"    "KIND=final TEMPLATE=AppShell" "$(kind "$work/f.html")"
check "html: none"                "KIND=unknown" "$(kind "$work/n.html")"
check "missing file exits 2"      2 "$(bash "$script" "$work/nope.md" x >/dev/null 2>&1; echo $?)"

if [ "$failures" -eq 0 ]; then echo "PASS: design-kind"; exit 0; fi
echo "FAIL: $failures design-kind case(s) failed"; exit 1
