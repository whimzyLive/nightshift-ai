#!/usr/bin/env bash
# worktree-gc.sh — merged-into-origin/<BASE-BRANCH>-only worktree reclamation. ALWAYS exits 0
# (mirrors cleanup-tmp.sh) — a GC failure must never fail a session.
#
# Removes worktrees under .claude/worktrees/ whose checked-out branch is FULLY MERGED into
# origin/<BASE-BRANCH> — the ONLY safe removal gate: never a worktree's own branch, and never an
# in-flight or concurrent-session worktree whose branch hasn't landed yet. Targets BOTH this
# story's managed `sdlc-*` worktrees (worktree-setup.sh) and any stray harness `agent-*` leftovers
# (the measured 8.7 GB / 7 dispatches on NA-22) — both gated on the identical merge check, so
# neither kind is ever removed while still in flight.
#
# Usage:
#   bash worktree-gc.sh [STORY-KEY]
#     STORY-KEY is OPTIONAL and only narrows the log lines — it does NOT gate removal. The base
#     is always origin/<BASE-BRANCH>, defined even with no arg (the SessionEnd case).
#
# Called from:
#   - session-complete.sh (happy-path session teardown, alongside the scoped-temp clean)
#   - hooks.json SessionEnd (safety net for a session that errors before session-complete.sh runs)

set -uo pipefail

STORY_KEY="${1:-}"

# Whole body wrapped in a function so ANY error path still falls through to the unconditional
# `exit 0` below — a GC failure (locked worktree, removed dir, unreadable repo) must never fail
# the session it is cleaning up after.
gc_main() {
  PRIMARY_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "worktree-gc.sh: not inside a git repo — skipping" >&2
    return 0
  }

  # Base branch: read the "Base branch" token from project-context.md so this published script
  # stays portable across installs of this plugin; default to main when the file/row is missing
  # or unreadable (this repo's own project-context.md: Base branch = main, not develop).
  CTX="$PRIMARY_ROOT/.claude/project/project-context.md"
  BASE_BRANCH="$(grep -iE '^\|[[:space:]]*Base branch[[:space:]]*\|' "$CTX" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([A-Za-z0-9_.\/-]+)`?[[:space:]]*\|.*/\1/' \
    | head -1 || true)"
  BASE_BRANCH="${BASE_BRANCH:-main}"
  BASE="origin/$BASE_BRANCH"

  git -C "$PRIMARY_ROOT" fetch origin "$BASE_BRANCH" 2>/dev/null || true

  if [ -n "$STORY_KEY" ]; then
    echo "worktree-gc.sh: run for $STORY_KEY (log context only — removal gate is base = $BASE for every candidate)" >&2
  fi

  # `sed` (not `awk '{print $2}'`) — a worktree path containing spaces would otherwise be truncated
  # to its first whitespace-delimited field.
  worktree_paths="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')"
  [ -n "$worktree_paths" ] || return 0

  while IFS= read -r WT; do
    [ -n "$WT" ] || continue
    wt_base="$(basename "$WT")"
    # Only ever consider this story's managed worktrees (sdlc-*) or stray harness leftovers
    # (agent-*) — never the primary checkout itself or any unrelated worktree.
    case "$wt_base" in
      sdlc-*|agent-*) ;;
      *) continue ;;
    esac

    WB="$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    WH="$(git -C "$WT" rev-parse HEAD 2>/dev/null || true)"
    if [ -z "$WB" ] || [ -z "$WH" ]; then
      echo "worktree-gc.sh: $WT unreadable (already removed or corrupted) — skip" >&2
      continue
    fi

    # `rev-parse --abbrev-ref HEAD` yields the literal string "HEAD" for a detached checkout (not
    # empty) — the `-z "$WB"` check above never catches this case, so it needs its own guard.
    if [ "$WB" = "HEAD" ]; then
      echo "worktree-gc.sh: $WT is in a detached HEAD state — skip" >&2
      continue
    fi

    # The ONLY safe removal gate (spec Global Constraints): (a) never the base branch itself, AND
    # (b) its head is fully merged into origin/<BASE-BRANCH>. Note: `merge-base --is-ancestor` only
    # recognizes MERGE-COMMIT PR integration — a squash-merged PR produces a brand-new commit on
    # origin/<BASE-BRANCH> that this worktree's HEAD is never an ancestor of, so a squash-merge
    # workflow would need a different (e.g. patch-id-based) merged check.
    if [ "$WB" = "$BASE_BRANCH" ]; then
      echo "worktree-gc.sh: $WT is on the base branch itself ($BASE_BRANCH) — skip" >&2
      continue
    fi

    # Defence-in-depth: never remove a worktree with uncommitted work, and never remove a worktree
    # whose branch has zero commits since $BASE yet (freshly provisioned from origin/<BASE-BRANCH>
    # by a concurrent session's dispatch still in flight — its HEAD trivially satisfies "ancestor of
    # $BASE" the instant it's created, well before that session's first commit lands).
    if [ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ]; then
      echo "worktree-gc.sh: $WT has uncommitted changes — skip" >&2
      continue
    fi
    if [ "$WH" = "$(git -C "$PRIMARY_ROOT" rev-parse "$BASE" 2>/dev/null || true)" ]; then
      echo "worktree-gc.sh: $WT has zero commits since $BASE (freshly provisioned, in flight) — skip" >&2
      continue
    fi

    if git -C "$PRIMARY_ROOT" merge-base --is-ancestor "$WH" "$BASE" 2>/dev/null; then
      echo "worktree-gc.sh: removing $WT (branch $WB fully merged into $BASE)" >&2
      if git -C "$PRIMARY_ROOT" worktree remove --force "$WT" 2>/dev/null; then
        git -C "$PRIMARY_ROOT" branch -D "$WB" 2>/dev/null || true
      else
        echo "worktree-gc.sh: failed to remove $WT — continuing" >&2
      fi
    fi
  done <<EOF
$worktree_paths
EOF

  git -C "$PRIMARY_ROOT" worktree prune 2>/dev/null || true
  return 0
}

gc_main
exit 0
