#!/usr/bin/env bash
# capture-learning.sh — NA-98. Write ONE learning capture into the gitignored staging area.
#
# usage: capture-learning.sh rule   <agent-or-shared>/<rule-id> <STORY-KEY> [<body-file>|-]
#        capture-learning.sh review <STORY-KEY> <YYYY-MM-DD> <round>       [<body-file>|-]
#        capture-learning.sh --print-root
#
# Prints CAPTURED=<path> on success. Reads exactly one environment variable, SDLC_CAPTURE_ROOT.
# Never reads stdin.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/frontmatter-lib.sh"

die() { printf '%s\n' "$1" >&2; exit 1; }

resolve_capture_root() {
  if [ -n "${SDLC_CAPTURE_ROOT:-}" ]; then
    printf '%s\n' "$SDLC_CAPTURE_ROOT"
    return 0
  fi
  local porcelain main
  porcelain="$(git worktree list --porcelain 2>/dev/null)" \
    || die "capture-learning.sh: 'git worktree list --porcelain' failed — cannot resolve the staging root; wrote nothing"
  printf '%s\n' "$porcelain" | head -3 | grep -q '^bare$' \
    && die "capture-learning.sh: main repository is bare — no primary checkout to capture into; wrote nothing"
  main="$(printf '%s\n' "$porcelain" | sed -n 's/^worktree //p' | head -1)"
  [ -n "$main" ] \
    && printf '%s\n' "$main/.claude/memories/captured" \
    || die "capture-learning.sh: no 'worktree ' entry in git worktree list output; wrote nothing"
}

ensure_capture_root() {
  local root="$1"
  mkdir -p "$root/rules" "$root/reviews" 2>/dev/null \
    || die "capture-learning.sh: cannot create staging root '$root' — check permissions and that no path segment is a file; wrote nothing"
  [ -w "$root" ] \
    || die "capture-learning.sh: staging root '$root' is not writable; wrote nothing"
  [ -f "$root/.gitignore" ] || printf '*\n!.gitignore\n' > "$root/.gitignore" \
    || die "capture-learning.sh: cannot write the ignore marker in '$root'; wrote nothing"
}

if [ "${1:-}" = "--print-root" ]; then
  root="$(resolve_capture_root)" || exit 1
  ensure_capture_root "$root"
  printf '%s\n' "$root"
  exit 0
fi
