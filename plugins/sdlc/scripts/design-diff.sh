#!/usr/bin/env bash
# design-diff.sh --base <ref> <design-dir>
#
# Shows exactly what a design revision changed. Compares the design folder in the working tree with
# the same folder at <ref> (the base branch — what every story so far was built against), so no one
# has to remember a hash: the comparison point is always "what is merged".
#
#   1. Renders every page of both versions (design-diff.cjs, Playwright) and diffs them pixel by pixel.
#   2. Captures each component instance from components.md by selector and diffs it on its own, so a
#      layout shift above it does not mark it changed.
#   3. Diffs every image the design ships (screenshots, exported jpgs/pngs) directly.
#   4. Diffs components.md rows (a component newly New/Changed, or its Gap widened).
#   5. Writes a "Before | After | Diff" PNG per change under renders/diff/, and replaces the
#      "## Changed in this revision" block at the end of index.md with one row per change.
#
# Component selector (components.md): the optional `Selector` column, else [data-slot="<kebab name>"]
# (shadcn marks every rendered component that way); `none` skips capture for that component.
#
# No Playwright (or SDLC_PLAYWRIGHT=none): no images — byte-compares files instead, so changed,
# added and removed files are still listed (Diff `-`), plus an `asset` row for each changed file no
# index row names (shared CSS/JS/tokens); agents compare before/after themselves.
#
# Revision: a hash of the block's rows — the same change always yields the same value, which is how
# routing (refs/design-revisions.md) knows a revision was already routed.
#
# stdout: `DIFF <change> <kind> <item> <file> <pixels>` per row, `UNCAPTURED <Component>` per
# component its selector found on no page, then:
#   SUMMARY rows=<n> diff=<playwright|skipped:<why>|disabled|new>
# diff=new: <ref> has no such design (a first ingest) — nothing written.
# Exit: 0 ok | 1 failure | 2 usage.
set -uo pipefail

usage() { echo "usage: design-diff.sh --base <ref> <design-dir>" >&2; exit 2; }

BASE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) [ "$#" -ge 2 ] || usage; BASE="$2"; shift 2 ;;
    -*)     usage ;;
    *)      break ;;
  esac
done
[ -n "$BASE" ] && [ "$#" -eq 1 ] || usage
DIR="${1%/}"
[ -f "$DIR/index.md" ] || { echo "ERROR: $DIR/index.md not found" >&2; exit 1; }

here="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "ERROR: not in a git repository" >&2; exit 1; }
DIR_ABS="$(cd "$DIR" && pwd -P)"
ROOT_P="$(cd "$ROOT" && pwd -P)"
REL="${DIR_ABS#"$ROOT_P"/}"
[ "$REL" != "$DIR_ABS" ] || { echo "ERROR: $DIR is outside the repository" >&2; exit 1; }

git rev-parse -q --verify "$BASE^{commit}" >/dev/null || { echo "ERROR: unknown base ref: $BASE (fetch it first)" >&2; exit 1; }
if ! git cat-file -e "$BASE:$REL/index.md" 2>/dev/null; then
  echo "SUMMARY rows=0 diff=new"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/old"
git -C "$ROOT" archive "$BASE" -- "$REL" | tar -x -C "$WORK/old" || { echo "ERROR: cannot read $REL at $BASE" >&2; exit 1; }
OLD="$WORK/old/$REL"

# index.md asset rows (never the Changed block: its rows start with a change word, not a kind)
rows() {
  perl -ne '
    next unless /^\|\s*(screen|component|page|screenshot)\s*\|/;
    chomp; s/^\|\s*//; s/\s*\|\s*$//;
    my @c = split /\s*\|\s*/, $_, -1;
    print "$c[0]\t$c[2]\n";' "$1"
}
{ rows "$OLD/index.md"; rows "$DIR/index.md"; } | LC_ALL=C sort -u >"$WORK/assets"
awk -F'\t' '$1 != "screenshot" && $2 ~ /\.html?$/ && $2 !~ /^source\// { print $2 }' "$WORK/assets" | LC_ALL=C sort -u >"$WORK/pages"
awk -F'\t' '$1 == "screenshot" { print $2 }' "$WORK/assets" | LC_ALL=C sort -u >"$WORK/shots"

# components.md -> TSV of name, selector, used-in (padding-tolerant; columns found by header)
inventory() {
  [ -f "$1" ] || return 0
  perl -ne '
    chomp; next unless /^\|/;
    s/^\|\s*//; s/\s*\|\s*$//;
    my @c = split /\s*\|\s*/, $_, -1;
    if (!%h) { if ($c[0] eq "Component") { %h = map { $c[$_] => $_ } 0..$#c } next }
    next if $c[0] =~ /^-+$/ || $c[0] eq "";
    my $sel = defined $h{Selector} ? $c[$h{Selector}] : "";
    # "-" for an empty cell: tab is IFS whitespace, so `read` would collapse an empty field
    print join("\t", map { defined $_ && $_ ne "" ? $_ : "-" } $c[0], $c[$h{Status}], $c[$h{Gap}], $sel, $c[$h{"Used in"}]), "\n";' "$1"
}
inventory "$OLD/components.md" >"$WORK/inv-old"
inventory "$DIR/components.md" >"$WORK/inv-new"
kebab() { printf '%s' "$1" | perl -pe 's/([a-z0-9])([A-Z])/$1-$2/g; s/([A-Z]+)([A-Z][a-z])/$1-$2/g; s/[\s_]+/-/g; $_ = lc'; }
: >"$WORK/comps"
while IFS="$(printf '\t')" read -r name status gap sel used; do
  case "$sel" in none) continue ;; ""|"—"|"-") sel="[data-slot=\"$(kebab "$name")\"]" ;; esac
  sel="$(printf '%s' "$sel" | sed 's/^`//; s/`$//')"
  [ "$used" = "-" ] && used=""
  printf '%s\t%s\t%s\n' "$name" "$sel" "$(printf '%s' "$used" | sed 's/, */,/g')" >>"$WORK/comps"
