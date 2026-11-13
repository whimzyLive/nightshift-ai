#!/usr/bin/env bash
# wireframe.test.sh — pins scripts/wireframe-build.sh (assembling pages from shared parts) and
# scripts/wireframe-check.sh (the kit-vocabulary, link, data-pattern, draft-meta and shared-shell lint).
#   bash plugins/sdlc/scripts/__tests__/wireframe.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
scripts="$(cd "$here/.." && pwd)"
kit="$(cd "$scripts/../refs/wireframe-kit" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
has() { if printf '%s' "$3" | grep -qF -- "$2"; then echo "ok   - $1"; else echo "FAIL - $1: '$2' not in output: $3"; failures=$((failures + 1)); fi; }
hasnt() { if printf '%s' "$3" | grep -qF -- "$2"; then echo "FAIL - $1: '$2' unexpectedly in output: $3"; failures=$((failures + 1)); else echo "ok   - $1"; fi; }
build() { bash "$scripts/wireframe-build.sh" "$@" 2>&1; }
lint() { bash "$scripts/wireframe-check.sh" "$@" 2>&1; }

cat >"$work/vocab.md" <<'MD'
# Pattern vocabulary

| Pattern | Template | Wireframe |
| --- | --- | --- |
| **List page** | ListPageLayout | `.sk` |
| `App shell` | AppShell | `.side` |
| Bottom nav | BottomNav | `.bottomnav` |

- Empty state - a list with nothing in it
MD

# fresh <dir>: a valid two-screen web draft plus one phone screen
fresh() {
  rm -rf "$1"; mkdir -p "$1/parts"
  cat >"$1/parts/shell.side.html" <<'HTML'
<nav class="side" data-pattern="App shell" aria-label="Main"><div class="logo">Product</div><a class="nav" data-nav="projects" href="projects.html">Projects</a><a class="nav" data-nav="clients" href="#">Clients</a></nav>
HTML
  cat >"$1/parts/shell.bottomnav.html" <<'HTML'
<nav class="bottomnav" data-pattern="Bottom nav" aria-label="Main"><a data-nav="projects" href="projects.phone.html">Projects</a><a data-nav="clients" href="#">Clients</a></nav>
HTML
  cat >"$1/projects.main.html" <<'HTML'
<!-- wf title: Projects | nav: projects | url: app.example/projects -->
<div class="rowx"><h1>Projects</h1><span class="sp"></span><a class="btn p" href="project-new.html">New project</a></div>
<div class="sk" data-pattern="List page" style="padding:6px 14px;flex:1"><table><tr><td>Harbour Street fit-out</td></tr></table></div>
<a class="btn" href="#">Export</a>
HTML
  cat >"$1/project-new.main.html" <<'HTML'
<!-- wf title: New project | nav: projects -->
<div class="sk" data-pattern="?"><h1>New project</h1><a class="btn p" href="projects.html">Create</a></div>
HTML
  cat >"$1/projects.phone.main.html" <<'HTML'
<!-- wf title: Projects (phone) | nav: clients -->
<div class="sk" data-pattern="Empty state"><h1>Projects</h1></div>
HTML
  build "$1" >/dev/null
}
page() { cat "$1/$2"; }

d="$work/ok"; fresh "$d"
out="$(build "$d")"
has   "build: web page"             "BUILT projects.html" "$out"
has   "build: second web page"      "BUILT project-new.html" "$out"
has   "build: phone page"           "BUILT projects.phone.html" "$out"
check "build: stylesheet copied"    "$(cat "$kit/wireframe.css")" "$(cat "$d/wireframe.css")"
check "build: strokes copied"       "3" "$(ls "$d/strokes" | wc -l | tr -d ' ')"
has   "build: draft meta"           '<meta name="board-kind" content="draft">' "$(page "$d" projects.html)"
has   "build: title"                '<title>Projects</title>' "$(page "$d" projects.html)"
has   "build: url slot"             '<div class="url">app.example/projects</div>' "$(page "$d" projects.html)"
has   "build: shell inserted"       'data-pattern="App shell"' "$(page "$d" projects.html)"
has   "build: current nav marked"   'class="nav on" data-nav="projects"' "$(page "$d" projects.html)"
hasnt "build: other nav not marked" 'class="nav on" data-nav="clients"' "$(page "$d" projects.html)"
has   "build: phone nav marked"     '<a data-nav="clients" href="#" class="on">' "$(page "$d" projects.phone.html)"
has   "build: phone frame"          '<div class="wf phone"><div class="device">' "$(page "$d" projects.phone.html)"
hasnt "build: header comment gone"  '<!-- wf' "$(page "$d" projects.html)"
hasnt "build: no placeholder left"  '{{' "$(page "$d" projects.html)"

rm "$d/parts/shell.side.html"
out="$(build "$d")"; rc=$?
check "build: missing part exits 1" "1" "$(bash "$scripts/wireframe-build.sh" "$d" >/dev/null 2>&1; echo $?)"
has   "build: missing part named"   "parts/shell.side.html" "$out"
check "build: no dir exits 2"       "2" "$(bash "$scripts/wireframe-build.sh" "$work/nope" >/dev/null 2>&1; echo $?)"
check "build: no args exits 2"      "2" "$(bash "$scripts/wireframe-build.sh" >/dev/null 2>&1; echo $?)"

