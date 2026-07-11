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

if git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $WT"; then
  # Case 1: WT already a registered worktree -> reuse (fast-forward to the branch head; no-op if
  # already current). A non-fast-forwardable state is a hard failure — never silently diverge it.
  # `-x` (whole-line match) matters here: porcelain lines are exactly `worktree <path>`, and a plain
  # substring match on `worktree $WT` would also match any worktree whose path merely starts with
  # this story's path (e.g. a registered `sdlc-NA-2` worktree matching a probe for `sdlc-NA-27`).
  #
  # If the branch was never pushed (a prior run created the worktree but died before `git push -u`),
  # `origin/$BRANCH` doesn't exist yet — probe for it first and skip the fetch/ff rather than hard
  # failing on every re-invocation forever (idempotent re-provision, invariant 2).
  if git -C "$PRIMARY_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    if ! git -C "$WT" fetch origin "$BRANCH" >&2; then
      echo "worktree-setup.sh: fetch of origin/$BRANCH into $WT failed" >&2
      exit 1
    fi
    if ! git -C "$WT" merge --ff-only "origin/$BRANCH" >&2; then
      echo "worktree-setup.sh: $WT could not fast-forward to origin/$BRANCH (non-fast-forwardable — resolve manually)" >&2
      exit 1
    fi
  else
    echo "worktree-setup.sh: origin/$BRANCH does not exist yet (never pushed) — reusing $WT as-is, skipping fetch/ff" >&2
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

# Provision node_modules ONCE per worktree (spec Open Question 1, decided), and re-provision
# whenever pnpm-lock.yaml has moved on since the last install (e.g. a later phase/fix-round added a
# dependency). pnpm's content-addressed global store hardlinks across worktrees, so this is cheap;
# it also builds the correct per-package node_modules link farms a pnpm workspace needs — a
# root-only symlink to the primary checkout's node_modules is deliberately NOT used (rejected in
# spec: it breaks those per-package link farms).
#
# Cheap idempotent staleness check: hash the worktree's own pnpm-lock.yaml and compare against the
# hash recorded at the last successful install. Missing node_modules (fresh worktree) or a missing
# hash file both count as stale (mismatch against an empty recorded hash), so this also covers the
# original "install once" case with no separate branch.
LOCK_FILE="$WT/pnpm-lock.yaml"
LOCK_HASH_FILE="$WT/node_modules/.sdlc-lock-hash"
hash_lockfile() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$LOCK_FILE" 2>/dev/null | awk '{print $1}'
  else
    shasum -a 256 "$LOCK_FILE" 2>/dev/null | awk '{print $1}'
  fi
}
CURRENT_LOCK_HASH="$(hash_lockfile)"
RECORDED_LOCK_HASH="$(cat "$LOCK_HASH_FILE" 2>/dev/null || true)"
if [ ! -d "$WT/node_modules" ] || [ "$CURRENT_LOCK_HASH" != "$RECORDED_LOCK_HASH" ]; then
  if ! (cd "$WT" && pnpm install --prefer-offline --frozen-lockfile) >&2; then
    echo "worktree-setup.sh: pnpm install --prefer-offline --frozen-lockfile failed in $WT" >&2
    exit 1
  fi
  printf '%s\n' "$CURRENT_LOCK_HASH" > "$LOCK_HASH_FILE"
fi

printf 'WORKTREE=%s\n' "$WT"
printf 'NX_CACHE_DIRECTORY=%s\n' "$NX_CACHE"
exit 0
