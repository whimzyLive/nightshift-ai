#!/usr/bin/env bash
# design-kind.sh <index.md|canvas.json|page.html> [<board>]
#
# Prints the kind of one design board:
#   KIND=draft|final|unknown
#   TEMPLATE=<name>        (only when the source declares one)
#
# Sources:
#   index.md     the `## Boards` table design-ingest.sh writes (File | Board kind | Template);
#                <board> is a File path, its basename, or the Title of its row in the asset table
#   canvas.json  a boards array (top level, or under `.boards`) or an object keyed by board name;
#                each board has `id`/`name`/`file` and `kind` (and optionally `template`)
#   page.html    `<meta name="board-kind" content="draft|final">` and `board-template` in the page;
#                <board> is ignored
# A board the source does not list, or any value other than draft|final, is `unknown`.
set -uo pipefail

src="${1:?usage: design-kind.sh <index.md|canvas.json|page.html> [<board>]}"
board="${2:-}"
[ -f "$src" ] || { echo "design-kind.sh: not a file: $src" >&2; exit 2; }

emit() {
  case "$1" in draft|final) ;; *) set -- unknown "" ;; esac
  printf 'KIND=%s\n' "$1"
  [ -n "${2:-}" ] && printf 'TEMPLATE=%s\n' "$2"
  exit 0
}

case "$src" in
  *.json)
    [ -n "$board" ] || { echo "design-kind.sh: a board is required for $src" >&2; exit 2; }
    out="$(jq -r --arg b "$board" '
      (if type == "array" then . elif has("boards") then .boards else . end) as $x
      | (if ($x | type) == "array" then $x else [$x | to_entries[] | ((.value | if type == "object" then . else {kind: .} end) + {name: .key})] end)
      | map(select(.id == $b or .name == $b or .file == $b)) | .[0]
      | [(.kind // ""), (.template // "")] | @tsv' "$src" 2>/dev/null)" || out=""
    emit "$(printf '%s' "$out" | cut -f1)" "$(printf '%s' "$out" | cut -f2)" ;;
  *.html|*.htm)
    meta() { perl -0ne 'print $1 if m{<meta\s+name="\Q'"$1"'\E"\s+content="([^"]*)"}i || m{<meta\s+content="([^"]*)"\s+name="\Q'"$1"'\E"}i' "$src"; }
    emit "$(meta board-kind)" "$(meta board-template)" ;;
  *)
    [ -n "$board" ] || { echo "design-kind.sh: a board is required for $src" >&2; exit 2; }
    out="$(B="$board" awk -F'|' '
      function trim(x) { gsub(/^ +| +$/, "", x); return x }
      function base(p,   n, a) { n = split(p, a, "/"); return a[n] }
      /^## / { sec = ($0 ~ /^## Boards/) ? "boards" : "" ; next }
      sec == "boards" {
        f = trim($2); if (f == "" || f == "File" || f ~ /^-+$/) next
        k[f] = trim($3); t[f] = trim($4); next
      }
      { f = trim($4); ti = trim($3); kd = trim($2)
        if (kd ~ /^(screen|component|page)$/ && (f == ENVIRON["B"] || ti == ENVIRON["B"] || base(f) == ENVIRON["B"])) want = f }
      END {
        if (want == "") want = ENVIRON["B"]
        if (!(want in k)) for (f in k) if (f == ENVIRON["B"] || base(f) == ENVIRON["B"]) want = f
        if (want in k) printf "%s\t%s\n", k[want], (t[want] == "-" ? "" : t[want])
      }' "$src")"
    emit "$(printf '%s' "$out" | cut -f1)" "$(printf '%s' "$out" | cut -f2)" ;;
esac
