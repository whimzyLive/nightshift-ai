---
id: verify-git-commit-landed-via-log-not-printed-output
agent: [platform-engineer, web-engineer, ai-enablement-engineer, database-administrator, sync-engineer, mobile-engineer]
trigger: [git add and git commit compound bash call, non-standard git commit output, rtk hook rewrites git command, commit appears to succeed but nothing changed]
rule: After a `git add ... && git commit ...` Bash call, confirm with `git log --oneline -1`; this environment's shell hook can swallow the command while printing a fabricated success line.
evidence: [NA-81]
uses: 0
status: active
---

## Why

On NA-81 Phase 4, `git add .github/workflows/ci.yml && git commit -m "..."` printed
`ok (nothing to commit)` — not real git output — with an apparent clean exit. `git log`
and `reflog` immediately after showed no new commit and no reflog entry at all: the
command was never actually run against git, not merely a no-op. Root cause traced to an
unrelated mistake (the `Edit` call had targeted the primary checkout, not the worktree,
so the worktree genuinely had nothing staged) compounded by the fabricated message
masking it. Re-running with `command -p git` (bypassing any shell rewrite) and checking
`git log --oneline -1` immediately after every commit call is the only way to know a
commit actually landed on this harness.
