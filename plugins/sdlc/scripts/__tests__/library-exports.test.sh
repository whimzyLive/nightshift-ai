#!/usr/bin/env bash
# library-exports.test.sh — pins scripts/library-exports.sh: the bundle's exported names come from
# the inventory folder, and a library export the bundle lacks is listed as SOURCE_ONLY.
#   bash plugins/sdlc/scripts/__tests__/library-exports.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/library-exports.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
tab="$(printf '\t')"

lib="$work/packages/ui"
inv="$lib/bundle/components"
mkdir -p "$inv/Button" "$inv/ListTable" "$inv/.cache" "$lib/src/components/ui" "$lib/src/components/shared" \
  "$lib/src/node_modules/dep" "$lib/preview"
: >"$inv/Badge.md"
: >"$inv/readme.md"

cat >"$lib/src/components/ui/button.tsx" <<'TSX'
export function Button() { return null }
export const buttonVariants = {}
TSX
cat >"$lib/src/components/ui/table.tsx" <<'TSX'
function Table() { return null }
function TableRow() { return null }
function TableCell() { return null }
export {
  Table,
  TableRow,
  TableCell as Cell,
  type TableProps,
}
TSX
cat >"$lib/src/components/shared/list-table.tsx" <<'TSX'
export type ListTableProps = { rows: number }
export interface ListRowProps { id: string }
export const ListTable = () => null
export const ListRow = () => null
export default function RoleMultiSelect() { return null }
export const MAX_ROWS = 50
export class DatePicker {}
TSX
echo 'export const StoryOnly = () => null' >"$lib/src/components/shared/list-table.stories.tsx"
echo 'export const TestOnly = () => null' >"$lib/src/components/shared/list-table.test.tsx"
echo 'export const Declared: unknown' >"$lib/src/components/shared/types.d.ts"
echo 'export const Generated = 1' >"$lib/src/components/shared/api.gen.ts"
echo 'export const Vendored = 1' >"$lib/src/node_modules/dep/index.js"
echo 'export const PreviewOnly = 1' >"$lib/preview/entry.tsx"
echo 'export const InBundleFolder = 1' >"$inv/Button/Button.tsx"

cat >"$work/ctx.md" <<MD
## Tooling