repo="$work/repo"; mkdir -p "$repo/wf"; git -C "$repo" init -q
check "build: refuses a tracked git dir" "2" "$(bash "$scripts/wireframe-build.sh" "$repo/wf" >/dev/null 2>&1; echo $?)"
echo "wf/" >"$repo/.gitignore"
check "build: accepts a git-ignored dir" "0" "$(bash "$scripts/wireframe-build.sh" "$repo/wf" >/dev/null 2>&1; echo $?)"

d="$work/ok"; fresh "$d"
out="$(lint "$d" --vocabulary "$work/vocab.md")"
check "check: valid draft passes"   "0" "$(lint "$d" --vocabulary "$work/vocab.md" >/dev/null; echo $?)"
has   "check: OK line"              "OK 3 board(s)" "$out"
has   "check: not-linked reported"  "NOTLINKED	projects.html	Export" "$out"
hasnt "check: shell links not reported" "Clients" "$out"

# bad <dir> <label> <expected-fragment>: mutate a board, expect the problem
bad() {
  local label="$1" file="$2" from="$3" to="$4" want="$5"
  fresh "$d"; FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$d/$file"
  local out; out="$(lint "$d" --vocabulary "$work/vocab.md")"; local rc=$?
  check "check: $label exits 1" "1" "$rc"
  has   "check: $label message" "$want" "$out"
}
bad "unknown class"       projects.html 'class="btn p"' 'class="btn fancy"' 'class `fancy` is not in the kit'
bad "missing link target" projects.html 'href="project-new.html"' 'href="nowhere.html"' 'no such board'
bad "missing data-pattern" projects.html ' data-pattern="List page"' '' 'has no data-pattern'
bad "pattern not in vocabulary" projects.html 'data-pattern="List page"' 'data-pattern="Fancy grid"' 'data-pattern `Fancy grid` is not'
bad "draft meta missing"  projects.html '<meta name="board-kind" content="draft">' '' 'board-kind meta is not draft'
bad "final kind rejected" projects.html 'content="draft"' 'content="final"' 'board-kind meta is not draft'
bad "style block"         projects.html '</head>' '<style>.x{color:red}</style></head>' 'a <style> block'
bad "script"              projects.html '</body>' '<script>1</script></body>' 'a <script>'
bad "extra stylesheet"    projects.html '</head>' '<link rel="stylesheet" href="x.css"></head>' 'stylesheet `x.css`'
bad "colour in style"     projects.html 'style="padding:6px 14px;flex:1"' 'style="color:#f00"' 'inline style property `color`'
bad "button in a"         projects.html '<a class="btn" href="#">Export</a>' '<a class="btn" href="#"><button>Export</button></a>' '<button> inside an <a>'
bad "lorem ipsum"         projects.html 'Export' 'Lorem ipsum dolor' 'lorem ipsum'
bad "emoji"               projects.html 'Export' 'Export 🚀' 'emoji'
bad "pasted shell"        projects.html 'data-nav="clients" href="#">Clients' 'data-nav="clients" href="#">Customers' 'shell differs from parts/shell.side.html'
bad "phone shell edited"  projects.phone.html '>Clients<' '>Customers<' 'shell differs from parts/shell.bottomnav.html'
bad "shell in fragment"   projects.main.html '<div class="rowx">' '<div class="chrome"></div><div class="rowx">' 'shell class `chrome` in a fragment'
bad "no wf root"          projects.html 'class="wf"' 'class="frame"' 'no .wf root'

fresh "$d"; rm "$d/projects.html"
has   "check: unbuilt fragment"     "no built page projects.html" "$(lint "$d" --vocabulary "$work/vocab.md")"

fresh "$d"; rm "$d/parts/shell.side.html"
has   "check: shell part missing"   "shared shell part parts/shell.side.html is missing" "$(lint "$d" --vocabulary "$work/vocab.md")"

fresh "$d"; perl -0pi -e 's/<nav class="side" data-pattern="App shell"/<nav class="side"/' "$d/parts/shell.side.html"
has   "check: shell part needs a pattern" "parts/shell.side.html: structural block" "$(lint "$d" --vocabulary "$work/vocab.md")"

check "check: needs --vocabulary exits 2" "2" "$(bash "$scripts/wireframe-check.sh" "$d" >/dev/null 2>&1; echo $?)"
check "check: missing dir exits 2"        "2" "$(bash "$scripts/wireframe-check.sh" "$work/nope" --vocabulary "$work/vocab.md" >/dev/null 2>&1; echo $?)"
check "check: missing vocabulary exits 2" "2" "$(bash "$scripts/wireframe-check.sh" "$d" --vocabulary "$work/nope.md" >/dev/null 2>&1; echo $?)"

# the shipped skeletons and stylesheet are themselves clean boards
check "kit: stylesheet loads strokes by relative url" "3" "$(grep -o 'strokes/box-[a-z]*\.svg' "$kit/wireframe.css" | sort -u | wc -l | tr -d ' ')"
for f in "$kit"/strokes/*.svg; do check "kit: $(basename "$f") is svg" "<svg" "$(head -c 4 "$f")"; done

if [ "$failures" -eq 0 ]; then echo "PASS: wireframe"; exit 0; fi
echo "FAIL: $failures wireframe case(s) failed"; exit 1
