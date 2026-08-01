---
id: bash-cd-bypasses-tool-worktree-isolation
agent: [web-engineer, platform-engineer]
trigger: [git worktree dispatch, cd into shared checkout path, accidental write to wrong checkout, absolute path missing worktree segment]
rule: Neither Bash `cd` into another checkout nor an Edit/Write path missing the worktree segment is tool-enforced; verify the absolute path names your assigned worktree before every Edit/Write call.
evidence: [NA-16, NA-3, NA-81]
uses: 0
status: active
---

## Why

Originally recorded as "the Write/Edit tools refuse to touch files outside your assigned
worktree" — disproven on NA-81: an `Edit` call using the primary checkout's absolute path
(worktree segment omitted) succeeded silently, dirtying the primary checkout with zero
refusal and zero error. Caught only via `git status --porcelain` run explicitly against
the primary checkout — the Edit tool's own success message gave no signal. Verify with
`git status --porcelain` in BOTH the assigned worktree and the primary checkout after any
Edit/Write in a worktree dispatch, not just the one you intended.
