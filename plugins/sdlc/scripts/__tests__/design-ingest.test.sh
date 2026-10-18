#!/usr/bin/env bash
# design-ingest.test.sh — pins design-ingest.sh: bundle unpacking, input classification, index.md
# row merging across re-runs, --replace pruning, folder copy, failure exits, and the render path
# (driven by a mock browser so no real Chrome is needed).
#
# The fixture bundle is built here in the exact shape a "standalone" HTML export uses: pages live
# gzipped+base64'd in a <script type="__bundler/manifest"> JSON object, their names in
# __bundler/ext_resources, and the shell page in a JSON-string __bundler/template.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/design-ingest.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/design-ingest.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 — $2" >&2; fail=1; }

run() { SDLC_DESIGN_BROWSER="${BROWSER_OVERRIDE:-none}" bash "$script" "$@"; }
row_of() { grep -F "| $2 |" "$1/index.md" | head -1; }

# --- fixture: a two-page bundle (one compressed screen, one uncompressed component) + a font ---
in="$tmp/in"; mkdir -p "$in"
a_b64="$(printf '<x-dc><h1>Alpha Screen body</h1></x-dc>' | gzip -c | base64 | tr -d '\n')"
b_b64="$(printf '<x-dc><p>Beta Widget body</p></x-dc>' | base64 | tr -d '\n')"
f_b64="$(printf 'font-bytes' | base64 | tr -d '\n')"
manifest="$(jq -cn --arg a "$a_b64" --arg b "$b_b64" --arg f "$f_b64" '{
  "u-a": {mime: "text/html", compressed: true,  data: $a},
  "u-b": {mime: "text/html", compressed: false, data: $b},
  "u-f": {mime: "font/woff2", compressed: false, data: $f}}')"
ext='[{"id":"./Alpha%20Screen%20v2.dc.html","uuid":"u-a"},{"id":"./Beta%20Widget.dc.html","uuid":"u-b"}]'
template="$(printf '%s' '<!DOCTYPE html><html><body><x-dc><dc-import name="Alpha Screen v2" hint-size="100%,900px"></dc-import></x-dc><script type="text/x-dc" data-dc-script="">class Component {}</script></body></html>' \
  | jq -Rs . | sed 's#</#<\\u002F#g')"
bundle="$in/My Design (standalone).html"
{
  echo '<!DOCTYPE html><html><head><title>Bundled Page</title></head><body>'
  echo "<script type=\"__bundler/manifest\">$manifest</script>"
  echo "<script type=\"__bundler/ext_resources\">$ext</script>"
  echo "<script type=\"__bundler/template\">$template</script>"
  echo '</body></html>'
} >"$bundle"
printf '<html><body>plain mock</body></html>' >"$in/Plain Mock.HTML"

# Mock browser: copies the page it was asked to render into $MOCK_LOG, writes a fake png.
mock="$tmp/mock-browser"; log="$tmp/browser-log"; mkdir -p "$log"
cat >"$mock" <<'MOCK'
#!/usr/bin/env bash
shot=""; url=""
for a in "$@"; do
  case "$a" in --screenshot=*) shot="${a#--screenshot=}" ;; file://*) url="${a#file://}" ;; esac
done
n="$(ls "$MOCK_LOG" | wc -l | tr -d ' ')"
cp "$url" "$MOCK_LOG/$n.html"
printf 'PNG' >"$shot"
MOCK
chmod +x "$mock"
printf 'png-bytes' >"$in/Screen Shot 1.PNG"
printf 'pdf-bytes' >"$in/Spec Notes.PDF"

# --- (1) bundle unpack + classification ----------------------------------------------------
d="$tmp/d1"
out="$(run --ticket ABC-1 --title "Alpha flow" "$d" "$bundle" "$in/Plain Mock.HTML" "$in/Screen Shot 1.PNG" "$in/Spec Notes.PDF")"
rc=$?
[ "$rc" -eq 0 ] && ok "(1a) ingest exits 0" || bad "(1a) ingest exits 0" "rc=$rc"
grep -q 'Alpha Screen body' "$d/pages/alpha-screen-v2.html" 2>/dev/null \
  && ok "(1b) compressed page unpacked to pages/alpha-screen-v2.html" || bad "(1b) compressed page unpacked" "missing or wrong content"
