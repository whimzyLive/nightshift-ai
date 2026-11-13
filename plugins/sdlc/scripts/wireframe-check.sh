#!/usr/bin/env bash
# wireframe-check.sh <dir> --vocabulary <file> [--kit <kit-dir>]
#
# Lints the wireframe boards in <dir> (the output of wireframe-build.sh). One line per problem on
# stdout, `FAIL <file>: <problem>`; exit 1 when any, else a final `OK <n> board(s)` and exit 0.
# Exit 2 on bad usage. `NOTLINKED<TAB><file><TAB><label>` lines (a link-style control that goes
# nowhere in this draft) are information, not problems.
#
# Boards are <dir>/*.html except *.main.html (fragments). Problems reported:
#   - a class outside the kit vocabulary (the selectors of wireframe.css), a <style> or <script>,
#     a stylesheet other than wireframe.css and the font, an inline style property outside layout
#   - an <a href> to a local board that is not in <dir>
#   - a <button> inside an <a>
#   - a structural block (.sk .sk2 .note .stat .cols .tabs .side .bottomnav) with no data-pattern
#   - a data-pattern that is neither `?` nor a name in the vocabulary file: a table cell, a heading,
#     or the lead of a list item (up to ` - `, ` — ` or `: `), markdown emphasis ignored
#   - the draft meta (`board-kind` = draft) missing, or no .wf root
#   - the shell pasted: shell classes in a fragment, a page whose shell differs from parts/shell.*.html
#     (the `on` class aside), a fragment with no built page
#   - lorem ipsum or an emoji in the copy
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
kit="$(cd "$here/../refs/wireframe-kit" 2>/dev/null && pwd)"
dir=""; vocab=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --vocabulary) vocab="${2:-}"; shift 2 ;;
    --kit) kit="${2:-}"; shift 2 ;;
    -*) echo "wireframe-check.sh: unknown argument '$1'" >&2; exit 2 ;;
    *) dir="$1"; shift ;;
  esac
done
[ -n "$dir" ] && [ -n "$vocab" ] || { echo "usage: wireframe-check.sh <dir> --vocabulary <file> [--kit <kit-dir>]" >&2; exit 2; }
[ -d "$dir" ] || { echo "wireframe-check.sh: not a directory: $dir" >&2; exit 2; }
[ -f "$vocab" ] || { echo "wireframe-check.sh: vocabulary file not found: $vocab" >&2; exit 2; }
[ -f "$kit/wireframe.css" ] || { echo "wireframe-check.sh: kit stylesheet not found: $kit/wireframe.css" >&2; exit 2; }

WF_DIR="$dir" WF_VOCAB="$vocab" WF_CSS="$kit/wireframe.css" perl -e '
use strict; use warnings;
sub slurp { local $/; open(my $h, "<:utf8", $_[0]) or die "cannot read $_[0]: $!"; my $t = <$h>; close $h; $t }
binmode(STDOUT, ":utf8");
my $dir = $ENV{WF_DIR};

my $css = slurp($ENV{WF_CSS}); $css =~ s/url\([^)]*\)//g;
my %kitclass; $kitclass{$1} = 1 while $css =~ /\.([A-Za-z_][\w-]*)/g;

