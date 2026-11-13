#!/usr/bin/env bash
# design-ingest.sh [--replace] [--no-render] [--ticket <KEY>] [--title <text>] <design-dir> <input>...
#
# Copies design references (HTML exports, screenshots, handoff folders, other reference files) into
# one per-design folder under the repo, makes them readable by agents, and (re)writes the folder's
# index.md — the single file every downstream SDLC agent reads first (refs/design-references.md).
#
# Layout written under <design-dir>:
#   source/<name>.html      bundled standalone HTML exports, kept verbatim (open in a browser)
#   pages/<page>.html       one readable markup file per page unpacked from a bundle, or a plain HTML
#   renders/<page>.png      best-effort headless-browser render of each bundle/plain page (vision input)
#   screenshots/<name>.<ext> image inputs (png/jpg/jpeg/webp/gif/svg)
#   references/<name>.<ext>  any other file input (pdf, md, txt, json, ...)
#   <folder>/...            a directory input (e.g. a design handoff export), copied verbatim, not rendered
#   index.md                generated asset table — only its Description column is hand-edited
#
# Why unpack: a "standalone" HTML export stores every page gzipped + base64'd inside a
# <script type="__bundler/manifest"> JSON blob. Read raw, an agent sees ~90% base64 noise; unpacked,
# each page is ordinary markup a story can point at on its own.
#
# Re-runs: inputs overwrite same-named files; --replace first deletes every asset except index.md
# (so hand-written descriptions survive), and only after every bundle input has validated. index.md
# rows are keyed by File — a re-run keeps each surviving row's Description (and its Render, when this
# run could not re-render) and drops rows whose file no longer exists. --replace refuses a
# <design-dir> that holds other ingested designs (a sibling index.md this script generated).
#
# Stable page names (--replace only): a bundle page keeps the file name of a page already in
# <design-dir>/pages/ so its render name, index Description and every story Design reference survive a
# revision. Only bundle-derived pages (index kind screen/component) are candidates. Match order: exact dc
# name (index Title, else the file's kebab name), then the page's <head> <title> when that title is unique
# among the old pages AND among this bundle's pages. Matches are reserved first; only unmatched pages get
# new names (so a new board can never take a matched board's name). Without --replace, or with no old
# pages, names are exactly what they were before (kebab of the dc name, -2 on a clash). A board no longer
# in the bundle is removed by --replace.
#
# Fonts: a page whose @font-face src is a relative URL with no file behind it prints
# `WARN<TAB>font-not-bundled<TAB><family><TAB><url>` and gets a note under the index table. Exports normally do not ship font files (a bundle may carry one in source/, but unpacked pages cannot load it); CSS kept inside a JS/JSON string
# (escaped quotes and slashes) is unescaped first; percent-encoded URLs are decoded. Not handled: linked
# stylesheets, fonts loaded from JS, and root-relative or remote URLs (skipped, the renderer owns them).
# Never fatal; prints nothing when every font resolves.
#
# Folder inputs: copied under their kebab name (never onto pages/, screenshots/, renders/,
# references/, source/ — those names get a -2 suffix), with dotfiles (.DS_Store, .env, ...) stripped.
#
# Rendering: Chrome/Chromium headless only (no node/playwright dependency). Browser resolution:
# $SDLC_DESIGN_BROWSER (a path, or `none` to disable) -> known install paths -> PATH lookup. Window
# size from $SDLC_DESIGN_RENDER_SIZE (default 1440,2000). No browser -> renders skipped, never fatal;
# a browser that produced no png for some pages -> render=chrome:failed=<n>, also never fatal.
#
# Board kinds: a page declares `<meta name="board-kind" content="draft|final">` and `board-template`.
# A draft page, or a final one without a template, is refused (exit 1, before anything is written). A page with
# no kind is treated as final and prints `NOTICE<TAB>board-kind-missing<TAB><file>`; the declared kinds are
# listed in a `## Boards` table of index.md (scripts/design-kind.sh reads it).
#
# stdout: one `INGESTED <kind> <path>` line per asset, then one summary line:
#   SUMMARY pages=<n> screenshots=<n> references=<n> folders=<n> rendered=<n> render=<chrome|chrome:failed=<n>|skipped:<why>|disabled>
# Exit: 0 ok | 1 failure (missing input/tool, malformed bundle, undecodable page) | 2 usage.
set -uo pipefail