grep -q 'Beta Widget body' "$d/pages/beta-widget.html" 2>/dev/null \
  && ok "(1c) uncompressed page unpacked to pages/beta-widget.html" || bad "(1c) uncompressed page unpacked" "missing or wrong content"
cmp -s "$bundle" "$d/source/my-design-standalone.html" \
  && ok "(1d) original bundle kept verbatim under source/" || bad "(1d) original bundle kept verbatim" "source copy differs or missing"
[ -z "$(find "$d" -name '*font*' -o -name 'u-f*')" ] \
  && ok "(1e) non-html bundle resources are not extracted" || bad "(1e) non-html resources skipped" "font resource extracted"
case "$(row_of "$d" 'pages/alpha-screen-v2.html')" in
  '| screen | Alpha Screen v2 | pages/alpha-screen-v2.html | - | TODO |') ok "(1f) shell-imported page is kind screen" ;;
  *) bad "(1f) shell-imported page is kind screen" "row: $(row_of "$d" 'pages/alpha-screen-v2.html')" ;;
esac
case "$(row_of "$d" 'pages/beta-widget.html')" in
  '| component | Beta Widget | pages/beta-widget.html | - | TODO |') ok "(1g) non-imported page is kind component" ;;
  *) bad "(1g) non-imported page is kind component" "row: $(row_of "$d" 'pages/beta-widget.html')" ;;
esac
[ -f "$d/pages/plain-mock.html" ] && row_of "$d" 'pages/plain-mock.html' | grep -q '^| page |' \
  && ok "(1h) plain HTML lands in pages/ as kind page" || bad "(1h) plain HTML as page" "missing file or wrong kind"
[ -f "$d/screenshots/screen-shot-1.png" ] && row_of "$d" 'screenshots/screen-shot-1.png' | grep -q '^| screenshot |' \
  && ok "(1i) image lands in screenshots/ with a lowercased extension" || bad "(1i) image as screenshot" "missing file or wrong kind"
[ -f "$d/references/spec-notes.pdf" ] && row_of "$d" 'references/spec-notes.pdf' | grep -q '^| reference |' \
  && ok "(1j) other file lands in references/" || bad "(1j) other file as reference" "missing file or wrong kind"
grep -qx 'Source ticket: `ABC-1`' "$d/index.md" && grep -qx '# Design — Alpha flow' "$d/index.md" \
  && ok "(1k) index carries ticket and title" || bad "(1k) index ticket/title" "header missing"
printf '%s\n' "$out" | grep -qx 'SUMMARY pages=3 screenshots=1 references=1 folders=0 rendered=0 render=disabled' \
  && ok "(1l) summary line counts every kind" || bad "(1l) summary line" "got: $(printf '%s\n' "$out" | tail -1)"
first_kinds="$(sed -n 's/^| \([a-z]*\) |.*/\1/p' "$d/index.md" | grep -v '^Kind$' | tr '\n' ' ')"
[ "$first_kinds" = "screen component page screenshot reference source " ] \
  && ok "(1m) index rows ordered screen, component, page, screenshot, reference, source" \
  || bad "(1m) index row order" "got: $first_kinds"

# --- (2) re-run keeps hand-written descriptions by File, merges new rows, keeps header ---------
perl -pi -e 's{(pages/beta-widget\.html \| - \| )TODO}{$1Trend chip | up/down states}' "$d/index.md"
printf 'notes' >"$in/later.md"
run "$d" "$in/later.md" >/dev/null
case "$(row_of "$d" 'pages/beta-widget.html')" in
  *'| Trend chip | up/down states |') ok "(2a) description (with a pipe) survives a re-run" ;;
  *) bad "(2a) description survives re-run" "row: $(row_of "$d" 'pages/beta-widget.html')" ;;
esac
row_of "$d" 'references/later.md' | grep -q '| TODO |$' \
  && ok "(2b) newly ingested file is added with a TODO description" || bad "(2b) new row added" "references/later.md row missing"
