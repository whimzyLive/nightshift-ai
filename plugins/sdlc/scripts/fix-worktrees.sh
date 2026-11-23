#!/usr/bin/env bash
# fix-worktrees.sh — per-agent worktrees for a parallel QA fix round (refs/parallel-fixes.md).
# Run from the PRIMARY checkout, after worktree-setup.sh has provisioned the story worktree.
#
#   fix-worktrees.sh enabled                       exit 0 iff project-context `SDLC parallel fixes` is `enabled`
#   fix-worktrees.sh add    <KEY> <TAG>            worktree + branch off the story worktree HEAD
#   fix-worktrees.sh merge  <KEY> <TAG>            cherry-pick that branch's commits onto the story branch
#   fix-worktrees.sh remove <KEY> [<TAG>]          drop one fix worktree + branch, or every one for <KEY>
#
# add    -> WORKTREE=<abs> FIX_BRANCH=<name> BASE_SHA=<sha>; exit 3 = node_modules cannot be cloned
#           cheaply (no copy-on-write filesystem) and the worktree was removed again: run sequentially.
# merge  -> RESULT=merged COMMITS=<n> | empty (exit 4) | dirty (exit 6) | conflict (exit 5);
#           a non-merged result leaves the story worktree exactly as it was.
# remove -> always exit 0.
#
# Dependencies are cloned from the story worktree with a copy-on-write copy (`cp -c` on macOS,
# `cp --reflink=always` on Linux), never installed: the fix branch has the story's own lockfile.

set -uo pipefail

CMD="${1:-}"
KEY="${2:-}"
TAG="${3:-}"

usage() {
  echo "usage: fix-worktrees.sh enabled | add <KEY> <TAG> | merge <KEY> <TAG> | remove <KEY> [<TAG>]" >&2
  exit 2
}

PRIMARY_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "fix-worktrees.sh: not inside a git repo" >&2
  exit 1
}

if [ "$CMD" = "enabled" ]; then
  CTX="$PRIMARY_ROOT/.claude/project/project-context.md"
  VALUE="$(grep -iE '^\|[[:space:]]*SDLC parallel fixes[[:space:]]*\|' "$CTX" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([A-Za-z0-9_.\/-]+)`?[[:space:]]*\|.*/\1/' \
    | head -1 || true)"
  [ "$VALUE" = "enabled" ]
  exit $?
fi

[ -n "$KEY" ] || usage
case "$CMD" in
  add | merge) [ -n "$TAG" ] || usage ;;
  remove) ;;
  *) usage ;;
esac
case "$KEY$TAG" in
  *[!A-Za-z0-9._-]*) echo "fix-worktrees.sh: KEY and TAG may only use A-Z a-z 0-9 . _ -" >&2; exit 2 ;;
esac

STORY_WT="$PRIMARY_ROOT/.claude/worktrees/sdlc-$KEY"
fix_wt() { printf '%s/.claude/worktrees/sdlc-%s-fix-%s' "$PRIMARY_ROOT" "$KEY" "$1"; }
fix_branch() { printf 'sdlc-fix/%s-%s' "$KEY" "$1"; }

drop() {
  wt="$(fix_wt "$1")"
  git -C "$PRIMARY_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  git -C "$PRIMARY_ROOT" worktree prune >/dev/null 2>&1 || true
  git -C "$PRIMARY_ROOT" branch -D "$(fix_branch "$1")" >/dev/null 2>&1 || true
}

# Copy-on-write clone of one directory into <dst>/; GNU cp reads `-c` as a SELinux flag and would
# make a full copy, so `-c` is macOS-only.
clone_dir() {
  src="$1"
  dst="$2"
  case "$(uname -s)" in
    Darwin) cp -cRP "$src" "$dst" >/dev/null 2>&1 ;;
    *) cp -RP --reflink=always "$src" "$dst" >/dev/null 2>&1 ;;
  esac || {
    rm -rf "$dst/$(basename "$src")"
    return 1
  }
}

case "$CMD" in
  remove)
    if [ -n "$TAG" ]; then
      drop "$TAG"
    else
      git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null \
        | sed -n "s|^worktree $PRIMARY_ROOT/.claude/worktrees/sdlc-$KEY-fix-||p" \
        | while IFS= read -r t; do drop "$t"; done
    fi
    exit 0
    ;;

  add)
    [ -d "$STORY_WT" ] || { echo "fix-worktrees.sh: no story worktree at $STORY_WT — run worktree-setup.sh first" >&2; exit 1; }
    drop "$TAG"
    base="$(git -C "$STORY_WT" rev-parse HEAD)" || exit 1
    wt="$(fix_wt "$TAG")"
    br="$(fix_branch "$TAG")"
    if ! git -C "$PRIMARY_ROOT" worktree add -b "$br" "$wt" "$base" >&2; then
      echo "fix-worktrees.sh: could not create $wt" >&2
      exit 1
    fi
    git -C "$wt" config extensions.worktreeConfig true
    git -C "$wt" config --worktree sdlc.provisionSha "$base"

    nm_list="$(find "$STORY_WT" -maxdepth 4 \( -name .git -o -name .claude \) -prune -o -name node_modules -type d -print -prune 2>/dev/null)"
    while IFS= read -r nm; do
      [ -n "$nm" ] || continue
      rel="${nm#"$STORY_WT"/}"
      parent="$wt/$(dirname "$rel")"
      mkdir -p "$parent"
      if ! clone_dir "$nm" "$parent"; then
        echo "fix-worktrees.sh: no copy-on-write clone of $rel here — a full install would cost minutes; run this fix sequentially" >&2
        drop "$TAG"
        exit 3
      fi
    done <<EOF
$nm_list
EOF
    printf 'WORKTREE=%s\nFIX_BRANCH=%s\nBASE_SHA=%s\n' "$wt" "$br" "$base"
    exit 0
    ;;

  merge)
    wt="$(fix_wt "$TAG")"
    br="$(fix_branch "$TAG")"
    [ -d "$STORY_WT" ] && [ -d "$wt" ] || { echo "RESULT=error"; echo "fix-worktrees.sh: missing worktree for $KEY/$TAG" >&2; exit 1; }
    if [ -n "$(git -C "$STORY_WT" status --porcelain 2>/dev/null)" ]; then
      echo "RESULT=error"
      echo "fix-worktrees.sh: story worktree has uncommitted changes" >&2
      exit 1
    fi
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
      echo "RESULT=dirty"
      exit 6
    fi
    pre="$(git -C "$STORY_WT" rev-parse HEAD)"
    base="$(git -C "$STORY_WT" merge-base "$pre" "$br")" || { echo "RESULT=error"; exit 1; }
    commits="$(git -C "$STORY_WT" rev-list --reverse --no-merges "$base..$br")"
    if [ -z "$commits" ]; then
      echo "RESULT=empty"
      exit 4
    fi
    n="$(printf '%s\n' "$commits" | wc -l | tr -d ' ')"
    # shellcheck disable=SC2086
    if git -C "$STORY_WT" cherry-pick $commits >/dev/null 2>&1; then
      printf 'RESULT=merged COMMITS=%s\n' "$n"
      exit 0
    fi
    git -C "$STORY_WT" cherry-pick --abort >/dev/null 2>&1 || true
    [ "$(git -C "$STORY_WT" rev-parse HEAD)" = "$pre" ] || git -C "$STORY_WT" reset -q --hard "$pre"
    echo "RESULT=conflict"
    exit 5
    ;;
esac
