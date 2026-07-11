#!/usr/bin/env bash
# worktree-setup.sh — idempotent per-story worktree provision + branch ownership.
#
# Provisions (or reuses) exactly ONE persistent git worktree per story, replacing the harness's
# per-dispatch `isolation: "worktree"` (which left an unreclaimed worktree behind after every
# domain-agent dispatch — measured 8.7 GB / 7 dispatches on NA-22, host disk 99%). The orchestrator
# (principal-engineer / qa-engineer playbook) calls this ONCE before dispatching the first domain
# agent for a story, and again — idempotently — before any later fix-round dispatch (QA loop,
# /review-fix, /sdlc:loop): a torn-down or GC'd worktree is transparently re-created.
#
# The PRIMARY checkout NEVER checks out the story branch. This script owns branch creation and
# creates it INSIDE the worktree (`git worktree add -b`), so the primary checkout stays on
# <BASE-BRANCH> for the whole story (invariant 1, docs/superpowers/specs/NA-27.md) — provisioning
# can never deadlock on "branch already checked out elsewhere".
#
# Usage:
#   bash worktree-setup.sh <STORY-KEY> <BRANCH> <BASE-BRANCH>
#     e.g. bash worktree-setup.sh NA-27 feat/NA-27 main
#
# On success, prints EXACTLY these two lines (and nothing else on stdout) for the caller to grep
# and thread into every dispatch prompt:
#   WORKTREE=<abs path>
#   NX_CACHE_DIRECTORY=<abs path>
#
# Any hard failure (cannot create/reuse the worktree, or pnpm install fails) -> non-zero exit with
# a clear message on stderr. The orchestrator STOPs the impl phase on failure — it must NEVER fall
# back to dispatching a writing agent into the primary checkout.

set -uo pipefail

STORY_KEY="${1:-}"
BRANCH="${2:-}"
BASE_BRANCH="${3:-}"

if [ -z "$STORY_KEY" ] || [ -z "$BRANCH" ] || [ -z "$BASE_BRANCH" ]; then
  echo "usage: worktree-setup.sh <STORY-KEY> <BRANCH> <BASE-BRANCH>" >&2
  exit 2
fi

PRIMARY_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "worktree-setup.sh: not inside a git repo" >&2
  exit 1
}

WT="$PRIMARY_ROOT/.claude/worktrees/sdlc-$STORY_KEY"
NX_CACHE="$PRIMARY_ROOT/.nx/cache"

if git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null | grep -qF "worktree $WT"; then
  # Case 1: WT already a registered worktree -> reuse (fast-forward to the branch head; no-op if
  # already current). A non-fast-forwardable state is a hard failure — never silently diverge it.
  if ! git -C "$WT" fetch origin "$BRANCH"; then
    echo "worktree-setup.sh: fetch of origin/$BRANCH into $WT failed" >&2
    exit 1
  fi
  if ! git -C "$WT" merge --ff-only "origin/$BRANCH"; then
    echo "worktree-setup.sh: $WT could not fast-forward to origin/$BRANCH (non-fast-forwardable — resolve manually)" >&2
    exit 1
  fi
elif git -C "$PRIMARY_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH" \
  || git -C "$PRIMARY_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  # Case 2: branch exists (local or origin) but no worktree — re-provision after a teardown/GC.
  if ! git -C "$PRIMARY_ROOT" fetch origin "$BRANCH"; then
    echo "worktree-setup.sh: fetch of origin/$BRANCH failed" >&2
    exit 1
  fi
  if ! git -C "$PRIMARY_ROOT" worktree add "$WT" "$BRANCH"; then
    echo "worktree-setup.sh: could not re-provision worktree at $WT for existing branch $BRANCH" >&2
    exit 1
  fi
else
  # Case 3: neither exists — first run. Create the branch INSIDE the worktree from the base; the
  # primary checkout is never touched.
  if ! git -C "$PRIMARY_ROOT" fetch origin "$BASE_BRANCH"; then
    echo "worktree-setup.sh: fetch of origin/$BASE_BRANCH failed" >&2
    exit 1
  fi
  if ! git -C "$PRIMARY_ROOT" worktree add -b "$BRANCH" "$WT" "origin/$BASE_BRANCH"; then
    echo "worktree-setup.sh: could not create worktree $WT with new branch $BRANCH from origin/$BASE_BRANCH" >&2
    exit 1
  fi
fi

# Provision node_modules ONCE per worktree (spec Open Question 1, decided). pnpm's content-addressed
# global store hardlinks across worktrees, so this is cheap; it also builds the correct per-package
# node_modules link farms a pnpm workspace needs — a root-only symlink to the primary checkout's
# node_modules is deliberately NOT used (rejected in spec: it breaks those per-package link farms).
if [ ! -d "$WT/node_modules" ]; then
  if ! (cd "$WT" && pnpm install --prefer-offline --frozen-lockfile); then
    echo "worktree-setup.sh: pnpm install --prefer-offline --frozen-lockfile failed in $WT" >&2
    exit 1
  fi
fi

printf 'WORKTREE=%s\n' "$WT"
printf 'NX_CACHE_DIRECTORY=%s\n' "$NX_CACHE"
exit 0