my %name = ("?" => 1);
for my $line (split /\n/, slurp($ENV{WF_VOCAB})) {
  (my $l = $line) =~ s/[`*_]//g;
  my @pieces = map { s/^\s+|\s+$//gr } split /\|/, $l;
  for my $p (@pieces) {
    (my $q = $p) =~ s/^(?:#+|[-+*]|\d+\.)\s+//;
    $name{$q} = 1 if length $q;
    $name{$1} = 1 if $q =~ /^(.+?)\s+(?:-|\x{2014}|\x{2013}|=)\s+/ || $q =~ /^(.+?):\s/;
  }
}

my %shellclass = map { $_ => 1 } qw(wf chrome lights url bodyrow side logo bottomnav device screen main);
my %structural = map { $_ => 1 } qw(sk sk2 note stat cols tabs side bottomnav);
my %styleok = map { $_ => 1 } qw(display flex flex-direction flex-wrap flex-grow flex-shrink flex-basis grid grid-template-columns grid-template-rows grid-column grid-row gap row-gap column-gap width height min-width max-width min-height max-height padding padding-top padding-right padding-bottom padding-left margin margin-top margin-right margin-bottom margin-left align-items align-self align-content justify-content justify-items justify-self place-items place-content position top right bottom left overflow text-align z-index order box-sizing);

my $problems = 0;
sub fail { my ($f, $msg) = @_; print "FAIL $f: $msg\n"; $problems++ }
sub lineno { my ($t, $pos) = @_; return 1 + (substr($t, 0, $pos) =~ tr/\n//) }
sub norm_shell { my $s = shift; $s =~ s/\s+class="on"//g; $s =~ s/(class="[^"]*?)\s+on\b/$1/g; $s =~ s/\s+/ /g; $s =~ s/> </></g; $s }
sub shell_block { my ($t, $cls) = @_; return $t =~ m{(<nav\b[^>]*\bclass="$cls"[^>]*>.*?</nav>)}s ? $1 : undef }

opendir(my $dh, $dir) or die; my @all = sort grep { /\.html$/ && !/^\./ } readdir($dh); closedir $dh;
my @frags = grep { /\.main\.html$/ } @all;
my @pages = grep { !/\.main\.html$/ } @all;
my %have = map { $_ => 1 } @pages;

my %shell = (web => "parts/shell.side.html", phone => "parts/shell.bottomnav.html");
my %shell_text;
for my $k (keys %shell) { $shell_text{$k} = slurp("$dir/$shell{$k}") if -f "$dir/$shell{$k}" }

for my $f (@frags) {
  (my $page = $f) =~ s/\.main\.html$/.html/;
  fail($f, "no built page $page (run wireframe-build.sh)") unless $have{$page};
  my $t = slurp("$dir/$f");
  while ($t =~ /<[a-zA-Z][\w-]*\b[^>]*\bclass="([^"]*)"[^>]*>/g) {
    my $pos = $-[0];
    for my $c (split " ", $1) {
      fail($f, "shell class `$c` in a fragment; the shell is shared (parts/) (line " . lineno($t, $pos) . ")") if $shellclass{$c};
    }
  }
}

for my $f (@pages) {
  my $t = slurp("$dir/$f");
  my $kind = $t =~ /class="wf phone"/ ? "phone" : "web";

  fail($f, "board-kind meta is not draft") unless $t =~ m{<meta\s+name="board-kind"\s+content="draft"\s*/?>}i || $t =~ m{<meta\s+content="draft"\s+name="board-kind"\s*/?>}i;
  fail($f, "no .wf root") unless $t =~ /class="wf(?:\s+phone)?"/;

  my $cls = $kind eq "phone" ? "bottomnav" : "side";
  my $block = shell_block($t, $cls);
  if (!defined $block) { fail($f, "no shell (nav.$cls)") }
  elsif (!defined $shell_text{$kind}) { fail($f, "shared shell part $shell{$kind} is missing") }
  else {
    my $part = shell_block($shell_text{$kind}, $cls);
    fail($f, "shell differs from $shell{$kind}; edit the part, never the page") if !defined $part || norm_shell($part) ne norm_shell($block);
  }

  # shell and parts are checked once, in parts/, so each page is scanned without its shell.
  my $body = $t;
  $body =~ s{(<nav\b[^>]*\bclass="(?:side|bottomnav)"[^>]*>.*?</nav>)}{ my $b = $1; $b =~ s/[^\n]//g; $b }gse;

  while ($body =~ /<style\b/gi) { fail($f, "a <style> block; use kit classes (line " . lineno($body, $-[0]) . ")") }
  while ($body =~ /<script\b/gi) { fail($f, "a <script>; boards are static (line " . lineno($body, $-[0]) . ")") }
  while ($body =~ /<link\b[^>]*>/gi) {
    my $tag = $&;
    next unless $tag =~ /rel="stylesheet"/i;
    my ($href) = $tag =~ /href="([^"]*)"/i; $href //= "";
    fail($f, "stylesheet `$href` is not wireframe.css or the font (line " . lineno($body, $-[0]) . ")") unless $href eq "wireframe.css" || $href =~ m{^https://fonts\.googleapis\.com/};
  }
  while ($body =~ /<a\b[^>]*>(?:(?!<\/a>).)*?<button\b/gis) { fail($f, "a <button> inside an <a>; style the <a> as the button (line " . lineno($body, $-[0]) . ")") }
  fail($f, "lorem ipsum in the copy") if $body =~ /lorem ipsum/i;
  fail($f, "emoji in the copy; use an inline stroke svg") if $body =~ /[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/;

  my %seen;
  while ($body =~ /<([a-zA-Z][\w-]*)\b([^>]*)>/g) {
    my ($tag, $attr, $pos) = ($1, $2, $-[0]);
    my $ln = lineno($body, $pos);
    my @classes = $attr =~ /\bclass="([^"]*)"/ ? split(" ", $1) : ();
    for my $c (@classes) {
      next if $kitclass{$c} || $seen{"$c:$ln"}++;
      fail($f, "class `$c` is not in the kit (line $ln)");
    }
    if ($attr =~ /\bstyle="([^"]*)"/) {
      for my $decl (split /;/, $1) {
        next unless $decl =~ /^\s*([\w-]+)\s*:/;
        fail($f, "inline style property `$1` is not layout (line $ln)") unless $styleok{$1};
      }
    }
    my $has = $attr =~ /\bdata-pattern="([^"]*)"/ ? $1 : undef;
    if (defined $has) {
      fail($f, "data-pattern `$has` is not `?` or a name in the vocabulary (line $ln)") unless $name{$has};
    } elsif (grep { $structural{$_} } @classes) {
      fail($f, "structural block <$tag class=\"@classes\"> has no data-pattern (line $ln)");
    }
  }

  while ($body =~ m{<a\b([^>]*)>(.*?)</a>}gis) {
    my ($attr, $inner) = ($1, $2);
    my $pos = $-[0];
    next unless $attr =~ /\bhref="([^"]*)"/;
    my $href = $1;
    if ($href eq "" || $href =~ /^#/) {
      (my $label = $inner) =~ s/<[^>]*>//g; $label =~ s/\s+/ /g; $label =~ s/^ | $//g;
      print "NOTLINKED\t$f\t$label\n" if length $label;
      next;
    }
    next if $href =~ m{^(?:[a-z][a-z0-9+.-]*:|//)}i;
    (my $path = $href) =~ s/[#?].*//;
    fail($f, "link to `$href` but no such board in the folder (line " . lineno($body, $pos) . ")") unless -f "$dir/$path";
  }
}

for my $k (sort keys %shell_text) {
  my $t = $shell_text{$k}; my $f = $shell{$k};
  my $ln;
  while ($t =~ /<([a-zA-Z][\w-]*)\b([^>]*)>/g) {
    my ($tag, $attr, $pos) = ($1, $2, $-[0]); $ln = lineno($t, $pos);
    my @classes = $attr =~ /\bclass="([^"]*)"/ ? split(" ", $1) : ();
    for my $c (@classes) { fail($f, "class `$c` is not in the kit (line $ln)") unless $kitclass{$c} }
    my $has = $attr =~ /\bdata-pattern="([^"]*)"/ ? $1 : undef;
    if (defined $has) { fail($f, "data-pattern `$has` is not `?` or a name in the vocabulary (line $ln)") unless $name{$has} }
    elsif (grep { $structural{$_} } @classes) { fail($f, "structural block <$tag class=\"@classes\"> has no data-pattern (line $ln)") }
  }
}

if ($problems) { exit 1 }
printf "OK %d board(s)\n", scalar @pages;
'