grep -qx 'Source ticket: `ABC-1`' "$d/index.md" && grep -qx '# Design — Alpha flow' "$d/index.md" \
  && ok "(2c) re-run without --ticket/--title keeps the prior header" || bad "(2c) header kept" "header lost"

# --- (3) --replace clears stale assets but keeps the description of a re-ingested file ---------
run --replace "$d" "$bundle" >/dev/null
[ ! -e "$d/screenshots" ] && [ ! -e "$d/references" ] && [ ! -e "$d/pages/plain-mock.html" ] \
  && ok "(3a) --replace removes assets not in this run" || bad "(3a) --replace removes stale assets" "stale files remain"
! grep -q 'screen-shot-1\|spec-notes\|later.md\|plain-mock' "$d/index.md" \
  && ok "(3b) --replace drops index rows for removed files" || bad "(3b) stale rows dropped" "stale row still indexed"
row_of "$d" 'pages/beta-widget.html' | grep -q '| Trend chip | up/down states |$' \
  && ok "(3c) --replace keeps the description of a re-ingested file" || bad "(3c) description kept under --replace" "lost"

# --- (4) a directory input is copied verbatim; html/png/md indexed, svg assets not -----------
fold="$in/Handoff Export"; mkdir -p "$fold/designs/assets" "$fold/screenshots"
printf '<x-dc>team</x-dc>' >"$fold/designs/team.dc.html"
printf 'svg' >"$fold/designs/assets/logo.svg"
printf 'png' >"$fold/screenshots/01-team.png"
printf '# Handoff' >"$fold/README.md"
d4="$tmp/d4"
out4="$(MOCK_LOG="$tmp/log4" BROWSER_OVERRIDE="$mock" run "$d4" "$fold")"
[ -f "$d4/handoff-export/designs/team.dc.html" ] && [ -f "$d4/handoff-export/designs/assets/logo.svg" ] \
  && ok "(4a) folder copied verbatim under its kebab name" || bad "(4a) folder copied" "files missing"
case "$(row_of "$d4" 'handoff-export/designs/team.dc.html')" in
  '| page | team | handoff-export/designs/team.dc.html | - | TODO |') ok "(4b) folder html indexed as page, never rendered" ;;
  *) bad "(4b) folder html as unrendered page" "row: $(row_of "$d4" 'handoff-export/designs/team.dc.html')" ;;
esac
row_of "$d4" 'handoff-export/screenshots/01-team.png' | grep -q '^| screenshot |' \
  && row_of "$d4" 'handoff-export/README.md' | grep -q '^| reference |' \
  && ok "(4c) folder png -> screenshot, md -> reference" || bad "(4c) folder png/md kinds" "rows missing"
! grep -q 'logo.svg' "$d4/index.md" && ok "(4d) folder svg assets are not indexed" || bad "(4d) svg not indexed" "logo.svg indexed"
printf '%s\n' "$out4" | grep -q ' folders=1 rendered=0 ' && [ ! -e "$d4/renders" ] \
  && ok "(4e) summary counts the folder; nothing rendered even with a browser" \
  || bad "(4e) folder count / no render" "got: $(printf '%s\n' "$out4" | tail -1)"

# --- (5) failure exits -----------------------------------------------------------------------
run "$tmp/d5" "$in/does-not-exist.png" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && [ ! -e "$tmp/d5" ] && ok "(5a) missing input exits 1 before touching the destination" \
  || bad "(5a) missing input" "rc=$rc or destination created"
run "$tmp/d5" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "(5b) no inputs is a usage error (exit 2)" || bad "(5b) usage exit" "rc=$rc"
printf '<script type="__bundler/manifest">not json</script>' >"$in/broken.html"
run "$tmp/d5" "$in/broken.html" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "(5c) malformed bundle manifest exits 1" || bad "(5c) malformed bundle" "rc=$rc"