| Token | Value |
| ----- | ----- |
| UI library | \`$lib/\` |

## Design

| Token | Value |
| ----- | ----- |
| Bundle inventory | \`$inv/\` |
| Bundle global | \`window.Acme\` |
MD

out="$(bash "$script" --context "$work/ctx.md" 2>&1)"; rc=$?
check "exit 0" 0 "$rc"
check "global, window. stripped" "GLOBAL=Acme" "$(printf '%s\n' "$out" | grep '^GLOBAL=')"
check "exported: folders and files of the inventory, PascalCase only" "Badge Button ListTable" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "EXPORTED" { print $2 }' | paste -sd' ' -)"
check "source only: named, default, class and brace exports; aliases by their exported name" \
  "Cell DatePicker ListRow RoleMultiSelect Table TableRow" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "SOURCE_ONLY" { print $2 }' | paste -sd' ' -)"
check "source only carries its file" "SOURCE_ONLY${tab}ListRow${tab}$lib/src/components/shared/list-table.tsx" \
  "$(printf '%s\n' "$out" | grep "^SOURCE_ONLY${tab}ListRow${tab}")"
check "no entry row: ENTRY is empty and nothing is ENTRY_ONLY" "ENTRY=|0" \
  "$(printf '%s\n' "$out" | grep '^ENTRY=')|$(printf '%s\n' "$out" | grep -c '^ENTRY_ONLY')"
check "summary" "SUMMARY exported=3 entry-only=0 source-only=6" "$(printf '%s\n' "$out" | tail -1)"
for skipped in buttonVariants TableProps ListTableProps ListRowProps MAX_ROWS StoryOnly TestOnly Declared Generated Vendored PreviewOnly InBundleFolder; do
  check "skipped: $skipped" "" "$(printf '%s\n' "$out" | awk -F'\t' -v n="$skipped" '$2 == n')"
done

out="$(bash "$script" --context "$work/ctx.md" --match 'select|row' 2>&1)"
check "--match filters both lists, case-insensitive" "SOURCE_ONLY:ListRow SOURCE_ONLY:RoleMultiSelect SOURCE_ONLY:TableRow" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "EXPORTED" || $1 == "SOURCE_ONLY" { print $1 ":" $2 }' | paste -sd' ' -)"
check "--match summary counts the kept lines" "SUMMARY exported=0 entry-only=0 source-only=3" "$(printf '%s\n' "$out" | tail -1)"
check "--match on the bundle" "EXPORTED${tab}ListTable" \
  "$(bash "$script" --context "$work/ctx.md" --match '^listtable$' | grep '^EXPORTED')"


cat >"$work/entry.tsx" <<'TSX'
import { Table, TableRow } from "ui/table"
import { ListTable } from "shared/list-table"
window.Acme = { Table, TableRow, ListTable, RoleMultiSelectLike }
TSX
out="$(bash "$script" --context "$work/ctx.md" --entry "$work/entry.tsx" 2>&1)"
check "entry: parts it names are mountable without an inventory entry" "Table TableRow" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "ENTRY_ONLY" { print $2 }' | paste -sd' ' -)"
check "entry: the rest stays source only (whole names, not substrings)" "Cell DatePicker ListRow RoleMultiSelect" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "SOURCE_ONLY" { print $2 }' | paste -sd' ' -)"
check "entry: summary and ENTRY line" "ENTRY=$work/entry.tsx SUMMARY exported=3 entry-only=2 source-only=4" \
  "$(printf '%s\n' "$out" | grep -E '^(ENTRY=|SUMMARY)' | paste -sd' ' -)"
echo "| Bundle entry | \`$work/entry.tsx\` |" >>"$work/ctx.md"
check "entry: read from the Bundle entry row" "2" "$(bash "$script" --context "$work/ctx.md" | grep -c '^ENTRY_ONLY')"
check "entry not a file" "REASON=Bundle entry is not a file: $work/nope" \
  "$(bash "$script" --context "$work/ctx.md" --entry "$work/nope" 2>&1)"

mkdir -p "$work/flat/Card" "$work/flatlib"
echo 'export const Card = 1; ' >"$work/flatlib/card.jsx"
echo 'export const Sheet = 1' >"$work/flatlib/sheet.js"
out="$(bash "$script" --context "$work/none.md" --inventory "$work/flat" --library "$work/flatlib" 2>&1)"; rc=$?
check "flags replace the rows; no src folder scans the library root" "0 GLOBAL= ENTRY= EXPORTED${tab}Card SOURCE_ONLY${tab}Sheet${tab}$work/flatlib/sheet.js SUMMARY exported=1 entry-only=0 source-only=1" \
  "$rc $(printf '%s\n' "$out" | paste -sd' ' -)"

echo '## Design' >"$work/empty.md"
check "no inventory row: reason and exit 1" "REASON=no Bundle inventory row in $work/empty.md|1" \
  "$(bash "$script" --context "$work/empty.md" 2>&1 | paste -sd' ' -)|$(bash "$script" --context "$work/empty.md" >/dev/null 2>&1; echo $?)"
check "no library row" "REASON=no UI library row in $work/empty.md|1" \
  "$(bash "$script" --context "$work/empty.md" --inventory "$inv" 2>&1 | paste -sd' ' -)|$(bash "$script" --context "$work/empty.md" --inventory "$inv" >/dev/null 2>&1; echo $?)"
check "inventory not a folder" "REASON=Bundle inventory is not a folder: $work/nope" \
  "$(bash "$script" --inventory "$work/nope" --library "$lib" 2>&1)"
check "library not a folder" "REASON=UI library is not a folder: $work/nope" \
  "$(bash "$script" --inventory "$inv" --library "$work/nope" 2>&1)"
check "bad regex" "1" "$(bash "$script" --context "$work/ctx.md" --match '(' >/dev/null 2>&1; echo $?)"
check "unknown argument exits 2" 2 "$(bash "$script" --nope >/dev/null 2>&1; echo $?)"

if [ "$failures" -eq 0 ]; then echo "PASS: library-exports"; exit 0; fi
echo "FAIL: $failures library-exports case(s) failed"; exit 1