done <"$WORK/inv-new"

OUT="$DIR/renders/diff"
rm -rf "$OUT"
: >"$WORK/found"
STATE="playwright"
if [ "${SDLC_PLAYWRIGHT:-}" = "none" ]; then
  STATE="disabled"
elif ! command -v node >/dev/null 2>&1; then
  STATE="skipped:no-node"
else
  node "$here/design-diff.cjs" "$OLD" "$DIR" "$OUT" "$WORK/pages" "$WORK/shots" "$WORK/comps" "$ROOT" >"$WORK/found" 2>"$WORK/err"
  rc=$?
  case "$rc" in
    0) ;;
    3) STATE="skipped:no-playwright"; sed 's/^/note: /' "$WORK/err" >&2; : >"$WORK/found" ;;
    *) cat "$WORK/err" >&2; exit 1 ;;
  esac
fi

if [ "$STATE" != "playwright" ]; then
  # Byte compare only — still names every changed, added and removed file.
  while IFS="$(printf '\t')" read -r kind file; do
    case "$kind" in screenshot) k=screenshot ;; *) case "$file" in *.htm|*.html) k=page ;; *) continue ;; esac ;; esac
    case "$file" in source/*) continue ;; esac
    title="$(basename "$file")"; title="${title%.*}"; title="${title%.dc}"
    if [ ! -e "$OLD/$file" ]; then ch=added
    elif [ ! -e "$DIR/$file" ]; then ch=removed
    elif cmp -s "$OLD/$file" "$DIR/$file"; then continue
    else ch=changed; fi
    printf '%s\t%s\t%s\t%s\t-\t-\n' "$ch" "$k" "$title" "$file" >>"$WORK/found"
  done <"$WORK/assets"
  # Files no index row names (shared CSS, JS, tokens, fonts) change what pages look like; without
  # renders that cannot be pinned to a page, so each is its own `asset` row.
  for side in "$OLD" "$DIR"; do (cd "$side" && find . -type f ! -path './renders/*' ! -path './source/*' ! -name index.md ! -name components.md | sed 's#^\./##'); done \
    | LC_ALL=C sort -u | while IFS= read -r file; do
        awk -F'\t' -v f="$file" '$2 == f { found = 1 } END { exit !found }' "$WORK/assets" && continue
        if [ ! -e "$OLD/$file" ]; then ch=added
        elif [ ! -e "$DIR/$file" ]; then ch=removed
        elif cmp -s "$OLD/$file" "$DIR/$file"; then continue
        else ch=changed; fi
        printf '%s\tasset\t%s\t%s\t-\t-\n' "$ch" "$(basename "$file")" "$file" >>"$WORK/found"
      done
fi

# components.md rows: new component, Status or Gap change, dropped component
awk -F'\t' 'FILENAME == ARGV[1] { s[$1] = $2; g[$1] = $3; next }
  !($1 in s) { printf "added\tinventory\t%s\t-\t%s\t-\n", $1, $2; next }
  s[$1] != $2 { printf "changed\tinventory\t%s\t-\t%s→%s\t-\n", $1, s[$1], $2; delete s[$1]; next }
  g[$1] != $3 { printf "changed\tinventory\t%s\t-\tGap\t-\n", $1 }
  { delete s[$1] }
  END { for (k in s) printf "removed\tinventory\t%s\t-\t-\t-\n", k }' \
  "$WORK/inv-old" "$WORK/inv-new" | LC_ALL=C sort >>"$WORK/found"

grep -v '^uncaptured' "$WORK/found" >"$WORK/table"
SHA="$(git rev-parse --short "$BASE")"
# content identity, not a timestamp: re-running on the same change yields the same Revision
REVISION="$(git hash-object --stdin <"$WORK/table" | cut -c1-12)"
{
  awk '/^## Changed in this revision$/ { exit } { print }' "$DIR/index.md" | perl -0pe 's/\n+\z/\n/'
  echo
  echo "## Changed in this revision"
  echo
  echo "<!-- Generated by design-diff.sh. Replaced on every revision; git history keeps older ones. -->"
  echo
  echo "Revision: \`$REVISION\` · compared with \`$BASE\` @ \`$SHA\`"
  echo
  if [ -s "$WORK/table" ]; then
    echo "Each Diff is Before | After | Diff, changed pixels in red. Open a row's Diff before its File."
    echo
    echo "| Change | Kind | Item | File | Pixels | Diff |"
    echo "|---|---|---|---|---|---|"
    while IFS="$(printf '\t')" read -r ch kind item file px diff; do
      [ "$diff" = "-" ] || diff="renders/diff/$diff"
      printf '| %s | %s | %s | %s | %s | %s |\n' "$ch" "$kind" "$item" "$file" "$px" "$diff"
    done <"$WORK/table"
  else
    echo "No changes."
  fi
} >"$WORK/index.md"
cp "$WORK/index.md" "$DIR/index.md"

while IFS="$(printf '\t')" read -r ch kind item file px diff; do
  if [ "$ch" = "uncaptured" ]; then echo "UNCAPTURED $item"; else echo "DIFF $ch $kind $item $file $px"; fi
done <"$WORK/found"
echo "SUMMARY rows=$(grep -c . "$WORK/table") diff=$STATE"