# --- (6) duplicate stems within one run get suffixed, not overwritten -------------------------
printf 'one' >"$in/a b.png"; printf 'two' >"$in/a-b.png"
d6="$tmp/d6"; run "$d6" "$in/a b.png" "$in/a-b.png" >/dev/null
[ "$(cat "$d6/screenshots/a-b.png" 2>/dev/null)" = "one" ] && [ "$(cat "$d6/screenshots/a-b-2.png" 2>/dev/null)" = "two" ] \
  && ok "(6) colliding names in one run are suffixed" || bad "(6) collision suffix" "files missing or overwritten"

# --- (7) render path, via the mock browser ---------------------------------------------------
d7="$tmp/d7"
out7="$(MOCK_LOG="$log" BROWSER_OVERRIDE="$mock" run "$d7" "$bundle" "$in/Plain Mock.HTML")"
[ -s "$d7/renders/alpha-screen-v2.png" ] && [ -s "$d7/renders/beta-widget.png" ] && [ -s "$d7/renders/plain-mock.png" ] \
  && ok "(7a) every bundle page and plain page gets a render" || bad "(7a) renders written" "missing render(s)"
row_of "$d7" 'pages/beta-widget.html' | grep -qF '| renders/beta-widget.png |' \
  && ok "(7b) index Render column names the png" || bad "(7b) Render column" "row: $(row_of "$d7" 'pages/beta-widget.html')"
beta_variant="$(grep -lF 'dc-import name=\"Beta Widget\"' "$log"/*.html 2>/dev/null | head -1)"
if [ -n "$beta_variant" ] && ! grep -qF 'name=\"Alpha Screen v2\"' "$beta_variant" && ! grep -qF 'class Component' "$beta_variant"; then
  ok "(7c) per-page render input imports only that page and drops the shell logic"
else
  bad "(7c) per-page render variant" "variant missing, still imports the shell page, or keeps the shell script"
fi
printf '%s\n' "$out7" | grep -q ' rendered=3 render=chrome$' && ok "(7d) summary reports renders" \
  || bad "(7d) render summary" "got: $(printf '%s\n' "$out7" | tail -1)"
out7b="$(BROWSER_OVERRIDE="$tmp/nope" run "$tmp/d7b" "$in/Plain Mock.HTML")"
printf '%s\n' "$out7b" | grep -q ' render=skipped:browser-not-executable$' && [ -f "$tmp/d7b/pages/plain-mock.html" ] \
  && ok "(7e) unusable browser skips renders without failing the ingest" || bad "(7e) render skip" "got: $(printf '%s\n' "$out7b" | tail -1)"
run "$d7" "$in/Plain Mock.HTML" >/dev/null
row_of "$d7" 'pages/plain-mock.html' | grep -qF '| renders/plain-mock.png |' \
  && ok "(7f) a browserless re-run keeps the existing render in the index" \
  || bad "(7f) render kept on browserless re-run" "row: $(row_of "$d7" 'pages/plain-mock.html')"
nopng="$tmp/nopng-browser"; printf '#!/usr/bin/env bash\nexit 0\n' >"$nopng"; chmod +x "$nopng"
out7g="$(BROWSER_OVERRIDE="$nopng" run "$tmp/d7g" "$bundle" "$in/Plain Mock.HTML")"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out7g" | grep -q ' rendered=0 render=chrome:failed=3$' \
  && ok "(7g) a browser that writes no png is reported as chrome:failed=<n>, not fatal" \
  || bad "(7g) silent render failure surfaced" "rc=$rc got: $(printf '%s\n' "$out7g" | tail -1)"

# --- (8) folder inputs never land on (or delete) the asset dirs -------------------------------
mkdir -p "$in/screenshots" "$in/pages"; printf 'x' >"$in/screenshots/x.png"; printf '<p>p</p>' >"$in/pages/p.html"
printf 'hero' >"$in/hero.png"
d8="$tmp/d8"; run "$d8" "$in/hero.png" "$in/screenshots" >/dev/null
[ "$(cat "$d8/screenshots/hero.png" 2>/dev/null)" = "hero" ] && [ -f "$d8/screenshots-2/x.png" ] \
  && ok "(8a) a folder named like an asset dir is suffixed, not merged over it" \
  || bad "(8a) reserved folder name" "hero.png lost or folder not suffixed"
