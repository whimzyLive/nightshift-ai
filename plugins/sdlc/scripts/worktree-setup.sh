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
# Any hard failure (cannot create/reuse the worktree, or the dependency install fails) -> non-zero
# exit with a clear message on stderr. The orchestrator STOPs the impl phase on failure — it must
# NEVER fall back to dispatching a writing agent into the primary checkout.

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

REGISTERED=false
if git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $WT"; then
  # `-x` (whole-line match) matters here: porcelain lines are exactly `worktree <path>`, and a plain
  # substring match on `worktree $WT` would also match any worktree whose path merely starts with
  # this story's path (e.g. a registered `sdlc-NA-2` worktree matching a probe for `sdlc-NA-27`).
  REGISTERED=true
fi

if $REGISTERED && [ ! -d "$WT" ]; then
  # The registration survives an out-of-band `rm -rf "$WT"` (git's worktree list doesn't notice
  # until pruned) — without this, Case 1 below would match forever, `git -C "$WT" fetch` would fail
  # (no such directory), and provisioning would be permanently bricked for this story. Prune the
  # stale registration and fall through to the branch-exists/create cases as if never registered.
  echo "worktree-setup.sh: $WT is registered but missing on disk (removed out-of-band) — pruning stale registration" >&2
  git -C "$PRIMARY_ROOT" worktree prune 2>/dev/null || true
  REGISTERED=false
fi

if $REGISTERED; then
  # Case 1: WT already a registered worktree -> reuse (fast-forward to the branch head; no-op if
  # already current). A non-fast-forwardable state is a hard failure — never silently diverge it.
  #
  # If the branch was never pushed (a prior run created the worktree but died before `git push -u`),
  # `origin/$BRANCH` doesn't exist yet — probe for it first and skip the fetch/ff rather than hard
  # failing on every re-invocation forever (idempotent re-provision, invariant 2).
  if git -C "$PRIMARY_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    if ! git -C "$WT" fetch origin "$BRANCH" >&2; then
      echo "worktree-setup.sh: fetch of origin/$BRANCH into $WT failed" >&2
      exit 1
    fi
    # Verify the worktree is actually attached to $BRANCH before fast-forwarding — a detached HEAD
    # (e.g. left mid-checkout by a crashed defect-verification run) would otherwise be silently
    # ff'd while detached, stranding any later commits off the branch entirely. `--abbrev-ref HEAD`
    # returns the literal string "HEAD" (not empty) when detached, so check for that explicitly.
    WT_BRANCH="$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -z "$WT_BRANCH" ] || [ "$WT_BRANCH" = "HEAD" ] || [ "$WT_BRANCH" != "$BRANCH" ]; then
      echo "worktree-setup.sh: $WT is on '$WT_BRANCH' (expected '$BRANCH') — re-attaching" >&2
      if ! git -C "$WT" checkout "$BRANCH" >&2; then
        echo "worktree-setup.sh: could not check out $BRANCH in $WT (dirty working tree?) — resolve manually" >&2
        exit 1
      fi
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
  #
  # The entry condition above admits a LOCAL-only branch too (never pushed) — probe for
  # origin/$BRANCH once (as Case 1 does) and only fetch/ff when it actually exists, rather than
  # fetching unconditionally, which would hard-fail every re-provision of a never-pushed branch
  # (breaks idempotent re-provision, invariant 2).
  REMOTE_EXISTS=false
  if git -C "$PRIMARY_ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    REMOTE_EXISTS=true
  fi
  if $REMOTE_EXISTS; then
    if ! git -C "$PRIMARY_ROOT" fetch origin "$BRANCH" >&2; then
      echo "worktree-setup.sh: fetch of origin/$BRANCH failed" >&2
      exit 1
    fi
  else
    echo "worktree-setup.sh: origin/$BRANCH does not exist yet (never pushed) — re-provisioning from the local branch, skipping fetch" >&2
  fi
  if ! git -C "$PRIMARY_ROOT" worktree add "$WT" "$BRANCH" >&2; then
    echo "worktree-setup.sh: could not re-provision worktree at $WT for existing branch $BRANCH" >&2
    exit 1
  fi
  # `worktree add "$WT" "$BRANCH"` checks out the LOCAL branch ref as-is — fast-forward it to the
  # freshly fetched origin head (mirrors Case 1) so a stale local ref doesn't leave the re-provisioned
  # worktree behind origin/$BRANCH.
  if $REMOTE_EXISTS; then
    if ! git -C "$WT" merge --ff-only "origin/$BRANCH" >&2; then
      echo "worktree-setup.sh: $WT could not fast-forward to origin/$BRANCH (local branch has diverged — resolve manually)" >&2
      exit 1
    fi
  fi
  # Record the provision-point SHA for worktree-gc.sh's zero-commit guard (spec — GC race fix): this
  # is a brand-new worktree directory (the prior one was torn down/GC'd, taking its own recorded SHA
  # with it), so there is no continuity to preserve — record fresh, in worktree-scoped config so it
  # persists across future idempotent re-invocations of this script for the same worktree.
  git -C "$WT" config extensions.worktreeConfig true
  git -C "$WT" config --worktree sdlc.provisionSha "$(git -C "$WT" rev-parse HEAD)"
