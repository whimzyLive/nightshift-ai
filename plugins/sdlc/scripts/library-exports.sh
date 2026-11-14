#!/usr/bin/env bash
# library-exports.sh [--context <project-context.md>] [--inventory <dir>] [--library <dir>] [--entry <file>] [--match <regex>]
#
# Lists what a design board can mount, and what the component library has in source but the design
# bundle does not export. Plan mode's control audit reads it: a control is `reuse` only when its
# component is an EXPORTED line; a SOURCE_ONLY line is "in source, not exported".
#
# Paths come from project-context: `Bundle inventory` (a folder, one entry per component the bundle
# exports), `Bundle global` (the name boards mount from), `UI library` (the component package) and
# the optional `Bundle entry` (the file the bundle is built from). --inventory, --library and --entry
# override the rows. A bundle can export parts that have no inventory entry: with an entry file, a
# library export it names is ENTRY_ONLY (mountable, no inventory entry) instead of SOURCE_ONLY.
# Without one, SOURCE_ONLY only means "no inventory entry". Source is `<library>/src` when that folder exists,
# else `<library>`; tests, stories, generated files, type declarations and the inventory folder
# are skipped. Only PascalCase value exports count (types and interfaces are not components).
# --match keeps the names matching a case-insensitive extended regex (e.g. 'select|picker|combobox').
#
# Output (greppable, tab-separated, sorted by name):
#   GLOBAL=<Bundle global>                     (empty when the row is absent)
#   ENTRY=<Bundle entry>                       (empty when there is none)
#   EXPORTED<TAB><Name>                        the bundle exports it and the inventory has its entry
#   ENTRY_ONLY<TAB><Name><TAB><file>           named in the bundle entry, no inventory entry
#   SOURCE_ONLY<TAB><Name><TAB><file>          exported in library source, absent from the bundle
#   SUMMARY exported=<n> entry-only=<n> source-only=<n>
#   exit 0 -> listed; exit 1 -> REASON=<why>; exit 2 -> usage
set -uo pipefail

CTX=".claude/project/project-context.md"; INVENTORY=""; LIBRARY=""; ENTRY=""; MATCH=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --context)   CTX="${2:-}"; shift 2 ;;
    --inventory) INVENTORY="${2:-}"; shift 2 ;;
    --library)   LIBRARY="${2:-}"; shift 2 ;;
    --entry)     ENTRY="${2:-}"; shift 2 ;;
    --match)     MATCH="${2:-}"; shift 2 ;;
    *) echo "library-exports.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

fail() { echo "REASON=$1"; exit 1; }

token() {
  [ -f "$CTX" ] || return 0
  grep -i -m1 -E "^\|[[:space:]]*$1[[:space:]]*\|" "$CTX" \
    | sed -E 's/^\|[^|]*\|[[:space:]]*([^|]*[^|[:space:]])?[[:space:]]*\|.*/\1/' | tr -d '`' || true
}

[ -n "$INVENTORY" ] || INVENTORY="$(token 'Bundle inventory')"
[ -n "$LIBRARY" ] || LIBRARY="$(token 'UI library')"
[ -n "$ENTRY" ] || ENTRY="$(token 'Bundle entry')"
GLOBAL="$(token 'Bundle global')"; GLOBAL="${GLOBAL#window.}"

[ -n "$INVENTORY" ] || fail "no Bundle inventory row in $CTX"
[ -n "$LIBRARY" ] || fail "no UI library row in $CTX"
[ -d "$INVENTORY" ] || fail "Bundle inventory is not a folder: $INVENTORY"
[ -d "$LIBRARY" ] || fail "UI library is not a folder: $LIBRARY"
[ -z "$ENTRY" ] || [ -f "$ENTRY" ] || fail "Bundle entry is not a file: $ENTRY"
if [ -n "$MATCH" ]; then
  printf '' | grep -i -E -e "$MATCH" >/dev/null 2>&1
  [ "$?" -le 1 ] || fail "unusable --match regex '$MATCH'"
fi

SRC="${LIBRARY%/}"; [ -d "$SRC/src" ] && SRC="$SRC/src"
inv_abs="$(cd "$INVENTORY" && pwd -P)"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

keep() { if [ -n "$MATCH" ]; then grep -i -E -e "$MATCH" || true; else cat; fi; }

find "$INVENTORY" -mindepth 1 -maxdepth 1 ! -name '.*' -print \
  | sed -E 's|.*/||; s|\.[^.]*$||' \
  | grep -E '^[A-Z][A-Za-z0-9]*$' | LC_ALL=C sort -u >"$work/exported"

find "$SRC" \( -name node_modules -o -name dist -o -name '.*' \) -prune -o -type f \
  \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.js' \) \
  ! -name '*.d.ts' ! -name '*.stories.*' ! -name '*.test.*' ! -name '*.spec.*' ! -name '*.gen.*' -print \
  | LC_ALL=C sort >"$work/files"

: >"$work/source"
while IFS= read -r file; do
  dir_abs="$(cd "$(dirname "$file")" && pwd -P)"
  case "$dir_abs/" in "$inv_abs"/*) continue ;; esac
  F="$file" perl -0ne '
    my %seen;
    while (/^[ \t]*export\s+(?:default\s+)?(?:async\s+)?(?:function\*?|const|let|var|class)\s+([A-Za-z_\$][\w\$]*)/mg) { $seen{$1} = 1 }
    while (/^[ \t]*export\s*\{([^}]*)\}/mg) {
      for my $part (split /,/, $1) {
        $part =~ s/^\s+|\s+$//g;
        next if $part eq "" || $part =~ /^type\s/;
        $part =~ s/^.*\sas\s+//;
        $seen{$part} = 1;
      }
    }
    for my $name (sort keys %seen) {
      print "$name\t$ENV{F}\n" if $name =~ /^[A-Z][A-Za-z0-9]*$/ && $name =~ /[a-z]/;
    }
  ' "$file" >>"$work/source"
done <"$work/files"

tab="$(printf '\t')"
LC_ALL=C sort -u -t "$tab" -k1,1 "$work/source" >"$work/source.uniq"
LC_ALL=C join -t "$tab" -v 1 "$work/source.uniq" "$work/exported" >"$work/unlisted"

: >"$work/entry.names"
[ -z "$ENTRY" ] || grep -o -E '[A-Za-z_][A-Za-z0-9_]*' "$ENTRY" | LC_ALL=C sort -u >"$work/entry.names"
LC_ALL=C join -t "$tab" "$work/unlisted" "$work/entry.names" >"$work/entry-only"
LC_ALL=C join -t "$tab" -v 1 "$work/unlisted" "$work/entry.names" >"$work/source-only"

matched() {
  awk -F'\t' '{ print $1 }' "$1" | keep >"$work/names"
  LC_ALL=C join -t "$tab" "$1" "$work/names"
}
keep <"$work/exported" >"$work/exported.out"
matched "$work/entry-only" >"$work/entry-only.out"
matched "$work/source-only" >"$work/source-only.out"

printf 'GLOBAL=%s\nENTRY=%s\n' "$GLOBAL" "$ENTRY"
sed "s/^/EXPORTED$tab/" "$work/exported.out"
sed "s/^/ENTRY_ONLY$tab/" "$work/entry-only.out"
sed "s/^/SOURCE_ONLY$tab/" "$work/source-only.out"
printf 'SUMMARY exported=%s entry-only=%s source-only=%s\n' "$(wc -l <"$work/exported.out" | tr -d ' ')" \
  "$(wc -l <"$work/entry-only.out" | tr -d ' ')" "$(wc -l <"$work/source-only.out" | tr -d ' ')"