usage() { echo "usage: design-ingest.sh [--replace] [--no-render] [--ticket <KEY>] [--title <text>] <design-dir> <input>..." >&2; exit 2; }

REPLACE=0; RENDER=1; TICKET=""; TITLE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --replace)   REPLACE=1; shift ;;
    --no-render) RENDER=0; shift ;;
    --ticket)    [ "$#" -ge 2 ] || usage; TICKET="$2"; shift 2 ;;
    --title)     [ "$#" -ge 2 ] || usage; TITLE="$2"; shift 2 ;;
    --)          shift; break ;;
    -*)          usage ;;
    *)           break ;;
  esac
done
[ "$#" -ge 2 ] || usage
DEST="$1"; shift

command -v jq >/dev/null 2>&1   || { echo "ERROR: jq is required" >&2; exit 1; }
command -v perl >/dev/null 2>&1 || { echo "ERROR: perl is required" >&2; exit 1; }
for f in "$@"; do
  [ -e "$f" ] || { echo "ERROR: input not found: $f" >&2; exit 1; }
done

mkdir -p "$DEST" || { echo "ERROR: cannot create $DEST" >&2; exit 1; }
DEST_ABS="$(cd "$DEST" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROWS="$WORK/rows.tsv"; : >"$ROWS"
# Asset dirs are pre-claimed so a folder input can never land on (and rm -rf) one of them.
USED="$WORK/used"; printf '%s\n' ./pages ./screenshots ./renders ./references ./source >"$USED"
FAILED="$WORK/failed"; : >"$FAILED"
RENDER_FAILED="$WORK/render-failed"; : >"$RENDER_FAILED"

