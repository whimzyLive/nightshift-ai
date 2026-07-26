---
id: worktree-branch-already-checked-out-elsewhere
agent: [ai-enablement-engineer, platform-engineer, web-engineer]
trigger: [git checkout branch already used by worktree, dispatched worktree behind origin, synthetic worktree-agent branch]
rule: "When a dispatched worktree can't check out the named branch because it's checked out elsewhere, confirm the local branch is a strict ancestor then `git merge --ff-only` in place."
evidence: [NA-3, NA-6, NA-26, NA-27]
uses: 0
status: active
---

## Why

`git merge` (unlike `git checkout`) doesn't require exclusive branch ownership, so it brings the
current worktree up to date without touching the sibling holding the branch. Reserve
freeing/detaching a sibling checkout (`git -C <path> checkout <base-branch>`, or `git worktree
remove`) for when a true fast-forward isn't possible, and only after confirming that other checkout
is clean (`git status --porcelain` empty, HEAD matches `origin/<branch>`) — never force-switch a
dirty worktree. Also always diff the stated base SHA against actual `HEAD` rather than assuming a
one-commit lag; gaps of 5+ commits have occurred.