run "$d8" "$bundle" >/dev/null; run "$d8" "$in/pages" >/dev/null
[ -f "$d8/pages/alpha-screen-v2.html" ] && [ -f "$d8/pages-2/p.html" ] && row_of "$d8" 'pages/alpha-screen-v2.html' | grep -q '^| screen |' \
  && ok "(8b) an additive folder named pages keeps the unpacked pages and their rows" \
  || bad "(8b) pages folder re-run" "unpacked pages wiped or rows dropped"

# --- (9) a page that fails to decode fails the ingest ----------------------------------------
bad_manifest="$(jq -cn '{"u-x": {mime: "text/html", compressed: true, data: "bm90LWd6aXA="}}')"
printf '<script type="__bundler/manifest">%s</script><script type="__bundler/ext_resources">[]</script>' "$bad_manifest" >"$in/undecodable.html"
run "$tmp/d9" "$in/undecodable.html" >/dev/null 2>"$tmp/d9.err"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'could not decode page' "$tmp/d9.err" \
  && ok "(9) an undecodable page exits 1" || bad "(9) undecodable page" "rc=$rc"

# --- (10) a bundle with no template still unpacks (every page a component) --------------------
printf '<script type="__bundler/manifest">%s</script><script type="__bundler/ext_resources">%s</script>' "$manifest" "$ext" >"$in/no-template.html"
run "$tmp/d10" "$in/no-template.html" >/dev/null; rc=$?
[ "$rc" -eq 0 ] && row_of "$tmp/d10" 'pages/alpha-screen-v2.html' | grep -q '^| component |' \
  && ok "(10) a template-less bundle unpacks with every page as component" || bad "(10) no-template bundle" "rc=$rc"

# --- (11) a formatter-padded index keeps every row and description ----------------------------
d11="$tmp/d11"; run "$d11" "$in/Screen Shot 1.PNG" "$in/Spec Notes.PDF" >/dev/null
perl -pi -e 's{^\| screenshot \| (.*) \| TODO \|$}{|  screenshot  |  $1  |  Login form, error state  |}' "$d11/index.md"
run "$d11" "$in/later.md" >/dev/null
row_of "$d11" 'screenshots/screen-shot-1.png' | grep -q '| Login form, error state |$' \
  && row_of "$d11" 'references/spec-notes.pdf' | grep -q '^| reference |' \
  && ok "(11) padded rows survive a re-run with their descriptions" \
  || bad "(11) padded index" "rows dropped: $(grep -c '^| ' "$d11/index.md") table lines"

# --- (12) dotfiles in a folder input are stripped ---------------------------------------------
mkdir -p "$in/Leaky"; printf 'SECRET=1' >"$in/Leaky/.env"; printf 'x' >"$in/Leaky/.DS_Store"; printf '# ok' >"$in/Leaky/notes.md"
run "$tmp/d12" "$in/Leaky" >/dev/null 2>&1
[ -f "$tmp/d12/leaky/notes.md" ] && [ ! -e "$tmp/d12/leaky/.env" ] && [ ! -e "$tmp/d12/leaky/.DS_Store" ] \
  && ok "(12) dotfiles never land in the design folder" || bad "(12) dotfile strip" ".env or .DS_Store copied"

# --- (13) --replace refuses a parent of other designs, and validates before deleting ------------
d13="$tmp/d13"; run "$d13/one" "$in/hero.png" >/dev/null
run --replace "$d13" "$in/hero.png" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && [ -f "$d13/one/screenshots/hero.png" ] \
  && ok "(13a) --replace on a folder of designs is refused, nothing deleted" || bad "(13a) replace guard" "rc=$rc or sibling deleted"
run --replace "$d13/one" "$in/broken.html" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && [ -f "$d13/one/screenshots/hero.png" ] \
  && ok "(13b) --replace with a malformed bundle fails before deleting anything" || bad "(13b) replace pre-validation" "rc=$rc or assets deleted"

exit "$fail"
