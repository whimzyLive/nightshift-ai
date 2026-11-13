#!/usr/bin/env bash
# wireframe-build.sh <dir> [--kit <kit-dir>]
#
# Assembles standalone wireframe pages in <dir> from the shared shell parts and the per-screen
# main fragments, so a page plays in a plain browser with no canvas.
#
#   <dir>/parts/shell.side.html        web nav (`<nav class="side">`), written once per run
#   <dir>/parts/shell.bottomnav.html   phone nav (`<nav class="bottomnav">`), written once per run
#   <dir>/<screen>.main.html           web main slot      -> <dir>/<screen>.html
#   <dir>/<screen>.phone.main.html     phone screen slot  -> <dir>/<screen>.phone.html
#
# A fragment's first line is `<!-- wf title: <t> | nav: <data-nav key> | url: <path> -->`; every key is
# optional. `nav` marks the shell link whose `data-nav` matches as the current one (class `on`).
# Also copies wireframe.css and strokes/ from the kit next to the pages (the CSS loads strokes by
# relative URL). Prints one `BUILT <file>` line per page. Exit 1 on a missing part, 2 on bad usage.
# <dir> must be outside any git work tree or git-ignored (drafts are never committed).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
kit="$(cd "$here/../refs/wireframe-kit" && pwd)"
dir=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --kit) kit="${2:-}"; shift 2 ;;
    -*) echo "wireframe-build.sh: unknown argument '$1'" >&2; exit 2 ;;
    *) dir="$1"; shift ;;
  esac
done
[ -n "$dir" ] || { echo "usage: wireframe-build.sh <dir> [--kit <kit-dir>]" >&2; exit 2; }
[ -d "$dir" ] || { echo "wireframe-build.sh: not a directory: $dir" >&2; exit 2; }
for f in wireframe.css skeleton.web.html skeleton.phone.html; do
  [ -f "$kit/$f" ] || { echo "wireframe-build.sh: kit file missing: $kit/$f" >&2; exit 2; }
done

if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git -C "$dir" check-ignore -q "$dir" 2>/dev/null; then
  echo "wireframe-build.sh: $dir is inside a git work tree and not git-ignored; use scripts/tmp-dir.sh output" >&2
  exit 2
fi

cp "$kit/wireframe.css" "$dir/wireframe.css"
mkdir -p "$dir/strokes" && cp "$kit"/strokes/*.svg "$dir/strokes/"

status=0
shopt -s nullglob
for src in "$dir"/*.main.html; do
  base="${src##*/}"; base="${base%.main.html}"
  case "$base" in
    *.phone) kind=phone; shell_part="$dir/parts/shell.bottomnav.html"; skeleton="$kit/skeleton.phone.html" ;;
    *)       kind=web;   shell_part="$dir/parts/shell.side.html";      skeleton="$kit/skeleton.web.html" ;;
  esac
  if [ ! -f "$shell_part" ]; then
    echo "wireframe-build.sh: missing ${shell_part#"$dir"/} for ${src##*/}" >&2; status=1; continue
  fi
  WF_SRC="$src" WF_SHELL="$shell_part" WF_SKEL="$skeleton" WF_KIND="$kind" perl -0e '
    sub slurp { local $/; open(my $h, "<", $_[0]) or die "cannot read $_[0]: $!"; my $t = <$h>; close $h; $t }
    my $main = slurp($ENV{WF_SRC});
    my %m;
    if ($main =~ s/\A\s*<!--\s*wf\b(.*?)-->\s*//s) {
      for my $kv (split /\|/, $1) { $m{$1} = $2 if $kv =~ /^\s*(\w+)\s*:\s*(.*?)\s*$/s }
    }
    my $shell = slurp($ENV{WF_SHELL});
    $shell =~ s{<a\b[^>]*\bdata-nav="[^"]*"[^>]*>}{
      my $t = $&; my $key = $t =~ /data-nav="([^"]*)"/ ? $1 : "";
      $t =~ s/(class="[^"]*?)\s+on\b/$1/;
      if (length $m{nav} && $key eq $m{nav}) {
        $t =~ s/class="([^"]*)"/class="$1 on"/ or $t =~ s/>$/ class="on">/;
      }
      $t }gex;
    my $page = slurp($ENV{WF_SKEL});
    my $title = $m{title} // "Wireframe";
    my $url = $m{url} // "";
    my %v = (TITLE => $title, URL => $url, SHELL => $shell, NAV => $shell, MAIN => $main);
    $page =~ s/\{\{(\w+)\}\}/exists $v{$1} ? $v{$1} : $&/ge;
    $page =~ s/\n{3,}/\n\n/g;
    print $page;
  ' >"$dir/$base.html.tmp" && mv "$dir/$base.html.tmp" "$dir/$base.html" && echo "BUILT $base.html" \
    || { rm -f "$dir/$base.html.tmp"; echo "wireframe-build.sh: failed to build $base.html" >&2; status=1; }
done
exit "$status"