kebab() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }
urldecode() { printf '%b' "${1//%/\\x}"; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
cell() { printf '%s' "$1" | tr '|\t\n' '/  '; }

# unique_name <dir-rel> <stem> <ext> -> a path not already claimed THIS run (re-runs overwrite).
unique_name() {
  local rel="$1/$2$3" n=2
  while grep -qxF -- "$rel" "$USED"; do rel="$1/$2-$n$3"; n=$((n + 1)); done
  printf '%s\n' "$rel" >>"$USED"
  printf '%s' "$rel"
}

# Empty cells are stored as `-`: tab is IFS whitespace, so `read` would collapse an empty field.
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$(cell "$2")" "$3" "${4:--}" >>"$ROWS"; echo "INGESTED $1 $3"; }

# script_body <type> <file> -> contents of <script type="<type>">...</script>.
script_body() { T="$1" perl -0ne 'print $1 if m{<script type="\Q$ENV{T}\E">(.*?)</script>}s' "$2"; }
is_bundle() { grep -q '<script type="__bundler/manifest">' "$1"; }

# Validate every bundle up front, so a bad input fails before --replace deletes anything.
for f in "$@"; do
  [ -f "$f" ] || continue
  case "$(lower "${f##*.}")" in html|htm) ;; *) continue ;; esac
  is_bundle "$f" || continue
  script_body "__bundler/manifest" "$f" | jq -e 'type == "object"' >/dev/null 2>&1 \
    || { echo "ERROR: $f: __bundler/manifest is not a JSON object" >&2; exit 1; }
done

# board_meta <name> <file> -> content of <meta name="<name>" content="..."> in the page, empty when absent.
board_meta() {
  perl -0ne 'print $1 if m{<meta\s+name="\Q'"$1"'\E"\s+content="([^"]*)"}i || m{<meta\s+content="([^"]*)"\s+name="\Q'"$1"'\E"}i' "$2"
}
# check_board <label> <file>: a draft board is never ingested; a final board names its template.
check_board() {
  local kind tpl
  kind="$(board_meta board-kind "$2")"; tpl="$(board_meta board-template "$2")"
  if [ "$kind" = "draft" ]; then
    echo "ERROR: $1 is a draft board (board-kind=draft) — drafts are never ingested; build the final board with /sdlc:design --final" >&2; return 1
  fi
  if [ "$kind" = "final" ] && [ -z "$tpl" ]; then
    echo "ERROR: $1 is a final board with no board-template — name the page template it is built on" >&2; return 1
  fi
  return 0
}

# Board kinds are checked up front, like bundles, so a refusal happens before --replace deletes anything.
for f in "$@"; do
  [ -f "$f" ] || continue
  case "$(lower "${f##*.}")" in html|htm) ;; *) continue ;; esac
  if is_bundle "$f"; then
    mf="$WORK/precheck-manifest.json"; script_body "__bundler/manifest" "$f" >"$mf"
    pc="$WORK/precheck-page.html"
    while IFS="$(printf '\t')" read -r uuid compressed; do
      if [ "$compressed" = "true" ]; then jq -r --arg u "$uuid" '.[$u].data' "$mf" | base64 --decode | gzip -dc >"$pc" 2>/dev/null
      else jq -r --arg u "$uuid" '.[$u].data' "$mf" | base64 --decode >"$pc" 2>/dev/null; fi
      [ -s "$pc" ] && { check_board "$(basename "$f") page $uuid" "$pc" || exit 1; }
    done < <(jq -r 'to_entries[] | select(.value.mime == "text/html") | [.key, (.value.compressed // false | tostring)] | @tsv' "$mf")
  else
    check_board "$f" "$f" || exit 1
  fi
done

# Old bundle-derived pages, snapshotted BEFORE --replace deletes pages/, so a revision keeps names:
# keep.tsv = file <TAB> index Title <TAB> <head> title <TAB> basename. Empty without --replace (--add never
# renames or overwrites by title).
# page_title <file> -> the page's <head> <title> (whitespace-collapsed); empty when the head has none.
# Only text before </head>, <body or <svg counts, so an inline <svg><title> never becomes a page key.
page_title() {
  perl -0ne '
    s{<(script|style)\b.*?</\1>}{}gsi;
    s{(?:</head>|<body\b|<svg\b).*}{}si;
    if (m{<title[^>]*>(.*?)</title>}si) { my $t = $1; $t =~ s/\s+/ /g; $t =~ s/^ | $//g; print $t }' "$1"
}
KEEP="$WORK/keep.tsv"; : >"$KEEP"
if [ "$REPLACE" = "1" ] && [ -f "$DEST_ABS/index.md" ]; then
  awk -F'|' '
    function trim(x) { gsub(/^ +| +$/, "", x); return x }
    { k = trim($2); t = trim($3); f = trim($4) }
    (k == "screen" || k == "component") && f ~ /^pages\/[^\/]+\.html$/ { print f "\t" t }' "$DEST_ABS/index.md" \
    | while IFS="$(printf '\t')" read -r pf title; do
        [ -f "$DEST_ABS/$pf" ] || continue
        b="$(basename "$pf" .html)"
        printf '%s\t%s\t%s\t%s\n' "$pf" "$title" "$(page_title "$DEST_ABS/$pf")" "$b" >>"$KEEP"
      done
fi

if [ "$REPLACE" = "1" ]; then
  if grep -lF -- '<!-- Generated by design-ingest.sh' "$DEST_ABS"/*/index.md >/dev/null 2>&1; then
    echo "ERROR: --replace refused: $DEST holds other ingested designs — point it at one design's folder" >&2
    exit 1
  fi
  find "$DEST_ABS" -mindepth 1 -maxdepth 1 ! -name index.md -exec rm -rf {} +
fi

# --- browser resolution --------------------------------------------------------------------
BROWSER=""; RENDER_STATE="disabled"
if [ "$RENDER" = "1" ]; then
  if [ -n "${SDLC_DESIGN_BROWSER:-}" ]; then
    if [ "$SDLC_DESIGN_BROWSER" = "none" ]; then RENDER_STATE="disabled"
    elif [ -x "$SDLC_DESIGN_BROWSER" ]; then BROWSER="$SDLC_DESIGN_BROWSER"
    else RENDER_STATE="skipped:browser-not-executable"; fi
  else
    for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
             "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
      [ -x "$c" ] && { BROWSER="$c"; break; }
    done
    if [ -z "$BROWSER" ]; then
      for c in google-chrome google-chrome-stable chromium chromium-browser; do
        p="$(command -v "$c" 2>/dev/null)" && { BROWSER="$p"; break; }
      done
    fi
    [ -z "$BROWSER" ] && RENDER_STATE="skipped:no-browser"
  fi
  [ -n "$BROWSER" ] && RENDER_STATE="chrome"
fi
SIZE="${SDLC_DESIGN_RENDER_SIZE:-1440,2000}"

# render <html-abs> <png-rel> -> echoes the png rel path on success, nothing on failure.
render() {
  [ -n "$BROWSER" ] || return 0
  local html="$1" out="$DEST_ABS/$2" prof i=0
  mkdir -p "$(dirname "$out")"
  rm -f "$out"
  prof="$(mktemp -d "$WORK/profile.XXXXXX")"
  "$BROWSER" --headless=new --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check \
    --user-data-dir="$prof" --window-size="$SIZE" --virtual-time-budget=8000 \
    --screenshot="$out" "file://$html" >/dev/null 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -gt 60 ] && { kill "$pid" 2>/dev/null; break; }
    sleep 1
  done
  wait "$pid" 2>/dev/null
  if [ -s "$out" ]; then printf '%s' "$2"; else echo "$2" >>"$RENDER_FAILED"; fi
  return 0
}

ingest_bundle() {
  local src="$1" base stem srcrel manifest ext tpl shell_names
  base="$(basename "$src")"; stem="$(kebab "${base%.*}")"; [ -n "$stem" ] || stem="design"
  srcrel="$(unique_name source "$stem" .html)"
  mkdir -p "$DEST_ABS/source"; cp "$src" "$DEST_ABS/$srcrel"
  row source "${base%.*}" "$srcrel" ""

  manifest="$WORK/manifest.json"; ext="$WORK/ext.json"; tpl="$WORK/template.html"
  script_body "__bundler/manifest" "$src" >"$manifest"
  script_body "__bundler/ext_resources" "$src" >"$ext"
  jq -e 'type == "object"' "$manifest" >/dev/null 2>&1 \
    || { echo "ERROR: $src: __bundler/manifest is not a JSON object" >&2; return 1; }
  jq -e 'type == "array"' "$ext" >/dev/null 2>&1 || echo '[]' >"$ext"
  script_body "__bundler/template" "$src" | jq -r . >"$tpl" 2>/dev/null || : >"$tpl"
  shell_names="$WORK/shell-names"
  grep -o '<dc-import name="[^"]*"' "$tpl" | sed 's/^<dc-import name="//; s/"$//' >"$shell_names" || true

  local uuid compressed id name pstem prel kind variant newtpl png dec i n=0 bp="$WORK/bp"
  rm -rf "$bp"; mkdir -p "$bp"
  # pass 1: decode every page (manifest order) to $bp/<n>.html + .name
  jq -r 'to_entries[] | select(.value.mime == "text/html") | [.key, (.value.compressed // false | tostring)] | @tsv' "$manifest" \
    | while IFS="$(printf '\t')" read -r uuid compressed; do
        id="$(jq -r --arg u "$uuid" '[.[] | select(.uuid == $u) | .id][0] // empty' "$ext")"
        if [ -n "$id" ]; then name="$(urldecode "${id##*/}")"; else name="$uuid"; fi
        name="${name%.html}"; name="${name%.dc}"
        n=$((n + 1)); dec="$bp/$(printf '%05d' "$n").html"
        if [ "$compressed" = "true" ]; then
          jq -r --arg u "$uuid" '.[$u].data' "$manifest" | base64 --decode | gzip -dc >"$dec" 2>/dev/null
        else
          jq -r --arg u "$uuid" '.[$u].data' "$manifest" | base64 --decode >"$dec" 2>/dev/null
        fi
        [ -s "$dec" ] || { echo "ERROR: $src: could not decode page $name" >&2; echo "$name" >>"$FAILED"; rm -f "$dec"; continue; }
        printf '%s' "$name" >"${dec%.html}.name"
      done

  # pass 2: resolve kept names for ALL pages first and reserve them, so a new page can never take one
  : >"$bp/new.tsv"; : >"$bp/match.tsv"
  for dec in "$bp"/*.html; do
    [ -f "$dec" ] || continue
    i="$(basename "$dec" .html)"; name="$(cat "${dec%.html}.name")"
    pstem="$(kebab "$name")"
    printf '%s\t%s\t%s\t%s\n' "$i" "$(cell "$name")" "$pstem" "$(page_title "$dec")" >>"$bp/new.tsv"
  done
  if [ -s "$KEEP" ] && [ -s "$bp/new.tsv" ]; then
    awk -F'\t' -v K="$KEEP" -v R="$USED" '
      FILENAME == K { kn++; kf[kn] = $1; kt[kn] = $2; kh[kn] = $3; kb[kn] = $4; if ($3 != "") khc[$3]++; next }
      FILENAME == R { used[$0] = 1; next }
      { nn++; ni[nn] = $1; nc[nn] = $2; nk[nn] = $3; nh[nn] = $4; if ($4 != "") nhc[$4]++ }
      END {
        for (i = 1; i <= nn; i++) for (j = 1; j <= kn; j++)
          if (!tk[j] && !used[kf[j]] && kt[j] == nc[i]) { m[i] = kf[j]; tk[j] = 1; break }
        for (i = 1; i <= nn; i++) if (m[i] == "" && nk[i] != "") for (j = 1; j <= kn; j++)
          if (!tk[j] && !used[kf[j]] && kb[j] == nk[i]) { m[i] = kf[j]; tk[j] = 1; break }
        for (i = 1; i <= nn; i++) if (m[i] == "" && nh[i] != "" && nhc[nh[i]] == 1 && khc[nh[i]] == 1)
          for (j = 1; j <= kn; j++)
            if (!tk[j] && !used[kf[j]] && kh[j] == nh[i]) { m[i] = kf[j]; tk[j] = 1; break }
        for (i = 1; i <= nn; i++) if (m[i] != "") print ni[i] "\t" m[i]
      }' "$KEEP" "$USED" "$bp/new.tsv" >"$bp/match.tsv"
    cut -f2 "$bp/match.tsv" >>"$USED"
  fi

  # pass 3: place, render, index
  for dec in "$bp"/*.html; do
    [ -f "$dec" ] || continue
    i="$(basename "$dec" .html)"; name="$(cat "${dec%.html}.name")"
    pstem="$(kebab "$name")"; [ -n "$pstem" ] || pstem="page"
    prel="$(awk -F'\t' -v i="$i" '$1 == i { print $2; exit }' "$bp/match.tsv")"
    [ -n "$prel" ] || prel="$(unique_name pages "$pstem" .html)"
    mkdir -p "$DEST_ABS/pages"; cp "$dec" "$DEST_ABS/$prel"
    if grep -qxF -- "$name" "$shell_names"; then kind=screen; else kind=component; fi
    png=""
    if [ -n "$BROWSER" ] && [ -s "$tpl" ]; then
      variant="$WORK/variant-$pstem.html"; newtpl="$WORK/newtpl-$pstem.json"
      DC_NAME="$(printf '%s' "$name" | sed 's/"/\&quot;/g')" perl -0pe '
        s{<x-dc>.*</x-dc>}{<x-dc><dc-import name="$ENV{DC_NAME}" hint-size="100%,900px"></dc-import></x-dc>}s;
        s{<script type="text/x-dc" data-dc-script="">.*?</script>}{}s;' "$tpl" \
        | jq -Rs . | sed 's#</#<\\u002F#g' >"$newtpl"
      NEWTPL="$newtpl" perl -0pe '
        BEGIN { open my $f, "<", $ENV{NEWTPL} or die; local $/; $n = <$f>; chomp $n; }
        s{(<script type="__bundler/template">).*?(</script>)}{$1$n$2}s;' "$src" >"$variant"
      png="$(render "$variant" "renders/$(basename "${prel%.html}").png")"
    fi
    row "$kind" "$name" "$prel" "$png"
  done
}

ingest_html() {
  local src="$1" base stem prel src_abs
  base="$(basename "$src")"; stem="$(kebab "${base%.*}")"; [ -n "$stem" ] || stem="page"
  prel="$(unique_name pages "$stem" .html)"
  mkdir -p "$DEST_ABS/pages"; cp "$src" "$DEST_ABS/$prel"
  src_abs="$DEST_ABS/$prel"
  row page "${base%.*}" "$prel" "$(render "$src_abs" "renders/$(basename "${prel%.html}").png")"
}

ingest_file() {
  local src="$1" base ext stem dir kind rel
  base="$(basename "$src")"
  case "$base" in *.*) ext=".$(lower "${base##*.}")"; stem="$(kebab "${base%.*}")" ;; *) ext=""; stem="$(kebab "$base")" ;; esac
  [ -n "$stem" ] || stem="file"
  case "$ext" in
    .html|.htm)
      if is_bundle "$src"; then ingest_bundle "$src"; else ingest_html "$src"; fi
      return ;;
    .png|.jpg|.jpeg|.webp|.gif|.svg) dir=screenshots; kind=screenshot ;;
    *) dir=references; kind=reference ;;
  esac
  rel="$(unique_name "$dir" "$stem" "$ext")"
  mkdir -p "$DEST_ABS/$dir"; cp "$src" "$DEST_ABS/$rel"
  row "$kind" "${base%.*}" "$rel" ""
}

ingest_folder() {
  local src="$1" stem rel f frel fext ftitle
  stem="$(kebab "$(basename "$src")")"; [ -n "$stem" ] || stem="folder"
  rel="$(unique_name . "$stem" "")"; rel="${rel#./}"
  rm -rf "${DEST_ABS:?}/$rel"; cp -R "$src" "$DEST_ABS/$rel"
  # Dotfiles never ship: .DS_Store is noise, a stray .env is a leaked secret once pushed.
  find "$DEST_ABS/$rel" -mindepth 1 -name '.*' -prune -print | while IFS= read -r f; do
    echo "note: dropped dotfile ${f#"$DEST_ABS"/}" >&2; rm -rf "$f"
  done
  echo "INGESTED folder $rel"
  echo "$rel" >>"$WORK/folders"
  # Folder pages are never rendered: handoff exports load tokens/fonts through a runtime that does
  # not resolve over file://, so a render would misstate the design — they ship screenshots instead.
  # svg/gif inside a folder are assets (logos, icons), not screenshots.
  find "$DEST_ABS/$rel" -type f | LC_ALL=C sort | while IFS= read -r f; do
    frel="${f#"$DEST_ABS"/}"
    case "$frel" in
      *'|'*|*"$(printf '\t')"*) echo "note: not indexed (| or tab in name): $frel" >&2; continue ;;
    esac
    fext="$(lower "${f##*.}")"
    ftitle="$(basename "${f%.*}")"; ftitle="${ftitle%.dc}"
    case "$fext" in
      html|htm) row page "$ftitle" "$frel" "" ;;
      png|jpg|jpeg|webp) row screenshot "$ftitle" "$frel" "" ;;
      md|pdf|txt) row reference "$ftitle" "$frel" "" ;;
    esac
  done
}

status=0
for input in "$@"; do
  if [ -d "$input" ]; then ingest_folder "$input" || status=1
  else ingest_file "$input" || status=1; fi
done
[ -s "$FAILED" ] && status=1
[ "$status" = "0" ] || exit 1

# --- index.md: merge this run's rows with surviving prior rows, keep Descriptions by File --------
INDEX="$DEST_ABS/index.md"
PRIOR="$WORK/prior.tsv"; : >"$PRIOR"
if [ -f "$INDEX" ]; then
  [ -n "$TICKET" ] || TICKET="$(sed -n 's/^Source ticket: `\(.*\)`$/\1/p' "$INDEX" | head -1)"
  [ -n "$TITLE" ]  || TITLE="$(sed -n 's/^# Design — //p' "$INDEX" | head -1)"
  # Padding-tolerant: a formatter may have aligned the table. Extra cells re-join into Description.
  perl -ne '
    next unless /^\|\s*(screen|component|page|screenshot|reference|source)\s*\|/;
    chomp; s/^\|\s*//; s/\s*\|\s*$//;
    my @c = split /\s*\|\s*/, $_, -1;
    my $desc = join(" | ", @c[4..$#c]);
    print join("\t", @c[0..3], $desc), "\n";' "$INDEX" >"$PRIOR"
fi

MERGED="$WORK/merged.tsv"; : >"$MERGED"
# this run's rows, each with the prior Description for the same File (or TODO), and the prior
# Render when this run produced none but that png is still on disk
while IFS="$(printf '\t')" read -r kind title file png; do
  desc="$(F="$file" awk -F'\t' '$3 == ENVIRON["F"] { print $5; exit }' "$PRIOR")"
  prior_png="$(F="$file" awk -F'\t' '$3 == ENVIRON["F"] { print $4; exit }' "$PRIOR")"
  [ "$png" = "-" ] && [ -n "$prior_png" ] && [ "$prior_png" != "-" ] && [ -e "$DEST_ABS/$prior_png" ] && png="$prior_png"
  printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$title" "$file" "$png" "${desc:-TODO}" >>"$MERGED"
done <"$ROWS"
# prior rows not re-ingested this run, kept only while their file still exists
while IFS="$(printf '\t')" read -r kind title file png desc; do
  F="$file" awk -F'\t' '$3 == ENVIRON["F"] { found = 1 } END { exit !found }' "$MERGED" && continue
  [ -e "$DEST_ABS/$file" ] || continue
  [ "$png" != "-" ] && [ ! -e "$DEST_ABS/$png" ] && png="-"
  printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$title" "$file" "$png" "$desc" >>"$MERGED"
done <"$PRIOR"

# --- fonts: @font-face relative src with nothing behind it (scans every page in the folder) ----
# CSS inside a JS/JSON string is unescaped first (\" \' \/ \u002F \n); data:, remote and root-relative urls
# are skipped; %XX is decoded. A font the original bundle carries (source/) is still reported: the unpacked
# page cannot load it over file://. Scans every page in the folder, whichever run ingested it.
FONTS="$WORK/fonts.tsv"; : >"$FONTS"
for pf in "$DEST_ABS"/pages/*.html; do
  [ -f "$pf" ] || continue
  PDIR="$(dirname "$pf")" perl -0ne '
    s/\\u002[Ff]/\//g; s/\\+(["\x27\/])/$1/g; s/\\+[nrt]/ /g;
    while (/\@font-face\s*\{(.*?)\}/sg) {
      my $blk = $1; my ($fam) = $blk =~ /font-family\s*:\s*([^;]+)/i;
      $fam //= ""; $fam =~ s/\s+/ /g; $fam =~ s/^\s*["\x27]?|["\x27]?\s*$//g; $fam = "unknown" if $fam eq "";
      while ($blk =~ /url\(\s*(?:"([^"]*)"|\x27([^\x27]*)\x27|([^)]*?))\s*\)/ig) {
        my $u = defined $1 ? $1 : defined $2 ? $2 : $3; $u =~ s/^\s+|\s+$//g;
        next if $u eq "" || $u =~ m{^(?:data:|blob:|https?:|//|/|#)}i;
        my $p = $u; $p =~ s/[?#].*//s;
        (my $dp = $p) =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
        next if -e "$ENV{PDIR}/$p" || -e "$ENV{PDIR}/$dp";
        (my $pu = $u) =~ s/\s+/ /g;
        print "$fam\t$pu\n";
      }
    }' "$pf" >>"$FONTS"
done
sort -u "$FONTS" -o "$FONTS"
while IFS="$(printf '\t')" read -r fam url; do printf 'WARN\tfont-not-bundled\t%s\t%s\n' "$fam" "$url"; done <"$FONTS"

BOARDS="$WORK/boards.tsv"; : >"$BOARDS"
for pf in "$DEST_ABS"/pages/*.html; do
  [ -f "$pf" ] || continue
  bk="$(board_meta board-kind "$pf")"
  case "$bk" in
    draft|final) printf '%s\t%s\t%s\n' "pages/$(basename "$pf")" "$bk" "$(cell "$(board_meta board-template "$pf")")" >>"$BOARDS" ;;
    *) printf 'NOTICE\tboard-kind-missing\tpages/%s\n' "$(basename "$pf")" ;;
  esac
done

{
  echo "# Design — ${TITLE:-$(basename "$DEST_ABS")}"
  echo
  [ -n "$TICKET" ] && { echo "Source ticket: \`$TICKET\`"; echo; }
  echo "<!-- Generated by design-ingest.sh. Edit only the Description column; re-runs keep it by File. -->"
  echo
  echo "Read this table first. Open a page or render only when a story's **Design** section names it."
  echo "Kinds: \`screen\`/\`component\` (unpacked from a bundled export), \`page\` (plain HTML),"
  echo "\`screenshot\`, \`reference\` (non-design material), \`source\` (original bundle — browser only, never read raw)."
  echo "Renders are best-effort headless captures; where a screenshot shows the same screen, the screenshot wins."
  echo
  echo "| Kind | Title | File | Render | Description |"
  echo "|---|---|---|---|---|"
  awk -F'\t' 'BEGIN { split("screen component page screenshot reference source", o, " "); for (i in o) r[o[i]] = i }
              { printf "%d\t%s\n", r[$1], $0 }' "$MERGED" | LC_ALL=C sort -t"$(printf '\t')" -k1,1n -k4,4 \
    | cut -f2- | while IFS="$(printf '\t')" read -r kind title file png desc; do
        printf '| %s | %s | %s | %s | %s |\n' "$kind" "$title" "$file" "$png" "$desc"
      done
  if [ -s "$BOARDS" ]; then
    echo
    echo "## Boards"
    echo
    echo "Board kind per page: \`final\` boards are mounted from the design bundle and are the only kind a story's Design row may name."
    echo "A page not listed here has no declared kind and is treated as final."
    echo
    echo "| File | Board kind | Template |"
    echo "|---|---|---|"
    while IFS="$(printf '\t')" read -r bf bk bt; do printf '| %s | %s | %s |\n' "$bf" "$bk" "${bt:--}"; done <"$BOARDS"
  fi
  if [ -s "$FONTS" ]; then
    echo
    echo "## Fonts not bundled"
    echo
    echo "The unpacked pages reference these fonts by relative URL but no file sits beside them (the original bundle under source/ may carry them). A renderer"
    echo "(design check, headless render) must serve them, or the board renders in a fallback font."
    echo
    while IFS="$(printf '\t')" read -r fam url; do echo "- \`$fam\` — \`$url\`"; done <"$FONTS"
  fi
} >"$INDEX"

count() { awk -F'\t' -v k="$1" '$1 ~ k { n++ } END { print n + 0 }' "$ROWS"; }
folders=0; [ -f "$WORK/folders" ] && folders="$(wc -l <"$WORK/folders" | tr -d ' ')"
RENDERED="$(awk -F'\t' '$4 != "-" { n++ } END { print n + 0 }' "$ROWS")"
[ -s "$RENDER_FAILED" ] && RENDER_STATE="chrome:failed=$(wc -l <"$RENDER_FAILED" | tr -d ' ')"
echo "SUMMARY pages=$(count '^(screen|component|page)$') screenshots=$(count '^screenshot$') references=$(count '^reference$') folders=$folders rendered=$RENDERED render=$RENDER_STATE"
