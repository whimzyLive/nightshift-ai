---
status: accepted
agents: [platform-engineer, web-engineer, ai-enablement-engineer]
source-stories: [NA-3, NA-16, NA-26, NA-27]
---

# 0005. Never operate from the shared/primary checkout path inside a dispatched worktree; free branch locks via ff-only merge

## Status

Accepted

## Decision

We will treat every domain-agent dispatch's assigned git worktree as the only valid
Bash working directory for that dispatch, and will never `cd` (directly or via a
Bash-tool call) into the shared/primary checkout path or any sibling worktree's path.
When the dispatch's own branch is checked out elsewhere (a sibling worktree or the
primary checkout) and blocks `git checkout <branch>`, we will resolve it by confirming
the target ref's actual state (`git merge-base --is-ancestor`, `git log <local>..<target>`)
and fast-forwarding the local worktree branch onto it (`git merge --ff-only
[origin/]<branch>`) rather than force-switching or force-freeing another checkout,
unless the sibling checkout is independently verified clean and a ff-only merge is
genuinely not possible.

## Context

Git's one-worktree-per-branch rule means a dispatch's target branch is frequently
already checked out somewhere else — the primary repo checkout (left over from a
planning phase) or a sibling agent's worktree — at the moment a new dispatch starts.
The Write/Edit tools correctly refuse to touch files outside a dispatch's assigned
worktree even after a `cd`, but the Bash tool does not enforce this: a bare `cd` to the
shared checkout path silently redirects subsequent git/file operations onto the wrong
checkout, which is a hard violation for any operation that stages or commits. This
recurred across at least three different domain agents (platform-engineer's very first
NA-3 dispatch and its two review-fix rounds; web-engineer's NA-16 hero-landing story and
its own review-fix round; ai-enablement-engineer's NA-26/NA-27 stories, several times
each) as an independently-rediscovered pattern rather than a documented, shared
convention.

## Alternatives Considered

### Force-switch the blocking checkout every time (`git checkout --force`, or delete/recreate the worktree)

- Pros: guaranteed to free the branch immediately, no need to reason about ancestry.
- Cons: risks discarding uncommitted work in the other checkout if it isn't actually
  clean; genuinely destructive in the case where the other checkout diverged rather than
  merely lagged.

### Always detach the other checkout's HEAD, never merge forward

- Pros: simple, uniform mechanism (one technique for every case).
- Cons: unnecessary and slightly riskier when the local worktree branch is a strict
  ancestor of the target — a plain ff-only merge achieves the same result with less
  disruption to the other checkout, and detaching should be reserved for when the other
  checkout genuinely needs to keep running (e.g. it's mid-dispatch itself).

## Consequences

- Every dispatch must verify `pwd` / `git branch --show-current` in the _default_
  (non-`cd`'d) Bash cwd before any write — an extra, cheap check that catches the
  silent-wrong-checkout class of bug before it produces a bad commit.
- The ff-only-first resolution order (verify ancestry → merge --ff-only) is strictly
  safer than forced approaches, at the cost of occasionally needing a second technique
  (verified-clean detach, or freeing the primary checkout) when the branches have
  genuinely diverged rather than merely lagged.
- New domain agents (or new dispatch types) inherit one documented git-worktree recipe
  instead of rediscovering it independently per-agent, which is what happened
  repeatedly across the source stories.
- Revisit if the harness's worktree-provisioning mechanism changes to guarantee a
  dispatch's target branch is never checked out elsewhere at dispatch start.
