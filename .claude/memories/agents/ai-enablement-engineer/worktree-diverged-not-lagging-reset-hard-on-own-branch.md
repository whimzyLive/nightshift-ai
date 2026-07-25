---
id: worktree-diverged-not-lagging-reset-hard-on-own-branch
agent: [ai-enablement-engineer]
trigger: [worktree local history diverged from target not just lagging, git reset --hard origin/branch]
rule: "When a dispatched worktree's branch has DIVERGED from the target, `git reset --hard origin/<branch>` on the worktree's OWN branch is correct — confirm `git status --short` is empty first."
evidence: [NA-26]
uses: 0
status: active
---
