---
id: bare-hook-script-reads-project-context-directly
agent: [ai-enablement-engineer]
trigger: [worktree-gc.sh, SessionEnd hook with zero args, script needs a per-repo config value with no orchestrator]
rule: 'A published multi-repo script needing a per-repo config value can read `project-context.md` directly at runtime when the caller is a bare hook/script with no orchestrator handing the value in.'
evidence: [NA-27]
uses: 0
status: active
---

## Why

Mirror an existing "read a single-value token row" script convention (sed/grep pattern, defaulted
on read-failure, `|| true` guards load-bearing under `set -uo pipefail`) rather than inventing a new
shape.
