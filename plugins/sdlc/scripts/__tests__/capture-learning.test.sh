#!/usr/bin/env bash
# capture-learning.test.sh — NA-98. Behaviour suite for capture-learning.sh + list-captured.sh.
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/capture-learning.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
scripts="$here/.."
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

# --- T1: frontmatter-lib round-trips a rule frontmatter block ---------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/sample.md" <<'EOF'
---
id: sample-rule
agent: [web-engineer]
trigger: [one, two]
rule: When X, do Y.
evidence: [AB-1]
uses: 0
status: captured
---

## Why

Body line.
EOF

# shellcheck source=/dev/null
. "$scripts/frontmatter-lib.sh"
parsed="$(extract_fm "$tmp/sample.md" | parse_frontmatter)"
[ "$(field_value "$parsed" id)" = "sample-rule" ] \
  && ok "(T1a) field_value id" || bad "(T1a) field_value id" "got '$(field_value "$parsed" id)'"
list_contains "$(field_value "$parsed" agent)" "web-engineer" \
  && ok "(T1b) list_contains agent" || bad "(T1b) list_contains agent" "agent list did not contain web-engineer"
has_field "$parsed" status \
  && ok "(T1c) has_field status" || bad "(T1c) has_field status" "status missing"

# --- T2: staging-root resolution -------------------------------------------
cap="$scripts/capture-learning.sh"

# T2a: SDLC_CAPTURE_ROOT wins verbatim, and is created when absent
root_a="$tmp/explicit-root"
SDLC_CAPTURE_ROOT="$root_a" bash "$cap" --print-root > "$tmp/out_a" 2>"$tmp/err_a"
[ "$(cat "$tmp/out_a")" = "$root_a" ] \
  && ok "(T2a) SDLC_CAPTURE_ROOT used verbatim" || bad "(T2a) SDLC_CAPTURE_ROOT verbatim" "got '$(cat "$tmp/out_a")'"
[ -d "$root_a/rules" ] && [ -d "$root_a/reviews" ] && [ -f "$root_a/.gitignore" ] \
  && ok "(T2b) root scaffolded (rules, reviews, .gitignore)" || bad "(T2b) root scaffolded" "missing subdir or marker"
[ "$(cat "$root_a/.gitignore")" = "$(printf '*\n!.gitignore')" ] \
  && ok "(T2c) marker content exact" || bad "(T2c) marker content" "got '$(cat "$root_a/.gitignore")'"

# T2d: set-but-unwritable SDLC_CAPTURE_ROOT is a hard error, writes nothing
printf 'not a dir\n' > "$tmp/blocker"
SDLC_CAPTURE_ROOT="$tmp/blocker/nested" bash "$cap" --print-root >/dev/null 2>"$tmp/err_d"
[ "$?" -ne 0 ] && ok "(T2d) unwritable override exits non-zero" || bad "(T2d) unwritable override" "exited 0"

# T2e: from a linked worktree, the root resolves to the MAIN worktree
wt_repo="$tmp/repo"; mkdir -p "$wt_repo"
wt_repo="$(cd "$wt_repo" && pwd -P)"  # canonicalise: git worktree list --porcelain always resolves symlinks (e.g. macOS /tmp -> /private/tmp)
git -C "$wt_repo" init -q
git -C "$wt_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$wt_repo" worktree add -q "$tmp/linked" -b linked >/dev/null 2>&1
got="$(cd "$tmp/linked" && bash "$cap" --print-root)"
case "$got" in
  "$wt_repo"/.claude/memories/captured) ok "(T2e) linked worktree resolves to main checkout" ;;
  *) bad "(T2e) linked worktree resolves to main checkout" "got '$got'" ;;
esac

exit "$fail"
