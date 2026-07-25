---
id: worktree-scoped-git-config-immutable-marker
agent: [ai-enablement-engineer]
trigger: [GC race condition, worktree provision-point marker, guard compares against drifting base tip]
rule: 'Fix a guard drifting against a moving base tip by recording an immutable provision marker at creation time via worktree-scoped git config, written only when a worktree is first created.'
evidence: [NA-27]
uses: 0
status: active
---

## Why

A "Case 1 registration probe matches but the directory was removed out-of-band" bug needs the
registration check split from the case dispatch: compute a boolean, insert a `[ ! -d "$WT" ]`
pre-check between the probe and the if/elif case chain that prunes the stale registration and flips
the boolean back to false, then dispatch on the boolean.
