# shared cross-domain memory

## 2026-07-10 — Story NA-22 — worktree/branch and Nx workspace gotchas

**Learnings:**

- The pre-work branch-checkout check in the domain-agent handoff protocol
  can legitimately fail with "not found on origin" even when the branch
  _does_ exist on origin — it's checked out in the **primary** (non-worktree)
  checkout, and your dispatch worktree's own branch
  (`worktree-agent-<id>`) is simply behind it. Don't treat this as a hard
  blocker before checking: `git fetch origin && git log <branch> --oneline
-3` (does it exist on origin?) and `git merge-base <branch> HEAD` (is my
  HEAD an ancestor?). If it's a clean fast-forward, `git merge <branch>
--ff-only` catches your worktree branch up without creating a new branch
  or touching the other worktree.
- `nx sync` in this workspace needs to be **invoked twice** to fully
  converge after adding a new workspace package as a dependency (e.g.
  `packages/design-system` consumed by `packages/ui`/`apps/marketing`) —
  the first run reports "workspace is out of sync" _and_ writes the
  `tsconfig.json`/`tsconfig.*.json` project-reference fixes in the same
  invocation; only the second run reports "already up to date". Any agent
  hitting the "workspace is out of sync" error from a plain `nx build`/
  `nx test`/etc. should run `nx sync` (possibly twice) rather than treating
  it as a real failure.
- A shared Postgres container from another worktree/session may already be
  listening on `localhost:5432` in this sandbox, even when `docker
ps`/`docker info` themselves hang or time out (the daemon socket seems
  only partially reachable via the CLI here, but the container's TCP port
  is fine). Check with `psql -h localhost -p 5432 -U postgresql -d
nightshift` (defaults from `apps/marketing/docker-compose.yml`) before
  assuming you must run `local-start` yourself — and check `\dt` first so
  you know whether you're about to reuse a clean or already-populated DB.

**Pitfalls:**

- None beyond what's captured above — no destructive actions taken.

**Patterns:**

- None new beyond the above.
