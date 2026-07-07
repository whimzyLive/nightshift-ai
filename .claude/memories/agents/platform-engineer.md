# platform-engineer memory

## 2026-07-07 — Story NA-3 — Bootstrap gtm plugin config via /gtm:init
**Learnings:**
- Dispatch-prompt "locked decisions" outrank a plan's own verify commands when they conflict. The
  NA-3 plan's TG2 jq check (`.dependencies == ["postiz@postiz-agent", ...]`, flat strings) was
  stale relative to the spec/dispatch instruction that `plugin.json` dependencies mirror sdlc's
  `{name, marketplace}` object shape. Followed the dispatch instruction (object shape, verified
  with `[.dependencies[] | "\(.name)@\(.marketplace)"] == [...]`) since sdlc's actual manifest is
  objects, not strings — a literal string array would be inconsistent with the only other
  plugin.json in the repo.
- "Vendored functional equivalent" should mean a genuinely adapted copy, not a literal branded
  copy: the sdlc scripts (session-key.sh/tmp-dir.sh/cleanup-tmp.sh/session-complete.sh) reference
  `SDLC_SESSION_KEY` and sdlc-specific commands (`/auto`, `/impl`, `refs/triage.md`) in comments —
  left as-is these would be misleading/wrong inside a standalone gtm package. Renamed the env var
  to `GTM_SESSION_KEY` and the sentinel to `GTM_SESSION_COMPLETE`, and rewrote the sdlc-specific
  prose to reference gtm commands instead. `session-key.sh`'s `CLAUDE_CODE_SESSION_ID` fallback is
  generic and needed no change.
- The repo's own portability-lint.sh only scans `plugins/sdlc` — running it against a new
  `plugins/gtm/` package is a no-op pass regardless of gtm's content. Don't rely on it as a real
  gate for a new plugin; ran the sdlc lint's individual grep checks by hand against `plugins/gtm/`
  for real coverage (no absolute paths, no broken `./${CLAUDE_PLUGIN_ROOT}`, no PII, no forbidden
  agent frontmatter, frontmatter completeness) in addition to the plan's literal TG8 steps.

**Pitfalls:**
- This dispatch's isolated worktree (`.claude/worktrees/agent-<id>`) is checked out on its own
  local branch (`worktree-agent-<id>`), NOT the named `feat/<STORY-KEY>` branch — because
  `feat/<STORY-KEY>` was already checked out in the shared main checkout by another process, and
  git refuses to check out the same branch in two worktrees. The Write tool enforces worktree
  isolation (blocks writes to the shared checkout path) but Bash does not — a `cd` to the shared
  checkout path silently let file writes land there instead of the isolated worktree. Caught this
  before committing (removed the accidental `plugins/gtm/` from the shared checkout) and instead
  fast-forwarded the isolated worktree's branch to `origin/feat/<STORY-KEY>` (`git merge --ff-only
  origin/feat/<STORY-KEY>`) to pick up commits (the plan doc) that existed on the named branch but
  not yet on the worktree's local branch. Always verify `pwd` / `git branch --show-current` in the
  *default* Bash cwd (no `cd`) before writing — never `cd` into the shared checkout path.

**Patterns:**
- For a new "standalone, zero-dependency-on-sibling-plugin" package, grep the whole new package
  tree for the sibling plugin's path (`plugins/<sibling>`) at the end, not just the vendored
  scripts subdir — provenance comments belong in the plan/spec docs, not inside the new package
  itself (even doc files under the new plugin's own `refs/`/`README.md` should stay free of the
  literal path).