else
  # Case 3: neither exists — first run. Create the branch INSIDE the worktree from the base; the
  # primary checkout is never touched.
  if ! git -C "$PRIMARY_ROOT" fetch origin "$BASE_BRANCH" >&2; then
    echo "worktree-setup.sh: fetch of origin/$BASE_BRANCH failed" >&2
    exit 1
  fi
  if ! git -C "$PRIMARY_ROOT" worktree add -b "$BRANCH" "$WT" "origin/$BASE_BRANCH" >&2; then
    echo "worktree-setup.sh: could not create worktree $WT with new branch $BRANCH from origin/$BASE_BRANCH" >&2
    exit 1
  fi
  # Record the provision-point SHA (this worktree's true creation point, off $BASE_BRANCH) in
  # worktree-scoped git config — worktree-gc.sh's zero-commit guard compares against this instead of
  # the CURRENT origin/$BASE_BRANCH tip, so a concurrent session's base advancing after this worktree
  # was created can never make a genuinely-zero-commit worktree look "merged" and get GC'd mid-flight.
  git -C "$WT" config extensions.worktreeConfig true
  git -C "$WT" config --worktree sdlc.provisionSha "$(git -C "$WT" rev-parse HEAD)"
fi

# Provision node_modules ONCE per worktree (spec Open Question 1, decided), and re-provision
# whenever the lockfile has moved on since the last install (e.g. a later phase/fix-round added a
# dependency). The package manager's content-addressed/shared cache hardlinks across worktrees, so
# this is cheap; it also builds the correct per-package node_modules link farms a workspace needs —
# a root-only symlink to the primary checkout's node_modules is deliberately NOT used (rejected in
# spec: it breaks those per-package link farms).
#
# Package manager: read the "Package manager" token from project-context.md (same sed pattern used
# for Base branch) so this published script stays correct for repos that aren't pnpm-based; default
# to pnpm when the file/row is missing or unreadable.
CTX="$PRIMARY_ROOT/.claude/project/project-context.md"
PKG_MANAGER="$(grep -iE '^\|[[:space:]]*Package manager[[:space:]]*\|' "$CTX" 2>/dev/null \
  | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([A-Za-z0-9_.\/-]+)`?[[:space:]]*\|.*/\1/' \
  | head -1 || true)"
PKG_MANAGER="${PKG_MANAGER:-pnpm}"

case "$PKG_MANAGER" in
  pnpm)
    INSTALL_CMD="pnpm install --prefer-offline --frozen-lockfile"
    LOCK_FILE_NAME="pnpm-lock.yaml"
    ;;
  npm)
    INSTALL_CMD="npm ci"
    LOCK_FILE_NAME="package-lock.json"
    ;;
  yarn)
    INSTALL_CMD="yarn install --immutable"
    LOCK_FILE_NAME="yarn.lock"
    ;;
  bun)
    INSTALL_CMD="bun install --frozen-lockfile"
    LOCK_FILE_NAME="bun.lockb"
    ;;
  *)
    echo "worktree-setup.sh: unrecognized Package manager '$PKG_MANAGER' in project-context.md — falling back to pnpm" >&2
    PKG_MANAGER="pnpm"
    INSTALL_CMD="pnpm install --prefer-offline --frozen-lockfile"
    LOCK_FILE_NAME="pnpm-lock.yaml"
    ;;
esac

# Cheap idempotent staleness check: hash the worktree's own lockfile and compare against the hash
# recorded at the last successful install. Missing node_modules (fresh worktree) or a missing hash
# file both count as stale (mismatch against an empty recorded hash), so this also covers the
# original "install once" case with no separate branch. An absent lockfile (dependency-less root, or
# an unrecognized manager token) skips the hash check entirely — install only when node_modules
# itself is missing.
LOCK_FILE="$WT/$LOCK_FILE_NAME"
LOCK_HASH_FILE="$WT/node_modules/.sdlc-lock-hash"
hash_lockfile() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$LOCK_FILE" 2>/dev/null | awk '{print $1}'
  else
    shasum -a 256 "$LOCK_FILE" 2>/dev/null | awk '{print $1}'
  fi
}

NEEDS_INSTALL=false
if [ -f "$LOCK_FILE" ]; then
  CURRENT_LOCK_HASH="$(hash_lockfile)"
  RECORDED_LOCK_HASH="$(cat "$LOCK_HASH_FILE" 2>/dev/null || true)"
  if [ ! -d "$WT/node_modules" ] || [ "$CURRENT_LOCK_HASH" != "$RECORDED_LOCK_HASH" ]; then
    NEEDS_INSTALL=true
  fi
else
  CURRENT_LOCK_HASH=""
  [ ! -d "$WT/node_modules" ] && NEEDS_INSTALL=true
fi

if $NEEDS_INSTALL; then
  if ! (cd "$WT" && eval "$INSTALL_CMD") >&2; then
    echo "worktree-setup.sh: $INSTALL_CMD failed in $WT" >&2
    exit 1
  fi
  # A dependency-less install can legitimately produce no node_modules at all — guard the write so
  # the redirect doesn't fail silently-successful (exit 0 with staleness stuck permanently stale).
  # Only record a hash when there was a lockfile to hash in the first place.
  if [ -f "$LOCK_FILE" ]; then
    mkdir -p "$WT/node_modules"
    printf '%s\n' "$CURRENT_LOCK_HASH" > "$LOCK_HASH_FILE"
  fi
fi

printf 'WORKTREE=%s\n' "$WT"
printf 'NX_CACHE_DIRECTORY=%s\n' "$NX_CACHE"
exit 0
